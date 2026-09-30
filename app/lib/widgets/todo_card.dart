import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import 'quadrant_tag.dart';
import 'sync_status_badge.dart';

/// 할 일 목록 카드. 할 일 목록, 일정의 날짜별 목록, 팀 공유 할 일에서 쓴다.
///
/// 데이터 모델에 묶이지 않도록 화면에서 필요한 값만 넘겨받는다.
class TodoCard extends StatelessWidget {
  const TodoCard({
    super.key,
    required this.title,
    required this.isImportant,
    required this.isUrgent,
    this.isDone = false,
    this.meta,
    this.isMetaEmphasized = false,
    this.doneLabel = '완료',
    this.isPendingSync = false,
    this.onDoneChanged,
    this.onTap,
  });

  final String title;
  final bool isImportant;
  final bool isUrgent;
  final bool isDone;

  /// 태그 옆 보조 글자. 예) `9월 24일`, `민 · 내일`
  final String? meta;

  /// `오늘 마감`처럼 강조가 필요하면 빨간 글자로 보여준다.
  final bool isMetaEmphasized;

  /// 완료된 할 일은 사분면 태그 대신 이 글자를 회색 태그로 보여준다. 예) `완료 · 오늘`
  final String doneLabel;

  /// 서버에 아직 반영되지 않은 변경이 있으면 오른쪽 위에 점을 표시한다.
  final bool isPendingSync;

  final ValueChanged<bool>? onDoneChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTextStyles.itemTitle.copyWith(
      color: isDone ? AppColors.textTertiary : AppColors.textPrimary,
      decoration: isDone ? TextDecoration.lineThrough : null,
      decorationColor: AppColors.textTertiary,
    );

    return Card(
      color: isDone ? AppColors.surfaceSubtle : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: AppSize.checkbox,
                child: Checkbox(
                  value: isDone,
                  onChanged: onDoneChanged == null
                      ? null
                      : (value) => onDoneChanged!(value ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: titleStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (isDone)
                          QuadrantTag.neutral(label: doneLabel)
                        else
                          QuadrantTag(
                            isImportant: isImportant,
                            isUrgent: isUrgent,
                          ),
                        if (meta != null && !isDone)
                          Text(
                            meta!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isMetaEmphasized
                                  ? AppColors.dangerText
                                  : AppColors.textSecondary,
                              fontWeight: isMetaEmphasized
                                  ? FontWeight.w700
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isPendingSync) ...[
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
