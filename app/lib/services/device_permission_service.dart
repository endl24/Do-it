import 'package:permission_handler/permission_handler.dart' as handler;

import 'permission_service.dart';

/// `permission_handler`로 만든 [PermissionService].
///
/// 06 진입 조건은 카메라 권한만 본다. 앨범은 시스템 사진 선택기로 고르므로
/// 사진 접근 권한이 필요 없다.
class DevicePermissionService implements PermissionService {
  const DevicePermissionService();

  @override
  Future<AppPermissionStatus> cameraStatus() async =>
      fromStatus(await handler.Permission.camera.status);

  @override
  Future<AppPermissionStatus> requestCamera() async =>
      fromStatus(await handler.Permission.camera.request(), isRequest: true);

  @override
  Future<AppPermissionStatus> notificationStatus() async =>
      fromStatus(await handler.Permission.notification.status);

  @override
  Future<AppPermissionStatus> requestNotification() async => fromStatus(
    await handler.Permission.notification.request(),
    isRequest: true,
  );

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
