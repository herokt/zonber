import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'game_art.dart';

// ─────────────────────────────────────────────────────────────
// 존버 — 동글동글한 메인 캐릭터(코드로 그린다, 이미지 없음). docs/CHARACTER_CONCEPT.md
// 동그란 몸 · 얼굴(눈·볼·입) · 양손 · 양발. 캐릭터마다 몸 색만 다르다.
// 존 장비(gear.dart)는 부위별로 겹쳐 그린다: 등 → 발 → 몸 → 얼굴 → 손 → 머리.
// 게임(Player)·아바타(CharacterAvatar)·상점 미리보기가 모두 이 함수를 쓴다.
// 그림(assets/images/game — 몸통·표정·장비)이 있으면 그림으로, 없으면 아래 코드 그림으로 그린다.
// ─────────────────────────────────────────────────────────────

/// 표정 3종 — 기본 · 아야(맞음/실점) · 신남(아슬아슬 회피/세이브)
enum ZonberFace { normal, hurt, happy }

class ZonberLook {
  final Color color;
  final ZonberFace face;
  /// 장착 장비 id 목록(gear.dart). 부위마다 하나
  final List<String> gear;
  /// 경과 시간(초) — 날개 펄럭임·불꽃·걸음
  final double t;
  final bool moving;
  /// 맞았을 때 납작해지는 정도 0→1
  final double squash;
  /// 눈동자가 쏠리는 방향(-1~1)
  final Offset look;
  /// 캐릭터 id — 몸통 그림(body_{id}.png)을 고른다. null 이면 코드 그림
  final String? body;
  const ZonberLook({
    required this.color,
    this.body,
    this.face = ZonberFace.normal,
    this.gear = const [],
    this.t = 0,
    this.moving = false,
    this.squash = 0,
    this.look = Offset.zero,
  });
}

Color _shade(Color c, double amount) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness + amount).clamp(0.0, 1.0)).toColor();
}

/// [center] 에 반지름 [r] 의 존버를 그린다. 장비·손발이 몸 밖으로 r 의 약 0.6배 삐져나온다.
void paintZonber(Canvas canvas, Offset center, double r, ZonberLook k) {
  String? gearOf(String prefix) {
    for (final g in k.gear) {
      if (g.startsWith(prefix)) return g;
    }
    return null;
  }

  final wings = gearOf('wings_');
  final rocket = gearOf('rocket_');
  final sneakers = gearOf('sneakers_');
  final boots = gearOf('boots_');
  final gloves = gearOf('gloves_');
  final band = gearOf('band_');
  final cap = gearOf('cap_');

  if (k.body != null && GameArt.img('body_${k.body}') != null) {
    _paintZonberArt(canvas, center, r, k, gearOf);
    return;
  }

  final body = k.color;
  final dark = _shade(body, -0.16);
  final light = _shade(body, 0.16);
  final step = k.moving ? sin(k.t * 16) : 0.0;

  canvas.save();
  canvas.translate(center.dx, center.dy);

  // ── 등: 날개 ──
  if (wings != null) _paintWings(canvas, r, wings, k.t);

  // ── 발 ──
  for (final sx in [-1.0, 1.0]) {
    final fc = Offset(sx * r * 0.44, r * 0.86 + sx * step * r * 0.07);
    final rect = Rect.fromCenter(center: fc, width: r * 0.72, height: r * 0.44);
    if (rocket != null) {
      _paintRocketBoot(canvas, rect, r, rocket, k.t, k.moving);
    } else if (sneakers != null) {
      _paintShoe(canvas, rect, r, sneakers == 'sneakers_neon' ? const Color(0xFFB6F23A) : Colors.white,
          sneakers == 'sneakers_neon' ? const Color(0xFF111827) : const Color(0xFFE5484D), studs: false);
    } else if (boots != null) {
      _paintShoe(canvas, rect, r, boots == 'boots_orange' ? const Color(0xFFFF7A1A) : const Color(0xFF1F2937),
          Colors.white, studs: true);
    } else {
      canvas.drawOval(rect, Paint()..color = dark);
    }
  }

  // ── 몸 — 맞으면 납작해졌다 돌아온다 ──
  canvas.save();
  if (k.squash > 0) {
    canvas.translate(0, r);
    canvas.scale(1 + 0.18 * k.squash, 1 - 0.24 * k.squash);
    canvas.translate(0, -r);
  }
  canvas.drawCircle(Offset.zero, r, Paint()
    ..shader = ui.Gradient.radial(Offset(-r * 0.35, -r * 0.4), r * 1.5, [light, body, dark], const [0, 0.55, 1]));
  canvas.drawCircle(Offset.zero, r, Paint()
    ..color = _shade(body, -0.28).withValues(alpha: 0.6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(1.0, r * 0.06));
  // 하이라이트
  canvas.drawOval(Rect.fromCenter(center: Offset(-r * 0.38, -r * 0.5), width: r * 0.42, height: r * 0.26),
      Paint()..color = Colors.white.withValues(alpha: 0.45));

  _paintFace(canvas, r, k);
  canvas.restore();

  // ── 손 ──
  for (final sx in [-1.0, 1.0]) {
    final hc = Offset(sx * r * 0.98, r * 0.14 - (k.moving ? step * sx : 0) * r * 0.06);
    if (gloves != null) {
      _paintGlove(canvas, hc, r, gloves, sx);
    } else {
      canvas.drawCircle(hc, r * 0.27, Paint()..color = light);
      canvas.drawCircle(hc, r * 0.27, Paint()
        ..color = _shade(body, -0.28).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, r * 0.05));
    }
  }

  // ── 머리 ──
  if (band != null) _paintBand(canvas, r, band, k.t);
  if (cap != null) _paintCap(canvas, r, cap == 'cap_red' ? const Color(0xFFE5484D) : const Color(0xFF2F6FE4));

  canvas.restore();
}

