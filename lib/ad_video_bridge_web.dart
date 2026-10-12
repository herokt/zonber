import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// 광고 영상 모드(ad_video.dart)의 호스트 연결(웹) — 호스트가 페이지에서 부르는 함수 둘을 건다
//   adVideoStep(n) → n 스텝 진행하고 그린 뒤 이 프레임 정보(JSON 문자열)를 돌려준다
//   adVideoNext()  → 이 장면을 끝낸다
class AdVideoBridge {
  static Future<void> serve(Future<String> Function(int steps) step) {
    final done = Completer<void>();
    globalContext['adVideoStep'] = ((JSNumber n) => step(n.toDartInt).then((s) => s.toJS).toJS).toJS;
    globalContext['adVideoNext'] = (() {
      if (!done.isCompleted) done.complete();
    }).toJS;
    return done.future;
  }
}
