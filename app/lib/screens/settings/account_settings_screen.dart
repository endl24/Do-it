import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../services/account_service.dart';
import '../../services/firebase_account_service.dart';
import '../email_auth/email_auth_screen.dart';
import 'settings_screen.dart';

// 인증 상태를 설정 화면에 연결한다. Firebase 없이 실행하면 기존 설정 화면을 유지한다.
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key, this.service});

  final AccountService? service;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

// 인증 서비스를 한 번 만들고 계정 상태 구독을 통해 로그인·로그아웃을 화면에 반영한다.
class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late final AccountService? _service;
  late final Stream<AccountIdentity?>? _changes;

  // Firebase가 초기화된 경우에만 실제 인증 서비스를 연결한다.
  @override
  void initState() {
    super.initState();
    _service =
        widget.service ??
        (Firebase.apps.isEmpty ? null : FirebaseAccountService());
    _changes = _service?.accountChanges;
  }

  // 로그인 화면의 성공과 취소를 구분해 설정 화면으로 전달한다.
  Future<bool> _authenticate() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EmailAuthScreen(service: _service!)),
    );
    return result == true;
  }

  // 복원된 로그인 계정과 이후 상태 변경을 설정 화면에 전달한다.
  @override
  Widget build(BuildContext context) {
    final service = _service;
    if (service == null) return const SettingsScreen();
    return StreamBuilder<AccountIdentity?>(
      stream: _changes,
      initialData: service.currentAccount,
      builder: (context, snapshot) {
        final account = snapshot.data;
        return SettingsScreen(
          isLinked: account != null,
          accountEmail: account?.email,
          onAuthenticate: _authenticate,
          onLogout: service.signOut,
        );
      },
    );
  }
}
