import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/team_ui_preview.dart';

Future<void> _tap(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('미리보기에서 완료 변경·생성·코드 오류·참여·탈퇴를 확인한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TeamUiPreviewApp());
    await tester.pumpAndSettle();
    expect(find.text('구성원 3명 · 공유 할 일 4건'), findsOneWidget);
    expect(find.text('미완료 3'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('미완료 2'), findsOneWidget);
    await _tap(tester, '팀 만들기');
    await tester.enterText(
      find.byKey(const ValueKey('team-name-input')),
      'UI 확인 팀',
    );
    await tester.pump();
    await _tap(tester, '팀 만들고 초대 코드 받기');
    expect(find.text('UI 확인 팀'), findsOneWidget);
    expect(find.text('UI0001'), findsOneWidget);

    await _tap(tester, '초대 코드로 참여');
    await tester.enterText(
      find.byKey(const ValueKey('team-code-input')),
      '7K4M9X',
    );
    await tester.pump();
    await _tap(tester, '참여하기');
    expect(find.textContaining('해당 코드의 팀을 찾을 수 없습니다'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('team-code-input')),
      '7K4M9P',
    );
    await tester.pump();
    await _tap(tester, '참여하기');
    expect(find.text('캡스톤 3팀'), findsOneWidget);
    expect(find.text('미완료 2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await _tap(tester, '팀 탈퇴');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('팀 탈퇴'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('아직 참여한 팀이 없습니다'), findsOneWidget);
    await _tap(tester, '실행 취소');
    expect(find.text('캡스톤 3팀'), findsOneWidget);
    expect(tester.takeException(), null);
  });
}
