part of '../main.dart';

// 골키퍼 — 골문·슈터·슛 종류·골대 그리기 (main.dart 에서 나눔 · 2026-09-22)

// ─────────────────────────────────────────────────────────────
// 골키퍼 — 페널티킥형 (2026-09-21 개편, 같은 날 페널티 에어리어 확대·슛 종류 추가). docs/STAGES.md §3.
// 화면 아래 가로 골문. 키퍼는 페널티 에어리어(= 나의 존) 안에서 움직인다.
// 페널티 에어리어 바로 바깥의 슈터(상대 선수)들이 차는 공이 골문 안으로 들어오면 실점, 포스트에 맞으면 튕기고,
// 골문 밖으로 가면 빗나감. 키퍼에 닿으면 튕겨 낸다(세이브). 5골이면 게임 오버.
//
//   단계  시간      슈터  새로 나오는 슛
//   0     ~15s     1명   직선
//   1     ~30s     2명   + 강슛(노랑)
//   2     ~50s     3명   + 감아차기(하늘색, 휘어 들어옴)
//   3     ~70s     3명   + 꼬불꼬불 슛(분홍) · 두 명 동시
//   4     ~95s     4명   + 총알슛(주황, 꼬리) · 슈터 좌우 이동
//   5     ~125s    5명   + 무회전(보라, 어디로 흔들릴지 모름) · 세 명 동시
//   6     125s~    6명   극악: 특수 슛 위주, 키퍼 반대쪽을 노리는 비율 85%
// ⚠️ 수치를 바꾸면 골키퍼 리더보드 기록의 의미가 달라진다(시즌 리셋 검토).
// ─────────────────────────────────────────────────────────────
class KeeperGoal {
  /// 골문 좌우 포스트 x, 골라인 y, 그물 깊이 (무대 좌표 480×768)
  static const double left = 110, right = 370, lineY = 720, depth = 34;
  static const double postRadius = 7;
  /// 키퍼 시작 줄(골라인 앞)
  static const double keeperY = 690;
  /// 페널티 에어리어 = 키퍼 이동 영역 = 나의 존 (world_config 의 keeper playArea 와 같은 값).
  /// 실제 비율(깊이 16.5m · 페널티 마크 11m · 아크 9.15m · 골 에어리어 5.5m)에 맞춰 선을 긋는다.
  static const Rect penaltyBox = Rect.fromLTRB(12, 420, 468, 720);
  static const Rect goalArea = Rect.fromLTRB(70, 620, 410, 720);
  static const Offset penaltySpot = Offset(240, 520);
  static const double arcRadius = 166;

  static const List<int> _shooterCount = [1, 2, 3, 3, 4, 5, 6];

  final Random _rng = Random();
  /// 슈터 위치 · 차는 순간 커지는 연출(1→0) · 좌우 이동 속도
  final List<Vector2> shooters = [];
  final List<double> kickFlash = [];
  final List<double> _drift = [];
  final List<double> _appear = [];

  static int tierAt(double t) {
    if (t < 15) return 0;
    if (t < 30) return 1;
    if (t < 50) return 2;
    if (t < 70) return 3;
    if (t < 95) return 4;
    if (t < 125) return 5;
    return 6;
  }

  Vector2 postPos(bool leftPost) => Vector2(leftPost ? left : right, lineY);

  /// 등장 연출 0→1
  double appear(int i) => _appear[i].clamp(0.0, 1.0);

  void update(double dt, double t) {
    final tier = tierAt(t);
    while (shooters.length < _shooterCount[tier]) {
      _addShooter();
    }
    for (int i = 0; i < shooters.length; i++) {
      kickFlash[i] = max(0, kickFlash[i] - dt * 4);
      _appear[i] += dt * 3;
      if (tier >= 4) {
        // 좌우로 움직인다 — 차는 각도가 계속 바뀐다
        shooters[i].x += _drift[i] * dt;
        if (shooters[i].x < 40 || shooters[i].x > 440) _drift[i] = -_drift[i];
        shooters[i].x = shooters[i].x.clamp(40.0, 440.0);
      }
    }
  }

