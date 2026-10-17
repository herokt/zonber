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

  // ── 레벨(세 존 공통, 2026-09-26) ──
  // 레벨은 [levelSeconds]초마다 1씩 오르고 [maxLevel] 에서 멈춘다. 난이도 값은 전부 레벨로 정한다 —
  // 레벨마다 같은 폭으로 조금씩 어려워지고(갑자기 벽이 오지 않게), 최고 레벨 이후로는 더 어려워지지 않는다.
  // 최고 레벨 = "극악이지만 버틸 수는 있는" 값. 예전 곡선에서 잘하는 유저가 무너지던 지점과 비슷하게 잡았다.
  // 레벨 안에서는 값이 그대로다(레벨업 소리·진동과 함께 한 칸 오른다).
  /// 레벨업 간격(초)
  static const double levelSeconds = 15.0;
  /// 최고 레벨 — 15 × 14 = 210초(3분 30초)에 도달
  static const int maxLevel = 15;
  static int levelAt(double t) => min(maxLevel, 1 + (t / levelSeconds).floor());

  /// 레벨 1 → [lv1], 최고 레벨 → [top] 사이를 레벨마다 같은 폭으로
  static double byLevel(int level, double lv1, double top) =>
      lv1 + (top - lv1) * ((level.clamp(1, maxLevel) - 1) / (maxLevel - 1));

  /// 공·탄 속도 곡선(2026-09-30) — 레벨 [speedKnee] 까지는 [byLevel] 과 같은 폭으로 오르고,
  /// 그 뒤로는 레벨마다 그 폭의 [speedLateStep] 배만 오른다. 중·후반(레벨 10 앞뒤)에 빈도·패턴까지 한꺼번에
  /// 올라 기록이 한 레벨에 몰리던 것을 풀려고 속도 증가만 먼저 누그러뜨렸다.
  /// [lv1]·[top] 은 예전(일직선) 곡선의 양 끝 — 실제 최고 레벨 값은 그보다 낮다(아래 각 속도 주석)
  static const int speedKnee = 5;
  static const double speedLateStep = 0.6;
  /// 속도가 오르는 폭 전체에 곱하는 배율(2026-10-12 1.0 → 0.5, 2026-10-17 → 0.35) — 레벨이 올라도 공·탄이 갑자기 빨라지지 않게,
  /// 어려움은 빈도·패턴이 먼저 올리고 속도는 천천히 따라온다. 중·상 레벨에서도 잘 움직이면 버틸 수 있게
  static const double speedGrowth = 0.35;
  static double speedByLevel(int level, double lv1, double top) {
    final l = level.clamp(1, maxLevel);
    final eff = l <= speedKnee ? l.toDouble() : speedKnee + (l - speedKnee) * speedLateStep;
    return lv1 + (top - lv1) * speedGrowth * ((eff - 1) / (maxLevel - 1));
  }

  /// 패턴 단계(0~6)가 시작되는 레벨 — 피구·골키퍼 공통. 단계마다 새 패턴이 하나씩 나온다
  static const List<int> tierLevels = [1, 2, 4, 6, 8, 10, 13];
  static int tierOf(int level) {
    var tier = 0;
    for (var i = 0; i < tierLevels.length; i++) {
      if (level >= tierLevels[i]) tier = i;
    }
    return tier;
  }

  // ── 갤럭시(링에서 나를 조준) ──
  /// 초당 탄 수 4.5 → 14.5 (2026-10-12 초반이 다른 두 존보다 어려워 시작 7 → 5, 같은 날 큰 운석이 생겨 전체 × 0.9.
  /// 2026-10-17 탄 사이를 벌리려고 최고 18 → 14.5. L5 7.4 · L10 10.9)
  static double cyberRate(int level) => byLevel(level, 4.5, 14.5);
  /// 탄속 150 → 180 ([speedByLevel] — L5 162 · L10 171. 2026-10-12 시작 160 → 150)
  static double cyberSpeed(int level) => speedByLevel(level, 150.0, 270.0);
  /// 화면에 동시에 있는 탄 상한 54 → 100 (2026-10-12 × 0.9, 2026-10-17 최고 126 → 100 — 초당 탄 수와 같이)
  static int cyberCap(int level) => byLevel(level, 54.0, 100.0).round();

  // ── 피구 ──
  /// 외야 패스 횟수 범위(무작위)
  static const int passHopsMin = 1, passHopsMax = 5;
  /// 턴 간격 1.2s → 0.55s. 던지는 빈도(1/간격)가 레벨마다 같은 폭으로 늘게 잡는다(2026-10-12 초반이 쉬워 시작 1.6s → 1.2s,
  /// 2026-10-17 최고 0.45s → 0.55s — L5 0.90s · L10 0.68s)
  static double dodgeBeat(int level) => 1 / byLevel(level, 1 / 1.2, 1 / 0.55);
  /// 공 속도 210 → 268 ([speedByLevel] — L5 233 · L10 250. 2026-10-12 시작 170 → 210)
  /// (투구는 여기에 [dodgeThrowScale] 을 곱한다. 외야 패스 속공은 곱하지 않는다)
  static double dodgeSpeed(int level) => speedByLevel(level, 210.0, 440.0);
  /// 두 곳에서 동시 투구 확률(단계별) — 극악 50% → 40%
  static const List<double> dodgeTwin = [0, 0, 0, 0, 0, 0.25, 0.4];
  /// 동시 투구의 두 번째 공은 이만큼(초) 늦게 — 두 공이 한 덩어리로 오지 않게(2026-10-12 0.35, 2026-10-17 → 0.45)
  static const double dodgeTwinDelay = 0.45;
  /// 일렬 투구(3·4·5개) — 공마다 이만큼(초)씩 늦게 던져 비스듬한·V자 대형으로 온다(2026-10-12 0.08, 2026-10-17 → 0.10. 예전엔 나란한 벽이 한꺼번에)
  static const double dodgeRowStagger = 0.10;
  /// 일렬 투구 공마다 속도를 이 비율 안에서 조금씩 다르게(±)
  static const double dodgeRowSpeedJitter = 0.06;
  /// 극악 단계 예측 조준 — 캐릭터가 가는 방향 이 시간(초) 앞을 노린다(예전 0.35)
  static const double dodgeLead = 0.25;
  /// 2026-09-24 코트를 무대 가운데 크게(세로 460 → 624) 키우면서 내야 → 우리 진영 평균 거리가 248 → 330(×1.33)이 됐다.
  /// 공이 오는 데 걸리는 시간(반응 시간)이 예전과 같도록 투구 속도에 같은 배율을 곱한다.
  /// 외야 패스는 좌우·뒤 외야에서 던지므로 거리가 거의 그대로라 곱하지 않는다.
  static const double dodgeThrowScale = 1.33;

  // ── 골키퍼 ──
  /// 턴 간격 1.5s → 0.8s (빈도가 레벨마다 같은 폭으로). 2026-10-12 초반이 쉬워 시작 2.0s → 1.5s,
  /// 2026-10-17 최고 0.65s → 0.8s — L5 1.20s · L10 0.96s
  static double keeperBeat(int level) => 1 / byLevel(level, 1 / 1.5, 1 / 0.8);
  /// 슛 속도 240 → 290 ([speedByLevel] — L5 260 · L10 275. 2026-10-12 시작 200 → 240),
  /// 여기에 [keeperShotScale] (슛 종류별 배수는 world_config.dart)
  static double keeperSpeed(int level) => speedByLevel(level, 240.0, 440.0) * keeperShotScale;
  /// 2026-09-24 경기장을 무대 전체로 넓히면서 슈터 자리를 y 280~395 → 110~395 로 넓혀 골라인까지 평균 거리가
  /// 383 → 468(×1.22)이 됐다. 슛이 골라인에 닿는 시간이 예전과 같도록 속도에 같은 배율을 곱한다.
  static const double keeperShotScale = 1.22;
  /// 여러 공이 골라인에 이 간격(초)보다 가깝게 도착하지 않게 늦춘다(2026-10-12 0.3 → 0.45, 2026-10-17 → 0.55 — 공이 뭉쳐 오지 않게)
  static const double keeperArrivalGap = 0.55;
  /// 여러 명이 동시에 찰 때 한 명씩 차는 간격(초)(2026-10-12 0.12 → 0.25)
  static const double keeperKickStagger = 0.25;
  /// 키퍼가 막는 범위(히트박스 절반, px) — 장갑 능력치(reach)가 더해진다
  static const double keeperReach = 18.0;
}
