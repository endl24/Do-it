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

  testWidgets('빈 목록에서 저장에 실패하면 빈 상태를 유지하고 안내만 띄운다', (tester) async {
    await _pumpScreen(tester, _SaveFailingTodoRepository());

    await tester.tap(find.text('할 일 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '저장 실패');
    final addButton = find.widgetWithText(FilledButton, '추가');
    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('기기에 저장하지 못했습니다. 저장 공간을 확인해 주세요.'), findsOneWidget);
    expect(find.text('아직 등록한 할 일이 없어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
  });

  group('할 일 삭제', () {
    Future<void> deleteTodo(WidgetTester tester, String title) async {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      final deleteButton = find.text('할 일 삭제');
      await tester.ensureVisible(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
    }

    testWidgets('확인 대화상자에서 취소하면 아무것도 바뀌지 않는다', (tester) async {
      final repository = InMemoryTodoRepository([
        _todo(id: 'keep', title: '졸업 요건 서류 제출'),
      ]);
      await _pumpScreen(tester, repository);

      await deleteTodo(tester, '졸업 요건 서류 제출');
      expect(find.text('할 일을 삭제할까요?'), findsOneWidget);
      expect(
        find.text("'졸업 요건 서류 제출'을 삭제하면 이 할 일에 예약된 알림도 함께 취소됩니다."),
        findsOneWidget,
      );

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(find.text('졸업 요건 서류 제출'), findsOneWidget);
      expect(await repository.getAll(), hasLength(1));
    });

    testWidgets('삭제한 뒤 실행 취소하면 할 일을 되살린다', (tester) async {
      final repository = InMemoryTodoRepository([
        _todo(id: 'undo', title: '스터디 발표 자료 정리'),
      ]);
      await _pumpScreen(tester, repository);

      await deleteTodo(tester, '스터디 발표 자료 정리');
      expect(
        find.text("'스터디 발표 자료 정리'를 삭제하면 이 할 일에 예약된 알림도 함께 취소됩니다."),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, '삭제'));
      await tester.pumpAndSettle();

      expect(find.text('할 일을 삭제했습니다'), findsOneWidget);
      expect(find.text('스터디 발표 자료 정리'), findsNothing);
      expect(await repository.getAll(), isEmpty);

      await tester.tap(find.text('실행 취소'));
      await tester.pumpAndSettle();

      expect(find.text('스터디 발표 자료 정리'), findsOneWidget);
      expect((await repository.getAll()).single.id, 'undo');
    });
  });
}

class _SaveFailingTodoRepository extends InMemoryTodoRepository {
  @override
  Future<void> save(Todo todo) => throw Exception('save failed');
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
