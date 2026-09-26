import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'gear.dart';
import 'gear_painter.dart';

// ─────────────────────────────────────────────────────────────
// 존버 — 동글동글한 메인 캐릭터(코드로 그린다, 이미지 없음). docs/CHARACTER_CONCEPT.md
// 찹쌀떡 몸(아래가 약간 납작) · 머리 위 한 가닥 · 반쯤 감은 눈 · 작은 손 · 짧은 발. 캐릭터마다 몸 색만 다르다.
// 커비와 겹치지 않게: 세로 타원 눈·볼터치·완전한 원형 몸은 쓰지 않는다(2026-09-22 시안 A 확정).
// 존 장비(gear.dart)는 gear_painter.dart 가 부위별로 겹쳐 그린다: 등 → 몸·얼굴 → 발 → 손 → 머리.
// 게임(Player)·아바타(CharacterAvatar)·상점 미리보기가 모두 이 함수를 쓴다.
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
  /// 몸통 스킨(cosmetics.dart skin_*). null·skin_none 이면 캐릭터 색
  final String? skin;
  /// 캐릭터 id(character_data.dart) — 평상시 표정이 캐릭터마다 다르다
  final String? charId;
  const ZonberLook({
    required this.color,
    this.skin,
    this.charId,
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

/// 어두운 스킨 — 얼굴을 밝은 색으로 그린다
const Set<String?> _darkSkins = {'skin_lava', 'skin_neon'};

/// 몸통 스킨의 대표 색 — 손·발·머리 한 가닥에 쓴다
Color skinPartColor(String? skin, Color base, double t) => switch (skin) {
      'skin_silver' => const Color(0xFFC3CCD8),
      'skin_gold' => const Color(0xFFF2C14E),
      'skin_rainbow' => HSVColor.fromAHSV(1, (t * 40) % 360, 0.55, 1).toColor(),
      'skin_galaxy' => const Color(0xFF8B78E0),
      'skin_candy' => const Color(0xFFFF9EC7),
      'skin_ice' => const Color(0xFFA5DDF5),
      'skin_lava' => const Color(0xFFB8392C),
      'skin_cloud' => const Color(0xFFF2F7FF),
      'skin_sunset' => const Color(0xFFFF9A6B),
      'skin_ocean' => const Color(0xFF3FA8D8),
      'skin_neon' => const Color(0xFF3B2C63),
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
      // 은하 — 연보라 바탕 · 분홍 성운 · 반짝이는 별(2026-09-22 너무 어두워 연하게)
      c.drawPath(mochi, Paint()
        ..shader = ui.Gradient.radial(Offset(-r * 0.3, -r * 0.3), r * 1.5,
            const [Color(0xFFC3B5FF), Color(0xFF8B78E0), Color(0xFF5A48B0)], const [0, 0.55, 1]));
      c.save();
      c.clipPath(mochi);
      c.drawCircle(Offset(r * 0.35, r * 0.35), r * 0.5,
          Paint()
            ..color = const Color(0x80FF8FE0)
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
    case 'skin_cloud':
      // 구름 — 몸 전체가 폭신한 뭉게구름. 흰 윗면 · 하늘빛 그늘이 진 몽글몽글한 아랫면(2026-09-26 얼룩져 보여 교체)
      c.drawPath(mochi, Paint()
        ..shader = ui.Gradient.linear(Offset(0, -r), Offset(0, r),
            const [Color(0xFFFFFFFF), Color(0xFFF3F7FF), Color(0xFFD3E3F8)], const [0, 0.5, 1]));
      c.save();
      c.clipPath(mochi);
      // 가장자리로 갈수록 살짝 푸르게 — 부푼 느낌
      c.drawPath(mochi, Paint()
        ..shader = ui.Gradient.radial(Offset(-r * 0.15, -r * 0.25), r * 1.25,
            [Colors.transparent, const Color(0xFFB7CFF0).withValues(alpha: 0.45)], const [0.6, 1]));
      // 아랫면 그늘 — 몽글몽글한 구름 배(천천히 흔들린다)
      final drift = sin(t * 0.8) * r * 0.05;
      final belly = Paint()
        ..color = const Color(0xFF9FBCEA).withValues(alpha: 0.75)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.03);
      for (int i = 0; i < 6; i++) {
        c.drawCircle(Offset(-r * 1.2 + i * r * 0.48 + drift, r * (i.isOdd ? 1.02 : 0.95)), r * 0.32, belly);
      }
      // 윗면 뭉게 볼록 — 흐린 흰 빛
      final puff = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12);
      for (final (px, py, ps) in const [(-0.55, -0.5, 0.3), (0.05, -0.7, 0.34), (0.6, -0.45, 0.28)]) {
        c.drawCircle(Offset(r * px, r * py), r * ps, puff);
      }
      c.restore();
    case 'skin_sunset':
      // 노을 — 보라에서 금빛으로 번지는 하늘 · 지는 해 · 구름 띠
      c.drawPath(mochi, Paint()
        ..shader = ui.Gradient.linear(Offset(0, -r), Offset(0, r),
            const [Color(0xFF4B3A8C), Color(0xFFFF7A6B), Color(0xFFFFC46B), Color(0xFFFFE9A8)], const [0, 0.42, 0.72, 1]));
      c.save();
      c.clipPath(mochi);
      c.drawCircle(Offset(r * 0.52, -r * 0.5), r * 0.22, Paint()..color = const Color(0xFFFFF3C4).withValues(alpha: 0.9));
      for (int i = 0; i < 3; i++) {
        final band = RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(-r * 0.3 + i * r * 0.3, r * (0.5 + i * 0.2)), width: r * (1.1 - 0.24 * i), height: r * 0.1),
            Radius.circular(r * 0.05));
        c.drawRRect(band, Paint()..color = const Color(0xFF6B2E63).withValues(alpha: 0.3));
      }
      c.restore();
      _volume(c, r, mochi);
    case 'skin_ocean':
      // 바다 — 물결이 천천히 지나간다
      c.drawPath(mochi, Paint()..shader = ui.Gradient.linear(Offset(0, -r), Offset(0, r), const [Color(0xFF7FE3F0), Color(0xFF1E7FB8)]));
      c.save();
      c.clipPath(mochi);
      final wave = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = max(1.0, r * 0.07);
      for (int i = 0; i < 4; i++) {
        final y = -r * 0.62 + i * r * 0.44;
        final path = Path()..moveTo(-r * 1.1, y);
        for (double x = -r * 1.1; x <= r * 1.1; x += r * 0.12) {
          path.lineTo(x, y + sin(x / r * 3 + t * 1.6 + i) * r * 0.07);
        }
        c.drawPath(path, wave);
      }
      c.restore();
      _volume(c, r, mochi);
    case 'skin_neon':
      // 네온 — 어두운 바탕에 격자가 시안↔핑크로 물든다
      c.drawPath(mochi, Paint()
        ..shader = ui.Gradient.radial(Offset(-r * 0.3, -r * 0.35), r * 1.6, const [Color(0xFF2B2150), Color(0xFF140E28)]));
      c.save();
      c.clipPath(mochi);
      final neon = 0.5 + 0.5 * sin(t * 2.2);
      final grid = Paint()
        ..color = Color.lerp(const Color(0xFF22D3EE), const Color(0xFFFF4D9D), neon)!.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.7, r * 0.035);
      for (int i = -2; i <= 2; i++) {
        if (i != 0) c.drawLine(Offset(i * r * 0.44, -r * 1.1), Offset(i * r * 0.62, r * 1.1), grid);
        c.drawLine(Offset(-r * 1.1, i * r * 0.42), Offset(r * 1.1, i * r * 0.42), grid);
      }
      c.drawCircle(Offset(r * 0.5, -r * 0.5), r * 0.12, Paint()
        ..color = const Color(0xFFFFF3A0).withValues(alpha: 0.35 + 0.4 * neon)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.1));
      c.restore();
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
      // 용암 — 위는 식은 검붉은 껍질, 아래로 갈수록 끓어오르는 주황 · 출렁이는 용암 물결 · 양옆으로 떠오르는 불씨
      // (2026-09-26 균열 무늬가 얼룩져 보여 교체)
      c.drawPath(mochi, Paint()
        ..shader = ui.Gradient.linear(Offset(0, -r), Offset(0, r),
            const [Color(0xFF3A1E2A), Color(0xFF6E2330), Color(0xFFC2402C), Color(0xFFFF8A3D)], const [0, 0.4, 0.72, 1]));
      c.save();
      c.clipPath(mochi);
      final glow = 0.5 + 0.5 * sin(t * 2.4);
      final lava = Path()..moveTo(-r * 1.2, r * 1.2);
      for (double x = -r * 1.2; x <= r * 1.2; x += r * 0.1) {
        lava.lineTo(x, r * 0.55 + sin(x / r * 3.2 + t * 1.8) * r * 0.06);
      }
      lava
        ..lineTo(r * 1.2, r * 1.2)
        ..close();
      c.drawPath(lava, Paint()
        ..color = const Color(0xFFFF7A2E).withValues(alpha: 0.35 + 0.3 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.16));
      c.drawPath(lava, Paint()
        ..shader = ui.Gradient.linear(Offset(0, r * 0.5), Offset(0, r), const [Color(0xFFFFA940), Color(0xFFFFE08A)]));
      // 불씨 — 얼굴을 피해 양옆으로 올라가며 사라진다
      for (int i = 0; i < 4; i++) {
        final p = (t * 0.35 + i * 0.27) % 1.0;
        final x = r * const [-0.78, -0.5, 0.52, 0.8][i] + sin(t * 1.5 + i * 2) * r * 0.05;
        c.drawCircle(Offset(x, r * 0.5 - p * r * 1.2), r * (0.055 - p * 0.025), Paint()
          ..color = const Color(0xFFFFC266).withValues(alpha: 0.9 * sin(p * pi))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.02));
      }
      c.restore();
    default:
      c.drawPath(mochi, Paint()
        ..shader = ui.Gradient.radial(Offset(-r * 0.35, -r * 0.4), r * 1.6, [_shade(base, 0.16), base, _shade(base, -0.16)], const [0, 0.55, 1]));
  }
}

