import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/empty_placeholder.dart';
import '../../../widgets/initial_avatar.dart';
import '../team_view_data.dart';

/// 12 팀 화면 위쪽의 팀 요약 카드. 팀 이름, 구성원·공유 할 일 수, 구성원 아바타와 초대 코드를 보여 준다.
class TeamSummaryCard extends StatelessWidget {
  /// 보여 줄 팀 [team]과 초대 코드 복사 동작 [onCopyCode]로 카드를 만든다.
  const TeamSummaryCard({
    super.key,
    required this.team,
    required this.onCopyCode,
  });

  final TeamViewData team;
  final VoidCallback onCopyCode;

  /// 팀 이름과 수를 아바타와 한 줄에 두고, 아래 점선 상자에 초대 코드와 [복사] 버튼을 그린다. 화면 읽기 프로그램은 아바타 대신 구성원 이름을 읽는다.
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name,
                        style: AppTextStyles.cardTitle.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '구성원 ${team.memberNames.length}명 · '
                        '공유 할 일 ${team.todos.length}건',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Semantics(
                  label: '팀 구성원: ${team.memberNames.join(', ')}',
                  excludeSemantics: true,
                  child: AvatarStack(names: team.memberNames),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            DashedBorderBox(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '초대 코드',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        SelectableText(
                          team.inviteCode,
                          style: AppTextStyles.inviteCode.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, AppSize.fabSmall),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    onPressed: onCopyCode,
                    child: const Text('복사'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
