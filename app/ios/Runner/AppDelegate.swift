import Flutter
import UIKit
import Vision

/// 앱의 iOS 진입점. Flutter 엔진이 준비되면 플러그인과 글자 인식 채널을 등록한다.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// 앱을 시작한다. 처리는 Flutter 기본 동작을 그대로 따른다.
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// 엔진이 만들어지면 패키지 플러그인과 [TextRecognitionPlugin]을 등록한다.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TextRecognitionPlugin") {
      TextRecognitionPlugin.register(with: registrar)
    }
  }
}

/// `doit/text_recognition` 채널의 iOS 쪽. Apple Vision으로 사진 속 글자를 줄 단위로 읽는다.
///
/// Vision은 OS에 들어 있는 모델로 단말 안에서만 처리한다(네트워크 사용 없음).
/// 한국어 인식은 iOS 16부터 지원하므로 Dart 쪽에서 그 이상일 때만 부른다.
final class TextRecognitionPlugin: NSObject, FlutterPlugin {
  /// `doit/text_recognition` 채널을 만들고 이 플러그인을 호출 대상으로 등록한다.
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "doit/text_recognition",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(TextRecognitionPlugin(), channel: channel)
  }

  /// Dart에서 온 호출을 이름에 따라 미리 읽기나 줄 인식으로 나눈다.
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "warmUp":
      warmUp(result: result)
    case "recognizeLines":
      recognizeLines(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// 빈 그림을 한 번 인식시켜 Vision 모델을 미리 읽어 둔다.
  private func warmUp(result: @escaping FlutterResult) {
    guard #available(iOS 16.0, *) else {
      result(nil)
      return
    }
    DispatchQueue.global(qos: .utility).async {
      let renderer = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32))
      let blank = renderer.image { context in
        UIColor.white.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
      }
      if let cgImage = blank.cgImage {
        let request = Self.makeRequest()
        try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
      }
      DispatchQueue.main.async { result(nil) }
    }
  }

  /// `path`의 사진을 백그라운드에서 인식하고, 결과나 오류를 메인 스레드에서 Dart에 돌려준다.
  private func recognizeLines(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let path = arguments["path"] as? String
    else {
      result(FlutterError(code: "invalidArgs", message: "path가 없습니다.", details: nil))
      return
    }
    guard #available(iOS 16.0, *) else {
      result(FlutterError(code: "unsupported", message: "iOS 16 이상이 필요합니다.", details: nil))
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      let outcome = Self.recognizeLines(atPath: path)
      DispatchQueue.main.async {
        switch outcome {
        case .success(let lines):
          result(lines)
        case .failure(let error):
          result(FlutterError(code: error.code, message: error.message, details: nil))
        }
      }
    }
  }

  /// 인식 실패를 Dart에 넘길 오류 코드와 메시지.
  private struct RecognitionError: Error {
    let code: String
    let message: String
  }

  /// 한국어·영어를 정확도 우선으로 읽는 Vision 요청을 만든다. 미리 읽기와 인식이 같은 설정을 쓴다.
  @available(iOS 16.0, *)
  private static func makeRequest() -> VNRecognizeTextRequest {
    let request = VNRecognizeTextRequest()
    request.revision = VNRecognizeTextRequestRevision3
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["ko-KR", "en-US"]
    request.usesLanguageCorrection = true
    return request
  }

  /// 사진을 열어 Vision으로 인식하고, 읽은 줄을 위에서 아래 순서로 돌려준다.
  @available(iOS 16.0, *)
  private static func recognizeLines(atPath path: String) -> Result<[String], RecognitionError> {
    guard let image = UIImage(contentsOfFile: path), let cgImage = image.cgImage else {
      return .failure(RecognitionError(code: "imageLoadFailed", message: "사진을 열 수 없습니다."))
    }

    let request = makeRequest()
    let handler = VNImageRequestHandler(
      cgImage: cgImage,
      orientation: CGImagePropertyOrientation(image.imageOrientation),
      options: [:]
    )
    do {
      try handler.perform([request])
    } catch {
      return .failure(RecognitionError(code: "recognitionFailed", message: error.localizedDescription))
    }

    // Vision 좌표는 왼쪽 아래가 원점이다. 위에서 아래, 같은 줄이면 왼쪽부터 읽는다.
    let observations = (request.results ?? []).sorted { first, second in
      let firstBox = first.boundingBox
      let secondBox = second.boundingBox
      if abs(firstBox.midY - secondBox.midY) > min(firstBox.height, secondBox.height) / 2 {
        return firstBox.midY > secondBox.midY
      }
      return firstBox.minX < secondBox.minX
    }
    let lines = observations.compactMap { $0.topCandidates(1).first?.string }
    return .success(lines)
  }
}

/// UIImage의 방향 값을 Vision이 쓰는 방향 값으로 바꾼다.
private extension CGImagePropertyOrientation {
  /// 사진의 회전 정보를 같은 뜻의 Vision 방향으로 옮긴다.
  init(_ orientation: UIImage.Orientation) {
    switch orientation {
    case .up: self = .up
    case .upMirrored: self = .upMirrored
    case .down: self = .down
    case .downMirrored: self = .downMirrored
    case .left: self = .left
    case .leftMirrored: self = .leftMirrored
    case .right: self = .right
    case .rightMirrored: self = .rightMirrored
    @unknown default: self = .up
    }
  }
}