// ─────────────────────────────────────────────────────────────
// 표정 — 캐릭터마다 셋(평소 · 아야 · 신남)이 다 다르다.
// 색만 다르면 스킨과 구분이 안 되므로, 표정이 곧 캐릭터의 성격이다.
//   민트 무심 · 잽 팔팔 · 루나 졸림 · 블레이즈 뾰로통 · 써니 해맑음 · 레이스 고혹 · 체리 사랑스러움 · 코코 아기
// ─────────────────────────────────────────────────────────────

void _paintFace(Canvas canvas, double r, ZonberLook k, Color inkColor) {
  final lx = k.look.dx.clamp(-1.0, 1.0) * r * 0.05;
  final ly = k.look.dy.clamp(-1.0, 1.0) * r * 0.04;
  final f = _FacePen(canvas, r, inkColor);
  switch (k.face) {
    case ZonberFace.normal:
      _normalFace(f, k.charId, lx, ly);
    case ZonberFace.hurt:
      _hurtFace(f, k.charId);
    case ZonberFace.happy:
      _happyFace(f, k.charId);
  }
}

/// 얼굴 부품 — 눈·눈썹·입을 같은 규칙으로 그린다(r = 몸 반지름)
class _FacePen {
  final Canvas c;
  final double r;
  final Color ink;
  _FacePen(this.c, this.r, this.ink);

