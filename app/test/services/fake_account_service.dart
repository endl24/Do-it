import 'dart:async';

import 'package:do_it/services/account_service.dart';

// 실제 네트워크 없이 성공·실패·요청 지연과 계정 변경을 재현한다.
class FakeAccountService implements AccountService {
  final _changes = StreamController<AccountIdentity?>.broadcast();
  AccountIdentity? account;
  AccountFailure? failure;
  Completer<void>? pending;
  int signInCalls = 0;
  int signUpCalls = 0;
  int signOutCalls = 0;
  String? submittedEmail;
  String? submittedPassword;

  @override
  AccountIdentity? get currentAccount => account;

  @override
  Stream<AccountIdentity?> get accountChanges => _changes.stream;

  // 입력값을 기록하고 지정한 지연·실패를 적용한 뒤 로그인 상태를 알린다.
  Future<void> _authenticate(String email, String password) async {
    submittedEmail = email;
    submittedPassword = password;
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
    account = AccountIdentity(uid: 'test-user', email: email);
    _changes.add(account);
  }

  @override
  Future<void> signIn(String email, String password) {
    signInCalls++;
    return _authenticate(email, password);
  }

  @override
  Future<void> signUp(String email, String password) {
    signUpCalls++;
    return _authenticate(email, password);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (failure != null) throw failure!;
    account = null;
    _changes.add(null);
  }

  // 테스트가 끝나면 구독 스트림을 해제한다.
  Future<void> dispose() => _changes.close();
}