/// 그림 버전 — 몸통 그림(손발이 붙은 동그란 몸) 위에 표정·장비 그림을 겹친다.
/// 기준: 머리(동그란 부분) 가운데가 [center], 머리 반지름 ≈ r.
void _paintZonberArt(Canvas canvas, Offset center, double r, ZonberLook k, String? Function(String) gearOf) {
  final bodyName = 'body_${k.body}';
  final w = r * 2.6; // 몸통 그림 폭(머리 폭 ≈ 0.8w ≈ 2r)
  final h = w * GameArt.aspect(bodyName);
  final step = k.moving ? sin(k.t * 16) : 0.0;
  final bob = k.moving ? -step.abs() * r * 0.06 : sin(k.t * 3) * r * 0.03;

  final wings = gearOf('wings_');
  final rocket = gearOf('rocket_');
  final sneakers = gearOf('sneakers_');
  final boots = gearOf('boots_');
  final gloves = gearOf('gloves_');
  final band = gearOf('band_');
  final cap = gearOf('cap_');

  canvas.save();
  canvas.translate(center.dx, center.dy + bob);
  if (k.squash > 0) {
    canvas.translate(0, h * 0.5);
    canvas.scale(1 + 0.18 * k.squash, 1 - 0.24 * k.squash);
    canvas.translate(0, -h * 0.5);
  }
  final bodyC = Offset(0, h * 0.14); // 몸통 그림 가운데(머리 가운데보다 아래)

  // 등 — 날개(펄럭)·로켓
  if (wings != null) {
    final flap = sin(k.t * 9) * 0.22;
    for (final sx in [-1.0, 1.0]) {
      GameArt.draw(canvas, 'gear_$wings', Offset(sx * w * 0.44, -h * 0.02), w * 0.5,
          rotation: sx * (-0.15 + flap), flipX: sx < 0);
    }
  }
  if (rocket != null) {
    GameArt.draw(canvas, 'gear_$rocket', Offset(w * 0.36, h * 0.2), w * 0.42, rotation: 0.35);
  }

  // 몸통
  GameArt.draw(canvas, bodyName, bodyC, w);

  // 발 — 운동화(한 짝 그림을 좌우로) · 축구화(한 쌍 그림)
  final footY = h * 0.52;
  if (sneakers != null) {
    for (final sx in [-1.0, 1.0]) {
      GameArt.draw(canvas, 'gear_$sneakers', Offset(sx * w * 0.2, footY + sx * step * r * 0.06), w * 0.34, flipX: sx < 0);
    }
  } else if (boots != null) {
    GameArt.draw(canvas, 'gear_$boots', Offset(0, footY), w * 0.5);
  }

  // 얼굴 — 머리 가운데
  final face = switch (k.face) {
    ZonberFace.hurt => 'face_hurt',
    ZonberFace.happy => 'face_happy',
    ZonberFace.normal => 'face_normal',
  };
  final lx = k.look.dx.clamp(-1.0, 1.0) * r * 0.06;
  final ly = k.look.dy.clamp(-1.0, 1.0) * r * 0.05;
  GameArt.draw(canvas, face, Offset(lx, r * 0.12 + ly), r * 1.3);

  // 손 — 장갑(한 짝 그림을 좌우로)
  if (gloves != null) {
    for (final sx in [-1.0, 1.0]) {
      GameArt.draw(canvas, 'gear_$gloves', Offset(sx * w * 0.41, h * 0.3 - (k.moving ? step * sx : 0) * r * 0.05), w * 0.28,
          flipX: sx > 0);
    }
  }

  // 머리 — 머리띠·모자
  if (band != null) GameArt.draw(canvas, 'gear_$band', Offset(0, -r * 0.62), w * 0.86);
  if (cap != null) GameArt.draw(canvas, 'gear_$cap', Offset(r * 0.05, -r * 0.72), w * 0.84);

  canvas.restore();
}

