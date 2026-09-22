import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'game_art.dart';
import 'gear.dart';
import 'gear_painter.dart';

// ─────────────────────────────────────────────────────────────
// 존버 — 동글동글한 메인 캐릭터(코드로 그린다, 이미지 없음). docs/CHARACTER_CONCEPT.md
// 찹쌀떡 몸(아래가 약간 납작) · 머리 위 한 가닥 · 반쯤 감은 눈 · 작은 손 · 짧은 발. 캐릭터마다 몸 색만 다르다.
// 커비와 겹치지 않게: 세로 타원 눈·볼터치·완전한 원형 몸은 쓰지 않는다(2026-09-22 시안 A 확정).
// 존 장비(gear.dart)는 gear_painter.dart 가 부위별로 겹쳐 그린다: 등 → 몸·얼굴 → 발 → 손 → 머리.
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
  /// 몸통 스킨(cosmetics.dart skin_*). null·skin_none 이면 캐릭터 색
  final String? skin;
  const ZonberLook({
    required this.color,
    this.body,
    this.skin,
    this.face = ZonberFace.normal,
    this.gear = const [],
    this.t = 0,
    this.moving = false,
    this.squash = 0,
    this.look = Offset.zero,
  });
}

const Color _ink = Color(0xFF1F2A44);

/// 찹쌀떡 몸 윤곽 — 가로 ±1.06r, 위 -0.92r, 아래 0.96r
Path mochiPath(double r) => Path()
  ..moveTo(-1.06 * r, 0.36 * r)
  ..cubicTo(-1.06 * r, -0.62 * r, -0.56 * r, -0.92 * r, 0, -0.92 * r)
  ..cubicTo(0.56 * r, -0.92 * r, 1.06 * r, -0.62 * r, 1.06 * r, 0.36 * r)
  ..cubicTo(1.06 * r, 0.84 * r, 0.68 * r, 0.96 * r, 0, 0.96 * r)
  ..cubicTo(-0.68 * r, 0.96 * r, -1.06 * r, 0.84 * r, -1.06 * r, 0.36 * r)
  ..close();

