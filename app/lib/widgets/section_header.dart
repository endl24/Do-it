import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// 입력칸이나 목록 위에 두는 작은 제목 줄. 오른쪽에 글자 수, 개수, 버튼 등을 둘 수 있다.
class SectionHeader extends StatelessWidget {
  /// [title]과 선택 [trailing] 위젯으로 제목 줄을 만든다.
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

  /// 제목을 왼쪽에, [trailing]을 오른쪽 끝에 둔다.
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

/// 제목 줄 오른쪽에 두는 옅은 보조 글자.
class _TrailingText extends StatelessWidget {
  /// 보여 줄 [text]로 보조 글자를 만든다.
  const _TrailingText(this.text);

  final String text;

  /// 캡션 크기의 옅은 글자로 그린다.
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
    );
  }
}
