import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/bottom_action_bar.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_placeholder.dart';
import '../../widgets/notice_box.dart';
import 'todo_candidate.dart';

/// 07 할 일 후보 검토 (A15 A16 A19 · C4 C6)
///
/// 06 메모 촬영 위에 push해서 쓴다. [다시 촬영]과 뒤로 가기는 06으로 돌아가고,
/// 등록이 끝나면 첫 화면(01 할 일 목록)까지 돌아간다.
/// 화면을 벗어나면 어떤 경로든 [imageFile]을 삭제한다(A19·C4).
class CandidateReviewScreen extends StatefulWidget {
  const CandidateReviewScreen({
    super.key,
    required this.candidates,
    required this.onRegister,
    this.imageFile,
  });

  final List<TodoCandidate> candidates;

  /// 인식에 사용한 촬영본. 미리보기로 보여주고 화면을 벗어날 때 삭제한다.
  final File? imageFile;

  /// 선택한 제목들을 할 일로 저장한다.
  // TODO(강두이): 공통 모델(A7)이 정해지면 저장소에 바로 저장하도록 바꾼다.
  final Future<void> Function(List<String> titles) onRegister;

  @override
  State<CandidateReviewScreen> createState() => _CandidateReviewScreenState();
}

class _CandidateReviewScreenState extends State<CandidateReviewScreen> {
  static const _maxTitleLength = 100;

  late final List<String> _texts;
  late final List<bool> _isSelected;
  final _editController = TextEditingController();
  final _editFocusNode = FocusNode();
  int? _editingIndex;
  bool _isRegistering = false;

  int get _selectedCount =>
      _isSelected.where((isSelected) => isSelected).length;

  @override
  void initState() {
    super.initState();
    _texts = [
      for (final candidate in widget.candidates)
        _truncate(candidate.text.trim()),
    ];
    _isSelected = [
      for (final candidate in widget.candidates) !candidate.isLikelyTitle,
    ];
  }

  @override
  void dispose() {
    _editController.dispose();
    _editFocusNode.dispose();
    widget.imageFile?.delete().ignore();
    super.dispose();
  }

  String _truncate(String text) =>
      text.length > _maxTitleLength ? text.substring(0, _maxTitleLength) : text;

  void _startEditing(int index) {
    _finishEditing();
    setState(() {
      _editingIndex = index;
      _editController.text = _texts[index];
    });
    _editFocusNode.requestFocus();
  }

  void _finishEditing() {
    final index = _editingIndex;
    if (index == null) return;
    final text = _editController.text.trim();
    _editFocusNode.unfocus();
    setState(() {
      // 비워 두고 나가면 원래 문장을 유지한다.
      if (text.isNotEmpty) _texts[index] = text;
      _editingIndex = null;
    });
  }

