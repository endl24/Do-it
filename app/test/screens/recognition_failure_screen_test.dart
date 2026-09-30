import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/screens/photo_import/recognition_failure_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 첫 화면(01) → 촬영 화면(06 대신) → 인식 실패 화면 순서로 push한 상태로 띄운다.
Future<void> _pumpFailure(
  WidgetTester tester, {
  int failureCount = 1,
  VoidCallback? onManualEntry,
}) async {
  // 설계서 기준 폰 크기(390×844)로 띄워 아래쪽 안내까지 화면에 들어오게 한다.
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RecognitionFailureScreen(
                              failureCount: failureCount,
                              onManualEntry: onManualEntry ?? () {},
                            ),
                          ),
                        ),
                        child: const Text('촬영'),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('목록'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('목록'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('촬영'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('실패 원인과 다시 시도하는 방법을 보여준다', (tester) async {
    await _pumpFailure(tester);

    expect(find.text('텍스트 인식'), findsOneWidget);
    expect(find.text('글자를 읽지 못했어요'), findsOneWidget);
    expect(find.text('이렇게 해보세요'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(
      find.text('인식에 실패해도 앱은 종료되지 않고, 방금 찍은 사진은 저장되지 않습니다.'),
      findsOneWidget,
    );
    expect(find.text('직접 입력이 더 빠를 수 있어요'), findsNothing);
  });

  testWidgets('세 번 연속 실패하면 직접 입력을 권한다', (tester) async {
    await _pumpFailure(tester, failureCount: 3);

    expect(find.text('직접 입력이 더 빠를 수 있어요'), findsOneWidget);
  });

  testWidgets('다시 촬영은 촬영 화면으로 돌아간다', (tester) async {
    await _pumpFailure(tester);

    await tester.tap(find.text('다시 촬영'));
    await tester.pumpAndSettle();

    expect(find.byType(RecognitionFailureScreen), findsNothing);
    expect(find.text('촬영'), findsOneWidget);
  });

  testWidgets('직접 입력으로 등록을 누르면 onManualEntry를 부른다', (tester) async {
    var isCalled = false;
    await _pumpFailure(tester, onManualEntry: () => isCalled = true);

    await tester.tap(find.text('직접 입력으로 등록'));
    await tester.pumpAndSettle();

    expect(isCalled, isTrue);
  });

  testWidgets('뒤로 가면 촬영 화면을 건너뛰고 첫 화면으로 돌아간다', (tester) async {
    await _pumpFailure(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(RecognitionFailureScreen), findsNothing);
    expect(find.text('촬영'), findsNothing);
    expect(find.text('목록'), findsOneWidget);
  });
}
