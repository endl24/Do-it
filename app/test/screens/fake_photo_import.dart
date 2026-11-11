import 'dart:io';

import 'package:do_it/services/memo_scanner.dart';
import 'package:do_it/services/permission_service.dart';
import 'package:flutter/material.dart';

/// 기기 카메라·인식 대신 정해 둔 줄을 돌려주는 [MemoScanner].
class FakeMemoScanner implements MemoScanner {
  FakeMemoScanner({
    this.lines = const ['이번 주 할 일', '- 졸업 서류 제출', '- 도서관 책 반납'],
    File? picture,
  }) : picture = picture ?? File('capture.jpg');

  final List<String> lines;

  /// 셔터를 누르면 돌려줄 촬영본. 실제 파일을 넣으면 삭제 여부를 확인할 수 있다.
  final File picture;

  @override
  bool get isRecognitionSupported => true;

  @override
  Future<void> startCamera() async {}

  @override
  Future<void> stopCamera() async {}

  @override
  Widget buildCameraPreview() => const ColoredBox(color: Colors.black);

  @override
  Future<File> takePicture() async => picture;

  @override
  Future<List<File>> pickFromAlbum() async => const [];

  @override
  Future<List<String>> recognizeLines(File image) async => lines;
}

/// 카메라 권한 상태를 고정해 둔 [PermissionService].
class FakePermissionService implements PermissionService {
  FakePermissionService(this.camera);

  final AppPermissionStatus camera;

  @override
  Future<AppPermissionStatus> cameraStatus() async => camera;

  @override
  Future<AppPermissionStatus> requestCamera() async => camera;

  @override
  Future<AppPermissionStatus> notificationStatus() async =>
      AppPermissionStatus.granted;

  @override
  Future<AppPermissionStatus> requestNotification() async =>
      AppPermissionStatus.granted;

  @override
  Future<void> openAppSettings() async {}
}
