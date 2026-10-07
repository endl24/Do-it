import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/retry_backoff.dart';
import '../../models/todo.dart';
import '../../services/sqlite_todo_repository.dart';
import '../../services/todo_repository.dart';
import '../../widgets/empty_placeholder.dart';
import '../../widgets/error_retry_card.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/page_header.dart';
import '../../widgets/skeleton_list.dart';
import '../../widgets/sync_status_badge.dart';
import '../../widgets/todo_card.dart';
import '../home/todo_controller.dart';
import 'todo_form_sheet.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key, this.repository, this.isOnline = true});

  final TodoRepository? repository;

  /// `false`면 목록 위에 오프라인 배너를 띄운다 (E1).
  final bool isOnline;

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  late final TodoController _controller;
  late final _retryBackoff = RetryBackoff(onRetry: _load);

  @override
  void initState() {
    super.initState();
    _controller = TodoController(widget.repository ?? SqliteTodoRepository());
    _load();
  }

  @override
  void dispose() {
    _retryBackoff.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _controller.load();
    if (!mounted) return;
    setState(() {
      if (_controller.loadErrorMessage == null) {
        _retryBackoff.recordSuccess();
      } else {
        _retryBackoff.recordFailure();
      }
    });
  }

  /// 서버와 동기화하는 할 일이 하나라도 있을 때만 동기화 배지를 보여준다.
  /// 모두 단말에만 있으면 '동기화 완료'가 사실이 아니기 때문이다.
  Widget? _buildSyncBadge() {
    final todos = _controller.todos;
    if (_controller.isLoading ||
        todos.every((todo) => todo.syncStatus == TodoSyncStatus.localOnly)) {
      return null;
    }
    final pendingCount = todos
        .where(
          (todo) =>
              todo.syncStatus == TodoSyncStatus.pending ||
              todo.syncStatus == TodoSyncStatus.failed,
        )
        .length;
    return SyncStatusBadge(pendingCount: pendingCount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Column(
            children: [
              PageHeader(
                title: '할 일',
                subtitle: _controller.isLoading
                    ? '저장된 할 일을 불러오는 중입니다'
                    : '남은 할 일 ${_controller.incompleteCount}개',
                trailing: _buildSyncBadge(),
              ),
              _FilterBar(
                selected: _controller.filter,
                onSelected: _controller.setFilter,
              ),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('할 일 추가'),
      ),
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

    final todos = _controller.visibleTodos;
    if (todos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.lg,
          AppSpacing.screenHorizontal,
          AppSpacing.xxl + AppSize.fab,
        ),
        child: Center(
          child: _controller.todos.isEmpty
              ? const EmptyPlaceholder(
                  icon: Icons.checklist_rounded,
                  message: '아직 등록한 할 일이 없어요',
                  description: '오른쪽 아래 버튼을 눌러 첫 할 일을 등록해 보세요.',
                )
              : EmptyPlaceholder.filtered(
                  onResetFilter: () => _controller.setFilter(TodoFilter.all),
                ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
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
            onTap: () => _openForm(todo),
          );
        },
      ),
    );
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
    _showResult(succeeded, successMessage: '할 일을 삭제했습니다.');
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
    return SingleChildScrollView(
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
