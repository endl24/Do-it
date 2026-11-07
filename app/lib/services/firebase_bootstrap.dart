import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

// 실행 시 전달한 플랫폼별 Firebase 설정을 보관하고 필수 값을 검증한다.
class FirebaseEnvironment {
  const FirebaseEnvironment({
    this.projectId = const String.fromEnvironment('FIREBASE_PROJECT_ID'),
    this.messagingSenderId = const String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    ),
    this.androidApiKey = const String.fromEnvironment(
      'FIREBASE_ANDROID_API_KEY',
    ),
    this.androidAppId = const String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
    this.iosApiKey = const String.fromEnvironment('FIREBASE_IOS_API_KEY'),
    this.iosAppId = const String.fromEnvironment('FIREBASE_IOS_APP_ID'),
    this.iosBundleId = const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
  });

  final String projectId;
  final String messagingSenderId;
  final String androidApiKey;
  final String androidAppId;
  final String iosApiKey;
  final String iosAppId;
  final String iosBundleId;

  // 현재 플랫폼의 설정을 검증한다. 설정이 전혀 없으면 로컬 실행을 선택한다.
  FirebaseOptions? optionsFor(TargetPlatform platform) {
    final String apiKey;
    final String appId;
    switch (platform) {
      case TargetPlatform.android:
        apiKey = androidApiKey;
        appId = androidAppId;
      case TargetPlatform.iOS:
        apiKey = iosApiKey;
        appId = iosAppId;
      default:
        return null;
    }

    final requiredValues = [projectId, messagingSenderId, apiKey, appId];
    if (requiredValues.every((value) => value.trim().isEmpty)) return null;
    if (requiredValues.any((value) => value.trim().isEmpty) ||
        (platform == TargetPlatform.iOS && iosBundleId.trim().isEmpty)) {
      throw StateError('현재 플랫폼의 Firebase 필수 설정이 누락되었습니다.');
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      iosBundleId: platform == TargetPlatform.iOS ? iosBundleId : null,
    );
  }
}

// Android·iOS에 설정이 있을 때만 Firebase를 초기화하고 실행 여부를 반환한다.
Future<bool> initializeFirebaseIfConfigured({
  FirebaseEnvironment environment = const FirebaseEnvironment(),
  TargetPlatform? platform,
  bool? isWeb,
  Future<void> Function(FirebaseOptions options)? initialize,
}) async {
  if (isWeb ?? kIsWeb) return false;
  final options = environment.optionsFor(platform ?? defaultTargetPlatform);
  if (options == null) return false;
  if (initialize != null) {
    await initialize(options);
  } else {
    await Firebase.initializeApp(options: options);
  }
  return true;
}
