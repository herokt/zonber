import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

// ─────────────────────────────────────────────────────────────
// 펫 그림 — 주위를 도는 오라 6종(2026-10-26 펫을 오라로 합쳤다, cosmetics.dart `Cosmetic.pet`). docs/SHOP.md §오라
//
//   예전(2026-10-12)엔 따로 데리고 다니는 펫 슬롯이 있었고, 도는 오라와 같이 못 쓰는 규칙이 있었다. 지금은 오라 칸에서 하나를 고른다.
//   아이템 id 는 그대로(pet_star …) — 예전에 산 기록(ownedItems)이 그대로 이어진다. 예전 착용 슬롯 'pet' 은
//   CoinStore 가 읽을 때 오라 슬롯으로 옮긴다(Cosmetics.migrateEquipped).
//   여기에는 그림(PetArt · paintPet · PetPreview)과 도는 속도·색만 남는다. 그리기는 paintAura 가 부른다.
// 그림(2026-10-12 시안 아트) — Gemini 로 뽑은 assets/images/sprites/{펫 id}.png([PetArt]). 못 읽었으면 코드 드로잉.
// 비교용 --dart-define=ART=code = 코드 드로잉만.
// ─────────────────────────────────────────────────────────────

class Pet {
  final String id;
  /// 도는 속도(rad/s)
  final double orbitSpeed;
  /// 몸 색(반짝임·미리보기 색)
  final Color color;
  const Pet(this.id, this.orbitSpeed, this.color);
}

class Pets {
  /// 예전 착용 슬롯 키(2026-10-26 전) — 읽을 때 오라로 옮기고 지운다
  static const String legacySlotKey = 'pet';

  /// 도는 길 반지름 = 캐릭터 몸 반지름 × 이 배수(게임 반지름 약 20.6 → 36px). 캐릭터 히트박스(반 11)보다 늘 바깥
  static const double orbitScale = 1.75;
  /// 펫 몸 반지름 = 캐릭터 몸 반지름 × 이 배수(게임 약 10px)
  static const double bodyScale = 0.48;

  static const List<Pet> all = [
    Pet('pet_star', 2.2, Color(0xFFFFD23F)),
    Pet('pet_slime', 2.4, Color(0xFF5EF2C2)),
    Pet('pet_ghost', 2.6, Color(0xFFE8ECF8)),
    Pet('pet_robot', 2.8, Color(0xFF9FB0CC)),
    Pet('pet_cat', 3.0, Color(0xFFFF9F43)),
    Pet('pet_dragon', 3.3, Color(0xFF4ADE80)),
  ];

  static Pet? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// 펫 오라 — 캐릭터([center], 몸 반지름 [r]) 둘레를 돈다. [front] false = 도는 길(얇은 원), true = 펫(늘 캐릭터 위 — 위에서 보는 화면)
void paintPetAura(Canvas canvas, String id, Offset center, double r, double t, {required bool front}) {
  final pet = Pets.byId(id);
  if (pet == null) return;
  final orbit = r * Pets.orbitScale;
  if (!front) {
    // 도는 길 — 아주 얇고 옅은 원. 어두운 바닥·밝은 바닥 모두 보이게 옅은 그림자 + 흰 선
    canvas.drawCircle(center, orbit, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.068
      ..color = Colors.black.withValues(alpha: 0.06));
    canvas.drawCircle(center, orbit, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.03
      ..color = Colors.white.withValues(alpha: 0.26));
    return;
  }
  final a = -pi / 2 + t * pet.orbitSpeed; // 위에서 출발해 시계 방향
  // 왼쪽으로 가는 중(x 가 줄어드는 중 = sin(a) > 0)이면 그림을 뒤집는다
  paintPet(canvas, id, center + Offset(cos(a), sin(a)) * orbit, r * Pets.bodyScale, t, flip: sin(a) > 0);
}

// ── 그림 ─────────────────────────────────────────────────────

/// 펫 그림(시안 아트) — 처음 그릴 때 한 번 읽는다. 읽는 동안·없으면 코드 드로잉
class PetArt {
  static bool enabled = const String.fromEnvironment('ART') != 'code';
  static final Map<String, ui.Image> _img = {};
  static Future<void>? _loading;

  static ui.Image? of(String id) {
    if (!enabled) return null;
    load();
    return _img[id];
  }

