import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../avatar.dart';
import '../design_system.dart';
import '../language_manager.dart';
import '../season.dart';
import '../store_shot.dart';
import '../world_config.dart';

// ─────────────────────────────────────────────────────────────
// 명예의 전당(2026-10-26 · 2026-10-28 트로피 홀로 다시 그림) — 끝난 시즌마다 존별 TOP 3 가 영원히 남는다.
// hall_of_fame/{시즌 id}(공개 읽기), 쓰기는 서버 함수(functions/season.js — 시즌이 끝난 뒤 첫 실행에 한 번).
// 랭킹 머리의 시즌 칩을 누르면 온다.
//
// 화면(docs/UI_DESIGN.md §4.9):
//   · 머리 — 트로피(assets/images/hall/trophy.png, 없으면 코드 드로잉) 뒤로 금빛 빛줄기가 천천히 돌고 금가루가 떠오른다.
//     지금 시즌 이름 · 마감까지 · 설명 한 줄
//   · 시즌 고르기 — 끝난 시즌이 둘 이상이면 칩 한 줄(최신이 앞)
//   · 존 상패 — 존마다 카드 하나: 존 히어로 띠 → 1위 메달리온(금 테 + 반짝임 쓸기, 전신 아바타가 오라까지 움직인다) · 이름 · 국기 · 기록 →
//     2·3위는 은·동 메달 줄. 카드는 위에서 아래로 차례로 떠오른다(시즌을 바꾸면 다시)
//   · 빈 상태 — 빈 포디움 실루엣 + "시즌이 끝나면 여기 새겨져요"
// 색은 디자인 시스템(AppColors — 라이트·다크 둘 다) · gold 는 1위에만 · 2·3위는 silver/bronze · 존 색은 그 존 상패에만.
// 움직임은 MediaQuery.disableAnimations 면 멈춘다.
// ─────────────────────────────────────────────────────────────
class HallOfFamePage extends StatefulWidget {
  final VoidCallback onBack;
  const HallOfFamePage({super.key, required this.onBack});

  @override
  State<HallOfFamePage> createState() => _HallOfFamePageState();
}

