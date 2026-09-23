import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// 스테이지 골격 — docs/STAGES.md
//
// 스테이지 3개, 난이도 1→3, **항상 전부 열려 있다**(해금 없음).
// 리더보드는 스테이지별로 완전 분리된 **신규** mapId (기존 zone_1_classic 은 잇지 않는다).
//
//   1 Cyber      피하기   빈 아레나   현행 네온 탄막 (사방 링 스폰)
//   2 Dodgeball  피하기   빈 코트     상대 코트(위)에서 캐릭터를 향해 한 턴에 한 번 투구
//   3 Keeper     막기     아래 골문    페널티킥형 — 위쪽 슈터들이 차고 키퍼는 골라인 앞 좌우 이동, 5골이면 게임 오버
//
// 진입 예고 표시는 없다(2026-09-18 제거).
// 스포너: ring(1), thrower(2 — _DodgeballThrower), shooter(3 — _KeeperShooter + KeeperGoal). 투사체 거동(straight/curve/bounce)과 Keeper 모드는
// Bullet/Player 가 처리한다.
// ─────────────────────────────────────────────────────────────

/// 스테이지의 동사. `dodge` = 맞으면 손해, `keeper` = 공에 닿으면 세이브·골대에 들어오면 실점.
enum WorldMode { dodge, keeper }

/// 투사체 거동. `Bullet`이 전부 지원한다.
/// wave = 좌우로 꼬불꼬불(사인파), knuckle = 무회전 — 옆으로 흔들리는 방향이 불규칙하게 바뀐다.
enum ProjectileMotion { straight, curve, homing, bounce, wave, knuckle }

/// 스포너 전략. `ring` = 중심(플레이어 또는 골대) 기준 원주, `thrower` = 위쪽 한 곳에서 턴마다 조준 투구(피구).
enum SpawnStrategy { ring, thrower, shooter }

class ProjectileDef {
  final String id;
  final String nameKey;
  /// 램프 속도에 곱해지는 배수
  final double speedMult;
  /// 히트박스 반지름(px). 시각 크기와 분리.
  final double radius;
  /// 렌더 지름(px)
  final double visualSize;
  final ProjectileMotion motion;
  /// curve: 진행 방향에 수직인 가속도(px/s²). 부호는 스폰 시 랜덤.
  final double lateralAccel;
  /// homing: 초당 회전 각(rad/s)
  final double turnRate;
  /// homing: 이 시간이 지나면 유도를 멈추고 직진
  final double maxTurnTime;
  /// wave: 좌우 흔들림 폭(px)·초당 횟수. knuckle: [waveAmp] 가 옆으로 흔들리는 최대 속도(px/s)
  final double waveAmp;
  final double waveHz;
  /// 뒤에 꼬리(잔상)를 그린다 — 총알슛
  final bool trail;
  final Color color;
  final Color coreColor;
  /// 피구공 무늬(빨간 띠)를 그린다(큰 공 전용) — paintDodgeBallBand
  final bool seams;
  /// 축구공 무늬(오각형)를 그린다(큰 공 전용) — paintSoccerPatches
  final bool soccer;

  const ProjectileDef({
    required this.id,
    required this.nameKey,
    this.speedMult = 1.0,
    this.radius = 3.5,
    this.visualSize = 9,
    this.motion = ProjectileMotion.straight,
    this.lateralAccel = 0,
    this.turnRate = 0,
    this.maxTurnTime = 0,
    this.waveAmp = 0,
    this.waveHz = 0,
    this.trail = false,
    required this.color,
    this.coreColor = Colors.white,
    this.seams = false,
    this.soccer = false,
  });
}

class WorldConfig {
  final String id;

