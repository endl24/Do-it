import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/screens/photo_import/candidate_review_screen.dart';
import 'package:do_it/screens/photo_import/todo_candidate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _candidates = [
  TodoCandidate(text: '졸업 서류 제출'),
  TodoCandidate(text: '스터디 자료 정리'),
  TodoCandidate(text: '이번 주 할 일', isLikelyTitle: true),
];

/// 첫 화면 위에 후보 검토 화면을 push한 상태로 띄운다.
Future<void> _pumpReview(
  WidgetTester tester, {
  List<TodoCandidate> candidates = _candidates,
  Future<void> Function(List<String> titles)? onRegister,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CandidateReviewScreen(
                    candidates: candidates,
                    onRegister: onRegister ?? (_) async {},
                  ),
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

FilledButton _registerButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

void main() {
  testWidgets('제목으로 보이는 줄은 기본 해제하고 선택 건수를 버튼에 보여준다', (tester) async {
    await _pumpReview(tester);

    expect(find.text('3개 문장을 찾았어요'), findsOneWidget);
    expect(find.text('제목처럼 보여 기본 해제했어요'), findsOneWidget);
    expect(find.text('선택한 2개 할 일로 등록'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();

    expect(find.text('선택한 3개 할 일로 등록'), findsOneWidget);
    expect(find.text('제목처럼 보여 기본 해제했어요'), findsNothing);
  });

  testWidgets('선택이 0건이면 등록 버튼을 막고 안내한다', (tester) async {
    await _pumpReview(tester);

    await tester.tap(find.byType(Checkbox).at(0));
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();

    expect(find.text('등록할 항목을 한 개 이상 선택해 주세요'), findsOneWidget);
    expect(_registerButton(tester).onPressed, isNull);
  });

  testWidgets('문장을 눌러 수정하면 수정한 문장으로 등록하고 목록으로 돌아간다', (tester) async {
    List<String>? registered;
    await _pumpReview(
      tester,
      onRegister: (titles) async => registered = titles,
    );

    await tester.tap(find.text('졸업 서류 제출'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '졸업 서류 제출하기');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('졸업 서류 제출하기'), findsOneWidget);

    await tester.tap(find.text('선택한 2개 할 일로 등록'));
    await tester.pumpAndSettle();

    expect(registered, ['졸업 서류 제출하기', '스터디 자료 정리']);
    expect(find.byType(CandidateReviewScreen), findsNothing);
    expect(find.text('열기'), findsOneWidget);
  });

  testWidgets('수정 중 100자를 넘기면 더 입력되지 않고 안내한다', (tester) async {
    await _pumpReview(tester);

    await tester.tap(find.byTooltip('문장 수정').first);
    await tester.pump();
    await tester.enterText(find.byType(TextField), '가' * 120);
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text.length, 100);
    expect(find.text('할 일 제목은 최대 100자까지 입력할 수 있어요'), findsOneWidget);
  });

  testWidgets('저장에 실패하면 화면에 남아 다시 시도할 수 있다', (tester) async {
    await _pumpReview(tester, onRegister: (_) async => throw Exception());

    await tester.tap(find.text('선택한 2개 할 일로 등록'));
    await tester.pump();

    expect(find.text('등록하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(find.byType(CandidateReviewScreen), findsOneWidget);
    expect(_registerButton(tester).onPressed, isNotNull);
  });

  testWidgets('뒤로 가면 인식 결과를 버릴지 확인한다', (tester) async {
    await _pumpReview(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('인식 결과를 버릴까요?'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.byType(CandidateReviewScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('버리기'));
    await tester.pumpAndSettle();
    expect(find.byType(CandidateReviewScreen), findsNothing);
  });

  testWidgets('다시 촬영은 확인 없이 이전 화면으로 돌아간다', (tester) async {
    await _pumpReview(tester);

    await tester.tap(find.text('다시 촬영'));
    await tester.pumpAndSettle();

    expect(find.text('인식 결과를 버릴까요?'), findsNothing);
    expect(find.byType(CandidateReviewScreen), findsNothing);
  });
}
