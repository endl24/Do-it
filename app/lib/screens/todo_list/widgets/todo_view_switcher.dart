import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// 할 일을 목록 또는 사분면으로 보는 방식을 나타낸다.
enum TodoViewMode { list, quadrant }

/// 목록과 사분면 보기 사이를 바꾸는 세그먼트 버튼이다.
class TodoViewSwitcher extends StatelessWidget {
  /// 현재 [selected] 보기와 변경 처리 함수를 받는다.
  const TodoViewSwitcher({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final TodoViewMode selected;
  final ValueChanged<TodoViewMode> onChanged;

  /// 두 보기 방식을 선택할 수 있는 세그먼트 버튼을 구성한다.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<TodoViewMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: TodoViewMode.list,
              icon: Icon(Icons.view_list_outlined),
              label: Text('목록'),
            ),
            ButtonSegment(
              value: TodoViewMode.quadrant,
              icon: Icon(Icons.grid_view_outlined),
              label: Text('사분면'),
            ),
          ],
          selected: {selected},
          onSelectionChanged: (values) => onChanged(values.single),
        ),
      ),
    );
  }
}
