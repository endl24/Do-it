import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

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
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "doit/text_recognition",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(TextRecognitionPlugin(), channel: channel)
  }

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

  private struct RecognitionError: Error {
    let code: String
    let message: String
  }

  @available(iOS 16.0, *)
  private static func makeRequest() -> VNRecognizeTextRequest {
    let request = VNRecognizeTextRequest()
    request.revision = VNRecognizeTextRequestRevision3
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["ko-KR", "en-US"]
    request.usesLanguageCorrection = true
    return request
  }

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

private extension CGImagePropertyOrientation {
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
