import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'gear.dart';
import 'zonber_painter.dart' show mochiPath;

// ─────────────────────────────────────────────────────────────
// 존 장비 그림(코드 그림). 좌표는 존버 몸 가운데가 원점, r = 몸 반지름.
// 몸과 같은 남색 외곽선 · 위→아래 명암 · 하이라이트로 그려서 몸에 붙어 보이게 한다.
//   등(날개) → 몸 → 발 → 손 → 머리 순서로 zonber_painter 가 부른다.
// 상점 카드는 GearIconPainter 로 아이템만 크게 그린다.
// ─────────────────────────────────────────────────────────────

const Color _ink = Color(0xFF1F2A44);

Color _sh(Color c, double a) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness + a).clamp(0.0, 1.0)).toColor();
}

Paint _line(double r, [double k = 0.065]) => Paint()
  ..color = _ink
  ..style = PaintingStyle.stroke
  ..strokeWidth = max(0.9, r * k)
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round;

Paint _thin(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Paint _grad(Rect b, Color top, Color bottom) =>
    Paint()..shader = ui.Gradient.linear(b.topCenter, b.bottomCenter, [top, bottom]);

void _shape(Canvas cv, Path p, Paint fill, double r, [double k = 0.065]) {
  cv.drawPath(p, fill);
  cv.drawPath(p, _line(r, k));
}

void _rrect(Canvas cv, RRect rr, Color main, double r, {double k = 0.065, double shade = 0.12}) {
  cv.drawRRect(rr, _grad(rr.outerRect, _sh(main, shade), _sh(main, -shade)));
  cv.drawRRect(rr, _line(r, k));
}

void _sparkle(Canvas cv, Offset c, double s, Color col) {
  final p = Path()
    ..moveTo(c.dx, c.dy - s)
    ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
    ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
    ..close();
  cv.drawPath(p, Paint()..color = col);
}

/// 위로 솟는 불꽃 한 가닥
void _flame(Canvas cv, Offset base, double w, double h) {
  final p = Path()
    ..moveTo(base.dx - w / 2, base.dy)
    ..quadraticBezierTo(base.dx - w * 0.55, base.dy - h * 0.55, base.dx, base.dy - h)
    ..quadraticBezierTo(base.dx + w * 0.55, base.dy - h * 0.55, base.dx + w / 2, base.dy)
    ..close();
  cv.drawPath(p, Paint()
    ..shader = ui.Gradient.linear(Offset(0, base.dy), Offset(0, base.dy - h), const [Color(0xFFFF4D2E), Color(0xFFFFB02E), Color(0xFFFFE680)],
        const [0, 0.55, 1]));
}

// ── 부위 기준점 ──────────────────────────────────────────────

Offset handAnchor(double r, double sx) => Offset(sx * r * 1.08, r * 0.3);
Offset footAnchor(double r, double sx) => Offset(sx * r * 0.42, r * 1.0);

/// 모자·털모자·헬멧은 머리 위 한 가닥을 덮는다
bool gearHidesTuft(String id) => id.startsWith('cap_') || id.startsWith('beanie_') || id.startsWith('helmet_');

/// 손 — 몸통 앞에 그리고 **외곽선도 통째로** 긋는다(몸·손·발 모두 같은 굵기의 테두리를 가진다)
void paintBareHand(Canvas cv, double r, Offset hc, Color body) {
  cv.drawCircle(hc, r * 0.22, Paint()..color = body);
  cv.drawCircle(hc, r * 0.22, _line(r, 0.07));
}

void paintBareFoot(Canvas cv, double r, Offset fc, Color body) {
  final foot = RRect.fromRectAndRadius(Rect.fromCenter(center: fc, width: r * 0.46, height: r * 0.34), Radius.circular(r * 0.17));
  cv.drawRRect(foot, Paint()..color = _sh(body, -0.2));
  cv.drawRRect(foot, _line(r, 0.07));
}

// ── 등 ───────────────────────────────────────────────────────

void paintGearBack(Canvas cv, double r, String id, double t) {
  final flap = sin(t * 9) * 0.16;
  for (final sx in [-1.0, 1.0]) {
    cv.save();
    cv.translate(sx * r * 0.7, -r * 0.3);
    cv.scale(sx, 1);
    cv.rotate(flap - 0.08);
    switch (id) {
      case 'wings_bat':
        _batWing(cv, r);
      case 'wings_mech':
        _mechWing(cv, r, t);
      default:
        _featherWing(cv, r, id, t);
    }
    cv.restore();
  }
}

void _featherWing(Canvas cv, double r, String id, double t) {
  final (Color hi, Color lo, Color vein) = switch (id) {
    'wings_gold' => (const Color(0xFFFFF3C4), const Color(0xFFE8A91E), const Color(0xFFB7791F)),
    'wings_star' => (const Color(0xFFEAF5FF), const Color(0xFF7FB2F5), const Color(0xFF4F7FD0)),
    'wings_comet' => (const Color(0xFFFFE9C7), const Color(0xFFFF8A3D), const Color(0xFFC2410C)),
    _ => (Colors.white, const Color(0xFFC9D6EA), const Color(0xFF9FB0CC)),
  };
  const angles = [0.38, 0.02, -0.36, -0.72];
  const lens = [0.78, 1.0, 1.16, 1.24];
  for (int i = 0; i < 4; i++) {
    final len = r * lens[i], w = r * 0.22;
    cv.save();
    cv.rotate(angles[i]);
    final p = Path()
      ..moveTo(0, 0)
      ..cubicTo(len * 0.3, -w, len * 0.8, -w * 0.9, len, 0)
      ..cubicTo(len * 0.8, w * 0.9, len * 0.3, w, 0, 0)
      ..close();
    _shape(cv, p, _grad(p.getBounds(), hi, lo), r, 0.055);
    cv.drawLine(Offset(len * 0.12, 0), Offset(len * 0.78, 0), _thin(vein, max(0.6, r * 0.03)));
    cv.restore();
  }
  // 날개 뿌리
  final root = Rect.fromCenter(center: Offset(r * 0.06, 0), width: r * 0.4, height: r * 0.34);
  cv.drawOval(root, _grad(root, hi, lo));
  cv.drawOval(root, _line(r, 0.055));
  if (id == 'wings_star') {
    for (int i = 0; i < 3; i++) {
      final s = r * 0.1 * (0.7 + 0.3 * sin(t * 6 + i * 2.1));
      _sparkle(cv, Offset(r * (0.55 + i * 0.2), -r * (0.5 - i * 0.28)), s, Colors.white);
    }
  }
  if (id == 'wings_gold') {
    _sparkle(cv, Offset(r * 0.75, -r * 0.42), r * 0.1 * (0.75 + 0.25 * sin(t * 5)), Colors.white);
  }
  if (id == 'wings_comet') {
    // 꼬리 불티 — 날개 끝에서 뒤로 흩어진다
    for (int i = 0; i < 3; i++) {
      final f = (t * 1.4 + i * 0.33) % 1.0;
      cv.drawCircle(Offset(r * (0.7 + f * 0.7), -r * (0.1 + i * 0.22)), r * 0.07 * (1 - f),
          Paint()..color = const Color(0xFFFFC46B).withValues(alpha: 0.9 * (1 - f)));
    }
  }
}

void _batWing(Canvas cv, double r) {
  const mem = Color(0xFF8A6BD1), memLo = Color(0xFF4B3585), bone = Color(0xFF2E2150);
  final len = r * 1.32;
  final tip = Offset(len, -len * 0.72);
  final pts = [Offset(len * 0.98, len * 0.04), Offset(len * 0.62, len * 0.12), Offset(len * 0.28, len * 0.2)];
  final p = Path()
    ..moveTo(0, -r * 0.14)
    ..quadraticBezierTo(len * 0.45, -len * 0.72, tip.dx, tip.dy);
  var prev = tip;
  for (final q in pts) {
    final m = (prev + q) / 2;
    p.quadraticBezierTo(m.dx - len * 0.06, m.dy - len * 0.12, q.dx, q.dy);
    prev = q;
  }
  final end = Offset(0, r * 0.16);
  final m = (prev + end) / 2;
  p.quadraticBezierTo(m.dx, m.dy - len * 0.08, end.dx, end.dy);
  p.close();
  _shape(cv, p, _grad(p.getBounds(), mem, memLo), r, 0.055);
  for (final q in [tip, pts[0], pts[1]]) {
    cv.drawLine(Offset(r * 0.04, -r * 0.04), q, _thin(bone, max(0.7, r * 0.045)));
  }
  cv.drawCircle(tip, r * 0.055, Paint()..color = bone);
}

void _mechWing(Canvas cv, double r, double t) {
  const hi = Color(0xFFF1F5F9), lo = Color(0xFF8A97AB), glow = Color(0xFF5EEAD4);
  const angles = [0.3, -0.12, -0.54];
  const lens = [0.92, 1.12, 1.26];
  for (int i = 0; i < 3; i++) {
    final len = r * lens[i], w = r * 0.2;
    cv.save();
    cv.rotate(angles[i]);
    final p = Path()
      ..moveTo(0, -w * 0.5)
      ..lineTo(len * 0.9, -w * 0.42)
      ..lineTo(len, 0)
      ..lineTo(len * 0.88, w * 0.5)
      ..lineTo(0, w * 0.5)
      ..close();
    _shape(cv, p, _grad(p.getBounds(), hi, lo), r, 0.055);
    final pulse = 0.55 + 0.45 * sin(t * 5 + i);
    cv.drawLine(Offset(len * 0.18, w * 0.24), Offset(len * 0.82, w * 0.24),
        _thin(glow.withValues(alpha: pulse), max(0.8, r * 0.05)));
    cv.drawCircle(Offset(len * 0.12, -w * 0.12), r * 0.03, Paint()..color = _ink.withValues(alpha: 0.55));
    cv.restore();
  }
  final joint = Rect.fromCircle(center: Offset.zero, radius: r * 0.16);
  cv.drawOval(joint, _grad(joint, hi, lo));
  cv.drawOval(joint, _line(r, 0.055));
  cv.drawCircle(Offset.zero, r * 0.065, Paint()..color = glow);
}

// ── 발 ───────────────────────────────────────────────────────

void paintGearFoot(Canvas cv, double r, String id, Offset fc, double sx, double t, bool moving) {
  if (id.startsWith('rocket_')) {
    _rocket(cv, r, id, fc, sx, t, moving);
  } else if (id.startsWith('sneakers_')) {
    _sneaker(cv, r, id, fc, sx, t);
  } else {
    _boot(cv, r, id, fc, sx);
  }
}

void _rocket(Canvas cv, double r, String id, Offset fc, double sx, double t, bool moving) {
  final (Color main, Color trim, List<Color> fire) = switch (id) {
    'rocket_plasma' => (const Color(0xFF6D5BD0), const Color(0xFF22D3EE), const [Color(0xFFE0FFFF), Color(0xFF38BDF8), Color(0x00A855F7)]),
    'rocket_chrome' => (const Color(0xFFD5DCE6), const Color(0xFFFF8A3D), const [Color(0xFFFFF7D6), Color(0xFFFFA53D), Color(0x00FF3D3D)]),
    'rocket_void' => (const Color(0xFF241B3D), const Color(0xFFB388FF), const [Color(0xFFF3E8FF), Color(0xFF9B6BFF), Color(0x004C1D95)]),
    _ => (const Color(0xFFE5484D), const Color(0xFFFFD23F), const [Color(0xFFFFF3A0), Color(0xFFFF8A3D), Color(0x00E5334D)]),
  };
  final w = r * 0.6, h = r * 0.42;
  final b = Rect.fromCenter(center: fc, width: w, height: h);
  final cx = b.center.dx;
  // 불꽃
  final ny = b.bottom + h * 0.2;
  final len = r * (moving ? 0.72 : 0.4) * (0.85 + 0.15 * sin(t * 30 + sx * 2));
  final fp = Path()
    ..moveTo(cx - w * 0.2, ny)
    ..quadraticBezierTo(cx - w * 0.24, ny + len * 0.6, cx, ny + len)
    ..quadraticBezierTo(cx + w * 0.24, ny + len * 0.6, cx + w * 0.2, ny)
    ..close();
  cv.drawPath(fp, Paint()..shader = ui.Gradient.linear(Offset(0, ny), Offset(0, ny + len), fire, const [0, 0.45, 1]));
  final core = Path()
    ..moveTo(cx - w * 0.1, ny)
    ..quadraticBezierTo(cx, ny + len * 0.7, cx + w * 0.1, ny)
    ..close();
  cv.drawPath(core, Paint()..color = Colors.white.withValues(alpha: 0.8));
  // 노즐
  final nz = Path()
    ..moveTo(cx - w * 0.15, b.bottom - h * 0.05)
    ..lineTo(cx + w * 0.15, b.bottom - h * 0.05)
    ..lineTo(cx + w * 0.22, ny)
    ..lineTo(cx - w * 0.22, ny)
    ..close();
  _shape(cv, nz, _grad(nz.getBounds(), const Color(0xFFCBD5E1), const Color(0xFF5B6778)), r, 0.05);
  // 부츠
  final boot = RRect.fromRectAndCorners(b,
      topLeft: Radius.circular(h * 0.5), topRight: Radius.circular(h * 0.5),
      bottomLeft: Radius.circular(h * 0.2), bottomRight: Radius.circular(h * 0.2));
  _rrect(cv, boot, main, r);
  final sole = RRect.fromRectAndCorners(Rect.fromLTRB(b.left, b.bottom - h * 0.34, b.right, b.bottom),
      bottomLeft: Radius.circular(h * 0.2), bottomRight: Radius.circular(h * 0.2));
  _rrect(cv, sole, const Color(0xFFB8C2D0), r, shade: 0.1);
  cv.drawLine(Offset(b.left + w * 0.2, b.top + h * 0.34), Offset(b.right - w * 0.2, b.top + h * 0.34), _thin(trim, max(0.8, r * 0.06)));
  cv.drawCircle(Offset(cx + sx * w * 0.27, b.bottom - h * 0.17), r * 0.045, Paint()..color = trim);
  cv.drawOval(Rect.fromCenter(center: Offset(cx - w * 0.16, b.top + h * 0.18), width: w * 0.24, height: h * 0.14),
      Paint()..color = Colors.white.withValues(alpha: 0.55));
}

/// 운동화 — 둥근 앞코 · 흰 밑창 · 끈 · 바깥쪽 줄무늬
void _sneaker(Canvas cv, double r, String id, Offset fc, double sx, double t) {
  final (Color main, Color accent, Color sole, bool high) = switch (id) {
    'sneakers_neon' => (const Color(0xFFB6F23A), const Color(0xFF111827), const Color(0xFF334155), false),
    'sneakers_hightop' => (const Color(0xFFE5484D), Colors.white, const Color(0xFFF3F4F6), true),
    'sneakers_gold' => (const Color(0xFFFFD66B), const Color(0xFFB8860B), const Color(0xFFFFF4CC), false),
    'sneakers_sky' => (const Color(0xFF7FC4F0), Colors.white, const Color(0xFFEFF6FF), false),
    'sneakers_violet' => (const Color(0xFF6D5BD0), const Color(0xFFFFD23F), const Color(0xFF241B3D), true),
    _ => (Colors.white, const Color(0xFFE5484D), const Color(0xFFE2E8F0), false),
  };
  final w = r * 0.64, h = r * 0.4;
  final b = Rect.fromCenter(center: fc, width: w, height: h);
  final cx = b.center.dx;
  if (high) {
    final ank = RRect.fromRectAndRadius(Rect.fromLTRB(cx - w * 0.3, b.top - h * 0.42, cx + w * 0.3, b.top + h * 0.4), Radius.circular(h * 0.18));
    _rrect(cv, ank, main, r);
    cv.drawLine(Offset(cx - w * 0.22, b.top - h * 0.26), Offset(cx + w * 0.22, b.top - h * 0.26), _thin(accent, max(0.7, r * 0.05)));
  }
  final upper = RRect.fromRectAndCorners(Rect.fromLTRB(b.left, b.top, b.right, b.bottom - h * 0.16),
      topLeft: Radius.circular(h * 0.5), topRight: Radius.circular(h * 0.5),
      bottomLeft: Radius.circular(h * 0.14), bottomRight: Radius.circular(h * 0.14));
  _rrect(cv, upper, main, r, shade: 0.08);
  // 앞코
  cv.drawOval(Rect.fromCenter(center: Offset(cx, b.bottom - h * 0.36), width: w * 0.6, height: h * 0.34),
      Paint()..color = _sh(main, 0.1).withValues(alpha: 0.9));
  // 바깥쪽 줄무늬
  final sw = Path()
    ..moveTo(cx + sx * w * 0.02, b.bottom - h * 0.3)
    ..quadraticBezierTo(cx + sx * w * 0.32, b.bottom - h * 0.34, cx + sx * w * 0.44, b.top + h * 0.3);
  cv.drawPath(sw, _thin(accent, max(0.9, r * 0.07)));
  // 끈
  for (int i = 0; i < 2; i++) {
    final y = b.top + h * (0.2 + i * 0.17);
    cv.drawLine(Offset(cx - w * 0.13, y), Offset(cx + w * 0.13, y), _thin(_ink.withValues(alpha: 0.55), max(0.6, r * 0.035)));
  }
  // 밑창
  final so = RRect.fromRectAndRadius(Rect.fromLTRB(b.left - w * 0.04, b.bottom - h * 0.28, b.right + w * 0.04, b.bottom), Radius.circular(h * 0.14));
  cv.drawRRect(so, Paint()..color = sole);
  cv.drawRRect(so, _line(r, 0.06));
  if (id == 'sneakers_gold') {
    _sparkle(cv, Offset(cx - sx * w * 0.2, b.top + h * 0.2), r * 0.09 * (0.7 + 0.3 * sin(t * 5 + sx)), Colors.white);
  }
}

/// 축구화 — 낮고 날렵한 갑피 · 대각 세 줄 · 스터드
void _boot(Canvas cv, double r, String id, Offset fc, double sx) {
  final (Color main, Color stripe) = switch (id) {
    'boots_orange' => (const Color(0xFFFF7A1A), const Color(0xFF111827)),
    'boots_mint' => (const Color(0xFF3FE0B5), const Color(0xFF0F5A4A)),
    'boots_white' => (const Color(0xFFF8FAFC), const Color(0xFF2F6FE4)),
    'boots_violet' => (const Color(0xFF6D5BD0), const Color(0xFFFFD23F)),
    'boots_carbon' => (const Color(0xFF111827), const Color(0xFFB6F23A)),
    _ => (const Color(0xFF1F2937), Colors.white),
  };
  final w = r * 0.64, h = r * 0.36;
  final b = Rect.fromCenter(center: fc + Offset(0, r * 0.02), width: w, height: h);
  final cx = b.center.dx;
  // 스터드
  for (int i = 0; i < 3; i++) {
    final x = b.left + w * (0.22 + i * 0.28);
    final st = Path()
      ..moveTo(x - r * 0.05, b.bottom - r * 0.01)
      ..lineTo(x + r * 0.05, b.bottom - r * 0.01)
      ..lineTo(x + r * 0.03, b.bottom + r * 0.07)
      ..lineTo(x - r * 0.03, b.bottom + r * 0.07)
      ..close();
    _shape(cv, st, Paint()..color = const Color(0xFFE2E8F0), r, 0.04);
  }
  final upper = RRect.fromRectAndCorners(b,
      topLeft: Radius.circular(h * 0.55), topRight: Radius.circular(h * 0.55),
      bottomLeft: Radius.circular(h * 0.2), bottomRight: Radius.circular(h * 0.2));
  _rrect(cv, upper, main, r, shade: 0.1);
  // 대각 세 줄(바깥쪽)
  cv.save();
  cv.clipRRect(upper);
  for (int i = 0; i < 3; i++) {
    final x = cx + sx * w * (0.1 + i * 0.12);
    cv.drawLine(Offset(x, b.bottom - h * 0.2), Offset(x + sx * w * 0.12, b.top + h * 0.15), _thin(stripe, max(0.7, r * 0.045)));
  }
  cv.restore();
  // 발목 칼라
  cv.drawArc(Rect.fromCenter(center: Offset(cx, b.top + h * 0.08), width: w * 0.44, height: h * 0.34), 0, pi, false,
      _thin(_ink.withValues(alpha: 0.7), max(0.7, r * 0.045)));
  // 밑창
  cv.drawLine(Offset(b.left + w * 0.06, b.bottom - h * 0.1), Offset(b.right - w * 0.06, b.bottom - h * 0.1),
      _thin(_sh(main, -0.25), max(0.7, r * 0.05)));
  cv.drawOval(Rect.fromCenter(center: Offset(cx - w * 0.14, b.top + h * 0.22), width: w * 0.22, height: h * 0.14),
      Paint()..color = Colors.white.withValues(alpha: 0.45));
}

// ── 손 ───────────────────────────────────────────────────────

void paintGearHand(Canvas cv, double r, String id, Offset hc, double sx, Color body) {
  if (id.startsWith('wrist_')) {
    paintBareHand(cv, r, hc, body);
    _wristband(cv, r, id, hc, sx);
  } else if (id.startsWith('mitts_') || id.startsWith('gauntlet_')) {
    _mitt(cv, r, id, hc, sx);
  } else {
    _keeperGlove(cv, r, id, hc, sx);
  }
}

void _wristband(Canvas cv, double r, String id, Offset hc, double sx) {
  final rect = Rect.fromCenter(center: hc + Offset(-sx * r * 0.15, 0), width: r * 0.16, height: r * 0.36);
  final rr = RRect.fromRectAndRadius(rect, Radius.circular(r * 0.06));
  if (id == 'wrist_rainbow') {
    const cols = [Color(0xFFE5484D), Color(0xFFFFC928), Color(0xFF3B8EF0)];
    cv.save();
    cv.clipRRect(rr);
    for (int i = 0; i < 3; i++) {
      cv.drawRect(Rect.fromLTWH(rect.left + rect.width * i / 3, rect.top, rect.width / 3 + 0.5, rect.height), Paint()..color = cols[i]);
    }
    cv.restore();
  } else {
    final (Color main, Color stripe) = switch (id) {
      'wrist_red' => (const Color(0xFFE5484D), Colors.white),
      'wrist_black' => (const Color(0xFF1F2937), const Color(0xFFB6F23A)),
      'wrist_gold' => (const Color(0xFFFFD66B), const Color(0xFFB8860B)),
      _ => (Colors.white, const Color(0xFFE5484D)),
    };
    cv.drawRRect(rr, _grad(rect, _sh(main, 0.05), _sh(main, -0.12)));
    cv.drawLine(Offset(rect.center.dx, rect.top + r * 0.04), Offset(rect.center.dx, rect.bottom - r * 0.04), _thin(stripe, max(0.7, r * 0.05)));
  }
  cv.drawRRect(rr, _line(r, 0.06));
}

/// 우주 장갑(흰 퉁퉁한 장갑 + 소매) · 네온 건틀릿
void _mitt(Canvas cv, double r, String id, Offset hc, double sx) {
  final neon = id.startsWith('gauntlet_');
  final (Color main, Color cuffC, Color glow) = switch (id) {
    'gauntlet_ion' => (const Color(0xFF2E1F6B), const Color(0xFF6D5BD0), const Color(0xFFB388FF)),
    'gauntlet_neon' => (const Color(0xFF1E293B), const Color(0xFF334155), const Color(0xFF5EEAD4)),
    'mitts_astro' => (const Color(0xFFDDE7F5), const Color(0xFF2F8CF2), const Color(0xFF5EEAD4)),
    _ => (Colors.white, const Color(0xFFFF8A3D), const Color(0xFF5EEAD4)),
  };
  final rad = r * 0.26;
  final c = hc + Offset(sx * r * 0.03, 0);
  // 소매
  final cuff = RRect.fromRectAndRadius(Rect.fromCenter(center: c + Offset(-sx * rad * 0.95, 0), width: rad * 0.62, height: rad * 1.36), Radius.circular(rad * 0.26));
  _rrect(cv, cuff, cuffC, r, shade: 0.1);
  // 엄지
  final th = Rect.fromCenter(center: c + Offset(-sx * rad * 0.3, -rad * 0.78), width: rad * 0.58, height: rad * 0.72);
  cv.drawOval(th, _grad(th, _sh(main, 0.08), _sh(main, neon ? -0.05 : -0.14)));
  cv.drawOval(th, _line(r, 0.06));
  // 장갑
  final body = Rect.fromCircle(center: c, radius: rad);
  cv.drawOval(body, _grad(body, _sh(main, 0.08), _sh(main, neon ? -0.06 : -0.16)));
  cv.drawOval(body, _line(r, 0.065));
  // 손가락 주름
  for (int i = 0; i < 2; i++) {
    final y = c.dy - rad * 0.2 + i * rad * 0.42;
    cv.drawLine(Offset(c.dx + sx * rad * 0.45, y), Offset(c.dx + sx * rad * 0.9, y), _thin(neon ? glow : _ink.withValues(alpha: 0.35), max(0.6, r * 0.035)));
  }
  if (neon) {
    for (int i = 0; i < 3; i++) {
      cv.drawCircle(Offset(c.dx - sx * rad * 0.05, c.dy - rad * 0.45 + i * rad * 0.45), r * 0.035, Paint()..color = glow);
    }
  } else {
    cv.drawOval(Rect.fromCenter(center: c + Offset(-rad * 0.3, -rad * 0.35), width: rad * 0.5, height: rad * 0.3),
        Paint()..color = Colors.white.withValues(alpha: 0.9));
  }
}

/// 골키퍼 장갑 — 손가락 네 개 · 엄지 · 손등 장식 · 손목 스트랩
void _keeperGlove(Canvas cv, double r, String id, Offset hc, double sx) {
  final (Color main, Color trim, Color strap) = switch (id) {
    'gloves_pro' => (const Color(0xFF1F2937), const Color(0xFFB6F23A), const Color(0xFF111827)),
    'gloves_fire' => (const Color(0xFFFF7A1A), const Color(0xFFFFD23F), const Color(0xFFB91C1C)),
    'gloves_ice' => (const Color(0xFFBFE6FF), const Color(0xFF2F8CF2), const Color(0xFF1E3A8A)),
    'gloves_violet' => (const Color(0xFF6D5BD0), const Color(0xFFFFD23F), const Color(0xFF2E1F6B)),
    'gloves_gold' => (const Color(0xFFFFD66B), const Color(0xFFFFF6CC), const Color(0xFFB8860B)),
    _ => (Colors.white, const Color(0xFF22C55E), const Color(0xFF16A34A)),
  };
  final c = hc + Offset(sx * r * 0.05, -r * 0.04);
  final w = r * 0.56, h = r * 0.66;
  // 엄지(몸 쪽)
  final th = Rect.fromCenter(center: c + Offset(-sx * w * 0.5, h * 0.04), width: w * 0.36, height: h * 0.48);
  cv.drawOval(th, _grad(th, _sh(main, 0.08), _sh(main, -0.12)));
  cv.drawOval(th, _line(r, 0.06));
  // 손가락 — 가운데 둘이 조금 길다
  for (int j = 0; j < 4; j++) {
    final fx = c.dx - w * 0.5 + w * (0.125 + j * 0.25);
    final top = c.dy - h * 0.5 + ((j == 1 || j == 2) ? 0 : h * 0.09);
    final f = RRect.fromRectAndRadius(Rect.fromLTRB(fx - w * 0.125, top, fx + w * 0.125, c.dy + h * 0.1), Radius.circular(w * 0.125));
    _rrect(cv, f, main, r, k: 0.055, shade: 0.08);
  }
  // 손등
  final palm = RRect.fromRectAndRadius(Rect.fromLTRB(c.dx - w * 0.5, c.dy - h * 0.1, c.dx + w * 0.5, c.dy + h * 0.34), Radius.circular(w * 0.18));
  _rrect(cv, palm, main, r, shade: 0.1);
  if (id == 'gloves_fire') {
    _flame(cv, Offset(c.dx, c.dy + h * 0.28), w * 0.4, h * 0.36);
  } else {
    cv.drawLine(Offset(c.dx - w * 0.32, c.dy + h * 0.24), Offset(c.dx + w * 0.3, c.dy - h * 0.02), _thin(trim, max(0.9, r * 0.07)));
  }
  // 손목 스트랩
  final st = RRect.fromRectAndRadius(Rect.fromLTRB(c.dx - w * 0.46, c.dy + h * 0.28, c.dx + w * 0.46, c.dy + h * 0.52), Radius.circular(h * 0.08));
  _rrect(cv, st, strap, r, shade: 0.08);
  cv.drawLine(Offset(c.dx - w * 0.3, c.dy + h * 0.4), Offset(c.dx + w * 0.3, c.dy + h * 0.4), _thin(Colors.white.withValues(alpha: 0.5), max(0.6, r * 0.03)));
  if (id == 'gloves_gold') {
    _sparkle(cv, Offset(c.dx + sx * w * 0.2, c.dy - h * 0.3), r * 0.1, Colors.white);
  }
}

// ── 머리 ─────────────────────────────────────────────────────

void paintGearHead(Canvas cv, double r, String id, double t) {
  if (id.startsWith('band_')) {
    _band(cv, r, id, t);
  } else if (id.startsWith('cap_')) {
    _cap(cv, r, id);
  } else if (id.startsWith('beanie_')) {
    _beanie(cv, r, id);
  } else if (id.startsWith('goggles_')) {
    _goggles(cv, r, id);
  } else if (id.startsWith('helmet_')) {
    _helmet(cv, r, t, id);
  } else {
    _antenna(cv, r, t);
  }
}

/// 이마를 두르는 띠 — 머리를 감싸 보이게 가운데가 살짝 내려간 곡선
Path _foreheadStrip(double r, double y0, double bw) => Path()
  ..moveTo(-r * 1.2, y0)
  ..quadraticBezierTo(0, y0 + r * 0.18, r * 1.2, y0)
  ..lineTo(r * 1.2, y0 + bw)
  ..quadraticBezierTo(0, y0 + r * 0.18 + bw, -r * 1.2, y0 + bw)
  ..close();

/// 이마 띠가 지운 몸통 외곽선을 **그 띠가 지나간 높이에서만** 다시 긋는다.
/// 통째로 다시 그리면 머리 장비는 맨 나중에 그려지므로 손·발 위에 몸통 외곽선이 얹힌다(2026-09-23 수정).
void _restoreBodyEdge(Canvas cv, double r, double y0, double bw) {
  cv.save();
  // 띠가 가운데에서 r*0.09 만큼 처지고, 외곽선 굵기 절반만큼 더 여유를 둔다
  cv.clipRect(Rect.fromLTRB(-r * 1.4, y0 - r * 0.1, r * 1.4, y0 + bw + r * 0.2));
  cv.drawPath(mochiPath(r), _line(r, 0.08));
  cv.restore();
}

void _stripEdges(Canvas cv, double r, double y0, double bw) {
  for (final y in [y0, y0 + bw]) {
    cv.drawPath(Path()
      ..moveTo(-r * 1.2, y)
      ..quadraticBezierTo(0, y + r * 0.18, r * 1.2, y), _line(r, 0.055));
  }
}

void _band(Canvas cv, double r, String id, double t) {
  final (Color main, Color mark) = switch (id) {
    'band_blue' => (const Color(0xFF2F8CF2), Colors.white),
    'band_stripe' => (const Color(0xFF1E3A8A), const Color(0xFFE5484D)),
    'band_mint' => (const Color(0xFF2ECFA6), const Color(0xFF0F5A4A)),
    'band_flame' => (const Color(0xFFFF7A1A), const Color(0xFFFFD23F)),
    _ => (const Color(0xFFE5484D), Colors.white),
  };
  final y0 = -r * 0.72, bw = r * 0.24;
  // 매듭 꼬리(머리 뒤로 보이게 먼저)
  final knot = Offset(r * 0.92, y0 + r * 0.14);
  for (int i = 0; i < 2; i++) {
    final wave = sin(t * 10 + i * 1.7) * r * 0.1;
    final end = knot + Offset(r * (0.5 + i * 0.1), r * (0.06 + i * 0.26) + wave);
    final tail = Path()
      ..moveTo(knot.dx, knot.dy - r * 0.08)
      ..quadraticBezierTo((knot.dx + end.dx) / 2, knot.dy - r * 0.12 + wave * 0.5, end.dx, end.dy - r * 0.09)
      ..lineTo(end.dx - r * 0.07, end.dy)
      ..lineTo(end.dx, end.dy + r * 0.09)
      ..quadraticBezierTo((knot.dx + end.dx) / 2, knot.dy + r * 0.12 + wave * 0.5, knot.dx, knot.dy + r * 0.08)
      ..close();
    _shape(cv, tail, Paint()..color = _sh(main, -0.08), r, 0.055);
    if (id == 'band_flame') _flame(cv, end + Offset(r * 0.02, r * 0.02), r * 0.16, r * (0.26 + 0.06 * sin(t * 18 + i)));
  }
  cv.save();
  cv.clipPath(mochiPath(r));
  final strip = _foreheadStrip(r, y0, bw);
  cv.drawPath(strip, _grad(strip.getBounds(), _sh(main, 0.1), _sh(main, -0.12)));
  if (id == 'band_stripe') {
    for (final dy in [bw * 0.3, bw * 0.7]) {
      cv.drawPath(Path()
        ..moveTo(-r * 1.2, y0 + dy)
        ..quadraticBezierTo(0, y0 + r * 0.18 + dy, r * 1.2, y0 + dy), _thin(dy < bw / 2 ? Colors.white : mark, max(0.7, r * 0.045)));
    }
  } else if (id == 'band_flame') {
    for (int i = -1; i <= 1; i++) {
      _flame(cv, Offset(i * r * 0.36, y0 + r * 0.09 + bw * 0.85 - (i == 0 ? 0 : r * 0.02)), r * 0.2, r * (0.18 + 0.04 * sin(t * 16 + i)));
    }
  } else {
    final patch = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, y0 + r * 0.09 + bw / 2), width: r * 0.26, height: bw * 0.62), Radius.circular(r * 0.05));
    cv.drawRRect(patch, Paint()..color = mark);
  }
  _stripEdges(cv, r, y0, bw);
  cv.restore();
  _restoreBodyEdge(cv, r, y0, bw);
  final kn = RRect.fromRectAndRadius(Rect.fromCenter(center: knot, width: r * 0.18, height: r * 0.2), Radius.circular(r * 0.06));
  _rrect(cv, kn, main, r, k: 0.055);
}

