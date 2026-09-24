import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import 'danger_button.dart';

/// 확인 대화상자를 띄우고, 사용자가 실행을 누르면 `true`를 돌려준다.
///
/// ```dart
/// final isConfirmed = await showConfirmDialog(
///   context,
///   title: '할 일을 삭제할까요?',
///   message: "'졸업 요건 서류 제출'을 삭제하면 예약된 알림도 함께 취소됩니다.",
///   confirmLabel: '삭제',
///   isDestructive: true,
/// );
/// ```
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = '취소',
  bool isDestructive = false,
}) async {
  final isConfirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        0,
      ),
      actionsPadding: const EdgeInsets.all(AppSpacing.xl),
      title: Text(title),
      content: Text(message),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelLabel),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: isDestructive
                  ? DangerButton.filled(
                      label: confirmLabel,
                      onPressed: () => Navigator.of(context).pop(true),
                    )
                  : FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(confirmLabel),
                    ),
            ),
          ],
        ),
      ],
    ),
  );
  return isConfirmed ?? false;
}

/// 되돌리기 버튼이 있는 스낵바. 예) `할 일을 삭제했습니다  [실행 취소]`
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
  String undoLabel = '실행 취소',
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: undoLabel, onPressed: onUndo),
      ),
    );
}
