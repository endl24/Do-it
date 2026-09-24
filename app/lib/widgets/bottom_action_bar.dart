import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';

/// 화면 아래에 고정되는 버튼 영역. `Scaffold.bottomNavigationBar`에 넣어 쓴다.
///
/// 버튼을 위에서 아래로 쌓는다. 예) [등록하기], [완료로 표시 / 삭제]
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.sm,
          AppSpacing.screenHorizontal,
          0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