void _cap(Canvas cv, double r, String id) {
  final (Color main, Color logo) = switch (id) {
    'cap_red' => (const Color(0xFFE5484D), Colors.white),
    'cap_black' => (const Color(0xFF1F2937), const Color(0xFFFFD66B)),
    'cap_mint' => (const Color(0xFF2ECFA6), const Color(0xFF0F5A4A)),
    _ => (const Color(0xFF2F6FE4), Colors.white),
  };
  final by = -r * 0.5;
  final crown = Path()
    ..moveTo(-r * 0.92, by)
    ..cubicTo(-r * 0.94, -r * 1.24, r * 0.94, -r * 1.24, r * 0.92, by)
    ..close();
  _shape(cv, crown, _grad(crown.getBounds(), _sh(main, 0.1), _sh(main, -0.12)), r, 0.07);
  // 솔기
  final seam = _thin(_sh(main, -0.25), max(0.6, r * 0.035));
  cv.drawPath(Path()
    ..moveTo(0, -r * 1.05)
    ..quadraticBezierTo(-r * 0.4, -r * 0.9, -r * 0.46, by), seam);
  cv.drawPath(Path()
    ..moveTo(0, -r * 1.05)
    ..quadraticBezierTo(r * 0.4, -r * 0.9, r * 0.46, by), seam);
  // 앞 로고 — 존버 원형 마크
  cv.drawCircle(Offset(0, -r * 0.74), r * 0.13, Paint()..color = logo);
  cv.drawCircle(Offset(0, -r * 0.74), r * 0.07, _thin(main, max(0.7, r * 0.045)));
  // 단추
  cv.drawCircle(Offset(0, -r * 1.06), r * 0.07, Paint()..color = _sh(main, -0.12));
  cv.drawCircle(Offset(0, -r * 1.06), r * 0.07, _line(r, 0.05));
  // 챙
  final brim = Path()
    ..moveTo(-r * 0.96, by)
    ..quadraticBezierTo(0, by + r * 0.5, r * 0.98, by)
    ..quadraticBezierTo(0, by + r * 0.12, -r * 0.98, by)
    ..close();
  _shape(cv, brim, _grad(brim.getBounds(), _sh(main, -0.08), _sh(main, -0.2)), r, 0.07);
}

