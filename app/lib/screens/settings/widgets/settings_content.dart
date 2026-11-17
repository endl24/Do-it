import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/danger_button.dart';
import '../../../widgets/grouped_card.dart';
import '../../../widgets/initial_avatar.dart';
import '../../../widgets/section_header.dart';
import '../../notification_settings/notification_settings.dart';

/// 14 설정 화면의 본문. 프로필·닉네임 카드, 알림·권한·동기화 줄, 계정 연동·로그아웃 줄과 회원 탈퇴 버튼을 보여 준다.
class SettingsContent extends StatelessWidget {
  /// 닉네임 입력 상태, 계정 연동·동기화 대기·알림·권한 표시 값과 각 줄을 눌렀을 때 동작으로 본문을 만든다.
  const SettingsContent({
    super.key,
    required this.name,
    required this.controller,
    required this.focus,
    required this.isBusy,
    required this.isLinked,
    this.accountEmail,
    required this.pendingCount,
    required this.notifications,
    required this.permissions,
    required this.onNameChanged,
    this.onNotifications,
    this.onPermissions,
    this.onLink,
    this.onLogout,
    this.onDelete,
  });
  final String name;
  final TextEditingController controller;
  final FocusNode focus;
  final bool isBusy;
  final bool isLinked;
  final String? accountEmail;
  final int pendingCount;
  final NotificationSettings notifications;
  final String permissions;
  final ValueChanged<String> onNameChanged;
  final VoidCallback? onNotifications;
  final VoidCallback? onPermissions;
  final VoidCallback? onLink;
  final VoidCallback? onLogout;
  final VoidCallback? onDelete;

  /// 프로필 카드 아래에 상태 줄 묶음, 계정 줄 묶음, 회원 탈퇴 버튼과 안내 문구를 차례로 그린다. 연동돼 있으면 계정 줄에 이메일을 보여 준다.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ProfileCard(
        name: name,
        controller: controller,
        focus: focus,
        isBusy: isBusy,
        isLinked: isLinked,
        onNameChanged: onNameChanged,
      ),
      const SizedBox(height: AppSpacing.md),
      GroupedCard(
        children: [
          LabelValueRow(
            label: '알림',
            value: notifications.isEnabled
                ? '켜짐 · ${formatSendTime(notifications.sendTime)}'
                : '꺼짐',
            onTap: onNotifications,
          ),
          LabelValueRow(
            label: '권한',
            description: permissions,
            onTap: onPermissions,
          ),
          LabelValueRow(
            label: '동기화',
            value: pendingCount > 0 ? '대기 $pendingCount건' : '대기 없음',
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      GroupedCard(
        children: [
          LabelValueRow(
            label: '계정 연동',
            value: isLinked ? '연동됨' : '연동하기',
            description: isLinked && accountEmail != null
                ? accountEmail
                : '다른 기기에서도 같은 할 일을 이어서 사용',
            onTap: onLink,
          ),
          LabelValueRow(label: '로그아웃', onTap: onLogout),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      DangerButton(label: '회원 탈퇴', onPressed: onDelete),
      const SizedBox(height: AppSpacing.md),
      Text(
        '탈퇴하면 계정과 계정에 연결된 할 일이 모두 삭제됩니다',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.xxl),
    ],
  );
}

/// 아바타·닉네임·연동 상태와 닉네임 입력칸을 보여 주는 프로필 카드.
class _ProfileCard extends StatelessWidget {
  /// 저장한 닉네임, 입력 컨트롤러·포커스, 요청 중·연동 여부와 입력 동작으로 카드를 만든다.
  const _ProfileCard({
    required this.name,
    required this.controller,
    required this.focus,
    required this.isBusy,
    required this.isLinked,
    required this.onNameChanged,
  });
  final String name;
  final TextEditingController controller;
  final FocusNode focus;
  final bool isBusy;
  final bool isLinked;
  final ValueChanged<String> onNameChanged;

  /// 저장한 닉네임으로 아바타와 이름을 보여 주고, 아래에 12자까지 받는 닉네임 입력칸과 글자 수를 그린다. 완료하거나 입력칸 밖을 누르면 포커스를 빼서 저장되게 한다.
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialAvatar(name: name),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.cardTitle),
                    Text(
                      isLinked ? '연동된 계정으로 로그인됨' : '계정이 연동되지 않았습니다',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SectionHeader.counter(
            title: '닉네임',
            length: controller.text.characters.length,
            maxLength: 12,
          ),
          TextField(
            key: const ValueKey('nickname-input'),
            controller: controller,
            focusNode: focus,
            enabled: !isBusy,
            inputFormatters: [LengthLimitingTextInputFormatter(12)],
            onChanged: onNameChanged,
            onEditingComplete: focus.unfocus,
            onTapOutside: (_) => focus.unfocus(),
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: '닉네임을 입력해 주세요'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '한글, 영문, 숫자 12자까지 쓸 수 있습니다',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}
