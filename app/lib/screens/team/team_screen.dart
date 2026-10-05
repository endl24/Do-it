import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_spacing.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/danger_button.dart';
import '../../widgets/empty_placeholder.dart';
import '../../widgets/notice_box.dart';
import '../../widgets/page_header.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton_list.dart';
import '../../widgets/status_message.dart';
import '../../widgets/todo_card.dart';
import '../team_setup/team_setup_screen.dart';
import 'team_view_data.dart';
import 'widgets/team_summary_card.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({
    super.key,
    this.team,
    this.isOnline = true,
    this.isLoading = false,
    this.errorMessage,
    this.onCreateTeam,
    this.onJoinTeam,
    this.onCreateTeamRequest,
    this.onJoinTeamRequest,
    this.onTodoDoneChanged,
    this.onLeaveTeam,
    this.onUndoLeaveTeam,
    this.onRetry,
    this.currentDate,
  });

  final TeamViewData? team;
  final bool isOnline;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onCreateTeam;
  final VoidCallback? onJoinTeam;
  final Future<TeamViewData> Function(String name)? onCreateTeamRequest;
  final Future<TeamViewData> Function(String code)? onJoinTeamRequest;
  final Future<void> Function(String id, bool isDone)? onTodoDoneChanged;
  final Future<void> Function()? onLeaveTeam;
  final Future<void> Function()? onUndoLeaveTeam;
  final VoidCallback? onRetry;
  final DateTime? currentDate;

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  late TeamViewData? _team = widget.team;
  late List<TeamSharedTodo> _todos = List.of(widget.team?.todos ?? []);
  final _updatingTodoIds = <String>{};
  bool _isLeaving = false;
  String? _actionError;

  bool get _canAct =>
      widget.isOnline &&
      !widget.isLoading &&
      widget.errorMessage == null &&
      !_isLeaving;

  @override
  void didUpdateWidget(covariant TeamScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.team != widget.team) {
      _team = widget.team;
      _todos = List.of(widget.team?.todos ?? []);
      _actionError = null;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openSetup({required bool focusJoin}) async {
    final team = await Navigator.of(context).push<TeamViewData>(
      MaterialPageRoute(
        builder: (_) => TeamSetupScreen(
          isOnline: widget.isOnline,
          focusJoin: focusJoin,
          onCreate: widget.onCreateTeamRequest,
          onJoin: widget.onJoinTeamRequest,
        ),
      ),
    );
    if (!mounted || team == null) return;
    setState(() {
      _team = team;
      _todos = List.of(team.todos);
      _actionError = null;
    });
    _showMessage('팀에 참여했습니다');
  }

  Future<void> _copyCode() async {
    final team = _team;
    if (team == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: team.inviteCode));
      if (mounted) _showMessage('초대 코드를 복사했습니다');
    } catch (_) {
      if (mounted) _showMessage('초대 코드를 복사하지 못했습니다. 다시 시도해 주세요.');
    }
  }

  Future<void> _changeDone(TeamSharedTodo todo, bool isDone) async {
    final callback = widget.onTodoDoneChanged;
    if (!_canAct || callback == null || _updatingTodoIds.contains(todo.id)) {
      return;
    }
    final team = _team;
    setState(() {
      _updatingTodoIds.add(todo.id);
      _actionError = null;
    });
    try {
      await callback(todo.id, isDone);
      if (!mounted || _team != team) return;
      setState(() {
        _todos = [
          for (final item in _todos)
            if (item.id == todo.id) item.withDone(isDone) else item,
        ];
      });
    } catch (_) {
      if (mounted && _team == team) {
        setState(() {
          _actionError = '완료 상태를 변경하지 못했습니다. 체크박스를 눌러 다시 시도해 주세요.';
        });
      }
    } finally {
      if (mounted) setState(() => _updatingTodoIds.remove(todo.id));
    }
  }

  Future<void> _leaveTeam() async {
    final team = _team;
    final callback = widget.onLeaveTeam;
    if (!_canAct || team == null || callback == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '팀에서 나갈까요?',
      message: "'${team.name}'에서 나가면 공유 할 일 목록에서 사라집니다.",
      confirmLabel: '팀 탈퇴',
      isDestructive: true,
    );
    if (!confirmed || !mounted || !_canAct || _team != team) return;
    final previousTodos = List<TeamSharedTodo>.of(_todos);
    setState(() {
      _isLeaving = true;
      _actionError = null;
    });
    try {
      await callback();
      if (!mounted || _team != team) return;
      setState(() {
        _team = null;
        _todos = [];
      });
      if (widget.onUndoLeaveTeam case final undo?) {
        showUndoSnackBar(
          context,
          message: '팀에서 나왔습니다',
          onUndo: () => _undoLeave(team, previousTodos, undo),
        );
      } else {
        _showMessage('팀에서 나왔습니다');
      }
    } catch (_) {
      if (mounted && _team == team) {
        setState(() {
          _actionError = '팀에서 나가지 못했습니다. 연결 상태를 확인하고 다시 시도해 주세요.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLeaving = false);
    }
  }

  Future<void> _undoLeave(
    TeamViewData team,
    List<TeamSharedTodo> todos,
    Future<void> Function() callback,
  ) async {
    if (!_canAct || _team != null) return;
    setState(() => _isLeaving = true);
    try {
      await callback();
      if (!mounted || _team != null) return;
      setState(() {
        _team = team;
        _todos = todos;
      });
    } catch (_) {
      if (mounted) _showMessage('팀 탈퇴를 취소하지 못했습니다. 다시 팀에 참여해 주세요.');
    } finally {
      if (mounted) setState(() => _isLeaving = false);
    }
  }

  String _todoMeta(TeamSharedTodo todo) {
    final date = todo.dueDate;
    if (date == null) return todo.ownerName;
    final today = widget.currentDate ?? DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final label = DateUtils.isSameDay(date, tomorrow)
        ? '내일'
        : '${date.month}월 ${date.day}일';
    return '${todo.ownerName} · $label';
  }

  @override
  Widget build(BuildContext context) {
    final team = _team;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            PageHeader(
              title: '팀',
              trailing: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppSize.chipHeight),
                ),
                onPressed: _canAct
                    ? widget.onCreateTeam ?? () => _openSetup(focusJoin: false)
                    : null,
                child: const Text('팀 만들기'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!widget.isOnline) ...[
                    const NoticeBox(
                      message: '팀 기능은 연결된 뒤에 사용할 수 있습니다',
                      icon: Icons.wifi_off,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (_actionError case final message?) ...[
                    NoticeBox.error(message: message),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (widget.isLoading)
                    const SkeletonList()
                  else if (widget.errorMessage case final message?) ...[
                    NoticeBox.error(message: message),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton(
                      onPressed: widget.isOnline ? widget.onRetry : null,
                      child: const Text('다시 시도'),
                    ),
                  ] else if (team == null) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    StatusMessage.icon(
                      icon: Icons.group_outlined,
                      title: '아직 참여한 팀이 없습니다',
                      description: '팀을 만들거나 초대 코드로 참여해 보세요',
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    OutlinedButton(
                      onPressed: _canAct
                          ? widget.onJoinTeam ??
                                () => _openSetup(focusJoin: true)
                          : null,
                      child: const Text('초대 코드로 참여'),
                    ),
                  ] else ...[
                    TeamSummaryCard(team: team, onCopyCode: _copyCode),
                    const SizedBox(height: AppSpacing.lg),
                    SectionHeader.caption(
                      title: '공유 할 일',
                      caption:
                          '미완료 ${_todos.where((todo) => !todo.isDone).length}',
                    ),
                    if (_todos.isEmpty)
                      const EmptyPlaceholder(message: '등록된 공유 할 일이 없습니다')
                    else
                      for (final todo in _todos) ...[
                        TodoCard(
                          key: ValueKey('team-todo-${todo.id}'),
                          title: todo.title,
                          isImportant: todo.isImportant,
                          isUrgent: todo.isUrgent,
                          isDone: todo.isDone,
                          meta: _todoMeta(todo),
                          onTap: _canAct ? todo.onTap : null,
                          onDoneChanged:
                              _canAct &&
                                  widget.onTodoDoneChanged != null &&
                                  !_updatingTodoIds.contains(todo.id)
                              ? (value) => _changeDone(todo, value)
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.listGap),
                      ],
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _canAct
                                ? widget.onJoinTeam ??
                                      () => _openSetup(focusJoin: true)
                                : null,
                            child: const Text('초대 코드로 참여'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        SizedBox(
                          width: AppSize.buttonHeight * 2,
                          child: DangerButton(
                            label: '팀 탈퇴',
                            onPressed: _canAct && _updatingTodoIds.isEmpty
                                ? widget.onLeaveTeam == null
                                      ? null
                                      : _leaveTeam
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