void _beanie(Canvas cv, double r, String id) {
  final a = id == 'beanie_pom' ? const Color(0xFF6D5BD0) : const Color(0xFFE5484D);
  final cuffTop = -r * 0.68, cuffBot = -r * 0.44;
  final dome = Path()
    ..moveTo(-r * 0.92, cuffTop + r * 0.04)
    ..cubicTo(-r * 0.9, -r * 1.36, r * 0.9, -r * 1.36, r * 0.92, cuffTop + r * 0.04)
    ..close();
  cv.drawPath(dome, _grad(dome.getBounds(), _sh(a, 0.08), _sh(a, -0.1)));
  cv.save();
  cv.clipPath(dome);
  cv.drawRect(Rect.fromLTRB(-r, -r * 0.98, r, -r * 0.86), Paint()..color = Colors.white);
  cv.restore();
  cv.drawPath(dome, _line(r, 0.07));
  // 방울
  final pc = Offset(0, -r * 1.18);
  for (final o in [const Offset(-0.1, 0.02), const Offset(0.1, 0.02), const Offset(0, -0.08)]) {
    cv.drawCircle(pc + o * r, r * 0.13, Paint()..color = Colors.white);
  }
  cv.drawCircle(pc, r * 0.18, _line(r, 0.055));
  cv.drawCircle(pc, r * 0.17, Paint()..color = Colors.white);
  cv.drawCircle(pc + Offset(-r * 0.05, -r * 0.05), r * 0.05, Paint()..color = const Color(0xFFE2E8F0));
  // 접힌 단(골지)
  final cuff = RRect.fromRectAndRadius(Rect.fromLTRB(-r * 0.98, cuffTop, r * 0.98, cuffBot), Radius.circular(r * 0.1));
  cv.drawRRect(cuff, _grad(cuff.outerRect, _sh(a, -0.02), _sh(a, -0.16)));
  for (double x = -r * 0.84; x <= r * 0.85; x += r * 0.14) {
    cv.drawLine(Offset(x, cuffTop + r * 0.04), Offset(x, cuffBot - r * 0.04), _thin(_sh(a, -0.24), max(0.6, r * 0.03)));
  }
  cv.drawRRect(cuff, _line(r, 0.07));
}

