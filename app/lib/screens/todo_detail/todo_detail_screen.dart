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

/// 상세 화면을 닫을 때 목록에 전달할 변경 종류를 나타낸다.
enum TodoDetailAction { completionChanged, deleted }

/// 상세 화면에서 변경한 할 일과 동작을 목록에 전달한다.
class TodoDetailResult {
  /// 수행한 [action]과 최신 [todo]를 담은 결과를 만든다.
  const TodoDetailResult({required this.action, required this.todo});

  final TodoDetailAction action;

  /// 화면을 닫을 때의 최신 할 일. 상세에서 수정했을 수 있으므로 처음 넘긴 값 대신 이 값을 쓴다.
  final Todo todo;
}

/// 할 일의 분류와 마감 정보, 완료 상태를 보여주고 변경 동작을 제공한다.
class TodoDetailScreen extends StatefulWidget {
  /// 표시할 [todo]와 수정·삭제 저장 함수를 받아 상세 화면을 만든다.
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

  /// 상세 화면의 최신 할 일과 저장 상태를 관리하는 상태 객체를 만든다.
  @override
  State<TodoDetailScreen> createState() => _TodoDetailScreenState();
}

/// 상세 화면에서 수정·완료·삭제 요청과 표시 값을 관리한다.
class _TodoDetailScreenState extends State<TodoDetailScreen> {
  late Todo _todo = widget.todo;
  bool _isSaving = false;

  /// 남은 기간 계산에 사용할 오늘 날짜를 시각 없이 돌려준다.
  DateTime get _today {
    final now = widget.currentDate ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 수정 시트를 열고 바뀐 할 일을 저장한 뒤 화면에 반영한다.
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

  /// 완료 상태를 반대로 저장하고 성공하면 결과와 함께 화면을 닫는다.
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
    Navigator.of(context).pop(
      TodoDetailResult(
        action: TodoDetailAction.completionChanged,
        todo: updated,
      ),
    );
  }

  /// 확인을 받은 뒤 할 일을 삭제하고 결과와 함께 화면을 닫는다.
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
    Navigator.of(context)
        .pop(TodoDetailResult(action: TodoDetailAction.deleted, todo: _todo));
  }

  /// 기존 안내를 닫고 [message]를 스낵바로 보여준다.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 최신 할 일 정보와 수정·완료·삭제 버튼을 갖춘 상세 화면을 구성한다.
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

  /// 마감일을 연월일 문구로 바꾸며 값이 없으면 설정되지 않았음을 알린다.
  String _dueDateLabel() {
    final dueDate = _todo.dueDate;
    if (dueDate == null) return '설정 안 함';
    return '${dueDate.year}년 ${dueDate.month}월 ${dueDate.day}일';
  }

  /// 오늘을 기준으로 마감일까지 남거나 지난 기간을 표시한다.
  String _remainingLabel() {
    final dueDate = _todo.dueDate;
    if (dueDate == null) return '마감일 없음';
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final difference = due.difference(_today).inDays;
    if (difference == 0) return '오늘 마감';
    if (difference > 0) return 'D-$difference';
    return '${difference.abs()}일 지남';
  }

  /// 할 일이 직접 입력되었는지 사진에서 가져왔는지 설명한다.
  String _sourceLabel() {
    return switch (_todo.source) {
      TodoSource.manual => '직접 입력',
      TodoSource.photo => '사진에서 가져옴',
    };
  }
}