void _paintFace(Canvas canvas, double r, ZonberLook k) {
  final ink = Paint()..color = const Color(0xFF1B1B2F);
  final lx = k.look.dx.clamp(-1.0, 1.0) * r * 0.05;
  final ly = k.look.dy.clamp(-1.0, 1.0) * r * 0.04;
  // 볼
  for (final sx in [-1.0, 1.0]) {
    canvas.drawOval(Rect.fromCenter(center: Offset(sx * r * 0.52, r * 0.16), width: r * 0.3, height: r * 0.16),
        Paint()..color = const Color(0xFFFF7AA8).withValues(alpha: 0.55));
  }
  switch (k.face) {
    case ZonberFace.normal:
      // 세로로 긴 눈 + 흰 반짝임 · 작은 웃는 입
      for (final sx in [-1.0, 1.0]) {
        final e = Offset(sx * r * 0.24 + lx, -r * 0.12 + ly);
        canvas.drawOval(Rect.fromCenter(center: e, width: r * 0.17, height: r * 0.34), ink);
        canvas.drawOval(Rect.fromCenter(center: e + Offset(0, -r * 0.07), width: r * 0.09, height: r * 0.12),
            Paint()..color = Colors.white);
      }
      canvas.drawArc(Rect.fromCenter(center: Offset(0, r * 0.2), width: r * 0.26, height: r * 0.18), 0.2, pi - 0.4, false,
          Paint()
            ..color = const Color(0xFF1B1B2F)
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = max(1.0, r * 0.06));
      break;
    case ZonberFace.hurt:
      // >< 눈 · 오므린 입
      final p = Paint()
        ..color = const Color(0xFF1B1B2F)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = max(1.2, r * 0.08);
      for (final sx in [-1.0, 1.0]) {
        final e = Offset(sx * r * 0.25, -r * 0.1);
        canvas.drawLine(e + Offset(-sx * r * 0.1, -r * 0.1), e + Offset(sx * r * 0.08, 0), p);
        canvas.drawLine(e + Offset(sx * r * 0.08, 0), e + Offset(-sx * r * 0.1, r * 0.1), p);
      }
      canvas.drawOval(Rect.fromCenter(center: Offset(0, r * 0.26), width: r * 0.16, height: r * 0.2), ink);
      break;
    case ZonberFace.happy:
      // ^^ 눈 · 크게 벌린 입
      final p = Paint()
        ..color = const Color(0xFF1B1B2F)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = max(1.2, r * 0.08);
      for (final sx in [-1.0, 1.0]) {
        canvas.drawArc(Rect.fromCenter(center: Offset(sx * r * 0.25, -r * 0.06), width: r * 0.26, height: r * 0.24), pi + 0.25,
            pi - 0.5, false, p);
      }
      final mouth = Path()
        ..moveTo(-r * 0.18, r * 0.12)
        ..quadraticBezierTo(0, r * 0.46, r * 0.18, r * 0.12)
        ..close();
      canvas.drawPath(mouth, Paint()..color = const Color(0xFF7A1F2B));
      canvas.drawOval(Rect.fromCenter(center: Offset(0, r * 0.28), width: r * 0.16, height: r * 0.08),
          Paint()..color = const Color(0xFFFF6B81));
      break;
  }
}