  Future<void> _register() async {
    _finishEditing();
    final titles = [
      for (var i = 0; i < _texts.length; i++)
        if (_isSelected[i]) _texts[i],
    ];
    setState(() => _isRegistering = true);
    try {
      await widget.onRegister(titles);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      debugPrint('할 일 후보 등록 실패: $error');
      if (!mounted) return;
      setState(() => _isRegistering = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('등록하지 못했어요. 다시 시도해 주세요.')));
    }
  }

  Future<void> _confirmDiscard() async {
    final isConfirmed = await showConfirmDialog(
      context,
      title: '인식 결과를 버릴까요?',
      message: '고르고 수정한 내용은 저장되지 않아요.',
      confirmLabel: '버리기',
      isDestructive: true,
    );
    if (isConfirmed && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedCount;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isRegistering) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('할 일 후보 검토')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.xs,
            AppSpacing.screenHorizontal,
            AppSpacing.xl,
          ),
          children: [
            _ReviewSummary(
              imageFile: widget.imageFile,
              candidateCount: _texts.length,
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < _texts.length; i++) ...[
              _CandidateTile(
                text: _texts[i],
                isSelected: _isSelected[i],
                isExcludedTitle:
                    widget.candidates[i].isLikelyTitle && !_isSelected[i],
                isEditing: _editingIndex == i,
                editController: _editController,
                editFocusNode: _editFocusNode,
                maxLength: _maxTitleLength,
                onSelectedChanged: (isSelected) =>
                    setState(() => _isSelected[i] = isSelected),
                onEditPressed: () => _startEditing(i),
                onEditDone: _finishEditing,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.xs),
            const NoticeBox(
              icon: Icons.hide_image_outlined,
              message: '인식에 사용한 원본 사진은 저장하지 않고 등록이 끝나면 바로 삭제됩니다.',
            ),
          ],
        ),
        bottomNavigationBar: BottomActionBar(
          children: [
            FilledButton(
              onPressed: selectedCount == 0 || _isRegistering
                  ? null
                  : _register,
              child: Text(
                selectedCount == 0
                    ? '등록할 항목을 한 개 이상 선택해 주세요'
                    : '선택한 $selectedCount개 할 일로 등록',
              ),
            ),
            OutlinedButton(
              onPressed: _isRegistering
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('다시 촬영'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({required this.imageFile, required this.candidateCount});

  static const _thumbnailSize = 72.0;

  final File? imageFile;
  final int candidateCount;

  @override
  Widget build(BuildContext context) {
    const placeholder = Icon(
      Icons.image_outlined,
      size: AppSize.iconMd,
      color: AppColors.textTertiary,
    );

    return Row(
      children: [
        Container(
          width: _thumbnailSize,
          height: _thumbnailSize,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: imageFile == null
              ? placeholder
              : Image.file(
                  imageFile!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => placeholder,
                ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$candidateCount개 문장을 찾았어요',
                style: AppTextStyles.appBarTitle.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '필요한 항목만 골라 수정한 뒤 등록하세요',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.text,
    required this.isSelected,
    required this.isExcludedTitle,
    required this.isEditing,
    required this.editController,
    required this.editFocusNode,
    required this.maxLength,
    required this.onSelectedChanged,
    required this.onEditPressed,
    required this.onEditDone,
  });

  final String text;
  final bool isSelected;

  /// 제목처럼 보여 기본 해제된 채로 남아 있는 후보. 점선 상자로 구분한다.
  final bool isExcludedTitle;
  final bool isEditing;
  final TextEditingController editController;
  final FocusNode editFocusNode;
  final int maxLength;
  final ValueChanged<bool> onSelectedChanged;
  final VoidCallback onEditPressed;
  final VoidCallback onEditDone;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Checkbox(
          value: isSelected,
          onChanged: (checked) => onSelectedChanged(checked ?? false),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: isEditing
              ? _CandidateEditor(
                  controller: editController,
                  focusNode: editFocusNode,
                  maxLength: maxLength,
                  onDone: onEditDone,
                )
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onEditPressed,
                  child: _CandidateText(
                    text: text,
                    isSelected: isSelected,
                    isExcludedTitle: isExcludedTitle,
                  ),
                ),
        ),
        if (!isEditing)
          IconButton(
            onPressed: onEditPressed,
            tooltip: '문장 수정',
            icon: const Icon(
              Icons.edit_outlined,
              size: AppSize.iconSm,
              color: AppColors.textTertiary,
            ),
          ),
      ],
    );
    const padding = EdgeInsets.symmetric(
      horizontal: AppSpacing.xxs,
      vertical: AppSpacing.xs,
    );

    if (isExcludedTitle) {
      return DashedBorderBox(padding: padding, child: content);
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isEditing ? AppColors.primary : AppColors.border,
        ),
      ),
      child: content,
    );
  }
}

class _CandidateText extends StatelessWidget {
  const _CandidateText({
    required this.text,
    required this.isSelected,
    required this.isExcludedTitle,
  });

  final String text;
  final bool isSelected;
  final bool isExcludedTitle;

  @override
  Widget build(BuildContext context) {
    final textStyle = isSelected
        ? AppTextStyles.itemTitle.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          )
        : AppTextStyles.input.copyWith(
            color: isExcludedTitle
                ? AppColors.textTertiary
                : AppColors.textSecondary,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: textStyle),
          if (isExcludedTitle)
            Text(
              '제목처럼 보여 기본 해제했어요',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onWarningContainer,
              ),
            ),
        ],
      ),
    );
  }
}

class _CandidateEditor extends StatelessWidget {
  const _CandidateEditor({
    required this.controller,
    required this.focusNode,
    required this.maxLength,
    required this.onDone,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int maxLength;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          style: AppTextStyles.itemTitle.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
          textInputAction: TextInputAction.done,
          inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
          onSubmitted: (_) => onDone(),
          onTapOutside: (_) => onDone(),
          decoration: const InputDecoration(
            isCollapsed: true,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, _) {
            final isAtLimit = value.text.length >= maxLength;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: Text(
                isAtLimit
                    ? '할 일 제목은 최대 $maxLength자까지 입력할 수 있어요'
                    : '${value.text.length}/$maxLength',
                style: AppTextStyles.caption.copyWith(
                  color: isAtLimit
                      ? AppColors.dangerText
                      : AppColors.textTertiary,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
