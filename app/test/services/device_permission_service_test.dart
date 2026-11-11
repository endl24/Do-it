import 'package:do_it/services/device_permission_service.dart';
import 'package:do_it/services/permission_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  AppPermissionStatus fromCheck(PermissionStatus status) =>
      DevicePermissionService.fromStatus(status);
  AppPermissionStatus fromRequest(PermissionStatus status) =>
      DevicePermissionService.fromStatus(status, isRequest: true);

  test('허용·제한 허용·임시 허용은 허용으로 본다', () {
    for (final status in [
      PermissionStatus.granted,
      PermissionStatus.limited,
      PermissionStatus.provisional,
    ]) {
      expect(fromCheck(status), AppPermissionStatus.granted);
      expect(fromRequest(status), AppPermissionStatus.granted);
    }
  });

  test('상태 확인의 denied는 아직 묻지 않은 것으로 본다', () {
    expect(
      fromCheck(PermissionStatus.denied),
      AppPermissionStatus.notDetermined,
    );
  });

  test('요청 결과의 denied는 거부로 본다', () {
    expect(fromRequest(PermissionStatus.denied), AppPermissionStatus.denied);
  });

  test('영구 거부와 제한은 설정에서만 켤 수 있는 상태로 본다', () {
    for (final status in [
      PermissionStatus.permanentlyDenied,
      PermissionStatus.restricted,
    ]) {
      expect(fromCheck(status), AppPermissionStatus.permanentlyDenied);
      expect(fromRequest(status), AppPermissionStatus.permanentlyDenied);
    }
  });
}
