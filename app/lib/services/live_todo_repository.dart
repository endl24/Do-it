import '../models/todo.dart';

/// 실시간 목록과 서버 새로고침을 지원하는 저장소의 추가 기능이다.
abstract interface class LiveTodoRepository {
  /// 할 일 목록과 동기화 대기 수가 바뀔 때마다 새 스냅샷을 보낸다.
  Stream<TodoSyncSnapshot> watchTodos();

  /// 캐시를 쓰지 않고 서버에서 할 일 목록을 다시 받아 온다.
  Future<List<Todo>> refreshFromServer();
}

/// 삭제 대기 문서까지 포함한 동기화 건수와 화면에 표시할 목록을 전달한다.
class TodoSyncSnapshot {
  /// 화면에 보여 줄 할 일 [todos]와 동기화 대기 수 [pendingCount]로 스냅샷을 만든다.
  const TodoSyncSnapshot({required this.todos, required this.pendingCount});

  final List<Todo> todos;
  final int pendingCount;
}
