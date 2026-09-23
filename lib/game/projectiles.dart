part of '../main.dart';

// 투사체 — 피구공·축구공 그림, 팀(외야)·존 연출, 패스 공, Bullet, BulletSpawner (main.dart 에서 나눔 · 2026-09-22)

// 공 그림에 쓰는 붓 — 공은 수십~백 개가 매 프레임 그려지므로 Paint 를 새로 만들지 않고 돌려 쓴다
final Paint _ballFill = Paint();
final Paint _ballStroke = Paint()..style = PaintingStyle.stroke;

/// 공 모양으로 자른다 — 원형 RRect 자르기가 Path 자르기보다 가볍다
void _clipBall(Canvas canvas, double r) =>
    canvas.clipRRect(RRect.fromRectAndRadius(Rect.fromCircle(center: Offset.zero, radius: r), Radius.circular(r)));

/// 피구공 무늬 — 가운데를 두르는 빨간 띠 + 띠 가장자리 흰 선. [spin] 만큼 돌린다.
/// (농구공처럼 보이던 곡선 이음매 대신, 놀이터 피구공의 단순한 띠). [alpha] 는 흐려질 때 투명도
void paintDodgeBallBand(Canvas canvas, Offset c, double r, double spin, {double alpha = 1}) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(spin);
  _clipBall(canvas, r);
  final bandH = r * 0.62;
  canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 2.2, height: bandH),
      _ballFill..color = const Color(0xFFE23B3B).withValues(alpha: alpha));
  _ballStroke
    ..color = Colors.white.withValues(alpha: 0.9 * alpha)
    ..strokeWidth = max(1.0, r * 0.12);
  canvas.drawLine(Offset(-r * 1.1, -bandH / 2), Offset(r * 1.1, -bandH / 2), _ballStroke);
  canvas.drawLine(Offset(-r * 1.1, bandH / 2), Offset(r * 1.1, bandH / 2), _ballStroke);
  canvas.restore();
}

/// 피구 상대 팀 — 상대 진영 내야 선수 + 우리 코트 주위 외야 선수. 조금씩 돌아다닌다.
class DodgeTeam {
  final Random _rng = Random();
  final List<Vector2> infield = [];
  final List<Vector2> outfield = [];
  final List<double> flash = []; // 내야 선수 던질 때 커지는 연출
  final List<Vector2> _inTarget = [];
  final List<Vector2> _outTarget = [];
  final List<int> _outSide = []; // 0 왼쪽 · 1 오른쪽 · 2 내 뒤
  Rect? _court, _own;

  static const List<int> _infieldCount = [3, 3, 4, 4, 5, 5, 6];

  /// 내야 선수가 돌아다니는 곳 — 상대 진영 전체(중앙선 바로 앞 50px 은 비운다)
  Rect _oppBack(Rect c) => Rect.fromLTRB(c.left + 20, c.top + 16, c.right - 20, c.top + c.height / 2 - 50);
  final List<double> _inSpeed = [];

  Vector2 _inSpot(Rect c) {
    final r = _oppBack(c);
    return Vector2(r.left + _rng.nextDouble() * r.width, r.top + _rng.nextDouble() * r.height);
  }

  Vector2 _outSpot(int side) {
    final c = _court!, o = _own!;
    const W = ZonberGame.mapWidth;
    switch (side) {
      case 0: return Vector2(c.left / 2, o.top + 24 + _rng.nextDouble() * (o.height - 48));
      case 1: return Vector2((c.right + W) / 2, o.top + 24 + _rng.nextDouble() * (o.height - 48));
      default: return Vector2(o.left + 40 + _rng.nextDouble() * (o.width - 80), c.bottom + 30);
    }
  }

