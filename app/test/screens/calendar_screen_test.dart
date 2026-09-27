import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/screens/calendar/calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpCalendar(
  WidgetTester tester, {
  List<CalendarDeadline> deadlines = const [],
  DateTime? initialDate,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: CalendarScreen(deadlines: deadlines, initialDate: initialDate),
    ),
  );
}

void main() {
  testWidgets('선택한 날짜의 마감 건수와 할 일 목록을 보여준다', (tester) async {
    await _pumpCalendar(
      tester,
      initialDate: DateTime(2026, 9, 21),
      deadlines: [
        CalendarDeadline(
          title: '졸업 요건 서류 제출',
          dueDate: DateTime(2026, 9, 21, 18),
          isImportant: true,
          isUrgent: true,
        ),
        CalendarDeadline(
          title: '스터디 발표 자료 정리',
          dueDate: DateTime(2026, 9, 24),
          isImportant: true,
          isUrgent: false,
        ),
        const CalendarDeadline(
          title: '마감 없는 할 일',
          isImportant: false,
          isUrgent: false,
        ),
      ],
    );

    expect(find.text('2026년 9월'), findsOneWidget);
    expect(find.text('9월 21일 (월)'), findsOneWidget);
    expect(find.text('마감 1건'), findsOneWidget);
    expect(find.text('졸업 요건 서류 제출'), findsOneWidget);
    expect(find.text('이 날짜에 다른 마감은 없습니다'), findsOneWidget);
    expect(find.text('마감 없는 할 일'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-9-24')));
    await tester.pump();

    expect(find.text('9월 24일 (목)'), findsOneWidget);
    expect(find.text('스터디 발표 자료 정리'), findsOneWidget);
    expect(find.text('졸업 요건 서류 제출'), findsNothing);
  });

  testWidgets('마감이 없는 날짜에는 빈 상태를 보여준다', (tester) async {
    await _pumpCalendar(tester, initialDate: DateTime(2026, 9, 21));

    expect(find.text('마감 0건'), findsOneWidget);
    expect(find.text('이 날짜에 다른 마감은 없습니다'), findsOneWidget);
  });

  testWidgets('월 이동 시 말일을 해당 월의 마지막 날로 맞춘다', (tester) async {
    await _pumpCalendar(tester, initialDate: DateTime(2026, 1, 31));

    await tester.tap(find.byTooltip('다음 달'));
    await tester.pump();

    expect(find.text('2026년 2월'), findsOneWidget);
    expect(find.text('2월 28일 (토)'), findsOneWidget);

    await tester.tap(find.byTooltip('이전 달'));
    await tester.pump();

    expect(find.text('2026년 1월'), findsOneWidget);
    expect(find.text('1월 28일 (수)'), findsOneWidget);
  });

  testWidgets('달력을 좌우로 밀면 월을 이동한다', (tester) async {
    await _pumpCalendar(tester, initialDate: DateTime(2026, 9, 21));

    await tester.drag(
      find.byKey(const ValueKey('calendar-month-grid')),
      const Offset(-250, 0),
    );
    await tester.pump();
    expect(find.text('2026년 10월'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('calendar-month-grid')),
      const Offset(250, 0),
    );
    await tester.pump();
    expect(find.text('2026년 9월'), findsOneWidget);
  });

  testWidgets('할 일 카드의 탭 동작을 전달한다', (tester) async {
    var tapCount = 0;
    await _pumpCalendar(
      tester,
      initialDate: DateTime(2026, 9, 21),
      deadlines: [
        CalendarDeadline(
          title: '졸업 요건 서류 제출',
          dueDate: DateTime(2026, 9, 21),
          isImportant: true,
          isUrgent: true,
          onTap: () => tapCount++,
        ),
      ],
    );

    await tester.tap(find.text('졸업 요건 서류 제출'));
    await tester.pump();

    expect(tapCount, 1);
  });
}
