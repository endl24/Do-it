import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/check_tile.dart';
import '../../widgets/grouped_card.dart';
import '../../widgets/notice_box.dart';
import '../../widgets/quadrant_tag.dart';
import '../../widgets/section_header.dart';
import 'notification_settings.dart';

/// 11 알림 설정 (A27 A28 A29 A31 A33 · B16 B17 B18 · C11 C12)
///
/// 14 설정 화면에서 push해서 쓴다. 바꾼 값은 저장 버튼 없이 바로 [onChanged]로 넘긴다.
class NotificationSettingsScreen extends StatefulWidget {
  /// 처음 보여 줄 설정 [initialSettings]와 바뀐 값을 받을 [onChanged]로 화면을 만든다.
  const NotificationSettingsScreen({
    super.key,
    required this.initialSettings,
    required this.onChanged,
    this.isPermissionDenied = false,
    this.onOpenSystemSettings,
  });

  final NotificationSettings initialSettings;

  /// 값이 바뀔 때마다 부른다. 저장과 알림 예약 재계산은 부르는 쪽이 맡는다.
  // TODO(강두이): 알림 패키지가 정해지면 여기서 단말에 저장하고 예약을 다시 계산한다.
  final ValueChanged<NotificationSettings> onChanged;

  /// 단말의 알림 권한이 꺼져 있으면 화면 상단에 안내를 띄운다(E6).
  final bool isPermissionDenied;

  /// [설정 열기]를 눌렀을 때 OS 앱 설정 화면으로 보낸다(A32).
  final VoidCallback? onOpenSystemSettings;

  /// 화면에서 바꾸는 설정 값을 관리할 상태를 만든다.
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

/// 바뀐 설정 값을 들고 있다가 바뀔 때마다 화면을 다시 그리고 [NotificationSettingsScreen.onChanged]로 알리는 상태.
class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late var _settings = widget.initialSettings;

  /// 설정 값을 [settings]로 바꿔 화면에 반영하고, 부르는 쪽에 바로 알린다.
  void _update(NotificationSettings settings) {
    setState(() => _settings = settings);
    widget.onChanged(settings);
  }

  /// [category] 분류의 반복 알림을 [isOn]에 따라 켜거나 끈다.
  void _toggleRepeat(RepeatCategory category, bool isOn) {
    _update(
      _settings.copyWith(
        repeatCategories: isOn
            ? {..._settings.repeatCategories, category}
            : ({..._settings.repeatCategories}..remove(category)),
      ),
    );
  }

  /// 발송 시각 바텀시트를 띄우고, 고른 시각이 지금과 다르면 설정에 반영한다.
  Future<void> _pickSendTime() async {
    final time = await showModalBottomSheet<TimeOfDay>(
      context: context,
      builder: (_) => _SendTimeSheet(initialTime: _settings.sendTime),
    );
    if (time != null && time != _settings.sendTime) {
      _update(_settings.copyWith(sendTime: time));
    }
  }