  /// 게임 중·결과 화면의 추가 기록 항목(번역 키) — 스테이지마다 다르고, 셀 때마다 보너스 코인(CoinStore.bonusFor).
  ///   갤럭시: 근접 회피(탄을 아슬아슬하게 스침) · 피구: 아슬 회피(큰 공을 몸 가까이서 스침, 더 좁은 링)
  ///   골키퍼: 연속 선방(직전 세이브 후 짧은 시간 안에 또 막으면 1)
  String get statKey => mode == WorldMode.keeper ? 'save_streak' : (id == 'dodgeball' ? 'close_dodge' : 'graze');
  /// 난이도 = 스테이지 번호(1~3). 캐러셀 순서와 같다.
  final int difficulty;
  final WorldMode mode;
  /// translations 키: 표시 이름
  final String nameKey;
  /// translations 키: 한 줄 판타지
  final String taglineKey;
  /// `GameConfig.stages` 의 장애물 레이아웃 id
  final String layoutId;
  /// Firestore `maps/{rankingMapId}` — 스테이지별 리더보드(신규)
  final String rankingMapId;
  final List<ProjectileDef> projectiles;
  final SpawnStrategy spawner;
  /// ring 스포너: 스폰 반경(dodge = 플레이어 중심, keeper = 골대 중심)
  final double spawnRadius;
  /// 동시 탄 상한 기본값(램프가 더한다)
  final int maxBullets;
  /// 스폰 간격(초) 시작값. null 이면 레이아웃(StageConfig) 기본값(0.10). 램프가 0.9^level 을 곱한다.
  final double? spawnInterval;
  /// 기본 탄속. null 이면 StageConfig 기본값(150). 램프가 +15/level, 상한 2배.
  final double? bulletSpeed;
  /// keeper: 골대 반지름(px)
  final double goalRadius;
  /// keeper: 허용 골 수. 이만큼 먹히면 게임 오버
  final int lives;
  /// 스테이지 강조색 — 카드·START·HUD
  final Color accent;
  /// 무대 바닥 (배경 이미지 `assets/images/worlds/{id}_bg.png` 가 없을 때)
  final Color floor;
  /// 무대 라인/테두리
  final Color line;
  /// 코트 전체(무대 좌표). 피구: 배경 이미지의 코트 라인 안쪽. 바깥 띠는 외야(패스가 도는 곳)
  final Rect? court;
  /// 캐릭터가 움직일 수 있는 영역. null 이면 무대 전체. 피구: 우리 편 진영(코트 아래 절반)
  final Rect? playArea;
  /// 화면에 보이는 무대 창(무대 좌표). null 이면 무대 전체(480×768). 피구·골키퍼는 반코트처럼 짧게 보여 준다
  final Rect? view;

  const WorldConfig({
    required this.id,
    required this.difficulty,
    this.mode = WorldMode.dodge,
    required this.nameKey,
    required this.taglineKey,
    required this.layoutId,
    required this.rankingMapId,
    required this.projectiles,
    this.spawner = SpawnStrategy.ring,
    this.spawnRadius = 450,
    this.maxBullets = 60,
    this.spawnInterval,
    this.bulletSpeed,
    this.goalRadius = 0,
    this.lives = 0,
    required this.accent,
    required this.floor,
    required this.line,
    this.court,
    this.playArea,
    this.view,
  });

  /// 표시용 대문자 id (번역 누락 시 폴백)
  String get displayName => id.toUpperCase();

  /// 항상 열려 있다 — 호출부 호환용
  bool get available => true;
}

