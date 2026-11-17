import '../models/todo.dart';

/// Firestore 문서의 내용과 아직 서버에 반영되지 않은 쓰기 상태를 보관한다.
class RemoteTodoDocument {
  /// 문서 ID [id], 내용 [data], 서버 반영 대기 여부 [isPending]으로 문서를 만든다.
  const RemoteTodoDocument({
    required this.id,
    required this.data,
    this.isPending = false,
  });

  final String id;
  final Map<String, Object?> data;
  final bool isPending;
}

/// Firebase SDK와 저장소 로직을 분리해 오프라인 쓰기·이관을 독립적으로 검증한다.
abstract interface class FirestoreTodoStore {
  /// 서버가 늦거나 연결이 없으면 캐시에서라도 계정의 할 일 문서를 모두 읽어 온다.
  Future<List<RemoteTodoDocument>> readAll();

  /// 캐시를 쓰지 않고 서버에서 계정의 할 일 문서를 모두 읽어 온다.
  Future<List<RemoteTodoDocument>> readServer();

  /// 할 일 문서가 바뀌거나 쓰기 대기·실패 상태가 바뀔 때마다 전체 문서 목록을 보낸다.
  Stream<List<RemoteTodoDocument>> watchAll();

  /// [id] 문서를 기기 캐시에서만 읽는다. 캐시에 없으면 null을 돌려준다.
  Future<RemoteTodoDocument?> readCached(String id);

  /// SDK가 로컬 쓰기를 받아들이면 반환한다. 서버 확인까지 기다리지 않는다.
  Future<void> enqueue(String id, Map<String, Object?> data);

  /// 서버 트랜잭션으로 같은 ID를 이관한다. 삭제·더 최신 서버 수정은 보존한다.
  Future<void> importTodo(Todo todo);

  /// [id] 할 일의 마지막 쓰기를 서버가 거절했는지 돌려준다.
  bool hasWriteFailure(String id);

  /// 새 쓰기 작업을 구분할 작업 ID를 만든다.
  String newOperationId();
}