void _antenna(Canvas cv, double r, double t) {
  const metal = Color(0xFFD5DCE6), dark = Color(0xFF6B7788);
  final arc = Path()
    ..moveTo(-r * 0.98, -r * 0.2)
    ..cubicTo(-r * 1.02, -r * 1.14, r * 1.02, -r * 1.14, r * 0.98, -r * 0.2);
  cv.drawPath(arc, _thin(_ink, max(2.0, r * 0.2)));
  cv.drawPath(arc, _thin(metal, max(1.0, r * 0.1)));
  // 안테나(오른쪽 귀에서)
  cv.drawLine(Offset(r * 1.02, -r * 0.4), Offset(r * 1.2, -r * 1.02), _thin(_ink, max(1.6, r * 0.12)));
  cv.drawLine(Offset(r * 1.02, -r * 0.4), Offset(r * 1.2, -r * 1.02), _thin(metal, max(0.8, r * 0.05)));
  final on = sin(t * 4) > -0.3;
  final tip = Offset(r * 1.21, -r * 1.06);
  if (on) cv.drawCircle(tip, r * 0.16, Paint()..color = const Color(0x55FF5A5A));
  cv.drawCircle(tip, r * 0.09, Paint()..color = on ? const Color(0xFFFF5A5A) : const Color(0xFF9F3A3A));
  cv.drawCircle(tip, r * 0.09, _line(r, 0.05));
  // 귀 덮개
  for (final sx in [-1.0, 1.0]) {
    final ear = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(sx * r * 1.0, -r * 0.2), width: r * 0.26, height: r * 0.42), Radius.circular(r * 0.11));
    cv.drawRRect(ear, _grad(ear.outerRect, metal, dark));
    cv.drawRRect(ear, _line(r, 0.06));
    cv.drawCircle(Offset(sx * r * 1.0, -r * 0.2), r * 0.05, Paint()..color = const Color(0xFF5EEAD4));
  }
}

