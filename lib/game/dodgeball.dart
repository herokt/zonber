part of '../main.dart';

// 피구 투구 — 상대 코트에서 한 턴에 한 번 (main.dart 에서 나눔 · 2026-09-22)

// ─────────────────────────────────────────────────────────────
// 피구 투구 — 상대 코트(위쪽)에서 캐릭터를 향해 **한 턴에 한 번** 던진다.
// docs/STAGES.md §2. 사방 스폰(갤럭시)과 달리 방향이 하나라 "무엇이 오나"를 읽는 게임.
//
// 턴 간격·공 속도·패턴 단계는 모두 레벨(15초마다 1, 최고 15)로 정한다 — lib/balance.dart (2026-09-26).
//   단계  시작 레벨(시각)
//   0  워밍업   L1 (0s)     한 개씩 천천히
//   1  분열     L2 (15s)    한 개 + 가끔 날아오다 3개로 갈라지는 공
//   2  분열+   L4 (45s)    분열 3 비중 ↑ (세로로 줄지어 오는 일렬 투구는 없다)
//   3  벽       L6 (75s)    가로 한 줄 3개(나란히 평행 비행) 추가
//   4  압박     L8 (105s)   분열 5 · 가로 4 · 빠른 공(주황)
//   5  연타     L10 (135s)  두 곳에서 동시 투구 25%, 가로 5
//   6  극악     L13 (180s)  예측 조준(가는 방향 0.25초 앞) + 동시 투구 40%. 최고 레벨 L15(210s)에서 멈춘다
// ⚠️ 수치를 바꾸면 피구 리더보드 기록의 의미가 달라진다(시즌 리셋 검토).
// ─────────────────────────────────────────────────────────────
enum _Throw { single, fastSingle, split3, split5, row3, row4, row5 }

class _DodgeballThrower {
  final Random _rng = Random();
  double _sinceThrow = 0;
  /// 첫 투구는 조금 기다렸다가 — 시작하자마자 맞지 않게
  double _nextBeat = 1.2;

  // 외야 패스 — 5~10초마다. 패스 도는 동안은 일반 투구를 쉰다.
  _PassBall? _pass;
  double _sincePass = 0;
  double _nextPass = 7;

  /// 패턴 단계(0~6) — 레벨로 정한다(Balance.tierLevels)
  static int tierAt(double t) => Balance.tierOf(Balance.levelAt(t));

  static const Map<int, Map<_Throw, int>> _weights = {
    0: {_Throw.single: 1},
    1: {_Throw.single: 7, _Throw.split3: 3},
    2: {_Throw.single: 4, _Throw.split3: 6},
    3: {_Throw.single: 2, _Throw.split3: 4, _Throw.row3: 4},
    4: {_Throw.fastSingle: 3, _Throw.split3: 2, _Throw.split5: 3, _Throw.row4: 2},
    5: {_Throw.fastSingle: 3, _Throw.split5: 3, _Throw.row4: 2, _Throw.row5: 2},
    6: {_Throw.fastSingle: 3, _Throw.split5: 3, _Throw.row5: 4},
  };

  _Throw _pick(int tier) {
    final w = _weights[tier]!;
    int roll = _rng.nextInt(w.values.reduce((a, b) => a + b));
    for (final e in w.entries) {
      roll -= e.value;
      if (roll < 0) return e.key;
    }
    return _Throw.single;
  }

  void update(double dt, ZonberGame game) {
    // 외야 패스 진행 중 — 끝날 때까지 일반 투구 쉼
    if (_pass != null) {
      if (_pass!.finished) {
        _pass = null;
        _sincePass = 0;
        _nextPass = 5 + _rng.nextDouble() * 5;
        _sinceThrow = 0;
        _nextBeat = 0.9;
      }
      return;
    }
    _sincePass += dt;
    if (_sincePass >= _nextPass && game.survivalTime >= 5 && !game.isGameOver) {
      _startPass(game);
      return;
    }
    _sinceThrow += dt;
    if (_sinceThrow < _nextBeat) return;
    _sinceThrow = 0;
    final level = Balance.levelAt(game.survivalTime);
    _nextBeat = Balance.dodgeBeat(level) / (Balance.lateGrowth(game.survivalTime) * game.spawnScale);
    final tier = Balance.tierOf(level);
    _throw(game, _pick(tier), tier, level);
    // 5단계부터 가끔 다른 자리에서 한 번 더 (동시 투구) — 조금 늦게 던져 두 공이 한 덩어리로 오지 않게
    if (_rng.nextDouble() < Balance.dodgeTwin[tier]) {
      final second = _pick(tier - 2);
      game.mapArea.add(TimerComponent(
        period: Balance.dodgeTwinDelay,
        removeOnFinish: true,
        onTick: () => _throw(game, second, tier, level),
      ));
    }
  }

