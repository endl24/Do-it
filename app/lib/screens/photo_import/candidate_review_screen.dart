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
  /// 인식한 후보 [candidates]와 등록 동작 [onRegister]로 후보 검토 화면을 만든다.
  const CandidateReviewScreen({
    super.key,
    required this.candidates,
    required this.onRegister,
    this.imageFile,
  });

  final List<TodoCandidate> candidates;

  /// 인식에 사용한 촬영본. 미리보기로 보여주고 화면을 벗어날 때 삭제한다.
  final File? imageFile;

  /// 선택한 제목들을 할 일로 저장한다. 01 할 일 목록이 저장소에 `photo` 출처로 저장하고,
  /// 실패하면 예외를 던져 이 화면에 남아 다시 시도하게 한다.
  final Future<void> Function(List<String> titles) onRegister;

  /// 후보별 문장·선택 여부를 관리할 상태를 만든다.
  @override
  State<CandidateReviewScreen> createState() => _CandidateReviewScreenState();
}

/// 후보 문장과 선택 여부, 지금 고치는 후보, 등록 진행 여부를 들고 있는 상태.
class _CandidateReviewScreenState extends State<CandidateReviewScreen> {
  static const _maxTitleLength = 100;

  late final List<String> _texts;
  late final List<bool> _isSelected;
  final _editController = TextEditingController();
  final _editFocusNode = FocusNode();
  int? _editingIndex;
  bool _isRegistering = false;

  /// 지금 선택된 후보 수를 돌려준다.
  int get _selectedCount =>
      _isSelected.where((isSelected) => isSelected).length;

  /// 후보 문장을 앞뒤 공백을 지우고 100자까지 자른 뒤 담고, 제목으로 보이는 후보만 빼고 모두 선택해 둔다.
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

  /// 화면을 떠날 때 입력 도구를 정리하고 촬영본을 삭제한다(A19·C4). 어떤 경로로 떠나도 여기서 지운다.
  @override
  void dispose() {
    _editController.dispose();
    _editFocusNode.dispose();
    widget.imageFile?.delete().ignore();
    super.dispose();
  }

  /// [text]가 제목 최대 길이(100자)를 넘으면 앞에서부터 그 길이만큼만 남긴다.
  String _truncate(String text) =>
      text.length > _maxTitleLength ? text.substring(0, _maxTitleLength) : text;

  /// [index]번 후보를 고치기 시작한다. 다른 후보를 고치던 중이었으면 그 내용을 먼저 반영한다.
  void _startEditing(int index) {
    _finishEditing();
    setState(() {
      _editingIndex = index;
      _editController.text = _texts[index];
    });
    _editFocusNode.requestFocus();
  }

  /// 고치던 후보의 입력 내용을 반영하고 고치기를 끝낸다. 고치는 후보가 없으면 아무것도 하지 않는다.
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

  /// 고치던 내용을 반영한 뒤 선택한 후보 문장들을 등록하고, 성공하면 첫 화면(01)까지 돌아간다.
  ///
  /// 등록에 실패하면 이 화면에 남아 버튼을 다시 누를 수 있게 하고 다시 시도하라고 안내한다.
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

  /// 인식 결과를 버릴지 묻고, 버리기를 고르면 06으로 돌아간다.
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

  /// 요약, 후보 목록, 사진 미저장 안내와 아래 [등록]·[다시 촬영] 버튼을 그린다.
  ///
  /// 뒤로 가기는 바로 닫지 않고 결과를 버릴지 먼저 묻는다. 등록 중에는 뒤로 가기와 버튼을 막는다.
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

/// 촬영본 미리보기와 찾은 문장 수를 보여 주는 화면 맨 위 요약.
class _ReviewSummary extends StatelessWidget {
  /// 미리보기 사진 [imageFile]과 찾은 문장 수로 요약을 만든다.
  const _ReviewSummary({required this.imageFile, required this.candidateCount});

  static const _thumbnailSize = 72.0;

  final File? imageFile;
  final int candidateCount;

  /// 왼쪽에 사진 미리보기(없거나 읽지 못하면 그림 아이콘)를, 오른쪽에 찾은 문장 수와 안내를 그린다.
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

/// 후보 하나를 선택하고 고칠 수 있는 행.
class _CandidateTile extends StatelessWidget {
  /// 후보 문장, 선택·고치기 상태, 입력 도구, 각 동작으로 행을 만든다.
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

  /// 체크박스, 문장(또는 고치는 중이면 입력칸), 고치기 버튼을 한 줄에 그린다.
  ///
  /// 제목처럼 보여 해제된 후보는 점선 상자로, 고치는 중인 후보는 기본 색 테두리로 구분한다.
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

/// 고치는 중이 아닐 때 후보 문장을 보여 주는 글자.
class _CandidateText extends StatelessWidget {
  /// 문장과 선택·제목 제외 여부로 글자를 만든다.
  const _CandidateText({
    required this.text,
    required this.isSelected,
    required this.isExcludedTitle,
  });

  final String text;
  final bool isSelected;
  final bool isExcludedTitle;

  /// 선택한 후보는 굵게, 해제한 후보는 옅게 그리고, 제목이라 해제된 후보에는 그 이유를 덧붙인다.
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

/// 후보 문장을 그 자리에서 고치는 입력칸.
class _CandidateEditor extends StatelessWidget {
  /// 입력 도구, 최대 글자 수, 고치기를 끝낼 때 동작으로 입력칸을 만든다.
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

  /// 최대 글자 수까지만 입력받는 입력칸과 그 아래 글자 수를 그린다.
  ///
  /// 완료 키를 누르거나 입력칸 밖을 누르면 고치기를 끝낸다. 최대 길이에 닿으면 글자 수 대신 제한 안내를 빨간 글자로 보여 준다.
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
