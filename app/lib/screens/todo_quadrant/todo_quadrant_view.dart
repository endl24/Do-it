import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../models/todo.dart';
import '../../widgets/sync_status_badge.dart';

/// 05 사분면 조회. 하단 탭이 유지되도록 01 할 일 탭 안에서 목록 대신 보여준다.
class TodoQuadrantView extends StatelessWidget {
  /// 표시할 할 일과 상세 진입 및 사분면 이동 동작을 받는다.
  const TodoQuadrantView({
    required this.todos,
    required this.onOpenDetail,
    required this.onMove,
    super.key,
  });

  final List<Todo> todos;
  final ValueChanged<Todo> onOpenDetail;
  final void Function(Todo todo, TodoQuadrant target) onMove;

  /// 네 사분면과 카드 이동 안내를 2행 2열로 구성한다.
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

  /// [quadrant]에 속한 할 일만 모아 하나의 사분면 영역을 만든다.
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

/// 카드를 길게 눌러 사분면 사이에서 옮길 수 있음을 안내한다.
class _MoveGuide extends StatelessWidget {
  /// 사분면 이동 안내를 만든다.
  const _MoveGuide();

  /// 아이콘과 설명 문구가 있는 안내 상자를 구성한다.
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

/// 한 사분면의 제목과 건수, 할 일 카드를 표시하고 드롭을 받는 영역이다.
class _QuadrantArea extends StatelessWidget {
  /// 표시할 사분면과 할 일, 상세 및 이동 동작을 받는다.
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

  /// 사분면 색상과 카드 목록을 표시하는 드롭 영역을 구성한다.
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

  /// 현재 사분면이 중요한 영역인지 알려준다.
  bool get _isImportant => switch (quadrant) {
    TodoQuadrant.doNow || TodoQuadrant.schedule => true,
    TodoQuadrant.delegate || TodoQuadrant.eliminate => false,
  };

  /// 현재 사분면이 긴급한 영역인지 알려준다.
  bool get _isUrgent => switch (quadrant) {
    TodoQuadrant.doNow || TodoQuadrant.delegate => true,
    TodoQuadrant.schedule || TodoQuadrant.eliminate => false,
  };
}

/// 영역 칸이 좁아 제목만 보여준다. 분류는 영역이 이미 알려 주므로 태그가 필요 없다.
class _QuadrantCard extends StatelessWidget {
  /// 표시할 [todo]와 선택 동작을 받는다.
  const _QuadrantCard({required this.todo, this.onTap});

  final Todo todo;
  final VoidCallback? onTap;

  /// 완료 및 동기화 상태와 제목만 간결하게 표시하는 카드를 구성한다.
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
