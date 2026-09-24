import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/widgets/check_tile.dart';
import 'package:do_it/widgets/confirm_dialog.dart';
import 'package:do_it/widgets/grouped_card.dart';
import 'package:do_it/widgets/initial_avatar.dart';
import 'package:do_it/widgets/quadrant_tag.dart';
import 'package:do_it/widgets/section_header.dart';
import 'package:do_it/widgets/sync_status_badge.dart';
import 'package:do_it/widgets/todo_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('QuadrantTag', () {
    testWidgets('중요도·긴급도에 맞는 글자를 보여준다', (tester) async {
      await tester.pumpWidget(
        _wrap(const QuadrantTag(isImportant: false, isUrgent: true)),
      );

      expect(find.text('비중요 · 긴급'), findsOneWidget);
    });
  });

  group('SyncStatusBadge', () {
    testWidgets('대기 개수가 있으면 대기, 없으면 완료로 보여준다', (tester) async {
      await tester.pumpWidget(_wrap(const SyncStatusBadge(pendingCount: 2)));
      expect(find.text('동기화 대기 2'), findsOneWidget);

      await tester.pumpWidget(_wrap(const SyncStatusBadge(pendingCount: 0)));
      expect(find.text('동기화 완료'), findsOneWidget);
    });
  });

  group('TodoCard', () {
    testWidgets('체크박스를 누르면 완료 상태를 알린다', (tester) async {
      bool? changed;
      await tester.pumpWidget(
        _wrap(
          TodoCard(
            title: '졸업 요건 서류 제출',
            isImportant: true,
            isUrgent: true,
            meta: '오늘 마감',
            onDoneChanged: (value) => changed = value,
          ),
        ),
      );

      expect(find.text('중요 · 긴급'), findsOneWidget);
      expect(find.text('오늘 마감'), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      expect(changed, isTrue);
    });

    testWidgets('완료된 할 일은 사분면 대신 완료 태그를 보여준다', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TodoCard(
            title: '우편물 수령',
            isImportant: false,
            isUrgent: false,
            isDone: true,
            doneLabel: '완료 · 오늘',
          ),
        ),
      );

      expect(find.text('완료 · 오늘'), findsOneWidget);
      expect(find.text('비중요 · 비긴급'), findsNothing);
    });
  });

  testWidgets('SectionHeader.counter는 글자 수를 보여준다', (tester) async {
    await tester.pumpWidget(
      _wrap(SectionHeader.counter(title: '제목', length: 14, maxLength: 100)),
    );

    expect(find.text('14 / 100'), findsOneWidget);
  });

  testWidgets('LabelValueRow는 누를 수 있을 때만 화살표를 보여준다', (tester) async {
    await tester.pumpWidget(
      _wrap(
        GroupedCard(
          children: [
            const LabelValueRow(label: '등록', value: '9월 18일'),
            LabelValueRow(label: '알림', value: '켜짐', onTap: () {}),
          ],
        ),
      ),
    );

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('CheckTile은 카드 어디를 눌러도 값을 뒤집는다', (tester) async {
    bool? changed;
    await tester.pumpWidget(
      _wrap(
        CheckTile(
          title: '마감 알림 받기',
          value: false,
          onChanged: (value) => changed = value,
        ),
      ),
    );

    await tester.tap(find.text('마감 알림 받기'));
    expect(changed, isTrue);
  });

  testWidgets('InitialAvatar는 이름 첫 글자를 보여준다', (tester) async {
    await tester.pumpWidget(_wrap(const InitialAvatar(name: '두이')));

    expect(find.text('두'), findsOneWidget);
  });

  testWidgets('showConfirmDialog는 누른 버튼에 따라 결과를 돌려준다', (tester) async {
    late BuildContext savedContext;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) {
            savedContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final confirmed = showConfirmDialog(
      savedContext,
      title: '할 일을 삭제할까요?',
      message: '예약된 알림도 함께 취소됩니다.',
      confirmLabel: '삭제',
      isDestructive: true,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(await confirmed, isTrue);

    final canceled = showConfirmDialog(
      savedContext,
      title: '할 일을 삭제할까요?',
      message: '예약된 알림도 함께 취소됩니다.',
      confirmLabel: '삭제',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(await canceled, isFalse);
  });
}