class _HallOfFamePageState extends State<HallOfFamePage> {
  bool _loading = true;
  List<HallOfFameSeason> _seasons = const [];
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<HallOfFameSeason> out = const [];
    if (kStoreShot) {
      out = StoreShot.hallOfFame();
    } else if (!kIsWeb) {
      try {
        final snap = await FirebaseFirestore.instance.collection('hall_of_fame').orderBy('end', descending: true).limit(24).get();
        out = [for (final d in snap.docs) HallOfFameSeason.fromDoc(d.id, d.data())];
      } catch (e) {
        debugPrint('Hall of fame load failed: $e');
      }
    }
    if (mounted) {
      setState(() {
        _seasons = out;
        _selected = 0;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final cur = Season.now;
    final sel = _seasons.isEmpty ? null : _seasons[_selected.clamp(0, _seasons.length - 1)];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NeonAppBar(title: lm.translate('hall_of_fame'), showBackButton: true, onBack: widget.onBack),
            Expanded(
              child: _loading
                  ? const AppLoading()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
                      children: [
                        _HallHero(season: cur),
                        const SizedBox(height: 16),
                        if (sel == null)
                          _EmptyHall(season: cur)
                        else ...[
                          if (_seasons.length > 1) ...[
                            _seasonPicker(lm),
                            const SizedBox(height: 12),
                          ],
                          _SeasonWing(key: ValueKey('wing_${sel.id}'), season: sel),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 끝난 시즌 고르기 — 최신이 앞. 고른 칩은 글자색으로 채운다(gold 는 1위 전용이라 쓰지 않는다)
  Widget _seasonPicker(LanguageManager lm) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            for (var i = 0; i < _seasons.length; i++) ...[
              AppChip(
                label: seasonTitle(lm, _seasons[i].info),
                color: i == _selected ? AppColors.text : null,
                filled: i == _selected,
                onTap: () => setState(() => _selected = i),
              ),
              if (i < _seasons.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      );
}

/// '2026 시즌' · '프리시즌'
String seasonTitle(LanguageManager lm, SeasonInfo se) =>
    se.isPreSeason ? lm.translate('season_pre') : lm.translate('season_name').replaceAll('{s}', se.label);

String _date(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  return '${l.year}.${l.month.toString().padLeft(2, '0')}.${l.day.toString().padLeft(2, '0')}';
}

/// 시즌 기간 '2026.01.01 – 2026.12.31'(끝은 포함하지 않는 순간이라 1초 전 날짜)
String _range(DateTime? start, DateTime? end) => '${_date(start)} – ${_date(end?.subtract(const Duration(seconds: 1)))}';

bool _still(BuildContext context) => MediaQuery.disableAnimationsOf(context);

// ─────────────────────────────────────────────────────────────
// 머리 — 트로피 · 빛줄기 · 금가루 · 지금 시즌
// ─────────────────────────────────────────────────────────────
class _HallHero extends StatefulWidget {
  final SeasonInfo season;
  const _HallHero({required this.season});

  @override
  State<_HallHero> createState() => _HallHeroState();
}

class _HallHeroState extends State<_HallHero> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(minutes: 1));
  final Stopwatch _clock = Stopwatch()..start();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final se = widget.season;
    final gold = AppColors.gold;
    final String sub;
    if (se.isPreSeason) {
      sub = lm.translate('hall_pre_starts').replaceAll('{date}', _date(se.end));
    } else {
      final d = se.daysLeft;
      final left = d <= 0 ? lm.translate('season_ends_today') : lm.translate('season_ends_in').replaceAll('{d}', '$d');
      sub = '$left · ${_date(se.end.subtract(const Duration(seconds: 1)))}';
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withValues(alpha: AppColors.isDark ? 0.35 : 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => CustomPaint(
          painter: _HallGlowPainter(t: _clock.elapsedMicroseconds / 1e6, gold: gold, surface: AppColors.surface, dark: AppColors.isDark),
          child: child,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Trophy(size: 104),
              const SizedBox(height: 12),
              Text(lm.translate('hall_tagline'), style: AppTextStyles.label(color: gold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(seasonTitle(lm, se), style: AppTextStyles.display(22), textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(sub, style: AppTextStyles.text(12, color: AppColors.textDim, weight: FontWeight.w700), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(lm.translate('hall_desc'),
                  style: AppTextStyles.text(12, color: AppColors.textDim, height: 1.4), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// 머리 바탕 — 크림(라이트)·숯(다크) 바탕 위로 트로피 뒤에서 뻗는 빛줄기가 천천히 돌고, 금가루가 떠오르며 깜빡인다
class _HallGlowPainter extends CustomPainter {
  final double t;
  final Color gold;
  final Color surface;
  final bool dark;
  const _HallGlowPainter({required this.t, required this.gold, required this.surface, required this.dark});

  static const int _rays = 12;
  static const int _dust = 26;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = Color.lerp(surface, gold, dark ? 0.05 : 0.08)!);

    // 트로피 자리(패딩 22 + 트로피 반)
    final c = Offset(size.width / 2, 22 + 52);
    final reach = math.max(size.width, size.height) * 1.1;

    // 빛줄기 — 가운데는 또렷하고 멀어질수록 사라진다
    final rayPaint = Paint()
      ..shader = RadialGradient(
        colors: [gold.withValues(alpha: dark ? 0.16 : 0.14), gold.withValues(alpha: 0)],
        stops: const [0.05, 0.75],
      ).createShader(Rect.fromCircle(center: c, radius: reach));
    final spin = t * 0.07;
    for (var i = 0; i < _rays; i++) {
      final a = spin + i * (math.pi * 2 / _rays);
      final w = 0.075 + 0.035 * math.sin(t * 0.9 + i * 1.7); // 숨 쉬듯 두께가 조금씩 변한다
      final p = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a - w) * reach, c.dy + math.sin(a - w) * reach)
        ..lineTo(c.dx + math.cos(a + w) * reach, c.dy + math.sin(a + w) * reach)
        ..close();
      canvas.drawPath(p, rayPaint);
    }

    // 트로피 뒤 후광
    canvas.drawCircle(
      c,
      120,
      Paint()
        ..shader = RadialGradient(
          colors: [gold.withValues(alpha: dark ? 0.34 : 0.26), gold.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: 120)),
    );

    // 금가루 — 저마다 다른 속도로 떠오르며 깜빡인다. 위치는 번호에서 정해져 매 프레임 같은 알갱이다
    for (var i = 0; i < _dust; i++) {
      final fx = _frac(i * 0.6180339887 + 0.17);
      final speed = 0.035 + _frac(i * 0.3819660113) * 0.05;
      final fy = 1 - _frac(t * speed + i * 0.137);
      final tw = 0.5 + 0.5 * math.sin(t * (2.2 + (i % 5) * 0.4) + i);
      final r = 1.2 + _frac(i * 0.7548776662) * 1.8;
      final p = Offset(fx * size.width, fy * size.height);
      final paint = Paint()..color = gold.withValues(alpha: (0.18 + 0.55 * tw) * (dark ? 1 : 0.85));
      canvas.drawCircle(p, r, paint);
      if (r > 2.2) {
        // 큰 알갱이는 십자 별빛
        final l = r * (2.2 + tw);
        canvas.drawLine(p.translate(-l, 0), p.translate(l, 0), paint..strokeWidth = 0.8);
        canvas.drawLine(p.translate(0, -l), p.translate(0, l), paint);
      }
    }

    // 아래로 갈수록 바탕으로 가라앉아 글자가 또렷하다
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [surface.withValues(alpha: 0), surface.withValues(alpha: dark ? 0.55 : 0.6)],
          stops: const [0.45, 1],
        ).createShader(rect),
    );
  }

  static double _frac(double v) => v - v.floorToDouble();

  @override
  bool shouldRepaint(covariant _HallGlowPainter old) => old.t != t || old.gold != gold || old.dark != dark;
}

/// 트로피 — 그림 슬롯(assets/images/hall/trophy.png, Gemini 시안)이 있으면 그것, 없으면 코드 드로잉
class _Trophy extends StatelessWidget {
  final double size;
  const _Trophy({required this.size});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          'assets/images/hall/trophy.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => CustomPaint(painter: _TrophyPainter(AppColors.gold)),
        ),
      );
}

/// 코드 드로잉 트로피 — 금 잔 · 손잡이 두 개 · 받침 · 별 문장
class _TrophyPainter extends CustomPainter {
  final Color gold;
  const _TrophyPainter(this.gold);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final light = Color.lerp(gold, Colors.white, 0.5)!;
    final deep = Color.lerp(gold, Colors.black, 0.38)!;
    final mid = Color.lerp(gold, Colors.black, 0.12)!;

    Paint metal(Rect r, {bool vertical = false}) => Paint()
      ..shader = LinearGradient(
        begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
        end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
        colors: [deep, gold, light, gold, deep],
        stops: const [0, 0.3, 0.5, 0.72, 1],
      ).createShader(r);

    // 그림자
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.955), width: w * 0.58, height: h * 0.06),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    // 받침 두 단
    final base = RRect.fromRectAndRadius(Rect.fromLTRB(w * 0.27, h * 0.86, w * 0.73, h * 0.95), Radius.circular(w * 0.03));
    canvas.drawRRect(base, metal(base.outerRect));
    final plinth = RRect.fromRectAndRadius(Rect.fromLTRB(w * 0.36, h * 0.80, w * 0.64, h * 0.87), Radius.circular(w * 0.02));
    canvas.drawRRect(plinth, metal(plinth.outerRect));

    // 기둥 + 마디
    final stem = Path()
      ..moveTo(w * 0.45, h * 0.64)
      ..lineTo(w * 0.55, h * 0.64)
      ..lineTo(w * 0.58, h * 0.81)
      ..lineTo(w * 0.42, h * 0.81)
      ..close();
    canvas.drawPath(stem, metal(stem.getBounds()));
    final knob = Rect.fromCenter(center: Offset(w * 0.5, h * 0.715), width: w * 0.2, height: h * 0.06);
    canvas.drawOval(knob, metal(knob));

    // 손잡이
    final handle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round
      ..color = mid;
    final left = Path()
      ..moveTo(w * 0.21, h * 0.24)
      ..cubicTo(w * -0.02, h * 0.26, w * 0.0, h * 0.56, w * 0.27, h * 0.52);
    canvas.drawPath(left, handle);
    final right = Path()
      ..moveTo(w * 0.79, h * 0.24)
      ..cubicTo(w * 1.02, h * 0.26, w * 1.0, h * 0.56, w * 0.73, h * 0.52);
    canvas.drawPath(right, handle);

    // 잔
    final cup = Path()
      ..moveTo(w * 0.19, h * 0.17)
      ..cubicTo(w * 0.19, h * 0.50, w * 0.34, h * 0.64, w * 0.50, h * 0.66)
      ..cubicTo(w * 0.66, h * 0.64, w * 0.81, h * 0.50, w * 0.81, h * 0.17)
      ..close();
    canvas.drawPath(cup, metal(cup.getBounds()));
    // 테두리 — 입구 타원(안쪽은 어둡게 깊이)
    final rim = Rect.fromLTRB(w * 0.19, h * 0.11, w * 0.81, h * 0.23);
    canvas.drawOval(rim, metal(rim));
    canvas.drawOval(rim.deflate(w * 0.035), Paint()..color = deep.withValues(alpha: 0.9));
    canvas.drawOval(
      Rect.fromLTRB(w * 0.25, h * 0.145, w * 0.75, h * 0.205),
      Paint()..color = Color.lerp(deep, Colors.black, 0.3)!,
    );

    // 하이라이트
    canvas.drawLine(
      Offset(w * 0.30, h * 0.27),
      Offset(w * 0.31, h * 0.50),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round,
    );

    // 별 문장
    final star = Path();
    final sc = Offset(w * 0.5, h * 0.41);
    final ro = w * 0.085, ri = ro * 0.45;
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final r = i.isEven ? ro : ri;
      final p = Offset(sc.dx + math.cos(a) * r, sc.dy + math.sin(a) * r);
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    canvas.drawPath(star, Paint()..color = deep.withValues(alpha: 0.85));
    canvas.drawPath(star.shift(Offset(0, -h * 0.008)), Paint()..color = light.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(covariant _TrophyPainter old) => old.gold != gold;
}

// ─────────────────────────────────────────────────────────────
// 시즌 한 벌 — 제목 + 존 상패 3장
// ─────────────────────────────────────────────────────────────
class _SeasonWing extends StatelessWidget {
  final HallOfFameSeason season;
  const _SeasonWing({super.key, required this.season});

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
          child: Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(seasonTitle(lm, season.info), style: AppTextStyles.display(18), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Text(_range(season.start, season.end), style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w700)),
            ],
          ),
        ),
        for (var i = 0; i < WorldData.worlds.length; i++) ...[
          _Reveal(
            delay: Duration(milliseconds: 90 * i),
            child: _ZonePlaque(
              world: WorldData.worlds[i],
              records: season.zones[WorldData.worlds[i].rankingMapId] ?? const [],
            ),
          ),
          if (i < WorldData.worlds.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

/// 아래에서 떠오르며 나타난다 — [delay] 뒤에 한 번. 움직임을 끈 기기에서는 바로 보인다
class _Reveal extends StatefulWidget {
  final Duration delay;
  final Widget child;
  const _Reveal({required this.delay, required this.child});

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final Animation<double> _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _rise =
      Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_still(context)) {
      _c.value = 1;
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _fade, child: SlideTransition(position: _rise, child: widget.child));
}

// ─────────────────────────────────────────────────────────────
// 존 상패 — 히어로 띠 · 1위 메달리온 · 2·3위 메달 줄
// ─────────────────────────────────────────────────────────────
class _ZonePlaque extends StatelessWidget {
  final WorldConfig world;
  final List<Map<String, dynamic>> records;
  const _ZonePlaque({required this.world, required this.records});

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final top = records.take(3).toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _band(lm),
          if (top.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
              child: Column(
                children: [
                  Icon(Icons.emoji_events_outlined, color: AppColors.textDim.withValues(alpha: 0.6), size: 30),
                  const SizedBox(height: 8),
                  Text(lm.translate('hall_zone_empty'),
                      style: AppTextStyles.text(13, color: AppColors.textDim), textAlign: TextAlign.center),
                ],
              ),
            )
          else ...[
            _champion(lm, top[0]),
            if (top.length > 1) ...[
              Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 16), color: AppColors.line),
              for (var i = 1; i < top.length; i++) _MinorRow(rank: i + 1, record: top[i], zone: world.id),
              const SizedBox(height: 6),
            ] else
              const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  /// 존 히어로 그림 띠(assets/images/worlds/{id}_hero.png, 없으면 존 색) — 아래로 갈수록 카드로 가라앉고, 위에 존 이름
  Widget _band(LanguageManager lm) {
    final accent = world.accent;
    return SizedBox(
      height: 68,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/worlds/${world.id}_hero.png',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.6),
            errorBuilder: (_, _, _) => Container(color: accent.withValues(alpha: 0.22)),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0B0D12).withValues(alpha: 0.30),
                  const Color(0xFF0B0D12).withValues(alpha: 0.45),
                  AppColors.surface,
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 14,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(999)),
                  child: Text(lm.translate('stage_n').replaceAll('{n}', '${world.difficulty}'),
                      style: AppTextStyles.display(10, color: AppColors.on(accent))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lm.translate(world.nameKey),
                    style: AppTextStyles.display(16, color: Colors.white).copyWith(
                      shadows: [Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 6)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('TOP 3', style: AppTextStyles.label(color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 1위 — 금 메달리온 속 전신 아바타(오라까지) · CHAMPION · 이름 · 국기 · 기록(금)
  Widget _champion(LanguageManager lm, Map<String, dynamic> r) {
    final gold = AppColors.gold;
    final name = (r['nickname'] as String?)?.trim().isNotEmpty == true ? r['nickname'] as String : lm.translate('unknown');
    final time = ((r['survivalTime'] as num?) ?? 0).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _Medallion(avatar: Avatar.fromRecord(r, zone: world.id), zone: world.id),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: gold, size: 16),
                    const SizedBox(width: 4),
                    Text(lm.translate('hall_champion'), style: AppTextStyles.label(color: gold)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(
                      child: Text(name, style: AppTextStyles.display(18), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    CountryChip(flag: (r['flag'] as String?) ?? '', height: 14),
                  ],
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: formatSurvival(time), style: AppTextStyles.display(28, color: gold)),
                    TextSpan(text: ' s', style: AppTextStyles.text(12, color: AppColors.textDim, weight: FontWeight.w800)),
                  ]),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 2·3위 한 줄 — 은·동 메달 · 아바타 · 이름 · 국기 · 기록
class _MinorRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> record;
  final String zone;
  const _MinorRow({required this.rank, required this.record, required this.zone});

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final medal = rank == 2 ? AppColors.silver : AppColors.bronze;
    final r = record;
    final name = (r['nickname'] as String?)?.trim().isNotEmpty == true ? r['nickname'] as String : lm.translate('unknown');
    final time = ((r['survivalTime'] as num?) ?? 0).toDouble();
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(medal, Colors.white, 0.35)!, medal, Color.lerp(medal, Colors.black, 0.25)!],
              ),
            ),
            child: Text('$rank', style: AppTextStyles.display(11, color: AppColors.on(medal))),
          ),
          const SizedBox(width: 10),
          AvatarView(avatar: Avatar.fromRecord(r, zone: zone), zone: zone, size: 32, borderColor: medal),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(name, style: AppTextStyles.text(14, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                CountryChip(flag: (r['flag'] as String?) ?? '', height: 13),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: formatSurvival(time), style: AppTextStyles.display(15)),
              TextSpan(text: 's', style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
    );
  }
}

/// 1위 메달리온 — 금 후광 · 금 테(그라데이션) 위로 3.6초마다 빛이 한 번 쓸고 지나간다 · 전신 아바타(오라까지) · 아래 "1" 메달
class _Medallion extends StatefulWidget {
  final Avatar avatar;
  final String zone;
  const _Medallion({required this.avatar, required this.zone});

  @override
  State<_Medallion> createState() => _MedallionState();
}

class _MedallionState extends State<_Medallion> with SingleTickerProviderStateMixin {
  static const double _size = 112;
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.gold;
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              size: const Size.square(_size),
              painter: _MedallionPainter(gold: gold, surface: AppColors.surface2, sweep: _c.value, dark: AppColors.isDark),
            ),
          ),
          // 전신 아바타 — 오라·잔상이 테 밖까지 나온다
          AvatarStage(avatar: widget.avatar, size: 92, zone: widget.zone),
          Positioned(
            bottom: 2,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: gold,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
              child: Text('1', style: AppTextStyles.display(11, color: AppColors.on(gold))),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedallionPainter extends CustomPainter {
  final Color gold;
  final Color surface;
  /// 0~1 한 주기 — 앞 30% 동안 빛이 왼쪽 위에서 오른쪽 아래로 쓸고, 나머지는 쉰다
  final double sweep;
  final bool dark;
  const _MedallionPainter({required this.gold, required this.surface, required this.sweep, required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final ringR = size.width * 0.40;

    // 후광
    canvas.drawCircle(
      c,
      size.width * 0.5,
      Paint()
        ..shader = RadialGradient(
          colors: [gold.withValues(alpha: dark ? 0.38 : 0.30), gold.withValues(alpha: 0)],
          stops: const [0.55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: size.width * 0.5)),
    );

    // 원판 + 금 테
    final ring = Rect.fromCircle(center: c, radius: ringR);
    canvas.drawCircle(c, ringR, Paint()..color = surface);
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 2,
          colors: [
            Color.lerp(gold, Colors.white, 0.45)!,
            gold,
            Color.lerp(gold, Colors.black, 0.3)!,
            gold,
            Color.lerp(gold, Colors.white, 0.45)!,
          ],
          stops: const [0, 0.25, 0.55, 0.8, 1],
          transform: const GradientRotation(-math.pi / 3),
        ).createShader(ring),
    );

    // 반짝임 쓸기 — 원판 안에서만
    if (sweep < 0.3) {
      final p = Curves.easeInOut.transform(sweep / 0.3);
      final d = ringR * 2.6;
      final x = -d * 0.6 + d * 1.2 * p;
      canvas.save();
      canvas.clipPath(Path()..addOval(ring.inflate(1.5)));
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-math.pi / 4);
      final band = Rect.fromLTWH(x - ringR * 0.22, -d, ringR * 0.44, d * 2);
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: dark ? 0.32 : 0.55),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(band),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _MedallionPainter old) =>
      old.sweep != sweep || old.gold != gold || old.surface != surface || old.dark != dark;
}