Paint _outline(double r) => Paint()
  ..color = _ink
  ..style = PaintingStyle.stroke
  ..strokeJoin = StrokeJoin.round
  ..strokeWidth = max(1.0, r * 0.08);

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

  if (k.body != null && GameArt.img('body_${k.body}') != null) {
    _paintZonberArt(canvas, center, r, k, gearOf);
    return;
  }

  // 부위별 장착 장비(gear_painter.dart 가 그린다)
  String? back, head, hands, feet;
  for (final id in k.gear) {
    switch (Gear.byId(id)?.slot) {
      case GearSlot.back:
        back = id;
      case GearSlot.head:
        head = id;
      case GearSlot.hands:
        hands = id;
      case GearSlot.feet:
        feet = id;
      case null:
        break;
    }
  }

  // 손·발·머리 한 가닥은 스킨의 대표 색으로
  final body = skinPartColor(k.skin, k.color, k.t);
  final step = k.moving ? sin(k.t * 16) : 0.0;
  // 몸·손·머리는 통통 튀고(걸음) 숨 쉬듯 움직인다 — 발은 땅에 붙어 있다
  final bob = k.moving ? -step.abs() * r * 0.07 : sin(k.t * 3) * r * 0.025;

  canvas.save();
  canvas.translate(center.dx, center.dy);
  // 맞으면 발밑을 기준으로 장비까지 통째로 납작해졌다 돌아온다
  if (k.squash > 0) {
    canvas.translate(0, r * 1.15);
    canvas.scale(1 + 0.18 * k.squash, 1 - 0.24 * k.squash);
    canvas.translate(0, -r * 1.15);
  }

  canvas.save();
  canvas.translate(0, bob);
  // ── 등 ──
  if (back != null) paintGearBack(canvas, r, back, k.t);
  // ── 머리 위 한 가닥(모자류를 쓰면 숨긴다) ──
  if (head == null || !gearHidesTuft(head)) {
    final tuft = Path()
      ..moveTo(0.02 * r, -0.86 * r)
      ..cubicTo(-0.04 * r, -1.25 * r, 0.33 * r, -1.4 * r, 0.44 * r, -1.18 * r)
      ..cubicTo(0.3 * r, -1.22 * r, 0.14 * r, -1.1 * r, 0.24 * r, -0.88 * r)
      ..close();
    canvas.drawPath(tuft, Paint()..color = body);
    canvas.drawPath(tuft, _outline(r)..strokeWidth = max(1.0, r * 0.07));
  }
  // ── 몸 ──
  final mochi = mochiPath(r);
  _paintSkin(canvas, r, mochi, k.skin, k.color, k.t);
  canvas.drawPath(mochi, _outline(r));
  canvas.drawOval(Rect.fromCenter(center: Offset(-r * 0.46, -r * 0.46), width: r * 0.36, height: r * 0.2),
      Paint()..color = Colors.white.withValues(alpha: 0.4));
  _paintFace(canvas, r, k, _darkSkins.contains(k.skin) ? const Color(0xFFF5F3FF) : const Color(0xFF1B1B2F));
  canvas.restore();

  // ── 발 — 몸 아래에 짧게 보인다(신발을 신을 자리) ──
  for (final sx in [-1.0, 1.0]) {
    final fc = footAnchor(r, sx) + Offset(0, sx * step * r * 0.07);
    if (feet != null) {
      paintGearFoot(canvas, r, feet, fc, sx, k.t, k.moving);
    } else {
      paintBareFoot(canvas, r, fc, body);
    }
  }

  canvas.save();
  canvas.translate(0, bob);
  // ── 손 — 몸 옆에 작게 삐져나온다(장갑을 낄 자리) ──
  for (final sx in [-1.0, 1.0]) {
    final hc = handAnchor(r, sx) + Offset(0, -(k.moving ? step * sx : 0) * r * 0.06);
    if (hands != null) {
      paintGearHand(canvas, r, hands, hc, sx, body);
    } else {
      paintBareHand(canvas, r, hc, body);
    }
  }
  // ── 머리 ──
  if (head != null) paintGearHead(canvas, r, head, k.t);
  canvas.restore();

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

/// 어두운 스킨 — 얼굴을 밝은 색으로 그린다
const Set<String?> _darkSkins = {'skin_galaxy', 'skin_lava'};

/// 몸통 스킨의 대표 색 — 손·발·머리 한 가닥에 쓴다
Color skinPartColor(String? skin, Color base, double t) => switch (skin) {
      'skin_silver' => const Color(0xFFC3CCD8),
      'skin_gold' => const Color(0xFFF2C14E),
      'skin_rainbow' => HSVColor.fromAHSV(1, (t * 40) % 360, 0.55, 1).toColor(),
      'skin_galaxy' => const Color(0xFF4B3A8C),
      'skin_candy' => const Color(0xFFFF9EC7),
      'skin_ice' => const Color(0xFFA5DDF5),
      'skin_lava' => const Color(0xFF4A3036),
      _ => base,
    };

/// 아래쪽을 살짝 어둡게 — 평평한 무늬 스킨에 입체감
void _volume(Canvas c, double r, Path mochi) {
  c.drawPath(mochi, Paint()
    ..shader = ui.Gradient.radial(Offset(-r * 0.35, -r * 0.45), r * 1.7,
        [Colors.white.withValues(alpha: 0.18), Colors.transparent, Colors.black.withValues(alpha: 0.22)], const [0, 0.5, 1]));
}

