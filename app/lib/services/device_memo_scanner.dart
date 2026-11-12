import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'memo_scanner.dart';
import 'text_recognizer.dart';

/// 기기 카메라·시스템 사진 선택기·단말 내 글자 인식으로 만든 [MemoScanner].
///
/// 촬영본과 앨범 사본은 받자마자 앱 임시 폴더(`memo_capture/`) 한 곳으로 옮긴다.
/// 화면(06·07·08)이 흐름이 끝날 때 지우고, 강제 종료 등으로 남은 파일은
/// 다음에 카메라를 켤 때 [clearLeftovers]가 지운다(A19 · 통과 기준 3).
class DeviceMemoScanner implements MemoScanner {
  DeviceMemoScanner({
    TextRecognizer? recognizer,
    Future<Directory> Function()? captureDirectory,
    Future<List<XFile>> Function()? pickImages,
  }) : _recognizer = recognizer ?? const PlatformTextRecognizer(),
       _captureDirectory = captureDirectory ?? _defaultCaptureDirectory,
       _pickImages = pickImages ?? _pickFromSystemPicker;

  final TextRecognizer _recognizer;
  final Future<Directory> Function() _captureDirectory;
  final Future<List<XFile>> Function() _pickImages;

  CameraController? _camera;

  /// 마지막 인식에 걸린 시간. README 처리 시간 측정값(#84)에 쓴다.
  Duration? lastRecognitionDuration;

  /// 앱 임시 폴더 안의 `memo_capture/` 위치를 돌려준다. 폴더는 쓸 때 만든다.
  static Future<Directory> _defaultCaptureDirectory() async {
    final temp = await getTemporaryDirectory();
    return Directory('${temp.path}/memo_capture');
  }

  /// 시스템 사진 선택기를 열어 사용자가 고른 사진을 받는다.
  static Future<List<XFile>> _pickFromSystemPicker() {
    // 시스템 사진 선택기는 고른 사진만 앱에 넘기므로 사진 접근 권한이 필요 없다.
    // 크기·화질 옵션을 주면 Android에서 원본 사본과 줄인 사본 두 개가 캐시에 생기고
    // 줄인 것만 돌려받아 원본 사본이 남는다. 그래서 옵션 없이 사본 하나만 받는다.
    return ImagePicker().pickMultiImage();
  }

  /// 이 기기에서 글자 인식을 쓸 수 있는지 인식기에 묻는다.
  @override
  bool get isRecognitionSupported => _recognizer.isSupported;

  /// 뒤쪽 카메라를 켠다.
  ///
  /// 켜기 전에 인식 모델을 미리 읽기 시작하고, 지난 흐름에서 남은 촬영본을 지운다.
  /// 카메라가 없으면 [CameraException]을 던진다.
  @override
  Future<void> startCamera() async {
    // 첫 인식 때 모델을 읽느라 오래 걸리므로(B2) 카메라를 켜는 동안 미리 읽어 둔다.
    _recognizer.warmUp().catchError(
      (Object error) => debugPrint('[OCR] 미리 준비 실패: $error'),
    );
    await clearLeftovers();
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException('noCamera', '사용할 수 있는 카메라가 없습니다.');
    }
    final back = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final camera = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _camera = camera;
    await camera.initialize();
  }

  /// 카메라를 끄고 자원을 놓는다. 켜져 있지 않으면 아무 일도 하지 않는다.
  @override
  Future<void> stopCamera() async {
    final camera = _camera;
    _camera = null;
    await camera?.dispose();
  }

  /// 카메라 미리보기를 뷰파인더 크기에 맞춰 그린다. 준비 전이면 빈 칸을 돌려준다.
  @override
  Widget buildCameraPreview() {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) {
      return const SizedBox.shrink();
    }
    // 미리보기 비율을 유지한 채 뷰파인더를 꽉 채운다. 넘치는 부분은 뷰파인더가 잘라낸다.
    final size = camera.value.previewSize;
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        // previewSize는 가로 기준이라 세로 화면에서는 너비·높이를 바꿔 쓴다.
        width: size?.height ?? 1,
        height: size?.width ?? 1,
        child: CameraPreview(camera),
      ),
    );
  }

  /// 사진을 찍어 앱 임시 폴더로 옮긴 파일을 돌려준다.
  @override
  Future<File> takePicture() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) {
      throw CameraException('notReady', '카메라가 준비되지 않았습니다.');
    }
    final picture = await camera.takePicture();
    return moveToCaptureDirectory(File(picture.path));
  }

  /// 앨범에서 고른 사진을 앱 임시 폴더로 옮겨 돌려준다. 취소하면 빈 목록이다.
  @override
  Future<List<File>> pickFromAlbum() async {
    final picked = await _pickImages();
    return [
      for (final image in picked)
        await moveToCaptureDirectory(File(image.path)),
    ];
  }

  /// [image]의 글자를 줄 단위로 읽고, 걸린 시간을 기록해 로그로 남긴다(#84 측정).
  @override
  Future<List<String>> recognizeLines(File image) async {
    final stopwatch = Stopwatch()..start();
    final lines = await _recognizer.recognizeLines(image);
    stopwatch.stop();
    lastRecognitionDuration = stopwatch.elapsed;
    debugPrint(
      '[OCR] 인식 ${stopwatch.elapsedMilliseconds}ms, 줄 ${lines.length}개, '
      '${await image.length()}바이트',
    );
    return lines;
  }

  /// [file]을 앱 임시 폴더로 옮긴다. 플러그인이 만든 원래 위치에는 남기지 않는다.
  Future<File> moveToCaptureDirectory(File file) async {
    final directory = await _captureDirectory();
    await directory.create(recursive: true);
    final name = file.uri.pathSegments.last;
    final target =
        '${directory.path}/'
        '${DateTime.now().microsecondsSinceEpoch}_$name';
    try {
      return await file.rename(target);
    } on FileSystemException {
      // 다른 저장 공간이라 옮길 수 없으면 복사한 뒤 원본을 지운다.
      final copy = await file.copy(target);
      await file.delete();
      return copy;
    }
  }

  /// 앱 임시 폴더에 남은 촬영본을 모두 지운다.
  Future<void> clearLeftovers() async {
    final directory = await _captureDirectory();
    if (!await directory.exists()) return;
    await for (final entity in directory.list()) {
      await entity.delete(recursive: true);
    }
  }
}
