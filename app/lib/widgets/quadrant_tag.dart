import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// 사분면 태그. 예) `중요 · 긴급`
class QuadrantTag extends StatelessWidget {
  const QuadrantTag({
    super.key,
    required this.isImportant,
    required this.isUrgent,
  }) : label = null;

  /// 완료된 할 일처럼 사분면과 상관없는 회색 태그. 예) `완료 · 오늘`
  const QuadrantTag.neutral({super.key, required String this.label})
    : isImportant = false,
      isUrgent = false;

  final bool isImportant;
  final bool isUrgent;
  final String? label;

  static String labelOf({required bool isImportant, required bool isUrgent}) =>
      '${isImportant ? '중요' : '비중요'} · ${isUrgent ? '긴급' : '비긴급'}';

  @override
  Widget build(BuildContext context) {
    final isNeutral = label != null;
    final colors = QuadrantColors.of(
      isImportant: isImportant,
      isUrgent: isUrgent,
    );

    return Container(
      height: AppSize.tagHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: isNeutral ? AppColors.surfaceMuted : colors.tagBackground,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label ?? labelOf(isImportant: isImportant, isUrgent: isUrgent),
          style: AppTextStyles.tag.copyWith(
            color: isNeutral ? AppColors.textSecondary : colors.foreground,
          ),
        ),
      ),
    );
  }
}
