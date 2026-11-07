import 'package:do_it/services/firebase_bootstrap.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const environment = FirebaseEnvironment(
    projectId: 'test-project',
    messagingSenderId: 'test-sender',
    androidApiKey: 'test-android-key',
    androidAppId: 'test-android-app',
    iosApiKey: 'test-ios-key',
    iosAppId: 'test-ios-app',
    iosBundleId: 'test.bundle',
  );

  test('설정이 없으면 Firebase를 호출하지 않고 로컬로 실행한다', () async {
    var calls = 0;
    final result = await initializeFirebaseIfConfigured(
      platform: TargetPlatform.android,
      isWeb: false,
      initialize: (_) async => calls++,
    );
    expect(result, isFalse);
    expect(calls, 0);
  });

  test('Android 설정으로 Firebase 초기화를 요청한다', () async {
    var calls = 0;
    final result = await initializeFirebaseIfConfigured(
      environment: environment,
      platform: TargetPlatform.android,
      isWeb: false,
      initialize: (options) async {
        calls++;
        expect(options.apiKey, 'test-android-key');
        expect(options.appId, 'test-android-app');
        expect(options.projectId, 'test-project');
      },
    );
    expect(result, isTrue);
    expect(calls, 1);
  });

  test('iOS 설정은 Android 앱 ID와 구분한다', () {
    final options = environment.optionsFor(TargetPlatform.iOS)!;
    expect(options.appId, 'test-ios-app');
    expect(options.apiKey, 'test-ios-key');
    expect(options.iosBundleId, 'test.bundle');
  });

  test('일부 설정만 있으면 값을 노출하지 않고 누락 오류를 알린다', () {
    const incomplete = FirebaseEnvironment(projectId: 'test-project');
    expect(
      () => incomplete.optionsFor(TargetPlatform.android),
      throwsStateError,
    );
  });

  test('iOS 번들 ID가 누락되면 초기화를 막는다', () {
    const incomplete = FirebaseEnvironment(
      projectId: 'test-project',
      messagingSenderId: 'test-sender',
      iosApiKey: 'test-ios-key',
      iosAppId: 'test-ios-app',
    );
    expect(() => incomplete.optionsFor(TargetPlatform.iOS), throwsStateError);
  });

  test('웹과 데스크톱은 모바일 Firebase를 초기화하지 않는다', () async {
    for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
      expect(environment.optionsFor(platform), isNull);
    }
    expect(
      await initializeFirebaseIfConfigured(
        environment: environment,
        platform: TargetPlatform.android,
        isWeb: true,
        initialize: (_) async => fail('웹에서는 초기화하면 안 됩니다.'),
      ),
      isFalse,
    );
  });

  test('초기화 실패를 성공이나 로컬 실행으로 숨기지 않는다', () async {
    await expectLater(
      initializeFirebaseIfConfigured(
        environment: environment,
        platform: TargetPlatform.android,
        isWeb: false,
        initialize: (_) async => throw StateError('test failure'),
      ),
      throwsStateError,
    );
  });
}
