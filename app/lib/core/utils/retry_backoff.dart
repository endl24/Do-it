import 'dart:async';

import 'package:flutter/foundation.dart';

/// 같은 요청의 연속 실패 횟수를 세고, 실패할 때마다 자동 재시도를 예약한다.
///
/// [slowDownAfter]번 연속으로 실패하면 재시도 간격을 두 배씩 늘린다 (16, B5).
/// 화면이 사라질 때 [dispose]로 예약을 취소해야 한다.
class RetryBackoff {
  RetryBackoff({
    required this.onRetry,
    this.slowDownAfter = 3,
    this.baseDelay = const Duration(seconds: 10),
    this.maxDelay = const Duration(minutes: 2),
  });

  final VoidCallback onRetry;
  final int slowDownAfter;
  final Duration baseDelay;
  final Duration maxDelay;

  int _failureCount = 0;
  Timer? _timer;

  int get failureCount => _failureCount;

  /// 연속 실패가 많아 재시도 간격을 늘린 상태
  bool get isSlowedDown => _failureCount >= slowDownAfter;

  /// 실패를 기록하고 다음 자동 재시도를 예약한다.
  void recordFailure() {
    _failureCount++;
    _timer?.cancel();
    _timer = Timer(delayAfter(_failureCount), onRetry);
  }

  /// 성공하면 횟수를 0으로 되돌리고 예약을 취소한다.
  void recordSuccess() {
    _failureCount = 0;
    cancel();
  }

  /// 횟수는 그대로 두고 예약만 취소한다. 예) 오프라인이 되어 재시도가 의미 없을 때
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();

  /// [failureCount]번 실패한 뒤 기다릴 시간.
  /// 기본값이면 10초, 10초, 20초, 40초, 80초, 그 뒤로는 2분.
  @visibleForTesting
  Duration delayAfter(int failureCount) {
    if (failureCount < slowDownAfter) return baseDelay;
    final doublings = failureCount - slowDownAfter + 1;
    final delay = baseDelay * (1 << doublings.clamp(0, 20));
    return delay > maxDelay ? maxDelay : delay;
  }
}
