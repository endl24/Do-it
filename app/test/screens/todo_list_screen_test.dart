import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/models/todo.dart';
import 'package:do_it/screens/todo_list/todo_list_screen.dart';
import 'package:do_it/services/todo_repository.dart';
import 'package:do_it/widgets/error_retry_card.dart';
import 'package:do_it/widgets/offline_banner.dart';
import 'package:do_it/widgets/sync_status_badge.dart';
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

  group('상태 표시', () {
    testWidgets('불러오기에 실패하면 오류 카드를 보여주고 다시 시도로 회복한다', (tester) async {
      final repository = _LoadFailingTodoRepository(
        failuresLeft: 1,
        todos: [_todo(id: 'retry', title: '과제 제출')],
      );
      await _pumpScreen(tester, repository);

      expect(find.text('할 일을 불러오지 못했습니다'), findsOneWidget);
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(find.text('과제 제출'), findsOneWidget);
      expect(find.text('할 일을 불러오지 못했습니다'), findsNothing);
    });

    testWidgets('세 번 연속 실패하면 문구를 바꾸고 점점 늦게 자동으로 다시 시도한다', (tester) async {
      final repository = _LoadFailingTodoRepository(failuresLeft: 3);
      await _pumpScreen(tester, repository);
      expect(repository.loadCount, 1);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(repository.loadCount, 2);
      expect(find.text(ErrorRetryCard.slowDownMessage), findsNothing);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(repository.loadCount, 3);
      expect(find.text(ErrorRetryCard.slowDownMessage), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      expect(repository.loadCount, 3);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(repository.loadCount, 4);
      expect(find.text('아직 등록한 할 일이 없어요'), findsOneWidget);
    });

    testWidgets('필터 결과가 없을 때 안내를 누르면 전체로 되돌린다', (tester) async {
      await _pumpScreen(
        tester,
        InMemoryTodoRepository([_todo(id: 'open', title: '과제 제출')]),
      );

      await tester.tap(find.widgetWithText(ChoiceChip, '완료'));
      await tester.pumpAndSettle();
      expect(find.text('조건에 맞는 할 일이 없습니다'), findsOneWidget);

      await tester.tap(find.text("필터를 '전체'로 바꿔 보세요"));
      await tester.pumpAndSettle();
      expect(find.text('과제 제출'), findsOneWidget);
      final allChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, '전체'),
      );
      expect(allChip.selected, isTrue);
    });

    testWidgets('오프라인이면 목록 위에 배너를 띄운다', (tester) async {
      await _pumpScreen(tester, InMemoryTodoRepository(), isOnline: false);

      expect(find.text(OfflineBanner.defaultMessage), findsOneWidget);
    });

    testWidgets('동기화하는 할 일이 있을 때만 대기 건수 배지를 보여준다', (tester) async {
      await _pumpScreen(
        tester,
        InMemoryTodoRepository([_todo(id: 'local', title: '단말에만 있음')]),
      );
      expect(find.byType(SyncStatusBadge), findsNothing);

      await _pumpScreen(
        tester,
        InMemoryTodoRepository([
          _todo(id: 'pending', title: '대기', syncStatus: TodoSyncStatus.pending),
          _todo(id: 'synced', title: '반영됨', syncStatus: TodoSyncStatus.synced),
        ]),
      );
      expect(find.text('동기화 대기 1'), findsOneWidget);
    });
  });
}

class _LoadFailingTodoRepository extends InMemoryTodoRepository {
  _LoadFailingTodoRepository({required this.failuresLeft, List<Todo>? todos})
    : super(todos ?? const <Todo>[]);

  int failuresLeft;
  int loadCount = 0;

  @override
  Future<List<Todo>> getAll() {
    loadCount++;
    if (failuresLeft > 0) {
      failuresLeft--;
      throw Exception('load failed');
    }
    return super.getAll();
  }
}

class _SaveFailingTodoRepository extends InMemoryTodoRepository {
  @override
  Future<void> save(Todo todo) => throw Exception('save failed');
}

Future<void> _pumpScreen(
  WidgetTester tester,
  TodoRepository repository, {
  bool isOnline = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: TodoListScreen(
        // 같은 테스트에서 다시 띄울 때 새 화면으로 만든다.
        key: UniqueKey(),
        repository: repository,
        isOnline: isOnline,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Todo _todo({
  required String id,
  required String title,
  TodoSyncStatus syncStatus = TodoSyncStatus.localOnly,
}) {
  final createdAt = DateTime(2026, 9, 30, 12);
  return Todo(
    id: id,
    title: title,
    importance: TodoImportance.important,
    urgency: TodoUrgency.urgent,
    isCompleted: false,
    reminderEnabled: false,
    source: TodoSource.manual,
    syncStatus: syncStatus,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}
