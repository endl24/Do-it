import 'dart:async';

import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/screens/team/team_screen.dart';
import 'package:do_it/screens/team/team_view_data.dart';
import 'package:do_it/widgets/todo_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _team = TeamViewData(
  name: '캡스톤 3팀',
  inviteCode: '7K4M9P',
  memberNames: ['두', '민', '현'],
  todos: [
    TeamSharedTodo(
      id: '1',
      title: '중간 발표 자료 합치기',
      ownerName: '민',
      isImportant: true,
      isUrgent: true,
    ),
    TeamSharedTodo(
      id: '2',
      title: 'API 명세 정리',
      ownerName: '두',
      isImportant: true,
      isUrgent: false,
      isDone: true,
    ),
  ],
);

Future<void> _pumpTeam(WidgetTester tester, TeamScreen screen) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: screen));
}

void main() {
  testWidgets('팀 정보와 공유 할 일 및 미완료 건수를 보여준다', (tester) async {
    await _pumpTeam(tester, const TeamScreen(team: _team));

    expect(find.text('캡스톤 3팀'), findsOneWidget);
    expect(find.text('구성원 3명 · 공유 할 일 2건'), findsOneWidget);
    expect(find.text('7K4M9P'), findsOneWidget);
    expect(find.text('미완료 1'), findsOneWidget);
    expect(find.text('중간 발표 자료 합치기'), findsOneWidget);
    expect(find.text('API 명세 정리'), findsOneWidget);
  });

  testWidgets('초대 코드를 클립보드에 복사하고 안내한다', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    await _pumpTeam(tester, const TeamScreen(team: _team));
    await tester.tap(find.text('복사'));
    await tester.pumpAndSettle();

    expect(copied, '7K4M9P');
    expect(find.text('초대 코드를 복사했습니다'), findsOneWidget);
  });

  testWidgets('완료 변경 성공 후 체크 상태와 미완료 건수를 갱신한다', (tester) async {
    String? changedId;
    bool? changedValue;
    await _pumpTeam(
      tester,
      TeamScreen(
        team: _team,
        onTodoDoneChanged: (id, value) async {
          changedId = id;
          changedValue = value;
        },
      ),
    );
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(changedId, '1');
    expect(changedValue, true);
    expect(find.text('미완료 0'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, true);
  });

  testWidgets('완료 저장 실패 시 기존 값을 유지하고 재시도할 수 있다', (tester) async {
    var attempts = 0;
    await _pumpTeam(
      tester,
      TeamScreen(
        team: _team,
        onTodoDoneChanged: (_, _) async {
          if (++attempts == 1) throw Exception('실패');
        },
      ),
    );
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('미완료 1'), findsOneWidget);
    expect(find.textContaining('완료 상태를 변경하지 못했습니다'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('미완료 0'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('처리 중인 완료 변경을 중복 실행하지 않는다', (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    await _pumpTeam(
      tester,
      TeamScreen(
        team: _team,
        onTodoDoneChanged: (_, _) {
          calls++;
          return pending.future;
        },
      ),
    );
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(
      tester.widget<Checkbox>(find.byType(Checkbox).first).onChanged,
      null,
    );
    expect(calls, 1);
    pending.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('팀 만들기와 참여 진입 동작을 전달한다', (tester) async {
    var createCalls = 0;
    var joinCalls = 0;
    await _pumpTeam(
      tester,
      TeamScreen(
        onCreateTeam: () => createCalls++,
        onJoinTeam: () => joinCalls++,
      ),
    );
    expect(find.text('아직 참여한 팀이 없습니다'), findsOneWidget);
    await tester.tap(find.text('팀 만들기'));
    await tester.tap(find.text('초대 코드로 참여'));
    expect(createCalls, 1);
    expect(joinCalls, 1);
  });

  testWidgets('팀 탈퇴 취소 시 유지하고 확인 후 목록에서 제거한다', (tester) async {
    var leaveCalls = 0;
    await _pumpTeam(
      tester,
      TeamScreen(team: _team, onLeaveTeam: () async => leaveCalls++),
    );
    await tester.ensureVisible(find.text('팀 탈퇴'));
    await tester.tap(find.text('팀 탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(leaveCalls, 0);
    expect(find.text('캡스톤 3팀'), findsOneWidget);

    await tester.tap(find.text('팀 탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('팀 탈퇴'),
      ),
    );
    await tester.pumpAndSettle();
    expect(leaveCalls, 1);
    expect(find.text('캡스톤 3팀'), findsNothing);
    expect(find.text('아직 참여한 팀이 없습니다'), findsOneWidget);
  });

  testWidgets('탈퇴 실패 시 팀을 유지하고 실패 안내를 표시한다', (tester) async {
    await _pumpTeam(
      tester,
      TeamScreen(team: _team, onLeaveTeam: () async => throw Exception('실패')),
    );
    await tester.ensureVisible(find.text('팀 탈퇴'));
    await tester.tap(find.text('팀 탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('팀 탈퇴'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('캡스톤 3팀'), findsOneWidget);
    expect(find.textContaining('팀에서 나가지 못했습니다'), findsOneWidget);
  });

  testWidgets('오프라인에서는 조회만 허용하고 팀 변경을 막는다', (tester) async {
    await _pumpTeam(
      tester,
      TeamScreen(
        team: _team,
        isOnline: false,
        onCreateTeam: () {},
        onJoinTeam: () {},
        onTodoDoneChanged: (_, _) async {},
        onLeaveTeam: () async {},
      ),
    );
    expect(find.text('팀 기능은 연결된 뒤에 사용할 수 있습니다'), findsOneWidget);
    expect(
      tester.widget<Checkbox>(find.byType(Checkbox).first).onChanged,
      null,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '팀 만들기'))
          .onPressed,
      null,
    );
    expect(find.byType(TodoCard), findsNWidgets(2));
  });

  testWidgets('공유 할 일이 없으면 빈 목록을 표시한다', (tester) async {
    await _pumpTeam(
      tester,
      const TeamScreen(
        team: TeamViewData(
          name: '새 팀',
          inviteCode: 'ABC123',
          memberNames: ['나'],
        ),
      ),
    );
    expect(find.text('미완료 0'), findsOneWidget);
    expect(find.text('등록된 공유 할 일이 없습니다'), findsOneWidget);
  });

  testWidgets('탈퇴 실행 취소 성공 후 이전 팀과 목록을 복원한다', (tester) async {
    var undoCalls = 0;
    await _pumpTeam(
      tester,
      TeamScreen(
        team: _team,
        onLeaveTeam: () async {},
        onUndoLeaveTeam: () async {
          undoCalls++;
        },
      ),
    );
    await tester.ensureVisible(find.text('팀 탈퇴'));
    await tester.tap(find.text('팀 탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('팀 탈퇴'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('실행 취소'));
    await tester.pumpAndSettle();
    expect(undoCalls, 1);
    expect(find.text('캡스톤 3팀'), findsOneWidget);
    expect(find.text('미완료 1'), findsOneWidget);
  });

  testWidgets('로딩과 오류 상태를 구분하고 재시도를 전달한다', (tester) async {
    await _pumpTeam(tester, const TeamScreen(isLoading: true));
    expect(find.bySemanticsLabel('불러오는 중'), findsOneWidget);
    expect(find.text('아직 참여한 팀이 없습니다'), findsNothing);
    var retryCalls = 0;
    await _pumpTeam(
      tester,
      TeamScreen(
        errorMessage: '팀을 불러오지 못했습니다. 연결 상태를 확인해 주세요.',
        onRetry: () => retryCalls++,
      ),
    );
    expect(find.textContaining('팀을 불러오지 못했습니다'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    expect(retryCalls, 1);
  });

  testWidgets('마감일과 담당자를 표시하고 다음 날은 내일로 표시한다', (tester) async {
    await _pumpTeam(
      tester,
      TeamScreen(
        currentDate: DateTime(2026, 9, 21),
        team: TeamViewData(
          name: '날짜 팀',
          inviteCode: 'ABC123',
          memberNames: const ['민'],
          todos: [
            TeamSharedTodo(
              id: '1',
              title: '내일 마감',
              ownerName: '민',
              isImportant: true,
              isUrgent: true,
              dueDate: DateTime(2026, 9, 22),
            ),
            TeamSharedTodo(
              id: '2',
              title: '다음 주 마감',
              ownerName: '민',
              isImportant: true,
              isUrgent: false,
              dueDate: DateTime(2026, 9, 28),
            ),
          ],
        ),
      ),
    );
    expect(find.text('민 · 내일'), findsOneWidget);
    expect(find.text('민 · 9월 28일'), findsOneWidget);
  });
}
