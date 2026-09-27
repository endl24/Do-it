import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/empty_placeholder.dart';
import '../../widgets/todo_card.dart';

class CalendarDeadline {
  const CalendarDeadline({
    required this.title,
    required this.isImportant,
    required this.isUrgent,
    this.dueDate,
    this.isDone = false,
    this.onTap,
    this.onDoneChanged,
  });

  final String title;
  final DateTime? dueDate;
  final bool isImportant;
  final bool isUrgent;
  final bool isDone;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onDoneChanged;
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    this.deadlines = const [],
    this.initialDate,
  });

  final List<CalendarDeadline> deadlines;
  final DateTime? initialDate;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final today = widget.initialDate ?? DateTime.now();
    _selectedDate = DateTime(today.year, today.month, today.day);
  }

  void _moveMonth(int offset) {
    setState(() {
      final targetMonth = DateTime(
        _selectedDate.year,
        _selectedDate.month + offset,
      );
      final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
      final day = _selectedDate.day <= lastDay ? _selectedDate.day : lastDay;
      _selectedDate = DateTime(targetMonth.year, targetMonth.month, day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedDeadlines = widget.deadlines.where((deadline) {
      final dueDate = deadline.dueDate;
      return dueDate != null && DateUtils.isSameDay(dueDate, _selectedDate);
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.xl,
                AppSpacing.screenHorizontal,
                AppSpacing.sectionGap,
              ),
              child: Column(
                children: [
                  _MonthHeader(
                    date: _selectedDate,
                    onPrevious: () => _moveMonth(-1),
                    onNext: () => _moveMonth(1),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _MonthGrid(
                    date: _selectedDate,
                    deadlines: widget.deadlines,
                    onSelect: (date) => setState(() => _selectedDate = date),
                    onPrevious: () => _moveMonth(-1),
                    onNext: () => _moveMonth(1),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.lg,
                AppSpacing.screenHorizontal,
                AppSpacing.xxl,
              ),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: _DateDetails(
                date: _selectedDate,
                deadlines: selectedDeadlines,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.date,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: '이전 달',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            '${date.year}년 ${date.month}월',
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          tooltip: '다음 달',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatefulWidget {
  const _MonthGrid({
    required this.date,
    required this.deadlines,
    required this.onSelect,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime date;
  final List<CalendarDeadline> deadlines;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  State<_MonthGrid> createState() => _MonthGridState();
}

class _MonthGridState extends State<_MonthGrid> {
  static const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];
  static const _swipeThreshold = 48.0;

  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) {
    final firstWeekday =
        DateTime(widget.date.year, widget.date.month).weekday % 7;
    final daysInMonth = DateTime(
      widget.date.year,
      widget.date.month + 1,
      0,
    ).day;
    final weekCount = ((firstWeekday + daysInMonth) / 7).ceil();

    return GestureDetector(
      key: const ValueKey('calendar-month-grid'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _dragDistance = 0,
      onHorizontalDragUpdate: (details) => _dragDistance += details.delta.dx,
      onHorizontalDragEnd: (_) {
        if (_dragDistance <= -_swipeThreshold) widget.onNext();
        if (_dragDistance >= _swipeThreshold) widget.onPrevious();
        _dragDistance = 0;
      },
      child: Column(
        children: [
          Row(
            children: [
              for (var weekday = 0; weekday < 7; weekday++)
                Expanded(
                  child: Center(
                    child: Text(
                      _weekdays[weekday],
                      style: AppTextStyles.fieldLabel.copyWith(
                        color: weekday == 0
                            ? AppColors.calendarSunday
                            : weekday == 6
                            ? AppColors.calendarSaturday
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var week = 0; week < weekCount; week++)
            Row(
              children: [
                for (var weekday = 0; weekday < 7; weekday++)
                  Expanded(
                    child: _buildDay(
                      week * 7 + weekday - firstWeekday + 1,
                      daysInMonth,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDay(int day, int daysInMonth) {
    if (day < 1 || day > daysInMonth) {
      return const SizedBox(height: AppSize.fab);
    }

    final dayDate = DateTime(widget.date.year, widget.date.month, day);
    final colors = widget.deadlines
        .where(
          (deadline) =>
              deadline.dueDate != null &&
              DateUtils.isSameDay(deadline.dueDate, dayDate),
        )
        .map(
          (deadline) => QuadrantColors.of(
            isImportant: deadline.isImportant,
            isUrgent: deadline.isUrgent,
          ).foreground,
        )
        .toSet()
        .take(3)
        .toList();

    return _DayCell(
      date: dayDate,
      isSelected: DateUtils.isSameDay(dayDate, widget.date),
      markerColors: colors,
      onTap: () => widget.onSelect(dayDate),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isSelected,
    required this.markerColors,
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final List<Color> markerColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = isSelected
        ? AppColors.onPrimary
        : date.weekday == DateTime.sunday
        ? AppColors.calendarSunday
        : date.weekday == DateTime.saturday
        ? AppColors.calendarSaturday
        : AppColors.textPrimary;

    return Semantics(
      label: '${date.year}년 ${date.month}월 ${date.day}일',
      selected: isSelected,
      button: true,
      child: InkWell(
        key: ValueKey('calendar-day-${date.year}-${date.month}-${date.day}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          height: AppSize.fab,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: AppSize.fabSmall,
                height: AppSize.chipHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : null,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  '${date.day}',
                  style: AppTextStyles.body.copyWith(
                    color: textColor,
                    fontWeight: isSelected ? FontWeight.w800 : null,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              SizedBox(
                height: AppSize.statusDot,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final color in markerColors)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: AppSize.statusDot - 2,
                        height: AppSize.statusDot - 2,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.onPrimary : color,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateDetails extends StatelessWidget {
  const _DateDetails({required this.date, required this.deadlines});

  static const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  final DateTime date;
  final List<CalendarDeadline> deadlines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${date.month}월 ${date.day}일 '
                '(${_weekdays[date.weekday % 7]})',
                style: AppTextStyles.itemTitle.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '마감 ${deadlines.length}건',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (deadlines.isEmpty)
          const EmptyPlaceholder(message: '이 날짜에 다른 마감은 없습니다')
        else
          for (final deadline in deadlines) ...[
            TodoCard(
              title: deadline.title,
              isImportant: deadline.isImportant,
              isUrgent: deadline.isUrgent,
              isDone: deadline.isDone,
              onTap: deadline.onTap,
              onDoneChanged: deadline.onDoneChanged,
            ),
            const SizedBox(height: AppSpacing.listGap),
          ],
      ],
    );
  }
}
