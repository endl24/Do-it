import 'dart:async';

import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/screens/email_auth/email_auth_screen.dart';
import 'package:do_it/services/account_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../services/fake_account_service.dart';

// 실제 경로를 열어 성공 시 복귀와 취소 결과를 함께 검증한다.
Future<void> _open(
  WidgetTester tester,
  FakeAccountService service, {
  ValueChanged<bool?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => EmailAuthScreen(service: service),
                ),
              );
              onResult?.call(result);
            },
            child: const Text('계정 열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('계정 열기'));
  await tester.pumpAndSettle();
}

// 이메일과 비밀번호 입력란에 테스트 값을 넣는다.
Future<void> _enter(
  WidgetTester tester, {
  String password = 'test-pass',
}) async {
  await tester.enterText(
    find.byKey(const ValueKey('auth-email')),
    ' user@example.com ',
  );
  await tester.enterText(find.byKey(const ValueKey('auth-password')), password);
}

void main() {
  late FakeAccountService service;
  setUp(() => service = FakeAccountService());
  tearDown(() => service.dispose());

  testWidgets('로그인 입력을 검증하고 잘못된 입력은 요청하지 않는다', (tester) async {
    await _open(tester, service);
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
    expect(find.text('올바른 이메일 주소를 입력해 주세요.'), findsOneWidget);
    expect(find.text('비밀번호를 입력해 주세요.'), findsOneWidget);
    expect(service.signInCalls, 0);
  });

  testWidgets('로그인 성공 시 이메일만 정리하고 비밀번호는 유지해 전달한다', (tester) async {
    bool? result;
    await _open(tester, service, onResult: (value) => result = value);
    await _enter(tester, password: ' password with spaces ');
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
    expect(service.submittedEmail, 'user@example.com');
    expect(service.submittedPassword, ' password with spaces ');
    expect(result, isTrue);
    expect(find.byType(EmailAuthScreen), findsNothing);
  });

  testWidgets('가입 비밀번호 길이와 확인 입력을 검증한다', (tester) async {
    await _open(tester, service);
    await tester.tap(find.text('새 계정 만들기'));
    await tester.pumpAndSettle();
    await _enter(tester, password: '123');
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirmation')),
      'different',
    );
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();
    expect(find.text('비밀번호는 6자 이상 입력해 주세요.'), findsOneWidget);
    expect(find.text('비밀번호가 일치하지 않습니다.'), findsOneWidget);
    expect(service.signUpCalls, 0);
  });

  testWidgets('회원가입 성공 시 가입 요청 후 설정으로 복귀한다', (tester) async {
    bool? result;
    await _open(tester, service, onResult: (value) => result = value);
    await tester.tap(find.text('새 계정 만들기'));
    await tester.pumpAndSettle();
    await _enter(tester);
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirmation')),
      'test-pass',
    );
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();
    expect(service.signUpCalls, 1);
    expect(service.signInCalls, 0);
    expect(result, isTrue);
  });

  testWidgets('잘못된 비밀번호와 네트워크 오류는 화면을 유지하고 재시도할 수 있다', (tester) async {
    service.failure = const AccountFailure('이메일 또는 비밀번호가 올바르지 않습니다.');
    await _open(tester, service);
    await _enter(tester);
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
    expect(find.text(service.failure!.message), findsOneWidget);
    service.failure = const AccountFailure(
      '네트워크에 연결할 수 없습니다. 연결 상태를 확인하고 다시 시도해 주세요.',
    );
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
    expect(find.text(service.failure!.message), findsOneWidget);
    service.failure = null;
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
    expect(service.signInCalls, 3);
    expect(find.byType(EmailAuthScreen), findsNothing);
  });

  testWidgets('이미 가입된 이메일은 가입 화면에 오류를 표시한다', (tester) async {
    service.failure = const AccountFailure('이미 가입된 이메일입니다. 로그인해 주세요.');
    await _open(tester, service);
    await tester.tap(find.text('새 계정 만들기'));
    await tester.pumpAndSettle();
    await _enter(tester);
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirmation')),
      'test-pass',
    );
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();
    expect(find.text(service.failure!.message), findsOneWidget);
    expect(find.byType(EmailAuthScreen), findsOneWidget);
  });

  testWidgets('인증 요청 중 입력·중복 제출·뒤로 가기를 막는다', (tester) async {
    service.pending = Completer<void>();
    await _open(tester, service);
    await _enter(tester);
    await tester.tap(find.text('로그인'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '로그인'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('auth-email')))
          .enabled,
      isFalse,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(EmailAuthScreen), findsOneWidget);
    expect(service.signInCalls, 1);
    service.pending!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('로그인 화면 취소는 성공 결과를 반환하지 않는다', (tester) async {
    bool? result = false;
    await _open(tester, service, onResult: (value) => result = value);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(service.signInCalls, 0);
  });

  testWidgets('작은 화면에서 가입 버튼까지 스크롤할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _open(tester, service);
    await tester.tap(find.text('새 계정 만들기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('가입하기'));
    expect(tester.takeException(), isNull);
  });
}
