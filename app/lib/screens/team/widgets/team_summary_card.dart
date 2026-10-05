import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/empty_placeholder.dart';
import '../../../widgets/initial_avatar.dart';
import '../team_view_data.dart';

class TeamSummaryCard extends StatelessWidget {
  const TeamSummaryCard({
    super.key,
    required this.team,
    required this.onCopyCode,
  });

  final TeamViewData team;
  final VoidCallback onCopyCode;

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