  void _addShooter() {
    // 페널티 에어리어 바로 바깥(아크 주변), 다른 슈터와 너무 붙지 않는 자리
    Vector2 p = Vector2(240, 360);
    for (int tries = 0; tries < 20; tries++) {
      // 세로는 경기장 위쪽까지(110~395) — 2026-09-24 무대 전체를 경기장으로 쓰면서 넓혔다(예전 280~395).
      // 멀어진 만큼 슛 속도를 올려 골라인까지 걸리는 시간은 같다(Balance.keeperShotScale)
      p = Vector2(50 + _rng.nextDouble() * 380, 110 + _rng.nextDouble() * 285);
      if (shooters.every((s) => s.distanceTo(p) > 80)) break;
    }
    if (shooters.isEmpty) p = Vector2(240, 360); // 첫 슈터는 정면, 아크 바로 위
    shooters.add(p);
    kickFlash.add(0);
    _appear.add(0);
    _drift.add((_rng.nextBool() ? 1 : -1) * (35 + _rng.nextDouble() * 35));
  }
}

/// 슛 종류 — 월드의 projectiles 순서와 같다(0 직선 · 1 강슛 · 2 감아차기 · 3 꼬불꼬불 · 4 총알슛 · 5 무회전)
enum _Kick { straight, power, curl, wave, rocket, knuckle }

class _KeeperShooter {
  final Random _rng = Random();
  double _since = 0;
  double _nextBeat = 1.4;

  /// 턴 간격: 2.0s 에서 1초에 1%씩 짧아지고 0.55s 하한
  static double beatAt(double t) => Balance.keeperBeatAt(t);

  /// 슛 속도: 200 → 초당 +2.2, 상한 480 (총알슛은 여기에 1.6배). 2026-09-22 꼬불꼬불 슛 구간부터 너무 빨라 조금 낮춤
  static double speedAt(double t) => Balance.keeperSpeedAt(t);

  /// 공이 골라인에 닿는 시각(예상)들 — 여러 공이 한꺼번에 도착하지 않게 이 간격 이상 벌린다(간발의 차는 허용)
  final List<double> _arrivals = [];
  static const double _arrivalGap = Balance.keeperArrivalGap;

  /// 키퍼 반대쪽을 노리는 비율
  static const List<double> _smart = [0.2, 0.35, 0.5, 0.6, 0.7, 0.8, 0.85];

  /// 단계별 슛 비중
  static const Map<int, Map<_Kick, int>> _weights = {
    0: {_Kick.straight: 1},
    1: {_Kick.straight: 6, _Kick.power: 3},
    2: {_Kick.straight: 3, _Kick.power: 3, _Kick.curl: 4},
    3: {_Kick.straight: 1, _Kick.power: 2, _Kick.curl: 3, _Kick.wave: 4},
    4: {_Kick.power: 2, _Kick.curl: 3, _Kick.wave: 3, _Kick.rocket: 3},
    5: {_Kick.power: 1, _Kick.curl: 3, _Kick.wave: 2, _Kick.rocket: 3, _Kick.knuckle: 4},
    6: {_Kick.curl: 3, _Kick.wave: 3, _Kick.rocket: 4, _Kick.knuckle: 4},
  };

  /// 여러 명이 동시에 찰 확률(두 명 · 세 명)
  static const List<double> _twin = [0, 0, 0, 0.3, 0.3, 0.3, 0.35];
  static const List<double> _trio = [0, 0, 0, 0, 0.1, 0.2, 0.3];

  _Kick _pick(int tier) {
    final w = _weights[tier]!;
    int roll = _rng.nextInt(w.values.reduce((a, b) => a + b));
    for (final e in w.entries) {
      roll -= e.value;
      if (roll < 0) return e.key;
    }
    return _Kick.straight;
  }