/// 몸통 칠하기 — 기본은 캐릭터 색 그라데이션, 스킨이면 스킨 무늬
void _paintSkin(Canvas c, double r, Path mochi, String? skin, Color base, double t) {
  final b = mochi.getBounds();
  switch (skin) {
    case 'skin_silver':
    case 'skin_gold':
      // 금속 — 대각 그라데이션 + 천천히 지나가는 반사 띠
      final cols = skin == 'skin_gold'
          ? const [Color(0xFFFFF6C8), Color(0xFFF2C14E), Color(0xFFB7801A), Color(0xFFF6D776)]
          : const [Color(0xFFFFFFFF), Color(0xFFC3CCD8), Color(0xFF7D8A9E), Color(0xFFDDE3EB)];
      c.drawPath(mochi, Paint()..shader = ui.Gradient.linear(b.topLeft, b.bottomRight, cols, const [0, 0.4, 0.75, 1]));
      c.save();
      c.clipPath(mochi);
      final x = -r * 1.8 + ((t * 0.35) % 1.0) * r * 3.6;
      c.drawPath(
          Path()
            ..moveTo(x, -r)
            ..lineTo(x + r * 0.35, -r)
            ..lineTo(x - r * 0.25, r)
            ..lineTo(x - r * 0.6, r)
            ..close(),
          Paint()..color = Colors.white.withValues(alpha: 0.38));
      c.restore();
    case 'skin_rainbow':
      // 무지개 — 색이 천천히 흘러간다
      final h0 = (t * 40) % 360;
      c.drawPath(
          mochi,
          Paint()
            ..shader = ui.Gradient.linear(b.topLeft, b.bottomRight,
                [for (int i = 0; i < 6; i++) HSVColor.fromAHSV(1, (h0 + i * 60) % 360, 0.6, 1).toColor()],
                const [0, 0.2, 0.4, 0.6, 0.8, 1]));
      _volume(c, r, mochi);
    case 'skin_galaxy':
      // 은하 — 짙은 보라 바탕 · 분홍 성운 · 반짝이는 별
      c.drawPath(mochi, Paint()
        ..shader = ui.Gradient.radial(Offset(-r * 0.3, -r * 0.3), r * 1.5,
            const [Color(0xFF6D4DD6), Color(0xFF2A1F63), Color(0xFF0F0B2E)], const [0, 0.55, 1]));
      c.save();
      c.clipPath(mochi);
      c.drawCircle(Offset(r * 0.35, r * 0.35), r * 0.5,
          Paint()
            ..color = const Color(0x66FF6AD5)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.3));
      final rnd = Random(7);
      for (int i = 0; i < 14; i++) {
        final pos = Offset((rnd.nextDouble() * 2 - 1) * r, (rnd.nextDouble() * 2 - 1) * r * 0.9);
        final size = r * (0.025 + 0.03 * rnd.nextDouble());
        final tw = 0.5 + 0.5 * sin(t * 3 + i * 1.3);
        c.drawCircle(pos, size, Paint()..color = Colors.white.withValues(alpha: 0.35 + 0.65 * tw));
      }
      c.restore();
    case 'skin_candy':
      // 사탕 — 분홍 바탕에 흰 사선 줄무늬
      c.drawPath(mochi, Paint()..shader = ui.Gradient.linear(Offset(0, -r), Offset(0, r), const [Color(0xFFFFC2DC), Color(0xFFFF8CBF)]));
      c.save();
      c.clipPath(mochi);
      final stripe = Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.16;
      for (double d = -2.5; d <= 2.5; d += 0.5) {
        c.drawLine(Offset((d - 1) * r, -r * 1.1), Offset((d + 1) * r, r * 1.1), stripe);
      }
      c.restore();
      _volume(c, r, mochi);
    case 'skin_ice':
      // 얼음 — 투명한 하늘색 · 각진 반사면 · 금
      c.drawPath(mochi, Paint()
        ..shader = ui.Gradient.linear(b.topLeft, b.bottomRight, const [Color(0xFFEFFBFF), Color(0xFFA5DDF5), Color(0xFF5BB3DE)], const [0, 0.5, 1]));
      c.save();
      c.clipPath(mochi);
      final facet = Paint()..color = Colors.white.withValues(alpha: 0.35);
      c.drawPath(
          Path()
            ..moveTo(-r, -r * 0.2)
            ..lineTo(-r * 0.2, -r)
            ..lineTo(r * 0.1, -r)
            ..lineTo(-r, r * 0.2)
            ..close(),
          facet);
      c.drawPath(
          Path()
            ..moveTo(r * 0.2, r)
            ..lineTo(r, r * 0.1)
            ..lineTo(r, r * 0.4)
            ..lineTo(r * 0.5, r)
            ..close(),
          facet);
      c.drawPath(
          Path()
            ..moveTo(-r * 0.1, r * 0.25)
            ..lineTo(r * 0.2, -r * 0.05)
            ..lineTo(r * 0.55, -r * 0.5),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(0.8, r * 0.04));
      c.restore();
    case 'skin_lava':
      // 용암 — 검붉은 바위에 빛나는 균열(맥박처럼 밝아졌다 어두워진다)
      c.drawPath(mochi, Paint()
        ..shader = ui.Gradient.radial(Offset(-r * 0.3, -r * 0.3), r * 1.5, const [Color(0xFF5A3A40), Color(0xFF2E1D22)]));
      c.save();
      c.clipPath(mochi);
      final glow = 0.6 + 0.4 * sin(t * 3);
      final crack = Paint()
        ..color = Color.lerp(const Color(0xFFFF4D2E), const Color(0xFFFFC23D), glow)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, r * 0.07)
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      final halo = Paint()
        ..color = const Color(0xFFFF6A2E).withValues(alpha: 0.5 * glow)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.2
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.1);
      final cracks = [
        Path()
          ..moveTo(-r * 0.95, r * 0.2)
          ..lineTo(-r * 0.5, r * 0.35)
          ..lineTo(-r * 0.35, r * 0.75)
          ..moveTo(-r * 0.5, r * 0.35)
          ..lineTo(-r * 0.2, r * 0.18),
        Path()
          ..moveTo(r * 1.0, -r * 0.1)
          ..lineTo(r * 0.58, r * 0.15)
          ..lineTo(r * 0.62, r * 0.55)
          ..lineTo(r * 0.28, r * 0.9),
        Path()
          ..moveTo(-r * 0.2, -r * 0.9)
          ..lineTo(-r * 0.05, -r * 0.62)
          ..lineTo(-r * 0.32, -r * 0.5),
      ];
      for (final p in cracks) {
        c.drawPath(p, halo);
        c.drawPath(p, crack);
      }
      c.restore();
    default:
      c.drawPath(mochi, Paint()
        ..shader = ui.Gradient.radial(Offset(-r * 0.35, -r * 0.4), r * 1.6, [_shade(base, 0.16), base, _shade(base, -0.16)], const [0, 0.55, 1]));
  }
}

