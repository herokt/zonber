part of '../main.dart';

// ZonberGame(Flame) — 무대·카메라·연출·게임 오버, 맵·장애물·배경 (main.dart 에서 나눔 · 2026-09-22)

class ZonberGame extends FlameGame with HasCollisionDetection, PanDetector {
  /// 장애물 레이아웃 id (`GameConfig.stages`) — 월드의 layoutId
  final String mapId;
  /// 월드 — 투사체·스포너·테마
  final WorldConfig worldConfig;
  final VoidCallback onExit;
  final Function(Map<String, dynamic>) onGameOver; // Callback for game over
  final double initialSurvivalTime;
  /// 이 판 이전의 개인 최고(초) — HUD의 BEST 표시용
  final double personalBest;

  ZonberGame({
    required this.mapId,
    WorldConfig? worldConfig,
    required this.onExit,
    required this.onGameOver,
    this.initialSurvivalTime = 0.0,
    this.personalBest = 0.0,
  }) : worldConfig = worldConfig ?? WorldData.defaultWorld;

  // ── 목표선 / 근접 회피 ──
  List<({String label, double time})> _targets = const [];
  final ValueNotifier<({String label, double time})?> targetNotifier = ValueNotifier(null);
  final ValueNotifier<int> grazeNotifier = ValueNotifier(0);

  void setTargets(List<({String label, double time})> targets) {
    _targets = targets;
    _updateTarget();
  }

  void _updateTarget() {
    ({String label, double time})? next;
    for (final t in _targets) {
      if (t.time > survivalTime) {
        next = t;
        break;
      }
    }
    if (targetNotifier.value != next) targetNotifier.value = next;
  }

  static const double mapWidth = 480.0;
  static const double mapHeight =
      768.0; // Updated to 24x32 grid (fits aspect ratio)
  static const double worldHeight = 800.0; // (구) 무대+하단 조이스틱 영역. 화면 밖 판정에만 쓴다
  /// 무대 바깥 여백 — 테두리와 그림자가 화면 끝에 붙지 않게
  static const double arenaMargin = 10.0;

  late Player player;
  late BulletSpawner spawner;

  // ── 나의 ZONE · 시작 연출 ──
  /// 나의 존: 캐릭터가 움직일 수 있는 영역. 갤럭시 = 맵 전체, 피구 = 우리 진영, 골키퍼 = 페널티 에어리어
  Rect get zoneRect => worldConfig.playArea ?? const Rect.fromLTWH(0, 0, mapWidth, mapHeight);
  /// 경기장 — 세 존 모두 무대 480×768 전체(2026-09-24). 존마다 화면에 같은 크기·같은 자리로 보인다.
  /// (예전엔 피구·골키퍼가 무대 일부만 보여 줘서 존마다 경기장 크기가 달랐고, 기기 비율에 따라 창을 늘였다)
  static const Rect viewRect = Rect.fromLTWH(0, 0, mapWidth, mapHeight);

  /// 경기장(+테두리 여백)이 게임 영역 안에 통째로 들어가는 가장 큰 크기로, 가운데 맞춤.
  /// 폭·높이 중 먼저 닿는 쪽에 맞추고(비율 유지), 남는 쪽은 존 바닥색 여백이 양쪽에 같게 남는다.
  /// 무대 좌표는 기기와 무관하게 같다 — 기기마다 보이는 경기장 넓이가 달라지지 않는다(랭킹 공정).
  void _fitView() {
    camera.viewfinder.visibleGameSize = Vector2(mapWidth + arenaMargin * 2, mapHeight + arenaMargin * 2);
    camera.viewfinder.position = Vector2(mapWidth / 2, mapHeight / 2);
    camera.viewfinder.anchor = Anchor.center;
  }
  /// 시작 전 남은 인트로 시간(초). 이 동안은 공이 나오지 않고 시간도 흐르지 않는다.
  double introLeft = 0;
  static const double introZone = 3.0; // 존 미션 안내 — 읽을 시간을 넉넉히
  static const double introStart = 0.7; // START!
  bool get inIntro => introLeft > 0;
  /// Flutter 오버레이 문구: 'zone' | 'start' | null
  final ValueNotifier<String?> introNotifier = ValueNotifier(null);