void _goggles(Canvas cv, double r, String id) {
  // 밤 고글은 어두운 띠에 호박색 렌즈
  final (Color strap, Color lensHi, Color lensLo) = switch (id) {
    'goggles_night' => (const Color(0xFF111827), const Color(0xFFFFE08A), const Color(0xFFB45309)),
    _ => (const Color(0xFF334155), const Color(0xFFA5F3FC), const Color(0xFF0E7490)),
  };
  final y0 = -r * 0.7, bw = r * 0.16;
  cv.save();
  cv.clipPath(mochiPath(r));
  final s = _foreheadStrip(r, y0, bw);
  cv.drawPath(s, _grad(s.getBounds(), _sh(strap, 0.08), _sh(strap, -0.08)));
  _stripEdges(cv, r, y0, bw);
  cv.restore();
  _restoreBodyEdge(cv, r, y0, bw);
  final cy = y0 + r * 0.14 + bw / 2;
  final bridge = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, cy), width: r * 0.24, height: r * 0.08), Radius.circular(r * 0.04));
  cv.drawRRect(bridge, Paint()..color = const Color(0xFF94A3B8));
  cv.drawRRect(bridge, _line(r, 0.05));
  for (final sx in [-1.0, 1.0]) {
    final c = Offset(sx * r * 0.3, cy);
    final rim = Rect.fromCircle(center: c, radius: r * 0.21);
    cv.drawOval(rim, _grad(rim, const Color(0xFFF1F5F9), const Color(0xFF8A97AB)));
    cv.drawOval(rim, _line(r, 0.06));
    final lens = Rect.fromCircle(center: c, radius: r * 0.14);
    cv.drawOval(lens, _grad(lens, lensHi, lensLo));
    cv.drawArc(Rect.fromCircle(center: c, radius: r * 0.09), pi * 1.05, pi * 0.45, false, _thin(Colors.white.withValues(alpha: 0.9), max(0.7, r * 0.04)));
  }
}

