import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// 목록을 불러오는 동안 보여주는 회색 자리 표시. 은은하게 깜빡인다.
class SkeletonList extends StatefulWidget {
  /// [itemHeight] 높이의 자리 표시를 [itemCount]개 보여 주는 목록을 만든다.
  const SkeletonList({super.key, this.itemCount = 3, this.itemHeight = 60});

  final int itemCount;
  final double itemHeight;

  /// 깜빡임 애니메이션을 관리할 상태를 만든다.
  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

/// 자리 표시가 깜빡이는 애니메이션을 돌리는 상태.
class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  /// 화면을 떠날 때 애니메이션 컨트롤러를 정리한다.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 회색 상자들을 세로로 쌓고, 투명도를 오가며 깜빡이게 그린다. 화면 읽기 프로그램에는 '불러오는 중'으로 알린다.
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '불러오는 중',
      child: FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0.5).animate(_controller),
        child: Column(
          children: [
            for (var i = 0; i < widget.itemCount; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.xs),
              Container(
                height: widget.itemHeight,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