  // ── 타격감 연출 ──
  final Random _fxRng = Random();
  /// 붉은 번쩍임 트리거(값이 바뀔 때마다 한 번)
  final ValueNotifier<int> flashNotifier = ValueNotifier(0);

  /// [at] 에서 [color] 파편이 튀어 퍼진다
  void burst(Vector2 at, Color color, {int count = 16, double speed = 220, double size = 3}) {
    // 파편 하나마다 매 프레임 Paint 를 만들지 않도록 한 번 터질 때 붓 하나를 같이 쓴다
    final paint = Paint();
    mapArea.add(ParticleSystemComponent(
      position: at.clone(),
      priority: 14,
      particle: Particle.generate(
        count: count,
        lifespan: 0.5,
        generator: (i) {
          final a = _fxRng.nextDouble() * 2 * pi;
          final v = Vector2(cos(a), sin(a)) * (speed * (0.5 + _fxRng.nextDouble() * 0.7));
          return AcceleratedParticle(
            speed: v,
            acceleration: -v * 1.6,
            child: ComputedParticle(renderer: (canvas, p) {
              canvas.drawCircle(Offset.zero, size * (1 - p.progress * 0.6),
                  paint..color = color.withValues(alpha: 1 - p.progress));
            }),
          );
        },
      ),
    ));
  }

  void flash() => flashNotifier.value++;


  /// 피격(피하기 존) — 파편 · 붉은 번쩍임 (경기장 흔들림은 2026-09-24 전 존에서 뺐다)
  void fxHit(Vector2 at, Color ballColor) {
    burst(at, ballColor, count: 18, speed: 240);
    burst(at, Colors.white, count: 8, speed: 140, size: 2);
    flash();
  }

  /// 실점(골키퍼) — 그물 앞 파편 · 붉은 번쩍임(문구는 띄우지 않는다)
  void fxGoal(Vector2 at) {
    burst(at, Colors.white, count: 22, speed: 260, size: 3);
    burst(at, const Color(0xFFE5484D), count: 12, speed: 180);
    flash();
  }

  /// 세이브 — 파편(문구·연속 표시는 띄우지 않는다)
  void fxSave(Vector2 at) {
    burst(at, Colors.white, count: 12, speed: 200, size: 2.5);
  }

  /// 골키퍼 — 페널티킥 골문·슈터 상태
  final KeeperGoal goal = KeeperGoal();
  /// 피구 — 상대 팀(내야·외야 선수) 상태
  final DodgeTeam dodgeTeam = DodgeTeam();
  late MapArea mapArea;
  // Joystick removed for touch-anywhere control

  // Direct Drag Control State
  Vector2 _dragDeltaAccumulator = Vector2.zero();

  Vector2 consumeDragDelta() {
    Vector2 delta = _dragDeltaAccumulator.clone();
    _dragDeltaAccumulator.setZero();
    return delta;
  }

  // UI Logic
  final ValueNotifier<double> survivalTimeNotifier = ValueNotifier(0.0);

  /// 위기 — 에너지(골키퍼는 남은 목숨)가 1칸. HUD 붉은 테두리 · 심장박동 소리 · 약한 진동
  final ValueNotifier<bool> dangerNotifier = ValueNotifier(false);
  int _lastLevel = 0;
  bool _bestAnnounced = false;
  double _heartT = 0;

  /// 멈춤·나가기 — 심장박동을 끈다(다시 이어지면 update 가 다시 켠다)
  void quietDanger() {
    dangerNotifier.value = false;
    AudioManager().setHeartbeat(false);
  }

