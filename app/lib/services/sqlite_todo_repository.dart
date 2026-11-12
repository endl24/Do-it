import 'package:sqflite/sqflite.dart';

import '../models/todo.dart';
import 'todo_repository.dart';

/// 할 일을 기기의 SQLite 데이터베이스에 영구 저장하는 저장소다.
class SqliteTodoRepository implements TodoRepository {
  /// 사용할 SQLite [databaseName]을 지정해 저장소를 만든다.
  SqliteTodoRepository({this.databaseName = 'do_it.db'});

  static const _databaseVersion = 1;
  static const _table = 'todos';

  final String databaseName;
  Database? _database;

  /// 데이터베이스를 처음 사용할 때 열고 할 일 테이블과 인덱스를 준비한다.
  Future<Database> get _db async {
    return _database ??= await openDatabase(
      databaseName,
      version: _databaseVersion,
      onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE $_table (
            id TEXT PRIMARY KEY,
            remote_id TEXT,
            title TEXT NOT NULL,
            importance TEXT NOT NULL,
            urgency TEXT NOT NULL,
            is_completed INTEGER NOT NULL DEFAULT 0,
            due_date TEXT,
            reminder_enabled INTEGER NOT NULL DEFAULT 0,
            source TEXT NOT NULL,
            sync_status TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await database.execute(
          'CREATE INDEX todos_due_date_index ON $_table(due_date)',
        );
        await database.execute(
          'CREATE INDEX todos_updated_at_index ON $_table(updated_at)',
        );
      },
    );
  }

  /// 미완료와 가까운 마감일을 우선해 저장된 할 일을 돌려준다.
  @override
  Future<List<Todo>> getAll() async {
    final database = await _db;
    final rows = await database.query(
      _table,
      orderBy: 'is_completed ASC, due_date ASC, created_at DESC',
    );
    return rows.map(Todo.fromMap).toList(growable: false);
  }

  /// [todo]를 저장하며 같은 식별자의 기존 항목은 교체한다.
  @override
  Future<void> save(Todo todo) async {
    final database = await _db;
    await database.insert(
      _table,
      todo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// [id]와 일치하는 할 일을 SQLite에서 삭제한다.
  @override
  Future<void> delete(String id) async {
    final database = await _db;
    await database.delete(_table, where: 'id = ?', whereArgs: <Object>[id]);
  }
}
