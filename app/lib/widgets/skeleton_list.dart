import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// 목록을 불러오는 동안 보여주는 회색 자리 표시. 은은하게 깜빡인다.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.itemCount = 3, this.itemHeight = 60});

  final int itemCount;
  final double itemHeight;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