  Paint get fill => Paint()..color = ink;

  Paint stroke([double w = 0.075]) => Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = max(1.0, r * w);

  /// 반쯤 감은 눈(아래 반달 + 눈꺼풀 선)
  void sleepyEyes(double lx, double ly) {
    for (final sx in [-1.0, 1.0]) {
      final e = Offset(sx * r * 0.31 + lx, -r * 0.14 + ly);
      c.drawArc(Rect.fromCenter(center: e, width: r * 0.31, height: r * 0.28), 0, pi, true, fill);
      c.drawLine(e + Offset(-r * 0.19, 0), e + Offset(r * 0.19, 0), stroke());
    }
  }

  /// 동그란 눈 + 반짝임. [lashes] 면 바깥쪽에 속눈썹이 붙는다
  void roundEyes({double size = 0.3, double dy = -0.14, double lx = 0, double ly = 0, bool lashes = false}) {
    for (final sx in [-1.0, 1.0]) {
      final e = Offset(sx * r * 0.31 + lx, r * dy + ly);
      c.drawOval(Rect.fromCenter(center: e, width: r * size, height: r * (size + 0.04)), fill);
      c.drawOval(Rect.fromCenter(center: e + Offset(-r * 0.05, -r * 0.05), width: r * 0.09, height: r * 0.09),
          Paint()..color = Colors.white.withValues(alpha: 0.9));
      c.drawOval(Rect.fromCenter(center: e + Offset(r * 0.04, r * 0.06), width: r * 0.05, height: r * 0.05),
          Paint()..color = Colors.white.withValues(alpha: 0.55));
      if (lashes) {
        for (int i = 0; i < 2; i++) {
          final a = e + Offset(sx * r * (size * 0.42 + 0.01), -r * (size * 0.28 - i * 0.09));
          c.drawLine(a, a + Offset(sx * r * 0.11, -r * (0.08 - i * 0.04)), stroke(0.05));
        }
      }
    }
  }

