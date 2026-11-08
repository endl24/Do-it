import 'dart:async';

import 'package:do_it/models/todo.dart';
import 'package:do_it/services/firestore_todo_store.dart';
import 'package:do_it/services/todo_migration.dart';

// SDK 없이 문서·오프라인 대기·이관 실패를 재현하는 저장소 대역이다.
class FakeFirestoreTodoStore implements FirestoreTodoStore {
  final documents = <String, RemoteTodoDocument>{};
  final failures = <String>{};
  final importedIds = <String>[];
  bool isOnline = true;
  int? failImportNumber;
  Completer<void>? importGate;
  int _operation = 0;

  @override
  Future<List<RemoteTodoDocument>> readAll() async => documents.values.toList();

  @override
  Future<RemoteTodoDocument?> readCached(String id) async => documents[id];

  // 캐시 수락과 서버 충돌 판정을 분리해 저장소의 상태 변환을 검사한다.
  @override
  Future<void> enqueue(String id, Map<String, Object?> data) async {
    documents[id] = RemoteTodoDocument(
      id: id,
      data: Map.of(data),
      isPending: !isOnline,
    );
  }

  // 실서버 트랜잭션 대신 최신 수정·삭제 보존과 중간 실패를 재현한다.
  @override
  Future<void> importTodo(Todo todo) async {
    importedIds.add(todo.id);
    if (importGate != null) await importGate!.future;
    if (!isOnline || importedIds.length == failImportNumber) {
      throw StateError('이관 실패');
    }
    final old = documents[todo.id]?.data;
    if (old?['deleted'] == true) return;
    if (old != null &&
        !todo.updatedAt.isAfter(DateTime.parse(old['updated_at']! as String))) {
      return;
    }
    documents[todo.id] = RemoteTodoDocument(
      id: todo.id,
      data: {...todo.toMap(), 'deleted': false},
    );
  }

  @override
  bool hasWriteFailure(String id) => failures.contains(id);

  @override
  String newOperationId() => 'operation-${++_operation}';
}

// 재시작한 세션에 같은 기록을 넘겨 이관 재개를 검증한다.
class MemoryMigrationJournal implements TodoMigrationJournal {
  TodoMigrationRecord? record;
  bool failCompletedWrite = false;

  @override
  Future<TodoMigrationRecord?> read() async => record;

  @override
  Future<void> write(TodoMigrationRecord value) async {
    if (failCompletedWrite && value.isCompleted) throw StateError('완료 기록 실패');
    record = value;
  }
}

// 시각·ID가 고정된 할 일로 이관과 충돌 테스트를 재현한다.
Todo migrationTodo(String id, {int version = 1, String title = '이관할 할 일'}) =>
    Todo(
      id: id,
      title: title,
      importance: TodoImportance.important,
      urgency: TodoUrgency.notUrgent,
      isCompleted: false,
      reminderEnabled: true,
      source: TodoSource.manual,
      syncStatus: TodoSyncStatus.localOnly,
      dueDate: DateTime.utc(2026, 12, 1),
      createdAt: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 11, version),
    );
