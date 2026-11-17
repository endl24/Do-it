import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/retry_backoff.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/danger_button.dart';
import '../../widgets/empty_placeholder.dart';
import '../../widgets/error_retry_card.dart';
import '../../widgets/notice_box.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/page_header.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton_list.dart';
import '../../widgets/status_message.dart';
import '../../widgets/todo_card.dart';
import '../team_setup/team_setup_screen.dart';
import 'team_view_data.dart';
import 'widgets/team_summary_card.dart';

/// 12 팀 화면. 참여한 팀의 요약·초대 코드와 공유 할 일 목록을 보여 주고, 팀 만들기·참여·탈퇴로 이어 준다.
///
/// 데이터를 불러오고 저장하는 일은 부르는 쪽 콜백에 맡긴다. 연결이 끊겼거나 불러오는 중·오류일 때는 팀 동작 버튼을 막는다.
class TeamScreen extends StatefulWidget {
  /// 팀 정보 [team], 연결·로딩·오류 상태와 팀 동작 콜백으로 팀 화면을 만든다.
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

  /// 보여 줄 팀과 공유 할 일, 진행 중인 동작을 관리할 상태를 만든다.
  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

/// 화면에 보여 줄 팀·공유 할 일과 완료 변경·탈퇴 진행 여부, 동작 오류 문구, 자동 재시도 예약을 들고 있는 상태.
class _TeamScreenState extends State<TeamScreen> {
  late TeamViewData? _team = widget.team;
  late List<TeamSharedTodo> _todos = List.of(widget.team?.todos ?? []);
  final _updatingTodoIds = <String>{};
  bool _isLeaving = false;
  String? _actionError;
  late final _retryBackoff = RetryBackoff(onRetry: _autoRetry);

  /// 연결돼 있고 불러오는 중·오류·탈퇴 중이 아니어서 팀 동작을 해도 되는지 돌려준다.
  bool get _canAct =>
      widget.isOnline &&
      !widget.isLoading &&
      widget.errorMessage == null &&
      !_isLeaving;

  /// 불러오기가 끝났는데 오류가 남아 있는지 돌려준다.
  bool get _hasLoadError => widget.errorMessage != null && !widget.isLoading;

  /// 처음부터 불러오기 오류 상태로 열리면 실패 한 번으로 세어 자동 재시도를 예약한다.
  @override
  void initState() {
    super.initState();
    if (_hasLoadError) _retryBackoff.recordFailure();
  }

  /// 부르는 쪽이 다른 팀을 넘기면 화면의 팀·공유 할 일을 바꾸고 동작 오류를 지운 뒤, 불러오기 결과를 반영한다.
  @override
  void didUpdateWidget(covariant TeamScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.team != widget.team) {
      _team = widget.team;
      _todos = List.of(widget.team?.todos ?? []);
      _actionError = null;
    }
    _trackLoadResult(oldWidget);
  }

  /// 예약해 둔 자동 재시도를 취소한다.
  @override
  void dispose() {
    _retryBackoff.dispose();
    super.dispose();
  }

  /// 부르는 쪽이 넘겨준 로딩·오류 값이 바뀔 때 연속 실패 횟수를 센다.
  ///
  /// 연결이 끊기면 자동 재시도 예약을 취소하고, 다시 연결되면 기다리지 않고 바로 다시 불러온다.
  void _trackLoadResult(TeamScreen oldWidget) {
    final wasFinished = oldWidget.errorMessage == null || oldWidget.isLoading;
    if (_hasLoadError && wasFinished) {
      _retryBackoff.recordFailure();
    } else if (!widget.isLoading && widget.errorMessage == null) {
      _retryBackoff.recordSuccess();
    }
    if (!widget.isOnline) {
      _retryBackoff.cancel();
    } else if (!oldWidget.isOnline && _hasLoadError) {
      // 연결이 돌아오면 예약을 기다리지 않고 바로 다시 불러온다.
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoRetry());
    }
  }

  /// 화면이 살아 있고 연결된 상태에서 아직 불러오기 오류가 있으면 부르는 쪽에 다시 불러오기를 요청한다.
  void _autoRetry() {
    if (mounted && widget.isOnline && _hasLoadError) widget.onRetry?.call();
  }

  /// 떠 있는 스낵바를 닫고 [message]를 새 스낵바로 띄운다.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 13 팀 만들기·참여 화면을 열고, 만들거나 참여한 팀을 돌려받으면 화면에 반영한 뒤 안내 스낵바를 띄운다.
  ///
  /// [focusJoin]이 true면 초대 코드 입력칸에 바로 커서를 둔다.
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

  /// 초대 코드를 클립보드에 복사하고 결과를 스낵바로 알린다.
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

  /// 공유 할 일 [todo]의 완료 상태를 [isDone]으로 바꾼다.
  ///
  /// 저장이 끝난 뒤에만 화면에 반영하고, 그 사이 팀이 바뀌었으면 결과를 버린다. 같은 할 일은 저장이 끝날 때까지 다시 누를 수 없고, 실패하면 오류 문구를 보여 준다.
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

  /// 확인 대화상자를 거쳐 팀에서 나가고, 실행 취소 스낵바를 띄운다.
  ///
  /// 실행 취소 동작이 없으면 안내 스낵바만 띄운다. 실패하면 팀을 그대로 두고 오류 문구를 보여 준다.
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

  /// 팀 탈퇴를 실행 취소해 나가기 전 팀 [team]과 공유 할 일 [todos]를 되살린다.
  ///
  /// 그 사이 다른 팀에 들어갔거나 팀 동작을 할 수 없는 상태면 아무것도 하지 않는다.
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

  /// 공유 할 일 카드에 보일 '담당자 · 마감일' 문구를 만든다. 마감일이 내일이면 '내일'로, 없으면 담당자만 쓴다.
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

  /// 머리글 아래에 연결·오류 안내를 두고, 상태에 따라 불러오는 중 표시, 오류 재시도 카드, 팀 없음 안내, 또는 팀 요약과 공유 할 일 목록을 그린다.
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
                    const OfflineBanner(message: '팀 기능은 연결된 뒤에 사용할 수 있습니다'),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (_actionError case final message?) ...[
                    NoticeBox.error(message: message),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (widget.isLoading)
                    const SkeletonList()
                  else if (widget.errorMessage case final message?)
                    ErrorRetryCard(
                      message: message,
                      isSlowedDown: _retryBackoff.isSlowedDown,
                      onRetry: widget.isOnline ? widget.onRetry : null,
                    )
                  else if (team == null) ...[
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
