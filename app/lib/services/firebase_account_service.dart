import 'package:firebase_auth/firebase_auth.dart';

import 'account_service.dart';

// Firebase Auth의 계정 상태와 이메일 인증 요청을 앱의 인증 인터페이스에 연결한다.
class FirebaseAccountService implements AccountService {
  FirebaseAccountService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  AccountIdentity? get currentAccount => _identity(_auth.currentUser);

  @override
  Stream<AccountIdentity?> get accountChanges =>
      _auth.authStateChanges().map(_identity);

  // 익명 계정은 이메일로 연동된 계정과 구분한다.
  AccountIdentity? _identity(User? user) =>
      user == null || user.isAnonymous || user.email == null
      ? null
      : AccountIdentity(uid: user.uid, email: user.email!);

  // Firebase 오류 코드를 안전한 사용자 안내로 변환한다.
  static AccountFailure failureForCode(String code) =>
      AccountFailure(switch (code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => '이메일 또는 비밀번호가 올바르지 않습니다.',
        'email-already-in-use' => '이미 가입된 이메일입니다. 로그인해 주세요.',
        'invalid-email' => '올바른 이메일 주소를 입력해 주세요.',
        'weak-password' || 'password-does-not-meet-requirements' =>
          '비밀번호가 보안 기준에 맞지 않습니다. 더 강한 비밀번호를 입력해 주세요.',
        'network-request-failed' => '네트워크에 연결할 수 없습니다. 연결 상태를 확인하고 다시 시도해 주세요.',
        'too-many-requests' => '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.',
        'user-disabled' => '사용이 중지된 계정입니다.',
        'operation-not-allowed' => '이메일·비밀번호 로그인이 활성화되지 않았습니다.',
        _ => '계정 요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      });

  // 인증 요청을 실행하고 Firebase의 원본 오류 대신 안내 메시지를 전달한다.
  Future<void> _request(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      throw failureForCode(error.code);
    }
  }

  // 기존 이메일 계정으로 로그인한다. 비밀번호는 변형하거나 별도로 저장하지 않는다.
  @override
  Future<void> signIn(String email, String password) => _request(() async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  });

  // 새 이메일 계정을 생성한다. 생성에 성공하면 Firebase가 로그인 상태를 유지한다.
  @override
  Future<void> signUp(String email, String password) => _request(() async {
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  });

  // 현재 기기에서 로그아웃하고 계정 변경 구독으로 화면 갱신을 알린다.
  @override
  Future<void> signOut() => _request(_auth.signOut);
}
