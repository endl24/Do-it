import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

// 인증 입력값을 검증하고 로그인·가입·요청 중 상태를 표시한다.
class EmailAuthForm extends StatelessWidget {
  const EmailAuthForm({
    super.key,
    required this.formKey,
    required this.email,
    required this.password,
    required this.confirmation,
    required this.isSigningUp,
    required this.isSubmitting,
    required this.onSubmit,
    required this.onSwitchMode,
    this.error,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController confirmation;
  final bool isSigningUp;
  final bool isSubmitting;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onSwitchMode;

  // 필수 입력과 비밀번호 확인을 검증하고 인증 요청 중 입력·버튼을 비활성화한다.
  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const ValueKey('auth-email'),
            controller: email,
            enabled: !isSubmitting,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            autocorrect: false,
            decoration: const InputDecoration(labelText: '이메일'),
            validator: (value) =>
                RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value!.trim())
                ? null
                : '올바른 이메일 주소를 입력해 주세요.',
          ),
          const SizedBox(height: AppSpacing.md),
          _PasswordField(
            controller: password,
            isSigningUp: isSigningUp,
            isSubmitting: isSubmitting,
            onSubmit: onSubmit,
          ),
          if (isSigningUp) ...[
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey('auth-confirmation'),
              controller: confirmation,
              enabled: !isSubmitting,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                if (!isSubmitting) onSubmit();
              },
              decoration: const InputDecoration(labelText: '비밀번호 확인'),
              validator: (value) =>
                  value == password.text ? null : '비밀번호가 일치하지 않습니다.',
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: isSubmitting ? null : onSubmit,
            child: Text(isSigningUp ? '가입하기' : '로그인'),
          ),
          TextButton(
            onPressed: isSubmitting ? null : onSwitchMode,
            child: Text(isSigningUp ? '기존 계정으로 로그인' : '새 계정 만들기'),
          ),
          if (isSubmitting)
            const LinearProgressIndicator(semanticsLabel: '인증 요청 중'),
        ],
      ),
    ),
  );
}

// 비밀번호를 숨겨 입력받고 가입 시 최소 길이를 검증한다.
class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.isSigningUp,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isSigningUp;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  // 로그인·가입 모드에 맞는 자동 완성과 제출 동작을 구성한다.
  @override
  Widget build(BuildContext context) => TextFormField(
    key: const ValueKey('auth-password'),
    controller: controller,
    enabled: !isSubmitting,
    obscureText: true,
    autocorrect: false,
    enableSuggestions: false,
    autofillHints: [
      isSigningUp ? AutofillHints.newPassword : AutofillHints.password,
    ],
    textInputAction: isSigningUp ? TextInputAction.next : TextInputAction.done,
    onFieldSubmitted: (_) {
      if (!isSigningUp && !isSubmitting) onSubmit();
    },
    decoration: const InputDecoration(labelText: '비밀번호'),
    validator: (value) {
      if (value == null || value.isEmpty) return '비밀번호를 입력해 주세요.';
      if (isSigningUp && value.length < 6) {
        return '비밀번호는 6자 이상 입력해 주세요.';
      }
      return null;
    },
  );
}
