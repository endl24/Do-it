import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

enum TodoViewMode { list, quadrant }

class TodoViewSwitcher extends StatelessWidget {
  const TodoViewSwitcher({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final TodoViewMode selected;
  final ValueChanged<TodoViewMode> onChanged;

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
