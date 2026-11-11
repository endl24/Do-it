import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/services.dart';

/// 사진 속 글자를 단말 안에서 줄 단위로 읽는다(A15 · C3).
abstract interface class TextRecognizer {
  /// 이 단말에서 글자 인식을 쓸 수 있는지.
  bool get isSupported;

  /// 인식 모델을 미리 읽어 첫 인식을 빠르게 한다. 실패해도 인식은 그대로 할 수 있다.
  Future<void> warmUp();

  /// [image]의 글자를 위에서 아래 순서의 줄로 돌려준다. 읽은 글자가 없으면 빈 목록이다.
  Future<List<String>> recognizeLines(File image);
}

/// 네이티브 인식기를 플랫폼 채널로 부른다.
///
/// Android는 ML Kit 한국어 모델(앱에 포함), iOS는 OS에 들어 있는 Apple Vision을 쓴다.
/// 두 쪽 모두 네트워크를 쓰지 않아 비행기 모드에서도 동작한다.
class PlatformTextRecognizer implements TextRecognizer {
  const PlatformTextRecognizer();

  static const _channel = MethodChannel('doit/text_recognition');

  /// Vision의 한국어 인식은 iOS 16부터 지원한다.
  static const _minimumIosVersion = 16;

  @override
  bool get isSupported {
    if (Platform.isAndroid) {
      // ML Kit는 32비트 단말을 지원하지 않는다(C2-2).
      final abi = Abi.current();
      return abi == Abi.androidArm64 || abi == Abi.androidX64;
    }
    if (Platform.isIOS) {
      return iosMajorVersion(Platform.operatingSystemVersion) >=
          _minimumIosVersion;
    }
    return false;
  }

  @override
  Future<void> warmUp() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('warmUp');
  }

  @override
  Future<List<String>> recognizeLines(File image) async {
    final lines = await _channel.invokeListMethod<String>('recognizeLines', {
      'path': image.path,
    });
    return lines ?? const [];
  }

  /// `Version 26.5 (Build 23F77)` 같은 문자열에서 앞 숫자를 읽는다. 못 읽으면 0이다.
  static int iosMajorVersion(String operatingSystemVersion) {
    final match = RegExp(r'(\d+)').firstMatch(operatingSystemVersion);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }
}
