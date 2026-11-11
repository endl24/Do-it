import '../models/todo.dart';

/// 저장 방식과 관계없이 할 일을 조회하고 변경하는 계약을 정의한다.
abstract interface class TodoRepository {
  /// 저장된 모든 할 일을 돌려준다.
  Future<List<Todo>> getAll();

  /// [todo]를 새로 저장하거나 같은 식별자의 기존 항목을 갱신한다.
  Future<void> save(Todo todo);

  /// [id]와 일치하는 할 일을 삭제한다.
  Future<void> delete(String id);
}

/// 앱 실행 중 메모리에 할 일을 보관하는 저장소다.
class InMemoryTodoRepository implements TodoRepository {
  /// 선택적으로 [initialTodos]를 채운 메모리 저장소를 만든다.
  InMemoryTodoRepository([Iterable<Todo> initialTodos = const <Todo>[]])
    : _todos = <String, Todo>{for (final todo in initialTodos) todo.id: todo};

  final Map<String, Todo> _todos;

  /// 메모리에 저장된 모든 할 일을 돌려준다.
  @override
  Future<List<Todo>> getAll() async => _todos.values.toList();

  /// [todo]를 식별자 기준으로 추가하거나 교체한다.
  @override
  Future<void> save(Todo todo) async {
    _todos[todo.id] = todo;
  }

  /// [id]와 일치하는 할 일을 메모리에서 제거한다.
  @override
  Future<void> delete(String id) async {
    _todos.remove(id);
  }
}
