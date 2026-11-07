import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/screens/settings/account_settings_screen.dart';
import 'package:do_it/services/account_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../services/fake_account_service.dart';

// 실제 설정 화면과 인증 경로를 가짜 서비스에 연결한다.
Future<void> _pump(WidgetTester tester, FakeAccountService service) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: AccountSettingsScreen(service: service),
    ),
  );
  await tester.pumpAndSettle();
}

// 스크롤 아래에 있는 설정 항목도 화면에 보이게 한 뒤 누른다.
Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  late FakeAccountService service;
  setUp(() => service = FakeAccountService());
  tearDown(() => service.dispose());

  testWidgets('서비스에서 복원된 로그인 상태와 이메일을 표시한다', (tester) async {
    service.account = const AccountIdentity(
      uid: 'saved-user',
      email: 'saved@example.com',
    );
    await _pump(tester, service);
    expect(find.text('연동된 계정으로 로그인됨'), findsOneWidget);
    expect(find.text('saved@example.com'), findsOneWidget);
  });

  testWidgets('계정 연동 화면에서 로그인하면 이메일과 연동 상태가 반영된다', (tester) async {
    await _pump(tester, service);
    await _tap(tester, '연동하기');
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'user@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'test-pass',
    );
    await _tap(tester, '로그인');
    expect(find.text('연동됨'), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);
    expect(find.text('계정을 연동했습니다'), findsOneWidget);
  });

  testWidgets('계정 연동을 취소하면 미연동 상태를 유지한다', (tester) async {
    await _pump(tester, service);
    await _tap(tester, '연동하기');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('계정이 연동되지 않았습니다'), findsOneWidget);
    expect(find.text('계정을 연동했습니다'), findsNothing);
  });

  testWidgets('로그아웃 취소는 계정을 유지하고 확인하면 미연동으로 바뀐다', (tester) async {
    service.account = const AccountIdentity(
      uid: 'saved-user',
      email: 'saved@example.com',
    );
    await _pump(tester, service);
    await _tap(tester, '로그아웃');
    await _tap(tester, '취소');
    expect(service.signOutCalls, 0);
    await _tap(tester, '로그아웃');
    await _tap(tester, '로그아웃');
    expect(service.signOutCalls, 1);
    expect(find.text('계정이 연동되지 않았습니다'), findsOneWidget);
    expect(find.text('saved@example.com'), findsNothing);
  });

  testWidgets('로그아웃 실패 시 계정을 유지하고 수동으로 재시도한다', (tester) async {
    service.account = const AccountIdentity(
      uid: 'saved-user',
      email: 'saved@example.com',
    );
    service.failure = const AccountFailure('네트워크 연결을 확인해 주세요.');
    await _pump(tester, service);
    await _tap(tester, '로그아웃');
    await _tap(tester, '로그아웃');
    expect(find.text('네트워크 연결을 확인해 주세요.'), findsOneWidget);
    expect(find.text('saved@example.com'), findsOneWidget);
    service.failure = null;
    await _tap(tester, '다시 시도');
    expect(service.signOutCalls, 2);
    expect(find.text('계정이 연동되지 않았습니다'), findsOneWidget);
  });
}
