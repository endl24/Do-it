/// 로그인한 계정을 구분하는 ID와 화면에 표시할 이메일을 보관한다.
class AccountIdentity {
  /// 계정 ID [uid]와 이메일 [email]로 계정 정보를 만든다.
  const AccountIdentity({required this.uid, required this.email});

  final String uid;
  final String email;
}

/// 인증 실패를 화면에서 안내할 수 있는 메시지로 전달한다.
class AccountFailure implements Exception {
  /// 화면에 보여 줄 안내 문구 [message]로 실패를 만든다.
  const AccountFailure(this.message);

  final String message;
}

/// 인증 구현과 화면을 분리해 실제 Firebase와 테스트용 서비스를 교체한다.
abstract interface class AccountService {
  /// 지금 로그인된 계정을 돌려준다. 로그인하지 않았으면 null이다.
  AccountIdentity? get currentAccount;

  /// 로그인·로그아웃으로 계정이 바뀔 때마다 새 계정(없으면 null)을 보낸다.
  Stream<AccountIdentity?> get accountChanges;

  /// 이메일과 비밀번호로 기존 계정에 로그인한다.
  Future<void> signIn(String email, String password);

  /// 이메일과 비밀번호로 계정을 생성하고 로그인한다.
  Future<void> signUp(String email, String password);

  /// 현재 기기의 로그인 상태를 해제한다.
  Future<void> signOut();
}
