import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// 삭제·탈퇴처럼 되돌리기 어려운 동작 버튼.
///
/// 기본은 테두리 버튼(할 일 삭제, 팀 탈퇴, 회원 탈퇴)이고,
/// [DangerButton.filled]는 확인 대화상자의 최종 실행 버튼에 쓴다.
class DangerButton extends StatelessWidget {
  const DangerButton({super.key, required this.label, required this.onPressed})
    : isFilled = false;

  const DangerButton.filled({
    super.key,
    required this.label,
    required this.onPressed,
  }) : isFilled = true;

  final String label;
  final VoidCallback? onPressed;
  final bool isFilled;

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
