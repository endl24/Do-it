import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// 서버 동기화 상태 배지. 대기 중인 변경이 있으면 `동기화 대기 N`, 없으면 `동기화 완료`.
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key, required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final isPending = pendingCount > 0;
    final foreground = isPending
        ? AppColors.onWarningContainer
        : AppColors.onPrimaryContainer;

    return Container(
      height: AppSize.badgeHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isPending
            ? AppColors.warningContainer
            : AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: isPending
              ? AppColors.warning.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusDot(color: isPending ? AppColors.warning : AppColors.primary),
          const SizedBox(width: AppSpacing.xs - 2),
          Text(
            isPending ? '동기화 대기 $pendingCount' : '동기화 완료',
            style: AppTextStyles.chip.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

/// 상태를 나타내는 작은 원. 동기화 대기 표시, 캘린더 마감 표시 등에 쓴다.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size});

  final Color color;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final dotSize = size ?? AppSize.statusDot;
    return Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