  /// ^ ^ 웃는 눈
  void archEyes({double dy = -0.08, double lx = 0}) {
    for (final sx in [-1.0, 1.0]) {
      c.drawArc(Rect.fromCenter(center: Offset(sx * r * 0.29 + lx, r * dy), width: r * 0.28, height: r * 0.24), pi + 0.25,
          pi - 0.5, false, stroke(0.08));
    }
  }

  /// 가늘게 뜬 실눈
  void slitEyes({double dy = -0.12, double lx = 0, double ly = 0, double w = 0.15}) {
    for (final sx in [-1.0, 1.0]) {
      final e = Offset(sx * r * 0.3 + lx, r * dy + ly);
      c.drawLine(e + Offset(-r * w, 0), e + Offset(r * w, 0), stroke(0.085));
    }
  }

  /// >< 질끈 감은 눈
  void squeezedEyes({double dy = -0.1}) {
    for (final sx in [-1.0, 1.0]) {
      final e = Offset(sx * r * 0.27, r * dy);
      c.drawLine(e + Offset(-sx * r * 0.1, -r * 0.1), e + Offset(sx * r * 0.08, 0), stroke(0.08));
      c.drawLine(e + Offset(sx * r * 0.08, 0), e + Offset(-sx * r * 0.1, r * 0.1), stroke(0.08));
    }
  }

  /// 아래로 처진 눈(슬픔)
  void sadEyes() {
    for (final sx in [-1.0, 1.0]) {
      c.drawArc(Rect.fromCenter(center: Offset(sx * r * 0.29, -r * 0.02), width: r * 0.28, height: r * 0.24), 0.25, pi - 0.5,
          false, stroke(0.08));
    }
  }

  /// 눈썹 — [tilt] 가 양수면 **안쪽이 내려온다(화남)**, 음수면 안쪽이 올라간다(당황·걱정)
  void brows(double tilt) {
    for (final sx in [-1.0, 1.0]) {
      final b = Offset(sx * r * 0.32, -r * 0.42);
      c.drawLine(b + Offset(-sx * r * 0.13, r * tilt), b + Offset(sx * r * 0.11, -r * tilt), stroke(0.065));
    }
  }

  void smile({double w = 0.24, double h = 0.14, double dy = 0.14}) {
    c.drawArc(Rect.fromCenter(center: Offset(0, r * dy), width: r * w, height: r * h), 0.2, pi - 0.4, false, stroke(0.06));
  }

  /// 아래로 휜 입(시무룩)
  void frown({double w = 0.24, double h = 0.14, double dy = 0.26}) {
    c.drawArc(Rect.fromCenter(center: Offset(0, r * dy), width: r * w, height: r * h), pi + 0.2, pi - 0.4, false, stroke(0.06));
  }

  void flatMouth({double w = 0.2, double dy = 0.18}) {
    c.drawLine(Offset(-r * w / 2, r * dy), Offset(r * w / 2, r * dy), stroke(0.06));
  }

  void openMouth({double w = 0.16, double h = 0.18, double dy = 0.2}) {
    c.drawOval(Rect.fromCenter(center: Offset(0, r * dy), width: r * w, height: r * h), fill);
  }

