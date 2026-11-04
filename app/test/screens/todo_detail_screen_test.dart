import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/models/todo.dart';
import 'package:do_it/screens/todo_detail/todo_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('할 일 상세 정보와 남은 기간을 표시한다', (tester) async {
    await _pumpDetail(
      tester,
      _todo(dueDate: DateTime(2026, 11, 7), source: TodoSource.photo),
      currentDate: DateTime(2026, 11, 4),
    );

    expect(find.text('중요 · 긴급'), findsOneWidget);
    expect(find.text('발표 자료 정리'), findsOneWidget);
    expect(find.text('2026년 11월 7일'), findsOneWidget);
    expect(find.text('D-3'), findsOneWidget);
    expect(find.text('사진에서 가져옴'), findsOneWidget);
  });

  testWidgets('완료로 표시하면 저장 후 목록으로 돌아간다', (tester) async {
    Todo? updated;
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TodoDetailScreen(
                  todo: _todo(),
                  onUpdate: (todo) async {
                    updated = todo;
                    return true;
                  },
                  onDelete: (_) async => true,
                ),
              ),
            ),
            child: const Text('상세 열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('상세 열기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('완료로 표시'));
    await tester.pumpAndSettle();

    expect(updated?.isCompleted, isTrue);
    expect(find.text('상세 열기'), findsOneWidget);
  });

  testWidgets('삭제 확인 후 삭제 콜백을 호출한다', (tester) async {
    var deleteCount = 0;
    await _pumpDetail(
      tester,
      _todo(),
      onDelete: (_) async {
        deleteCount++;
        return true;
      },
    );

    await tester.tap(find.widgetWithText(OutlinedButton, '삭제'));
    await tester.pumpAndSettle();
    expect(find.text('할 일을 삭제할까요?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();

    expect(deleteCount, 1);
  });
}

Future<void> _pumpDetail(
  WidgetTester tester,
  Todo todo, {
  DateTime? currentDate,
  Future<bool> Function(Todo)? onDelete,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: TodoDetailScreen(
        todo: todo,
        currentDate: currentDate,
        onUpdate: (_) async => true,
        onDelete: onDelete ?? (_) async => true,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Todo _todo({DateTime? dueDate, TodoSource source = TodoSource.manual}) {
  final createdAt = DateTime(2026, 11, 1, 12);
  return Todo(
    id: 'detail',
    title: '발표 자료 정리',
    importance: TodoImportance.important,
    urgency: TodoUrgency.urgent,
    isCompleted: false,
    dueDate: dueDate,
    reminderEnabled: false,
    source: source,
    syncStatus: TodoSyncStatus.localOnly,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}
