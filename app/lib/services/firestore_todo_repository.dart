import '../models/todo.dart';
import 'firestore_todo_store.dart';
import 'todo_repository.dart';

// 계정별 서버 할 일을 조회·저장하고 삭제 기록으로 오래된 수정의 복원을 막는다.
class FirestoreTodoRepository implements TodoRepository {
  FirestoreTodoRepository(this.store, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final FirestoreTodoStore store;
  final DateTime Function() _clock;
  final Map<String, String> _undoTokens = {};

  // 삭제 문서를 숨기고 SDK의 대기·실패 상태를 공통 Todo 모델에 전달한다.
  @override
  Future<List<Todo>> getAll() async {
    final documents = await store.readAll();
    return [
      for (final document in documents)
        if (document.data['deleted'] != true)
          Todo.fromMap({
            ...document.data,
            'id': document.id,
            'remote_id': document.id,
            'sync_status': store.hasWriteFailure(document.id)
                ? TodoSyncStatus.failed.name
                : document.isPending
                ? TodoSyncStatus.pending.name
                : TodoSyncStatus.synced.name,
          }),
    ];
  }

  // updatedAt을 유지해 수정 순서를 비교한다. 명시적 실행 취소만 삭제를 복구할 수 있다.
  @override
  Future<void> save(Todo todo) async {
    final cached = await store.readCached(todo.id);
    final data = cached?.data;
    final isDeleted = data?['deleted'] == true;
    final undoToken = _undoTokens[todo.id];
    if (isDeleted && (undoToken == null || undoToken != data?['deleteToken'])) {
      throw StateError('다른 변경으로 삭제된 할 일은 수정할 수 없습니다.');
    }
    final previousUpdated = data?['updated_at'] as String?;
    final previousTime = previousUpdated == null
        ? null
        : DateTime.parse(previousUpdated);
    if (!isDeleted &&
        previousTime != null &&
        todo.updatedAt.isBefore(previousTime)) {
      throw StateError('더 최근에 수정된 할 일을 다시 불러와 주세요.');
    }
    final restoredTime = isDeleted
        ? _later(_clock(), previousTime?.add(const Duration(microseconds: 1)))
        : todo.updatedAt;
    await store.enqueue(todo.id, {
      ...todo.toMap(),
      'remote_id': todo.id,
      'sync_status': TodoSyncStatus.pending.name,
      'updated_at': restoredTime.toUtc().toIso8601String(),
      'deleted': false,
      'operationId': store.newOperationId(),
      if (isDeleted) 'restoredFrom': undoToken,
    });
    _undoTokens.remove(todo.id);
  }

  // 물리 삭제 대신 삭제 토큰을 남긴다. 이후의 일반 수정은 서버 규칙에서도 차단한다.
  @override
  Future<void> delete(String id) async {
    final token = store.newOperationId();
    await store.enqueue(id, {
      'id': id,
      'deleted': true,
      'deleteToken': token,
      'operationId': token,
      'updated_at': _clock().toUtc().toIso8601String(),
    });
    _undoTokens[id] = token;
  }

  // 복구 시각이 삭제 시각보다 앞서지 않도록 보정한다.
  DateTime _later(DateTime first, DateTime? second) =>
      second != null && second.isAfter(first) ? second : first;
}
