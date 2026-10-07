import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/models/todo.dart';
import 'package:do_it/screens/todo_list/todo_list_screen.dart';
import 'package:do_it/services/todo_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('저장된 할 일이 없으면 빈 상태를 표시한다', (tester) async {
    await _pumpScreen(tester, InMemoryTodoRepository());

    expect(find.text('아직 등록한 할 일이 없어요'), findsOneWidget);
    expect(find.text('남은 할 일 0개'), findsOneWidget);
  });

  testWidgets('폼에서 할 일을 등록하면 목록과 저장소에 반영한다', (tester) async {
    final repository = InMemoryTodoRepository();
    await _pumpScreen(tester, repository);

    await tester.tap(find.text('할 일 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '발표 자료 정리');
    final addButton = find.widgetWithText(FilledButton, '추가');
    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('발표 자료 정리'), findsOneWidget);
    expect(find.text('남은 할 일 1개'), findsOneWidget);
    final saved = await repository.getAll();
    expect(saved.single.title, '발표 자료 정리');
    expect(saved.single.quadrant, TodoQuadrant.doNow);
  });

  testWidgets('완료한 할 일은 완료 필터에서 확인할 수 있다', (tester) async {
    final todo = _todo(id: 'filter', title: '과제 제출');
    await _pumpScreen(tester, InMemoryTodoRepository([todo]));

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('남은 할 일 0개'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '완료'));
    await tester.pumpAndSettle();

    expect(find.text('과제 제출'), findsOneWidget);
    expect(find.text('완료', skipOffstage: false), findsNWidgets(2));
  });
}

Future<void> _pumpScreen(WidgetTester tester, TodoRepository repository) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: TodoListScreen(repository: repository),
    ),
  );
  await tester.pumpAndSettle();
}

Todo _todo({required String id, required String title}) {
  final createdAt = DateTime(2026, 9, 30, 12);
  return Todo(
    id: id,
    title: title,
    importance: TodoImportance.important,
    urgency: TodoUrgency.urgent,
    isCompleted: false,
    reminderEnabled: false,
    source: TodoSource.manual,
    syncStatus: TodoSyncStatus.localOnly,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}
