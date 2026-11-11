import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/retry_backoff.dart';
import '../../models/todo.dart';
import '../../services/device_memo_scanner.dart';
import '../../services/device_permission_service.dart';
import '../../services/memo_scanner.dart';
import '../../services/permission_service.dart';
import '../../services/sqlite_todo_repository.dart';
import '../../services/todo_repository.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_placeholder.dart';
import '../../widgets/error_retry_card.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/page_header.dart';
import '../../widgets/skeleton_list.dart';
import '../../widgets/sync_status_badge.dart';
import '../../widgets/todo_card.dart';
import '../home/todo_controller.dart';
import '../home/widgets/empty_todo_view.dart';
import '../photo_import/memo_capture_screen.dart';
import '../todo_detail/todo_detail_screen.dart';
import '../todo_quadrant/todo_quadrant_view.dart';
import 'todo_form_sheet.dart';
import 'widgets/todo_view_switcher.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({
    super.key,
    this.repository,
    this.isOnline = true,
    this.memoScanner,
    this.permissionService,
  });

  final TodoRepository? repository;

  /// 사진에서 가져오기(06)에 쓸 카메라·글자 인식. 없으면 기기 구현체를 쓴다.
  final MemoScanner? memoScanner;

  /// 06 진입 전 카메라 권한 확인(09). 없으면 기기 구현체를 쓴다.
  final PermissionService? permissionService;

  /// `false`면 목록 위에 오프라인 배너를 띄운다 (E1).
  final bool isOnline;

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  late final TodoController _controller;
  late final _retryBackoff = RetryBackoff(onRetry: _load);
  var _viewMode = TodoViewMode.list;
  bool _wasLoading = false;
  String? _lastLoadError;

  bool get _isQuadrantMode => _viewMode == TodoViewMode.quadrant;

  @override
  void initState() {
    super.initState();
    _controller = TodoController(widget.repository ?? SqliteTodoRepository());
    _controller.addListener(_trackLoadResult);
    _load();
  }

  @override
  void dispose() {
    _retryBackoff.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // 직접 다시 시도한 사이에 예약된 재시도가 겹쳐 두 번 불러오지 않게 한다.
    _retryBackoff.cancel();
    await _controller.load();
  }

  // 조회와 실시간 구독의 실패 모두 기존 자동 재시도 규칙으로 처리한다.
  void _trackLoadResult() {
    final error = _controller.loadErrorMessage;
    if (!_controller.isLoading && error == null) {
      _retryBackoff.recordSuccess();
    } else if (error != null &&
        (_wasLoading || error != _lastLoadError) &&
        widget.isOnline) {
      _retryBackoff.recordFailure();
    }
    _wasLoading = _controller.isLoading;
    _lastLoadError = error;
  }

  // 수동 새로고침은 서버 응답을 요청하고 실패해도 현재 목록을 보존한다.
  Future<void> _refresh() async {
    _retryBackoff.cancel();
    await _controller.load(fromServer: true);
    if (!mounted) return;
    if (_controller.errorMessage != null) {
      _showResult(false, successMessage: '');
    }
  }

  // 연결이 복구되면 서버 목록을 다시 받아 캐시와 화면을 맞춘다.
  @override
  void didUpdateWidget(covariant TodoListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isOnline) _retryBackoff.cancel();
    if (!oldWidget.isOnline && widget.isOnline) _refresh();
  }

  /// 서버와 동기화하는 할 일이 하나라도 있을 때만 동기화 배지를 보여준다.
  /// 모두 단말에만 있으면 '동기화 완료'가 사실이 아니기 때문이다.
  Widget? _buildSyncBadge() {
    final todos = _controller.todos;
    if (_controller.isLoading ||
        (!_controller.isRemote &&
            todos.every(
              (todo) => todo.syncStatus == TodoSyncStatus.localOnly,
            ))) {
      return null;
    }
    final pendingCount =
        _controller.syncPendingCount ??
        todos
            .where(
              (todo) =>
                  todo.syncStatus == TodoSyncStatus.pending ||
                  todo.syncStatus == TodoSyncStatus.failed,
            )
            .length;
    return SyncStatusBadge(pendingCount: pendingCount);
  }

  /// 동기화 배지와 사진에서 가져오기 버튼. 02에서는 빈 상태의 버튼이 진입을 맡는다.
  Widget? _buildHeaderActions() {
    final badge = _buildSyncBadge();
    if (_isEmptyState) return badge;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?badge,
        IconButton(
          onPressed: _openPhotoImport,
          tooltip: '사진에서 가져오기',
          icon: const Icon(Icons.photo_camera_outlined),
        ),
      ],
    );
  }

  /// 불러오기까지 끝났는데 할 일이 한 건도 없는 02 빈 상태인지.
  /// 필터로 가려져 안 보이는 경우는 해당하지 않는다.
  /// 사분면 보기에서는 전환 세그먼트를 유지하도록 네 영역의 '아직 없음'으로 보여준다.
  bool get _isEmptyState =>
      !_isQuadrantMode &&
      !_controller.isLoading &&
      _controller.loadErrorMessage == null &&
      _controller.todos.isEmpty;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // 02에서는 빈 상태의 두 버튼이 추가 진입을 맡으므로 필터·요약·FAB를 숨긴다.
        final isEmptyState = _isEmptyState;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                PageHeader(
                  title: _isQuadrantMode ? '사분면' : '할 일',
                  subtitle: isEmptyState
                      ? null
                      : _controller.isLoading
                      ? '저장된 할 일을 불러오는 중입니다'
                      : _isQuadrantMode
                      ? '중요도와 긴급도에 따라 할 일을 나눠 봅니다'
                      : '남은 할 일 ${_controller.incompleteCount}개',
                  trailing: _buildHeaderActions(),
                ),
                if (!isEmptyState)
                  TodoViewSwitcher(
                    selected: _viewMode,
                    onChanged: (mode) => setState(() => _viewMode = mode),
                  ),
                if (!isEmptyState && !_isQuadrantMode) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _FilterBar(
                    selected: _controller.filter,
                    onSelected: _controller.setFilter,
                  ),
                ],
                if (!widget.isOnline)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.sm,
                      AppSpacing.screenHorizontal,
                      0,
                    ),
                    child: OfflineBanner(),
                  ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
          floatingActionButton: isEmptyState || _isQuadrantMode
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('할 일 추가'),
                ),
        );
      },
    );
  }

  Widget _buildBody() {
    const statusPadding = EdgeInsets.fromLTRB(
      AppSpacing.screenHorizontal,
      AppSpacing.md,
      AppSpacing.screenHorizontal,
      0,
    );
    if (_controller.isLoading) {
      return const SingleChildScrollView(
        padding: statusPadding,
        child: SkeletonList(),
      );
    }

    final loadErrorMessage = _controller.loadErrorMessage;
    if (loadErrorMessage != null) {
      return SingleChildScrollView(
        padding: statusPadding,
        child: ErrorRetryCard(
          title: '할 일을 불러오지 못했습니다',
          message: loadErrorMessage,
          isSlowedDown: _retryBackoff.isSlowedDown,
          onRetry: _load,
        ),
      );
    }

    if (_isQuadrantMode) {
      return TodoQuadrantView(
        todos: _controller.todos,
        onOpenDetail: _openDetail,
        onMove: _move,
      );
    }

    if (_controller.todos.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: EmptyTodoView(onAdd: _addFirstTodo, onPhoto: _openPhotoImport),
      );
    }

    final todos = _controller.visibleTodos;
    if (todos.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.lg,
                  AppSpacing.screenHorizontal,
                  AppSpacing.xxl + AppSize.fab,
                ),
                child: Center(
                  child: EmptyPlaceholder.filtered(
                    onResetFilter: () => _controller.setFilter(TodoFilter.all),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.md,
          AppSpacing.screenHorizontal,
          AppSpacing.xxl + AppSize.fab,
        ),
        itemCount: todos.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.listGap),
        itemBuilder: (context, index) {
          final todo = todos[index];
          return TodoCard(
            key: ValueKey(todo.id),
            title: todo.title,
            isImportant: todo.isImportant,
            isUrgent: todo.isUrgent,
            isDone: todo.isCompleted,
            meta: _dueLabel(todo.dueDate),
            isMetaEmphasized: _isDueToday(todo.dueDate),
            isPendingSync: todo.syncStatus == TodoSyncStatus.pending,
            onDoneChanged: (_) => _toggle(todo),
            onTap: () => _openDetail(todo),
          );
        },
      ),
    );
  }

  /// 02에서는 필터가 보이지 않으므로, '완료' 필터에서 마지막 할 일을 지운 뒤 새로 추가해도
  /// 새 할 일이 필터에 가려지지 않게 전체로 되돌린다.
  void _addFirstTodo() {
    _controller.setFilter(TodoFilter.all);
    _openForm();
  }

  /// 06 메모 촬영을 연다. 카메라 권한이 없으면 09 권한 안내를 먼저 띄운다(A14 A18).
  Future<void> _openPhotoImport() async {
    var addedCount = 0;
    await MemoCaptureScreen.open(
      context,
      permissionService:
          widget.permissionService ?? const DevicePermissionService(),
      scanner: widget.memoScanner ?? DeviceMemoScanner(),
      onManualEntry: _openManualEntryFromPhoto,
      onRegister: (titles) async {
        addedCount = await _addPhotoTodos(titles);
      },
    );
    if (!mounted || addedCount == 0) return;
    _showResult(true, successMessage: '할 일 $addedCount개를 추가했습니다.');
  }

  /// 07에서 고른 제목을 사진 출처 할 일로 저장한다. 하나라도 실패하면 예외를 던져 07이 안내한다.
  Future<int> _addPhotoTodos(List<String> titles) async {
    var added = 0;
    final now = DateTime.now();
    for (final (index, title) in titles.indexed) {
      // 목록은 최근 만든 순서라, 메모 첫 줄이 맨 위에 오도록 뒷줄일수록 조금 앞선 시각을 준다.
      final createdAt = now.subtract(Duration(microseconds: index));
      final succeeded = await _controller.add(
        Todo(
          // 한꺼번에 만들어 시각이 겹쳐도 ID가 같아지지 않게 순번을 붙인다.
          id: '${now.microsecondsSinceEpoch}_$index',
          title: title.trim(),
          // 03 등록 폼의 기본값과 같다.
          importance: TodoImportance.important,
          urgency: TodoUrgency.urgent,
          isCompleted: false,
          reminderEnabled: false,
          source: TodoSource.photo,
          syncStatus: TodoSyncStatus.localOnly,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      if (!succeeded) {
        throw StateError(_controller.errorMessage ?? '할 일을 저장하지 못했습니다.');
      }
      added++;
    }
    return added;
  }

  /// 06·08의 [직접 입력]: 사진 흐름을 모두 닫고 03 등록 시트를 연다.
  void _openManualEntryFromPhoto() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _openForm();
  }

  Future<void> _openForm([Todo? todo]) async {
    final result = await showTodoFormSheet(context, todo: todo);
    if (!mounted || result == null) return;

    if (result.shouldDelete) {
      await _delete(todo!);
      return;
    }

    final savedTodo = result.todo!;
    final succeeded = todo == null
        ? await _controller.add(savedTodo)
        : await _controller.update(savedTodo);
    if (!mounted) return;
    _showResult(
      succeeded,
      successMessage: todo == null ? '할 일을 추가했습니다.' : '할 일을 수정했습니다.',
    );
  }

  Future<void> _openDetail(Todo todo) async {
    final result = await Navigator.of(context).push<TodoDetailResult>(
      MaterialPageRoute(
        builder: (_) => TodoDetailScreen(
          todo: todo,
          onUpdate: _controller.update,
          onDelete: _controller.remove,
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result.action == TodoDetailAction.deleted) {
      showUndoSnackBar(
        context,
        message: '할 일을 삭제했습니다',
        onUndo: () => _restore(result.todo),
      );
      return;
    }
    _showResult(
      true,
      successMessage: result.todo.isCompleted ? '할 일을 완료했습니다.' : '미완료로 변경했습니다.',
    );
  }

  Future<void> _move(Todo todo, TodoQuadrant target) async {
    final succeeded = await _controller.move(todo, target);
    if (!mounted || succeeded) return;
    _showResult(false, successMessage: '');
  }

  Future<void> _toggle(Todo todo) async {
    final succeeded = await _controller.toggle(todo);
    if (!mounted || succeeded) return;
    _showResult(false, successMessage: '');
  }

  Future<void> _delete(Todo todo) async {
    final confirmed = await showDeleteTodoDialog(context, todo.title);
    if (!mounted || !confirmed) return;
    final succeeded = await _controller.remove(todo);
    if (!mounted) return;
    if (!succeeded) {
      _showResult(false, successMessage: '');
      return;
    }
    // TODO(강두이): 알림 예약 서비스가 생기면 삭제할 때 예약 알림을 취소하고, 실행 취소하면 다시 예약한다 (A30).
    showUndoSnackBar(
      context,
      message: '할 일을 삭제했습니다',
      onUndo: () => _restore(todo),
    );
  }

  Future<void> _restore(Todo todo) async {
    final succeeded = await _controller.add(todo);
    if (!mounted || succeeded) return;
    _showResult(false, successMessage: '');
  }

  void _showResult(bool succeeded, {required String successMessage}) {
    final message = succeeded ? successMessage : _controller.errorMessage;
    if (message == null || message.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static bool _isDueToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  static String? _dueLabel(DateTime? date) {
    if (date == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(date.year, date.month, date.day);
    if (due == today) return '오늘 마감';
    if (due == today.add(const Duration(days: 1))) return '내일';
    return '${date.month}월 ${date.day}일';
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});

  final TodoFilter selected;
  final ValueChanged<TodoFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        child: Row(
          children: [
            _FilterChip(
              label: '전체',
              value: TodoFilter.all,
              selected: selected,
              onSelected: onSelected,
            ),
            const SizedBox(width: AppSpacing.xs),
            _FilterChip(
              label: '미완료',
              value: TodoFilter.incomplete,
              selected: selected,
              onSelected: onSelected,
            ),
            const SizedBox(width: AppSpacing.xs),
            _FilterChip(
              label: '완료',
              value: TodoFilter.completed,
              selected: selected,
              onSelected: onSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final TodoFilter value;
  final TodoFilter selected;
  final ValueChanged<TodoFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: value == selected,
      onSelected: (_) => onSelected(value),
    );
  }
}
