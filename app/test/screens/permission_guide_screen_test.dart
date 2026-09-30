import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/screens/photo_import/permission_guide_screen.dart';
import 'package:do_it/services/permission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePermissionService implements PermissionService {
  _FakePermissionService({
    this.camera = AppPermissionStatus.notDetermined,
    this.notification = AppPermissionStatus.notDetermined,
    this.cameraAnswer = AppPermissionStatus.granted,
    this.notificationAnswer = AppPermissionStatus.granted,
  });

  AppPermissionStatus camera;
  AppPermissionStatus notification;

  /// 권한 창에서 사용자가 고를 답
  final AppPermissionStatus cameraAnswer;
  final AppPermissionStatus notificationAnswer;

  var settingsOpenCount = 0;

  @override
  Future<AppPermissionStatus> cameraStatus() async => camera;

  @override
  Future<AppPermissionStatus> requestCamera() async => camera = cameraAnswer;

  @override
  Future<AppPermissionStatus> notificationStatus() async => notification;

  @override
  Future<AppPermissionStatus> requestNotification() async =>
      notification = notificationAnswer;

  @override
  Future<void> openAppSettings() async => settingsOpenCount++;
}

/// 첫 화면(01) → 권한 안내 화면 순서로 push한 상태로 띄운다.
Future<void> _pumpGuide(
  WidgetTester tester,
  _FakePermissionService service, {
  VoidCallback? onCameraGranted,
}) async {
  // 설계서 기준 폰 크기(390×844)보다 길게 띄워 알림 카드까지 화면에 들어오게 한다.
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PermissionGuideScreen(
                    permissionService: service,
                    onCameraGranted: onCameraGranted ?? () {},
                  ),
                ),
              ),
              child: const Text('목록'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('목록'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('처음에는 권한이 필요한 이유와 사진 처리 방식을 보여준다', (tester) async {
    await _pumpGuide(tester, _FakePermissionService());

    expect(find.text('권한 안내'), findsOneWidget);
    expect(find.text('이 기능에는\n권한이 필요합니다'), findsOneWidget);
    expect(find.text('카메라 · 사진'), findsOneWidget);
    expect(
      find.text('촬영한 사진은 단말 안에서만 처리되고 외부로 전송되지 않으며, 등록이 끝나면 삭제됩니다.'),
      findsOneWidget,
    );
    expect(find.text('권한 허용하기'), findsOneWidget);
    expect(find.text('알림 허용하기'), findsOneWidget);
    expect(find.text('권한을 거부해도 직접 입력으로 할 일을 등록하고 관리할 수 있습니다.'), findsOneWidget);
  });

  testWidgets('카메라 권한을 허용하면 촬영 화면으로 넘어간다', (tester) async {
    var isGranted = false;
    await _pumpGuide(
      tester,
      _FakePermissionService(),
      onCameraGranted: () => isGranted = true,
    );

    await tester.tap(find.text('권한 허용하기'));
    await tester.pumpAndSettle();

    expect(isGranted, isTrue);
  });

  testWidgets('카메라 권한을 거부하면 화면에 남아 안내한다', (tester) async {
    var isGranted = false;
    await _pumpGuide(
      tester,
      _FakePermissionService(cameraAnswer: AppPermissionStatus.denied),
      onCameraGranted: () => isGranted = true,
    );

    await tester.tap(find.text('권한 허용하기'));
    await tester.pumpAndSettle();

    expect(isGranted, isFalse);
    expect(find.byType(PermissionGuideScreen), findsOneWidget);
    expect(find.text('현재 거부됨 — 사진으로 등록할 수 없습니다'), findsOneWidget);
    expect(find.textContaining('사진으로 등록하려면 카메라와 사진 접근이 필요합니다'), findsOneWidget);
    expect(find.text('권한 허용하기'), findsOneWidget);
  });

  testWidgets('카메라 권한을 영구 거부했으면 설정에서 켜도록 바꿔 보여준다', (tester) async {
    final service = _FakePermissionService(
      camera: AppPermissionStatus.permanentlyDenied,
    );
    await _pumpGuide(tester, service);

    expect(find.text('권한 허용하기'), findsNothing);
    await tester.tap(find.text('설정에서 권한 켜기'));
    await tester.pump();

    expect(service.settingsOpenCount, 1);
  });

  testWidgets('알림 권한이 거부됐으면 상태와 설정 이동 경로를 보여준다', (tester) async {
    final service = _FakePermissionService(
      notification: AppPermissionStatus.denied,
    );
    await _pumpGuide(tester, service);

    expect(find.text('현재 거부됨 — 알림이 오지 않습니다'), findsOneWidget);
    expect(
      find.text('설정 > 앱 > Do it > 알림 에서 언제든 다시 켤 수 있습니다.'),
      findsOneWidget,
    );

    await tester.tap(find.text('설정에서 알림 켜기'));
    await tester.pump();

    expect(service.settingsOpenCount, 1);
  });

  testWidgets('알림 허용하기를 누르면 권한을 요청하고 결과를 보여준다', (tester) async {
    await _pumpGuide(
      tester,
      _FakePermissionService(notificationAnswer: AppPermissionStatus.denied),
    );

    await tester.tap(find.text('알림 허용하기'));
    await tester.pumpAndSettle();

    expect(find.text('알림 허용하기'), findsNothing);
    expect(find.text('현재 거부됨 — 알림이 오지 않습니다'), findsOneWidget);
  });

  testWidgets('설정에서 권한을 켜고 돌아오면 상태를 다시 읽는다', (tester) async {
    final service = _FakePermissionService(
      notification: AppPermissionStatus.denied,
    );
    await _pumpGuide(tester, service);

    service.notification = AppPermissionStatus.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('허용됨 — 마감 알림을 받습니다'), findsOneWidget);
    expect(find.text('설정에서 알림 켜기'), findsNothing);
  });

  testWidgets('나중에 하기는 첫 화면으로 돌아간다', (tester) async {
    await _pumpGuide(tester, _FakePermissionService());

    await tester.tap(find.text('나중에 하기'));
    await tester.pumpAndSettle();

    expect(find.byType(PermissionGuideScreen), findsNothing);
    expect(find.text('목록'), findsOneWidget);
  });
}
