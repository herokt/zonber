import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'game_art.dart';

// ─────────────────────────────────────────────────────────────
// 꾸미기 — 몸통 스킨(skin) · 이동 잔상(trail) · 캐릭터 오라(aura). 코인으로 사고 종류마다 하나씩 착용한다.
// 스킨은 캐릭터와 상관없이 몸 전체를 덮는다(그림은 zonber_painter.dart 의 _paintSkin).
// 존별 장비(날개·머리띠·장갑 등)는 gear.dart. 전부 코드로 그린다(이미지 없음). 게임 판정에는 아무 영향이 없다. docs/SHOP.md
//
// 그리기 함수는 게임(Player)과 상점 미리보기가 같이 쓴다 — 보이는 그대로 산다.
// ─────────────────────────────────────────────────────────────

enum CosmeticKind { skin, trail, aura }

class Cosmetic {
  final String id;
  final CosmeticKind kind;
  /// 번역 키: cos_{id}
  String get nameKey => 'cos_$id';
  final int price; // 0 = 기본(무료)
  const Cosmetic(this.id, this.kind, this.price);
}

class Cosmetics {
  static const String defaultTrail = 'trail_basic';
  static const String defaultAura = 'aura_none';
  static const String defaultSkin = 'skin_none';

  static const List<Cosmetic> all = [
    // 몸통 스킨
    Cosmetic('skin_none', CosmeticKind.skin, 0),
    Cosmetic('skin_silver', CosmeticKind.skin, 400),
    Cosmetic('skin_candy', CosmeticKind.skin, 450),
    Cosmetic('skin_ice', CosmeticKind.skin, 500),
    Cosmetic('skin_gold', CosmeticKind.skin, 650),
    Cosmetic('skin_lava', CosmeticKind.skin, 700),
    Cosmetic('skin_galaxy', CosmeticKind.skin, 750),
    Cosmetic('skin_rainbow', CosmeticKind.skin, 900),
    // 잔상
    Cosmetic('trail_basic', CosmeticKind.trail, 0),
    Cosmetic('trail_sparkle', CosmeticKind.trail, 200),
    Cosmetic('trail_bubble', CosmeticKind.trail, 250),
    Cosmetic('trail_heart', CosmeticKind.trail, 300),
    Cosmetic('trail_flame', CosmeticKind.trail, 350),
    Cosmetic('trail_rainbow', CosmeticKind.trail, 500),
    // 오라
    Cosmetic('aura_none', CosmeticKind.aura, 0),
    Cosmetic('aura_ring', CosmeticKind.aura, 200),
    Cosmetic('aura_orbit', CosmeticKind.aura, 350),
    Cosmetic('aura_electric', CosmeticKind.aura, 450),
    Cosmetic('aura_halo', CosmeticKind.aura, 500),
    Cosmetic('aura_crown', CosmeticKind.aura, 700),
  ];

  static List<Cosmetic> ofKind(CosmeticKind k) => all.where((c) => c.kind == k).toList();

  static Cosmetic? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  static String kindKey(CosmeticKind k) => k.name;
  static String defaultOf(CosmeticKind k) => switch (k) {
        CosmeticKind.skin => defaultSkin,
        CosmeticKind.trail => defaultTrail,
        CosmeticKind.aura => defaultAura,
      };
}

// ── 잔상 입자 ────────────────────────────────────────────────

