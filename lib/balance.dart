import 'dart:math';

// ─────────────────────────────────────────────────────────────
// 밸런스 수치 모음 — 조정할 때 여기부터 본다. 플레이 로그(PlaytestLog)로 확인하고 바꾼다.
// ⚠️ 스테이지 난이도(속도·간격)를 크게 바꾸면 시즌을 올린다(season.dart · docs/RELEASE.md).
// 장비 능력치는 gear.dart, 상점 가격은 gear.dart · cosmetics.dart · character_data.dart, 일일 보상은 daily_rewards.dart.
// ─────────────────────────────────────────────────────────────
class Balance {
  // ── 코인 ──
  /// 이만큼 버틸 때마다 코인 1개
  static const double secondsPerCoin = 5;

  // ── 스테이지별 추가 기록(난이도를 비슷하게) ──
  /// 갤럭시 근접 회피 — 히트박스 바깥 이 거리(px) 안을 스치면 1
  static const double grazeRing = 4.0;
  /// 피구 아슬 회피
  static const double closeDodgeRing = 5.0;
  /// 골키퍼 연속 선방 — 직전 세이브 후 이 시간(초) 안에 또 막으면 1
  static const double saveStreakWindow = 1.0;
  /// 추가 기록 1번에 주는 보너스 코인
  static const int bonusCoinsPerStat = 1;

  // ── 피구 ──
  /// 외야 패스 횟수 범위(무작위)
  static const int passHopsMin = 1, passHopsMax = 5;
  /// 턴 간격: 2.0s 에서 1초에 1%씩, 하한 0.4s
  static double dodgeBeatAt(double t) => max(0.4, 2.0 * pow(0.99, t).toDouble());
  /// 공 속도: 150 → 초당 +2.2, 상한 460 (투구는 여기에 [dodgeThrowScale] 을 곱한다. 외야 패스 속공은 곱하지 않는다)
  static double dodgeSpeedAt(double t) => min(460.0, 150.0 + 2.2 * t);
  /// 2026-09-24 코트를 무대 가운데 크게(세로 460 → 624) 키우면서 내야 → 우리 진영 평균 거리가 248 → 330(×1.33)이 됐다.
  /// 공이 오는 데 걸리는 시간(반응 시간)이 예전과 같도록 투구 속도에 같은 배율을 곱한다.
  /// 외야 패스는 좌우·뒤 외야에서 던지므로 거리가 거의 그대로라 곱하지 않는다.
  static const double dodgeThrowScale = 1.33;

  // ── 골키퍼 ──
  /// 턴 간격: 2.0s 에서 1초에 1%씩, 하한 0.55s
  static double keeperBeatAt(double t) => max(0.55, 2.0 * pow(0.99, t).toDouble());
  /// 슛 속도: 200 → 초당 +2.2, 상한 480 (슛 종류별 배수는 world_config.dart)
  static double keeperSpeedAt(double t) => min(480.0, 200.0 + 2.2 * t) * keeperShotScale;
  /// 2026-09-24 경기장을 무대 전체로 넓히면서 슈터 자리를 y 280~395 → 110~395 로 넓혀 골라인까지 평균 거리가
  /// 383 → 468(×1.22)이 됐다. 슛이 골라인에 닿는 시간이 예전과 같도록 속도에 같은 배율을 곱한다.
  static const double keeperShotScale = 1.22;
  /// 여러 공이 골라인에 이 간격(초)보다 가깝게 도착하지 않게 늦춘다(간발의 차는 허용)
  static const double keeperArrivalGap = 0.3;
  /// 키퍼가 막는 범위(히트박스 절반, px) — 장갑 능력치(reach)가 더해진다
  static const double keeperReach = 18.0;
}
