import 'dart:async';
import 'dart:io';

/// Firestore 호스트의 HTTPS 응답을 확인해 실제 인터넷 연결 변화를 알린다.
/// Wi-Fi 연결 여부만으로는 인터넷 사용 가능 여부를 알 수 없으므로 직접 확인한다.
class InternetStatus {
  /// 확인 방법 [probe]와 검사 간격 [interval]로 만든다. [probe]가 없으면 Firestore 호스트에 직접 접속해 본다.
  InternetStatus({
    Future<bool> Function()? probe,
    this.interval = const Duration(seconds: 3),
  }) : _probe = probe ?? _canReachServer;

  final Future<bool> Function() _probe;
  final Duration interval;

  /// 확인이 끝난 뒤 3초마다 다시 검사하며 구독 취소 시 반복을 멈춘다.
  Stream<bool> watch() {
    Timer? timer;
    var isCancelled = false;
    bool? previous;
    late StreamController<bool> controller;

    /// 서버에 닿는지 한 번 확인해 결과가 바뀌었을 때만 알리고, [interval] 뒤 다음 확인을 예약한다.
    Future<void> check() async {
      bool isOnline;
      try {
        isOnline = await _probe();
      } catch (_) {
        isOnline = false;
      }
      if (isCancelled) return;
      if (isOnline != previous) {
        previous = isOnline;
        controller.add(isOnline);
      }
      timer = Timer(interval, check);
    }

    controller = StreamController<bool>(
      onListen: check,
      onCancel: () {
        isCancelled = true;
        timer?.cancel();
      },
    );
    return controller.stream;
  }

  /// 인증 정보 없이 호스트 도달 여부만 확인하고 연결은 즉시 정리한다.
  static Future<bool> _canReachServer() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final response = await (() async {
        final request = await client.getUrl(
          Uri.https('firestore.googleapis.com', '/'),
        );
        return request.close();
      })().timeout(const Duration(seconds: 3));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
