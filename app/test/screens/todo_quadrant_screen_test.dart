import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/models/todo.dart';
import 'package:do_it/screens/home/todo_controller.dart';
import 'package:do_it/screens/todo_quadrant/todo_quadrant_screen.dart';
import 'package:do_it/services/todo_repository.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('네 사분면과 영역별 할 일을 표시한다', (tester) async {
    final controller = await _controller([
      _todo('now', '오늘 발표 준비', TodoQuadrant.doNow),
      _todo('plan', '다음 주 계획', TodoQuadrant.schedule),
    ]);
    await _pump(tester, controller);

    expect(find.text('지금 한다'), findsOneWidget);
    expect(find.text('계획한다'), findsOneWidget);
    expect(find.text('빨리 끝낸다'), findsOneWidget);
    expect(find.text('미뤄둔다'), findsOneWidget);
    expect(find.text('오늘 발표 준비'), findsOneWidget);
    expect(find.text('다음 주 계획'), findsOneWidget);
    expect(find.text('아직 없음'), findsNWidgets(2));
  });

  testWidgets('카드를 길게 눌러 다른 사분면으로 이동한다', (tester) async {
    final repository = InMemoryTodoRepository([
      _todo('move', '옮길 할 일', TodoQuadrant.doNow),
    ]);
    final controller = TodoController(repository);
    await controller.load();
    await _pump(tester, controller);

    final draggable = find.byKey(const ValueKey('quadrant-todo-move'));
    final target = find.byKey(const ValueKey('quadrant-eliminate'));
    final gesture = await tester.startGesture(tester.getCenter(draggable));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final saved = (await repository.getAll()).single;
    expect(saved.quadrant, TodoQuadrant.eliminate);
    expect(
      find.descendant(of: target, matching: find.text('옮길 할 일')),
      findsOneWidget,
    );
  });

  testWidgets('할 일 카드를 누르면 상세 화면을 연다', (tester) async {
    final controller = await _controller([
      _todo('detail', '상세로 이동', TodoQuadrant.doNow),
    ]);
    await _pump(tester, controller);

    await tester.tap(find.text('상세로 이동'));
    await tester.pumpAndSettle();

    expect(find.text('할 일 상세'), findsOneWidget);
    expect(find.text('완료로 표시'), findsOneWidget);
  });
}

Future<TodoController> _controller(List<Todo> todos) async {
  final controller = TodoController(InMemoryTodoRepository(todos));
  await controller.load();
  return controller;
}

Future<void> _pump(WidgetTester tester, TodoController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: TodoQuadrantScreen(controller: controller),
    ),
  );
  await tester.pumpAndSettle();
}

Todo _todo(String id, String title, TodoQuadrant quadrant) {
  final createdAt = DateTime(2026, 11, 4, 12);
  final importance = switch (quadrant) {
    TodoQuadrant.doNow || TodoQuadrant.schedule => TodoImportance.important,
    TodoQuadrant.delegate ||
    TodoQuadrant.eliminate => TodoImportance.unimportant,
  };
  final urgency = switch (quadrant) {
    TodoQuadrant.doNow || TodoQuadrant.delegate => TodoUrgency.urgent,
    TodoQuadrant.schedule || TodoQuadrant.eliminate => TodoUrgency.notUrgent,
  };
  return Todo(
    id: id,
    title: title,
    importance: importance,
    urgency: urgency,
    isCompleted: false,
    reminderEnabled: false,
    source: TodoSource.manual,
    syncStatus: TodoSyncStatus.localOnly,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}
