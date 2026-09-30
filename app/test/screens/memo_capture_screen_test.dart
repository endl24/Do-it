import 'dart:async';
import 'dart:io';

import 'package:do_it/core/theme/app_theme.dart';
import 'package:do_it/screens/photo_import/candidate_review_screen.dart';
import 'package:do_it/screens/photo_import/memo_capture_screen.dart';
import 'package:do_it/screens/photo_import/permission_guide_screen.dart';
import 'package:do_it/screens/photo_import/recognition_failure_screen.dart';
import 'package:do_it/screens/photo_import/todo_candidate.dart';
import 'package:do_it/services/memo_scanner.dart';
import 'package:do_it/services/permission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeScanner implements MemoScanner {
  _FakeScanner({
    this.isRecognitionSupported = true,
    this.lines = const ['이번 주 할 일', '- 졸업 서류 제출', '- 도서관 책 반납'],
    this.albumImages = const [],
  });

  @override
  final bool isRecognitionSupported;

  List<String> lines;
  List<File> albumImages;

  /// 채워 두면 인식이 이 Completer가 끝날 때까지 기다린다.
  Completer<void>? recognitionGate;

  var isCameraRunning = false;

  @override
  Future<void> startCamera() async => isCameraRunning = true;

  @override
  Future<void> stopCamera() async => isCameraRunning = false;

  @override
  Widget buildCameraPreview() => const ColoredBox(color: Colors.black);

  @override
  Future<File> takePicture() async => File('capture.jpg');

  @override
  Future<List<File>> pickFromAlbum() async => albumImages;

  @override
  Future<List<String>> recognizeLines(File image) async {
    await recognitionGate?.future;
    return lines;
  }
}

class _FakePermissionService implements PermissionService {
  _FakePermissionService(this.camera);

  AppPermissionStatus camera;

  @override
  Future<AppPermissionStatus> cameraStatus() async => camera;

  @override
  Future<AppPermissionStatus> requestCamera() async =>
      camera = AppPermissionStatus.granted;

  @override
  Future<AppPermissionStatus> notificationStatus() async =>
      AppPermissionStatus.granted;

  @override
  Future<AppPermissionStatus> requestNotification() async =>
      AppPermissionStatus.granted;

  @override
  Future<void> openAppSettings() async {}
}

