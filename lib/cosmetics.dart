import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';


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
    Cosmetic('skin_cloud', CosmeticKind.skin, 350),
    Cosmetic('skin_silver', CosmeticKind.skin, 400),
    Cosmetic('skin_candy', CosmeticKind.skin, 450),
    Cosmetic('skin_sunset', CosmeticKind.skin, 450),
    Cosmetic('skin_ice', CosmeticKind.skin, 500),
    Cosmetic('skin_ocean', CosmeticKind.skin, 550),
    Cosmetic('skin_neon', CosmeticKind.skin, 600),
    Cosmetic('skin_gold', CosmeticKind.skin, 650),
    Cosmetic('skin_lava', CosmeticKind.skin, 700),
    Cosmetic('skin_galaxy', CosmeticKind.skin, 750),
    Cosmetic('skin_rainbow', CosmeticKind.skin, 900),
    // 잔상
    Cosmetic('trail_basic', CosmeticKind.trail, 0),
    Cosmetic('trail_sparkle', CosmeticKind.trail, 200),
    Cosmetic('trail_bubble', CosmeticKind.trail, 250),
    Cosmetic('trail_note', CosmeticKind.trail, 250),
    Cosmetic('trail_heart', CosmeticKind.trail, 300),
    Cosmetic('trail_petal', CosmeticKind.trail, 300),
    Cosmetic('trail_snow', CosmeticKind.trail, 350),
    Cosmetic('trail_flame', CosmeticKind.trail, 350),
    Cosmetic('trail_bolt', CosmeticKind.trail, 450),
    Cosmetic('trail_rainbow', CosmeticKind.trail, 500),
    // 오라
    Cosmetic('aura_none', CosmeticKind.aura, 0),
    Cosmetic('aura_ring', CosmeticKind.aura, 200),
    Cosmetic('aura_petal', CosmeticKind.aura, 300),
    Cosmetic('aura_orbit', CosmeticKind.aura, 350),
    Cosmetic('aura_electric', CosmeticKind.aura, 450),
    Cosmetic('aura_halo', CosmeticKind.aura, 500),
    Cosmetic('aura_butterfly', CosmeticKind.aura, 550),
    Cosmetic('aura_flame', CosmeticKind.aura, 600),
    Cosmetic('aura_crown', CosmeticKind.aura, 700),
    Cosmetic('aura_star', CosmeticKind.aura, 800),
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
    case 'trail_note':
      // 음표 — 분홍·보라 음표가 흔들리며 떠오른다
      final col = Color.lerp(const Color(0xFFFF8AD0), const Color(0xFF9B7BFF), seed)!;
      canvas.save();
      canvas.translate(sin(p * 6 + seed * 6) * 3 * scale, -8 * p * scale);
      canvas.scale((0.5 + 0.5 * fade) * scale);
      final paint = Paint()..color = col.withValues(alpha: fade);
      canvas.drawOval(Rect.fromCenter(center: const Offset(-1.4, 3.4), width: 5, height: 3.8), paint);
      canvas.drawRect(const Rect.fromLTWH(0.5, -5, 1.4, 8.4), paint);
      canvas.drawPath(
          Path()
            ..moveTo(1.9, -5)
            ..quadraticBezierTo(5.4, -3.6, 4.2, -0.6)
            ..quadraticBezierTo(4.6, -3.4, 1.9, -3.2)
            ..close(),
          paint);
      canvas.restore();
      break;
    case 'trail_petal':
      // 꽃잎 — 연분홍 잎이 빙글 돌며 떨어진다
      final col = Color.lerp(const Color(0xFFFFC2DC), const Color(0xFFFF7FB0), seed)!;
      canvas.save();
      canvas.translate(sin(p * 4 + seed * 6) * 4 * scale, 5 * p * scale);
      canvas.rotate(p * 4 + seed * 6);
      final w = (5.5 + 1.5 * seed) * scale, h = w * 0.55 * (0.45 + 0.55 * cos(p * 5).abs());
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w, height: max(0.8, h)),
          Paint()..color = col.withValues(alpha: 0.95 * fade));
      canvas.restore();
      break;
    case 'trail_snow':
      // 눈송이 — 여섯 갈래 결정이 천천히 돈다
      canvas.save();
      canvas.translate(sin(p * 3 + seed * 6) * 3 * scale, 4 * p * scale);
      canvas.rotate(p * 2 + seed * 6);
      final rr = (3.6 + 1.6 * seed) * (0.5 + 0.5 * fade) * scale;
      final arm = Paint()
        ..color = const Color(0xFFE8F7FF).withValues(alpha: fade)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = max(0.7, 1.1 * scale);
      for (int i = 0; i < 3; i++) {
        final a = i * pi / 3;
        final d = Offset(cos(a) * rr, sin(a) * rr);
        canvas.drawLine(-d, d, arm);
      }
      canvas.drawCircle(Offset.zero, rr * 0.22, Paint()..color = Colors.white.withValues(alpha: fade));
      canvas.restore();
      break;
    case 'trail_bolt':
      // 번개 — 노란 지그재그가 짧게 번쩍인다
      final zig = Path()
        ..moveTo(1.4 * scale, -6 * scale)
        ..lineTo(-1.8 * scale, 0.4 * scale)
        ..lineTo(0.6 * scale, 0.4 * scale)
        ..lineTo(-1.6 * scale, 6 * scale)
        ..lineTo(2.4 * scale, -0.8 * scale)
        ..lineTo(0.2 * scale, -0.8 * scale)
        ..close();
      canvas.save();
      canvas.scale(0.5 + 0.5 * fade);
      canvas.drawPath(zig, Paint()
        ..color = const Color(0xFF7DD3FC).withValues(alpha: 0.7 * fade)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * scale));
      canvas.drawPath(zig, Paint()..color = const Color(0xFFFFF3A0).withValues(alpha: fade));
      canvas.restore();
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
        final p = center + Offset(cos(a) * (r + 14), sin(a) * (r + 14) * 0.5);
        canvas.drawCircle(p, 4.4, Paint()..color = (i == 0 ? const Color(0xFF7DD3FC) : const Color(0xFFFDE68A)));
        canvas.drawCircle(p + const Offset(-1.3, -1.3), 1.4, Paint()..color = Colors.white.withValues(alpha: 0.9));
      }
      if (!front) {
        canvas.drawOval(Rect.fromCenter(center: center, width: (r + 14) * 2, height: (r + 14) * 1.0), Paint()
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
        final rr = r + 9 + (rng.nextDouble() - 0.5) * 9;
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
        canvas.drawCircle(center, r + 12, Paint()
          ..shader = ui.Gradient.radial(center, r + 14, [const Color(0x55FFE08A), const Color(0x00FFE08A)]));
        return;
      }
      // 천사 고리 — 머리 위에 떠서 살짝 오르내린다
      final y = center.dy - r * 1.35 + sin(t * 2.5) * r * 0.12;
      final rect = Rect.fromCenter(center: Offset(center.dx, y), width: r * 1.5, height: r * 0.48);
      canvas.drawOval(rect, Paint()
        ..color = const Color(0xFFFFD66B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0);
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
    case 'aura_petal':
      // 꽃잎 — 연분홍 잎 여섯이 넓게 돌며 흩날린다(뒤쪽 반은 캐릭터 뒤)
      for (int i = 0; i < 6; i++) {
        final a = t * 1.1 + i * pi / 3;
        if ((sin(a) > 0) != front) continue;
        final rr = r + 20 + sin(t * 2 + i) * 3;
        final p = center + Offset(cos(a) * rr, sin(a) * rr * 0.45 - r * 0.1);
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(a * 1.6);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 8.5, height: 4.6),
            Paint()..color = Color.lerp(const Color(0xFFFFC2DC), const Color(0xFFFF7FB0), (i % 3) / 2)!);
        canvas.drawOval(Rect.fromCenter(center: const Offset(-1.6, -0.6), width: 3.2, height: 1.6),
            Paint()..color = Colors.white.withValues(alpha: 0.55));
        canvas.restore();
      }
      break;
    case 'aura_butterfly':
      // 나비 — 두 마리가 넓은 타원을 날아 돈다. 날개는 퍼덕인다
      for (int i = 0; i < 2; i++) {
        final a = t * 1.4 + i * pi;
        if ((sin(a) > 0) != front) continue;
        final rr = r + 22;
        final p = center + Offset(cos(a) * rr, sin(a) * rr * 0.5 - r * 0.45 + sin(t * 5 + i) * 3);
        final flap = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 14 + i * 2));
        final body = i == 0 ? const Color(0xFF8AB4FF) : const Color(0xFFFFA8D8);
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(sin(a) * 0.25);
        for (final sx in [-1.0, 1.0]) {
          canvas.drawOval(Rect.fromCenter(center: Offset(sx * 3.4 * flap, -1.6), width: 6.4 * flap, height: 5.4),
              Paint()..color = body);
          canvas.drawOval(Rect.fromCenter(center: Offset(sx * 2.8 * flap, 2.0), width: 5.0 * flap, height: 4.0),
              Paint()..color = body.withValues(alpha: 0.8));
        }
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 1.6, height: 7), const Radius.circular(0.8)),
            Paint()..color = const Color(0xFF3A2E5A));
        canvas.restore();
      }
      break;
    case 'aura_flame':
      if (front) return;
      // 불꽃 — 몸 바깥 둘레를 따라 불길이 넓게 솟는다(양 끝이 어깨 위까지 올라온다)
      for (int i = 0; i < 9; i++) {
        final a = pi * (0.05 + i * 0.1125);
        final h = r * (0.7 + 0.5 * (0.5 + 0.5 * sin(t * 9 + i * 1.7)));
        final base = center + Offset(cos(a) * r * 1.22, r * 0.2 + sin(a) * r * 0.75);
        final w = r * 0.28;
        final p = Path()
          ..moveTo(base.dx - w, base.dy)
          ..quadraticBezierTo(base.dx - w * 1.2, base.dy - h * 0.6, base.dx, base.dy - h)
          ..quadraticBezierTo(base.dx + w * 1.2, base.dy - h * 0.6, base.dx + w, base.dy)
          ..close();
        canvas.drawPath(p, Paint()
          ..shader = ui.Gradient.linear(Offset(0, base.dy), Offset(0, base.dy - h),
              const [Color(0xFFFF5A2E), Color(0xFFFFB13D), Color(0x00FFF3A0)], const [0, 0.55, 1]));
      }
      break;
    case 'aura_star':
      // 별무리 — 금빛 별 넷이 넓은 궤도를 돌며 깜빡인다
      for (int i = 0; i < 4; i++) {
        final a = t * 1.8 + i * pi / 2;
        if ((sin(a) > 0) != front) continue;
        final rr = r + 18 + sin(t * 3 + i) * 4;
        canvas.save();
        canvas.translate(center.dx + cos(a) * rr, center.dy + sin(a) * rr * 0.55);
        canvas.rotate(t * 1.2 + i);
        final s = 4.2 + 1.6 * sin(t * 6 + i * 1.5);
        _star4(canvas, s + 1.6, Paint()
          ..color = const Color(0xFFFFE27A).withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
        _star4(canvas, s, Paint()..color = const Color(0xFFFFF3C4));
        canvas.restore();
      }
      break;
    default:
      return; // aura_none
  }
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
  // 그림 시간은 되감지 않고 계속 흐른다 — 컨트롤러는 다시 그리는 신호로만 쓴다(무지개 등이 6초마다 뚝 끊기지 않게)
  final Stopwatch _clock = Stopwatch()..start();

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
          final t = _clock.elapsedMicroseconds / 1e6;
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