  /// 권한 안내, 알림 받기, 마감 알림 발송 시각, 반복 알림, 묶음 알림 미리보기를 차례로 그린다.
  ///
  /// 알림 받기를 끄면 발송 시각과 반복 알림은 누를 수 없게 막는다.
  @override
  Widget build(BuildContext context) {
    final isEnabled = _settings.isEnabled;

    return Scaffold(
      appBar: AppBar(title: const Text('알림')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.xs,
          AppSpacing.screenHorizontal,
          AppSpacing.xxl,
        ),
        children: [
          if (widget.isPermissionDenied) ...[
            _PermissionBanner(
              onOpenSystemSettings: widget.onOpenSystemSettings,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          CheckTile(
            title: '알림 받기',
            subtitle: '단말에 예약되어 오프라인에서도 동작합니다',
            value: isEnabled,
            onChanged: (value) => _update(_settings.copyWith(isEnabled: value)),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const SectionHeader(title: '마감 알림'),
          GroupedCard(
            footer: '알림은 08:00 ~ 22:00 사이에만 발송됩니다',
            children: [
              LabelValueRow(
                label: '발송 시각',
                valueWidget: Text(
                  formatSendTime(_settings.sendTime),
                  style: AppTextStyles.itemTitle.copyWith(
                    color: isEnabled
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                  ),
                ),
                onTap: isEnabled ? _pickSendTime : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const SectionHeader(title: '반복 알림'),
          GroupedCard(
            footer:
                '한 사람에게 하루 5회를 넘겨 보내지 않습니다\n'
                '마감일이 없는 할 일은 등록 7일 뒤 반복이 자동 중단됩니다',
            children: [
              for (final category in RepeatCategory.values)
                _RepeatRow(
                  category: category,
                  value: _settings.repeatCategories.contains(category),
                  onChanged: isEnabled
                      ? (isOn) => _toggleRepeat(category, isOn)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const SectionHeader(title: '알림 미리보기'),
          const _BundledPreview(),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '같은 시각에 2건 이상이면 하나로 묶어 건수와 함께 표시합니다',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 알림 권한이 꺼져 있을 때 화면 맨 위에 띄우는 안내와 [설정 열기] 버튼(E6, A32).
class _PermissionBanner extends StatelessWidget {
  /// [설정 열기]를 눌렀을 때 실행할 동작으로 안내를 만든다.
  const _PermissionBanner({required this.onOpenSystemSettings});

  final VoidCallback? onOpenSystemSettings;

  /// 오류 안내 박스 아래에 [설정 열기] 버튼을 붙여 그린다.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NoticeBox.error(
          icon: Icons.notifications_off_outlined,
          message: '알림 권한이 꺼져 있어 설정이 적용되지 않습니다',
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: onOpenSystemSettings,
          child: const Text('설정 열기'),
        ),
      ],
    );
  }
}

/// 반복 알림 분류 하나를 켜고 끄는 행. 사분면 태그, 하루 횟수, 체크박스를 한 줄에 둔다.
class _RepeatRow extends StatelessWidget {
  /// [category] 분류와 지금 켜짐 여부 [value]로 행을 만든다. [onChanged]가 `null`이면 누를 수 없다.
  const _RepeatRow({
    required this.category,
    required this.value,
    required this.onChanged,
  });

  final RepeatCategory category;
  final bool value;
  final ValueChanged<bool>? onChanged;

  /// 행 어디를 눌러도 켜짐 여부가 바뀌게 하고, 누를 수 없을 때는 태그와 글자를 흐리게 그린다.
  @override
  Widget build(BuildContext context) {
    final isEnabled = onChanged != null;

    return InkWell(
      onTap: isEnabled ? () => onChanged!(!value) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xxs,
          AppSpacing.sm,
          AppSpacing.xxs,
        ),
        child: Row(
          children: [
            Opacity(
              opacity: isEnabled ? 1 : 0.5,
              child: QuadrantTag(
                isImportant: category.isImportant,
                isUrgent: category.isUrgent,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '1일 ${category.timesPerDay}회',
                style: AppTextStyles.body.copyWith(
                  color: isEnabled
                      ? AppColors.textSecondary
                      : AppColors.textTertiary,
                ),
              ),
            ),
            Checkbox(
              value: value,
              onChanged: isEnabled
                  ? (checked) => onChanged!(checked ?? false)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// 묶음 알림(A31)이 어떻게 보이는지 보여주는 예시.
class _BundledPreview extends StatelessWidget {
  /// 고정된 예시 내용으로 미리보기를 만든다.
  const _BundledPreview();

  static const _iconBoxSize = 44.0;

  /// 앱 아이콘 자리와 묶음 알림 제목·내용 예시를 카드에 그린다.
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: _iconBoxSize,
              height: _iconBoxSize,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.checklist,
                size: AppSize.iconSm,
                color: AppColors.onPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘 마감인 할 일 3건',
                    style: AppTextStyles.itemTitle.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '졸업 요건 서류 제출 외 2건',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 발송 시각을 고르는 바텀시트. 08:00~22:00 밖이면 안내를 띄우고 [확인]을 막는다(C12).
///
/// 앱에 한국어 지역화가 없어 `showTimePicker`는 영어로 나오므로 직접 만든다.
class _SendTimeSheet extends StatefulWidget {
  /// 처음 선택해 둘 시각 [initialTime]으로 바텀시트를 만든다.
  const _SendTimeSheet({required this.initialTime});

  final TimeOfDay initialTime;

  /// 오전·오후, 시, 분 선택 값을 관리할 상태를 만든다.
  @override
  State<_SendTimeSheet> createState() => _SendTimeSheetState();
}

/// 오전·오후, 시(1~12), 분(10분 단위) 휠의 선택 위치를 들고 있다가 시각으로 바꿔 주는 상태.
class _SendTimeSheetState extends State<_SendTimeSheet> {
  static const _minuteStep = 10;
  static const _pickerHeight = 180.0;
  static const _itemExtent = 40.0;

  late var _isPm = widget.initialTime.period == DayPeriod.pm;
  late var _hourIndex = (widget.initialTime.hourOfPeriod + 11) % 12;
  late var _minuteIndex = widget.initialTime.minute ~/ _minuteStep;

  late final _periodController = FixedExtentScrollController(
    initialItem: _isPm ? 1 : 0,
  );
  late final _hourController = FixedExtentScrollController(
    initialItem: _hourIndex,
  );
  late final _minuteController = FixedExtentScrollController(
    initialItem: _minuteIndex,
  );

  /// 바텀시트를 닫을 때 세 휠의 스크롤 컨트롤러를 정리한다.
  @override
  void dispose() {
    _periodController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  /// 세 휠에서 고른 값을 24시간제 시각으로 바꿔 돌려준다. 예) 오후 12시 → 12:00, 오전 12시 → 00:00
  TimeOfDay get _time {
    final hour = (_hourIndex + 1) % 12 + (_isPm ? 12 : 0);
    return TimeOfDay(hour: hour, minute: _minuteIndex * _minuteStep);
  }

  /// 세 휠과 [확인] 버튼을 그린다. 고른 시각이 허용 시간대 밖이면 안내 문구를 띄우고 [확인]을 막는다.
  @override
  Widget build(BuildContext context) {
    final isAllowed = NotificationSettings.isAllowedSendTime(_time);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.lg,
          AppSpacing.screenHorizontal,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '발송 시각',
              style: AppTextStyles.appBarTitle.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(
              height: _pickerHeight,
              child: Row(
                children: [
                  _wheel(
                    labels: const ['오전', '오후'],
                    controller: _periodController,
                    onSelected: (index) => setState(() => _isPm = index == 1),
                  ),
                  _wheel(
                    labels: [for (var hour = 1; hour <= 12; hour++) '$hour시'],
                    controller: _hourController,
                    onSelected: (index) => setState(() => _hourIndex = index),
                  ),
                  _wheel(
                    labels: [
                      for (var minute = 0; minute < 60; minute += _minuteStep)
                        '${minute.toString().padLeft(2, '0')}분',
                    ],
                    controller: _minuteController,
                    onSelected: (index) => setState(() => _minuteIndex = index),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: AppSpacing.xl,
              child: isAllowed
                  ? null
                  : Text(
                      '알림은 08시부터 22시 사이에만 보낼 수 있습니다',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.dangerText,
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.xs),
            FilledButton(
              onPressed: isAllowed
                  ? () => Navigator.of(context).pop(_time)
                  : null,
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  /// [labels]를 항목으로 하는 iOS식 휠 하나를 만든다. 고를 때마다 [onSelected]에 위치를 넘긴다.
  Widget _wheel({
    required List<String> labels,
    required FixedExtentScrollController controller,
    required ValueChanged<int> onSelected,
  }) {
    return Expanded(
      child: CupertinoPicker(
        itemExtent: _itemExtent,
        scrollController: controller,
        onSelectedItemChanged: onSelected,
        children: [
          for (final label in labels)
            Center(
              child: Text(
                label,
                style: AppTextStyles.input.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
