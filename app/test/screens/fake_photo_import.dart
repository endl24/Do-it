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

  /// 항상 인식을 지원하는 기기로 본다.
  @override
  bool get isRecognitionSupported => true;

  /// 카메라를 켜지 않고 바로 끝낸다.
  @override
  Future<void> startCamera() async {}

  /// 끌 카메라가 없어 바로 끝낸다.
  @override
  Future<void> stopCamera() async {}

  /// 미리보기 대신 검은 칸을 그린다.
  @override
  Widget buildCameraPreview() => const ColoredBox(color: Colors.black);

  /// 정해 둔 [picture]를 촬영본으로 돌려준다.
  @override
  Future<File> takePicture() async => picture;

  /// 앨범 선택을 취소한 것처럼 빈 목록을 돌려준다.
  @override
  Future<List<File>> pickFromAlbum() async => const [];

  /// 사진과 관계없이 정해 둔 [lines]를 인식 결과로 돌려준다.
  @override
  Future<List<String>> recognizeLines(File image) async => lines;
}

/// 카메라 권한 상태를 고정해 둔 [PermissionService].
class FakePermissionService implements PermissionService {
  FakePermissionService(this.camera);

  final AppPermissionStatus camera;

  /// 고정해 둔 카메라 권한 상태를 돌려준다.
  @override
  Future<AppPermissionStatus> cameraStatus() async => camera;

  /// 요청해도 고정해 둔 카메라 권한 상태를 그대로 돌려준다.
  @override
  Future<AppPermissionStatus> requestCamera() async => camera;

  /// 알림 권한은 항상 허용으로 본다.
  @override
  Future<AppPermissionStatus> notificationStatus() async =>
      AppPermissionStatus.granted;

  /// 알림 권한 요청은 항상 허용으로 끝난다.
  @override
  Future<AppPermissionStatus> requestNotification() async =>
      AppPermissionStatus.granted;

  /// 설정 화면을 열지 않고 바로 끝낸다.
  @override
  Future<void> openAppSettings() async {}
}