/// 여러 꾸미기를 한 캐릭터에 **함께** 입혀 보는 무대 — 내 가방 미리보기.
/// 잔상은 뒤로 흐르고, 오라는 캐릭터 뒤·앞에 겹쳐 그린다(스킨은 캐릭터 그림 자체라 여기서 다루지 않는다).
/// [charRadius] 는 그릴 캐릭터의 몸 반지름(px) — 게임 기준 반지름 18에 맞춰 효과 크기를 정한다.
class CosmeticStage extends StatefulWidget {
  final List<Cosmetic> items;
  final Color base;
  final double charRadius;
  final Widget child;
  const CosmeticStage({super.key, required this.items, required this.base, required this.charRadius, required this.child});

  @override
  State<CosmeticStage> createState() => _CosmeticStageState();
}

class _CosmeticStageState extends State<CosmeticStage> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  // 시간은 되감지 않는다 — 무지개·불꽃이 6초마다 끊기지 않게
  final Stopwatch _clock = Stopwatch()..start();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _clock.elapsedMicroseconds / 1e6;
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: CustomPaint(painter: _StagePainter(widget.items, widget.base, t, widget.charRadius, front: false))),
              child!,
              Positioned.fill(child: CustomPaint(painter: _StagePainter(widget.items, widget.base, t, widget.charRadius, front: true))),
            ],
          );
        },
        child: widget.child,
      );
}

