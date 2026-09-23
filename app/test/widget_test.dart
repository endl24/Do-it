import 'package:do_it/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('앱 실행 시 홈 화면이 보인다', (tester) async {
    await tester.pumpWidget(const DoItApp());

    expect(find.text('Home'), findsOneWidget);
  });
}
