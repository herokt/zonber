part of '../main.dart';

// 펫 — 게임을 돕는 서브 캐릭터(lib/pets.dart · 2026-10-12)
//   세 존 모두: 캐릭터 둘레(반지름 Pets.orbitRadius)를 같은 빠르기로 계속 돈다. 도는 길은 얇은 원으로 보여 준다.
//   캐릭터 쪽으로 오던 탄·공이 펫에 닿으면 **바깥쪽으로** 튕겨 낸다(Bullet.petSwat) — 펫을 맞고 캐릭터 쪽으로 오는 일은 없다.
//     피하기 존: 튕긴 공은 흐려지며 사라지고 더는 다치게 하지 않는다.
//     골키퍼   : 골대(아래) 쪽으로는 튕기지 않는다. 쳐내고도 들어가면 골이고, 연속 선방에는 세지 않는다.
//   한 번 쳐내면 PetPower.cooldown 초 쉰다(흐려지고 z). 쉬는 동안 닿는 공은 그냥 지나간다. 다시 준비되면 반짝인다.
//
// 판정은 공과의 **거리로만** 한다. 펫에는 히트박스가 없어 캐릭터 충돌(Player.onCollisionStart)과 섞이지 않는다.
// 도는 길(36px)은 캐릭터 히트박스(반 11px)보다 충분히 바깥이라, 펫이 쳐내는 범위와 캐릭터 몸이 겹치지 않는다.

class PetHelper extends PositionComponent with HasGameReference<ZonberGame> {
  final Pet pet;
  PetHelper(this.pet) : super(anchor: Anchor.center, size: Vector2.all(30), priority: 11);

  /// 게임 안 몸 반지름(px) — 그림 크기(2026-10-12 8 → 6 → 7 → 7.5 → 9 → 10). 그림 한 변 = 2.5배. 쳐내는 범위는 PetPower.reach 로 따로
  static const double bodyR = 10;

  double _t = 0;
  double _angle = -pi / 2; // 캐릭터 위에서 출발
  double _rest = 0; // 남은 쉬는 시간(초)
  bool _wasResting = false;
  bool _flip = false; // 왼쪽으로 가는 중이면 그림을 뒤집는다

  /// 이번 판에 쳐낸 수
  int swats = 0;

  bool get _keeper => game.worldConfig.mode == WorldMode.keeper;

  static final Paint _ringDark = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  static final Paint _ringLight = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.6;

  @override
  Future<void> onLoad() async {
    _place(0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_rest > 0) _rest = max(0, _rest - dt);
    if (_wasResting && _rest <= 0) {
      // 다시 준비됨 — 펫 색 반짝임
      game.burst(position.clone(), pet.color, count: 6, speed: 70, size: 1.8);
    }
    _wasResting = _rest > 0;
    _place(dt);
    if (game.isGameOver || game.inIntro || game.storeShot) return;
    if (_rest <= 0) _trySwat();
  }

  /// 캐릭터 둘레를 같은 빠르기로 계속 돈다(쉬는 동안에도 — 2026-10-12)
  void _place(double dt) {
    final p = game.player;
    if (!p.isMounted) return;
    final before = position.x;
    _angle += pet.power.orbitSpeed * dt;
    position = p.position + Vector2(cos(_angle), sin(_angle)) * Pets.orbitRadius;
    final dx = position.x - before;
    if (dx.abs() > 0.05) _flip = dx < 0;
  }

  void _trySwat() {
    final p = game.player;
    if (!p.isMounted) return;
    final reach = pet.power.reach;
    for (final c in game.mapArea.children) {
      if (c is! Bullet || c.deflected || c.scored || c.petTouched) continue;
      if (c.position.distanceTo(position) > reach + c.def.radius) continue;
      final out = c.position - p.position; // 캐릭터 → 공 = 바깥쪽
      // 캐릭터 쪽으로 오는 공만(이미 멀어지는 공에 쉬는 시간을 쓰지 않게). 골키퍼는 골대로 가는 공도
      final incoming = c.velocity.dot(out) < 0 || (_keeper && c.velocity.y > 0);
      if (!incoming) continue;
      _swat(c, out);
      return; // 한 번에 하나
    }
  }

  void _swat(Bullet b, Vector2 out) {
    _rest = pet.power.cooldown;
    _wasResting = true;
    swats++;
    b.petSwat(out);
    game.burst(b.position.clone(), pet.color, count: 9, speed: 150, size: 2.2);
    game.burst(b.position.clone(), Colors.white, count: 5, speed: 110, size: 1.6);
    AudioManager().playSfx(Sfx.save, volume: 0.35, minGapMs: 80);
    Haptics.tick();
  }

  @override
  void render(Canvas canvas) {
    final cd = pet.power.cooldown;
    final tired = cd > 0 ? (_rest / cd).clamp(0.0, 1.0) : 0.0;
    final p = game.player;
    if (p.isMounted && !game.isGameOver) {
      // 도는 길 — 아주 얇고 옅은 원(2026-10-12 더 얇게 — 살짝만 보이면 된다). 어두운 바닥·밝은 바닥 모두 보이게 옅은 그림자 + 흰 선, 쉬는 동안은 더 옅게
      final ring = Offset(size.x / 2 + p.position.x - position.x, size.y / 2 + p.position.y - position.y);
      final k = 1 - 0.6 * tired;
      canvas.drawCircle(ring, Pets.orbitRadius, _ringDark..color = Colors.black.withValues(alpha: 0.06 * k));
      canvas.drawCircle(ring, Pets.orbitRadius, _ringLight..color = Colors.white.withValues(alpha: 0.26 * k));
    }
    paintPet(canvas, pet.id, Offset(size.x / 2, size.y / 2), bodyR, _t, tired: tired, flip: _flip);
  }
}
