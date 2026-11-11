import 'dart:async';

import 'package:do_it/services/internet_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('연결 변화만 알리고 구독 취소 후 검사를 멈춘다', () async {
    var probes = 0;
    final connected = Completer<void>();
    final events = <bool>[];
    final subscription =
        InternetStatus(
          interval: const Duration(milliseconds: 10),
          probe: () async => ++probes >= 3,
        ).watch().listen((isOnline) {
          events.add(isOnline);
          if (isOnline) connected.complete();
        });
    await connected.future.timeout(const Duration(seconds: 2));
    expect(events, [false, true]);
    await subscription.cancel();
    final count = probes;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(probes, count);
  });

  test('연결 확인 오류를 오프라인으로 처리하고 다음 검사에서 복구한다', () async {
    var attempts = 0;
    final connected = Completer<void>();
    final events = <bool>[];
    final subscription =
        InternetStatus(
          interval: const Duration(milliseconds: 10),
          probe: () async {
            if (++attempts == 1) throw StateError('연결 실패');
            return true;
          },
        ).watch().listen((isOnline) {
          events.add(isOnline);
          if (isOnline) connected.complete();
        });
    await connected.future.timeout(const Duration(seconds: 2));
    expect(events, [false, true]);
    await subscription.cancel();
  });

  test('확인 중 취소해도 완료 결과나 재검사 예약이 남지 않는다', () async {
    final gate = Completer<bool>();
    final events = <bool>[];
    var probes = 0;
    final subscription = InternetStatus(
      interval: const Duration(milliseconds: 10),
      probe: () {
        probes++;
        return gate.future;
      },
    ).watch().listen(events.add);
    await subscription.cancel();
    gate.complete(true);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(events, isEmpty);
    expect(probes, 1);
  });
}
