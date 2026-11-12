import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// 탭 화면 맨 위의 큰 제목. 예) `할 일`, `사분면`, `팀`, `설정`
class PageHeader extends StatelessWidget {
  /// [title]과 선택 [trailing]·[subtitle]로 화면 제목 줄을 만든다.
  const PageHeader({
    super.key,
    required this.title,
    this.trailing,
    this.subtitle,
  });

  final String title;

  /// 제목 오른쪽 끝에 두는 위젯. 예) 날짜 요약, `팀 만들기` 버튼, 목록/사분면 토글
  final Widget? trailing;

  /// 제목 아래 한 줄 설명
  final String? subtitle;

  /// 큰 제목과 오른쪽 위젯을 한 줄에 두고, 설명이 있으면 그 아래에 붙인다.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.xs,
        AppSpacing.screenHorizontal,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.display.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              subtitle!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
