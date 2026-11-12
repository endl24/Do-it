import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// 안내 박스의 색 분위기. 일반 안내는 [neutral], 오류는 [danger]를 쓴다.
enum NoticeTone { neutral, danger }

/// 아이콘과 짧은 안내 문구를 담은 박스. 오프라인 배너, 안내·오류 메시지에 쓴다.
class NoticeBox extends StatelessWidget {
  /// 일반 안내 색으로 안내 박스를 만든다.
  const NoticeBox({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.info_outline,
    this.tone = NoticeTone.neutral,
  });

  /// 오류 아이콘과 빨간 색으로 오류 안내 박스를 만든다.
  const NoticeBox.error({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.error_outline,
  }) : tone = NoticeTone.danger;

  final String message;
  final String? title;
  final IconData? icon;
  final NoticeTone tone;

  /// [tone]에 맞는 배경·테두리·글자 색으로 아이콘, 제목, 안내 문구를 그린다.
  @override
  Widget build(BuildContext context) {
    final isDanger = tone == NoticeTone.danger;
    final foreground = isDanger
        ? AppColors.onDangerContainer
        : AppColors.textLabel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDanger ? AppColors.dangerContainer : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDanger ? AppColors.dangerBorder : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                icon,
                size: 16,
                color: isDanger ? AppColors.danger : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: AppTextStyles.fieldLabel.copyWith(
                      color: isDanger ? AppColors.dangerText : foreground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs / 2),
                ],
                Text(
                  message,
                  style: AppTextStyles.bodySmall.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
