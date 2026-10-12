// 광고 영상 모드(ad_video.dart)의 호스트 연결 — 웹 빌드는 ad_video_bridge_web.dart 를 쓴다. 모바일에서는 아무것도 하지 않는다
class AdVideoBridge {
  static Future<void> serve(Future<String> Function(int steps) step) async {}
}