  /// 외야 패스: 우리 코트 주위(좌·우 외야, 내 뒤)를 1~5번(무작위) 돌다가(초록 공) 빠른 공으로 던진다
  void _startPass(ZonberGame game) {
    final world = game.worldConfig;
    // 우리 코트 주위 외야 선수들(왼쪽·오른쪽·내 뒤) 사이로 1~5번(무작위) 돈다. 선수가 움직여도 따라간다.
    final outs = game.dodgeTeam.outfield;
    if (outs.isEmpty) return;
    final hops = Balance.passHopsMin + _rng.nextInt(Balance.passHopsMax - Balance.passHopsMin + 1);
    final pts = <Vector2>[];
    int last = -1;
    for (int k = 0; k <= hops; k++) {
      int s;
      do {
        s = _rng.nextInt(outs.length);
      } while (s == last && outs.length > 1);
      last = s;
      pts.add(outs[s]); // 같은 Vector2 객체 — 선수가 움직이면 패스 목표도 움직인다
    }
    final def = world.projectiles.length > 1 ? world.projectiles[1] : world.projectiles.first;
    final shot = min(700.0, max(380.0, Balance.dodgeSpeed(Balance.levelAt(game.survivalTime)) * 1.7));
    _pass = _PassBall(points: pts, def: def, shotSpeed: shot);
    game.mapArea.add(_pass!);
  }

  void _throw(ZonberGame game, _Throw kind, int tier, int level) {
    if (game.isGameOver || !game.player.isMounted) return;
    final world = game.worldConfig;
    final ball = world.projectiles.first;
    final fast = world.projectiles.length > 1 ? world.projectiles[1] : ball;

    AudioManager().playSfx(Sfx.throwBall, volume: 0.5, minGapMs: 60);
    // 상대 선수 한 명이 던진다(던지는 순간 커진다) — 선수가 없으면 무대 위쪽 바깥
    final team = game.dodgeTeam;
    final Vector2 origin;
    if (team.infield.isNotEmpty) {
      final i = _rng.nextInt(team.infield.length);
      team.flash[i] = 1;
      origin = team.infield[i] + Vector2(0, 12);
    } else {
      origin = Vector2(60 + _rng.nextDouble() * (ZonberGame.mapWidth - 120), -30);
    }
    Vector2 target = game.player.position.clone();
    // 극악: 캐릭터가 움직이는 방향 앞을 노린다
    if (tier >= 6) target += game.player.recentVelocity * Balance.dodgeLead;
    final dir = (target - origin).normalized();
    final perp = Vector2(-dir.y, dir.x);
    // 코트가 길어진 만큼 빠르게 — 공이 오는 시간은 예전 코트와 같다(Balance.dodgeThrowScale)
    final speed = Balance.dodgeSpeed(level) * Balance.dodgeThrowScale * Balance.lateGrowth(game.survivalTime);

    void add(Vector2 from, ProjectileDef def, double v, {int splitInto = 0}) {
      final b = Bullet(from, from + dir * 100, speed: v * def.speedMult, def: def);
      if (splitInto > 0) {
        // 캐릭터까지 거리의 40% 지점에서 갈라진다
        b.splitAfter = (target - from).length * 0.4 / (v * def.speedMult);
        b.splitInto = splitInto;
      }
      game.mapArea.add(b);
    }

    switch (kind) {
      case _Throw.single:
        add(origin, ball, speed);
        break;
      case _Throw.fastSingle:
        add(origin, fast, speed);
        break;
      case _Throw.split3:
        add(origin, ball, speed, splitInto: 3);
        break;
      case _Throw.split5:
        add(origin, ball, speed, splitInto: 5);
        break;
      case _Throw.row3:
      case _Throw.row4:
      case _Throw.row5:
        // 가로 한 줄로 오되 대형을 매번 조금씩 바꾼다(2026-10-12 — 예전엔 나란한 벽이 한꺼번에 와 4·5개가 뭉쳐 보였다).
        // 왼쪽부터 · 오른쪽부터 · 가운데 먼저(V) · 양 끝 먼저(Λ) 중 하나로 공마다 조금씩 늦게 던지고, 속도도 조금씩 다르게
        final n = kind == _Throw.row3 ? 3 : kind == _Throw.row4 ? 4 : 5;
        const gap = 28.0;
        final shape = _rng.nextInt(4);
        for (int i = 0; i < n; i++) {
          final c = i - (n - 1) / 2;
          final order = switch (shape) {
            0 => i.toDouble(),
            1 => (n - 1 - i).toDouble(),
            2 => c.abs(),
            _ => (n - 1) / 2 - c.abs(),
          };
          final off = perp * (c * gap);
          final from = origin + off;
          final v = speed * ball.speedMult * (1 + (_rng.nextDouble() * 2 - 1) * Balance.dodgeRowSpeedJitter);
          // 캐릭터 위치 + 대형 폭의 절반만큼만 벌려 조준 → 도착할 때 대형이 좁아진다
          final aim = target + off * 0.5;
          final delay = order * Balance.dodgeRowStagger;
          if (delay <= 0) {
            game.mapArea.add(Bullet(from, aim, speed: v, def: ball));
          } else {
            game.mapArea.add(TimerComponent(
              period: delay,
              removeOnFinish: true,
              onTick: () {
                if (!game.isGameOver) game.mapArea.add(Bullet(from, aim, speed: v, def: ball));
              },
            ));
          }
        }
        break;
    }
  }
}
