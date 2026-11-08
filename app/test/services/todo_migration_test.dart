import 'dart:async';

import 'package:do_it/services/firestore_todo_repository.dart';
import 'package:do_it/services/todo_migration.dart';
import 'package:do_it/services/todo_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_firestore_todo_store.dart';

void main() {
  late InMemoryTodoRepository local;
  late MemoryMigrationJournal journal;
  late Map<String, FakeFirestoreTodoStore> stores;
  String? uid;
  TodoRepositorySession session() => TodoRepositorySession(
    local: local,
    journal: journal,
    currentUid: () => uid,
    remoteFor: (id) => FirestoreTodoRepository(
      stores.putIfAbsent(id, FakeFirestoreTodoStore.new),
    ),
  );
  setUp(() {
    local = InMemoryTodoRepository([
      migrationTodo('one'),
      migrationTodo('two'),
    ]);
    journal = MemoryMigrationJournal();
    stores = {};
    uid = null;
  });

  test('로그인 전에는 SQLite 역할의 로컬 저장소를 그대로 사용한다', () async {
    expect(await session().forAccount(null), same(local));
    expect(stores, isEmpty);
  });

  test('첫 로그인 시 같은 ID로 이관하고 서버 확인 후 원본을 정리한다', () async {
    uid = 'account-a';
    final repository = await session().forAccount(uid);
    expect((await repository.getAll()).map((todo) => todo.id), ['one', 'two']);
    expect(await local.getAll(), isEmpty);
    expect(journal.record!.isCompleted, isTrue);
    expect(journal.record!.todos, isEmpty);
  });

  test('이관 중 실패하면 원본을 보존하고 재시작 후 같은 ID로 재개한다', () async {
    uid = 'account-a';
    final store = stores[uid!] = FakeFirestoreTodoStore()..failImportNumber = 2;
    await expectLater(session().forAccount(uid), throwsStateError);
    expect(await local.getAll(), hasLength(2));
    expect(journal.record!.isCompleted, isFalse);
    store.failImportNumber = null;
    await session().forAccount(uid);
    expect(store.documents.keys, unorderedEquals(['one', 'two']));
    expect(await local.getAll(), isEmpty);
  });

  test('완료 표시 저장 실패 시에도 원본을 보존하고 중복 없이 재시도한다', () async {
    uid = 'account-a';
    journal.failCompletedWrite = true;
    await expectLater(session().forAccount(uid), throwsStateError);
    expect(await local.getAll(), hasLength(2));
    journal.failCompletedWrite = false;
    await session().forAccount(uid);
    expect(stores[uid!]!.documents, hasLength(2));
  });

  test('서버의 더 최신 수정은 이관으로 덮어쓰지 않는다', () async {
    uid = 'account-a';
    final store = stores[uid!] = FakeFirestoreTodoStore();
    await store.importTodo(
      migrationTodo('one', version: 10, title: '최신 서버 내용'),
    );
    final repository = await session().forAccount(uid);
    expect((await repository.getAll()).first.title, '최신 서버 내용');
  });

  test('서버 삭제 기록은 이관을 재시도해도 되살아나지 않는다', () async {
    uid = 'account-a';
    final store = stores[uid!] = FakeFirestoreTodoStore();
    await FirestoreTodoRepository(store).delete('one');
    final repository = await session().forAccount(uid);
    expect((await repository.getAll()).map((todo) => todo.id), ['two']);
  });

  test('미완료 이관은 다른 계정으로 넘기지 않는다', () async {
    uid = 'account-a';
    stores[uid!] = FakeFirestoreTodoStore()..isOnline = false;
    await expectLater(session().forAccount(uid), throwsStateError);
    uid = 'account-b';
    await expectLater(session().forAccount(uid), throwsStateError);
    expect(stores['account-b']!.documents, isEmpty);
    expect(await local.getAll(), hasLength(2));
  });

  test('이관 도중 계정이 바뀌면 완료 처리와 원본 삭제를 중단한다', () async {
    uid = 'account-a';
    final gate = Completer<void>();
    stores[uid!] = FakeFirestoreTodoStore()..importGate = gate;
    final pending = session().forAccount(uid);
    final assertion = expectLater(pending, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    uid = 'account-b';
    gate.complete();
    await assertion;
    expect(journal.record!.isCompleted, isFalse);
    expect(await local.getAll(), hasLength(2));
  });

  test('완료 이후 재로그인은 원본을 중복 이관하지 않는다', () async {
    uid = 'account-a';
    await session().forAccount(uid);
    final count = stores[uid!]!.importedIds.length;
    await session().forAccount(uid);
    expect(stores[uid!]!.importedIds, hasLength(count));
  });

  test('로그아웃 후 새 로컬 항목은 다음 로그인에서 한 번 이관한다', () async {
    uid = 'account-a';
    await session().forAccount(uid);
    uid = null;
    expect(await session().forAccount(null), same(local));
    await local.save(migrationTodo('new-local'));
    uid = 'account-a';
    await session().forAccount(uid);
    expect(
      stores[uid!]!.documents.keys,
      unorderedEquals(['one', 'two', 'new-local']),
    );
  });
}
