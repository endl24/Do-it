import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/screens/notification_settings/notification_settings.dart';
import 'package:do_it/screens/notification_settings/notification_settings_screen.dart';
import 'package:do_it/widgets/quadrant_tag.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpSettings(
  WidgetTester tester, {
  NotificationSettings initialSettings = const NotificationSettings(),
  ValueChanged<NotificationSettings>? onChanged,
  bool isPermissionDenied = false,
  VoidCallback? onOpenSystemSettings,
}) async {
  // 설계서 기준 폰 크기(390×844)보다 길게 띄워 미리보기까지 화면에 들어오게 한다.
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: NotificationSettingsScreen(
        initialSettings: initialSettings,
        onChanged: onChanged ?? (_) {},
        isPermissionDenied: isPermissionDenied,
        onOpenSystemSettings: onOpenSystemSettings,
      ),
    ),
  );
}

Checkbox _repeatCheckbox(WidgetTester tester, int index) =>
    tester.widgetList<Checkbox>(find.byType(Checkbox)).elementAt(index + 1);

void main() {
  testWidgets('알림 받기, 발송 시각, 반복 알림, 미리보기를 보여준다', (tester) async {
    await _pumpSettings(tester);

    expect(find.text('알림'), findsOneWidget);
    expect(find.text('알림 받기'), findsOneWidget);
    expect(find.text('오전 9:00'), findsOneWidget);
    expect(find.text('알림은 08:00 ~ 22:00 사이에만 발송됩니다'), findsOneWidget);
    expect(find.byType(QuadrantTag), findsNWidgets(3));
    expect(find.text('1일 3회'), findsOneWidget);
    expect(find.text('1일 1회'), findsNWidgets(2));
    expect(find.text('오늘 마감인 할 일 3건'), findsOneWidget);
    expect(find.text('알림 권한이 꺼져 있어 설정이 적용되지 않습니다'), findsNothing);
  });

  testWidgets('알림 받기를 끄면 바로 알리고 나머지 설정을 막는다', (tester) async {
    NotificationSettings? changed;
    await _pumpSettings(tester, onChanged: (settings) => changed = settings);

    await tester.tap(find.text('알림 받기'));
    await tester.pump();

    expect(changed?.isEnabled, isFalse);
    expect(_repeatCheckbox(tester, 0).onChanged, isNull);

    await tester.tap(find.text('오전 9:00'));
    await tester.pumpAndSettle();
    expect(find.text('확인'), findsNothing);
  });

  testWidgets('분류별 반복 알림을 끄고 켠다', (tester) async {
    NotificationSettings? changed;
    await _pumpSettings(tester, onChanged: (settings) => changed = settings);

    await tester.tap(find.text('1일 3회'));
    await tester.pump();

    expect(
      changed?.repeatCategories,
      isNot(contains(RepeatCategory.importantUrgent)),
    );
    expect(changed?.repeatCategories, hasLength(2));
    expect(_repeatCheckbox(tester, 0).value, isFalse);
  });

  testWidgets('발송 시각을 바꾼다', (tester) async {
    NotificationSettings? changed;
    await _pumpSettings(tester, onChanged: (settings) => changed = settings);

    await tester.tap(find.text('오전 9:00'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('9시'), const Offset(0, -40));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(changed?.sendTime, const TimeOfDay(hour: 10, minute: 0));
    expect(find.text('오전 10:00'), findsOneWidget);
  });

  testWidgets('08시~22시 밖의 시각은 고를 수 없다', (tester) async {
    await _pumpSettings(tester);

    await tester.tap(find.text('오전 9:00'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('9시'), const Offset(0, 80));
    await tester.pumpAndSettle();

    expect(find.text('알림은 08시부터 22시 사이에만 보낼 수 있습니다'), findsOneWidget);
    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '확인'),
    );
    expect(confirm.onPressed, isNull);
    expect(find.byType(CupertinoPicker), findsNWidgets(3));
  });

  testWidgets('알림 권한이 꺼져 있으면 안내와 설정 열기를 보여준다', (tester) async {
    var isOpened = false;
    await _pumpSettings(
      tester,
      isPermissionDenied: true,
      onOpenSystemSettings: () => isOpened = true,
    );

    expect(find.text('알림 권한이 꺼져 있어 설정이 적용되지 않습니다'), findsOneWidget);
    await tester.tap(find.text('설정 열기'));
    expect(isOpened, isTrue);
  });

  test('발송 시각을 오전·오후로 표기한다', () {
    expect(formatSendTime(const TimeOfDay(hour: 9, minute: 0)), '오전 9:00');
    expect(formatSendTime(const TimeOfDay(hour: 12, minute: 30)), '오후 12:30');
    expect(formatSendTime(const TimeOfDay(hour: 22, minute: 0)), '오후 10:00');
  });

  test('08:00부터 22:00까지만 발송 시각으로 허용한다', () {
    bool isAllowed(int hour, int minute) =>
        NotificationSettings.isAllowedSendTime(
          TimeOfDay(hour: hour, minute: minute),
        );

    expect(isAllowed(7, 50), isFalse);
    expect(isAllowed(8, 0), isTrue);
    expect(isAllowed(22, 0), isTrue);
    expect(isAllowed(22, 10), isFalse);
  });
}
