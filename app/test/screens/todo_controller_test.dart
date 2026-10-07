import 'package:do_it/models/todo.dart';
import 'package:do_it/screens/home/todo_controller.dart';
import 'package:do_it/services/todo_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Todo', () {
    test('중요도와 긴급도로 사분면을 구한다', () {
      expect(
        _todo(
          id: '1',
          importance: TodoImportance.important,
          urgency: TodoUrgency.urgent,
        ).quadrant,
        TodoQuadrant.doNow,
      );
      expect(
        _todo(
          id: '2',
          importance: TodoImportance.important,
          urgency: TodoUrgency.notUrgent,
        ).quadrant,
        TodoQuadrant.schedule,
      );
      expect(
        _todo(
          id: '3',
          importance: TodoImportance.unimportant,
          urgency: TodoUrgency.urgent,
        ).quadrant,
        TodoQuadrant.delegate,
      );
      expect(
        _todo(
          id: '4',
          importance: TodoImportance.unimportant,
          urgency: TodoUrgency.notUrgent,
        ).quadrant,
        TodoQuadrant.eliminate,
      );
    });

    test('저장용 Map으로 변환한 뒤 같은 값으로 복원한다', () {
      final original = _todo(
        id: 'map-test',
        dueDate: DateTime(2026, 10, 3),
        isCompleted: true,
      );

      final restored = Todo.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.importance, original.importance);
      expect(restored.urgency, original.urgency);
      expect(restored.isCompleted, isTrue);
      expect(restored.dueDate, original.dueDate);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });
  });

  group('TodoController', () {
    test('미완료와 가까운 마감일을 먼저 정렬한다', () async {
      final completed = _todo(
        id: 'completed',
        isCompleted: true,
        dueDate: DateTime(2026, 10, 1),
      );
      final later = _todo(id: 'later', dueDate: DateTime(2026, 10, 5));
      final sooner = _todo(id: 'sooner', dueDate: DateTime(2026, 10, 2));
      final controller = TodoController(
        InMemoryTodoRepository([completed, later, sooner]),
      );

      await controller.load();

      expect(controller.todos.map((todo) => todo.id), [
        'sooner',
        'later',
        'completed',
      ]);
    });

    test('필터에 맞는 할 일만 노출한다', () async {
      final incomplete = _todo(id: 'incomplete');
      final completed = _todo(id: 'completed', isCompleted: true);
      final controller = TodoController(
        InMemoryTodoRepository([incomplete, completed]),
      );
      await controller.load();

      controller.setFilter(TodoFilter.incomplete);
      expect(controller.visibleTodos, [incomplete]);

      controller.setFilter(TodoFilter.completed);
      expect(controller.visibleTodos, [completed]);
    });

    test('추가, 완료 변경, 삭제를 저장소와 함께 반영한다', () async {
      final repository = InMemoryTodoRepository();
      final controller = TodoController(repository);
      await controller.load();
      final todo = _todo(id: 'crud');

      expect(await controller.add(todo), isTrue);
      expect((await repository.getAll()).single.isCompleted, isFalse);

      expect(await controller.toggle(todo), isTrue);
      expect((await repository.getAll()).single.isCompleted, isTrue);

      expect(await controller.remove(controller.todos.single), isTrue);
      expect(await repository.getAll(), isEmpty);
    });

    test('저장 실패는 되돌리고, 다음 작업이 성공하면 오류 메시지를 지운다', () async {
      final repository = _FailingTodoRepository()..failSave = true;
      final controller = TodoController(repository);
      await controller.load();

      expect(await controller.add(_todo(id: 'fail')), isFalse);
      expect(controller.todos, isEmpty);
      expect(controller.errorMessage, isNotNull);
      expect(controller.loadErrorMessage, isNull);

      repository.failSave = false;
      expect(await controller.add(_todo(id: 'ok')), isTrue);
      expect(controller.errorMessage, isNull);
    });

    test('삭제 실패 뒤 마지막 할 일을 지워도 불러오기 오류로 남지 않는다', () async {
      final repository = _FailingTodoRepository([_todo(id: 'last')]);
      final controller = TodoController(repository);
      await controller.load();

      repository.failDelete = true;
      expect(await controller.remove(controller.todos.single), isFalse);
      expect(controller.todos, hasLength(1));

      repository.failDelete = false;
      expect(await controller.remove(controller.todos.single), isTrue);
      expect(controller.todos, isEmpty);
      expect(controller.errorMessage, isNull);
      expect(controller.loadErrorMessage, isNull);
    });

    test('불러오기에 실패하면 불러오기 오류 메시지를 둔다', () async {
      final controller = TodoController(
        _FailingTodoRepository()..failLoad = true,
      );

      await controller.load();

      expect(controller.isLoading, isFalse);
      expect(controller.loadErrorMessage, isNotNull);
    });
  });
}

class _FailingTodoRepository extends InMemoryTodoRepository {
  _FailingTodoRepository([super.initialTodos]);

  bool failLoad = false;
  bool failSave = false;
  bool failDelete = false;

  @override
  Future<List<Todo>> getAll() {
    if (failLoad) throw Exception('load failed');
    return super.getAll();
  }

  @override
  Future<void> save(Todo todo) {
    if (failSave) throw Exception('save failed');
    return super.save(todo);
  }

  @override
  Future<void> delete(String id) {
    if (failDelete) throw Exception('delete failed');
    return super.delete(id);
  }
}

Todo _todo({
  required String id,
  TodoImportance importance = TodoImportance.important,
  TodoUrgency urgency = TodoUrgency.urgent,
  bool isCompleted = false,
  DateTime? dueDate,
}) {
  final createdAt = DateTime(2026, 9, 30, 12);
  return Todo(
    id: id,
    title: '할 일 $id',
    importance: importance,
    urgency: urgency,
    isCompleted: isCompleted,
    dueDate: dueDate,
    reminderEnabled: false,
    source: TodoSource.manual,
    syncStatus: TodoSyncStatus.localOnly,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}