  /// ω 입
  void catMouth({double dy = 0.14}) {
    final p = Path()
      ..moveTo(-r * 0.14, r * dy)
      ..quadraticBezierTo(-r * 0.07, r * (dy + 0.12), 0, r * (dy + 0.01))
      ..quadraticBezierTo(r * 0.07, r * (dy + 0.12), r * 0.14, r * dy);
    c.drawPath(p, stroke(0.06));
  }

  /// 크게 벌린 웃는 입(혀까지)
  void grin() {
    final mouth = Path()
      ..moveTo(-r * 0.18, r * 0.12)
      ..quadraticBezierTo(0, r * 0.46, r * 0.18, r * 0.12)
      ..close();
    c.drawPath(mouth, Paint()..color = const Color(0xFF7A1F2B));
    c.drawOval(Rect.fromCenter(center: Offset(0, r * 0.28), width: r * 0.16, height: r * 0.08),
        Paint()..color = const Color(0xFFFF6B81));
  }

  /// 볼에 흐르는 땀 한 방울
  void sweat() {
    final p = Offset(r * 0.52, -r * 0.3);
    c.drawCircle(p, r * 0.07, Paint()..color = const Color(0xFF7DD3FC));
    c.drawCircle(p + Offset(-r * 0.02, -r * 0.02), r * 0.025, Paint()..color = Colors.white.withValues(alpha: 0.8));
  }

  /// 눈 밑 작은 점(졸림)
  void underDots() {
    for (final sx in [-1.0, 1.0]) {
      c.drawCircle(Offset(sx * r * 0.3, r * 0.02), max(0.8, r * 0.028), Paint()..color = ink.withValues(alpha: 0.45));
    }
  }