  static Future<void> load() => _loading ??= !enabled
      ? Future.value()
      : Future.wait([
          for (final p in Pets.all)
            () async {
              try {
                final data = await rootBundle.load('assets/images/sprites/${p.id}.png');
                final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
                _img[p.id] = (await codec.getNextFrame()).image;
              } catch (_) {
                // 그림 없음 — 코드 드로잉
              }
            }(),
        ]);
}

final Paint _petArtPaint = Paint()..filterQuality = FilterQuality.medium;

/// 펫 하나를 [c] 에 그린다. [r] 몸 반지름(게임 10 · 미리보기는 더 크게), [t] 시간(초),
/// [tired] 0~1 — 쉬는 중(1 = 막 쳐냄). 쉬는 동안 흐려지고 눈을 감는다(그림이면 흐려지고 살짝 작아진다).
/// [flip] 좌우로 뒤집기(왼쪽으로 갈 때)
void paintPet(Canvas canvas, String id, Offset c, double r, double t, {double tired = 0, bool flip = false}) {
  final a = 1 - 0.45 * tired.clamp(0.0, 1.0);
  final bob = sin(t * 4) * r * 0.08;
  canvas.save();
  canvas.translate(c.dx, c.dy + bob);
  // 바닥 그림자
  canvas.drawOval(Rect.fromCenter(center: Offset(0, r * 1.15), width: r * 1.3, height: r * 0.32),
      Paint()..color = Colors.black.withValues(alpha: 0.18 * a));
  final art = PetArt.of(id);
  if (art != null) {
    // 그림 한 변 = 몸 반지름의 2.5배(그림 안에 여백이 조금 있다)
    final side = r * 2.5 * (1 - 0.08 * tired.clamp(0.0, 1.0));
    if (flip) canvas.scale(-1, 1);
    canvas.rotate(sin(t * 2.2) * 0.06);
    canvas.drawImageRect(art, Rect.fromLTWH(0, 0, art.width.toDouble(), art.height.toDouble()),
        // 그림은 덜 흐리게(예쁜 그림이 쉬는 동안 회색 덩어리로 보이지 않게)
        Rect.fromCenter(center: Offset.zero, width: side, height: side), _petArtPaint..color = Color.fromRGBO(255, 255, 255, 1 - 0.3 * tired.clamp(0.0, 1.0)));
    if (flip) canvas.scale(-1, 1);
    _restZ(canvas, r, t, tired);
    canvas.restore();
    return;
  }
  switch (id) {
    case 'pet_star':
      _star(canvas, r, a, t);
    case 'pet_slime':
      _slime(canvas, r, a, t);
    case 'pet_ghost':
      _ghost(canvas, r, a, t);
    case 'pet_robot':
      _robot(canvas, r, a, t);
    case 'pet_cat':
      _cat(canvas, r, a, t);
    case 'pet_dragon':
      _dragon(canvas, r, a, t);
  }
  _face(canvas, r, a, closed: tired > 0.02, dy: id == 'pet_robot' ? -r * 0.05 : 0, robot: id == 'pet_robot');
  _restZ(canvas, r, t, tired);
  canvas.restore();
}

/// 쉬는 중 — 작은 z
void _restZ(Canvas canvas, double r, double t, double tired) {
  if (tired <= 0.02) return;
  final zp = Offset(r * 0.9, -r * 1.1 - (t * 0.8 % 1) * r * 0.5);
  final tp = TextPainter(
    text: TextSpan(text: 'z', style: TextStyle(fontSize: max(7.0, r * 0.9), fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 0.8))),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, zp);
}

Paint _fill(Color c, double a) => Paint()..color = c.withValues(alpha: (c.a * a).clamp(0.0, 1.0));
Paint _ink(double r, double a, [double w = 0.12]) => Paint()
  ..color = const Color(0xFF1B1530).withValues(alpha: 0.85 * a)
  ..style = PaintingStyle.stroke
  ..strokeWidth = max(0.8, r * w)
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round;

void _face(Canvas canvas, double r, double a, {required bool closed, double dy = 0, bool robot = false}) {
  final ink = Paint()..color = (robot ? const Color(0xFF7DF9FF) : const Color(0xFF1B1530)).withValues(alpha: 0.9 * a);
  for (final sx in [-1.0, 1.0]) {
    final e = Offset(sx * r * 0.32, -r * 0.08 + dy);
    if (closed) {
      canvas.drawArc(Rect.fromCenter(center: e, width: r * 0.32, height: r * 0.22), 0.2, pi - 0.4, false,
          Paint()
            ..color = ink.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(0.8, r * 0.1)
            ..strokeCap = StrokeCap.round);
    } else {
      canvas.drawOval(Rect.fromCenter(center: e, width: r * 0.24, height: r * 0.3), ink);
      if (!robot) canvas.drawCircle(e + Offset(-r * 0.04, -r * 0.06), r * 0.06, Paint()..color = Colors.white.withValues(alpha: 0.9 * a));
    }
  }
  if (!robot) {
    canvas.drawArc(Rect.fromCenter(center: Offset(0, r * 0.18 + dy), width: r * 0.3, height: r * 0.2), 0.15, pi - 0.3, false,
        _ink(r, a, 0.09));
    for (final sx in [-1.0, 1.0]) {
      canvas.drawCircle(Offset(sx * r * 0.58, r * 0.16 + dy), r * 0.12, Paint()..color = const Color(0xFFFF7FA8).withValues(alpha: 0.45 * a));
    }
  }
}