  void update(double dt, ZonberGame game) {
    _since += dt;
    if (_since < _nextBeat) return;
    _since = 0;
    final t = game.survivalTime;
    _nextBeat = beatAt(t);
    final goal = game.goal;
    if (goal.shooters.isEmpty || game.isGameOver || !game.player.isMounted) return;
    final tier = KeeperGoal.tierAt(t);
    final order = List<int>.generate(goal.shooters.length, (i) => i)..shuffle(_rng);
    final roll = _rng.nextDouble();
    final n = roll < _trio[tier] ? 3 : roll < _trio[tier] + _twin[tier] ? 2 : 1;
    _arrivals.removeWhere((a) => a < t - 0.5);
    final world = game.worldConfig;
    final center = Vector2((KeeperGoal.left + KeeperGoal.right) / 2, KeeperGoal.lineY);
    for (int k = 0; k < min(n, order.length); k++) {
      final si = order[k];
      final kind = _pick(tier);
      final def = world.projectiles[min(kind.index, world.projectiles.length - 1)];
      // 골라인까지 걸리는 시간(휘는 공은 조금 더) — 이미 날아오는 공과 도착이 겹치면 늦게 찬다
      final fly = goal.shooters[si].distanceTo(center) / (speedAt(t) * def.speedMult) * (def.motion == ProjectileMotion.straight ? 1.0 : 1.08);
      var arrive = t + k * 0.12 + fly;
      // 밀 때는 반드시 늦어지는 쪽으로만 민다. (예전엔 `(a + gap) - a` 가 부동소수점 반올림으로
      // gap 보다 아주 조금 작게 나오면 같은 자리로 계속 다시 밀어 무한 루프 → 두 명 동시 슛(50초~)에서 앱이 굳었다)
      for (bool moved = true; moved;) {
        moved = false;
        for (final a in _arrivals) {
          final pushed = a + _arrivalGap;
          if ((a - arrive).abs() < _arrivalGap && pushed > arrive) {
            arrive = pushed;
            moved = true;
          }
        }
      }
      // 1.2초 넘게 밀리는 슛은 건너뛴다. 극악(턴 0.55초·동시 슛)은 평균 1.95발 × 간격 0.3초 = 0.585초로 턴보다 길어서,
      // 밀린 예약 슛(TimerComponent)이 판 길이만큼 끝없이 쌓였다(390초에 67개 — 슛이 20초 뒤에 나감).
      // 오래 보면 초당 슛 수는 어차피 간격 0.3초가 상한이라 난이도는 거의 같다.
      if (arrive - fly - t - k * 0.12 > 1.2) continue;
      _arrivals.add(arrive);
      _kick(game, si, kind, t, tier, delay: arrive - fly - t);
    }
  }

  /// 골문 안 목표 x — 가끔 포스트, 단계가 오를수록 키퍼 반대쪽
  double _targetX(ZonberGame game, int tier) {
    const l = KeeperGoal.left + 14, r = KeeperGoal.right - 14;
    final roll = _rng.nextDouble();
    if (roll < 0.07) return _rng.nextBool() ? KeeperGoal.left + 2 : KeeperGoal.right - 2; // 포스트 맞기
    if (roll < 0.07 + _smart[tier]) {
      final kx = game.player.position.x;
      final leftSpan = (kx - 40) - l;
      final rightSpan = r - (kx + 40);
      if (leftSpan <= 0 && rightSpan <= 0) return l + _rng.nextDouble() * (r - l);
      final goLeft = rightSpan <= 0 || (leftSpan > 0 && _rng.nextDouble() < leftSpan / (leftSpan + rightSpan));
      return goLeft ? l + _rng.nextDouble() * leftSpan : (kx + 40) + _rng.nextDouble() * rightSpan;
    }
    return l + _rng.nextDouble() * (r - l);
  }

  /// 슈터 [si] 가 [kind] 슛을 찬다
  void _kick(ZonberGame game, int si, _Kick kind, double t, int tier, {double delay = 0}) {
    if (delay > 0) {
      game.mapArea.add(TimerComponent(
        period: delay,
        removeOnFinish: true,
        onTick: () {
          if (!game.isGameOver) _kick(game, si, kind, t, tier);
        },
      ));
      return;
    }
    final goal = game.goal;
    if (si >= goal.shooters.length) return;
    final world = game.worldConfig;
    final def = world.projectiles[min(kind.index, world.projectiles.length - 1)];
    final origin = goal.shooters[si] + Vector2(0, 14);
    final target = Vector2(_targetX(game, tier), KeeperGoal.lineY + KeeperGoal.depth * 0.5);
    final speed = speedAt(t) * def.speedMult;
    goal.kickFlash[si] = 1;
    final dir = (target - origin).normalized();
    final perp = Vector2(-dir.y, dir.x);
    final tt = target.distanceTo(origin) / speed;
    final sign = _rng.nextBool() ? 1.0 : -1.0;
    switch (def.motion) {
      case ProjectileMotion.curve:
        // 감아차기 — 휘는 만큼 반대쪽을 겨눠 차서 결국 목표로 휘어 들어오게 (d ≈ ½·a·T²)
        final d = 0.5 * def.lateralAccel * tt * tt;
        game.mapArea.add(Bullet(origin, target - perp * (sign * d), speed: speed, def: def, curveSign: sign));
        break;
      case ProjectileMotion.wave:
        // 꼬불꼬불 — 도착 순간의 옆 위치(A·sin ωT)만큼 반대로 겨눈다
        final d = def.waveAmp * sin(2 * pi * def.waveHz * tt);
        game.mapArea.add(Bullet(origin, target - perp * (sign * d), speed: speed, def: def, curveSign: sign));
        break;
      default:
        // 직선·강슛·총알슛·무회전(무회전은 흔들림이 매번 달라 보정하지 않는다)
        game.mapArea.add(Bullet(origin, target, speed: speed, def: def));
    }
    AudioManager().playSfx(Sfx.kick, volume: kind == _Kick.rocket ? 0.8 : 0.55, minGapMs: 50);
  }
}

