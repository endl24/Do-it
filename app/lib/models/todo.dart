enum TodoImportance { important, unimportant }

enum TodoUrgency { urgent, notUrgent }

enum TodoSource { manual, photo }

enum TodoSyncStatus { localOnly, pending, synced, failed }

enum TodoQuadrant {
  doNow,
  schedule,
  delegate,
  eliminate;

  String get label => switch (this) {
    TodoQuadrant.doNow => '지금 한다',
    TodoQuadrant.schedule => '계획한다',
    TodoQuadrant.delegate => '빨리 끝낸다',
    TodoQuadrant.eliminate => '미뤄둔다',
  };

  String get description => switch (this) {
    TodoQuadrant.doNow => '중요 · 긴급',
    TodoQuadrant.schedule => '중요 · 비긴급',
    TodoQuadrant.delegate => '비중요 · 긴급',
    TodoQuadrant.eliminate => '비중요 · 비긴급',
  };
}

class Todo {
  const Todo({
    required this.id,
    required this.title,
    required this.importance,
    required this.urgency,
    required this.isCompleted,
    required this.reminderEnabled,
    required this.source,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
    this.dueDate,
    this.remoteId,
  });

  factory Todo.create({
    required String title,
    required TodoImportance importance,
    required TodoUrgency urgency,
    DateTime? dueDate,
    bool reminderEnabled = false,
    TodoSource source = TodoSource.manual,
  }) {
    final now = DateTime.now();
    return Todo(
      id: '${now.microsecondsSinceEpoch}',
      title: title.trim(),
      importance: importance,
      urgency: urgency,
      isCompleted: false,
      dueDate: dueDate,
      reminderEnabled: reminderEnabled,
      source: source,
      syncStatus: TodoSyncStatus.localOnly,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Todo.fromMap(Map<String, Object?> map) {
    return Todo(
      id: map['id']! as String,
      remoteId: map['remote_id'] as String?,
      title: map['title']! as String,
      importance: TodoImportance.values.byName(map['importance']! as String),
      urgency: TodoUrgency.values.byName(map['urgency']! as String),
      isCompleted: map['is_completed'] == 1,
      dueDate: _dateFromMap(map['due_date']),
      reminderEnabled: map['reminder_enabled'] == 1,
      source: TodoSource.values.byName(map['source']! as String),
      syncStatus: TodoSyncStatus.values.byName(map['sync_status']! as String),
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
    );
  }

  final String id;
  final String? remoteId;
  final String title;
  final TodoImportance importance;
  final TodoUrgency urgency;
  final bool isCompleted;
  final DateTime? dueDate;
  final bool reminderEnabled;
  final TodoSource source;
  final TodoSyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isImportant => importance == TodoImportance.important;
  bool get isUrgent => urgency == TodoUrgency.urgent;

  TodoQuadrant get quadrant => switch ((importance, urgency)) {
    (TodoImportance.important, TodoUrgency.urgent) => TodoQuadrant.doNow,
    (TodoImportance.important, TodoUrgency.notUrgent) => TodoQuadrant.schedule,
    (TodoImportance.unimportant, TodoUrgency.urgent) => TodoQuadrant.delegate,
    (TodoImportance.unimportant, TodoUrgency.notUrgent) =>
      TodoQuadrant.eliminate,
  };

  Todo copyWith({
    String? remoteId,
    String? title,
    TodoImportance? importance,
    TodoUrgency? urgency,
    bool? isCompleted,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? reminderEnabled,
    TodoSource? source,
    TodoSyncStatus? syncStatus,
    DateTime? updatedAt,
  }) {
    return Todo(
      id: id,
      remoteId: remoteId ?? this.remoteId,
      title: title?.trim() ?? this.title,
      importance: importance ?? this.importance,
      urgency: urgency ?? this.urgency,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      source: source ?? this.source,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Todo moveTo(TodoQuadrant target) {
    return switch (target) {
      TodoQuadrant.doNow => copyWith(
        importance: TodoImportance.important,
        urgency: TodoUrgency.urgent,
      ),
      TodoQuadrant.schedule => copyWith(
        importance: TodoImportance.important,
        urgency: TodoUrgency.notUrgent,
      ),
      TodoQuadrant.delegate => copyWith(
        importance: TodoImportance.unimportant,
        urgency: TodoUrgency.urgent,
      ),
      TodoQuadrant.eliminate => copyWith(
        importance: TodoImportance.unimportant,
        urgency: TodoUrgency.notUrgent,
      ),
    };
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'remote_id': remoteId,
      'title': title,
      'importance': importance.name,
      'urgency': urgency.name,
      'is_completed': isCompleted ? 1 : 0,
      'due_date': dueDate?.toIso8601String(),
      'reminder_enabled': reminderEnabled ? 1 : 0,
      'source': source.name,
      'sync_status': syncStatus.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static DateTime? _dateFromMap(Object? value) {
    return value == null ? null : DateTime.tryParse(value as String);
  }
}
