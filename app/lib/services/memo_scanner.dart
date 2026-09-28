import 'dart:io';

import 'package:flutter/widgets.dart';

/// 06 메모 촬영에 필요한 카메라, 앨범, 단말 내 글자 인식(A14 A15 · C3).
// TODO(강두이): 카메라·앨범·글자 인식 패키지를 팀과 정하면 구현체를 만든다.
abstract interface class MemoScanner {
  /// 이 단말에서 글자 인식을 쓸 수 있는지. 64비트 단말에서만 동작한다(C2-2).
  bool get isRecognitionSupported;

  Future<void> startCamera();
  Future<void> stopCamera();

  /// [startCamera]가 끝난 뒤 촬영 화면 미리보기로 보여줄 위젯.
  Widget buildCameraPreview();

  Future<File> takePicture();

  /// 앨범에서 고른 사진. 선택을 취소하면 빈 목록이다.
  Future<List<File>> pickFromAlbum();

  /// 사진 속 글자를 줄 단위로 돌려준다. 읽은 글자가 없으면 빈 목록이다.
  Future<List<String>> recognizeLines(File image);
}
