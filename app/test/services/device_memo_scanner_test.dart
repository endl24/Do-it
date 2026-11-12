import 'dart:io';

import 'package:do_it/services/device_memo_scanner.dart';
import 'package:do_it/services/text_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

/// 네이티브 인식 대신 정해 둔 줄이나 오류를 돌려주고, 받은 사진을 기록하는 인식기.
class _FakeRecognizer implements TextRecognizer {
  _FakeRecognizer({this.lines = const [], this.error});

  final List<String> lines;
  final Object? error;
  File? lastImage;

  @override
  bool isSupported = true;

  /// 미리 읽을 모델이 없어 바로 끝낸다.
  @override
  Future<void> warmUp() async {}

  /// 받은 사진을 [lastImage]에 남기고, [error]가 있으면 던지고 없으면 [lines]를 돌려준다.
  @override
  Future<List<String>> recognizeLines(File image) async {
    lastImage = image;
    if (error != null) throw error!;
    return lines;
  }
}

/// [DeviceMemoScanner]가 사진을 임시 폴더로 옮기고 지우는지, 인식 결과를 그대로 넘기는지 검사한다.
void main() {
  late Directory root;
  late Directory pluginTemp;
  late Directory captureDirectory;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('device_memo_scanner_test');
    pluginTemp = await Directory('${root.path}/plugin').create();
    captureDirectory = Directory('${root.path}/memo_capture');
  });

  tearDown(() => root.delete(recursive: true));

  /// 테스트용 임시 폴더와 가짜 인식기·선택기를 연결한 스캐너를 만든다.
  DeviceMemoScanner scanner({
    TextRecognizer? recognizer,
    List<XFile> picked = const [],
  }) {
    return DeviceMemoScanner(
      recognizer: recognizer ?? _FakeRecognizer(),
      captureDirectory: () async => captureDirectory,
      pickImages: () async => picked,
    );
  }

  /// 플러그인이 만든 것처럼 원래 위치에 작은 사진 파일을 만든다.
  Future<File> pluginFile(String name) =>
      File('${pluginTemp.path}/$name').writeAsBytes([1, 2, 3]);

  test('앨범 사진을 앱 임시 폴더로 옮기고 원래 위치에는 남기지 않는다', () async {
    final original = await pluginFile('image_picker_1.jpg');

    final images = await scanner(picked: [XFile(original.path)])
        .pickFromAlbum();

    expect(images, hasLength(1));
    expect(images.single.parent.path, captureDirectory.path);
    expect(await images.single.readAsBytes(), [1, 2, 3]);
    expect(await original.exists(), isFalse);
  });

  test('여러 장을 고르면 모두 임시 폴더로 옮겨 화면이 지울 수 있게 한다', () async {
    final first = await pluginFile('a.jpg');
    final second = await pluginFile('b.jpg');

    final images = await scanner(
      picked: [XFile(first.path), XFile(second.path)],
    ).pickFromAlbum();

    expect(images, hasLength(2));
    expect(images.map((image) => image.path).toSet(), hasLength(2));
    expect(pluginTemp.listSync(), isEmpty);
  });

  test('앨범 선택을 취소하면 빈 목록이다', () async {
    expect(await scanner().pickFromAlbum(), isEmpty);
  });

  test('남은 촬영본을 모두 지운다', () async {
    await captureDirectory.create();
    await File('${captureDirectory.path}/left.jpg').writeAsBytes([1]);
    await File('${captureDirectory.path}/other.jpg').writeAsBytes([1]);

    await scanner().clearLeftovers();

    expect(captureDirectory.listSync(), isEmpty);
  });

  test('임시 폴더가 없어도 정리할 때 오류가 나지 않는다', () async {
    await scanner().clearLeftovers();

    expect(await captureDirectory.exists(), isFalse);
  });

  test('인식기가 읽은 줄을 그대로 돌려주고 걸린 시간을 기록한다', () async {
    final recognizer = _FakeRecognizer(lines: ['- 졸업 서류 제출', '- 도서관 책 반납']);
    final memoScanner = scanner(recognizer: recognizer);
    final image = await pluginFile('memo.jpg');

    final lines = await memoScanner.recognizeLines(image);

    expect(lines, ['- 졸업 서류 제출', '- 도서관 책 반납']);
    expect(recognizer.lastImage, image);
    expect(memoScanner.lastRecognitionDuration, isNotNull);
  });

  test('인식기 오류는 화면이 08로 보낼 수 있게 그대로 올린다', () async {
    final memoScanner = scanner(
      recognizer: _FakeRecognizer(error: Exception('recognitionFailed')),
    );
    final image = await pluginFile('memo.jpg');

    expect(memoScanner.recognizeLines(image), throwsException);
  });

  test('지원 여부는 인식기를 따른다', () {
    final recognizer = _FakeRecognizer()..isSupported = false;

    expect(scanner(recognizer: recognizer).isRecognitionSupported, isFalse);
  });

  test('iOS 버전 문자열에서 주 버전을 읽는다', () {
    expect(
      PlatformTextRecognizer.iosMajorVersion('Version 26.5 (Build 23F77)'),
      26,
    );
    expect(PlatformTextRecognizer.iosMajorVersion('15.8'), 15);
    expect(PlatformTextRecognizer.iosMajorVersion('unknown'), 0);
  });
}
