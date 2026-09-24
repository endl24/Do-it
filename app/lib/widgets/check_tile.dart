import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// 제목·설명과 오른쪽 체크박스로 켜고 끄는 카드. 예) `마감 알림 받기`, `알림 받기`
class CheckTile extends StatelessWidget {
  const CheckTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onChanged != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isEnabled ? () => onChanged!(!value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.itemTitle.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Checkbox(
                value: value,
                onChanged: isEnabled
                    ? (checked) => onChanged!(checked ?? false)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
