import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/todo.dart';
import 'todo_migration.dart';

// 기존 todos 표를 수정하지 않고 별도 SQLite 파일에 이관 상태를 기록한다.
class SqliteMigrationJournal implements TodoMigrationJournal {
  SqliteMigrationJournal({this.databaseName = 'do_it_migration.db'});

  final String databaseName;
  Future<Database>? _database;

  // 이관 중인 스냅샷과 완료 표시를 저장할 단일 행 표를 연다.
  Future<Database> get _db => _database ??= openDatabase(
    databaseName,
    version: 1,
    onCreate: (database, _) => database.execute(
      'CREATE TABLE migration (id INTEGER PRIMARY KEY, uid TEXT NOT NULL, payload TEXT NOT NULL, completed INTEGER NOT NULL)',
    ),
  );

  // 마지막 이관 상태를 읽어 앱 재시작 후에도 같은 작업을 재개한다.
  @override
  Future<TodoMigrationRecord?> read() async {
    final rows = await (await _db).query('migration', where: 'id = 1');
    if (rows.isEmpty) return null;
    final row = rows.single;
    return TodoMigrationRecord(
      uid: row['uid']! as String,
      isCompleted: row['completed'] == 1,
      todos: (jsonDecode(row['payload']! as String) as List).map(
        (value) => Todo.fromMap(Map<String, Object?>.from(value as Map)),
      ),
    );
  }

  // 스냅샷과 완료 여부를 한 행으로 원자적으로 교체한다.
  @override
  Future<void> write(TodoMigrationRecord record) async {
    await (await _db).insert('migration', {
      'id': 1,
      'uid': record.uid,
      'payload': jsonEncode(record.todos.map((todo) => todo.toMap()).toList()),
      'completed': record.isCompleted ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // 이관 기록의 데이터베이스 연결을 해제한다.
  Future<void> close() async {
    final database = _database;
    _database = null;
    if (database != null) await (await database).close();
  }
}
