import 'dart:io';

import 'package:do_it/models/todo.dart';
import 'package:do_it/screens/home/todo_controller.dart';
import 'package:do_it/services/sqlite_todo_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late String databasePath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('do_it_sqlite_test');
    databasePath = '${directory.path}/do_it.db';
  });

  tearDown(() async {
    await _closeConnection(databasePath);
    await directory.delete(recursive: true);
  });

  group('SqliteTodoRepository 재시작', () {
    test('저장한 할 일의 모든 값을 재시작 후에도 그대로 불러온다', () async {
      final todo = _todo(
        id: 'full',
        title: '논문 서류 제출',
        importance: TodoImportance.unimportant,
        urgency: TodoUrgency.notUrgent,
        isCompleted: true,
        dueDate: DateTime(2026, 11, 20, 9, 30),
        reminderEnabled: true,
        source: TodoSource.photo,
        syncStatus: TodoSyncStatus.pending,
        remoteId: 'remote-1',
      );
      await SqliteTodoRepository(databaseName: databasePath).save(todo);

      final restored = await (await _restart(databasePath)).getAll();

      expect(restored, hasLength(1));
      expect(restored.single.toMap(), todo.toMap());
    });

    test('마감일이 없는 할 일은 재시작 후에도 마감일이 없다', () async {
      await SqliteTodoRepository(databaseName: databasePath)
          .save(_todo(id: 'no-due'));

      final restored = await (await _restart(databasePath)).getAll();

      expect(restored.single.dueDate, isNull);
    });

    test('수정한 내용을 새 항목을 만들지 않고 재시작 후에도 유지한다', () async {
      final repository = SqliteTodoRepository(databaseName: databasePath);
      final todo = _todo(id: 'edit', dueDate: DateTime(2026, 11, 20));
      await repository.save(todo);
      await repository.save(
        todo.copyWith(
          title: '수정한 제목',
          urgency: TodoUrgency.notUrgent,
          clearDueDate: true,
        ),
      );

      final restored = await (await _restart(databasePath)).getAll();

      expect(restored, hasLength(1));
      expect(restored.single.title, '수정한 제목');
      expect(restored.single.urgency, TodoUrgency.notUrgent);
      expect(restored.single.dueDate, isNull);
    });

    test('완료 상태를 재시작 후에도 유지한다', () async {
      final repository = SqliteTodoRepository(databaseName: databasePath);
      final todo = _todo(id: 'done');
      await repository.save(todo);
      await repository.save(todo.copyWith(isCompleted: true));

      final restored = await (await _restart(databasePath)).getAll();

      expect(restored.single.isCompleted, isTrue);
    });

    test('삭제한 할 일만 재시작 후에도 사라진다', () async {
      final repository = SqliteTodoRepository(databaseName: databasePath);
      await repository.save(_todo(id: 'keep'));
      await repository.save(_todo(id: 'remove'));
      await repository.delete('remove');

      final restored = await (await _restart(databasePath)).getAll();

      expect(restored.map((todo) => todo.id), <String>['keep']);
    });

    test('삭제를 실행 취소하면 재시작 후에도 남아 있다', () async {
      final repository = SqliteTodoRepository(databaseName: databasePath);
      final todo = _todo(id: 'undo');
      await repository.save(todo);
      await repository.delete(todo.id);
      await repository.save(todo);

      final restored = await (await _restart(databasePath)).getAll();

      expect(restored.single.toMap(), todo.toMap());
    });

    test('여러 번 재시작해도 데이터를 유지한다', () async {
      await SqliteTodoRepository(databaseName: databasePath)
          .save(_todo(id: 'first'));
      await (await _restart(databasePath)).save(_todo(id: 'second'));

      final restored = await (await _restart(databasePath)).getAll();

      expect(
        restored.map((todo) => todo.id),
        unorderedEquals(<String>['first', 'second']),
      );
    });
  });

  group('SqliteTodoRepository 조회', () {
    test('처음 열면 빈 목록을 돌려준다', () async {
      final todos = await SqliteTodoRepository(databaseName: databasePath)
          .getAll();

      expect(todos, isEmpty);
    });

    test('미완료를 먼저, 그 안에서는 마감일이 빠른 순으로 돌려준다', () async {
      final repository = SqliteTodoRepository(databaseName: databasePath);
      await repository.save(_todo(id: 'late', dueDate: DateTime(2026, 12, 1)));
      await repository.save(
        _todo(id: 'done', isCompleted: true, dueDate: DateTime(2026, 10, 1)),
      );
      await repository.save(_todo(id: 'soon', dueDate: DateTime(2026, 11, 1)));

      final todos = await repository.getAll();

      expect(todos.map((todo) => todo.id), <String>['soon', 'late', 'done']);
    });
  });

  group('TodoController와 SQLite', () {
    test('앱에서 한 추가·수정·완료·삭제가 재시작 후 목록과 필터에 반영된다', () async {
      final controller = TodoController(
        SqliteTodoRepository(databaseName: databasePath),
      );
      addTearDown(controller.dispose);
      await controller.load();

      final edited = _todo(id: 'edited');
      final done = _todo(id: 'done');
      final removed = _todo(id: 'removed');
      expect(await controller.add(edited), isTrue);
      expect(await controller.add(done), isTrue);
      expect(await controller.add(removed), isTrue);
      expect(await controller.update(edited.copyWith(title: '수정한 제목')), isTrue);
      expect(await controller.toggle(done), isTrue);
      expect(await controller.remove(removed), isTrue);

      final restarted = TodoController(await _restart(databasePath));
      addTearDown(restarted.dispose);
      await restarted.load();

      expect(restarted.loadErrorMessage, isNull);
      expect(
        restarted.todos.map((todo) => todo.id),
        unorderedEquals(<String>['edited', 'done']),
      );
      expect(restarted.incompleteCount, 1);

      restarted.setFilter(TodoFilter.incomplete);
      expect(restarted.visibleTodos.single.title, '수정한 제목');

      restarted.setFilter(TodoFilter.completed);
      expect(restarted.visibleTodos.single.id, 'done');
    });
  });
}

/// 앱을 껐다 켠 상황을 만든다. 연결을 닫아 파일에 저장된 값만 남기고 새 저장소를 돌려준다.
Future<SqliteTodoRepository> _restart(String databasePath) async {
  await _closeConnection(databasePath);
  return SqliteTodoRepository(databaseName: databasePath);
}

/// 데이터베이스 연결을 닫는다. 같은 경로의 연결은 하나만 있으므로 그 연결이 닫힌다.
Future<void> _closeConnection(String databasePath) async {
  final database = await databaseFactory.openDatabase(databasePath);
  await database.close();
}

/// 테스트용 할 일을 만든다. 지정하지 않은 값은 기본값으로 채운다.
Todo _todo({
  required String id,
  String title = '테스트 할 일',
  TodoImportance importance = TodoImportance.important,
  TodoUrgency urgency = TodoUrgency.urgent,
  bool isCompleted = false,
  DateTime? dueDate,
  bool reminderEnabled = false,
  TodoSource source = TodoSource.manual,
  TodoSyncStatus syncStatus = TodoSyncStatus.localOnly,
  String? remoteId,
}) {
  return Todo(
    id: id,
    remoteId: remoteId,
    title: title,
    importance: importance,
    urgency: urgency,
    isCompleted: isCompleted,
    dueDate: dueDate,
    reminderEnabled: reminderEnabled,
    source: source,
    syncStatus: syncStatus,
    createdAt: DateTime(2026, 11, 5, 14, 30),
    updatedAt: DateTime(2026, 11, 5, 14, 30),
  );
}