  @override
  void onRemove() {
    AudioManager().setHeartbeat(false);
    super.onRemove();
  }

  void _updateFeedback(double dt) {
    // 레벨업(30초마다 빨라진다)
    final lv = spawner.currentLevel;
    if (lv > _lastLevel && survivalTime > 1) {
      AudioManager().playSfx(Sfx.levelUp, volume: 0.6);
      Haptics.medium();
    }
    _lastLevel = lv;
    // 개인 최고 기록을 넘긴 순간 — 한 판에 한 번
    if (!_bestAnnounced && personalBest > 0 && survivalTime > personalBest) {
      _bestAnnounced = true;
      AudioManager().playSfx(Sfx.newBest, volume: 0.7);
      Haptics.medium();
    }
    // 위기
    final e = energyNotifier.value;
    final danger = e.max > 1 && e.current <= 1;
    if (danger != dangerNotifier.value) {
      dangerNotifier.value = danger;
      AudioManager().setHeartbeat(danger);
      _heartT = 0;
    }
    if (danger) {
      _heartT -= dt;
      if (_heartT <= 0) {
        _heartT = 0.8;
        Haptics.heartbeat();
      }
    }
  }

  /// 에너지(실드) 상태 — Player가 매 프레임 업데이트
  final ValueNotifier<({int current, int max, double chargeProgress, Color color})>
      energyNotifier = ValueNotifier((
    current: 0,
    max: 0,
    chargeProgress: 0.0,
    color: AppColors.primary,
  ));

  double survivalTime = 0.0;
  bool isGameOver = false;
  /// 성능 측정(test/perf_bench_test.dart) 전용 — 맞거나 골을 먹어도 판이 끝나지 않는다
  @visibleForTesting
  bool debugNoGameOver = false;
  String? lastRecordId; // Last saved record ID

  @override
  Color backgroundColor() => worldConfig.floor;

  @override
  Future<void> onLoad() async {
    // 무대 전체(+테두리 여백)를 가운데 맞춤 — 세로가 긴 폰에서는 위아래가 존 바닥색으로 고르게 남는다
    camera.viewfinder.anchor = Anchor.center;

    world.add(GridBackground()..priority = 5);
    mapArea = MapArea();
    world.add(mapArea);

    // Joystick removed

    startGame(initialTime: initialSurvivalTime);
  }

  void startGame({double initialTime = 0.0}) {
    isGameOver = false;
    survivalTime = initialTime;
    survivalTimeNotifier.value = initialTime;
    lastRecordId = null;

    // Track Play Count
    // Track Play Count - Moved to RankingSystem.saveRecord (Global)
    // UserProfileManager.incrementMapPlayCount(mapId);

    overlays.remove('GameOverMenu');
    // overlays.add('GameUI'); // Removed old overlay

    mapArea.removeAll(mapArea.children);
    _addStageBackground();

    final bool keeper = worldConfig.mode == WorldMode.keeper;
    if (keeper) mapArea.add(GoalZone()..priority = 1);
    if (worldConfig.court != null) mapArea.add(DodgeTeamZone()..priority = 2);
    // 새 판은 존 깜빡임부터, 부활로 이어지는 판은 START! 만
    introLeft = initialSurvivalTime > 0 ? introStart : introZone + introStart;
    // introNotifier 는 여기(onLoad — Flutter 가 화면을 짓는 중)서 바꾸지 않는다. 첫 update 에서 설정된다.
    // (빌드 도중 ValueNotifier 를 바꾸면 릴리스 웹에서 HUD 갱신이 멈췄다)
    mapArea.add(ZoneIntro()..priority = 16);
    player = Player()
      ..keeperMode = keeper
      // Keeper 는 골대 바로 아래에서 시작한다
      ..position = keeper
          ? Vector2(mapWidth / 2, KeeperGoal.keeperY) // 골문 정면
          : worldConfig.playArea != null
              ? Vector2(worldConfig.playArea!.center.dx, worldConfig.playArea!.center.dy)
              : Vector2(mapWidth / 2, mapHeight / 2)
      ..width = 48
      ..height = 48
      ..anchor = Anchor.center
      ..priority = 10; // Ensure player is above trail (trail will be 0 or -1)
    mapArea.add(player);

    camera.stop();
    _fitView();

    spawner = BulletSpawner();
    mapArea.add(spawner);

    resumeEngine();

    // Start BGM
    AudioManager().startBgm();
  }

