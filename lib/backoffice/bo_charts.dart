import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'bo_common.dart';

// ─────────────────────────────────────────────────────────────
// 차트 — 패키지 없이 CustomPaint. 세로 막대(누적 가능) + 선(선택) · 가로 눈금 · 마우스 올리면 값.
// ─────────────────────────────────────────────────────────────
class BoSeries {
  final String name;
  final Color color;
  final List<double> values;
  const BoSeries(this.name, this.color, this.values);
}

class BoChart extends StatefulWidget {
  final List<String> labels;
  final List<BoSeries> bars; // 누적 막대
  final BoSeries? line; // 막대 위 선(같은 축)
  final double height;
  final String Function(double v)? format;
  const BoChart({super.key, required this.labels, this.bars = const [], this.line, this.height = 200, this.format});

  @override
  State<BoChart> createState() => _BoChartState();
}

class _BoChartState extends State<BoChart> {
  int? _hover;

  String _fmt(double v) => widget.format?.call(v) ?? fmtNum(v);

  @override
  Widget build(BuildContext context) {
    final legend = [...widget.bars, ?widget.line];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (legend.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(spacing: 14, children: [
              for (final s in legend)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 10,
                    height: s == widget.line ? 3 : 10,
                    decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 5),
                  Text(s.name, style: Bo.caption.copyWith(color: Bo.text2)),
                ]),
            ]),
          ),
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(builder: (context, c) {
            final painter = _ChartPainter(
              labels: widget.labels,
              bars: widget.bars,
              line: widget.line,
              hover: _hover,
              fmt: _fmt,
            );
            return MouseRegion(
              onHover: (e) {
                final i = painter.indexAt(e.localPosition, c.biggest);
                if (i != _hover) setState(() => _hover = i);
              },
              onExit: (_) => setState(() => _hover = null),
              child: CustomPaint(size: c.biggest, painter: painter),
            );
          }),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<String> labels;
  final List<BoSeries> bars;
  final BoSeries? line;
  final int? hover;
  final String Function(double) fmt;
  final bool dark = Bo.isDark;
  _ChartPainter({required this.labels, required this.bars, required this.line, required this.hover, required this.fmt});

  static const double _left = 40, _bottom = 22, _top = 8, _right = 4;

  int get n => labels.length;

  double _stackAt(int i) => bars.fold<double>(0, (a, s) => a + (i < s.values.length ? s.values[i] : 0));

  double get _max {
    double m = 0;
    for (int i = 0; i < n; i++) {
      m = math.max(m, _stackAt(i));
      if (line != null && i < line!.values.length) m = math.max(m, line!.values[i]);
    }
    return _niceMax(m);
  }

  /// 눈금 4칸이 깔끔한 정수가 되도록(1·2·3·5 단계)
  static double _niceMax(double m) {
    if (m <= 0) return 4;
    final raw = m / 4;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    var step = 10 * mag;
    for (final f in const [1.0, 2.0, 3.0, 5.0, 10.0]) {
      if (f * mag >= raw) {
        step = f * mag;
        break;
      }
    }
    if (step < 1) step = 1;
    return step * 4;
  }

  Rect _plot(Size s) => Rect.fromLTRB(_left, _top, s.width - _right, s.height - _bottom);

  int? indexAt(Offset p, Size s) {
    final r = _plot(s);
    if (n == 0 || p.dx < r.left || p.dx > r.right) return null;
    return ((p.dx - r.left) / (r.width / n)).floor().clamp(0, n - 1);
  }

  void _text(Canvas c, String s, Offset at, {TextStyle? style, TextAlign align = TextAlign.center, double? maxW}) {
    final tp = TextPainter(text: TextSpan(text: s, style: style ?? Bo.caption), textDirection: TextDirection.ltr, textAlign: align)
      ..layout(maxWidth: maxW ?? 200);
    final dx = switch (align) { TextAlign.right => at.dx - tp.width, TextAlign.center => at.dx - tp.width / 2, _ => at.dx };
    tp.paint(c, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = _plot(size);
    final max = _max;
    final grid = Paint()
      ..color = Bo.lineSoft
      ..strokeWidth = 1;
    // 가로 눈금 4칸
    for (int k = 0; k <= 4; k++) {
      final y = r.bottom - r.height * k / 4;
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), k == 0 ? (Paint()..color = Bo.line) : grid);
      _text(canvas, fmt(max * k / 4), Offset(r.left - 8, y), align: TextAlign.right);
    }
    if (n == 0) return;
    final slot = r.width / n;
    final bw = math.min(28.0, slot * 0.56);
    // 호버 배경
    if (hover != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(r.left + slot * hover!, r.top, slot, r.height), const Radius.circular(4)),
        Paint()..color = Bo.hoverStrong,
      );
    }
    // 막대
    for (int i = 0; i < n; i++) {
      final cx = r.left + slot * (i + 0.5);
      double acc = 0;
      for (int si = 0; si < bars.length; si++) {
        final v = i < bars[si].values.length ? bars[si].values[i] : 0.0;
        if (v <= 0) continue;
        final y0 = r.bottom - r.height * acc / max;
        final y1 = r.bottom - r.height * (acc + v) / max;
        acc += v;
        final isTop = bars.skip(si + 1).every((s) => i >= s.values.length || s.values[i] <= 0);
        final rect = Rect.fromLTRB(cx - bw / 2, y1, cx + bw / 2, y0);
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect,
              topLeft: isTop ? const Radius.circular(3) : Radius.zero, topRight: isTop ? const Radius.circular(3) : Radius.zero),
          Paint()..color = (hover == null || hover == i) ? bars[si].color : bars[si].color.withValues(alpha: 0.55),
        );
      }
      // x 라벨 — 칸이 좁으면 건너뛴다
      final every = slot < 34 ? 2 : 1;
      if (i % every == 0 || i == n - 1) _text(canvas, labels[i], Offset(cx, r.bottom + 12));
    }
    // 선
    if (line != null && line!.values.isNotEmpty) {
      final p = Path();
      final pts = <Offset>[];
      for (int i = 0; i < n && i < line!.values.length; i++) {
        final pt = Offset(r.left + slot * (i + 0.5), r.bottom - r.height * line!.values[i] / max);
        pts.add(pt);
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(
        p,
        Paint()
          ..color = line!.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
      for (final pt in pts) {
        canvas.drawCircle(pt, 3.2, Paint()..color = Bo.surface);
        canvas.drawCircle(
            pt,
            3.2,
            Paint()
              ..color = line!.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8);
      }
    }
    // 툴팁
    if (hover != null) {
      final i = hover!;
      final lines = <(String, Color)>[
        for (final s in bars) ('${s.name}  ${fmt(i < s.values.length ? s.values[i] : 0)}', s.color),
        if (line != null) ('${line!.name}  ${fmt(i < line!.values.length ? line!.values[i] : 0)}', line!.color),
      ];
      const lh = 17.0;
      final w = 150.0, h = 24 + lh * lines.length;
      var x = r.left + slot * (i + 0.5) + 12;
      if (x + w > size.width) x = r.left + slot * (i + 0.5) - 12 - w;
      final box = RRect.fromRectAndRadius(Rect.fromLTWH(x, r.top + 4, w, h), const Radius.circular(6));
      canvas.drawRRect(box.shift(const Offset(0, 1)), Paint()..color = Colors.black.withValues(alpha: 0.06));
      canvas.drawRRect(box, Paint()..color = Bo.surface2);
      canvas.drawRRect(
          box,
          Paint()
            ..color = Bo.line
            ..style = PaintingStyle.stroke);
      _text(canvas, labels[i], Offset(x + 10, r.top + 16),
          style: Bo.caption.copyWith(color: Bo.text, fontWeight: FontWeight.w600), align: TextAlign.left);
      for (int k = 0; k < lines.length; k++) {
        final y = r.top + 16 + lh * (k + 1);
        canvas.drawCircle(Offset(x + 14, y), 3.5, Paint()..color = lines[k].$2);
        _text(canvas, lines[k].$1, Offset(x + 22, y), style: Bo.caption.copyWith(color: Bo.text2), align: TextAlign.left);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.hover != hover || old.labels != labels || old.bars != bars || old.line != line || old.dark != dark;
}

/// 도넛 조각 하나
class BoSlice {
  final String label;
  final double value;
  final Color color;
  const BoSlice(this.label, this.value, this.color);
}

/// 작은 도넛 + 범례(비율)
class BoDonut extends StatelessWidget {
  final List<BoSlice> slices;
  final double size;
  final String? center;
  final String? centerSub;
  const BoDonut({super.key, required this.slices, this.size = 120, this.center, this.centerSub});

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (a, s) => a + s.value);
    return Row(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(alignment: Alignment.center, children: [
            CustomPaint(size: Size.square(size), painter: _DonutPainter(slices, total)),
            Column(mainAxisSize: MainAxisSize.min, children: [
              if (center != null) Text(center!, style: Bo.h2.copyWith(fontSize: 17, fontFeatures: Bo.tabular)),
              if (centerSub != null) Text(centerSub!, style: Bo.caption),
            ]),
          ]),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final s in slices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(width: 9, height: 9, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.label, style: Bo.body, overflow: TextOverflow.ellipsis)),
                    Text(fmtNum(s.value), style: Bo.cellStrong),
                    SizedBox(
                      width: 56,
                      child: Text(fmtPct(s.value, total), textAlign: TextAlign.right, style: Bo.muted),
                    ),
                  ]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<BoSlice> slices;
  final double total;
  final bool dark = Bo.isDark;
  _DonutPainter(this.slices, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const stroke = 16.0;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(r, 0, math.pi * 2, false,
        Paint()
          ..color = Bo.track
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
    if (total <= 0) return;
    double start = -math.pi / 2;
    for (final s in slices) {
      final sweep = math.pi * 2 * s.value / total;
      if (sweep <= 0) continue;
      canvas.drawArc(r, start, math.max(0, sweep - 0.02), false,
          Paint()
            ..color = s.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.slices != slices || old.total != total || old.dark != dark;
}
