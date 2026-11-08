import 'package:do_it/models/todo.dart';
import 'package:do_it/services/firestore_todo_repository.dart';
import 'package:do_it/services/firestore_todo_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_firestore_todo_store.dart';

void main() {
  late FakeFirestoreTodoStore store;
  late FirestoreTodoRepository repository;
  setUp(() {
    store = FakeFirestoreTodoStore();
    repository = FirestoreTodoRepository(
      store,
      clock: () => DateTime.utc(2026, 11, 20),
    );
  });

  test('할 일의 필드를 보존하고 문서 ID와 동기화 상태를 변환한다', () async {
    final todo = migrationTodo('one');
    await repository.save(todo);
    final restored = (await repository.getAll()).single;
    expect(restored.id, todo.id);
    expect(restored.remoteId, todo.id);
    expect(restored.title, todo.title);
    expect(restored.dueDate, todo.dueDate);
    expect(restored.updatedAt, todo.updatedAt);
    expect(restored.syncStatus, TodoSyncStatus.synced);
  });

  test('오프라인 쓰기는 로컬 반영 후 반환하고 동기화 대기로 표시한다', () async {
    store.isOnline = false;
    await repository.save(migrationTodo('pending'));
    expect(
      (await repository.getAll()).single.syncStatus,
      TodoSyncStatus.pending,
    );
    final old = store.documents['pending']!;
    store.documents['pending'] = RemoteTodoDocument(id: old.id, data: old.data);
    expect(
      (await repository.getAll()).single.syncStatus,
      TodoSyncStatus.synced,
    );
  });

  test('서버에서 거절된 쓰기는 실패 상태로 표시한다', () async {
    await repository.save(migrationTodo('failed'));
    store.failures.add('failed');
    expect(
      (await repository.getAll()).single.syncStatus,
      TodoSyncStatus.failed,
    );
  });

  test('캐시에 더 최신 값이 있으면 오래된 수정으로 덮어쓰지 않는다', () async {
    await repository.save(migrationTodo('one', version: 5));
    await expectLater(
      repository.save(migrationTodo('one', version: 2)),
      throwsStateError,
    );
    expect(
      (await repository.getAll()).single.updatedAt,
      DateTime.utc(2026, 11, 5),
    );
  });

  test('삭제는 문서를 남기되 목록에서는 숨긴다', () async {
    await repository.save(migrationTodo('one'));
    await repository.delete('one');
    expect(await repository.getAll(), isEmpty);
    expect(store.documents['one']!.data['deleted'], isTrue);
    expect(store.documents['one']!.data['deleteToken'], isNotEmpty);
  });

  test('다른 기기의 수정은 더 최신이어도 삭제 기록을 복구하지 못한다', () async {
    await repository.delete('one');
    final otherDevice = FirestoreTodoRepository(store);
    await expectLater(
      otherDevice.save(migrationTodo('one', version: 28)),
      throwsStateError,
    );
    expect(await repository.getAll(), isEmpty);
  });

  test('같은 세션의 삭제 실행 취소는 토큰을 지정하고 기존 ID를 복구한다', () async {
    final todo = migrationTodo('one');
    await repository.save(todo);
    await repository.delete(todo.id);
    final token = store.documents[todo.id]!.data['deleteToken'];
    await repository.save(todo);
    expect(store.documents[todo.id]!.data['restoredFrom'], token);
    expect((await repository.getAll()).single.id, todo.id);
  });

  test('실행 취소 전에 다른 삭제가 발생하면 이전 토큰으로 복구하지 않는다', () async {
    final todo = migrationTodo('one');
    await repository.delete(todo.id);
    await FirestoreTodoRepository(store).delete(todo.id);
    await expectLater(repository.save(todo), throwsStateError);
    expect(await repository.getAll(), isEmpty);
  });
}
