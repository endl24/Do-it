import 'package:do_it/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('앱 실행 시 할 일 탭이 먼저 보인다', (tester) async {
    await tester.pumpWidget(const DoItApp());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('할 일'), findsNWidgets(2));
  });

  testWidgets('하단 탭을 누르면 해당 화면으로 바뀐다', (tester) async {
    await tester.pumpWidget(const DoItApp());

    await tester.tap(find.text('일정'));
    await tester.pumpAndSettle();

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.selectedIndex, 1);
    expect(find.text('일정'), findsNWidgets(2));
  });
}