class _StagePainter extends CustomPainter {
  final List<Cosmetic> items;
  final Color base;
  final double t;

  /// 캐릭터 몸 반지름(px)
  final double r;
  final bool front;
  _StagePainter(this.items, this.base, this.t, this.r, {required this.front});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (final item in items) {
      switch (item.kind) {
        case CosmeticKind.skin:
          break; // 캐릭터 그림이 직접 그린다
        case CosmeticKind.aura:
          canvas.save();
          canvas.translate(center.dx, center.dy);
          canvas.scale(r / 18); // paintAura 는 반지름 18 기준
          paintAura(canvas, item.id, Offset.zero, 18, t, base, front: front);
          canvas.restore();
        case CosmeticKind.trail:
          if (front) break;
          // 잔상 — 캐릭터 뒤(왼쪽)로 입자가 흘러간다
          const n = 9;
          for (int i = 0; i < n; i++) {
            final p = ((t * 1.4 + i / n) % 1.0);
            final seed = ((i * 37) % 100) / 100.0;
            final x = center.dx - r * 0.8 - p * r * 2.2;
            final y = center.dy + sin(i * 1.7 + t * 3) * r * 0.32;
            canvas.save();
            canvas.translate(x, y);
            paintTrailParticle(canvas, item.id, p, seed, base, scale: r / 15);
            canvas.restore();
          }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StagePainter old) => true;
}