  /// 스테이지 배경 이미지 — `assets/images/worlds/{id}_bg.png`(더미 또는 실아트).
  /// 없으면 `worldConfig.floor` 색만 쓴다.
  Future<void> _addStageBackground() async {
    try {
      final sprite = await loadSprite('worlds/${worldConfig.id}_bg.png');
      if (isGameOver) return;
      mapArea.add(SpriteComponent(sprite: sprite, size: Vector2(mapWidth, mapHeight), priority: -1));
    } catch (_) {
      // 배경 에셋 없음 — 바닥색만
    }
  }

  void gameOver() {
    if (isGameOver) return;
    isGameOver = true;

    pauseEngine();

    // Stop BGM and Play Game Over
    AudioManager().stopBgm();
    quietDanger();
    AudioManager().playSfx(Sfx.gameOver);

    // Notify App
    onGameOver({
      'survivalTime': recordTime(survivalTime), // 소수점 셋째 자리까지
      'mapId': worldConfig.rankingMapId,
      'level': spawner.currentLevel,
      'graze': player.isMounted ? player.grazeCount : grazeNotifier.value,
    });
  }

  @override
  void update(double dt) {
    // (멈칫 hit-stop 은 뺐다 — 맞고·막고·먹히는 순간 화면이 0.07~0.12초 서서 프레임이 끊긴 것처럼 보였다)
    super.update(dt);

    // 시작 연출 — 나의 존 깜빡임 → START! → 시작
    if (inIntro) {
      introLeft -= dt;
      final phase = introLeft > introStart ? 'zone' : (introLeft > 0 ? 'start' : null);
      if (introNotifier.value != phase) introNotifier.value = phase;
      return;
    }

    if (!isGameOver) {
      survivalTime += dt;
      survivalTimeNotifier.value = survivalTime;
      if (_targets.isNotEmpty) _updateTarget();
      if (player.isMounted) _updateFeedback(dt);
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // 기기·창 크기가 바뀌면 보이는 무대 창을 다시 맞춘다
    if (isLoaded) _fitView();
  }

  // PanDetector Implementation for Direct Touch Control
  @override
  void onPanUpdate(DragUpdateInfo info) {
    _dragDeltaAccumulator += info.delta.global;
  }
}



class MapArea extends PositionComponent {
  MapArea() : super(size: Vector2(ZonberGame.mapWidth, ZonberGame.mapHeight));

  /// 경기장 밖(테두리 여백)으로 나간 공·파편은 그리지 않는다
  @override
  void renderTree(Canvas canvas) {
    canvas.save();
    canvas.clipRect(ZonberGame.viewRect);
    super.renderTree(canvas);
    canvas.restore();
  }

  @override
  void render(Canvas canvas) {
    canvas.clipRect(size.toRect());
    super.render(canvas);
  }
}

/// 존 테두리 — 무대(배경 이미지·공) 위에 그린다. 바깥쪽은 존 바닥색이 이어진다.
class GridBackground extends Component with HasGameReference<ZonberGame> {
  @override
  void render(Canvas canvas) {
    const rect = ZonberGame.viewRect;
    // 바깥 가장자리를 살짝 눌러 무대가 떠 보이게
    canvas.drawRect(
      rect.inflate(3),
      Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = game.worldConfig.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
}

/// Keeper 월드의 골대 존 — 맵 중앙 원. 공이 들어오면 실점(Bullet.update 가 판정). 렌더 전용.