// ─────────────────────────────────────────────────────────────
// 빈 상태 — 아직 끝난 시즌이 없다: 빈 포디움 실루엣
// ─────────────────────────────────────────────────────────────
class _EmptyHall extends StatelessWidget {
  final SeasonInfo season;
  const _EmptyHall({required this.season});

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final hint = season.isPreSeason
        ? lm.translate('hall_empty_pre')
        : lm.translate('hall_empty_hint').replaceAll('{season}', seasonTitle(lm, season));
    return _Reveal(
      delay: const Duration(milliseconds: 120),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _pedestal(2, 34, AppColors.silver),
                const SizedBox(width: 10),
                _pedestal(1, 52, AppColors.gold),
                const SizedBox(width: 10),
                _pedestal(3, 24, AppColors.bronze),
              ],
            ),
            const SizedBox(height: 22),
            Text(lm.translate('hall_empty'), style: AppTextStyles.text(14, weight: FontWeight.w800), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(hint, style: AppTextStyles.text(12, color: AppColors.textDim, height: 1.4), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  /// 빈 자리 — 점선 동그라미(아직 없는 아바타) + 단
  Widget _pedestal(int rank, double height, Color medal) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size.square(44),
            painter: _DashedCirclePainter(medal.withValues(alpha: 0.7)),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(child: Text('$rank', style: AppTextStyles.display(14, color: medal))),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 64,
            height: height,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(top: BorderSide(color: medal.withValues(alpha: 0.8), width: 2)),
            ),
          ),
        ],
      );
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  const _DashedCirclePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1.5;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    const n = 14;
    for (var i = 0; i < n; i++) {
      final a = i * math.pi * 2 / n;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a, math.pi * 2 / n * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) => old.color != color;
}