void _helmet(Canvas cv, double r, double t, String id) {
  final visor = id == 'helmet_visor'; // 금빛 바이저가 얼굴 위를 가린다
  final c = Offset(0, -r * 0.08);
  final rad = r * 1.3;
  // 목깃
  final collar = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, r * 0.74), width: r * 1.5, height: r * 0.24), Radius.circular(r * 0.12));
  _rrect(cv, collar, const Color(0xFFD5DCE6), r, shade: 0.1);
  cv.drawCircle(Offset(-r * 0.4, r * 0.74), r * 0.04, Paint()..color = const Color(0xFFFF5A5A));
  cv.drawCircle(Offset(r * 0.4, r * 0.74), r * 0.04, Paint()..color = const Color(0xFF5EEAD4));
  // 유리 돔
  cv.drawCircle(c, rad, Paint()..color = const Color(0x2EBFE9FF));
  cv.drawCircle(c, rad, _thin(const Color(0xB3E0F2FE), max(1.0, r * 0.07)));
  cv.drawCircle(c, rad + r * 0.035, _thin(_ink.withValues(alpha: 0.75), max(0.8, r * 0.04)));
  cv.drawArc(Rect.fromCircle(center: c, radius: rad * 0.84), pi * 1.08, pi * 0.32, false, _thin(Colors.white.withValues(alpha: 0.85), max(1.0, r * 0.09)));
  cv.drawCircle(c + Offset(rad * 0.28, -rad * 0.72), r * 0.05, Paint()..color = Colors.white.withValues(alpha: 0.85));
  if (visor) {
    // 바이저 — 돔 위쪽 절반을 금빛으로 덮는다
    cv.save();
    cv.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: rad)));
    final band = Rect.fromLTRB(c.dx - rad, c.dy - rad * 0.72, c.dx + rad, c.dy - rad * 0.02);
    cv.drawRect(band, _grad(band, const Color(0xCCFFE9A3), const Color(0xB3E0A21B)));
    cv.drawLine(Offset(band.left, band.bottom), Offset(band.right, band.bottom), _thin(const Color(0xFF9A6A00), max(0.9, r * 0.055)));
    cv.drawArc(Rect.fromCircle(center: c, radius: rad * 0.7), pi * 1.1, pi * 0.3, false,
        _thin(Colors.white.withValues(alpha: 0.75), max(0.8, r * 0.06)));
    cv.restore();
  }
}

