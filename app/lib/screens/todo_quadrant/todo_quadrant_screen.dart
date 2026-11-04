import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../models/todo.dart';
import '../../widgets/page_header.dart';
import '../../widgets/todo_card.dart';
import '../home/todo_controller.dart';
import '../todo_detail/todo_detail_screen.dart';
import '../todo_list/widgets/todo_view_switcher.dart';

class TodoQuadrantScreen extends StatelessWidget {
  const TodoQuadrantScreen({required this.controller, super.key});

  final TodoController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => Column(
            children: [
              const PageHeader(
                title: '사분면',
                subtitle: '중요도와 긴급도에 따라 할 일을 나눠 봅니다',
              ),
              TodoViewSwitcher(
                selected: TodoViewMode.quadrant,
                onChanged: (mode) {
                  if (mode == TodoViewMode.list) Navigator.of(context).pop();
                },
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.sm,
                  AppSpacing.screenHorizontal,
                  AppSpacing.sm,
                ),
                child: _MoveGuide(),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    0,
                    AppSpacing.screenHorizontal,
                    AppSpacing.md,
                  ),
                  child: _QuadrantGrid(
                    controller: controller,
                    onOpenDetail: (todo) => _openDetail(context, todo),
                    onMoveFailed: () => _showMessage(
                      context,
                      controller.errorMessage ?? '분류를 변경하지 못했습니다.',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, Todo todo) async {
    final result = await Navigator.of(context).push<TodoDetailResult>(
      MaterialPageRoute(
        builder: (_) => TodoDetailScreen(
          todo: todo,
          onUpdate: controller.update,
          onDelete: controller.remove,
        ),
      ),
    );
    if (!context.mounted || result == null) return;
    final message = switch (result) {
      TodoDetailResult.completed =>
        todo.isCompleted ? '미완료로 변경했습니다.' : '할 일을 완료했습니다.',
      TodoDetailResult.deleted => '할 일을 삭제했습니다.',
    };
    _showMessage(context, message);
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MoveGuide extends StatelessWidget {
  const _MoveGuide();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.touch_app_outlined,
            size: AppSize.iconSm,
            color: AppColors.onPrimaryContainer,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '카드를 길게 눌러 다른 영역으로 옮겨 보세요',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuadrantGrid extends StatelessWidget {
  const _QuadrantGrid({
    required this.controller,
    required this.onOpenDetail,
    required this.onMoveFailed,
  });

  final TodoController controller;
  final ValueChanged<Todo> onOpenDetail;
  final VoidCallback onMoveFailed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _area(TodoQuadrant.doNow)),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: _area(TodoQuadrant.schedule)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _area(TodoQuadrant.delegate)),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: _area(TodoQuadrant.eliminate)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _area(TodoQuadrant quadrant) {
    final todos = controller.todos
        .where((todo) => todo.quadrant == quadrant)
        .toList(growable: false);
    return _QuadrantArea(
      key: ValueKey('quadrant-${quadrant.name}'),
      quadrant: quadrant,
      todos: todos,
      onOpenDetail: onOpenDetail,
      onMove: (todo) async {
        if (!await controller.move(todo, quadrant)) onMoveFailed();
      },
    );
  }
}

class _QuadrantArea extends StatelessWidget {
  const _QuadrantArea({
    required this.quadrant,
    required this.todos,
    required this.onOpenDetail,
    required this.onMove,
    super.key,
  });

  final TodoQuadrant quadrant;
  final List<Todo> todos;
  final ValueChanged<Todo> onOpenDetail;
  final ValueChanged<Todo> onMove;

  @override
  Widget build(BuildContext context) {
    final colors = QuadrantColors.of(
      isImportant: _isImportant,
      isUrgent: _isUrgent,
    );
    return DragTarget<Todo>(
      onWillAcceptWithDetails: (details) => details.data.quadrant != quadrant,
      onAcceptWithDetails: (details) => onMove(details.data),
      builder: (context, candidateData, _) {
        final isReceiving = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: colors.areaBackground,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isReceiving ? colors.foreground : colors.areaBorder,
              width: isReceiving ? 2 : AppSize.borderWidth,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      quadrant.label,
                      style: AppTextStyles.fieldLabel.copyWith(
                        color: colors.foreground,
                      ),
                    ),
                  ),
                  Text(
                    '${todos.length}',
                    style: AppTextStyles.tag.copyWith(color: colors.foreground),
                  ),
                ],
              ),
              Text(
                quadrant.description,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: todos.isEmpty
                    ? Center(
                        child: Text(
                          '아직 없음',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        key: PageStorageKey(quadrant.name),
                        itemCount: todos.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) {
                          final todo = todos[index];
                          return LongPressDraggable<Todo>(
                            key: ValueKey('quadrant-todo-${todo.id}'),
                            data: todo,
                            feedback: Material(
                              color: Colors.transparent,
                              child: SizedBox(
                                width: 180,
                                child: _card(todo, onTap: null),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.35,
                              child: _card(todo, onTap: null),
                            ),
                            child: _card(todo, onTap: () => onOpenDetail(todo)),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _card(Todo todo, {required VoidCallback? onTap}) {
    return TodoCard(
      title: todo.title,
      isImportant: todo.isImportant,
      isUrgent: todo.isUrgent,
      isDone: todo.isCompleted,
      isPendingSync: todo.syncStatus == TodoSyncStatus.pending,
      onTap: onTap,
    );
  }

  bool get _isImportant => switch (quadrant) {
    TodoQuadrant.doNow || TodoQuadrant.schedule => true,
    TodoQuadrant.delegate || TodoQuadrant.eliminate => false,
  };

  bool get _isUrgent => switch (quadrant) {
    TodoQuadrant.doNow || TodoQuadrant.delegate => true,
    TodoQuadrant.schedule || TodoQuadrant.eliminate => false,
  };
}
