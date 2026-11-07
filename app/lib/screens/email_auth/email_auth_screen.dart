import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../services/account_service.dart';
import 'widgets/email_auth_form.dart';

// 이메일·비밀번호 로그인과 회원가입을 처리하고 성공 결과를 이전 화면에 전달한다.
class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key, required this.service});

  final AccountService service;

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

// 입력값과 가입 모드, 요청 상태를 관리하고 중복 인증 요청을 막는다.
class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _isSigningUp = false;
  bool _isSubmitting = false;
  String? _error;

  // 화면이 닫히면 입력 컨트롤러와 비밀번호 입력 내용을 해제한다.
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  // 입력을 검증하고 가입 또는 로그인을 요청한다. 실패하면 입력 화면을 유지한다.
  Future<void> _submit() async {
    if (_isSubmitting || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final action = _isSigningUp
          ? widget.service.signUp
          : widget.service.signIn;
      await action(_email.text.trim(), _password.text);
      if (widget.service.currentAccount == null) {
        throw const AccountFailure('로그인 상태를 확인하지 못했습니다. 다시 시도해 주세요.');
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AccountFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '요청을 처리하지 못했습니다. 연결 상태를 확인하고 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // 가입·로그인 모드를 전환하고 이전 오류와 비밀번호를 지운다.
  void _switchMode() {
    if (_isSubmitting) return;
    setState(() {
      _isSigningUp = !_isSigningUp;
      _error = null;
      _password.clear();
      _confirmation.clear();
      _form.currentState?.reset();
    });
  }

  // 키보드나 작은 화면에서도 스크롤할 수 있는 인증 입력 화면을 구성한다.
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_isSubmitting,
    child: Scaffold(
      appBar: AppBar(
        title: Text(_isSigningUp ? '이메일 회원가입' : '이메일 로그인'),
        leading: BackButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: EmailAuthForm(
            formKey: _form,
            email: _email,
            password: _password,
            confirmation: _confirmation,
            isSigningUp: _isSigningUp,
            isSubmitting: _isSubmitting,
            error: _error,
            onSubmit: _submit,
            onSwitchMode: _switchMode,
          ),
        ),
      ),
    ),
  );
}
