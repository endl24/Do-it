import 'package:flutter/foundation.dart';

/// 12 팀 화면에 보여 줄 팀 정보. 팀 이름·초대 코드·구성원 이름과 공유 할 일을 담는다.
@immutable
class TeamViewData {
  /// 팀 이름·초대 코드·구성원 이름과 공유 할 일로 팀 정보를 만든다.
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

/// 팀 구성원이 함께 보는 공유 할 일 하나. 화면에 보여 줄 값과 담당자 이름을 담는다.
@immutable
class TeamSharedTodo {
  /// 할 일 id·제목·담당자·사분면·마감일·완료 여부와 누를 때 동작으로 공유 할 일을 만든다.
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

  /// 완료 여부만 [isDone]으로 바꾼 새 공유 할 일을 돌려준다. 원본은 바꾸지 않는다.
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