  /// 발그레한 볼 — 부드러운 분홍 위에 볼 선 두 줄(몸 색이 분홍·빨강이어도 보이게)
  void blush({double dy = 0.06, double w = 0.26, double alpha = 0.5}) {
    for (final sx in [-1.0, 1.0]) {
      final ctr = Offset(sx * r * 0.52, r * dy);
      c.drawOval(
          Rect.fromCenter(center: ctr, width: r * w, height: r * w * 0.62),
          Paint()
            ..color = const Color(0xFFFF5C8A).withValues(alpha: alpha * 0.9)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05));
      final line = Paint()
        ..color = ink.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = max(0.8, r * 0.032);
      for (int i = 0; i < 2; i++) {
        final x = ctr.dx + (i == 0 ? -r * 0.05 : r * 0.05);
        c.drawLine(Offset(x - r * 0.025, ctr.dy - r * 0.05), Offset(x + r * 0.025, ctr.dy + r * 0.05), line);
      }
    }
  }

  /// 속눈썹이 긴 눈 — 또렷한 눈매에 바깥쪽 속눈썹 두 가닥
  void lashEyes({double dy = -0.12, double lx = 0, double ly = 0}) {
    for (final sx in [-1.0, 1.0]) {
      final e = Offset(sx * r * 0.3 + lx, r * dy + ly);
      c.drawArc(Rect.fromCenter(center: e, width: r * 0.32, height: r * 0.28), pi + 0.12, pi - 0.24, false, stroke(0.085));
      c.drawCircle(e + Offset(0, r * 0.03), r * 0.06, fill);
      for (int i = 0; i < 2; i++) {
        final a = Offset(sx * r * (0.42 + i * 0.03), r * (dy - 0.05 + i * 0.06));
        c.drawLine(a, a + Offset(sx * r * 0.1, -r * 0.08), stroke(0.05));
      }
    }
  }

  /// 한쪽 윙크 — 왼눈은 감고 오른눈은 초롱초롱
  void winkEyes({double lx = 0}) {
    c.drawArc(Rect.fromCenter(center: Offset(-r * 0.29 + lx, -r * 0.1), width: r * 0.28, height: r * 0.24), pi + 0.25,
        pi - 0.5, false, stroke(0.08));
    final e = Offset(r * 0.31 + lx, -r * 0.13);
    c.drawOval(Rect.fromCenter(center: e, width: r * 0.3, height: r * 0.34), fill);
    c.drawOval(Rect.fromCenter(center: e + Offset(-r * 0.05, -r * 0.05), width: r * 0.1, height: r * 0.1),
        Paint()..color = Colors.white.withValues(alpha: 0.9));
  }

  /// 하트 눈
  void heartEyes({double size = 0.17}) {
    for (final sx in [-1.0, 1.0]) {
      final e = Offset(sx * r * 0.31, -r * 0.13);
      final hr = r * size;
      final p = Path()
        ..moveTo(e.dx, e.dy + hr * 0.9)
        ..cubicTo(e.dx - hr * 1.3, e.dy - hr * 0.1, e.dx - hr * 0.6, e.dy - hr * 1.1, e.dx, e.dy - hr * 0.35)
        ..cubicTo(e.dx + hr * 0.6, e.dy - hr * 1.1, e.dx + hr * 1.3, e.dy - hr * 0.1, e.dx, e.dy + hr * 0.9)
        ..close();
      c.drawPath(p, Paint()..color = const Color(0xFFFF4D79));
      c.drawCircle(e + Offset(-hr * 0.35, -hr * 0.32), hr * 0.2, Paint()..color = Colors.white.withValues(alpha: 0.85));
    }
  }

  /// 도톰한 입술 미소
  void lipSmile({double w = 0.26, double dy = 0.15}) {
    final rect = Rect.fromCenter(center: Offset(0, r * dy), width: r * w, height: r * w * 0.7);
    c.drawPath(Path()..addArc(rect, 0.1, pi - 0.2)..close(), Paint()..color = const Color(0xFFFF6B81).withValues(alpha: 0.8));
    c.drawArc(rect, 0.1, pi - 0.2, false, stroke(0.06));
  }

  /// 삐죽 내민 입(뾰로통)
  void pout({double dy = 0.2, double w = 0.1}) {
    final p = Path()
      ..moveTo(-r * w, r * dy)
      ..quadraticBezierTo(0, r * (dy - 0.13), r * w, r * dy);
    c.drawPath(p, stroke(0.07));
  }

  /// 눈물 한 방울
  void tear({double sx = 1}) {
    final p = Offset(sx * r * 0.42, r * 0.14);
    final path = Path()
      ..moveTo(p.dx, p.dy - r * 0.16)
      ..quadraticBezierTo(p.dx + r * 0.11, p.dy + r * 0.04, p.dx, p.dy + r * 0.13)
      ..quadraticBezierTo(p.dx - r * 0.11, p.dy + r * 0.04, p.dx, p.dy - r * 0.16)
      ..close();
    c.drawPath(path, Paint()..color = const Color(0xFF5FC8F5));
    c.drawPath(path, Paint()
      ..color = const Color(0xFF1B6C94).withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, r * 0.03));
    c.drawCircle(p + Offset(-r * 0.03, r * 0.02), r * 0.032, Paint()..color = Colors.white.withValues(alpha: 0.9));
  }
}

/// 평소 얼굴
void _normalFace(_FacePen f, String? id, double lx, double ly) {
  switch (id) {
    case 'electric_blue': // 잽 — 깨어 있는 눈 · 장난스러운 ω 입
      f.brows(-0.05);
      f.roundEyes(lx: lx, ly: ly);
      f.catMouth();
    case 'plasma_purple': // 루나 — 졸린 실눈 · 눈 밑 점 · 작은 미소
      f.slitEyes(lx: lx, ly: ly);
      f.underDots();
      f.smile(w: 0.18, h: 0.1);
    case 'cyber_red': // 블레이즈 — 발그레한 볼 · 동그란 눈 · 뾰로통한 입
      f.blush();
      f.roundEyes(size: 0.3, dy: -0.12, lx: lx, ly: ly);
      f.pout();
    case 'solar_gold': // 써니 — ^^ 눈 · 활짝 웃는 입
      f.archEyes(lx: lx);
      f.smile(w: 0.3, h: 0.26, dy: 0.12);
    case 'void_dark': // 레이스 — 긴 속눈썹 · 도톰한 입술
      f.lashEyes(lx: lx, ly: ly);
      f.lipSmile(w: 0.22);
    case 'blossom_pink': // 체리 — 속눈썹 달린 큰 눈 · 볼터치 · 입술 미소
      f.blush(alpha: 0.6);
      f.roundEyes(size: 0.32, dy: -0.13, lx: lx, ly: ly, lashes: true);
      f.lipSmile();
    case 'frost_cyan': // 코코 — 아주 큰 눈 · 볼터치 · ω 입
      f.blush(dy: 0.1, w: 0.24);
      f.roundEyes(size: 0.38, dy: -0.1, lx: lx, ly: ly);
      f.catMouth(dy: 0.2);
    default: // 민트 — 반쯤 감은 눈 · 작은 미소
      f.sleepyEyes(lx, ly);
      f.smile();
  }
}

