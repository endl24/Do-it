import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/notice_box.dart';
import '../../../widgets/section_header.dart';

class TeamSetupForm extends StatelessWidget {
  const TeamSetupForm({
    super.key,
    required this.nameController,
    required this.codeController,
    required this.isOnline,
    required this.isSubmitting,
    required this.isJoining,
    required this.focusJoin,
    required this.createError,
    required this.joinError,
    required this.onNameChanged,
    required this.onCodeChanged,
    required this.onCreate,
    required this.onJoin,
  });

  final TextEditingController nameController;
  final TextEditingController codeController;
  final bool isOnline;
  final bool isSubmitting;
  final bool isJoining;
  final bool focusJoin;
  final String? createError;
  final String? joinError;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onCodeChanged;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final isEnabled = isOnline && !isSubmitting;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      children: [
        _FormCard(
          title: '새 팀 만들기',
          children: [
            SectionHeader.counter(
              title: '팀 이름',
              length: nameController.text.characters.length,
              maxLength: 20,
            ),
            TextField(
              key: const ValueKey('team-name-input'),
              controller: nameController,
              enabled: isEnabled,
              autofocus: !focusJoin,
              inputFormatters: [LengthLimitingTextInputFormatter(20)],
              textInputAction: TextInputAction.done,
              onChanged: onNameChanged,
              onSubmitted: (_) => onCreate(),
              decoration: InputDecoration(
                hintText: '팀 이름을 입력해 주세요',
                errorText: createError,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: isEnabled && nameController.text.trim().isNotEmpty
                  ? onCreate
                  : null,
              child: Text(
                isSubmitting && !isJoining ? '팀 만드는 중…' : '팀 만들고 초대 코드 받기',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '만들면 6자리 초대 코드가 발급되고, 만든 사람이 첫 구성원이 됩니다.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text('또는'),
              ),
              Expanded(child: Divider()),
            ],
          ),
        ),
        _JoinCard(
          controller: codeController,
          isEnabled: isEnabled,
          isLoading: isSubmitting && isJoining,
          autofocus: focusJoin,
          error: joinError,
          onChanged: onCodeChanged,
          onJoin: onJoin,
        ),
        const SizedBox(height: AppSpacing.lg),
        const NoticeBox(
          message: '팀 기능은 네트워크 연결이 필요합니다. 오프라인에서는 내 할 일만 사용할 수 있어요.',
        ),
        if (!isOnline) ...[
          const SizedBox(height: AppSpacing.sm),
          const NoticeBox.error(message: '팀 기능은 연결된 뒤에 사용할 수 있습니다'),
        ],
      ],
    );
  }
}

class _JoinCard extends StatelessWidget {
  const _JoinCard({
    required this.controller,
    required this.isEnabled,
    required this.isLoading,
    required this.autofocus,
    required this.error,
    required this.onChanged,
    required this.onJoin,
  });

  final TextEditingController controller;
  final bool isEnabled;
  final bool isLoading;
  final bool autofocus;
  final String? error;
  final ValueChanged<String> onChanged;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final errorBorder = error == null
        ? null
        : OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.danger),
          );
    return _FormCard(
      title: '초대 코드로 참여',
      children: [
        const SectionHeader(title: '초대 코드 6자리'),
        TextField(
          key: const ValueKey('team-code-input'),
          controller: controller,
          enabled: isEnabled,
          autofocus: autofocus,
          textAlign: TextAlign.center,
          style: AppTextStyles.inviteCode.copyWith(
            color: AppColors.textPrimary,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(6),
          ],
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onChanged: onChanged,
          onSubmitted: (_) => onJoin(),
          decoration: InputDecoration(
            hintText: '초대 코드 입력',
            enabledBorder: errorBorder,
            focusedBorder: errorBorder,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          NoticeBox.error(message: error!),
        ],
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: isEnabled && controller.text.length == 6 ? onJoin : null,
          child: Text(isLoading ? '참여하는 중…' : '참여하기'),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: AppTextStyles.cardTitle.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}