  void update(double dt, ZonberGame game) {
    final w = game.worldConfig;
    if (w.court == null) return;
    _court = w.court;
    _own = w.playArea ?? w.court;
    final tier = _DodgeballThrower.tierAt(game.survivalTime);
    while (infield.length < _infieldCount[tier]) {
      infield.add(_inSpot(_court!));
      _inTarget.add(_inSpot(_court!));
      _inSpeed.add(40 + _rng.nextDouble() * 50);
      flash.add(0);
    }
    while (outfield.length < 3) {
      final side = outfield.length;
      outfield.add(_outSpot(side));
      _outTarget.add(_outSpot(side));
      _outSide.add(side);
    }
    // 천천히 돌아다닌다
    // 자유롭게 돌아다닌다 — 목표에 닿으면 새 목표·새 속도(가끔 빠르게 뛰어간다)
    void wander(List<Vector2> ps, List<Vector2> ts, Vector2 Function(int) pick, double Function(int) speed) {
      for (int i = 0; i < ps.length; i++) {
        final d = ts[i] - ps[i];
        if (d.length < 3) {
          ts[i] = pick(i);
        } else {
          ps[i].add(d.normalized() * min(d.length, speed(i) * dt));
        }
      }
    }
    wander(infield, _inTarget, (i) {
      _inSpeed[i] = _rng.nextDouble() < 0.25 ? 120 + _rng.nextDouble() * 60 : 40 + _rng.nextDouble() * 50;
      return _inSpot(_court!);
    }, (i) => _inSpeed[i]);
    wander(outfield, _outTarget, (i) => _outSpot(_outSide[i]), (_) => 55);
    for (int i = 0; i < flash.length; i++) {
      flash[i] = max(0, flash[i] - dt * 4);
    }
  }
}

/// 피구 상대 선수 그리기 — 빨간 유니폼 점(내야) · 조금 작은 점(외야)
class DodgeTeamZone extends Component with HasGameReference<ZonberGame> {
  @override
  void update(double dt) {
    if (!game.isGameOver) game.dodgeTeam.update(dt, game);
  }

  @override
  void render(Canvas canvas) {
    final t = game.dodgeTeam;
    void player(Vector2 p, double r, {bool throwing = false}) {
      final c = Offset(p.x, p.y);
      canvas.drawCircle(c + const Offset(1, 2), r, Paint()..color = Colors.black.withValues(alpha: 0.18));
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFFE5484D));
      canvas.drawCircle(c, r, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2);
      canvas.drawCircle(c + Offset(0, -r * 0.18), r * 0.38, Paint()..color = const Color(0xFFFFE0C2));
    }
    for (int i = 0; i < t.infield.length; i++) {
      player(t.infield[i], 11 * (1 + 0.35 * t.flash[i]), throwing: t.flash[i] > 0.2);
    }
    for (final p in t.outfield) {
      player(p, 10);
    }
  }
}

/// 시작 연출 — 나의 존을 존 색으로 깜빡여 보여 준다(문구는 Flutter 오버레이)
class ZoneIntro extends Component with HasGameReference<ZonberGame> {
  @override
  void render(Canvas canvas) {
    final g = game;
    if (!g.inIntro || g.introLeft <= ZonberGame.introStart) return;
    final t = (ZonberGame.introZone + ZonberGame.introStart) - g.introLeft; // 0 → introZone
    final on = (t * 3.3).floor() % 2 == 0; // 약 3번 깜빡
    final r = g.zoneRect.deflate(2);
    final accent = g.worldConfig.accent;
    // 존 바깥은 살짝 어둡게 — 여기가 내 자리
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(const Rect.fromLTWH(0, 0, ZonberGame.mapWidth, ZonberGame.mapHeight))
      ..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)));
    canvas.drawPath(outside, Paint()..color = Colors.black.withValues(alpha: 0.28));
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)),
        Paint()..color = accent.withValues(alpha: on ? 0.30 : 0.10));
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), Paint()
      ..color = accent.withValues(alpha: on ? 1 : 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4);
  }
}

