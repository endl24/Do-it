import 'package:flutter/material.dart';

import 'app.dart';
import 'services/firebase_bootstrap.dart';

// Firebase 설정을 확인하고 초기화한 뒤 앱을 실행한다.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isFirebaseReady = await initializeFirebaseIfConfigured();
  debugPrint(
    isFirebaseReady ? 'Firebase 초기화 완료' : 'Firebase 없이 기존 로컬 앱으로 실행합니다.',
  );
  runApp(const DoItApp());
}