class WorldData {
  static const List<WorldConfig> worlds = [
    // ── 1. Cyber — 현행 ZONBER 네온 탄막. 리더보드는 신규 'cyber' ──────
    WorldConfig(
      id: 'cyber',
      difficulty: 1,
      nameKey: 'world_cyber',
      taglineKey: 'world_cyber_tagline',
      layoutId: 'zone_1_classic',
      rankingMapId: 'cyber',
      projectiles: [
        ProjectileDef(
          id: 'bullet', nameKey: 'proj_cyber_bullet',
          speedMult: 1.0, radius: 3.5, visualSize: 9,
          color: Color(0xFFD32F2F),
        ),
      ],
      spawner: SpawnStrategy.ring,
      spawnRadius: 450,
      maxBullets: 60,
      accent: Color(0xFF0A9DBD),
      floor: Color(0xFF141A33), // 네온 탄이 읽히도록 짙은 남색 무대는 유지
      line: Color(0x6619E6FF),
    ),
    // ── 2. Dodgeball — 상대 코트(위)에서 캐릭터를 향해 던진다. 분열·세트 투구로 점점 어려워진다 ──
    WorldConfig(
      id: 'dodgeball',
      difficulty: 2,
      nameKey: 'world_dodgeball',
      taglineKey: 'world_dodgeball_tagline',
      layoutId: 'zone_1_classic',
      rankingMapId: 'dodgeball',
      projectiles: [
        ProjectileDef(
          id: 'ball', nameKey: 'proj_dodgeball_ball',
          speedMult: 1.0, radius: 8, visualSize: 22,
          // 노란 피구공 + 빨간 띠 (놀이터 피구공, 피구왕 통키 참고)
          color: Color(0xFFFFC928), seams: true,
        ),
        ProjectileDef(
          id: 'fast', nameKey: 'proj_dodgeball_fast',
          speedMult: 1.35, radius: 7, visualSize: 18,
          // 빠른 공 — 주황 + 띠 (노란 기본 공과 한눈에 구분). 외야 패스 뒤 속공도 이 공
          color: Color(0xFFFF7A1A), seams: true,
        ),
      ],
      // 턴 간격·속도·패턴은 _DodgeballThrower 가 시간으로 정한다(spawnInterval/bulletSpeed 미사용)
      spawner: SpawnStrategy.thrower,
      maxBullets: 40,
      accent: Color(0xFFE5484D),
      floor: Color(0xFFE9CFA6), // 밝은 마루
      line: Color(0xB3FFFFFF),
      // dodgeball_bg.png(960×1536) 코트 라인을 잰 값 ÷2. 배경을 바꾸면 다시 잴 것.
      court: Rect.fromLTRB(46, 230, 434, 690),
      playArea: Rect.fromLTRB(46, 462, 434, 690), // 중앙선(y 460) 아래 = 우리 편 진영
      view: Rect.fromLTRB(0, 190, 480, 750), // 코트 + 외야 띠만 보이게(세로 560)
    ),
    // ── 3. Keeper — 가운데 골대를 지킨다. 공에 닿으면 세이브, 골대에 들어오면 실점 ──
    WorldConfig(
      id: 'keeper',
      difficulty: 3,
      mode: WorldMode.keeper,
      nameKey: 'world_keeper',
      taglineKey: 'world_keeper_tagline',
      layoutId: 'zone_1_classic',
      rankingMapId: 'keeper',
      projectiles: [
        // 직선 슛 — 흰 축구공
        ProjectileDef(
          id: 'shot', nameKey: 'proj_keeper_shot',
          speedMult: 1.0, radius: 7, visualSize: 19,
          color: Color(0xFFF4F6F8), soccer: true,
        ),
        // 강슛 — 노란 축구공, 빠르다
        ProjectileDef(
          id: 'power', nameKey: 'proj_keeper_power',
          speedMult: 1.35, radius: 7, visualSize: 19,
          color: Color(0xFFFFD23F), soccer: true,
        ),
        // 바나나킥 — 하늘색 축구공, 휘어 들어온다(슈터가 휘는 만큼 반대로 겨눠 찬다)
        ProjectileDef(
          id: 'curve', nameKey: 'proj_keeper_curve',
          speedMult: 1.0, radius: 7, visualSize: 19,
          motion: ProjectileMotion.curve, lateralAccel: 110,
          color: Color(0xFFBDE3FF), soccer: true,
        ),
        // 꼬불꼬불 슛 — 분홍 축구공, 좌우로 흔들리며 온다
        ProjectileDef(
          id: 'wave', nameKey: 'proj_keeper_wave',
          speedMult: 0.9, radius: 7, visualSize: 19,
          motion: ProjectileMotion.wave, waveAmp: 34, waveHz: 1.6,
          color: Color(0xFFFFB8D9), soccer: true,
        ),
        // 총알슛 — 주황 축구공 + 꼬리, 아주 빠르다
        ProjectileDef(
          id: 'bullet', nameKey: 'proj_keeper_bullet',
          speedMult: 1.6, radius: 7, visualSize: 18,
          color: Color(0xFFFF8A3D), soccer: true, trail: true,
        ),
        // 무회전 — 보라 축구공, 돌지 않고 어디로 휠지 모르게 흔들린다
        ProjectileDef(
          id: 'knuckle', nameKey: 'proj_keeper_knuckle',
          speedMult: 1.0, radius: 7, visualSize: 19,
          motion: ProjectileMotion.knuckle, waveAmp: 150,
          color: Color(0xFFD9CCFF), soccer: true,
        ),
      ],
      // 페널티킥형 — 골문·슈터·턴·속도는 KeeperGoal / _KeeperShooter 가 정한다(goalRadius·spawnRadius 미사용)
      spawner: SpawnStrategy.shooter,
      spawnRadius: 430,
      maxBullets: 24,
      goalRadius: 64,
      // 페널티 에어리어 = 키퍼 이동 영역 = 나의 존 (KeeperGoal.penaltyBox 와 같은 값)
      playArea: Rect.fromLTRB(12, 420, 468, 720),
      view: Rect.fromLTRB(0, 250, 480, 768), // 반코트 — 페널티 에어리어와 그 앞 슈터 자리만(세로 518)
      lives: 5,
      accent: Color(0xFF2F6FE4),
      floor: Color(0xFFA8DC8F), // 밝은 잔디
      line: Color(0xB3FFFFFF),
    ),
  ];

  static WorldConfig getWorld(String id) =>
      worlds.firstWhere((w) => w.id == id, orElse: () => defaultWorld);

  /// 첫 실행·폴백 = 스테이지 1
  static WorldConfig get defaultWorld => worlds.first;

  /// 모든 스테이지는 항상 열려 있다. (호출부 호환용 — 항상 true)
  static bool isUnlocked(WorldConfig w, Map<String, double> bestTimes) => true;

  /// 랭킹 mapId → 스테이지
  static WorldConfig? byRankingMapId(String mapId) {
    for (final w in worlds) {
      if (w.rankingMapId == mapId) return w;
    }
    return null;
  }
}