/// 첫 화면(01)에서 [MemoCaptureScreen.open]으로 연다.
Future<void> _pumpCapture(
  WidgetTester tester,
  _FakeScanner scanner, {
  AppPermissionStatus camera = AppPermissionStatus.granted,
  VoidCallback? onManualEntry,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => MemoCaptureScreen.open(
                context,
                permissionService: _FakePermissionService(camera),
                scanner: scanner,
                onManualEntry: onManualEntry ?? () {},
                onRegister: (_) async {},
              ),
              child: const Text('목록'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('목록'));
  await tester.pumpAndSettle();
}

Future<void> _shoot(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('촬영'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('촬영 안내, 앨범·촬영·직접 입력 버튼을 보여준다', (tester) async {
    final scanner = _FakeScanner();
    await _pumpCapture(tester, scanner);

    expect(find.text('메모 촬영'), findsOneWidget);
    expect(
      find.text('한 번에 한 장만 인식합니다. 글자가 안내선 안에 들어오게 맞춰 주세요.'),
      findsOneWidget,
    );
    expect(find.text('앨범'), findsOneWidget);
    expect(find.text('직접 입력'), findsOneWidget);
    expect(scanner.isCameraRunning, isTrue);
  });

  testWidgets('인식하는 동안 단말에서 처리한다고 안내하고 결과를 07로 넘긴다', (tester) async {
    final scanner = _FakeScanner()..recognitionGate = Completer<void>();
    await _pumpCapture(tester, scanner);

    await tester.tap(find.bySemanticsLabel('촬영'));
    await tester.pump();

    expect(find.text('텍스트 인식 중...'), findsOneWidget);
    expect(find.text('단말에서 처리하며 이미지는 외부로 전송되지 않습니다'), findsOneWidget);

    scanner.recognitionGate!.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CandidateReviewScreen), findsOneWidget);
    expect(find.text('졸업 서류 제출'), findsOneWidget);
  });

  testWidgets('글자를 못 읽으면 08로 넘기고 연속 실패 횟수를 센다', (tester) async {
    final scanner = _FakeScanner(lines: const []);
    await _pumpCapture(tester, scanner);

    for (var i = 1; i <= 3; i++) {
      await _shoot(tester);
      expect(find.byType(RecognitionFailureScreen), findsOneWidget);
      expect(
        find.text('직접 입력이 더 빠를 수 있어요'),
        i < 3 ? findsNothing : findsOneWidget,
      );
      await tester.tap(find.text('다시 촬영'));
      await tester.pumpAndSettle();
    }

    expect(find.byType(MemoCaptureScreen), findsOneWidget);
  });

  testWidgets('앨범에서 두 장 이상 고르면 한 장만 고르라고 안내한다', (tester) async {
    final scanner = _FakeScanner(albumImages: [File('a.jpg'), File('b.jpg')]);
    await _pumpCapture(tester, scanner);

    await tester.tap(find.text('앨범'));
    await tester.pumpAndSettle();

    expect(find.text('한 번에 한 장만 인식할 수 있습니다. 사진을 하나만 선택해 주세요.'), findsOneWidget);
    expect(find.byType(CandidateReviewScreen), findsNothing);
  });

  testWidgets('앨범 선택을 취소하면 촬영 화면에 남는다', (tester) async {
    await _pumpCapture(tester, _FakeScanner());

    await tester.tap(find.text('앨범'));
    await tester.pumpAndSettle();

    expect(find.byType(MemoCaptureScreen), findsOneWidget);
    expect(find.byType(CandidateReviewScreen), findsNothing);
  });

  testWidgets('앨범에서 한 장을 고르면 촬영과 같은 흐름으로 인식한다', (tester) async {
    await _pumpCapture(tester, _FakeScanner(albumImages: [File('a.jpg')]));

    await tester.tap(find.text('앨범'));
    await tester.pumpAndSettle();

    expect(find.byType(CandidateReviewScreen), findsOneWidget);
  });

  testWidgets('인식을 지원하지 않는 단말이면 직접 입력을 권한다', (tester) async {
    var isManualEntry = false;
    final scanner = _FakeScanner(isRecognitionSupported: false);
    await _pumpCapture(
      tester,
      scanner,
      onManualEntry: () => isManualEntry = true,
    );

    expect(
      find.text('이 기기에서는 사진 인식을 사용할 수 없습니다. 직접 입력으로 할 일을 등록해 주세요.'),
      findsOneWidget,
    );
    expect(scanner.isCameraRunning, isFalse);

    await tester.tap(find.widgetWithText(FilledButton, '직접 입력'));
    await tester.pumpAndSettle();

    expect(isManualEntry, isTrue);
  });

  testWidgets('닫으면 카메라를 끄고 첫 화면으로 돌아간다', (tester) async {
    final scanner = _FakeScanner();
    await _pumpCapture(tester, scanner);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    expect(find.byType(MemoCaptureScreen), findsNothing);
    expect(scanner.isCameraRunning, isFalse);
  });

  testWidgets('카메라 권한이 없으면 09를 거쳐 허용 후 06으로 바뀐다', (tester) async {
    await _pumpCapture(
      tester,
      _FakeScanner(),
      camera: AppPermissionStatus.notDetermined,
    );

    expect(find.byType(PermissionGuideScreen), findsOneWidget);

    await tester.tap(find.text('권한 허용하기'));
    await tester.pumpAndSettle();

    expect(find.byType(PermissionGuideScreen), findsNothing);
    expect(find.byType(MemoCaptureScreen), findsOneWidget);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    expect(find.text('목록'), findsOneWidget);
  });

  group('candidatesFromLines', () {
    test('글머리표를 떼고 빈 줄을 뺀다', () {
      final candidates = candidatesFromLines([
        '이번 주 할 일',
        '',
        '- 졸업 서류 제출',
        '• 스터디 자료 정리',
        '2) 도서관 책 반납',
        '-',
      ]);

      expect(
        [for (final candidate in candidates) candidate.text],
        ['이번 주 할 일', '졸업 서류 제출', '스터디 자료 정리', '도서관 책 반납'],
      );
      expect(candidates.first.isLikelyTitle, isTrue);
      expect(candidates[1].isLikelyTitle, isFalse);
    });

    test('글머리표가 하나도 없으면 첫 줄도 할 일로 본다', () {
      final candidates = candidatesFromLines(['우유 사기', '빨래 하기']);

      expect(candidates.first.isLikelyTitle, isFalse);
    });
  });
}
