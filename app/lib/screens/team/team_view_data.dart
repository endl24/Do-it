import 'package:flutter/foundation.dart';

@immutable
class TeamViewData {
  const TeamViewData({
    required this.name,
    required this.inviteCode,
    required this.memberNames,
    this.todos = const [],
  });

  final String name;
  final String inviteCode;
  final List<String> memberNames;
  final List<TeamSharedTodo> todos;
}

@immutable
class TeamSharedTodo {
  const TeamSharedTodo({
    required this.id,
    required this.title,
    required this.ownerName,
    required this.isImportant,
    required this.isUrgent,
    this.dueDate,
    this.isDone = false,
    this.onTap,
  });

  final String id;
  final String title;
  final String ownerName;
  final bool isImportant;
  final bool isUrgent;
  final DateTime? dueDate;
  final bool isDone;
  final VoidCallback? onTap;

  TeamSharedTodo withDone(bool isDone) => TeamSharedTodo(
    id: id,
    title: title,
    ownerName: ownerName,
    isImportant: isImportant,
    isUrgent: isUrgent,
    dueDate: dueDate,
    isDone: isDone,
    onTap: onTap,
  );
}
