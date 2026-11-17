import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/notice_box.dart';
import '../../../widgets/section_header.dart';

/// 13 팀 만들기·참여 화면의 입력 폼. 새 팀 만들기 카드와 초대 코드 참여 카드, 연결 안내를 보여 준다.
class TeamSetupForm extends StatelessWidget {
  /// 입력 컨트롤러, 연결·요청 상태, 오류 문구와 입력·제출 동작으로 폼을 만든다.
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

  /// 팀 이름 입력 카드와 '또는' 구분선, 초대 코드 참여 카드, 네트워크 안내를 차례로 그린다.
  ///
  /// 연결이 끊겼거나 요청 중이면 입력과 버튼을 막는다. 팀 이름은 20자까지 받고 비어 있으면 [만들기]를 막는다.
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

/// 6자리 초대 코드를 입력해 팀에 참여하는 카드.
class _JoinCard extends StatelessWidget {
  /// 입력 컨트롤러, 사용 가능·요청 중 여부, 오류 문구와 입력·참여 동작으로 카드를 만든다.
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

  /// 영문·숫자만 6자리까지 받는 가운데 정렬 입력칸과 [참여하기] 버튼을 그린다. 오류가 있으면 입력칸 테두리를 빨갛게 하고 아래에 오류 안내를 띄운다.
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

/// 제목과 내용을 카드 안에 묶어 보여 주는 폼 카드 틀.
class _FormCard extends StatelessWidget {
  /// 카드 제목 [title]과 내용 [children]으로 카드를 만든다.
  const _FormCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  /// 제목 아래에 내용 위젯을 가로로 꽉 채워 쌓는다.
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