// ── 장비 그림 ─────────────────────────────────────────────────

void _paintWings(Canvas canvas, double r, String id, double t) {
  final flap = sin(t * 9) * 0.22;
  final fill = switch (id) {
    'wings_gold' => const Color(0xFFFFD66B),
    'wings_star' => const Color(0xFFBFE3FF),
    _ => Colors.white,
  };
  final edge = switch (id) {
    'wings_gold' => const Color(0xFFB8860B),
    'wings_star' => const Color(0xFF4F8FE8),
    _ => const Color(0xFF94A3B8),
  };
  for (final sx in [-1.0, 1.0]) {
    canvas.save();
    canvas.translate(sx * r * 0.7, -r * 0.25);
    canvas.rotate(sx * (-0.35 + flap));
    // 깃털 세 장
    for (int i = 0; i < 3; i++) {
      final fr = Rect.fromCenter(
          center: Offset(sx * r * (0.42 + i * 0.12), -r * 0.12 + i * r * 0.2), width: r * (0.95 - i * 0.18), height: r * 0.34);
      canvas.drawOval(fr, Paint()..color = fill);
      canvas.drawOval(fr, Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, r * 0.05));
    }
    if (id == 'wings_star') {
      canvas.drawCircle(Offset(sx * r * 0.6, -r * 0.2), r * 0.06, Paint()..color = Colors.white);
    }
    canvas.restore();
  }
}

void _paintRocketBoot(Canvas canvas, Rect rect, double r, String id, double t, bool moving) {
  final plasma = id == 'rocket_plasma';
  // 불꽃 — 발밑으로 뿜는다(움직이면 길게)
  final len = r * (moving ? 0.55 : 0.3) * (0.85 + 0.15 * sin(t * 30));
  final flame = Path()
    ..moveTo(rect.left + rect.width * 0.2, rect.bottom - r * 0.05)
    ..quadraticBezierTo(rect.center.dx, rect.bottom + len * 1.6, rect.right - rect.width * 0.2, rect.bottom - r * 0.05)
    ..close();
  canvas.drawPath(flame, Paint()
    ..shader = ui.Gradient.linear(Offset(0, rect.bottom), Offset(0, rect.bottom + len * 1.4), plasma
        ? [const Color(0xFFE0F2FE), const Color(0xFF38BDF8), const Color(0x00A855F7)]
        : [const Color(0xFFFFF3A0), const Color(0xFFFF8A3D), const Color(0x00E5334D)], const [0, 0.5, 1]));
  final boot = RRect.fromRectAndRadius(rect, Radius.circular(r * 0.2));
  canvas.drawRRect(boot, Paint()..color = plasma ? const Color(0xFF6D5BD0) : const Color(0xFFE5484D));
  canvas.drawRect(Rect.fromLTWH(rect.left, rect.bottom - rect.height * 0.35, rect.width, rect.height * 0.35),
      Paint()..color = const Color(0xFF9CA3AF));
  canvas.drawRRect(boot, Paint()
    ..color = Colors.black.withValues(alpha: 0.35)
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(0.8, r * 0.05));
}

void _paintShoe(Canvas canvas, Rect rect, double r, Color main, Color accent, {required bool studs}) {
  final shoe = RRect.fromRectAndRadius(rect, Radius.circular(r * 0.22));
  canvas.drawRRect(shoe, Paint()..color = main);
  // 줄무늬
  canvas.drawLine(Offset(rect.left + rect.width * 0.25, rect.top + rect.height * 0.3),
      Offset(rect.right - rect.width * 0.25, rect.top + rect.height * 0.55), Paint()
        ..color = accent
        ..strokeWidth = max(1.0, r * 0.08)
        ..strokeCap = StrokeCap.round);
  // 밑창
  canvas.drawRect(Rect.fromLTWH(rect.left + r * 0.04, rect.bottom - rect.height * 0.22, rect.width - r * 0.08, rect.height * 0.22),
      Paint()..color = studs ? const Color(0xFF374151) : const Color(0xFFE5E7EB));
  if (studs) {
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(rect.left + rect.width * (0.25 + i * 0.25), rect.bottom + r * 0.02), r * 0.04,
          Paint()..color = Colors.white);
    }
  }
  canvas.drawRRect(shoe, Paint()
    ..color = Colors.black.withValues(alpha: 0.35)
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(0.8, r * 0.05));
}

