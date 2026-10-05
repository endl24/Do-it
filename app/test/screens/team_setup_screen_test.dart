import 'dart:async';

import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/screens/team/team_screen.dart';
import 'package:do_it/screens/team/team_view_data.dart';
import 'package:do_it/screens/team_setup/team_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _name = ValueKey('team-name-input');
const _code = ValueKey('team-code-input');
const _createLabel = '팀 만들고 초대 코드 받기';

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: screen));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('팀 이름은 20자까지 입력하고 빈 이름 생성은 막는다', (tester) async {
    await _pump(tester, const TeamSetupScreen());
    final button = find.widgetWithText(FilledButton, _createLabel);
    expect(tester.widget<FilledButton>(button).onPressed, null);
    await tester.enterText(find.byKey(_name), '   ');
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, null);
    await tester.enterText(find.byKey(_name), '가' * 21);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(_name))
          .controller!
          .text
          .characters
          .length,
      20,
    );
    expect(find.text('20 / 20'), findsOneWidget);
  });

  testWidgets('12번에서 생성 화면을 열고 성공 결과를 팀 화면에 반영한다', (tester) async {
    String? submitted;
    await _pump(
      tester,
      TeamScreen(
        onCreateTeamRequest: (name) async {
          submitted = name;
          return TeamViewData(
            name: name,
            inviteCode: 'ABC123',
            memberNames: const ['나'],
          );
        },
      ),
    );
    await _tap(tester, '팀 만들기');
    expect(find.text('팀 만들기 · 참여'), findsOneWidget);
    await tester.enterText(find.byKey(_name), '  새 팀  ');
    await tester.pump();
    await _tap(tester, _createLabel);
    expect(submitted, '새 팀');
    expect(find.text('새 팀'), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.byType(TeamSetupScreen), findsNothing);
  });

  testWidgets('초대 코드 형식을 제한하고 대소문자를 유지해 참여한다', (tester) async {
    String? submitted;
    await _pump(
      tester,
      TeamScreen(
        onJoinTeamRequest: (code) async {
          submitted = code;
          return TeamViewData(
            name: '기존 팀',
            inviteCode: code,
            memberNames: const ['나', '민'],
          );
        },
      ),
    );
    await _tap(tester, '초대 코드로 참여');
    await tester.enterText(find.byKey(_code), 'ab12!가CD9');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(_code)).controller!.text,
      'ab12CD',
    );
    await _tap(tester, '참여하기');
    expect(submitted, 'ab12CD');
    expect(find.text('기존 팀'), findsOneWidget);
  });

  testWidgets('없는 초대 코드는 입력을 유지하고 수정 후 재시도한다', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      TeamScreen(
        onJoinTeamRequest: (code) async {
          calls++;
          if (code == 'BAD123') {
            throw const TeamSetupException(TeamSetupFailure.invalidCode);
          }
          return TeamViewData(
            name: '참여 팀',
            inviteCode: code,
            memberNames: const ['나'],
          );
        },
      ),
    );
    await _tap(tester, '초대 코드로 참여');
    await tester.enterText(find.byKey(_code), 'BAD123');
    await tester.pump();
    await _tap(tester, '참여하기');
    expect(find.textContaining('해당 코드의 팀을 찾을 수 없습니다'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(_code)).controller!.text,
      'BAD123',
    );
    await tester.enterText(find.byKey(_code), 'GOOD12');
    await tester.pump();
    expect(find.textContaining('해당 코드의 팀을 찾을 수 없습니다'), findsNothing);
    await _tap(tester, '참여하기');
    expect(calls, 2);
    expect(find.text('참여 팀'), findsOneWidget);
  });

  testWidgets('오프라인에서는 두 입력과 실행을 비활성화한다', (tester) async {
    await _pump(tester, const TeamSetupScreen(isOnline: false));
    expect(tester.widget<TextField>(find.byKey(_name)).enabled, false);
    expect(tester.widget<TextField>(find.byKey(_code)).enabled, false);
    expect(find.text('팀 기능은 연결된 뒤에 사용할 수 있습니다'), findsOneWidget);
  });

  testWidgets('요청 중 입력과 중복 실행을 막는다', (tester) async {
    final request = Completer<TeamViewData>();
    var calls = 0;
    await _pump(
      tester,
      TeamScreen(
        onCreateTeamRequest: (_) {
          calls++;
          return request.future;
        },
      ),
    );
    await _tap(tester, '팀 만들기');
    await tester.enterText(find.byKey(_name), '새 팀');
    await tester.pump();
    await tester.tap(find.text(_createLabel));
    await tester.pump();
    expect(find.text('팀 만드는 중…'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(_name)).enabled, false);
    expect(calls, 1);
    request.complete(
      const TeamViewData(name: '새 팀', inviteCode: 'ABC123', memberNames: ['나']),
    );
    await tester.pumpAndSettle();
    expect(find.text('새 팀'), findsOneWidget);
  });

  testWidgets('서버 미연결 시 성공으로 처리하지 않고 안내한다', (tester) async {
    await _pump(tester, const TeamScreen());
    await _tap(tester, '팀 만들기');
    await tester.enterText(find.byKey(_name), '새 팀');
    await tester.pump();
    await _tap(tester, _createLabel);
    expect(find.textContaining('현재 팀 기능을 사용할 수 없습니다'), findsOneWidget);
    expect(find.byType(TeamSetupScreen), findsOneWidget);
  });

  testWidgets('뒤로 가면 생성하지 않고 12번으로 돌아온다', (tester) async {
    await _pump(tester, const TeamScreen());
    await _tap(tester, '팀 만들기');
    await tester.enterText(find.byKey(_name), '미저장 팀');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('아직 참여한 팀이 없습니다'), findsOneWidget);
  });
}
