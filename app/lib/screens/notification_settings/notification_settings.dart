import 'package:flutter/material.dart';

/// 반복 알림을 켜고 끌 수 있는 분류(A28). 비중요·비긴급은 반복 알림이 없다.
enum RepeatCategory {
  importantUrgent(isImportant: true, isUrgent: true, timesPerDay: 3),
  importantNotUrgent(isImportant: true, isUrgent: false, timesPerDay: 1),
  notImportantUrgent(isImportant: false, isUrgent: true, timesPerDay: 1);

  /// 분류별 중요도·긴급도와 하루 반복 횟수를 정한다.
  const RepeatCategory({
    required this.isImportant,
    required this.isUrgent,
    required this.timesPerDay,
  });

  final bool isImportant;
  final bool isUrgent;
  final int timesPerDay;
}

/// 11 알림 설정 화면에서 바꾸는 값(A33).
// TODO(강두이): 공통 모델(A7)이 확정되면 models/로 옮기고 단말에 저장한다.
@immutable
class NotificationSettings {
  /// 설정 값을 만든다. 주지 않은 값은 알림 켬, 오전 9시, 반복 알림 세 분류 모두 켬으로 정한다.
  const NotificationSettings({
    this.isEnabled = true,
    this.sendTime = const TimeOfDay(hour: 9, minute: 0),
    this.repeatCategories = const {
      RepeatCategory.importantUrgent,
      RepeatCategory.importantNotUrgent,
      RepeatCategory.notImportantUrgent,
    },
  });

  /// 알림을 보낼 수 있는 가장 이른 시각과 늦은 시각(C12).
  static const earliestSendTime = TimeOfDay(hour: 8, minute: 0);
  static const latestSendTime = TimeOfDay(hour: 22, minute: 0);

  /// [time]이 알림을 보낼 수 있는 시간대(08:00~22:00) 안이면 `true`를 돌려준다(C12).
  static bool isAllowedSendTime(TimeOfDay time) =>
      time.compareTo(earliestSendTime) >= 0 &&
      time.compareTo(latestSendTime) <= 0;

  final bool isEnabled;

  /// 마감 당일 마감 알림을 보내는 시각(A27).
  final TimeOfDay sendTime;

  /// 반복 알림을 켠 분류.
  final Set<RepeatCategory> repeatCategories;

  /// 주어진 값만 바꾼 새 설정을 돌려준다. 원본은 바꾸지 않는다.
  NotificationSettings copyWith({
    bool? isEnabled,
    TimeOfDay? sendTime,
    Set<RepeatCategory>? repeatCategories,
  }) {
    return NotificationSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      sendTime: sendTime ?? this.sendTime,
      repeatCategories: repeatCategories ?? this.repeatCategories,
    );
  }
}

/// `오전 9:00`, `오후 12:30`처럼 설계서 표기로 바꾼다.
String formatSendTime(TimeOfDay time) {
  final period = time.period == DayPeriod.am ? '오전' : '오후';
  final minute = time.minute.toString().padLeft(2, '0');
  return '$period ${time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod}:$minute';
}
