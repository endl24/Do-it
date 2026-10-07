import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../models/todo.dart';
import '../../widgets/confirm_dialog.dart';

class TodoFormResult {
  const TodoFormResult.save(this.todo) : shouldDelete = false;

  const TodoFormResult.delete() : todo = null, shouldDelete = true;

  final Todo? todo;
  final bool shouldDelete;
}

Future<TodoFormResult?> showTodoFormSheet(BuildContext context, {Todo? todo}) {
  return showModalBottomSheet<TodoFormResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TodoForm(todo: todo),
  );
}

Future<bool> showDeleteTodoDialog(BuildContext context, String title) {
  return showConfirmDialog(
    context,
    title: '할 일을 삭제할까요?',
    message: "'$title'을 삭제하면 다시 복구할 수 없습니다.",
    confirmLabel: '삭제',
    isDestructive: true,
  );
}

class _TodoForm extends StatefulWidget {
  const _TodoForm({this.todo});

  final Todo? todo;

  @override
  State<_TodoForm> createState() => _TodoFormState();
}

class _TodoFormState extends State<_TodoForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late TodoImportance _importance;
  late TodoUrgency _urgency;
  late DateTime? _dueDate;
  late bool _reminderEnabled;

  @override
  void initState() {
    super.initState();
    final todo = widget.todo;
    _titleController = TextEditingController(text: todo?.title);
    _importance = todo?.importance ?? TodoImportance.important;
    _urgency = todo?.urgency ?? TodoUrgency.urgent;
    _dueDate = todo?.dueDate;
    _reminderEnabled = todo?.reminderEnabled ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.lg,
        AppSpacing.screenHorizontal,
        AppSpacing.lg + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.todo == null ? '할 일 추가' : '할 일 수정',
                      style: AppTextStyles.headline.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _titleController,
                autofocus: true,
                maxLength: 100,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '할 일',
                  hintText: '해야 할 일을 입력하세요',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? '할 일을 입력해 주세요.'
                    : null,
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: AppSpacing.md),
              _SelectionSection<TodoImportance>(
                label: '중요도',
                value: _importance,
                segments: const [
                  ButtonSegment(
                    value: TodoImportance.important,
                    label: Text('중요'),
                  ),
                  ButtonSegment(
                    value: TodoImportance.unimportant,
                    label: Text('비중요'),
                  ),
                ],
                onChanged: (value) => setState(() => _importance = value),
              ),
              const SizedBox(height: AppSpacing.md),
              _SelectionSection<TodoUrgency>(
                label: '긴급도',
                value: _urgency,
                segments: const [
                  ButtonSegment(value: TodoUrgency.urgent, label: Text('긴급')),
                  ButtonSegment(
                    value: TodoUrgency.notUrgent,
                    label: Text('비긴급'),
                  ),
                ],
                onChanged: (value) => setState(() => _urgency = value),
              ),
              const SizedBox(height: AppSpacing.lg),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('마감일'),
                subtitle: Text(_dateLabel(_dueDate)),
                trailing: _dueDate == null
                    ? null
                    : IconButton(
                        tooltip: '마감일 지우기',
                        onPressed: () => setState(() => _dueDate = null),
                        icon: const Icon(Icons.clear),
                      ),
                onTap: _pickDate,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('알림 사용'),
                subtitle: const Text('마감일 알림을 받을 수 있게 표시합니다'),
                value: _reminderEnabled,
                onChanged: (value) => setState(() => _reminderEnabled = value),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(widget.todo == null ? '추가' : '저장'),
                ),
              ),
              if (widget.todo != null) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.dangerText,
                    ),
                    onPressed: () =>
                        Navigator.of(context)
                            .pop(const TodoFormResult.delete()),
                    child: const Text('할 일 삭제'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 10, 12, 31),
    );
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final current = widget.todo;
    final todo = current == null
        ? Todo.create(
            title: _titleController.text,
            importance: _importance,
            urgency: _urgency,
            dueDate: _dueDate,
            reminderEnabled: _reminderEnabled,
          )
        : current.copyWith(
            title: _titleController.text,
            importance: _importance,
            urgency: _urgency,
            dueDate: _dueDate,
            clearDueDate: _dueDate == null,
            reminderEnabled: _reminderEnabled,
          );
    Navigator.of(context).pop(TodoFormResult.save(todo));
  }

  static String _dateLabel(DateTime? date) {
    if (date == null) return '설정 안 함';
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }
}

class _SelectionSection<T> extends StatelessWidget {
  const _SelectionSection({
    required this.label,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<ButtonSegment<T>> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textLabel),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<T>(
            segments: segments,
            selected: {value},
            onSelectionChanged: (values) => onChanged(values.single),
          ),
        ),
      ],
    );
  }
}
