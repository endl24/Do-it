import 'package:do_it/core/theme/app_spacing.dart';
import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/models/todo.dart';
import 'package:do_it/screens/home/widgets/empty_todo_view.dart';
import 'package:do_it/screens/todo_list/todo_list_screen.dart';
import 'package:do_it/services/todo_repository.dart';
import 'package:do_it/widgets/error_retry_card.dart';
import 'package:do_it/widgets/offline_banner.dart';
import 'package:do_it/widgets/sync_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('02 빈 상태', () {
    testWidgets('할 일이 0건이면 두 버튼만 보여주고 필터·요약·FAB는 숨긴다', (tester) async {
      await _pumpScreen(tester, InMemoryTodoRepository());

      expect(find.byType(EmptyTodoView), findsOneWidget);
      expect(find.text('아직 등록한 할 일이 없어요'), findsOneWidget);
      expect(find.text('할 일 직접 추가'), findsOneWidget);
      expect(find.text('사진에서 가져오기'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('남은 할 일 0개'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('[할 일 직접 추가]로 등록하면 목록·필터·FAB로 돌아간다', (tester) async {
      final repository = InMemoryTodoRepository();
      await _pumpScreen(tester, repository);

      await _addTodoFromEmptyState(tester, '첫 할 일');

      expect(find.byType(EmptyTodoView), findsNothing);
      expect(find.text('첫 할 일'), findsOneWidget);
      expect(find.text('남은 할 일 1개'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(3));
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect((await repository.getAll()).single.title, '첫 할 일');
    });

    testWidgets('[사진에서 가져오기]는 준비 중이라고 안내하고 화면을 바꾸지 않는다', (tester) async {
      await _pumpScreen(tester, InMemoryTodoRepository());

      await tester.tap(find.text('사진에서 가져오기'));
      await tester.pump();

      expect(find.text('사진에서 가져오기는 아직 준비 중입니다.'), findsOneWidget);
      expect(find.byType(EmptyTodoView), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('완료 필터에서 마지막 할 일을 지우고 추가해도 새 할 일이 보인다', (tester) async {
      final repository = InMemoryTodoRepository([
        _todo(id: 'last', title: '마지막 할 일'),
      ]);
      await _pumpScreen(tester, repository);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '완료'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('마지막 할 일'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '삭제'));
      await tester.pumpAndSettle();
      expect(find.byType(EmptyTodoView), findsOneWidget);

      await _addTodoFromEmptyState(tester, '새 할 일');

      expect(find.text('새 할 일'), findsOneWidget);
    });

    testWidgets('작은 화면에서도 넘치지 않고 스크롤해 버튼에 닿을 수 있다', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pumpScreen(tester, InMemoryTodoRepository());

      expect(tester.takeException(), isNull);
      final photoButton = find.text('사진에서 가져오기');
      await tester.ensureVisible(photoButton);
      await tester.pumpAndSettle();
      await tester.tap(photoButton);
      await tester.pump();
      expect(find.text('사진에서 가져오기는 아직 준비 중입니다.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('불러오기에 실패하면 빈 상태 대신 오류 카드를 보여준다', (tester) async {
      await _pumpScreen(tester, _LoadFailingTodoRepository(failuresLeft: 1));

      expect(find.byType(EmptyTodoView), findsNothing);
      expect(find.byType(ErrorRetryCard), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  testWidgets('폼에서 할 일을 등록하면 목록과 저장소에 반영한다', (tester) async {
    final repository = InMemoryTodoRepository();
    await _pumpScreen(tester, repository);

    await _addTodoFromEmptyState(tester, '발표 자료 정리');

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

  testWidgets('필터 칩은 화면 왼쪽 여백에 맞춰 시작한다', (tester) async {
    await _pumpScreen(
      tester,
      InMemoryTodoRepository([_todo(id: 'chip', title: '과제 제출')]),
    );

    final firstChip = find.widgetWithText(ChoiceChip, '전체');
    expect(tester.getTopLeft(firstChip).dx, AppSpacing.screenHorizontal);
  });

  testWidgets('할 일 카드를 누르면 상세 화면을 연다', (tester) async {
    final todo = _todo(id: 'detail', title: '상세에서 확인할 일');
    await _pumpScreen(tester, InMemoryTodoRepository([todo]));

    await tester.tap(find.text('상세에서 확인할 일'));
    await tester.pumpAndSettle();

    expect(find.text('할 일 상세'), findsOneWidget);
    expect(find.text('수정'), findsOneWidget);
    expect(find.text('완료로 표시'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);
  });

  testWidgets('상세에서 완료 상태를 바꾸면 목록에 바뀐 상태를 안내한다', (tester) async {
    final repository = InMemoryTodoRepository([
      _todo(id: 'toggle', title: '상태를 바꿀 일'),
    ]);
    await _pumpScreen(tester, repository);

    await tester.tap(find.text('상태를 바꿀 일'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('완료로 표시'));
    await tester.pumpAndSettle();

    expect(find.text('할 일을 완료했습니다.'), findsOneWidget);
    expect((await repository.getAll()).single.isCompleted, isTrue);

    await tester.tap(find.text('상태를 바꿀 일'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('미완료로 표시'));
    await tester.pumpAndSettle();

    expect(find.text('미완료로 변경했습니다.'), findsOneWidget);
    expect((await repository.getAll()).single.isCompleted, isFalse);
  });

  testWidgets('빈 목록에서 저장에 실패하면 빈 상태를 유지하고 안내만 띄운다', (tester) async {
    await _pumpScreen(tester, _SaveFailingTodoRepository());

    await _addTodoFromEmptyState(tester, '저장 실패');

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

  group('할 일 삭제', () {
    Future<void> deleteTodo(WidgetTester tester, String title) async {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      final deleteButton = find.widgetWithText(OutlinedButton, '삭제');
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

    testWidgets('상세에서 수정한 뒤 삭제하고 실행 취소하면 수정한 내용으로 되살린다', (tester) async {
      final repository = InMemoryTodoRepository([
        _todo(id: 'edited', title: '원래 제목'),
      ]);
      await _pumpScreen(tester, repository);

      await tester.tap(find.text('원래 제목'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('수정'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '수정한 제목');
      final saveButton = find.widgetWithText(FilledButton, '저장');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, '삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('실행 취소'));
      await tester.pumpAndSettle();

      expect(find.text('수정한 제목'), findsOneWidget);
      expect((await repository.getAll()).single.title, '수정한 제목');
    });
  });

  testWidgets('사분면 세그먼트를 누르면 사분면 보기로 바꾼다', (tester) async {
    await _pumpScreen(
      tester,
      InMemoryTodoRepository([_todo(id: 'segment', title: '전환할 일')]),
    );

    await tester.tap(find.text('사분면'));
    await tester.pumpAndSettle();

    expect(find.text('사분면'), findsNWidgets(2));
    expect(find.text('지금 한다'), findsOneWidget);
    expect(find.text('계획한다'), findsOneWidget);
    expect(find.text('빨리 끝낸다'), findsOneWidget);
    expect(find.text('미뤄둔다'), findsOneWidget);
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

/// 02의 [할 일 직접 추가]로 03을 열어 제목만 입력하고 등록한다.
Future<void> _addTodoFromEmptyState(WidgetTester tester, String title) async {
  await tester.tap(find.text('할 일 직접 추가'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField), title);
  final addButton = find.widgetWithText(FilledButton, '추가');
  await tester.ensureVisible(addButton);
  await tester.pumpAndSettle();
  await tester.tap(addButton);
  await tester.pumpAndSettle();
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