void _star(Canvas canvas, double r, double a, double t) {
  canvas.save();
  canvas.rotate(sin(t * 2) * 0.12);
  final path = Path();
  for (int i = 0; i < 10; i++) {
    final rr = i.isEven ? r * 1.15 : r * 0.62;
    final ang = -pi / 2 + i * pi / 5;
    final p = Offset(cos(ang) * rr, sin(ang) * rr + r * 0.05);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  path.close();
  canvas.drawPath(path, Paint()
    ..shader = ui.Gradient.radial(Offset(-r * 0.3, -r * 0.4), r * 1.6, [
      const Color(0xFFFFF6C8).withValues(alpha: a),
      const Color(0xFFFFC53D).withValues(alpha: a),
    ]));
  canvas.drawPath(path, _ink(r, a, 0.09));
  canvas.restore();
}

void _slime(Canvas canvas, double r, double a, double t) {
  final w = 1 + sin(t * 5) * 0.06;
  final rect = Rect.fromCenter(center: Offset(0, r * 0.12), width: r * 2.1 * w, height: r * 1.8 / w);
  final body = Path()
    ..moveTo(rect.left, rect.bottom)
    ..quadraticBezierTo(rect.left - r * 0.05, rect.top + r * 0.2, 0, rect.top - r * 0.25)
    ..quadraticBezierTo(rect.right + r * 0.05, rect.top + r * 0.2, rect.right, rect.bottom)
    ..close();
  canvas.drawPath(body, Paint()
    ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
      const Color(0xFFB9FBE0).withValues(alpha: 0.95 * a),
      const Color(0xFF2ECFA6).withValues(alpha: 0.95 * a),
    ]));
  canvas.drawPath(body, _ink(r, a, 0.09));
  canvas.drawOval(Rect.fromCenter(center: Offset(-r * 0.45, -r * 0.35), width: r * 0.4, height: r * 0.25),
      Paint()..color = Colors.white.withValues(alpha: 0.7 * a));
}

void _ghost(Canvas canvas, double r, double a, double t) {
  final path = Path()..moveTo(-r, r * 0.9);
  path.lineTo(-r, -r * 0.1);
  path.arcTo(Rect.fromCircle(center: Offset(0, -r * 0.1), radius: r), pi, pi, false);
  path.lineTo(r, r * 0.9);
  for (int i = 0; i < 4; i++) {
    final x0 = r - i * r * 0.5;
    path.quadraticBezierTo(x0 - r * 0.25, r * (0.9 + 0.3 * (i.isEven ? 1 : -0.2) * (0.6 + 0.4 * sin(t * 6 + i))), x0 - r * 0.5, r * 0.9);
  }
  path.close();
  canvas.drawPath(path, Paint()..color = const Color(0xFFF4F6FF).withValues(alpha: 0.92 * a));
  canvas.drawPath(path, _ink(r, a, 0.08));
}

void _robot(Canvas canvas, double r, double a, double t) {
  // 안테나 — 끝이 깜빡인다
  canvas.drawLine(Offset(0, -r * 0.85), Offset(0, -r * 1.35), _ink(r, a, 0.1));
  canvas.drawCircle(Offset(0, -r * 1.42), r * 0.18,
      Paint()..color = Color.lerp(const Color(0xFFFF5A5A), const Color(0xFFFFD23F), 0.5 + 0.5 * sin(t * 6))!.withValues(alpha: a));
  final head = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: r * 2.1, height: r * 1.8), Radius.circular(r * 0.5));
  canvas.drawRRect(head, Paint()
    ..shader = ui.Gradient.linear(head.outerRect.topCenter, head.outerRect.bottomCenter, [
      const Color(0xFFE6ECF5).withValues(alpha: a),
      const Color(0xFF8A97AB).withValues(alpha: a),
    ]));
  canvas.drawRRect(head, _ink(r, a, 0.09));
  final visor = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, -r * 0.05), width: r * 1.5, height: r * 0.7), Radius.circular(r * 0.3));
  canvas.drawRRect(visor, Paint()..color = const Color(0xFF1B2A44).withValues(alpha: a));
  for (final sx in [-1.0, 1.0]) {
    canvas.drawCircle(Offset(sx * r * 1.12, 0), r * 0.18, _fill(const Color(0xFFB8C2D3), a));
  }
}

