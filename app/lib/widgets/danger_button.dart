import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// 삭제·탈퇴처럼 되돌리기 어려운 동작 버튼.
///
/// 기본은 테두리 버튼(할 일 삭제, 팀 탈퇴, 회원 탈퇴)이고,
/// [DangerButton.filled]는 확인 대화상자의 최종 실행 버튼에 쓴다.
class DangerButton extends StatelessWidget {
  /// 빨간 테두리 버튼을 만든다.
  const DangerButton({super.key, required this.label, required this.onPressed})
    : isFilled = false;

  /// 빨간 배경을 채운 버튼을 만든다. 확인 대화상자의 최종 실행 버튼에 쓴다.
  const DangerButton.filled({
    super.key,
    required this.label,
    required this.onPressed,
  }) : isFilled = true;

  final String label;
  final VoidCallback? onPressed;
  final bool isFilled;

  /// [isFilled]에 따라 채운 버튼이나 테두리 버튼을 위험 색으로 그린다.
  @override
  Widget build(BuildContext context) {
    if (isFilled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.danger,
          foregroundColor: AppColors.onPrimary,
        ),
        child: Text(label),
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.dangerText,
        side: const BorderSide(color: AppColors.dangerBorder),
      ),
      child: Text(label),
    );
  }
}