void _paintFace(Canvas canvas, double r, ZonberLook k, Color inkColor) {
  final ink = Paint()..color = inkColor;
  final lx = k.look.dx.clamp(-1.0, 1.0) * r * 0.05;
  final ly = k.look.dy.clamp(-1.0, 1.0) * r * 0.04;
  switch (k.face) {
    case ZonberFace.normal:
      // 반쯤 감은 눈(눈꺼풀 선 + 아래 반달) — 무심하게 버티는 표정 · 작은 입
      final lid = Paint()
        ..color = inkColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = max(1.2, r * 0.075);
      for (final sx in [-1.0, 1.0]) {
        final e = Offset(sx * r * 0.31 + lx, -r * 0.14 + ly);
        canvas.drawArc(Rect.fromCenter(center: e, width: r * 0.31, height: r * 0.28), 0, pi, true, ink);
        canvas.drawLine(e + Offset(-r * 0.19, 0), e + Offset(r * 0.19, 0), lid);
      }
      canvas.drawArc(Rect.fromCenter(center: Offset(0, r * 0.14), width: r * 0.24, height: r * 0.14), 0.2, pi - 0.4, false,
          Paint()
            ..color = inkColor
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = max(1.0, r * 0.06));
      break;
    case ZonberFace.hurt:
      // >< 눈 · 오므린 입
      final p = Paint()
        ..color = inkColor
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
        ..color = inkColor
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