/// 잔상 입자 하나를 원점(0,0)에 그린다. [p] 수명 진행 0→1, [seed] 입자마다 고정 난수(모양·색 변주),
/// [base] 캐릭터 색, [scale] 크기 배수(미리보기용)
void paintTrailParticle(Canvas canvas, String trailId, double p, double seed, Color base, {double scale = 1}) {
  final fade = (1 - p).clamp(0.0, 1.0);
  switch (trailId) {
    case 'trail_sparkle' when GameArt.img('fx_sparkle') != null:
      GameArt.draw(canvas, 'fx_sparkle', Offset.zero, (14 + 6 * seed) * (0.5 + 0.5 * fade) * scale, opacity: fade);
      break;
    case 'trail_heart' when GameArt.img('fx_heart') != null:
      canvas.save();
      canvas.translate(0, -6 * p * scale);
      GameArt.draw(canvas, 'fx_heart', Offset.zero, (9 + 3 * seed) * (0.6 + 0.4 * fade) * scale, opacity: fade);
      canvas.restore();
      break;
    case 'trail_sparkle':
      // 별가루 — 네 갈래 반짝임, 금·흰색이 섞인다
      final c = seed < 0.5 ? const Color(0xFFFFE27A) : Colors.white;
      final r = (4.5 + 2 * seed) * (0.4 + 0.6 * fade) * scale;
      _star4(canvas, r, Paint()..color = c.withValues(alpha: fade));
      break;
    case 'trail_bubble':
      // 비눗방울 — 속이 빈 동그라미, 커지며 사라진다
      final r = (2.5 + 5 * p) * scale;
      canvas.drawCircle(Offset.zero, r, Paint()
        ..color = HSVColor.fromAHSV(1, 180 + 120 * seed, 0.35, 1).toColor().withValues(alpha: 0.8 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * scale);
      canvas.drawCircle(Offset(-r * 0.35, -r * 0.35), r * 0.22, Paint()..color = Colors.white.withValues(alpha: 0.7 * fade));
      break;
    case 'trail_heart':
      // 하트 — 분홍 하트가 살짝 떠오른다
      final r = (4 + 1.5 * seed) * (0.5 + 0.5 * fade) * scale;
      canvas.save();
      canvas.translate(0, -6 * p * scale);
      _heart(canvas, r, Paint()..color = Color.lerp(const Color(0xFFFF5C8A), const Color(0xFFFF9EC0), seed)!.withValues(alpha: fade));
      canvas.restore();
      break;
    case 'trail_flame':
      // 불꽃 — 노랑 → 주황 → 빨강으로 식으며 줄어든다
      final col = p < 0.35
          ? Color.lerp(const Color(0xFFFFF3A0), const Color(0xFFFFA62B), p / 0.35)!
          : Color.lerp(const Color(0xFFFFA62B), const Color(0xFFE5334D), (p - 0.35) / 0.65)!;
      final r = (5.5 * (1 - p * 0.7)) * scale;
      canvas.drawCircle(Offset.zero, r, Paint()
        ..color = col.withValues(alpha: 0.9 * fade)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.2 * scale));
      break;
    case 'trail_rainbow':
      // 무지개 — 입자마다 색상이 돌아간다
      final col = HSVColor.fromAHSV(1, (seed * 360) % 360, 0.75, 1).toColor();
      canvas.drawCircle(Offset.zero, 3.6 * (0.4 + 0.6 * fade) * scale, Paint()..color = col.withValues(alpha: 0.9 * fade));
      break;
    default:
      // 기본 — 캐릭터 색 점
      canvas.drawCircle(Offset.zero, 3 * fade * scale, Paint()
        ..color = base.withValues(alpha: 0.85 * fade)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 * scale));
  }
}

void _star4(Canvas canvas, double r, Paint paint) {
  final path = Path()
    ..moveTo(0, -r)
    ..quadraticBezierTo(0, 0, r, 0)
    ..quadraticBezierTo(0, 0, 0, r)
    ..quadraticBezierTo(0, 0, -r, 0)
    ..quadraticBezierTo(0, 0, 0, -r)
    ..close();
  canvas.drawPath(path, paint);
}

void _heart(Canvas canvas, double r, Paint paint) {
  final path = Path()
    ..moveTo(0, r * 0.9)
    ..cubicTo(-r * 1.3, -r * 0.1, -r * 0.6, -r * 1.1, 0, -r * 0.35)
    ..cubicTo(r * 0.6, -r * 1.1, r * 1.3, -r * 0.1, 0, r * 0.9)
    ..close();
  canvas.drawPath(path, paint);
}

// ── 오라 ─────────────────────────────────────────────────────

