import 'package:do_it/services/firebase_account_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('로그인 실패는 계정 존재 여부를 구분하지 않는 안내로 변환한다', () {
    for (final code in [
      'wrong-password',
      'invalid-credential',
      'user-not-found',
    ]) {
      expect(
        FirebaseAccountService.failureForCode(code).message,
        '이메일 또는 비밀번호가 올바르지 않습니다.',
      );
    }
  });

  test('중복 이메일·네트워크·보안 정책 오류를 구분해 안내한다', () {
    expect(
      FirebaseAccountService.failureForCode('email-already-in-use').message,
      contains('이미 가입된 이메일'),
    );
    expect(
      FirebaseAccountService.failureForCode('network-request-failed').message,
      contains('네트워크'),
    );
    expect(
      FirebaseAccountService.failureForCode('weak-password').message,
      contains('보안 기준'),
    );
  });
}