// ── 상점 카드용 — 아이템만 크게 ───────────────────────────────

/// 머리·등 아이템 뒤에 흐린 몸 윤곽(어디에 붙는지 보이게)
void _ghost(Canvas cv, double r) {
  final p = mochiPath(r);
  cv.drawPath(p, Paint()..color = const Color(0xFF94A3B8).withValues(alpha: 0.18));
  cv.drawPath(p, _thin(const Color(0xFF94A3B8).withValues(alpha: 0.55), max(1.0, r * 0.05)));
}

class GearIconPainter extends CustomPainter {
  final String id;
  final Color body;
  const GearIconPainter(this.id, this.body);

  @override
  void paint(Canvas canvas, Size size) {
    final item = Gear.byId(id);
    if (item == null) return;
    final s = min(size.width, size.height);
    final ctr = size.center(Offset.zero);
    canvas.save();
    switch (item.slot) {
      case GearSlot.hands:
        final r = s * 1.25;
        final a = handAnchor(r, 1);
        canvas.translate(ctr.dx - a.dx, ctr.dy - a.dy);
        paintGearHand(canvas, r, id, a, 1, body);
      case GearSlot.feet:
        final r = s * 1.25;
        final a = footAnchor(r, 1);
        final lift = id.startsWith('rocket_') ? s * 0.2 : 0.0;
        canvas.translate(ctr.dx - a.dx, ctr.dy - a.dy - lift);
        paintGearFoot(canvas, r, id, a, 1, 0, false);
      case GearSlot.back:
        final r = s * 0.3;
        canvas.translate(ctr.dx, ctr.dy + s * 0.12);
        paintGearBack(canvas, r, id, 0);
        _ghost(canvas, r);
      case GearSlot.head:
        final r = s * 0.36;
        canvas.translate(ctr.dx, ctr.dy + s * 0.16);
        _ghost(canvas, r);
        paintGearHead(canvas, r, id, 0);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GearIconPainter old) => old.id != id || old.body != body;
}
