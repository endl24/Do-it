/// 할 일의 중요 여부를 나타낸다.
enum TodoImportance { important, unimportant }

/// 할 일의 긴급 여부를 나타낸다.
enum TodoUrgency { urgent, notUrgent }

/// 할 일이 직접 입력되었는지 사진에서 만들어졌는지 나타낸다.
enum TodoSource { manual, photo }

/// 로컬 변경 사항이 원격 저장소와 동기화된 상태를 나타낸다.
enum TodoSyncStatus { localOnly, pending, synced, failed }

/// 중요도와 긴급도를 조합한 아이젠하워 사분면을 나타낸다.
enum TodoQuadrant {
  doNow,
  schedule,
  delegate,
  eliminate;

  /// 화면에 표시할 사분면 이름을 돌려준다.
  String get label => switch (this) {
    TodoQuadrant.doNow => '지금 한다',
    TodoQuadrant.schedule => '계획한다',
    TodoQuadrant.delegate => '빨리 끝낸다',
    TodoQuadrant.eliminate => '미뤄둔다',
  };

  /// 사분면의 중요도와 긴급도 조합을 설명한다.
  String get description => switch (this) {
    TodoQuadrant.doNow => '중요 · 긴급',
    TodoQuadrant.schedule => '중요 · 비긴급',
    TodoQuadrant.delegate => '비중요 · 긴급',
    TodoQuadrant.eliminate => '비중요 · 비긴급',
  };
}

/// 제목과 분류, 완료 및 동기화 상태를 보관하는 할 일 모델이다.
class Todo {
  /// 저장된 값으로 변경할 수 없는 할 일을 만든다.
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

  /// 새 할 일에 식별자와 생성 시각의 기본값을 채워 만든다.
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

  /// 로컬 데이터베이스 행을 할 일 모델로 복원한다.
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

  /// 이 할 일이 중요한 항목인지 알려준다.
  bool get isImportant => importance == TodoImportance.important;

  /// 이 할 일이 긴급한 항목인지 알려준다.
  bool get isUrgent => urgency == TodoUrgency.urgent;

  /// 현재 중요도와 긴급도에 해당하는 사분면을 돌려준다.
  TodoQuadrant get quadrant => switch ((importance, urgency)) {
    (TodoImportance.important, TodoUrgency.urgent) => TodoQuadrant.doNow,
    (TodoImportance.important, TodoUrgency.notUrgent) => TodoQuadrant.schedule,
    (TodoImportance.unimportant, TodoUrgency.urgent) => TodoQuadrant.delegate,
    (TodoImportance.unimportant, TodoUrgency.notUrgent) =>
      TodoQuadrant.eliminate,
  };

  /// 지정한 값만 바꾼 새 할 일을 만들고 원본은 유지한다.
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

  /// [target] 사분면에 맞게 중요도와 긴급도를 바꾼 새 할 일을 돌려준다.
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

  /// 할 일을 로컬 데이터베이스에 저장할 수 있는 값으로 변환한다.
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

  /// 저장된 문자열 날짜를 복원하며 값이 없거나 잘못되었으면 null을 돌려준다.
  static DateTime? _dateFromMap(Object? value) {
    return value == null ? null : DateTime.tryParse(value as String);
  }
}