/// 축구공 무늬(반지름 1 기준) — 가운데 검은 오각형 + 가장자리 조각 5개. 한 번만 만들고 크기만 바꿔 그린다
final Path _soccerUnit = () {
  final p = Path();
  void pent(double cx, double cy, double rr, double rot) {
    for (int i = 0; i < 5; i++) {
      final a = rot + i * 2 * pi / 5 - pi / 2;
      final pt = Offset(cx + cos(a) * rr, cy + sin(a) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    p.close();
  }
  pent(0, 0, 0.36, 0);
  for (int i = 0; i < 5; i++) {
    final a = i * 2 * pi / 5 - pi / 2;
    pent(cos(a) * 0.95, sin(a) * 0.95, 0.3, pi / 5);
  }
  return p;
}();

/// 축구공 무늬 — 가운데 검은 오각형 + 가장자리 조각 5개. [spin] 만큼 돌린다. [alpha] 는 흐려질 때 투명도
void paintSoccerPatches(Canvas canvas, Offset c, double r, double spin, {double alpha = 1}) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(spin);
  _clipBall(canvas, r);
  canvas.scale(r);
  canvas.drawPath(_soccerUnit, _ballFill..color = const Color(0xFF1F2937).withValues(alpha: alpha));
  canvas.restore();
}

/// 피구 외야 패스 — 코트 바깥 띠를 따라 공을 몇 번 돌린 뒤 캐릭터를 향해 빠르게 던진다.
/// 패스 중인 공은 공중에 띄운 공이라 맞지 않는다(충돌 없음). 마지막에 진짜 공(Bullet)을 쏘고 사라진다.
class _PassBall extends PositionComponent with HasGameReference<ZonberGame> {
  final List<Vector2> points;
  final ProjectileDef def;
  final double shotSpeed;
  int _i = 0;
  double _hopT = 0;
  double _hold = 0;
  double _age = 0;
  double _lift = 0;
  bool finished = false;

  /// 패스 중 공 색
  static const Color passColor = Color(0xFF22C55E);

  _PassBall({required this.points, required this.def, required this.shotSpeed}) {
    position = points.first.clone();
    size = Vector2.all(def.visualSize);
    // 경로 좌표는 외야 선수 위치 객체 그대로(선수가 움직이면 따라간다)
    anchor = Anchor.center;
    priority = 12; // 캐릭터 위로 — 머리 위로 넘어가는 패스
  }

  @override
  void update(double dt) {
    if (finished || game.isGameOver) return;
    _age += dt;
    if (_i >= points.length - 1) {
      // 마지막 외야수 손에서 잠깐 멈췄다가 던진다
      _lift = 0;
      _hold += dt;
      if (_hold >= 0.25) _fire();
      return;
    }
    final a = points[_i], b = points[_i + 1];
    final dur = max(0.3, a.distanceTo(b) / 540);
    _hopT += dt;
    final p = (_hopT / dur).clamp(0.0, 1.0);
    position = a + (b - a) * p;
    _lift = sin(pi * p); // 포물선처럼 떴다가 받는다(크기로 표현)
    if (p >= 1) {
      _i++;
      _hopT = 0;
    }
  }

  void _fire() {
    finished = true;
    if (game.player.isMounted) {
      game.mapArea.add(Bullet(position.clone(), game.player.position.clone(), speed: shotSpeed, def: def));
      AudioManager().playSfx(Sfx.throwBall, volume: 0.75);
    }
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final r = size.x / 2;
    final c = Offset(r, r);
    final s = (_age < 0.12 ? 0.4 + 0.6 * (_age / 0.12) : 1.0) * (1 + 0.45 * _lift);
    canvas.translate(c.dx, c.dy);
    canvas.scale(s);
    canvas.translate(-c.dx, -c.dy);
    // 패스 중인 공은 초록 — 아직 날아오지 않는 공임을 표시. 던지는 순간 원래 공(주황 속공)으로 바뀐다
    canvas.drawCircle(c, r, Paint()..color = passColor);
    paintDodgeBallBand(canvas, c, r, _age * 9);
    canvas.drawCircle(c.translate(-r * 0.32, -r * 0.34), r * 0.26, Paint()..color = Colors.white.withValues(alpha: 0.55));
    canvas.drawCircle(c, r, Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
  }
}

class Bullet extends PositionComponent
    with HasGameReference<ZonberGame>, CollisionCallbacks {
  Vector2 velocity = Vector2.zero();
  final double speed;
  /// 월드 투사체 정의 — 크기·색·거동·벽 반응
  final ProjectileDef def;
  double _age = 0;
  /// curve: 휘는 방향(±1)
  final double _curveSign;
  /// 분열: 이 시간(초)이 지나면 [splitInto]개로 갈라진다. null 이면 분열 없음
  double? splitAfter;
  int splitInto = 0;

  /// 골키퍼: 막히거나(키퍼·포스트·닫힌 벽) 튕겨 나간 공 — 더는 득점·세이브 대상이 아니다
  bool deflected = false;
  double _deflectAge = 0;
  /// 골키퍼: 골망에 들어간 공 — 속도가 줄며 사라진다
  bool scored = false;

  /// wave·knuckle: 찬 방향(흔들림의 기준선)과 옆으로 움직이는 속도
  Vector2 _baseDir = Vector2(0, 1);
  static final Random _rng = Random();
  double _lat = 0, _latTarget = 0, _latOffset = 0, _knuckleT = 0;

  /// 골키퍼: 키퍼 몸에 맞은 적이 있다 — 골문을 벗어나면 세이브, 그래도 들어가면 골
  bool keeperTouched = false;
  /// 같은 접촉이 여러 번 잡히지 않게 잠깐 쉰다(초)
  double keeperCd = 0;

  /// 법선 [n] 방향 성분만 반발계수 [e] 로 되튕긴다(접선 성분은 [friction] 만큼 유지).
  /// 정면 충돌은 크게 꺾이고, 스치듯 맞으면 방향만 조금 바뀐다. 득점 대상에서 빼지 않는다.
  void reflectSoft(Vector2 n, {double e = 0.6, double friction = 0.92}) {
    final nn = n.normalized();
    final vn = velocity.dot(nn);
    if (vn >= 0) return; // 이미 멀어지는 중
    final normal = nn * vn;
    final tangent = velocity - normal;
    velocity = tangent * friction - normal * e;
    if (velocity.length < 90) velocity = velocity.normalized() * 90;
    // 거동(휘기·흔들림)은 여기서 끝 — 튕긴 뒤엔 직선으로
    _baseDir = velocity.normalized();
    _free = true;
  }

  /// 키퍼 접촉 — 반발 후 결과는 골라인에서 정한다
  void keeperTouch(Vector2 n) {
    reflectSoft(n, e: 0.65, friction: 0.9);
    keeperTouched = true;
    keeperCd = 0.25;
  }

  /// 튕긴 뒤 — 휘기·흔들림 없이 직선으로 난다
  bool _free = false;

  /// 튕긴·골망 공은 흐려지며 사라진다
  double get _fade {
    if (scored) return (1 - (_age - _deflectAge) / 0.45).clamp(0.0, 1.0);
    if (deflected) return (1 - (_age - _deflectAge - 0.7) / 0.5).clamp(0.0, 1.0);
    return 1;
  }

  Bullet(Vector2 position, Vector2 targetPosition, {this.speed = 200.0, required this.def, double? curveSign})
      : _curveSign = curveSign ?? (Random().nextBool() ? 1.0 : -1.0) {
    this.position = position;
    size = Vector2(def.visualSize, def.visualSize);
    anchor = Anchor.center;
    Vector2 direction = targetPosition - position;
    velocity = direction.normalized() * speed;
    _baseDir = velocity.normalized();
  }

  @override
  void render(Canvas canvas) {
    // 흐려지는 공은 색마다 투명도를 곱해 그린다. (예전엔 공마다 saveLayer — 막히거나 골망에 든
    // 공이 흐려지는 동안 화면 밖 버퍼를 매 프레임 만들어서 세이브·실점 순간 프레임이 떨어졌다)
    final f = _fade;
    if (f <= 0) return;
    _renderBall(canvas, f);
  }

  void _renderBall(Canvas canvas, double a) {
    final c = Offset(size.x / 2, size.y / 2);
    if (def.seams && _age < 0.12) {
      // 피구 — 상대 손에서 튀어나오듯 0.12초 동안 커지며 등장
      final s = 0.4 + 0.6 * (_age / 0.12);
      canvas.translate(c.dx, c.dy);
      canvas.scale(s);
      canvas.translate(-c.dx, -c.dy);
    }
    // 꽉 찬 공 — 몸통 · 아래쪽 음영 · 위쪽 하이라이트. 네온 링이 아니라 "공"으로 읽히게.
    final r = size.x / 2;
    if (def.trail && !deflected && !scored && velocity.length2 > 0) {
      // 총알슛 꼬리 — 진행 반대쪽으로 흐려지는 잔상
      final back = velocity.normalized();
      final tail = c - Offset(back.x, back.y) * (r * 4.2);
      canvas.drawLine(c, tail, Paint()
        ..shader = ui.Gradient.linear(c, tail, [def.color.withValues(alpha: 0.75 * a), def.color.withValues(alpha: 0)])
        ..strokeWidth = r * 1.5
        ..strokeCap = StrokeCap.round);
    }
    final body = a < 1 ? def.color.withValues(alpha: a) : def.color;
    canvas.drawCircle(c, r, _ballFill..color = body);
    canvas.drawCircle(c.translate(r * 0.18, r * 0.22), r * 0.82, _ballFill..color = Colors.black.withValues(alpha: 0.14 * a));
    canvas.drawCircle(c, r * 0.8, _ballFill..color = body);
    if (def.seams) paintDodgeBallBand(canvas, c, r, _age * 7 * _curveSign, alpha: a);
    // 무회전 슛은 돌지 않는다
    if (def.soccer) {
      paintSoccerPatches(canvas, c, r, def.motion == ProjectileMotion.knuckle && !deflected ? 0.3 : _age * 6 * _curveSign,
          alpha: a);
    }
    canvas.drawCircle(c.translate(-r * 0.32, -r * 0.34), r * 0.26, _ballFill..color = Colors.white.withValues(alpha: 0.55 * a));
    canvas.drawCircle(
      c,
      r,
      _ballStroke
        ..color = Colors.black.withValues(alpha: 0.28 * a)
        ..strokeWidth = 1.2,
    );
  }

  @override
  Future<void> onLoad() async {
    // 공끼리는 부딪힐 일이 없다 — passive 로 두면 캐릭터(active)하고만 검사한다.
    // (모두 active 면 탄 100개일 때 공끼리 겹친 쌍까지 매 프레임 검사했다)
    add(CircleHitbox(radius: def.radius, position: size / 2, anchor: Anchor.center)
      ..collisionType = CollisionType.passive);
  }

  @override
  void update(double dt) {
    _age += dt;

    // --- 분열: 진행 방향 기준 좌우로 부채꼴(3개 ±16°, 5개 ±14°·±28°) ---
    if (splitAfter != null && _age >= splitAfter! && splitInto > 1) {
      final step = splitInto >= 5 ? 0.245 : 0.28; // rad
      final dir = velocity.normalized();
      for (int i = 0; i < splitInto; i++) {
        final a = (i - (splitInto - 1) / 2) * step;
        final d = dir.clone()..rotate(a);
        parent?.add(Bullet(position.clone(), position + d * 100, speed: speed * 1.05, def: def));
      }
      removeFromParent();
      return;
    }

    if (keeperCd > 0) keeperCd -= dt;

    // --- 거동 --- (키퍼·포스트에 튕긴 공은 직선)
    switch (_free ? ProjectileMotion.straight : def.motion) {
      case ProjectileMotion.curve:
        // 진행 방향에 수직인 가속 → 포물선처럼 휜다 (속도 크기는 유지)
        final perp = Vector2(-velocity.y, velocity.x).normalized();
        velocity += perp * (def.lateralAccel * _curveSign * dt);
        velocity = velocity.normalized() * speed;
        break;
      case ProjectileMotion.homing:
        if (_age < def.maxTurnTime && game.player.isMounted) {
          final toPlayer = game.player.position - position;
          final current = atan2(velocity.y, velocity.x);
          final target = atan2(toPlayer.y, toPlayer.x);
          double diff = (target - current + pi) % (2 * pi) - pi;
          final maxStep = def.turnRate * dt;
          diff = diff.clamp(-maxStep, maxStep);
          velocity.rotate(diff);
        }
        break;
      case ProjectileMotion.wave:
        // 꼬불꼬불 — 찬 방향을 축으로 좌우 사인파 (옆 위치 = A·sin(ωt))
        if (!deflected && !scored) {
          final w = 2 * pi * def.waveHz;
          final perp = Vector2(-_baseDir.y, _baseDir.x);
          velocity = _baseDir * speed + perp * (def.waveAmp * w * cos(w * _age) * _curveSign);
        }
        break;
      case ProjectileMotion.knuckle:
        // 무회전 — 0.12~0.3초마다 옆으로 흔들리는 방향이 바뀐다. 너무 멀리 새지 않게 기준선 쪽으로 당긴다.
        if (!deflected && !scored) {
          _knuckleT -= dt;
          if (_knuckleT <= 0) {
            _knuckleT = 0.12 + _rng.nextDouble() * 0.18;
            _latTarget = ((_rng.nextDouble() * 2 - 1) * def.waveAmp - _latOffset * 2.2)
                .clamp(-def.waveAmp, def.waveAmp);
          }
          _lat += (_latTarget - _lat) * min(1.0, dt * 9);
          _latOffset += _lat * dt;
          final perp = Vector2(-_baseDir.y, _baseDir.x);
          velocity = _baseDir * speed + perp * _lat;
        }
        break;
      case ProjectileMotion.straight:
      case ProjectileMotion.bounce:
        break;
    }

    position += velocity * dt;

    // Keeper: 포스트·닫힌 벽에 맞으면 튕기고, 열린 입구로 완전히 들어오면 실점
    final wc = game.worldConfig;
    if (wc.mode == WorldMode.keeper) {
      if (_keeperUpdate(wc)) return;
    }

    // 피구: 무대 밖으로 나가며 멀어지는 공은 바로 치운다. 직선 공이라 되돌아오지 않고 동시 공 상한도 없어서,
    // 1000px 밖까지 날게 두면 늦은 판에 보이지 않는 공이 수백 개 쌓여 프레임이 튀었다.
    // (갤럭시는 동시 탄 상한이 화면 밖 탄까지 세므로 난이도가 바뀌지 않게 아래 기존 기준을 그대로 쓴다)
    if (wc.spawner == SpawnStrategy.thrower && _leavingStage(40)) {
      removeFromParent();
      return;
    }

    // Cleanup - Tighter bounds
    if (position.x < -1000 ||
        position.x > ZonberGame.mapWidth + 1000 ||
        position.y < -1000 ||
        position.y > ZonberGame.worldHeight + 1000) {
      removeFromParent();
    }
  }


  /// 무대(480×768)에서 [margin] 이상 벗어났고 무대 가운데에서 멀어지는 중
  bool _leavingStage(double margin) {
    final x = position.x, y = position.y;
    final outside = x < -margin || x > ZonberGame.mapWidth + margin || y < -margin || y > ZonberGame.mapHeight + margin;
    if (!outside) return false;
    return velocity.x * (x - ZonberGame.mapWidth / 2) + velocity.y * (y - ZonberGame.mapHeight / 2) > 0;
  }

  /// 득점 없이 끝난 공 — 키퍼가 건드렸으면 세이브 확정, 아니면 빗나감. 흐려지며 사라진다
  void _settle() {
    deflected = true;
    _deflectAge = _age;
    if (keeperTouched && game.player.isMounted) game.player.creditSave(position.clone());
  }

  /// 골키퍼(페널티킥) 판정. 공을 제거했으면 true.
  bool _keeperUpdate(WorldConfig wc) {
    final br = def.radius;

    if (scored) {
      // 그물 안 — 그물 끝에서 멈추고 흐려지며 사라진다
      velocity *= 0.8;
      if (position.y > KeeperGoal.lineY + KeeperGoal.depth - br) {
        position.y = KeeperGoal.lineY + KeeperGoal.depth - br;
        velocity.setZero();
      }
      if (_age - _deflectAge > 0.5) {
        removeFromParent();
        return true;
      }
      return false;
    }

    // 1) 골포스트 — 둥근 기둥, 맞은 각도대로 튕긴다
    for (final pl in [true, false]) {
      final pc = game.goal.postPos(pl);
      final off = position - pc;
      if (off.length < KeeperGoal.postRadius + br && velocity.dot(off) < 0) {
        // 포스트 — 맞은 각도대로 튕긴다. 맞고 골문 안으로 들어갈 수도 있다(득점 대상 유지)
        reflectSoft(off, e: 0.75, friction: 0.95);
        position = pc + off.normalized() * (KeeperGoal.postRadius + br + 1);
        game.shake(4, 0.18);
        game.burst(position.clone(), Colors.white, count: 8, speed: 150, size: 2);
        AudioManager().playSfx(Sfx.hit, volume: 0.35, minGapMs: 60);
        return false;
      }
    }

    // 2) 골라인 통과 — 골문 안이면 실점(키퍼·포스트를 맞고 들어가도 골), 밖이면 빗나감
    if (!deflected && position.y >= KeeperGoal.lineY) {
      final inMouth = position.x > KeeperGoal.left + KeeperGoal.postRadius &&
          position.x < KeeperGoal.right - KeeperGoal.postRadius;
      if (inMouth) {
        scored = true;
        _deflectAge = _age;
        game.fxGoal(position.clone());
        if (game.player.isMounted) game.player.concedeGoal();
      } else {
        _settle(); // 골문 옆으로 — 키퍼가 건드렸으면 세이브
      }
    }

    // 3) 튕겨서 골문 반대쪽(위)으로 가거나 무대 옆으로 나가면 끝 — 키퍼가 건드렸으면 세이브
    if (!deflected && !scored && (_free || keeperTouched)) {
      final away = velocity.y < -20;
      final outSide = position.x < -10 || position.x > ZonberGame.mapWidth + 10;
      if (away || outSide) _settle();
    }

    // 4) 튕긴·빗나간 공 정리
    if (deflected &&
        (_fade <= 0 ||
            position.x < -40 ||
            position.y < -40 ||
            position.x > ZonberGame.mapWidth + 40 ||
            position.y > ZonberGame.mapHeight + 40)) {
      removeFromParent();
      return true;
    }
    return false;
  }
}

class BulletSpawner extends Component with HasGameReference<ZonberGame> {
  // ── 난이도 곡선 튜닝 상수 ──────────────────────────────
  // ⚠️ 이 값을 바꾸면 기존 리더보드 기록과 난이도가 달라진다.
  //    변경 시 시즌 리셋을 함께 검토할 것.
  static const double _levelDuration = 25.0; // 레벨업 간격(초)
  static const int _startLevel = 1;          // 시작 레벨 (0이면 초반 무위험 구간이 길어짐)
  static const double _intervalDecay = 0.9;  // 레벨당 스폰 간격 배수
  static const double _minInterval = 0.02;   // 스폰 간격 하한
  static const double _speedPerLevel = 15.0; // 레벨당 탄속 증가
  static const int _limitPerLevel = 10;      // 레벨당 동시 탄환 상한 증가
  // ──────────────────────────────────────────────────────

  // Manual Timer Logic
  double _timeSinceLastSpawn = 0.0;

  // Base Config
  double _baseInterval = 0.1;
  double _baseSpeed = 150.0;
  int _baseLimit = 100;

  final Random _random = Random();

  /// 피구(thrower) — 한 턴에 한 번 캐릭터를 향해 던진다
  final _DodgeballThrower _thrower = _DodgeballThrower();

  /// 골키퍼(shooter) — 열린 입구를 노리고 턴마다 찬다
  final _KeeperShooter _shooter = _KeeperShooter();

  /// 현재 난이도 레벨 (경과 시간 기반)
  int get currentLevel =>
      _startLevel + (game.survivalTime / _levelDuration).floor();

  @override
  void onMount() {
    super.onMount();
    StageConfig? config = GameConfig.getStage(game.mapId);
    if (config != null) {
      _baseInterval = config.spawnInterval;
      _baseSpeed = config.bulletSpeed;
    }
    // 월드가 정하는 값이 우선 — 동시 탄 상한, 스폰 간격, 기본 탄속
    final world = game.worldConfig;
    _baseLimit = world.maxBullets;
    _baseInterval = world.spawnInterval ?? _baseInterval;
    _baseSpeed = world.bulletSpeed ?? _baseSpeed;
  }

  @override
  void update(double dt) {
    if (game.inIntro) return; // 시작 연출 중엔 공을 내지 않는다
    if (game.worldConfig.spawner == SpawnStrategy.thrower) {
      _thrower.update(dt, game);
      return;
    }
    if (game.worldConfig.spawner == SpawnStrategy.shooter) {
      _shooter.update(dt, game);
      return;
    }
    _timeSinceLastSpawn += dt;

    final int level = currentLevel;

    double currentInterval = _baseInterval * pow(_intervalDecay, level);
    if (currentInterval < _minInterval) currentInterval = _minInterval;

    if (_timeSinceLastSpawn >= currentInterval) {
      _timeSinceLastSpawn = 0;
      _spawnBullet(level);
    }
  }

  void _spawnBullet(int level) {
    if (game.isGameOver) return;
    if (!game.player.isMounted) return;

    // Player has anchor=Anchor.center, so position IS the center already
    // Keeper 모드는 골대(맵 중앙)를 기준으로 스폰하고 골대를 조준한다
    final bool keeper = game.worldConfig.mode == WorldMode.keeper;
    Vector2 playerPos = keeper
        ? Vector2(ZonberGame.mapWidth / 2, ZonberGame.mapHeight / 2)
        : game.player.position;

    // RAMPING: Increase bullet cap slightly over time
    int currentLimit = _baseLimit + (level * _limitPerLevel);

    if (game.mapArea.children.whereType<Bullet>().length > currentLimit) {
      return;
    }

    // RAMPING: 레벨당 속도 +15, 기본값의 2배에서 상한
    // (slowTime 감속은 Bullet.update()에서 실시간 적용 — 여기서 곱하지 않는다)
    double currentSpeed =
        (_baseSpeed + (level * _speedPerLevel)).clamp(0, _baseSpeed * 2);

    final world = game.worldConfig;
    final def = world.projectiles[_random.nextInt(world.projectiles.length)];
    final Vector2 spawnPos;
    // ring — 플레이어(또는 keeper 골대) 중심 원주
    final double range = world.spawnRadius;
    final double angle = _random.nextDouble() * 2 * pi;
    spawnPos = playerPos + Vector2(cos(angle), sin(angle)) * range;

    final double jitter = keeper ? game.worldConfig.goalRadius * 1.2 : 100;
    Vector2 targetPos =
        playerPos +
        Vector2(
          (_random.nextDouble() - 0.5) * jitter,
          (_random.nextDouble() - 0.5) * jitter,
        );

    game.mapArea.add(Bullet(spawnPos, targetPos, speed: currentSpeed * def.speedMult, def: def));
  }
}