void _cat(Canvas canvas, double r, double a, double t) {
  final orange = const Color(0xFFFF9F43);
  for (final sx in [-1.0, 1.0]) {
    final ear = Path()
      ..moveTo(sx * r * 0.85, -r * 0.35)
      ..lineTo(sx * r * 0.7, -r * 1.25)
      ..lineTo(sx * r * 0.15, -r * 0.8)
      ..close();
    canvas.drawPath(ear, _fill(orange, a));
    canvas.drawPath(ear, _ink(r, a, 0.08));
  }
  canvas.drawCircle(Offset.zero, r, Paint()
    ..shader = ui.Gradient.radial(Offset(-r * 0.3, -r * 0.35), r * 1.5, [
      const Color(0xFFFFD9A8).withValues(alpha: a),
      orange.withValues(alpha: a),
    ]));
  canvas.drawCircle(Offset.zero, r, _ink(r, a, 0.08));
  // 줄무늬 · 수염
  for (int i = -1; i <= 1; i++) {
    canvas.drawLine(Offset(i * r * 0.25, -r * 0.95), Offset(i * r * 0.2, -r * 0.62), _ink(r, a * 0.6, 0.08));
  }
  for (final sx in [-1.0, 1.0]) {
    for (int i = 0; i < 2; i++) {
      canvas.drawLine(Offset(sx * r * 0.45, r * (0.25 + i * 0.14)), Offset(sx * r * 1.15, r * (0.18 + i * 0.22)), _ink(r, a * 0.55, 0.05));
    }
  }
  canvas.drawLine(Offset(r * 0.95, r * 0.5), Offset(r * 1.35, r * (0.1 + 0.15 * sin(t * 5))), _ink(r, a, 0.14)..color = orange.withValues(alpha: a));
}

void _dragon(Canvas canvas, double r, double a, double t) {
  final green = const Color(0xFF4ADE80);
  // 날개 — 퍼덕인다
  final flap = sin(t * 12) * 0.35;
  for (final sx in [-1.0, 1.0]) {
    canvas.save();
    canvas.translate(sx * r * 0.75, -r * 0.2);
    canvas.rotate(sx * (-0.3 + flap));
    final wing = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(sx * r * 0.9, -r * 1.0, sx * r * 1.25, -r * 0.2)
      ..quadraticBezierTo(sx * r * 0.8, -r * 0.15, sx * r * 0.9, r * 0.25)
      ..quadraticBezierTo(sx * r * 0.45, 0, 0, 0)
      ..close();
    canvas.drawPath(wing, _fill(const Color(0xFFA78BFA), a));
    canvas.drawPath(wing, _ink(r, a, 0.07));
    canvas.restore();
  }
  // 뿔
  for (final sx in [-1.0, 1.0]) {
    final horn = Path()
      ..moveTo(sx * r * 0.45, -r * 0.75)
      ..lineTo(sx * r * 0.6, -r * 1.3)
      ..lineTo(sx * r * 0.2, -r * 0.85)
      ..close();
    canvas.drawPath(horn, _fill(const Color(0xFFFFE9A8), a));
  }
  canvas.drawCircle(Offset.zero, r, Paint()
    ..shader = ui.Gradient.radial(Offset(-r * 0.3, -r * 0.35), r * 1.5, [
      const Color(0xFFB9FBC8).withValues(alpha: a),
      green.withValues(alpha: a),
    ]));
  canvas.drawCircle(Offset.zero, r, _ink(r, a, 0.08));
  canvas.drawOval(Rect.fromCenter(center: Offset(0, r * 0.5), width: r * 1.0, height: r * 0.6), _fill(const Color(0xFFFFF3C4), a * 0.9));
}

/// 가방 카드·미리보기용 — 제자리에서 통통 뛰는 펫
class PetPreview extends StatefulWidget {
  final String petId;
  final double size;
  const PetPreview({super.key, required this.petId, this.size = 48});

  @override
  State<PetPreview> createState() => _PetPreviewState();
}

class _PetPreviewState extends State<PetPreview> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  final Stopwatch _clock = Stopwatch()..start();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _PetPainter(widget.petId, _clock.elapsedMicroseconds / 1e6),
        ),
      );
}

class _PetPainter extends CustomPainter {
  final String id;
  final double t;
  _PetPainter(this.id, this.t);

  @override
  void paint(Canvas canvas, Size size) =>
      paintPet(canvas, id, Offset(size.width / 2, size.height * 0.46), size.width * 0.27, t);

  @override
  bool shouldRepaint(_PetPainter old) => old.t != t || old.id != id;
}
