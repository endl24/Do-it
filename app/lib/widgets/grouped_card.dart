import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// 여러 행을 구분선으로 나눠 한 카드에 담는다. 할 일 상세 정보, 설정 목록 등에 쓴다.
class GroupedCard extends StatelessWidget {
  const GroupedCard({super.key, required this.children, this.footer});

  final List<Widget> children;

  /// 카드 맨 아래 옅은 배경으로 붙는 설명. 예) `알림은 08:00 ~ 22:00 사이에만 발송됩니다`
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(),
            children[i],
          ],
          if (footer != null) ...[
            if (children.isNotEmpty) const Divider(),
            Container(
              color: AppColors.surfaceSubtle,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                footer!,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 왼쪽에 라벨, 오른쪽에 값을 두는 행. [onTap]이 있으면 오른쪽 화살표가 붙는다.
class LabelValueRow extends StatelessWidget {
  const LabelValueRow({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
    this.description,
    this.onTap,
  }) : assert(value == null || valueWidget == null);

  final String label;
  final String? value;

  /// 글자 대신 배지 등 다른 위젯을 값으로 보여줄 때 쓴다.
  final Widget? valueWidget;

  /// 라벨 아래 작은 설명. 예) `다른 기기에서도 같은 할 일을 이어서 사용`
  final String? description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.body.copyWith(
                        color: description == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (description != null)
                      Text(
                        description!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  style: AppTextStyles.body.copyWith(
                    color: onTap == null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: onTap == null ? FontWeight.w600 : null,
                  ),
                ),
              ?valueWidget,
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.chevron_right,
                  size: AppSize.iconSm,
                  color: AppColors.textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
