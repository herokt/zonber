part of '../main.dart';

// 플레이어(존버) — 이동·에너지·무적·추가 기록·골키퍼 판정 (main.dart 에서 나눔 · 2026-09-22)

class Player extends PositionComponent
    with CollisionCallbacks, HasGameReference<ZonberGame> {
  /// 내 아바타 한 벌(avatar.dart) — 캐릭터 · 몸통 스킨 · 잔상 · 오라 · 이 존 장비.
  /// 가방에서 장착한 그대로가 게임 안에도 나온다
  Avatar avatar = Avatar.fallback;
  /// Keeper 월드: 공에 닿으면 세이브, 다치지 않는다. 목숨은 월드 lives.
  bool keeperMode = false;

  String get characterId => avatar.characterId;
  Color get trailColor => avatar.color;
  String get trailId => avatar.trailId;
  String get auraId => avatar.auraId;
  /// 이 존에서 입은 장비(gear.dart) — 능력치 보너스도 여기서 나온다
  List<String> get gearIds => avatar.gearOf(game.worldConfig.id);
  double _auraT = 0;

  // --- 표정·몸짓(존버) ---
  ZonberFace _face = ZonberFace.normal;
  double _faceTimer = 0;
  double _squash = 0;
  bool _moving = false;

  /// 잠깐 표정을 바꾼다 — 아야(맞음·실점) / 신남(아슬아슬·세이브)
  void showFace(ZonberFace f, double seconds, {bool squash = false}) {
    // 아야가 신남보다 우선
    if (_face == ZonberFace.hurt && _faceTimer > 0 && f == ZonberFace.happy) return;
    _face = f;
    _faceTimer = seconds;
    if (squash) _squash = 1;
  }

  // 연기·잔상 파티클 — 매 프레임 Random·Paint 를 새로 만들지 않고 돌려 쓴다
  static final Random _rng = Random();
  static final Paint _smokePaint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

  // --- 캐릭터 스탯 (onLoad에서 CharacterStats로부터 설정) ---
  double _hbHalf = 12.0;       // 히트박스 절반 크기
  double _speedMult = 1.0;     // 이동 속도 배수
  int _maxShields = 0;         // 최대 실드 개수
  double _shieldCooldown = 0;  // 기력 기반 회복 속도 (낮을수록 빠름)
  double _iframeDuration = 1.5; // 회피: 피격 후 무적 시간 (캐릭터별)
  // --- 런타임 상태 ---
  double _energy = 0;       // 현재 에너지 (0.0 ~ _maxShields)
  bool _isInvincible = false;
  double _invincibleTimer = 0;
  double _invincibleDuration = 1.5; // 이번 무적의 지속 시간 (파워업으로 연장 가능)
  bool _isBlinking = false;
  double _blinkTimer = 0;
  bool _blinkVisible = true;

  // --- 추가 기록(스테이지별, WorldConfig.statKey). 셀 때마다 보너스 코인 ---
  // 갤럭시 근접 회피 · 피구 아슬 회피: 히트박스 바깥 링을 스치고 지나간 탄(피구는 링이 더 좁다)
  int grazeCount = 0;
  final Set<Bullet> _grazing = {};
  // 난이도를 비슷하게: 탄이 많은 갤럭시는 링을 더 좁게, 공이 적은 피구는 조금 넓게
  static const double _grazeRing = Balance.grazeRing;
  static const double _closeDodgeRing = Balance.closeDodgeRing;

  void _updateGraze() {
    final ring = _hbHalf + (game.worldConfig.statKey == 'close_dodge' ? _closeDodgeRing : _grazeRing);
    _grazing.removeWhere((b) => !b.isMounted); // 피격·소멸된 탄은 카운트하지 않는다
    for (final c in game.mapArea.children) {
      if (c is! Bullet) continue;
      final d = c.position.distanceTo(position);
      final r = ring + c.def.radius;
      if (d < r) {
        _grazing.add(c);
      } else if (_grazing.contains(c) && d > r + 6) {
        _grazing.remove(c);
        grazeCount++;
        game.grazeNotifier.value = grazeCount;
        showFace(ZonberFace.happy, 0.45);
        _statSpark();
      }
    }
  }

  @override
  Future<void> onLoad() async {
    // 캐릭터 스탯 먼저 로드
    final profile = await UserProfileManager.getProfile();
    avatar = await Avatar.mine(profile['characterId'] ?? Avatar.defaultCharacterId);
    final stats = avatar.character.stats;
    // 존 장비의 능력치 보너스(gear.dart) — 입은 그대로가 곧 보너스다
    final zone = game.worldConfig.id;
    final bonus = Gear.bonusOf(zone, CoinStore.equipped);

    // 모든 캐릭터 동일한 시각 크기 및 히트박스
    const double visualSize = 42;
    const double hitboxSize = 22;
    size = Vector2(visualSize, visualSize);

    // 스탯 적용 — 캐릭터 공통 기본값 + 장비 보너스
    _hbHalf = 11.0; // 고정 히트박스 22px의 절반
    _speedMult = stats.speedMultiplier + bonus.speed;
    _maxShields = stats.maxEnergy + bonus.energy;
    _shieldCooldown = max(1.0, stats.energyCooldown - bonus.recovery);
    _iframeDuration = stats.iframeDuration + bonus.iframe;
    _invincibleDuration = _iframeDuration;
    _energy = _maxShields.toDouble(); // 최대치로 시작
    if (keeperMode) {
      // Keeper: 목숨 = 허용 골 수(월드 lives), 회복 없음. 무적은 쓰이지 않는다.
      // 막는 범위는 몸 크기만큼 넉넉하게(36px) — 골문 폭 280 을 한 명이 지킨다
      _hbHalf = Balance.keeperReach + bonus.reach;
      _maxShields = game.worldConfig.lives;
      _shieldCooldown = 0;
      _energy = _maxShields.toDouble();
    }

    // 히트박스: 시각 크기 중앙에 배치
    const double hbOffset = (visualSize - hitboxSize) / 2;
    add(
      RectangleHitbox(
        position: Vector2(hbOffset, hbOffset),
        size: Vector2(hitboxSize, hitboxSize),
      ),
    );

    // 캐릭터는 코드로 그린다(render — paintZonber). 스프라이트 이미지는 쓰지 않는다

    // 초기 에너지 상태 HUD에 반영
    _notifyEnergy();
  }

  void _notifyEnergy() {
    final int current = _energy.floor().clamp(0, _maxShields);
    final double progress = _energy - current;
    game.energyNotifier.value = (
      current: current,
      max: _maxShields,
      chargeProgress: progress,
      color: trailColor,
    );
  }

  @override
  void render(Canvas canvas) {
    // 깜빡임 중 비가시 프레임이면 스킵
    if (_isBlinking && !_blinkVisible) return;

    // 오라 — 몸이 기울어도 오라(왕관·고리)는 똑바로 서 있게 기울기를 되돌려 그린다
    final r = size.x * 0.43;
    void upright(void Function() draw) {
      canvas.save();
      canvas.translate(size.x / 2, size.y / 2);
      canvas.rotate(-angle);
      draw();
      canvas.restore();
    }
    final hasAura = auraId != Cosmetics.defaultAura;
    super.render(canvas); // PositionComponent — 자기 그림은 없다(아래에서 코드로 그린다)
    if (hasAura) upright(() => paintAura(canvas, auraId, Offset.zero, r, _auraT, trailColor, front: false));
    // 존버 — 몸 반지름 16(판정 히트박스는 22px 그대로), 손발·장비가 조금 삐져나온다
    final v = recentVelocity;
    paintZonber(
      canvas,
      Offset(size.x / 2, size.y / 2),
      16,
      avatar.look(
        zone: game.worldConfig.id,
        face: _face,
        t: _auraT,
        moving: _moving,
        squash: _squash,
        lookAt: Offset(v.x / 300, v.y / 300),
      ),
    );
    if (hasAura) upright(() => paintAura(canvas, auraId, Offset.zero, r, _auraT, trailColor, front: true));
  }

  /// 최근 이동 속도(px/s, 지수 평활) — 피구 극악 단계의 예측 조준에 쓴다
  Vector2 recentVelocity = Vector2.zero();
  Vector2? _prevPos;

  @override
  void update(double dt) {
    super.update(dt);
    _auraT += dt;
    if (_prevPos != null && dt > 0) {
      recentVelocity = recentVelocity * 0.85 + (position - _prevPos!) / dt * 0.15;
    }
    _prevPos = position.clone();

    // --- 무적 타이머 ---
    // 깜빡임은 무적이 끝날 때까지 계속된다. 캐릭터마다 무적 시간이 다르므로
    // (1.0s ~ 2.5s) 고정 횟수로 끊으면 "아직 무적인지" 알 수 없게 된다.
    if (_isInvincible) {
      _invincibleTimer += dt;

      // 종료 직전 0.4초는 깜빡임을 빠르게 해 곧 풀린다는 신호를 준다
      final remaining = _invincibleDuration - _invincibleTimer;
      final blinkInterval = remaining <= 0.4 ? 0.05 : 0.12;

      _blinkTimer += dt;
      if (_blinkTimer >= blinkInterval) {
        _blinkTimer = 0;
        _blinkVisible = !_blinkVisible;
      }

      if (_invincibleTimer >= _invincibleDuration) {
        _isInvincible = false;
        _invincibleTimer = 0;
        _invincibleDuration = _iframeDuration; // 연장분 초기화
        _isBlinking = false;
        _blinkVisible = true;
      }
    }

    // --- 에너지 자동 회복 (캐릭터별 cooldown) ---
    if (_maxShields > 0 && _shieldCooldown > 0 && _energy < _maxShields) {
      _energy += dt / _shieldCooldown;
      if (_energy > _maxShields) _energy = _maxShields.toDouble();
    }

    // --- 에너지 HUD 업데이트 ---
    _notifyEnergy();

    // --- 근접 회피 ---
    if (!keeperMode && !_isInvincible && !game.isGameOver) _updateGraze();

    // Check if moving
    Vector2 rawDrag = game.consumeDragDelta();
    // 최종 이동량 = 손가락 이동 × 캐릭터 속도 × 유저 감도 설정
    // 이동량 = 드래그 × 속도(캐릭터 기본 + 장비 능력치). 조작 감도 설정은 2026-09-22 제거 — 속도 능력치로 대신한다
    Vector2 dragInput = rawDrag * _speedMult;
    bool isMoving = !rawDrag.isZero();
    _moving = isMoving || recentVelocity.length2 > 400;

    // 표정·납작함이 돌아온다. 몸은 도는 대신 가는 쪽으로 살짝 기운다
    if (_faceTimer > 0) {
      _faceTimer -= dt;
      if (_faceTimer <= 0) _face = ZonberFace.normal;
    }
    _squash = max(0, _squash - dt * 5);
    angle = (recentVelocity.x * 0.0009).clamp(-0.22, 0.22);

    // --- 아이들 연기 (항상, 캐릭터 뒤편 perimeter에서 사방으로 뿜음) ---
    if (_rng.nextDouble() < 0.12) {
      final idleAngle = _rng.nextDouble() * 2 * pi;
      final edgeRadius = 10.0 + _rng.nextDouble() * 4.0;
      final spawnPos = position + Vector2(cos(idleAngle) * edgeRadius, sin(idleAngle) * edgeRadius);
      final burstSpeed = 45.0 + _rng.nextDouble() * 65.0;
      game.mapArea.add(
        ParticleSystemComponent(
          priority: 0,
          particle: AcceleratedParticle(
            lifespan: 0.6 + _rng.nextDouble() * 0.5,
            position: spawnPos,
            speed: Vector2(cos(idleAngle) * burstSpeed, sin(idleAngle) * burstSpeed),
            child: ComputedParticle(
              renderer: (canvas, particle) {
                final sz = 6.0 * (1.0 - particle.progress);
                canvas.drawCircle(
                  Offset.zero,
                  sz / 2,
                  _smokePaint..color = trailColor.withValues(alpha: (1.0 - particle.progress) * 0.6),
                );
              },
            ),
          ),
        ),
      );
    }

    // --- MOVEMENT LOGIC ---
    if (isMoving) {
      // 이동 트레일 (적당히 — 뒤쪽에서 뿜음)
      // 꾸미기 잔상은 조금 더 촘촘하게 — 산 티가 나도록
      if (_rng.nextDouble() < (trailId == Cosmetics.defaultTrail ? 0.28 : 0.45)) {
        // 이동 방향의 반대(뒤쪽)에 편향된 각도
        final backAngle = atan2(-rawDrag.y, -rawDrag.x) + (_rng.nextDouble() - 0.5) * pi;
        final trailSpeed = 20.0 + _rng.nextDouble() * 30.0;
        final spawnOffset = Vector2(cos(backAngle) * 8, sin(backAngle) * 8);
        final seed = _rng.nextDouble();
        final style = trailId;
        game.mapArea.add(
          ParticleSystemComponent(
            priority: 0,
            particle: AcceleratedParticle(
              lifespan: 0.35 + _rng.nextDouble() * 0.25,
              position: position + spawnOffset,
              speed: Vector2(cos(backAngle) * trailSpeed, sin(backAngle) * trailSpeed),
              child: ComputedParticle(
                // 착용한 잔상 모양으로(상점 꾸미기). 기본은 캐릭터 색 점
                renderer: (canvas, particle) =>
                    paintTrailParticle(canvas, style, particle.progress, seed, trailColor),
              ),
            ),
          ),
        );
      }

      // Player has anchor=Anchor.center, so position = center of the sprite.
      // Clamp so the hitbox (centered at position, half=12.5) stays within map.

      // 1. Move X
      position.x = (position.x + dragInput.x).clamp(_hbHalf, ZonberGame.mapWidth  - _hbHalf);

      // 2. Move Y
      position.y = (position.y + dragInput.y).clamp(_hbHalf, ZonberGame.mapHeight - _hbHalf);

      // 피구 등: 이동 영역(우리 편 진영) 안으로
      final pa = game.worldConfig.playArea;
      if (pa != null) {
        position.x = position.x.clamp(pa.left + _hbHalf, pa.right - _hbHalf);
        position.y = position.y.clamp(pa.top + _hbHalf, pa.bottom - _hbHalf);
      }

    }
  }

  /// 추가 기록을 센 순간 — 금빛 반짝임 · 가벼운 진동(보너스 코인이 쌓인다는 신호)
  void _statSpark() {
    game.burst(position.clone(), const Color(0xFFFFD23F), count: 7, speed: 110, size: 2.2);
    AudioManager().playSfx(Sfx.graze, volume: 0.45, minGapMs: 90);
    Haptics.tick();
  }

  // 골키퍼 연속 선방 — 직전 세이브 후 이 시간(초) 안에 또 막으면 1 센다
  static const double _streakWindow = Balance.saveStreakWindow;
  double _lastSaveAt = -100;

  /// Keeper: 키퍼에 맞은 공이 골문을 벗어났다 — 세이브 확정
  void creditSave(Vector2 at) {
    if (game.isGameOver) return;
    final now = game.survivalTime;
    if (now - _lastSaveAt <= _streakWindow) {
      grazeCount++;
      game.grazeNotifier.value = grazeCount;
      _statSpark();
    }
    _lastSaveAt = now;
    game.fxSave(at);
    showFace(ZonberFace.happy, 0.7);
    AudioManager().playSfx(Sfx.save, volume: 0.8);
    Haptics.light();
  }

  /// Keeper: 골을 허용했다 — 목숨 1 소모. 0이면 게임 오버.
  void concedeGoal() {
    if (game.isGameOver || game.storeShot) return;
    showFace(ZonberFace.hurt, 0.9, squash: true);
    _energy = (_energy - 1.0).clamp(0.0, _maxShields.toDouble());
    _notifyEnergy();
    AudioManager().playSfx(Sfx.goal, volume: 0.8);
    Haptics.heavy();
    if (_energy <= 0 && !game.debugNoGameOver) game.gameOver();
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (other is Bullet) {
      if (keeperMode) {
        // 막기 — 키퍼에 닿으면 공이 몸에서 튕긴다. 정면으로 맞으면 크게 꺾이고, 살짝 스치면 방향만 조금 바뀐다.
        // 세이브는 여기서 정하지 않는다 — 꺾이고도 골문으로 들어가면 골이다(Bullet._keeperUpdate 가 판정).
        if (other.deflected || other.scored || other.keeperCd > 0) return;
        final n = other.position - position;
        other.keeperTouch(n.length2 == 0 ? -other.velocity : n);
        other.position = position + (n.length2 == 0 ? Vector2(0, -1) : n.normalized()) * (_hbHalf + other.def.radius + 2);
        game.burst(other.position.clone(), Colors.white, count: 6, speed: 120, size: 2);
        AudioManager().playSfx(Sfx.save, volume: 0.35, minGapMs: 60);
        Haptics.tick();
        return;
      }
      if (game.storeShot) return; // 스토어 스크린샷 — 공이 지나간다
      if (_isInvincible) {
        // 무적 중 — 총알만 제거
        other.removeFromParent();
        return;
      }
      if (game.debugNoGameOver && _energy < 1.0) _energy = 1.0;
      if (_energy >= 1.0) {
        // 에너지 1 소모 → 캐릭터별 무적 시간 부여
        _energy -= 1.0;
        _invincibleDuration = _iframeDuration;
        _invincibleTimer = 0;
        _isInvincible = true;
        _isBlinking = true;
        _blinkTimer = 0;
        _blinkVisible = false;
        _notifyEnergy();
        showFace(ZonberFace.hurt, 0.8, squash: true);
        game.fxHit(other.position.clone(), other.def.color);
        other.removeFromParent();
        AudioManager().playSfx(Sfx.hit);
        Haptics.heavy();
        return;
      }
      // 에너지 부족 — 게임 오버 (마지막 한 방도 번쩍임·파편)
      showFace(ZonberFace.hurt, 5, squash: true);
      game.fxHit(other.position.clone(), other.def.color);
      game.gameOver();
      Haptics.gameOver();
      removeFromParent();
    }
  }

}
