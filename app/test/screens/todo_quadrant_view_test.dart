import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/models/todo.dart';
import 'package:do_it/screens/home/widgets/empty_todo_view.dart';
import 'package:do_it/screens/todo_list/todo_list_screen.dart';
import 'package:do_it/services/todo_repository.dart';
import 'package:do_it/widgets/error_retry_card.dart';
import 'package:do_it/widgets/offline_banner.dart';
import 'package:do_it/widgets/quadrant_tag.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('네 사분면과 영역별 할 일을 표시한다', (tester) async {
    await _pumpQuadrant(
      tester,
      InMemoryTodoRepository([
        _todo('now', '오늘 발표 준비', TodoQuadrant.doNow),
        _todo('plan', '다음 주 계획', TodoQuadrant.schedule),
      ]),
    );

    expect(find.text('지금 한다'), findsOneWidget);
    expect(find.text('계획한다'), findsOneWidget);
    expect(find.text('빨리 끝낸다'), findsOneWidget);
    expect(find.text('미뤄둔다'), findsOneWidget);
    expect(find.text('오늘 발표 준비'), findsOneWidget);
    expect(find.text('다음 주 계획'), findsOneWidget);
    expect(find.text('아직 없음'), findsNWidgets(2));
  });

  testWidgets('카드는 제목만 보여주고 체크박스와 태그는 넣지 않는다', (tester) async {
    await _pumpQuadrant(
      tester,
      InMemoryTodoRepository([_todo('card', '제목만', TodoQuadrant.delegate)]),
    );

    expect(find.text('제목만'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(QuadrantTag), findsNothing);
  });

  testWidgets('새 화면을 띄우지 않고 탭 안에서 전환하며 필터와 추가 버튼을 숨긴다', (tester) async {
    await _pumpQuadrant(
      tester,
      InMemoryTodoRepository([_todo('tab', '탭 안에서', TodoQuadrant.doNow)]),
    );

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.text('목록'));
    await tester.pumpAndSettle();

    expect(find.text('남은 할 일 1개'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('오프라인이면 사분면에서도 배너를 띄운다', (tester) async {
    await _pumpQuadrant(
      tester,
      InMemoryTodoRepository([_todo('offline', '오프라인', TodoQuadrant.doNow)]),
      isOnline: false,
    );

    expect(find.text(OfflineBanner.defaultMessage), findsOneWidget);
  });

  testWidgets('카드를 길게 눌러 다른 사분면으로 이동한다', (tester) async {
    final repository = InMemoryTodoRepository([
      _todo('move', '옮길 할 일', TodoQuadrant.doNow),
    ]);
    await _pumpQuadrant(tester, repository);

    await _dragToEliminate(tester, 'move');

    final saved = (await repository.getAll()).single;
    expect(saved.quadrant, TodoQuadrant.eliminate);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('quadrant-eliminate')),
        matching: find.text('옮길 할 일'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('옮기기 저장에 실패하면 원래 영역으로 돌리고 안내한다', (tester) async {
    await _pumpQuadrant(
      tester,
      _SaveFailingTodoRepository([
        _todo('fail', '못 옮기는 일', TodoQuadrant.doNow),
      ]),
    );

    await _dragToEliminate(tester, 'fail');

    expect(find.text('기기에 저장하지 못했습니다. 저장 공간을 확인해 주세요.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('quadrant-doNow')),
        matching: find.text('못 옮기는 일'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('할 일 카드를 누르면 상세 화면을 연다', (tester) async {
    await _pumpQuadrant(
      tester,
      InMemoryTodoRepository([_todo('detail', '상세로 이동', TodoQuadrant.doNow)]),
    );

    await tester.tap(find.text('상세로 이동'));
    await tester.pumpAndSettle();

    expect(find.text('할 일 상세'), findsOneWidget);
    expect(find.text('완료로 표시'), findsOneWidget);
  });

  testWidgets('상세에서 삭제해도 실행 취소로 되살리고 사분면에 머문다', (tester) async {
    final repository = InMemoryTodoRepository([
      _todo('undo', '지울 일', TodoQuadrant.schedule),
    ]);
    await _pumpQuadrant(tester, repository);

    await _deleteFromDetail(tester, '지울 일');

    expect(find.text('아직 없음'), findsNWidgets(4));
    expect(await repository.getAll(), isEmpty);

    await tester.tap(find.text('실행 취소'));
    await tester.pumpAndSettle();

    expect(find.text('지울 일'), findsOneWidget);
    expect(find.text('지금 한다'), findsOneWidget);
    expect((await repository.getAll()).single.id, 'undo');
  });

  testWidgets('마지막 할 일을 지우면 네 영역이 비고 목록으로 가면 02 빈 상태가 된다', (tester) async {
    await _pumpQuadrant(
      tester,
      InMemoryTodoRepository([_todo('last', '마지막', TodoQuadrant.doNow)]),
    );

    await _deleteFromDetail(tester, '마지막');
    expect(find.text('아직 없음'), findsNWidgets(4));
    expect(find.byType(EmptyTodoView), findsNothing);

    await tester.tap(find.text('목록'));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyTodoView), findsOneWidget);
    expect(find.text('사분면'), findsNothing);
  });

  testWidgets('불러오기에 실패하면 빈 영역 대신 오류 카드를 보여준다', (tester) async {
    await _pumpScreen(tester, _LoadFailingTodoRepository());
    expect(find.byType(ErrorRetryCard), findsOneWidget);

    await tester.tap(find.text('사분면'));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorRetryCard), findsOneWidget);
    expect(find.text('아직 없음'), findsNothing);
    expect(find.text('지금 한다'), findsNothing);
  });

  for (final size in const [Size(320, 568), Size(393, 852)]) {
    testWidgets('${size.width.toInt()}폭 화면에서 넘치지 않는다', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pumpQuadrant(
        tester,
        InMemoryTodoRepository([
          for (final quadrant in TodoQuadrant.values)
            for (var i = 0; i < 5; i++)
              _todo(
                '${quadrant.name}-$i',
                '제목이 아주 길어서 카드 안에서 여러 줄로 넘어가는 할 일 $i',
                quadrant,
              ),
        ]),
      );

      expect(tester.takeException(), isNull);
    });
  }
}

class _SaveFailingTodoRepository extends InMemoryTodoRepository {
  _SaveFailingTodoRepository(super.todos);

  @override
  Future<void> save(Todo todo) => throw Exception('save failed');
}

class _LoadFailingTodoRepository extends InMemoryTodoRepository {
  @override
  Future<List<Todo>> getAll() => throw Exception('load failed');
}

Future<void> _pumpScreen(
  WidgetTester tester,
  TodoRepository repository, {
  bool isOnline = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: TodoListScreen(repository: repository, isOnline: isOnline),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpQuadrant(
  WidgetTester tester,
  TodoRepository repository, {
  bool isOnline = true,
}) async {
  await _pumpScreen(tester, repository, isOnline: isOnline);
  await tester.tap(find.text('사분면'));
  await tester.pumpAndSettle();
}

Future<void> _dragToEliminate(WidgetTester tester, String id) async {
  final draggable = find.byKey(ValueKey('quadrant-todo-$id'));
  final target = find.byKey(const ValueKey('quadrant-eliminate'));
  final gesture = await tester.startGesture(tester.getCenter(draggable));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  await gesture.moveTo(tester.getCenter(target));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _deleteFromDetail(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(OutlinedButton, '삭제'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, '삭제'));
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
