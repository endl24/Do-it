import 'package:flutter/material.dart';

import '../../../models/todo.dart';

class TodoCard extends StatelessWidget {
  const TodoCard({
    required this.todo,
    required this.onToggle,
    required this.onTap,
    super.key,
  });

  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(todo.quadrant);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                label: todo.isCompleted ? '미완료로 표시' : '완료로 표시',
                child: Checkbox(
                  value: todo.isCompleted,
                  onChanged: (_) => onToggle(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      todo.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            decoration: todo.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: todo.isCompleted
                                ? const Color(0xFF969188)
                                : null,
                          ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.$1,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            child: Text(
                              todo.quadrant.description,
                              style: TextStyle(
                                color: colors.$2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          _dueLabel(todo.dueDate),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: _isDueToday(todo.dueDate)
                                    ? const Color(0xFFC4473D)
                                    : const Color(0xFF77736A),
                                fontWeight: _isDueToday(todo.dueDate)
                                    ? FontWeight.w700
                                    : null,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!todo.isCompleted)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Icon(Icons.circle, size: 10, color: colors.$2),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static (Color, Color) _colorsFor(TodoQuadrant quadrant) {
    return switch (quadrant) {
      TodoQuadrant.doNow =>
        (const Color(0xFFF8E0DD), const Color(0xFFB84037)),
      TodoQuadrant.schedule =>
        (const Color(0xFFDDEFEA), const Color(0xFF246F63)),
      TodoQuadrant.delegate =>
        (const Color(0xFFF7ECD2), const Color(0xFF91640C)),
      TodoQuadrant.eliminate =>
        (const Color(0xFFE8EDF3), const Color(0xFF526172)),
    };
  }

  static bool _isDueToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  static String _dueLabel(DateTime? date) {
    if (date == null) return '마감일 없음';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(date.year, date.month, date.day);
    if (due == today) return '오늘 마감';
    if (due == today.add(const Duration(days: 1))) return '내일';
    return '${date.month}월 ${date.day}일';
  }
}
