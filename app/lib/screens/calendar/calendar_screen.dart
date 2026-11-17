import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/empty_placeholder.dart';
import '../../widgets/todo_card.dart';

/// 10 일정 화면에 표시할 마감 할 일 하나. 화면이 할 일 모델에 묶이지 않도록 보여 줄 값과 누를 때 동작만 담는다.
class CalendarDeadline {
  /// 제목·사분면·마감일·완료 여부와 누를 때 동작으로 마감 항목을 만든다.
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

/// 10 일정 화면. 한 달 달력에 마감일이 있는 할 일을 표시하고, 고른 날짜의 할 일 목록을 보여 준다.
class CalendarScreen extends StatefulWidget {
  /// 달력에 표시할 마감 목록 [deadlines]와 처음 선택할 날짜 [initialDate]로 일정 화면을 만든다.
  const CalendarScreen({
    super.key,
    this.deadlines = const [],
    this.initialDate,
  });

  final List<CalendarDeadline> deadlines;
  final DateTime? initialDate;

  /// 선택한 날짜를 관리할 상태를 만든다.
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

/// 지금 선택된 날짜를 들고, 달 이동과 날짜 선택에 따라 달력과 목록을 다시 그리는 상태.
class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedDate;

  /// 오늘(또는 [CalendarScreen.initialDate])을 처음 선택된 날짜로 정한다.
  ///
  /// 시각은 버리고 날짜만 남겨 같은 날 비교가 어긋나지 않게 한다.
  @override
  void initState() {
    super.initState();
    final today = widget.initialDate ?? DateTime.now();
    _selectedDate = DateTime(today.year, today.month, today.day);
  }

  /// [offset]만큼 이전·다음 달로 이동한다.
  ///
  /// 옮긴 달에 같은 날짜가 없으면(예: 1월 31일 → 2월) 그 달의 마지막 날로 보정한다.
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

  /// 선택한 날짜에 마감인 할 일을 골라, 위에는 월 머리글과 달력을, 아래에는 그날의 마감 목록을 그린다.
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

/// 달력 위에 연월 제목과 이전·다음 달 버튼을 보여 주는 머리글.
class _MonthHeader extends StatelessWidget {
  /// 표시할 달 [date]와 이전·다음 달 동작으로 머리글을 만든다.
  const _MonthHeader({
    required this.date,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// 가운데 'yyyy년 m월' 제목과 양옆 화살표 버튼을 한 줄로 그린다.
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

/// 한 달 날짜를 요일 칸에 맞춰 보여 주고, 좌우로 밀어 달을 넘기는 달력 격자.
class _MonthGrid extends StatefulWidget {
  /// 기준 날짜 [date], 마감 목록, 날짜 선택·달 이동 동작으로 격자를 만든다.
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

  /// 가로로 민 거리를 관리할 상태를 만든다.
  @override
  State<_MonthGrid> createState() => _MonthGridState();
}

/// 가로로 민 거리를 모아 두었다가 기준 거리를 넘으면 달을 넘기는 상태.
class _MonthGridState extends State<_MonthGrid> {
  static const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];
  static const _swipeThreshold = 48.0;

  double _dragDistance = 0;

  /// 달의 첫 요일과 날짜 수로 필요한 주 수를 계산해 요일 머리글과 날짜 칸을 그린다.
  ///
  /// 왼쪽으로 [_swipeThreshold] 넘게 밀면 다음 달, 오른쪽으로 밀면 이전 달로 넘긴다.
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

  /// [day]일 칸을 만든다. 이 달 범위를 벗어난 앞뒤 칸은 빈칸으로 둔다.
  ///
  /// 그날 마감인 할 일의 사분면 색을 겹치지 않게 최대 3개까지 점으로 표시한다.
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

/// 날짜 숫자와 마감 표시 점을 보여 주는 달력 한 칸. 선택된 날은 배경을 채운다.
class _DayCell extends StatelessWidget {
  /// 날짜·선택 여부·표시 점 색·누를 때 동작으로 칸을 만든다.
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

  /// 일요일·토요일·선택 여부에 따라 글자색을 정하고, 날짜 숫자 아래에 마감 표시 점을 그린다. 화면 읽기 프로그램에는 연월일로 읽힌다.
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

/// 달력 아래에서 고른 날짜와 마감 건수, 그날 마감인 할 일 카드를 보여 주는 영역.
class _DateDetails extends StatelessWidget {
  /// 고른 날짜 [date]와 그날 마감 목록 [deadlines]로 영역을 만든다.
  const _DateDetails({required this.date, required this.deadlines});

  static const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  final DateTime date;
  final List<CalendarDeadline> deadlines;

  /// 날짜·요일과 마감 건수를 머리에 두고, 마감 할 일 카드와 끝의 '다른 마감 없음' 안내를 이어 그린다.
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
        const EmptyPlaceholder(message: '이 날짜에 다른 마감은 없습니다'),
      ],
    );
  }
}