/// 아야 — 맞았을 때. 캐릭터마다 아파하는 모양이 다르다
void _hurtFace(_FacePen f, String? id) {
  switch (id) {
    case 'electric_blue': // 잽 — 놀라서 눈이 커지고 땀
      f.brows(-0.08);
      f.roundEyes(size: 0.34, dy: -0.12);
      f.openMouth(w: 0.2, h: 0.22, dy: 0.24);
      f.sweat();
    case 'plasma_purple': // 루나 — 잠에서 깬 듯 반쯤 뜬 눈 · 시무룩
      f.slitEyes(dy: -0.08, w: 0.17);
      f.frown(w: 0.2, h: 0.12);
      f.sweat();
    case 'cyber_red': // 블레이즈 — 볼을 부풀리고 삐진다
      f.blush(alpha: 0.65);
      f.squeezedEyes();
      f.pout(dy: 0.24, w: 0.12);
    case 'solar_gold': // 써니 — 울상
      f.sadEyes();
      f.frown();
    case 'void_dark': // 레이스 — 눈을 내리깔고 입술을 깨문다
      f.lashEyes(dy: -0.06);
      f.frown(w: 0.2, h: 0.12);
    case 'blossom_pink': // 체리 — 눈물이 그렁그렁
      f.blush(alpha: 0.65);
      f.sadEyes();
      f.tear();
      f.frown(w: 0.2, h: 0.12);
    case 'frost_cyan': // 코코 — 앙 하고 크게 운다
      f.blush(dy: 0.1, w: 0.24, alpha: 0.65);
      f.squeezedEyes();
      f.openMouth(w: 0.22, h: 0.24, dy: 0.24);
      f.tear();
    default: // 민트 — >< 눈 · 오므린 입
      f.squeezedEyes();
      f.openMouth(dy: 0.26, h: 0.2);
  }
}

/// 신남 — 아슬아슬 회피·세이브. 캐릭터마다 좋아하는 모양이 다르다
void _happyFace(_FacePen f, String? id) {
  switch (id) {
    case 'electric_blue': // 잽 — 반짝이는 눈 · 활짝
      f.roundEyes(size: 0.32, dy: -0.12);
      f.grin();
    case 'plasma_purple': // 루나 — 살짝 뜬 눈 · ω 입
      f.slitEyes(dy: -0.14, w: 0.13);
      f.catMouth(dy: 0.16);
    case 'cyber_red': // 블레이즈 — 볼터치 그대로 배시시
      f.blush(alpha: 0.6);
      f.archEyes(dy: -0.1);
      f.smile(w: 0.3, h: 0.22, dy: 0.16);
    case 'solar_gold': // 써니 — ^^ 눈 · 크게 웃는 입
      f.archEyes();
      f.grin();
    case 'void_dark': // 레이스 — 윙크 한 번 · 입술 미소
      f.winkEyes();
      f.lipSmile(w: 0.24, dy: 0.17);
    case 'blossom_pink': // 체리 — 하트 눈 · 볼터치
      f.blush(alpha: 0.7);
      f.heartEyes();
      f.lipSmile(w: 0.28, dy: 0.17);
    case 'frost_cyan': // 코코 — ^^ 눈 · ω 입
      f.blush(dy: 0.1, w: 0.24, alpha: 0.6);
      f.archEyes(dy: -0.06);
      f.catMouth(dy: 0.18);
    default: // 민트 — ^^ 눈 · 크게 벌린 입
      f.archEyes(dy: -0.06);
      f.grin();
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
      old.look.color != look.color ||
      old.look.face != look.face ||
      old.look.charId != look.charId ||
      old.look.skin != look.skin ||
      old.look.t != look.t ||
      old.look.gear != look.gear;
}
