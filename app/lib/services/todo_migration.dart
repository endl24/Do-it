import 'dart:convert';

import '../models/todo.dart';
import 'firestore_todo_repository.dart';
import 'todo_repository.dart';

// 이관 대상의 스냅샷·소유 계정·서버 저장 완료 여부를 보관한다.
class TodoMigrationRecord {
  TodoMigrationRecord({
    required this.uid,
    required Iterable<Todo> todos,
    this.isCompleted = false,
  }) : todos = List.unmodifiable(todos);

  final String uid;
  final List<Todo> todos;
  final bool isCompleted;
}

// 이관 중 앱이 종료돼도 같은 스냅샷과 계정으로 재개할 수 있도록 기록한다.
abstract interface class TodoMigrationJournal {
  Future<TodoMigrationRecord?> read();
  Future<void> write(TodoMigrationRecord record);
}

// 인증 계정별 저장소 전환과 SQLite 원본의 일회성 이관을 순서대로 처리한다.
class TodoRepositorySession {
  TodoRepositorySession({
    required this.local,
    required this.journal,
    required this.remoteFor,
    required this.currentUid,
  });

  final TodoRepository local;
  final TodoMigrationJournal journal;
  final FirestoreTodoRepository Function(String uid) remoteFor;
  final String? Function() currentUid;
  Future<void> _tail = Future.value();

  // 계정 변경 요청을 직렬화해 두 계정의 이관이 같은 SQLite 원본을 동시에 쓰지 않게 한다.
  Future<TodoRepository> forAccount(String? uid) {
    final result = _tail.then((_) => _prepare(uid));
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  // 서버 저장 확인 전에는 원본을 남기고, 완료 표시를 먼저 기록한 후 원본을 정리한다.
  Future<TodoRepository> _prepare(String? uid) async {
    _ensureAccount(uid);
    var record = await journal.read();
    if (record != null && record.isCompleted) {
      await _cleanSource(record);
      await journal.write(
        TodoMigrationRecord(
          uid: record.uid,
          todos: const [],
          isCompleted: true,
        ),
      );
    }
    _ensureAccount(uid);
    if (uid == null) return local;
    final remote = remoteFor(uid);
    if (record != null && !record.isCompleted && record.uid != uid) {
      throw StateError('이전 계정의 이관이 완료되지 않았습니다. 이전 계정으로 로그인해 이관을 마쳐 주세요.');
    }
    if (record == null || record.isCompleted) {
      record = TodoMigrationRecord(uid: uid, todos: await local.getAll());
      _ensureAccount(uid);
      await journal.write(record);
    }
    for (final todo in record.todos) {
      _ensureAccount(uid);
      await remote.store.importTodo(todo);
    }
    _ensureAccount(uid);
    final completed = TodoMigrationRecord(
      uid: uid,
      todos: record.todos,
      isCompleted: true,
    );
    await journal.write(completed);
    await _cleanSource(completed);
    await journal.write(
      TodoMigrationRecord(uid: uid, todos: const [], isCompleted: true),
    );
    _ensureAccount(uid);
    return remote;
  }

  // 이관 후에도 원본이 스냅샷과 같을 때만 지운다. 그 사이 수정된 데이터는 보존한다.
  Future<void> _cleanSource(TodoMigrationRecord record) async {
    final current = {for (final todo in await local.getAll()) todo.id: todo};
    for (final original in record.todos) {
      final existing = current[original.id];
      if (existing != null &&
          jsonEncode(existing.toMap()) == jsonEncode(original.toMap())) {
        await local.delete(original.id);
      }
    }
  }

  // 비동기 작업 도중 로그아웃하거나 계정이 바뀌면 이전 계정의 작업을 중단한다.
  void _ensureAccount(String? uid) {
    if (currentUid() != uid) throw StateError('계정이 변경되어 저장소 전환을 중단했습니다.');
  }
}
