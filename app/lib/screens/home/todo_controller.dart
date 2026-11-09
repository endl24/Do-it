import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/todo.dart';
import '../../services/live_todo_repository.dart';
import '../../services/todo_repository.dart';

enum TodoFilter { all, incomplete, completed }

class TodoController extends ChangeNotifier {
  TodoController(this._repository);

  final TodoRepository _repository;
  final List<Todo> _todos = <Todo>[];
  StreamSubscription<TodoSyncSnapshot>? _subscription;
  Future<void>? _loading;
  bool _isDisposed = false;
  int _snapshotVersion = 0;
  int? syncPendingCount;

  bool get isRemote => _repository is LiveTodoRepository;

  bool isLoading = true;

  /// 목록을 불러오지 못했을 때의 메시지. 화면 전체를 오류 상태로 바꾼다.
  String? loadErrorMessage;

  /// 마지막 추가·수정·삭제가 실패했을 때의 메시지. 다음 작업을 시작하면 지운다.
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

  // 중복 조회를 합치고 실시간 구독은 컨트롤러당 하나만 유지한다.
  Future<void> load({bool fromServer = false}) {
    return _loading ??= _load(fromServer: fromServer).whenComplete(() {
      _loading = null;
    });
  }

  // 늦게 끝난 조회가 더 최근에 도착한 실시간 목록을 덮어쓰지 않도록 한다.
  Future<void> _load({required bool fromServer}) async {
    _watch();
    final version = _snapshotVersion;
    isLoading = true;
    loadErrorMessage = null;
    errorMessage = null;
    notifyListeners();
    try {
      final repository = _repository;
      final todos = fromServer && repository is LiveTodoRepository
          ? await (repository as LiveTodoRepository).refreshFromServer()
          : await repository.getAll();
      if (_isDisposed) return;
      if (version == _snapshotVersion) _replace(todos);
    } catch (_) {
      if (_isDisposed) return;
      if (fromServer) {
        errorMessage = '서버에서 새로고침하지 못했습니다. 연결 상태를 확인해 주세요.';
      } else if (version == _snapshotVersion) {
        loadErrorMessage = '저장된 할 일을 불러오지 못했습니다. 다시 시도해 주세요.';
      }
    } finally {
      if (!_isDisposed) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  // 다른 기기의 변경과 메타데이터 변경을 같은 목록에 반영한다.
  void _watch() {
    final repository = _repository;
    if (repository is! LiveTodoRepository || _subscription != null) return;
    _subscription = (repository as LiveTodoRepository).watchTodos().listen(
      (snapshot) {
        if (_isDisposed) return;
        _snapshotVersion++;
        syncPendingCount = snapshot.pendingCount;
        _replace(snapshot.todos);
        isLoading = false;
        loadErrorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        if (_isDisposed) return;
        loadErrorMessage = '서버 변경을 불러오지 못했습니다. 다시 시도해 주세요.';
        isLoading = false;
        notifyListeners();
        unawaited(_subscription?.cancel());
        _subscription = null;
      },
    );
  }

  // 목록 교체 후 기존 정렬 규칙을 그대로 적용한다.
  void _replace(List<Todo> todos) {
    _todos
      ..clear()
      ..addAll(todos);
    _sort();
  }

  // 계정 전환이나 화면 종료 후 이전 구독이 화면을 갱신하지 않도록 정리한다.
  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void setFilter(TodoFilter nextFilter) {
    if (filter == nextFilter) return;
    filter = nextFilter;
    notifyListeners();
  }

  Future<bool> add(Todo todo) async {
    errorMessage = null;
    _todos.insert(0, todo);
    _sort();
    notifyListeners();
    return _persist(todo, rollback: () => _todos.remove(todo));
  }

  Future<bool> update(Todo todo) async {
    final index = _todos.indexWhere((item) => item.id == todo.id);
    if (index < 0) return false;
    errorMessage = null;
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
    final version = _snapshotVersion;
    errorMessage = null;
    _todos.removeAt(index);
    notifyListeners();
    try {
      await _repository.delete(todo.id);
      return true;
    } catch (_) {
      if (_isDisposed) return false;
      if (version == _snapshotVersion) _todos.insert(index, todo);
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
    final version = _snapshotVersion;
    try {
      await _repository.save(todo);
      return true;
    } catch (_) {
      if (_isDisposed) return false;
      if (version == _snapshotVersion) rollback();
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