void _paintGlove(Canvas canvas, Offset c, double r, String id, double sx) {
  final (Color main, Color palm) = switch (id) {
    'gloves_gold' => (const Color(0xFFFFD66B), const Color(0xFFB8860B)),
    'gloves_pro' => (const Color(0xFF111827), const Color(0xFFB6F23A)),
    _ => (Colors.white, const Color(0xFF22C55E)),
  };
  final rect = Rect.fromCenter(center: c + Offset(sx * r * 0.04, 0), width: r * 0.62, height: r * 0.7);
  final g = RRect.fromRectAndRadius(rect, Radius.circular(r * 0.26));
  canvas.drawRRect(g, Paint()..color = main);
  // 손목 밴드
  canvas.drawRect(Rect.fromLTWH(rect.left, rect.bottom - rect.height * 0.28, rect.width, rect.height * 0.28),
      Paint()..color = palm);
  // 엄지
  canvas.drawOval(Rect.fromCenter(center: c + Offset(-sx * r * 0.26, -r * 0.02), width: r * 0.22, height: r * 0.3),
      Paint()..color = main);
  canvas.drawRRect(g, Paint()
    ..color = Colors.black.withValues(alpha: 0.35)
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(0.8, r * 0.05));
}

void _paintBand(Canvas canvas, double r, String id, double t) {
  final col = switch (id) {
    'band_blue' => const Color(0xFF2F8CF2),
    'band_flame' => const Color(0xFFFF7A1A),
    _ => const Color(0xFFE5484D),
  };
  // 이마를 두르는 띠
  canvas.save();
  canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r * 1.01)));
  canvas.drawRect(Rect.fromLTWH(-r, -r * 0.62, r * 2, r * 0.24), Paint()..color = col);
  canvas.drawRect(Rect.fromLTWH(-r * 0.12, -r * 0.62, r * 0.24, r * 0.24), Paint()..color = Colors.white.withValues(alpha: 0.85));
  canvas.restore();
  // 매듭 끝자락 두 가닥 — 바람에 날린다
  final knot = Offset(r * 0.9, -r * 0.5);
  for (int i = 0; i < 2; i++) {
    final wave = sin(t * 10 + i * 1.7) * r * 0.12;
    final end = knot + Offset(r * (0.55 + i * 0.12), r * (0.02 + i * 0.22) + wave);
    canvas.drawLine(knot, end, Paint()
      ..color = col
      ..strokeWidth = r * 0.16
      ..strokeCap = StrokeCap.round);
    if (id == 'band_flame') {
      canvas.drawCircle(end, r * 0.14 + sin(t * 18 + i) * r * 0.03, Paint()
        ..color = const Color(0xFFFFD23F)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.06));
    }
  }
}

void _paintCap(Canvas canvas, double r, Color col) {
  // 모자 — 머리 위 반구 + 앞으로 나온 챙
  final dome = Rect.fromCenter(center: Offset(0, -r * 0.55), width: r * 1.5, height: r * 1.0);
  canvas.save();
  canvas.clipRect(Rect.fromLTRB(-r * 2, -r * 2, r * 2, -r * 0.55));
  canvas.drawOval(dome, Paint()..color = col);
  canvas.restore();
  canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(r * 0.18, -r * 0.55), width: r * 1.7, height: r * 0.18),
          Radius.circular(r * 0.09)),
      Paint()..color = _shade(col, -0.15));
  canvas.drawCircle(Offset(0, -r * 1.05), r * 0.08, Paint()..color = _shade(col, -0.15));
}

/// 위젯용 — 정적인 존버(아바타·상점 카드)
class ZonberPainter extends CustomPainter {
  final ZonberLook look;
  const ZonberPainter(this.look);

  @override
  void paint(Canvas canvas, Size size) {
    // 손·발·장비가 삐져나오는 만큼 몸을 작게(캔버스의 약 30% 반지름)
    final r = min(size.width, size.height) * 0.3;
    paintZonber(canvas, Offset(size.width / 2, size.height * 0.46), r, look);
  }

  @override
  bool shouldRepaint(covariant ZonberPainter old) =>
      old.look.color != look.color || old.look.face != look.face || old.look.t != look.t || old.look.gear != look.gear ||
      old.look.body != look.body;
}