/// 골문·페널티 에어리어·슈터 그리기 + 골대 상태 갱신
class GoalZone extends Component with HasGameReference<ZonberGame> {
  @override
  void update(double dt) {
    if (!game.isGameOver) game.goal.update(dt, game.survivalTime);
  }

  /// 움직이지 않는 그림(박스·그물·골대) — 한 번 기록해 두고 매 프레임 그대로 찍는다.
  /// (그물 선 80여 개를 매 프레임 새 Paint 로 다시 긋던 것을 줄였다)
  ui.Picture? _static;

  @override
  void onRemove() {
    _static?.dispose();
    _static = null;
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    final pic = _static ??= () {
      final rec = ui.PictureRecorder();
      _renderStatic(Canvas(rec));
      return rec.endRecording();
    }();
    canvas.drawPicture(pic);
    _renderShooters(canvas);
  }

  void _renderStatic(Canvas canvas) {
    final goal = game.goal;
    const l = KeeperGoal.left, r = KeeperGoal.right, y = KeeperGoal.lineY, d = KeeperGoal.depth;
    const box = KeeperGoal.penaltyBox;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // 페널티 에어리어 안쪽을 살짝 밝게 — 여기가 나의 존
    canvas.drawRect(box, Paint()..color = Colors.white.withValues(alpha: 0.06));
    // 페널티 에어리어 · 골 에어리어 · 페널티 마크 · 페널티 아크(박스 바깥 부분만)
    canvas.drawRect(box, line);
    canvas.drawRect(KeeperGoal.goalArea, line);
    canvas.drawCircle(KeeperGoal.penaltySpot, 4, Paint()..color = Colors.white.withValues(alpha: 0.85));
    const sp = KeeperGoal.penaltySpot;
    const ar = KeeperGoal.arcRadius;
    final half = acos((sp.dy - box.top) / ar); // 박스 윗변과 만나는 각
    canvas.drawArc(Rect.fromCircle(center: sp, radius: ar), -pi / 2 - half, half * 2, false, line);

    // 그물 — 골라인 뒤
    final netRect = Rect.fromLTRB(l, y, r, y + d);
    canvas.drawRect(netRect, Paint()..color = Colors.white.withValues(alpha: 0.28));
    final net = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (double x = l; x <= r; x += 10) {
      canvas.drawLine(Offset(x, y), Offset(x, y + d), net);
    }
    for (double yy = y; yy <= y + d; yy += 8) {
      canvas.drawLine(Offset(l, yy), Offset(r, yy), net);
    }
    final frame = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(netRect, frame);
    // 골라인 — 무대 끝까지
    canvas.drawLine(const Offset(0, y), const Offset(ZonberGame.mapWidth, y), Paint()
      ..color = Colors.white
      ..strokeWidth = 3);

    // 골포스트 2개
    for (final pl in [true, false]) {
      final p = goal.postPos(pl);
      final pc = Offset(p.x, p.y);
      canvas.drawCircle(pc + const Offset(1, 2), KeeperGoal.postRadius, Paint()..color = Colors.black.withValues(alpha: 0.25));
      canvas.drawCircle(pc, KeeperGoal.postRadius, Paint()..color = Colors.white);
      canvas.drawCircle(pc, KeeperGoal.postRadius, Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
  }

  static final Paint _fill = Paint();
  static final Paint _rim = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;

  /// 슈터(상대 선수) — 빨간 유니폼 점. 차는 순간 커진다.
  void _renderShooters(Canvas canvas) {
    final goal = game.goal;
    for (int i = 0; i < goal.shooters.length; i++) {
      final s = goal.shooters[i];
      final a = goal.appear(i);
      final scale = a * (1 + 0.35 * goal.kickFlash[i]);
      if (scale <= 0) continue;
      final c = Offset(s.x, s.y);
      canvas.drawCircle(c + const Offset(1, 2), 13 * scale, _fill..color = Colors.black.withValues(alpha: 0.2));
      canvas.drawCircle(c, 13 * scale, _fill..color = const Color(0xFFE5484D));
      canvas.drawCircle(c, 13 * scale, _rim);
      canvas.drawCircle(c + Offset(0, -2 * scale), 5 * scale, _fill..color = const Color(0xFFFFE0C2)); // 머리
    }
  }
}
