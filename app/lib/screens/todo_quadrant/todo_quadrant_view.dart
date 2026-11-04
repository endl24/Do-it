import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../models/todo.dart';
import '../../widgets/sync_status_badge.dart';

/// 05 사분면 조회. 하단 탭이 유지되도록 01 할 일 탭 안에서 목록 대신 보여준다.
class TodoQuadrantView extends StatelessWidget {
  const TodoQuadrantView({
    required this.todos,
    required this.onOpenDetail,
    required this.onMove,
    super.key,
  });

  final List<Todo> todos;
  final ValueChanged<Todo> onOpenDetail;
  final void Function(Todo todo, TodoQuadrant target) onMove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
            child: Column(
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
            ),
          ),
        ),
      ],
    );
  }

  Widget _area(TodoQuadrant quadrant) {
    return _QuadrantArea(
      key: ValueKey('quadrant-${quadrant.name}'),
      quadrant: quadrant,
      todos: todos
          .where((todo) => todo.quadrant == quadrant)
          .toList(growable: false),
      onOpenDetail: onOpenDetail,
      onMove: (todo) => onMove(todo, quadrant),
    );
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
                                child: _QuadrantCard(todo: todo),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.35,
                              child: _QuadrantCard(todo: todo),
                            ),
                            child: _QuadrantCard(
                              todo: todo,
                              onTap: () => onOpenDetail(todo),
                            ),
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

  bool get _isImportant => switch (quadrant) {
    TodoQuadrant.doNow || TodoQuadrant.schedule => true,
    TodoQuadrant.delegate || TodoQuadrant.eliminate => false,
  };

  bool get _isUrgent => switch (quadrant) {
    TodoQuadrant.doNow || TodoQuadrant.delegate => true,
    TodoQuadrant.schedule || TodoQuadrant.eliminate => false,
  };
}

/// 영역 칸이 좁아 제목만 보여준다. 분류는 영역이 이미 알려 주므로 태그가 필요 없다.
class _QuadrantCard extends StatelessWidget {
  const _QuadrantCard({required this.todo, this.onTap});

  final Todo todo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: todo.isCompleted ? AppColors.surfaceSubtle : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  todo.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.fieldLabel.copyWith(
                    color: todo.isCompleted
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                    decoration: todo.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: AppColors.textTertiary,
                  ),
                ),
              ),
              if (todo.syncStatus == TodoSyncStatus.pending) ...[
                const SizedBox(width: AppSpacing.xs),
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xxs),
                  child: StatusDot(color: AppColors.warning),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
