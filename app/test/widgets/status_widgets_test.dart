import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/core/utils/retry_backoff.dart';
import 'package:do_it/widgets/empty_placeholder.dart';
import 'package:do_it/widgets/error_retry_card.dart';
import 'package:do_it/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(20), child: child),
  ),
);

void main() {
  testWidgets('OfflineBanner는 기본으로 E1 문구를 보여준다', (tester) async {
    await tester.pumpWidget(_wrap(const OfflineBanner()));

    expect(find.text(OfflineBanner.defaultMessage), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
  });

  group('ErrorRetryCard', () {
    testWidgets('원인 문구와 다시 시도 버튼을 보여주고 누르면 onRetry를 부른다', (tester) async {
      var retryCount = 0;
      await tester.pumpWidget(
        _wrap(ErrorRetryCard.server(onRetry: () => retryCount++)),
      );

      expect(find.text('서버에 연결하지 못했습니다'), findsOneWidget);
      expect(
        find.text('네트워크 상태를 확인한 뒤 다시 시도해 주세요. 저장된 할 일은 그대로 있습니다.'),
        findsOneWidget,
      );
      await tester.tap(find.text('다시 시도'));
      expect(retryCount, 1);
    });

    testWidgets('여러 번 실패하면 잠시 후 다시 시도하라고 안내한다', (tester) async {
      await tester.pumpWidget(
        _wrap(ErrorRetryCard.server(onRetry: () {}, isSlowedDown: true)),
      );

      expect(find.text(ErrorRetryCard.slowDownMessage), findsOneWidget);
      expect(find.text('서버에 연결하지 못했습니다'), findsOneWidget);
    });

    testWidgets('onRetry가 없으면 다시 시도를 누를 수 없다', (tester) async {
      await tester.pumpWidget(
        _wrap(const ErrorRetryCard(message: '팀을 불러오지 못했습니다', onRetry: null)),
      );

      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);
    });
  });

  testWidgets('EmptyPlaceholder.filtered는 누르면 필터를 되돌린다', (tester) async {
    var resetCount = 0;
    await tester.pumpWidget(
      _wrap(EmptyPlaceholder.filtered(onResetFilter: () => resetCount++)),
    );

    expect(find.text('조건에 맞는 할 일이 없습니다'), findsOneWidget);
    expect(find.text("필터를 '전체'로 바꿔 보세요"), findsOneWidget);
    await tester.tap(find.text("필터를 '전체'로 바꿔 보세요"));
    expect(resetCount, 1);
  });

  group('RetryBackoff', () {
    test('세 번째 실패부터 간격을 두 배씩 늘리고 2분을 넘지 않는다', () {
      final backoff = RetryBackoff(onRetry: () {});

      expect(
        [for (var count = 1; count <= 7; count++) backoff.delayAfter(count)],
        const [
          Duration(seconds: 10),
          Duration(seconds: 10),
          Duration(seconds: 20),
          Duration(seconds: 40),
          Duration(seconds: 80),
          Duration(minutes: 2),
          Duration(minutes: 2),
        ],
      );
    });

    testWidgets('실패하면 자동 재시도를 예약하고, 성공하면 횟수와 예약을 지운다', (tester) async {
      var retryCount = 0;
      final backoff = RetryBackoff(onRetry: () => retryCount++);
      addTearDown(backoff.dispose);

      backoff
        ..recordFailure()
        ..recordFailure();
      expect(backoff.isSlowedDown, isFalse);
      backoff.recordFailure();
      expect(backoff.isSlowedDown, isTrue);

      await tester.pump(const Duration(seconds: 19));
      expect(retryCount, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(retryCount, 1);

      backoff
        ..recordFailure()
        ..recordSuccess();
      expect(backoff.failureCount, 0);
      await tester.pump(const Duration(minutes: 5));
      expect(retryCount, 1);
    });
  });
}
