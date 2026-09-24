import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// 입력칸이나 목록 위에 두는 작은 제목 줄. 오른쪽에 글자 수, 개수, 버튼 등을 둘 수 있다.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  /// 오른쪽에 `현재 / 최대` 글자 수를 보여주는 생성자. 예) `제목  14 / 100`
  SectionHeader.counter({
    super.key,
    required this.title,
    required int length,
    required int maxLength,
  }) : trailing = _TrailingText('$length / $maxLength');

  /// 오른쪽에 보조 글자를 보여주는 생성자. 예) `공유 할 일  미완료 3`
  SectionHeader.caption({
    super.key,
    required this.title,
    required String caption,
  }) : trailing = _TrailingText(caption);

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.fieldLabel.copyWith(
                color: AppColors.textLabel,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _TrailingText extends StatelessWidget {
  const _TrailingText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
    );
  }
}
