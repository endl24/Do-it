import 'dart:io';

import 'package:do_it/services/sqlite_migration_journal.dart';
import 'package:do_it/services/todo_migration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_firestore_todo_store.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('이관 중 스냅샷과 완료 표시는 연결을 닫았다 열어도 유지된다', () async {
    final directory = await Directory.systemTemp.createTemp(
      'do_it_migration_test',
    );
    final path = '${directory.path}/migration.db';
    final first = SqliteMigrationJournal(databaseName: path);
    final second = SqliteMigrationJournal(databaseName: path);
    addTearDown(() async {
      await first.close();
      await second.close();
      await directory.delete(recursive: true);
    });
    await first.write(
      TodoMigrationRecord(uid: 'account-a', todos: [migrationTodo('one')]),
    );
    await first.close();
    final pending = (await second.read())!;
    expect(pending.uid, 'account-a');
    expect(pending.isCompleted, isFalse);
    expect(pending.todos.single.toMap(), migrationTodo('one').toMap());
    await second.write(
      TodoMigrationRecord(uid: 'account-a', todos: const [], isCompleted: true),
    );
    await second.close();
    final complete = (await first.read())!;
    expect(complete.isCompleted, isTrue);
    expect(complete.todos, isEmpty);
  });
}
