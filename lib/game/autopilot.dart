part of '../main.dart';

// 자동 플레이 — 광고 영상 모드(ad_video.dart)에서만 쓴다. 사람이 손가락으로 끄는 것처럼 캐릭터를 움직인다.
//   피하기 존: 0.06초마다 둘레 후보 자리 중 앞으로 0.9초 동안 공과 가장 덜 겹칠 자리를 골라 그쪽으로 끈다
//   골키퍼: 골문으로 오는 공 중 가장 급한 공이 키퍼 줄을 지날 자리로 간다
class AutoPilot {
  /// 손가락이 끄는 빠르기 상한(무대 px/초)
  static const double _maxSpeed = 760;
  static const double _keeperSpeed = 900;
  static const List<double> _rings = [0, 20, 40, 66, 96];
  static const int _dirs = 16;

  Vector2? _target;
  double _think = 0;
  final Vector2 _vel = Vector2.zero();

  /// 이번 스텝에 끌 거리(무대 px)
  Vector2 drag(ZonberGame game, double dt) {
    if (game.inIntro || dt <= 0) return Vector2.zero();
    final keeper = game.worldConfig.mode == WorldMode.keeper;
    final p = game.player.position;
    _think -= dt;
    if (_think <= 0 || _target == null) {
      _think = 0.06;
      _target = keeper ? _keeperTarget(game) : _dodgeTarget(game);
    }
    // 목표 쪽으로 — 속도를 바로 바꾸지 않고 따라가게 해 손가락처럼 부드럽게
    final limit = keeper ? _keeperSpeed : _maxSpeed;
    final want = (_target! - p) * 14;
    if (want.length > limit) want.scaleTo(limit);
    _vel.lerp(want, 1 - exp(-dt * 20));
    return _vel * dt;
  }

  Vector2 _dodgeTarget(ZonberGame game) {
    final p = game.player.position.clone();
    final zone = game.zoneRect.deflate(18);
    final center = Vector2(zone.center.dx, zone.center.dy);
    final bullets = [
      for (final c in game.mapArea.children)
        if (c is Bullet && !c.deflected && c.position.distanceTo(p) < 360) c,
    ];
    Vector2 best = p;
    double bestCost = double.infinity;
    for (final r in _rings) {
      for (int k = 0; k < (r == 0 ? 1 : _dirs); k++) {
        final a = k * 2 * pi / _dirs + (r % 40 == 0 ? 0 : pi / _dirs);
        final q = Vector2(
          (p.x + cos(a) * r).clamp(zone.left, zone.right),
          (p.y + sin(a) * r).clamp(zone.top, zone.bottom),
        );
        double cost = _danger(q, p, bullets);
        // 벽·구석에 몰리지 않게 — 영상에서 캐릭터가 화면 가운데 쪽에 보이도록
        final edge = [q.x - zone.left, zone.right - q.x, q.y - zone.top, zone.bottom - q.y].reduce(min);
        if (edge < 90) cost += (1 - edge / 90) * (1 - edge / 90) * 6;
        // 가운데 쪽 · 덜 움직이는 쪽 · 직전 목표 쪽을 조금 좋게(흔들림 방지)
        final off = q.distanceTo(center) / 180;
        cost += off * off * 1.2;
        cost += q.distanceTo(p) / 100 * 0.12;
        if (_target != null) cost += q.distanceTo(_target!) / 100 * 0.1;
        if (cost < bestCost) {
          bestCost = cost;
          best = q;
        }
      }
    }
    return best;
  }

  /// 캐릭터가 [p]에서 [q]로 가는 동안 공과 겹치는 정도 — 공은 지금 속도 그대로 간다고 본다
  double _danger(Vector2 q, Vector2 p, List<Bullet> bullets) {
    final travel = max(1e-3, q.distanceTo(p) / _maxSpeed);
    double cost = 0;
    for (int s = 0; s <= 9; s++) {
      final t = s * 0.1;
      final f = min(1.0, t / travel);
      final px = p.x + (q.x - p.x) * f, py = p.y + (q.y - p.y) * f;
      final w = 1.0 - t * 0.75;
      for (final b in bullets) {
        final dx = b.position.x + b.velocity.x * t - px;
        final dy = b.position.y + b.velocity.y * t - py;
        final d = sqrt(dx * dx + dy * dy) - (b.def.radius + 17);
        if (d < 0) {
          cost += w * 40;
        } else if (d < 36) {
          final u = 1 - d / 36;
          cost += w * u * u * 3;
        }
      }
    }
    return cost;
  }

  Vector2 _keeperTarget(ZonberGame game) {
    const lineY = KeeperGoal.keeperY - 6;
    final home = Vector2(240, lineY);
    Vector2? at;
    double soonest = double.infinity;
    for (final c in game.mapArea.children) {
      if (c is! Bullet || c.deflected || c.scored || c.velocity.y < 30) continue;
      final t = (lineY - c.position.y) / c.velocity.y;
      if (t < -0.08) continue;
      final x = c.position.x + c.velocity.x * max(0.0, t);
      if (x < KeeperGoal.left - 24 || x > KeeperGoal.right + 24) continue; // 골문을 벗어나는 공은 보낸다
      if (t < soonest) {
        soonest = t;
        // 시간이 있으면 한 발 앞으로 나가 막는다
        final y = t > 0.5 ? lineY - 30 : lineY;
        at = Vector2(x.clamp(KeeperGoal.left + 10, KeeperGoal.right - 10), y);
      }
    }
    return at ?? home;
  }
}
