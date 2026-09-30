/// 단말 권한 상태. 권한 패키지의 상태를 화면에서 쓰기 쉽게 줄여 둔 것이다.
enum AppPermissionStatus {
  /// 아직 묻지 않았다. 요청하면 OS 권한 창이 뜬다.
  notDetermined,
  granted,

  /// 거부했지만 다시 요청할 수 있다.
  denied,

  /// 다시 묻지 않도록 거부했다. 설정 화면에서만 켤 수 있다.
  permanentlyDenied,
}

/// 카메라·사진, 알림 권한을 확인하고 요청한다(A18 A32).
// TODO(강두이): 권한 패키지를 팀과 정하면 구현체를 만든다.
abstract interface class PermissionService {
  /// 카메라와 사진 접근을 한 권한처럼 다룬다. 둘 중 하나라도 거부면 거부다.
  Future<AppPermissionStatus> cameraStatus();
  Future<AppPermissionStatus> requestCamera();

  Future<AppPermissionStatus> notificationStatus();
  Future<AppPermissionStatus> requestNotification();

  /// OS의 이 앱 설정 화면을 연다.
  Future<void> openAppSettings();
}
