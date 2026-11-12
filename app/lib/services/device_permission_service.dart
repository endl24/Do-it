import 'package:permission_handler/permission_handler.dart' as handler;

import 'permission_service.dart';

/// `permission_handler`로 만든 [PermissionService].
///
/// 06 진입 조건은 카메라 권한만 본다. 앨범은 시스템 사진 선택기로 고르므로
/// 사진 접근 권한이 필요 없다.
class DevicePermissionService implements PermissionService {
  const DevicePermissionService();

  /// 묻지 않고 지금의 카메라 권한 상태를 확인한다.
  @override
  Future<AppPermissionStatus> cameraStatus() async =>
      fromStatus(await handler.Permission.camera.status);

  /// OS 권한 창을 띄워 카메라 권한을 요청하고 결과를 돌려준다.
  @override
  Future<AppPermissionStatus> requestCamera() async =>
      fromStatus(await handler.Permission.camera.request(), isRequest: true);

  /// 묻지 않고 지금의 알림 권한 상태를 확인한다.
  @override
  Future<AppPermissionStatus> notificationStatus() async =>
      fromStatus(await handler.Permission.notification.status);

  /// OS 권한 창을 띄워 알림 권한을 요청하고 결과를 돌려준다.
  @override
  Future<AppPermissionStatus> requestNotification() async => fromStatus(
    await handler.Permission.notification.request(),
    isRequest: true,
  );

  /// 기기 설정의 이 앱 화면을 연다. 다시 묻지 않는 거부 상태일 때 쓴다.
  @override
  Future<void> openAppSettings() => handler.openAppSettings();

  /// 패키지의 상태를 화면에서 쓰는 상태로 바꾼다.
  ///
  /// 묻기 전 상태도 패키지는 `denied`로 알려 주므로, 상태를 확인할 때의 `denied`는
  /// [AppPermissionStatus.notDetermined]로, 요청한 결과의 `denied`는 거부로 본다.
  static AppPermissionStatus fromStatus(
    handler.PermissionStatus status, {
    bool isRequest = false,
  }) {
    return switch (status) {
      handler.PermissionStatus.granted ||
      handler.PermissionStatus.limited ||
      handler.PermissionStatus.provisional => AppPermissionStatus.granted,
      handler.PermissionStatus.denied =>
        isRequest
            ? AppPermissionStatus.denied
            : AppPermissionStatus.notDetermined,
      handler.PermissionStatus.permanentlyDenied ||
      handler.PermissionStatus.restricted =>
        AppPermissionStatus.permanentlyDenied,
    };
  }
}
