import 'dart:async';

import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/screens/home/todo_controller.dart';
import 'package:do_it/screens/todo_list/todo_list_screen.dart';
import 'package:do_it/services/firestore_todo_repository.dart';
import 'package:do_it/services/firestore_todo_store.dart';
import 'package:do_it/widgets/skeleton_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../services/fake_firestore_todo_store.dart';

void main() {
  late FakeFirestoreTodoStore store;
  late FirestoreTodoRepository repository;

  setUp(() {
    store = FakeFirestoreTodoStore();
    repository = FirestoreTodoRepository(store);
  });
  tearDown(() => store.changes.close());

  // 실제 Firestore 저장소 변환과 화면을 연결하되 SDK 입출력만 대체한다.
  Future<void> pump(WidgetTester tester, {bool isOnline = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TodoListScreen(repository: repository, isOnline: isOnline),
      ),
    );
    await tester.pumpAndSettle();
  }

  // 다른 기기에서 받은 문서나 메타데이터 변경을 재현한다.
  void receive(
    String title, {
    bool isPending = false,
    bool isCompleted = false,
  }) {
    final todo = migrationTodo(
      'shared',
      title: title,
    ).copyWith(isCompleted: isCompleted);
    store.documents['shared'] = RemoteTodoDocument(
      id: 'shared',
      data: {...todo.toMap(), 'deleted': false},
      isPending: isPending,
    );
    store.emit();
  }

  testWidgets('다른 기기의 추가·수정·완료·삭제가 새로고침 없이 반영된다', (tester) async {
    await pump(tester);
    receive('기기 A에서 추가');
    await tester.pumpAndSettle();
    expect(find.text('기기 A에서 추가'), findsOneWidget);
    receive('기기 A에서 수정', isCompleted: true);
    await tester.pumpAndSettle();
    expect(find.text('기기 A에서 추가'), findsNothing);
    expect(find.text('기기 A에서 수정'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    store.documents['shared'] = const RemoteTodoDocument(
      id: 'shared',
      data: {'deleted': true},
    );
    store.emit();
    await tester.pumpAndSettle();
    expect(find.text('기기 A에서 수정'), findsNothing);
    expect(find.text('아직 등록한 할 일이 없어요'), findsOneWidget);
  });

  testWidgets('메타데이터 확인만으로 대기 배지가 완료로 바뀐다', (tester) async {
    receive('오프라인에서 작성', isPending: true);
    await pump(tester, isOnline: false);
    expect(find.text('동기화 대기 1'), findsOneWidget);
    receive('오프라인에서 작성');
    await tester.pumpAndSettle();
    expect(find.text('동기화 대기 1'), findsNothing);
    expect(find.text('동기화 완료'), findsOneWidget);
    expect(store.serverReads, 0);
  });

  testWidgets('마지막 항목 삭제도 서버 전송 전에는 대기 건수로 남는다', (tester) async {
    receive('삭제할 할 일');
    await pump(tester);
    store.documents['shared'] = const RemoteTodoDocument(
      id: 'shared',
      data: {'deleted': true},
      isPending: true,
    );
    store.emit();
    await tester.pumpAndSettle();
    expect(find.text('아직 등록한 할 일이 없어요'), findsOneWidget);
    expect(find.text('동기화 대기 1'), findsOneWidget);
    store.documents['shared'] = const RemoteTodoDocument(
      id: 'shared',
      data: {'deleted': true},
    );
    store.emit();
    await tester.pumpAndSettle();
    expect(find.text('동기화 완료'), findsOneWidget);
  });

  testWidgets('빈 목록도 당겨서 서버 새로고침할 수 있다', (tester) async {
    await pump(tester);
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();
    expect(store.serverReads, 1);
  });

  testWidgets('짧은 목록도 서버 새로고침하며 실패하면 기존 항목을 보존한다', (tester) async {
    receive('기존 항목');
    await pump(tester);
    store.isOnline = false;
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(store.serverReads, 1);
    expect(find.text('기존 항목'), findsOneWidget);
    expect(find.textContaining('서버에서 새로고침하지 못했습니다'), findsOneWidget);
  });

  for (final shouldFail in [false, true]) {
    testWidgets('서버 응답 대기 중 목록·배지·요약을 유지한다 (${shouldFail ? '실패' : '성공'})', (
      tester,
    ) async {
      final delayed = _DelayedRefreshStore();
      store = delayed;
      repository = FirestoreTodoRepository(store);
      receive('기존 목록');
      await pump(tester);

      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(store.serverReads, 1);
      expect(find.text('기존 목록'), findsOneWidget);
      expect(find.text('남은 할 일 1개'), findsOneWidget);
      expect(find.text('동기화 완료'), findsOneWidget);
      expect(find.byType(SkeletonList), findsNothing);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);

      if (shouldFail) {
        delayed.gate.completeError(StateError('서버 응답 실패'));
      } else {
        delayed.gate.complete([
          RemoteTodoDocument(
            id: 'shared',
            data: migrationTodo('shared', title: '서버 최신 목록').toMap(),
          ),
        ]);
      }
      await tester.pumpAndSettle();
      expect(find.text(shouldFail ? '기존 목록' : '서버 최신 목록'), findsOneWidget);
      expect(find.text('남은 할 일 1개'), findsOneWidget);
      expect(find.text('동기화 완료'), findsOneWidget);
      expect(find.byType(SkeletonList), findsNothing);
      expect(
        find.textContaining('서버에서 새로고침하지 못했습니다'),
        shouldFail ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets('필터 결과가 없어도 당겨서 새로고침한다', (tester) async {
    receive('미완료 항목');
    await pump(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, '완료'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();
    expect(store.serverReads, 1);
  });

  testWidgets('온라인 복귀 시 배너를 숨기고 서버 새로고침한다', (tester) async {
    receive('캐시 항목');
    await pump(tester, isOnline: false);
    expect(find.textContaining('오프라인 상태입니다'), findsOneWidget);
    await pump(tester);
    expect(find.textContaining('오프라인 상태입니다'), findsNothing);
    expect(store.serverReads, 1);
  });

  testWidgets('화면 종료 후에는 실시간 구독을 해제한다', (tester) async {
    await pump(tester);
    expect(store.changes.hasListener, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(store.changes.hasListener, isFalse);
    receive('종료 후 변경');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('실시간 구독 오류도 기존 자동 재시도로 복구한다', (tester) async {
    receive('유지할 항목');
    await pump(tester);
    store.changes.addError(StateError('구독 실패'));
    await tester.pumpAndSettle();
    expect(find.text('할 일을 불러오지 못했습니다'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('유지할 항목'), findsOneWidget);
    expect(find.text('할 일을 불러오지 못했습니다'), findsNothing);
  });

  test('늦은 초기 조회가 더 최신 실시간 목록을 덮어쓰지 않는다', () async {
    final delayed = _DelayedStore();
    final controller = TodoController(FirestoreTodoRepository(delayed));
    final loading = controller.load();
    delayed.documents['new'] = RemoteTodoDocument(
      id: 'new',
      data: migrationTodo('new', title: '최신 목록').toMap(),
    );
    delayed.emit();
    await Future<void>.delayed(Duration.zero);
    delayed.gate.complete([]);
    await loading;
    expect(controller.todos.single.title, '최신 목록');
    controller.dispose();
    await delayed.changes.close();
  });

  test('동시에 요청된 새로고침은 서버 조회 하나로 합친다', () async {
    final delayed = _DelayedStore();
    final controller = TodoController(FirestoreTodoRepository(delayed));
    final first = controller.load(fromServer: true);
    final second = controller.load(fromServer: true);
    delayed.gate.complete([]);
    await Future.wait([first, second]);
    expect(delayed.serverReads, 1);
    controller.dispose();
    await delayed.changes.close();
  });

  test('쓰기 실패의 되돌리기가 더 최근 서버 목록을 덮어쓰지 않는다', () async {
    final failing = _FailingWriteStore();
    await failing.importTodo(migrationTodo('one', title: '기존 제목'));
    final controller = TodoController(FirestoreTodoRepository(failing));
    await controller.load();
    final updating = controller.update(
      controller.todos.single.copyWith(title: '로컬 수정'),
    );
    failing.documents['one'] = RemoteTodoDocument(
      id: 'one',
      data: migrationTodo('one', version: 3, title: '최신 서버 제목').toMap(),
    );
    failing.emit();
    await Future<void>.delayed(Duration.zero);
    failing.gate.completeError(StateError('쓰기 실패'));
    expect(await updating, isFalse);
    expect(controller.todos.single.title, '최신 서버 제목');
    controller.dispose();
    await failing.changes.close();
  });
}

// 초기 조회는 즉시 끝내고 수동 서버 새로고침 응답만 지연시킨다.
class _DelayedRefreshStore extends FakeFirestoreTodoStore {
  final gate = Completer<List<RemoteTodoDocument>>();

  @override
  Future<List<RemoteTodoDocument>> readServer() {
    serverReads++;
    return gate.future;
  }
}

// 쓰기 응답을 늦춰 서버 구독 결과와 오류 되돌리기가 겹치는 상황을 검사한다.
class _FailingWriteStore extends FakeFirestoreTodoStore {
  final gate = Completer<void>();

  @override
  Future<void> enqueue(String id, Map<String, Object?> data) => gate.future;
}

// 오래 걸리는 서버 응답을 제어해 조회·구독 사이의 순서 경쟁을 검사한다.
class _DelayedStore extends FakeFirestoreTodoStore {
  final gate = Completer<List<RemoteTodoDocument>>();

  @override
  Future<List<RemoteTodoDocument>> readAll() => gate.future;

  @override
  Future<List<RemoteTodoDocument>> readServer() {
    serverReads++;
    return gate.future;
  }
}
