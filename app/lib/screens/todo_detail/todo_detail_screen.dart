import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../models/todo.dart';
import '../../widgets/bottom_action_bar.dart';
import '../../widgets/danger_button.dart';
import '../../widgets/grouped_card.dart';
import '../../widgets/quadrant_tag.dart';
import '../todo_list/todo_form_sheet.dart';

enum TodoDetailResult { completed, deleted }

class TodoDetailScreen extends StatefulWidget {
  const TodoDetailScreen({
    required this.todo,
    required this.onUpdate,
    required this.onDelete,
    this.currentDate,
    super.key,
  });

  final Todo todo;
  final Future<bool> Function(Todo todo) onUpdate;
  final Future<bool> Function(Todo todo) onDelete;
  final DateTime? currentDate;

  @override
  State<TodoDetailScreen> createState() => _TodoDetailScreenState();
}

class _TodoDetailScreenState extends State<TodoDetailScreen> {
  late Todo _todo = widget.todo;
  bool _isSaving = false;

  DateTime get _today {
    final now = widget.currentDate ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _edit() async {
    if (_isSaving) return;
    final result = await showTodoFormSheet(context, todo: _todo);
    if (!mounted || result == null) return;
    if (result.shouldDelete) {
      await _delete();
      return;
    }

    final updated = result.todo!;
    setState(() => _isSaving = true);
    final succeeded = await widget.onUpdate(updated);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (succeeded) _todo = updated;
    });
    _showMessage(succeeded ? '할 일을 수정했습니다.' : '할 일을 수정하지 못했습니다.');
  }

  Future<void> _toggleCompleted() async {
    if (_isSaving) return;
    final updated = _todo.copyWith(isCompleted: !_todo.isCompleted);
    setState(() => _isSaving = true);
    final succeeded = await widget.onUpdate(updated);
    if (!mounted) return;
    if (!succeeded) {
      setState(() => _isSaving = false);
      _showMessage('완료 상태를 변경하지 못했습니다.');
      return;
    }
    Navigator.of(context).pop(TodoDetailResult.completed);
  }

  Future<void> _delete() async {
    if (_isSaving) return;
    final confirmed = await showDeleteTodoDialog(context, _todo.title);
    if (!mounted || !confirmed) return;
    setState(() => _isSaving = true);
    final succeeded = await widget.onDelete(_todo);
    if (!mounted) return;
    if (!succeeded) {
      setState(() => _isSaving = false);
      _showMessage('할 일을 삭제하지 못했습니다.');
      return;
    }
    Navigator.of(context).pop(TodoDetailResult.deleted);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(title: const Text('할 일 상세')),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
              AppSpacing.screenHorizontal,
              AppSpacing.xxl,
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: QuadrantTag(
                  isImportant: _todo.isImportant,
                  isUrgent: _todo.isUrgent,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _todo.title,
                style: AppTextStyles.headline.copyWith(
                  color: AppColors.textPrimary,
                  decoration: _todo.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              GroupedCard(
                children: [
                  LabelValueRow(label: '마감일', value: _dueDateLabel()),
                  LabelValueRow(label: '남은 기간', value: _remainingLabel()),
                  LabelValueRow(label: '등록 경로', value: _sourceLabel()),
                  LabelValueRow(
                    label: '상태',
                    value: _todo.isCompleted ? '완료' : '진행 중',
                  ),
                ],
              ),
              if (_isSaving) ...[
                const SizedBox(height: AppSpacing.md),
                const LinearProgressIndicator(semanticsLabel: '저장 중'),
              ],
            ],
          ),
        ),
        bottomNavigationBar: BottomActionBar(
          children: [
            FilledButton(
              onPressed: _isSaving ? null : _edit,
              child: const Text('수정'),
            ),
            OutlinedButton(
              onPressed: _isSaving ? null : _toggleCompleted,
              child: Text(_todo.isCompleted ? '미완료로 표시' : '완료로 표시'),
            ),
            DangerButton(label: '삭제', onPressed: _isSaving ? null : _delete),
          ],
        ),
      ),
    );
  }

  String _dueDateLabel() {
    final dueDate = _todo.dueDate;
    if (dueDate == null) return '설정 안 함';
    return '${dueDate.year}년 ${dueDate.month}월 ${dueDate.day}일';
  }

  String _remainingLabel() {
    final dueDate = _todo.dueDate;
    if (dueDate == null) return '마감일 없음';
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final difference = due.difference(_today).inDays;
    if (difference == 0) return '오늘 마감';
    if (difference > 0) return 'D-$difference';
    return '${difference.abs()}일 지남';
  }

  String _sourceLabel() {
    return switch (_todo.source) {
      TodoSource.manual => '직접 입력',
      TodoSource.photo => '사진에서 가져옴',
    };
  }
}
