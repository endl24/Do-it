import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/bottom_action_bar.dart';
import '../../widgets/notice_box.dart';
import '../../widgets/status_message.dart';

/// 08 텍스트 인식 실패 안내 (A17 A19 · B6 B10)
///
/// 06 메모 촬영 위에 push해서 쓴다. [다시 촬영]은 06으로 돌아가고,
/// 뒤로 가기는 06을 건너뛰고 첫 화면(01 할 일 목록)까지 돌아간다.
/// 화면을 벗어나면 어떤 경로든 [imageFile]을 삭제한다(A19).
class RecognitionFailureScreen extends StatefulWidget {
  const RecognitionFailureScreen({
    super.key,
    required this.onManualEntry,
    this.failureCount = 1,
    this.imageFile,
  });

  /// 이 횟수만큼 연속으로 실패하면 직접 입력을 권한다(B10).
  static const manyFailuresThreshold = 3;

  /// [직접 입력으로 등록]을 눌렀을 때 03 할 일 등록으로 넘어간다(A17).
  // TODO(강두이): 03 할 일 등록 화면이 생기면 여기서 바로 push한다.
  final VoidCallback onManualEntry;

  /// 연속으로 인식에 실패한 횟수. 06이 세고, 인식에 성공하면 초기화한다.
  final int failureCount;

  /// 인식에 실패한 촬영본. 저장하지 않고 화면을 벗어날 때 삭제한다.
  final File? imageFile;

  @override
  State<RecognitionFailureScreen> createState() =>
      _RecognitionFailureScreenState();
}

class _RecognitionFailureScreenState extends State<RecognitionFailureScreen> {
  @override
  void dispose() {
    widget.imageFile?.delete().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('텍스트 인식')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.md,
            AppSpacing.screenHorizontal,
            AppSpacing.xl,
          ),
          children: [
            StatusMessage.icon(
              icon: Icons.crop_free,
              title: '글자를 읽지 못했어요',
              description: '사진이 흐리거나 글자가 너무 작으면\n인식에 실패할 수 있습니다.',
              isError: true,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (widget.failureCount >=
                RecognitionFailureScreen.manyFailuresThreshold) ...[
              const NoticeBox(
                icon: Icons.keyboard_outlined,
                message: '직접 입력이 더 빠를 수 있어요',
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const _RetryTipsCard(),
            const SizedBox(height: AppSpacing.md),
            const NoticeBox(
              message: '인식에 실패해도 앱은 종료되지 않고, 방금 찍은 사진은 저장되지 않습니다.',
            ),
          ],
        ),
        bottomNavigationBar: BottomActionBar(
          children: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('다시 촬영'),
            ),
            OutlinedButton(
              onPressed: widget.onManualEntry,
              child: const Text('직접 입력으로 등록'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RetryTipsCard extends StatelessWidget {
  const _RetryTipsCard();

  static const _tips = [
    '메모지를 평평하게 펴고 그림자가 지지 않게 찍어 주세요',
    '글자가 화면 안내선을 가득 채우도록 가까이서 찍어 주세요',
    '한 번에 한 장만 인식하니 여러 장이면 나눠서 찍어 주세요',
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이렇게 해보세요',
              style: AppTextStyles.fieldLabel.copyWith(
                color: AppColors.textLabel,
              ),
            ),
            for (var i = 0; i < _tips.length; i++) ...[
              const SizedBox(height: AppSpacing.md),
              _TipRow(number: i + 1, text: _tips[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.number, required this.text});

  static const _badgeSize = 28.0;

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: _badgeSize,
          height: _badgeSize,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.surfaceMuted,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: AppTextStyles.chip.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs / 2),
            child: Text(
              text,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}
