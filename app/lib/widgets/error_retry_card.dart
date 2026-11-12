import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import 'notice_box.dart';

/// 원인 문구와 [다시 시도] 버튼을 묶은 오류 카드 (E2).
///
/// 같은 요청이 여러 번 연속으로 실패하면([isSlowedDown]) 문구를
/// "잠시 후 다시 시도해 주세요"로 바꾼다. 실패 횟수는 `RetryBackoff`로 센다.
class ErrorRetryCard extends StatelessWidget {
  /// 원인 문구와 [다시 시도] 동작으로 오류 카드를 만든다.
  const ErrorRetryCard({
    super.key,
    required this.message,
    required this.onRetry,
    this.title,
    this.isSlowedDown = false,
  });

  /// 서버 조회·반영에 실패했을 때 쓰는 기본 문구
  const ErrorRetryCard.server({
    super.key,
    required this.onRetry,
    this.isSlowedDown = false,
  }) : title = '서버에 연결하지 못했습니다',
       message = '네트워크 상태를 확인한 뒤 다시 시도해 주세요. 저장된 할 일은 그대로 있습니다.';

  static const slowDownMessage = '잠시 후 다시 시도해 주세요. 그동안 앱이 자동으로 다시 시도합니다.';

  final String? title;
  final String message;

  /// `null`이면 [다시 시도]를 누를 수 없다. 예) 오프라인일 때
  final VoidCallback? onRetry;
  final bool isSlowedDown;

  /// 오류 안내 박스와 [다시 시도] 버튼을 세로로 놓는다. 안내 박스는 화면 읽기 프로그램이 바로 읽도록 알린다.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: NoticeBox.error(
            title: title,
            message: isSlowedDown ? slowDownMessage : message,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    );
  }
}
