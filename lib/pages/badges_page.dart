import 'package:flutter/material.dart';

import '../achievement_manager.dart';
import '../badges.dart';
import '../design_system.dart';
import '../language_manager.dart';

// ─────────────────────────────────────────────────────────────
// 뱃지 페이지 — 진행률 · 등급별 개수 · 분류 필터 · 격자. 뱃지를 누르면 위쪽 설명 영역에 이름·등급·조건·획득 여부.
// 하단 메뉴 '뱃지' 탭. docs/BADGES.md
// ─────────────────────────────────────────────────────────────
class BadgesPage extends StatefulWidget {
  /// 뒤로 가기(하단 탭에서는 홈으로). 없으면 Navigator.pop
  final VoidCallback? onBack;
  const BadgesPage({super.key, this.onBack});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  Set<String> _owned = {};
  BadgeCategory? _filter; // null = 전체
  BadgeDef? _selected;

  @override
  void initState() {
    super.initState();
    AchievementManager.getMine().then((keys) {
      if (!mounted) return;
      final owned = keys.toSet();
      setState(() {
        _owned = owned;
        _selected = Badges.best(owned) ?? Badges.all.first;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final earned = Badges.all.where((b) => _owned.contains(b.key)).toList();
    final list = Badges.all.where((b) => _filter == null || b.category == _filter).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 머리 ──
            NeonAppBar(
              title: lm.translate('nav_badges'),
              showBackButton: true,
              onBack: widget.onBack,
              actions: [Text('${earned.length} / ${Badges.all.length}', style: AppTextStyles.display(16, color: AppColors.textDim))],
            ),
            // ── 진행률 · 등급별 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: earned.length / Badges.all.length,
                      minHeight: 8,
                      backgroundColor: AppColors.surface2,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (int t = 1; t <= 4; t++) ...[
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: BadgeDef.tierColor(t), shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(
                          '${lm.translate('badge_tier_$t')} ${earned.where((b) => b.tier == t).length}/${Badges.all.where((b) => b.tier == t).length}',
                          style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w700),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // ── 설명 영역 ──
            if (_selected != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _detail(lm, _selected!),
              ),
            // ── 분류 필터 ──
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                children: [
                  _chip(lm.translate('badge_filter_all'), null, earned.length, Badges.all.length),
                  for (final c in BadgeCategory.values)
                    _chip(lm.translate('badge_cat_${c.name}'), c, earned.where((b) => b.category == c).length,
                        Badges.all.where((b) => b.category == c).length),
                ],
              ),
            ),
            // ── 격자 ──
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 96,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.78,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) => _tile(lm, list[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, BadgeCategory? c, int got, int total) {
    final sel = _filter == c;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = c),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: sel ? AppColors.primary : AppColors.line),
          ),
          child: Text('$label $got/$total',
              style: AppTextStyles.text(12, color: sel ? AppColors.background : AppColors.textDim, weight: FontWeight.w800)),
        ),
      ),
    );
  }

  Widget _tile(LanguageManager lm, BadgeDef b) {
    final got = _owned.contains(b.key);
    final sel = _selected?.key == b.key;
    return GestureDetector(
      onTap: () => setState(() => _selected = b),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
        decoration: BoxDecoration(
          color: sel ? b.color.withValues(alpha: 0.14) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? b.color : AppColors.line, width: sel ? 2 : 1),
        ),
        child: Column(
          children: [
            BadgeIcon(badge: b, size: 44, locked: !got),
            const Spacer(),
            Text(lm.translate(b.nameKey),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.text(11, weight: FontWeight.w800, color: got ? AppColors.text : AppColors.textDim, height: 1.2)),
          ],
        ),
      ),
    );
  }

  /// 고른 뱃지 설명 — 큰 아이콘 · 이름 · 등급/분류 · 조건 · 획득 여부
  Widget _detail(LanguageManager lm, BadgeDef b) {
    final got = _owned.contains(b.key);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: got ? b.color : AppColors.line, width: got ? 1.5 : 1),
      ),
      child: Row(
        children: [
          BadgeIcon(badge: b, size: 64, locked: !got),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(lm.translate(b.nameKey),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.text(17, weight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 8),
                    _pill(lm.translate('badge_tier_${b.tier}'), b.color),
                  ],
                ),
                const SizedBox(height: 4),
                Text(lm.translate(b.descKey), style: AppTextStyles.text(13, color: AppColors.text, height: 1.35)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(got ? Icons.check_circle_rounded : Icons.lock_outline_rounded, size: 14, color: got ? AppColors.up : AppColors.textDim),
                    const SizedBox(width: 4),
                    Text(lm.translate(got ? 'badge_earned' : 'badge_locked'),
                        style: AppTextStyles.text(11, color: got ? AppColors.up : AppColors.textDim, weight: FontWeight.w800)),
                    const SizedBox(width: 10),
                    Text(lm.translate('badge_cat_${b.category.name}'), style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: AppTextStyles.text(10, color: c, weight: FontWeight.w900)),
      );
}
