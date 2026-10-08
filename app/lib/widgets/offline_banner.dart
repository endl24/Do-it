import 'package:flutter/material.dart';

import 'notice_box.dart';

/// 목록 위에 계속 떠 있는 오프라인 안내 (E1).
///
/// 연결이 끊겨도 쓸 수 있는 기능은 막지 않고 안내만 한다.
/// 팀처럼 연결이 꼭 필요한 화면은 [message]를 바꿔 쓴다.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.message = defaultMessage});

  static const defaultMessage = '오프라인 상태입니다. 등록·수정은 그대로 되고, 연결되면 자동 반영됩니다.';

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: NoticeBox(icon: Icons.cloud_off_outlined, message: message),
    );
  }
}
