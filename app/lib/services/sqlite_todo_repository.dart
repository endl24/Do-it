import 'package:sqflite/sqflite.dart';

import '../models/todo.dart';
import 'todo_repository.dart';

class SqliteTodoRepository implements TodoRepository {
  SqliteTodoRepository({this.databaseName = 'do_it.db'});

  static const _databaseVersion = 1;
  static const _table = 'todos';

  final String databaseName;
  Database? _database;

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

  @override
  Future<List<Todo>> getAll() async {
    final database = await _db;
    final rows = await database.query(
      _table,
      orderBy: 'is_completed ASC, due_date ASC, created_at DESC',
    );
    return rows.map(Todo.fromMap).toList(growable: false);
  }

  @override
  Future<void> save(Todo todo) async {
    final database = await _db;
    await database.insert(
      _table,
      todo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String id) async {
    final database = await _db;
    await database.delete(_table, where: 'id = ?', whereArgs: <Object>[id]);
  }
}
