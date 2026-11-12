import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// 점선 테두리 안에 비어 있음을 알리는 박스. 예) 필터 결과 없음, 날짜별 마감 없음
class EmptyPlaceholder extends StatelessWidget {
  /// [message]와 선택 설명·아이콘으로 빈 상태 박스를 만든다.
  const EmptyPlaceholder({
    super.key,
    required this.message,
    this.description,
    this.icon,
    this.onTap,
  });

  /// 필터 때문에 보일 항목이 없을 때. 누르면 [onResetFilter]로 필터를 '전체'로 되돌린다 (16).
  const EmptyPlaceholder.filtered({
    super.key,
    required VoidCallback onResetFilter,
  }) : message = '조건에 맞는 할 일이 없습니다',
       description = "필터를 '전체'로 바꿔 보세요",
       icon = Icons.search,
       onTap = onResetFilter;

  final String message;
  final String? description;
  final IconData? icon;

  /// 박스 전체를 누를 수 있게 한다.
  final VoidCallback? onTap;

  /// [onTap]이 있으면 박스 전체를 버튼처럼 누를 수 있게 감싼다.
  @override
  Widget build(BuildContext context) {
    final box = _buildBox();
    if (onTap == null) return box;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: box,
      ),
    );
  }

  /// 점선 박스 안에 아이콘·안내 문구·설명을 그린다.
  ///
  /// 아이콘이 있으면 가운데 정렬로 크게, 없으면 왼쪽 정렬로 작게 보여 준다.
  Widget _buildBox() {
    final hasIcon = icon != null;

    return DashedBorderBox(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: hasIcon ? AppSpacing.xl : AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: hasIcon
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (hasIcon) ...[
            Icon(icon, size: AppSize.iconMd, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            message,
            textAlign: hasIcon ? TextAlign.center : TextAlign.start,
            style: (hasIcon ? AppTextStyles.itemTitle : AppTextStyles.bodySmall)
                .copyWith(
                  color: hasIcon ? AppColors.textLabel : AppColors.textTertiary,
                ),
          ),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              description!,
              textAlign: hasIcon ? TextAlign.center : TextAlign.start,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 점선 테두리 박스. 제외된 인식 후보, 빈 목록 자리 등에 쓴다.
class DashedBorderBox extends StatelessWidget {
  /// 기본 여백·배경색·테두리 색·모서리 반경으로 점선 박스를 만든다.
  const DashedBorderBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color = AppColors.surfaceSubtle,
    this.borderColor = AppColors.borderStrong,
    this.radius = AppRadius.md,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double radius;

  /// 배경 상자 위에 점선 테두리를 덧그린다.
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(
        color: borderColor,
        radius: radius,
      ),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
}

/// 둥근 사각형 테두리를 점선으로 그리는 페인터.
class _DashedBorderPainter extends CustomPainter {
  /// 테두리 색과 모서리 반경을 받아 페인터를 만든다.
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dashLength = 4.0;
  static const _gapLength = 3.0;

  /// 둥근 사각형 둘레를 따라가며 [_dashLength]만큼 그리고 [_gapLength]만큼 띄우기를 반복한다.
  ///
  /// 선 두께의 절반만큼 안쪽으로 들여 그려서 테두리가 잘리지 않게 한다.
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSize.borderWidth;
    const inset = AppSize.borderWidth / 2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - inset * 2,
        size.height - inset * 2,
      ),
      Radius.circular(radius),
    );

    final dashed = Path();
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      for (var distance = 0.0; distance < metric.length;) {
        dashed.addPath(
          metric.extractPath(distance, distance + _dashLength),
          Offset.zero,
        );
        distance += _dashLength + _gapLength;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  /// 색이나 모서리 반경이 바뀌었을 때만 다시 그린다.
  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}
