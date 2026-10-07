import 'package:flutter/foundation.dart';

import '../../models/todo.dart';
import '../../services/todo_repository.dart';

enum TodoFilter { all, incomplete, completed }

class TodoController extends ChangeNotifier {
  TodoController(this._repository);

  final TodoRepository _repository;
  final List<Todo> _todos = <Todo>[];

  bool isLoading = true;
  String? errorMessage;
  TodoFilter filter = TodoFilter.all;

  List<Todo> get todos => List<Todo>.unmodifiable(_todos);

  List<Todo> get visibleTodos {
    return switch (filter) {
      TodoFilter.all => todos,
      TodoFilter.incomplete =>
        todos.where((todo) => !todo.isCompleted).toList(growable: false),
      TodoFilter.completed =>
        todos.where((todo) => todo.isCompleted).toList(growable: false),
    };
  }

  int get incompleteCount => _todos.where((todo) => !todo.isCompleted).length;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      _todos
        ..clear()
        ..addAll(await _repository.getAll());
      _sort();
    } catch (_) {
      errorMessage = '저장된 할 일을 불러오지 못했습니다. 다시 시도해 주세요.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(TodoFilter nextFilter) {
    if (filter == nextFilter) return;
    filter = nextFilter;
    notifyListeners();
  }

  Future<bool> add(Todo todo) async {
    _todos.insert(0, todo);
    _sort();
    notifyListeners();
    return _persist(todo, rollback: () => _todos.remove(todo));
  }

  Future<bool> update(Todo todo) async {
    final index = _todos.indexWhere((item) => item.id == todo.id);
    if (index < 0) return false;
    final previous = _todos[index];
    _todos[index] = todo;
    _sort();
    notifyListeners();
    return _persist(
      todo,
      rollback: () {
        final currentIndex = _todos.indexWhere((item) => item.id == todo.id);
        if (currentIndex >= 0) _todos[currentIndex] = previous;
      },
    );
  }

  Future<bool> toggle(Todo todo) {
    return update(todo.copyWith(isCompleted: !todo.isCompleted));
  }

  Future<bool> move(Todo todo, TodoQuadrant target) {
    if (todo.quadrant == target) return Future<bool>.value(true);
    return update(todo.moveTo(target));
  }

  Future<bool> remove(Todo todo) async {
    final index = _todos.indexOf(todo);
    if (index < 0) return false;
    _todos.removeAt(index);
    notifyListeners();
    try {
      await _repository.delete(todo.id);
      return true;
    } catch (_) {
      _todos.insert(index, todo);
      errorMessage = '할 일을 삭제하지 못했습니다.';
      notifyListeners();
      return false;
    }
  }

  List<Todo> todosFor(DateTime date) {
    return _todos
        .where((todo) {
          final dueDate = todo.dueDate;
          return dueDate != null &&
              dueDate.year == date.year &&
              dueDate.month == date.month &&
              dueDate.day == date.day;
        })
        .toList(growable: false);
  }

  Future<bool> _persist(Todo todo, {required VoidCallback rollback}) async {
    try {
      await _repository.save(todo);
      return true;
    } catch (_) {
      rollback();
      _sort();
      errorMessage = '기기에 저장하지 못했습니다. 저장 공간을 확인해 주세요.';
      notifyListeners();
      return false;
    }
  }

  void _sort() {
    _todos.sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      final aDue = a.dueDate;
      final bDue = b.dueDate;
      if (aDue == null && bDue != null) return 1;
      if (aDue != null && bDue == null) return -1;
      if (aDue != null && bDue != null) {
        final dateOrder = aDue.compareTo(bDue);
        if (dateOrder != 0) return dateOrder;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
  }
}
