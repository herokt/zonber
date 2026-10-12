import 'dart:convert';
import 'dart:ui' show Offset;

// ─────────────────────────────────────────────────────────────
// 광고 영상 모드 — `--dart-define=STORE_SHOT=true --dart-define=AD_VIDEO=true` 웹 빌드에서만 켜진다(2026-10-12).
// 스토어 스크린샷 모드(store_shot.dart)의 가짜 랭킹·로그인 없음을 그대로 쓰고, 판 화면만 자동 플레이(game/autopilot.dart)로 돌린다.
// 장면(존)마다 로그에 `ADVIDEO scene <이름>` 을 찍고 엔진을 멈춘 채 기다린다 — 호스트(scripts/ad_video_capture.mjs)가
// `adVideoStep(n)` 으로 n 스텝(1/60초씩) 넘기고 캡처하기를 되풀이한 뒤 `adVideoNext()` 로 다음 장면으로 넘긴다.
// 합성 scripts/make_ad_video.py(Google Ads 동영상 9:16 · 16:9 · 1:1).
//   · 캐릭터는 실제 판처럼 맞으면 맞는다. 판은 끝나지 않는다(debugNoGameOver)
//   · 효과음은 틀지 않고 프레임마다 모아 넘긴다 — 합성할 때 같은 프레임에 섞는다
// ─────────────────────────────────────────────────────────────
const bool kAdVideo = bool.fromEnvironment('AD_VIDEO');

class AdVideo {
  /// 찍을 언어 — 페이지 주소의 `?lang=en` (기본 ko). 언어마다 다시 빌드하지 않게
  static String get lang => Uri.base.queryParameters['lang'] ?? 'ko';

  /// 장면 — (이름, 존 id, 시작 생존 시간). 공이 많은 단계에서 시작한다
  static const List<(String, String, double)> scenes = [
    ('galaxy', 'cyber', 112),
    ('dodgeball', 'dodgeball', 84),
    ('keeper', 'keeper', 76),
  ];

  static final List<(String, double)> _sfx = [];

  /// 효과음 기록(AudioManager.playSfx 가 소리 대신 부른다)
  static void logSfx(String name, double volume) => _sfx.add((name, volume));

  /// 이번 프레임 정보 — 생존 시간 · 캐릭터 화면 좌표(논리 px) · 그동안 난 효과음. 효과음 목록은 비운다
  static String frameInfo(double t, Offset? player) {
    final s = jsonEncode({
      't': t,
      'x': player?.dx,
      'y': player?.dy,
      'sfx': [for (final (n, v) in _sfx) [n, v]],
    });
    _sfx.clear();
    return s;
  }
}