/// 캐릭터 둘레의 오라를 [center] 기준으로 그린다. [r] 캐릭터 반지름, [t] 경과 시간(초).
/// [front] false = 캐릭터 뒤(먼저 그림), true = 앞(나중에 그림). 왕관·고리처럼 위에 얹히는 건 앞에.
void paintAura(Canvas canvas, String auraId, Offset center, double r, double t, Color base, {required bool front}) {
  if (_paintAuraArt(canvas, auraId, center, r, t, front)) return;
  switch (auraId) {
    case 'aura_ring':
      if (front) return;
      // 네온 링 — 캐릭터 색 고리가 숨 쉬듯 커졌다 작아진다
      final pulse = 0.5 + 0.5 * sin(t * 4);
      final rr = r + 4 + 2 * pulse;
      canvas.drawCircle(center, rr, Paint()
        ..color = base.withValues(alpha: 0.35 + 0.25 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
      canvas.drawCircle(center, rr, Paint()
        ..color = base.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4);
      break;
    case 'aura_orbit':
      // 궤도 위성 — 작은 구슬 두 개가 비스듬한 궤도를 돈다(앞쪽 반은 캐릭터 앞에)
      for (int i = 0; i < 2; i++) {
        final a = t * 3 + i * pi;
        final isFront = sin(a) > 0;
        if (isFront != front) continue;
        final p = center + Offset(cos(a) * (r + 7), sin(a) * (r + 7) * 0.45);
        canvas.drawCircle(p, 3.4, Paint()..color = (i == 0 ? const Color(0xFF7DD3FC) : const Color(0xFFFDE68A)));
        canvas.drawCircle(p + const Offset(-1, -1), 1.1, Paint()..color = Colors.white.withValues(alpha: 0.9));
      }
      if (!front) {
        canvas.drawOval(Rect.fromCenter(center: center, width: (r + 7) * 2, height: (r + 7) * 0.9), Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
      }
      break;
    case 'aura_electric':
      if (front) return;
      // 번개 — 들쭉날쭉한 파란 고리가 0.08초마다 모양을 바꾼다
      final rng = Random((t * 12).floor());
      final path = Path();
      const n = 18;
      for (int i = 0; i <= n; i++) {
        final a = i / n * 2 * pi;
        final rr = r + 5 + (rng.nextDouble() - 0.5) * 6;
        final pt = center + Offset(cos(a) * rr, sin(a) * rr);
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, Paint()
        ..color = const Color(0xFF60A5FA).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      canvas.drawPath(path, Paint()
        ..color = const Color(0xFFE0F2FE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2);
      break;
    case 'aura_halo':
      if (!front) {
        // 은은한 금빛 후광
        canvas.drawCircle(center, r + 6, Paint()
          ..shader = ui.Gradient.radial(center, r + 8, [const Color(0x55FFE08A), const Color(0x00FFE08A)]));
        return;
      }
      // 천사 고리 — 머리 위에 떠서 살짝 오르내린다
      final y = center.dy - r * 0.95 + sin(t * 2.5) * 1.5;
      final rect = Rect.fromCenter(center: Offset(center.dx, y), width: r * 1.3, height: r * 0.42);
      canvas.drawOval(rect, Paint()
        ..color = const Color(0xFFFFD66B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6);
      canvas.drawOval(rect, Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8);
      break;
    case 'aura_crown':
      if (!front) {
        // 반짝이 두 개가 둘레를 돈다
        for (int i = 0; i < 2; i++) {
          final a = t * 1.6 + i * pi;
          canvas.save();
          canvas.translate(center.dx + cos(a) * (r + 6), center.dy + sin(a) * (r + 6));
          _star4(canvas, 2.6 + sin(t * 6 + i) * 0.8, Paint()..color = const Color(0xFFFFE27A));
          canvas.restore();
        }
        return;
      }
      // 왕관 — 머리 위 금관(세 봉우리 + 보석)
      final w = r * 1.25, h = r * 0.62;
      final bx = center.dx - w / 2, by = center.dy - r * 0.78;
      final crown = Path()
        ..moveTo(bx, by)
        ..lineTo(bx + w * 0.12, by - h)
        ..lineTo(bx + w * 0.32, by - h * 0.45)
        ..lineTo(bx + w * 0.5, by - h * 1.1)
        ..lineTo(bx + w * 0.68, by - h * 0.45)
        ..lineTo(bx + w * 0.88, by - h)
        ..lineTo(bx + w, by)
        ..close();
      canvas.drawPath(crown, Paint()
        ..shader = ui.Gradient.linear(Offset(bx, by - h), Offset(bx, by), [const Color(0xFFFFE9A3), const Color(0xFFE0A21B)]));
      canvas.drawPath(crown, Paint()
        ..color = const Color(0xFF9A6A00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
      canvas.drawCircle(Offset(bx + w * 0.5, by - h * 0.35), 1.8, Paint()..color = const Color(0xFFE5484D));
      break;
    default:
      return; // aura_none
  }
}

/// 오라 그림(assets/images/game/fx_*) — 있으면 그림으로 그리고 true
bool _paintAuraArt(Canvas canvas, String auraId, Offset c, double r, double t, bool front) {
  switch (auraId) {
    case 'aura_ring':
      if (GameArt.img('fx_neon_ring') == null) return false;
      if (!front) {
        final pulse = 1 + 0.06 * sin(t * 4);
        GameArt.draw(canvas, 'fx_neon_ring', c + Offset(0, r * 0.9), r * 2.6 * pulse); // 발밑 고리
      }
      return true;
    case 'aura_orbit':
      if (GameArt.img('fx_planet') == null) return false;
      for (int i = 0; i < 2; i++) {
        final a = t * 2.5 + i * pi;
        if ((sin(a) > 0) != front) continue;
        GameArt.draw(canvas, 'fx_planet', c + Offset(cos(a) * r * 1.5, sin(a) * r * 0.55), r * 0.8);
      }
      return true;
    case 'aura_electric':
      if (GameArt.img('fx_bolt') == null) return false;
      if (front) {
        final k = (t * 6).floor();
        for (int i = 0; i < 3; i++) {
          final a = i * 2 * pi / 3 + k * 0.9;
          GameArt.draw(canvas, 'fx_bolt', c + Offset(cos(a), sin(a)) * r * 1.35, r * 0.55, rotation: a + pi / 2,
              opacity: 0.6 + 0.4 * ((k + i) % 2));
        }
      }
      return true;
    case 'aura_halo':
      if (GameArt.img('fx_halo') == null) return false;
      if (front) GameArt.draw(canvas, 'fx_halo', c + Offset(0, -r * 1.25 + sin(t * 2.5) * r * 0.06), r * 1.4);
      return true;
    case 'aura_crown':
      if (GameArt.img('fx_crown') == null) return false;
      if (front) GameArt.draw(canvas, 'fx_crown', c + Offset(0, -r * 1.2), r * 1.2);
      return true;
  }
  return false;
}

// ── 상점 미리보기 ─────────────────────────────────────────────

/// 상점 카드 미리보기 — 가운데 캐릭터(원)에 오라를 두르거나, 오른쪽→왼쪽으로 잔상을 흘린다.
class CosmeticPreview extends StatefulWidget {
  final Cosmetic item;
  final Color base;
  final Widget character;
  final double size;
  const CosmeticPreview({super.key, required this.item, required this.base, required this.character, this.size = 72});

  @override
  State<CosmeticPreview> createState() => _CosmeticPreviewState();
}

class _CosmeticPreviewState extends State<CosmeticPreview> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 1.6,
      height: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value * 6;
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(size: Size(s * 1.6, s), painter: _PreviewPainter(widget.item, widget.base, t, s, front: false)),
              SizedBox(width: s * 0.5, height: s * 0.5, child: child),
              CustomPaint(size: Size(s * 1.6, s), painter: _PreviewPainter(widget.item, widget.base, t, s, front: true)),
            ],
          );
        },
        child: widget.character,
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  final Cosmetic item;
  final Color base;
  final double t;
  final double s;
  final bool front;
  _PreviewPainter(this.item, this.base, this.t, this.s, {required this.front});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    if (item.kind == CosmeticKind.skin) return; // 스킨은 캐릭터 그림 자체(상점이 따로 그린다)
    if (item.kind == CosmeticKind.aura) {
      // 미리보기는 캐릭터가 작아서(지름 s*0.5) 오라도 같은 비율로 키운다
      canvas.save();
      canvas.translate(center.dx, center.dy);
      final k = (s * 0.25) / 18; // 게임 캐릭터 반지름 18 기준
      canvas.scale(k);
      paintAura(canvas, item.id, Offset.zero, 18, t, base, front: front);
      canvas.restore();
      return;
    }
    if (front) return;
    // 잔상 — 캐릭터 왼쪽으로 입자 9개가 흘러간다
    const n = 9;
    for (int i = 0; i < n; i++) {
      final p = ((t * 1.4 + i / n) % 1.0);
      final seed = ((i * 37) % 100) / 100.0;
      final x = center.dx - s * 0.2 - p * s * 0.55;
      final y = center.dy + sin(i * 1.7 + t * 3) * s * 0.08;
      canvas.save();
      canvas.translate(x, y);
      paintTrailParticle(canvas, item.id, p, seed, base, scale: s / 60);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) => true;
}
