import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// 이름 첫 글자를 보여주는 원형 아바타. 같은 이름은 항상 같은 색을 받는다.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({super.key, required this.name, this.size});

  const InitialAvatar.small({super.key, required this.name})
    : size = AppSize.avatarSmall;

  final String name;
  final double? size;

  static const _palettes = [
    QuadrantColors.importantNotUrgent,
    QuadrantColors.notImportantUrgent,
    QuadrantColors.notImportantNotUrgent,
    QuadrantColors.importantUrgent,
  ];

  @override
  Widget build(BuildContext context) {
    final avatarSize = size ?? AppSize.avatar;
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed.characters.first;
    final codeSum = trimmed.codeUnits.fold(0, (sum, unit) => sum + unit);
    final palette = _palettes[codeSum % _palettes.length];
    final isSmall = avatarSize <= AppSize.avatarSmall;

    return Container(
      width: avatarSize,
      height: avatarSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.tagBackground,
        shape: BoxShape.circle,
        border: isSmall ? Border.all(color: AppColors.surface, width: 2) : null,
      ),
      child: Text(
        initial,
        style: (isSmall ? AppTextStyles.tag : AppTextStyles.cardTitle).copyWith(
          color: palette.foreground,
          height: 1,
        ),
      ),
    );
  }
}

/// 겹쳐 놓은 아바타 묶음. 팀 카드의 구성원 표시에 쓴다.
class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key, required this.names, this.maxCount = 4});

  final List<String> names;
  final int maxCount;

  static const _overlap = 6.0;

  @override
  Widget build(BuildContext context) {
    final visible = names.take(maxCount).toList();
    const step = AppSize.avatarSmall - _overlap;

    return SizedBox(
      height: AppSize.avatarSmall,
      width: visible.isEmpty
          ? 0
          : step * (visible.length - 1) + AppSize.avatarSmall,
      child: Stack(
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: step * i,
              child: InitialAvatar.small(name: visible[i]),
            ),
        ],
      ),
    );
  }
}
