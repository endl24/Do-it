import '../models/todo.dart';

// Firestore 문서의 내용과 아직 서버에 반영되지 않은 쓰기 상태를 보관한다.
class RemoteTodoDocument {
  const RemoteTodoDocument({
    required this.id,
    required this.data,
    this.isPending = false,
  });

  final String id;
  final Map<String, Object?> data;
  final bool isPending;
}

// Firebase SDK와 저장소 로직을 분리해 오프라인 쓰기·이관을 독립적으로 검증한다.
abstract interface class FirestoreTodoStore {
  Future<List<RemoteTodoDocument>> readAll();
  Future<RemoteTodoDocument?> readCached(String id);

  // SDK가 로컬 쓰기를 받아들이면 반환한다. 서버 확인까지 기다리지 않는다.
  Future<void> enqueue(String id, Map<String, Object?> data);

  // 서버 트랜잭션으로 같은 ID를 이관한다. 삭제·더 최신 서버 수정은 보존한다.
  Future<void> importTodo(Todo todo);

  bool hasWriteFailure(String id);
  String newOperationId();
}
