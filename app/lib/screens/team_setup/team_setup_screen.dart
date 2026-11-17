import 'package:flutter/material.dart';

import '../team/team_view_data.dart';
import 'widgets/team_setup_form.dart';

/// 팀 만들기·참여가 실패한 이유. [invalidCode]는 초대 코드에 맞는 팀이 없음, [unavailable]은 팀 기능을 쓸 수 없음이다.
enum TeamSetupFailure { invalidCode, unavailable }

/// 팀 만들기·참여 콜백이 실패 이유를 화면에 알릴 때 던지는 예외.
class TeamSetupException implements Exception {
  /// 실패 이유 [reason]으로 예외를 만든다.
  const TeamSetupException(this.reason);

  final TeamSetupFailure reason;
}

/// 13 팀 만들기·참여 화면. 새 팀을 만들거나 6자리 초대 코드로 팀에 참여한다.
///
/// 성공하면 만들거나 참여한 팀을 돌려주며 닫힌다. 요청 중에는 뒤로 가기를 막는다.
class TeamSetupScreen extends StatefulWidget {
  /// 연결 여부 [isOnline], 초대 코드 입력에 먼저 커서를 둘지 [focusJoin], 만들기·참여 콜백으로 화면을 만든다.
  const TeamSetupScreen({
    super.key,
    this.isOnline = true,
    this.focusJoin = false,
    this.onCreate,
    this.onJoin,
  });

  final bool isOnline;
  final bool focusJoin;
  final Future<TeamViewData> Function(String name)? onCreate;
  final Future<TeamViewData> Function(String code)? onJoin;

  /// 입력값과 요청 진행 여부, 오류 문구를 관리할 상태를 만든다.
  @override
  State<TeamSetupScreen> createState() => _TeamSetupScreenState();
}

/// 팀 이름·초대 코드 입력값과 요청 진행 여부, 만들기·참여 쪽 오류 문구를 들고 있는 상태.
class _TeamSetupScreenState extends State<TeamSetupScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  bool _isJoining = false;
  String? _createError;
  String? _joinError;

  /// 팀 이름·초대 코드 입력 컨트롤러를 정리한다.
  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// [isJoining]에 따라 초대 코드로 참여하거나 입력한 이름으로 팀을 만든다.
  ///
  /// 앞뒤 공백을 지운 값이 비었거나 초대 코드가 6자리가 아니면 보내지 않는다. 성공하면 받은 팀을 돌려주며 닫고, 실패하면 이유에 맞는 오류 문구를 해당 입력칸에 보여 준다.
  Future<void> _submit({required bool isJoining}) async {
    if (_isSubmitting || !widget.isOnline) return;
    final value = (isJoining ? _codeController : _nameController).text.trim();
    if (value.isEmpty || (isJoining && value.length != 6)) return;
    final callback = isJoining ? widget.onJoin : widget.onCreate;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _isJoining = isJoining;
      _createError = null;
      _joinError = null;
    });
    try {
      if (callback == null) {
        throw const TeamSetupException(TeamSetupFailure.unavailable);
      }
      final team = await callback(value);
      if (!mounted) return;
      Navigator.of(context).pop(team);
    } catch (error) {
      if (!mounted) return;
      final message = switch (error) {
        TeamSetupException(reason: TeamSetupFailure.invalidCode) =>
          '해당 코드의 팀을 찾을 수 없습니다. 대소문자를 확인하고 다시 입력해 주세요.',
        TeamSetupException(reason: TeamSetupFailure.unavailable) =>
          '현재 팀 기능을 사용할 수 없습니다. 잠시 후 다시 시도해 주세요.',
        _ => '요청을 처리하지 못했습니다. 연결 상태를 확인하고 다시 시도해 주세요.',
      };
      setState(() {
        if (isJoining) {
          _joinError = message;
        } else {
          _createError = message;
        }
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// 뒤로 가기 버튼이 있는 앱 바 아래에 만들기·참여 입력 폼을 그린다. 입력을 고치면 그쪽 오류 문구를 지운다.
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('팀 만들기 · 참여'),
          leading: BackButton(
            onPressed: _isSubmitting
                ? null
                : () => Navigator.of(context).maybePop(),
          ),
        ),
        body: SafeArea(
          child: TeamSetupForm(
            nameController: _nameController,
            codeController: _codeController,
            isOnline: widget.isOnline,
            isSubmitting: _isSubmitting,
            isJoining: _isJoining,
            focusJoin: widget.focusJoin,
            createError: _createError,
            joinError: _joinError,
            onNameChanged: (_) => setState(() => _createError = null),
            onCodeChanged: (_) => setState(() => _joinError = null),
            onCreate: () => _submit(isJoining: false),
            onJoin: () => _submit(isJoining: true),
          ),
        ),
      ),
    );
  }
}
