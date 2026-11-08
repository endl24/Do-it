import 'dart:async';

import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/screens/todo_list/account_todo_screen.dart';
import 'package:do_it/services/account_service.dart';
import 'package:do_it/services/firestore_todo_repository.dart';
import 'package:do_it/services/todo_migration.dart';
import 'package:do_it/services/todo_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../services/fake_firestore_todo_store.dart';

// 인증 계정을 전환해 이전 계정의 화면이 남는지 검사한다.
class SwitchingAccountService implements AccountService {
  final changes = StreamController<AccountIdentity?>.broadcast();
  AccountIdentity? account;

  @override
  AccountIdentity? get currentAccount => account;
  @override
  Stream<AccountIdentity?> get accountChanges => changes.stream;

  @override
  Future<void> signIn(String email, String password) async {
    account = AccountIdentity(uid: email, email: email);
    changes.add(account);
  }

  @override
  Future<void> signUp(String email, String password) => signIn(email, password);

  @override
  Future<void> signOut() async {
    account = null;
    changes.add(null);
  }
}

void main() {
  late SwitchingAccountService account;
  late InMemoryTodoRepository local;
  late Map<String, FakeFirestoreTodoStore> stores;
  late MemoryMigrationJournal journal;

  setUp(() {
    account = SwitchingAccountService();
    local = InMemoryTodoRepository([
      migrationTodo('local', title: '로컬에서 만든 할 일'),
    ]);
    stores = {};
    journal = MemoryMigrationJournal();
  });
  tearDown(() => account.changes.close());

  // 테스트 저장소와 인증 서비스를 연결하되 실제 SQLite·Firebase는 호출하지 않는다.
  Future<void> pump(WidgetTester tester) async {
    final session = TodoRepositorySession(
      local: local,
      journal: journal,
      currentUid: () => account.currentAccount?.uid,
      remoteFor: (uid) => FirestoreTodoRepository(
        stores.putIfAbsent(uid, FakeFirestoreTodoStore.new),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AccountTodoScreen(accountService: account, session: session),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('로그인 시 이관한 서버 목록을 표시하고 로그아웃 시 이전 목록을 숨긴다', (tester) async {
    await pump(tester);
    expect(find.text('로컬에서 만든 할 일'), findsOneWidget);
    await account.signIn('account-a', 'unused');
    await tester.pumpAndSettle();
    expect(stores['account-a']!.documents.keys, contains('local'));
    expect(find.text('로컬에서 만든 할 일'), findsOneWidget);
    await account.signOut();
    await tester.pumpAndSettle();
    expect(find.text('로컬에서 만든 할 일'), findsNothing);
    expect(find.textContaining('아직 등록한 할 일이 없어요'), findsOneWidget);
  });

  testWidgets('다른 계정으로 전환하면 이전 계정의 할 일이 표시되지 않는다', (tester) async {
    await pump(tester);
    await account.signIn('account-a', 'unused');
    await tester.pumpAndSettle();
    await account.signIn('account-b', 'unused');
    await tester.pumpAndSettle();
    expect(find.text('로컬에서 만든 할 일'), findsNothing);
    expect(stores['account-b']!.documents, isEmpty);
  });

  testWidgets('이관 실패 시 원본을 남기고 재시도 버튼으로 복구한다', (tester) async {
    await pump(tester);
    stores['account-a'] = FakeFirestoreTodoStore()..isOnline = false;
    await account.signIn('account-a', 'unused');
    await tester.pumpAndSettle();
    expect(find.text('할 일 저장소를 준비하지 못했습니다'), findsOneWidget);
    expect(await local.getAll(), hasLength(1));
    stores['account-a']!.isOnline = true;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('로컬에서 만든 할 일'), findsOneWidget);
    expect(await local.getAll(), isEmpty);
  });
}
