import '../models/todo.dart';

// 실시간 목록과 서버 새로고침을 지원하는 저장소의 추가 기능이다.
abstract interface class LiveTodoRepository {
  Stream<TodoSyncSnapshot> watchTodos();
  Future<List<Todo>> refreshFromServer();
}

// 삭제 대기 문서까지 포함한 동기화 건수와 화면에 표시할 목록을 전달한다.
class TodoSyncSnapshot {
  const TodoSyncSnapshot({required this.todos, required this.pendingCount});

  final List<Todo> todos;
  final int pendingCount;
}
