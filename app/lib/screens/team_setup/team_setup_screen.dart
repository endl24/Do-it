import 'package:flutter/material.dart';

import '../team/team_view_data.dart';
import 'widgets/team_setup_form.dart';

enum TeamSetupFailure { invalidCode, unavailable }

class TeamSetupException implements Exception {
  const TeamSetupException(this.reason);

  final TeamSetupFailure reason;
}

class TeamSetupScreen extends StatefulWidget {
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

  @override
  State<TeamSetupScreen> createState() => _TeamSetupScreenState();
}

class _TeamSetupScreenState extends State<TeamSetupScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  bool _isJoining = false;
  String? _createError;
  String? _joinError;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

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
