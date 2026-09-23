import '../models/todo.dart';

abstract interface class TodoRepository {
  Future<List<Todo>> getAll();

  Future<void> save(Todo todo);

  Future<void> delete(String id);
}

class InMemoryTodoRepository implements TodoRepository {
  InMemoryTodoRepository([Iterable<Todo> initialTodos = const <Todo>[]])
      : _todos = <String, Todo>{
          for (final todo in initialTodos) todo.id: todo,
        };

  final Map<String, Todo> _todos;

  @override
  Future<List<Todo>> getAll() async => _todos.values.toList();

  @override
  Future<void> save(Todo todo) async {
    _todos[todo.id] = todo;
  }

  @override
  Future<void> delete(String id) async {
    _todos.remove(id);
  }
}
