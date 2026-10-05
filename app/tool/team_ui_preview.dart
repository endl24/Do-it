import 'package:do_it/core/theme/app_colors.dart';
import 'package:do_it/core/theme/app_spacing.dart';
import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/screens/team/team_screen.dart';
import 'package:do_it/screens/team/team_view_data.dart';
import 'package:do_it/screens/team_setup/team_setup_screen.dart';
import 'package:flutter/material.dart';

void main() => runApp(const TeamUiPreviewApp());

class TeamUiPreviewApp extends StatefulWidget {
  const TeamUiPreviewApp({super.key});

  @override
  State<TeamUiPreviewApp> createState() => _TeamUiPreviewAppState();
}

class _TeamUiPreviewAppState extends State<TeamUiPreviewApp> {
  final _store = _PreviewTeamStore();
  late final _initialTeam = _store.currentTeam;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '팀 UI 미리보기',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Banner(
        message: 'UI 미리보기',
        location: BannerLocation.topEnd,
        color: AppColors.warning,
        child: child!,
      ),
      home: Scaffold(
        body: TeamScreen(
          team: _initialTeam,
          isOnline: !const bool.fromEnvironment('TEAM_UI_OFFLINE'),
          currentDate: DateTime(2026, 9, 21),
          onCreateTeamRequest: _store.create,
          onJoinTeamRequest: _store.join,
          onTodoDoneChanged: _store.changeDone,
          onLeaveTeam: _store.leave,
          onUndoLeaveTeam: _store.undoLeave,
        ),
        bottomNavigationBar: NavigationBar(
          height: AppSize.fab + AppSpacing.xs,
          selectedIndex: 2,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.checklist), label: '할 일'),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              label: '일정',
            ),
            NavigationDestination(icon: Icon(Icons.group_outlined), label: '팀'),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              label: '설정',
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewTeamStore {
  _PreviewTeamStore() {
    final team = TeamViewData(
      name: '캡스톤 3팀',
      inviteCode: '7K4M9P',
      memberNames: const ['두', '민', '현'],
      todos: [
        TeamSharedTodo(
          id: '1',
          title: '중간 발표 자료 합치기',
          ownerName: '민',
          isImportant: true,
          isUrgent: true,
          dueDate: DateTime(2026, 9, 23),
        ),
        TeamSharedTodo(
          id: '2',
          title: 'API 명세 정리',
          ownerName: '두',
          isImportant: true,
          isUrgent: false,
          dueDate: DateTime(2026, 9, 28),
        ),
        TeamSharedTodo(
          id: '3',
          title: '테스트 시나리오 작성',
          ownerName: '현',
          isImportant: false,
          isUrgent: true,
          dueDate: DateTime(2026, 9, 22),
        ),
        const TeamSharedTodo(
          id: '4',
          title: '회의록 정리',
          ownerName: '민',
          isImportant: false,
          isUrgent: false,
          isDone: true,
        ),
      ],
    );
    _teams[team.inviteCode] = team;
    currentTeam = team;
  }

  final _teams = <String, TeamViewData>{};
  TeamViewData? currentTeam;
  TeamViewData? _leftTeam;
  int _nextCode = 1;

  Future<TeamViewData> create(String name) async {
    final code = 'UI${(_nextCode++).toString().padLeft(4, '0')}';
    final team = TeamViewData(
      name: name,
      inviteCode: code,
      memberNames: const ['나'],
    );
    _teams[code] = team;
    currentTeam = team;
    return team;
  }

  Future<TeamViewData> join(String code) async {
    final team = _teams[code];
    if (team == null) {
      throw const TeamSetupException(TeamSetupFailure.invalidCode);
    }
    currentTeam = team;
    return team;
  }

  Future<void> changeDone(String id, bool isDone) async {
    final team = currentTeam;
    if (team == null) return;
    final updated = TeamViewData(
      name: team.name,
      inviteCode: team.inviteCode,
      memberNames: team.memberNames,
      todos: [
        for (final todo in team.todos)
          if (todo.id == id) todo.withDone(isDone) else todo,
      ],
    );
    _teams[team.inviteCode] = updated;
    currentTeam = updated;
  }

  Future<void> leave() async {
    _leftTeam = currentTeam;
    currentTeam = null;
  }

  Future<void> undoLeave() async => currentTeam = _leftTeam;
}
