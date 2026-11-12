import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/todo.dart';
import '../../services/live_todo_repository.dart';
import '../../services/todo_repository.dart';

/// 할 일 목록에 적용할 완료 상태 필터를 나타낸다.
enum TodoFilter { all, incomplete, completed }

/// 저장소의 할 일 목록과 조회·변경 상태를 화면에 전달한다.
class TodoController extends ChangeNotifier {
  /// 사용할 할 일 저장소를 받아 컨트롤러를 만든다.
  TodoController(this._repository);

  final TodoRepository _repository;
  final List<Todo> _todos = <Todo>[];
  StreamSubscription<TodoSyncSnapshot>? _subscription;
  Future<void>? _loading;
  bool _isDisposed = false;
  int _snapshotVersion = 0;
  int? syncPendingCount;

  /// 실시간 원격 저장소를 사용하고 있는지 알려준다.
  bool get isRemote => _repository is LiveTodoRepository;

  bool isLoading = true;

  /// 목록을 불러오지 못했을 때의 메시지. 화면 전체를 오류 상태로 바꾼다.
  String? loadErrorMessage;

  /// 마지막 추가·수정·삭제가 실패했을 때의 메시지. 다음 작업을 시작하면 지운다.
  String? errorMessage;
  TodoFilter filter = TodoFilter.all;

  /// 외부에서 목록을 바꾸지 못하도록 읽기 전용 할 일 목록을 돌려준다.
  List<Todo> get todos => List<Todo>.unmodifiable(_todos);

  /// 현재 필터에 해당하는 할 일만 모아 돌려준다.
  List<Todo> get visibleTodos {
    return switch (filter) {
      TodoFilter.all => todos,
      TodoFilter.incomplete =>
        todos.where((todo) => !todo.isCompleted).toList(growable: false),
      TodoFilter.completed =>
        todos.where((todo) => todo.isCompleted).toList(growable: false),
    };
  }

  /// 완료하지 않은 할 일의 수를 돌려준다.
  int get incompleteCount => _todos.where((todo) => !todo.isCompleted).length;

  /// 중복 조회를 하나로 합치고 필요하면 서버에서 목록을 새로 요청한다.
  Future<void> load({bool fromServer = false}) {
    return _loading ??= _load(fromServer: fromServer).whenComplete(() {
      _loading = null;
    });
  }

  /// 저장소 목록을 불러오되 늦은 응답이 최신 실시간 목록을 덮지 않게 한다.
  Future<void> _load({required bool fromServer}) async {
    _watch();
    final version = _snapshotVersion;
    // 기존 목록이 있는 서버 새로고침은 목록·배지·요약을 유지한다.
    if (!fromServer || _todos.isEmpty) isLoading = true;
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

  /// 다른 기기의 변경과 동기화 메타데이터를 실시간 목록에 반영한다.
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

  /// 현재 목록을 [todos]로 교체하고 화면 표시 순서로 정렬한다.
  void _replace(List<Todo> todos) {
    _todos
      ..clear()
      ..addAll(todos);
    _sort();
  }

  /// 실시간 구독을 취소해 화면 종료 뒤 목록이 갱신되지 않도록 한다.
  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  /// 목록에 적용할 필터를 [nextFilter]로 바꾸고 화면에 알린다.
  void setFilter(TodoFilter nextFilter) {
    if (filter == nextFilter) return;
    filter = nextFilter;
    notifyListeners();
  }

  /// [todo]를 목록에 먼저 추가한 뒤 저장하며 실패하면 되돌린다.
  Future<bool> add(Todo todo) async {
    errorMessage = null;
    _todos.insert(0, todo);
    _sort();
    notifyListeners();
    return _persist(todo, rollback: () => _todos.remove(todo));
  }

  /// 같은 식별자의 할 일을 [todo]로 바꾼 뒤 저장하며 실패하면 되돌린다.
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

  /// [todo]의 완료 상태를 반대로 바꿔 저장한다.
  Future<bool> toggle(Todo todo) {
    return update(todo.copyWith(isCompleted: !todo.isCompleted));
  }

  /// [todo]를 [target] 사분면으로 옮겨 저장한다.
  Future<bool> move(Todo todo, TodoQuadrant target) {
    if (todo.quadrant == target) return Future<bool>.value(true);
    return update(todo.moveTo(target));
  }

  /// [todo]를 목록과 저장소에서 삭제하며 실패하면 원래 위치로 되돌린다.
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

  /// [date]에 마감하는 할 일만 모아 돌려준다.
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

  /// [todo]를 저장하고 실패하면 [rollback]으로 화면 상태를 복구한다.
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

  /// 미완료, 가까운 마감일, 최근 생성 순서로 목록을 정렬한다.
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
