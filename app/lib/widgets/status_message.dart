import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// 화면 가운데에 크게 보여주는 상태 안내. 예) 빈 할 일 목록, 텍스트 인식 실패
class StatusMessage extends StatelessWidget {
  /// [title]과 선택 [description]·[illustration]으로 상태 안내를 만든다.
  const StatusMessage({
    super.key,
    required this.title,
    this.description,
    this.illustration,
  });

  /// 제목 위에 둘 그림. 아이콘이면 [StatusMessage.icon]을 쓴다.
  final Widget? illustration;
  final String title;
  final String? description;

  /// 원형 배경 위 아이콘을 그림으로 쓰는 생성자
  StatusMessage.icon({
    super.key,
    required IconData icon,
    required this.title,
    this.description,
    bool isError = false,
  }) : illustration = _IconCircle(icon: icon, isError: isError);

  /// 그림, 제목, 설명을 가운데 정렬로 세로로 쌓는다.
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (illustration != null) ...[
          illustration!,
          const SizedBox(height: AppSpacing.xl),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.headlineSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            description!,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// 상태 안내 위에 두는 원형 배경 아이콘.
class _IconCircle extends StatelessWidget {
  /// 보여 줄 [icon]과 오류 여부로 원형 아이콘을 만든다.
  const _IconCircle({required this.icon, required this.isError});

  static const _size = 96.0;

  final IconData icon;
  final bool isError;

  /// 오류면 빨간 색, 아니면 기본 색으로 원과 아이콘을 그린다.
  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: isError ? AppColors.dangerContainer : AppColors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 36,
        color: isError ? AppColors.danger : AppColors.primary,
      ),
    );
  }
}
