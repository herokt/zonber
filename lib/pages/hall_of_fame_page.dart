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
// 명예의 전당(2026-10-26) — 끝난 시즌마다 존별 TOP 3 가 영원히 남는다. hall_of_fame/{시즌 id}(공개 읽기),
// 쓰기는 서버 함수(functions/season.js — 시즌이 끝난 뒤 첫 실행에 한 번). 랭킹 머리의 시즌 칩을 누르면 온다.
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<HallOfFameSeason> out = const [];
    if (!kIsWeb && !kStoreShot) {
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
        _loading = false;
      });
    }
  }

  String _date(DateTime? d) {
    if (d == null) return '';
    final l = d.toLocal();
    return '${l.year}.${l.month.toString().padLeft(2, '0')}.${l.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final cur = Season.now;
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
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                      children: [
                        // 지금 시즌 — 마감까지
                        _nowCard(lm, cur),
                        const SizedBox(height: 18),
                        if (_seasons.isEmpty) _empty(lm) else for (final s in _seasons) ...[_seasonCard(lm, s), const SizedBox(height: 14)],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nowCard(LanguageManager lm, SeasonInfo se) {
    final name = se.isPreSeason ? lm.translate('season_pre') : lm.translate('season_name').replaceAll('{s}', se.label);
    final d = se.daysLeft;
    final sub = d <= 0 ? lm.translate('season_ends_today') : lm.translate('season_ends_in').replaceAll('{d}', '$d');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: AppColors.gold, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.display(16)),
                const SizedBox(height: 3),
                Text('$sub · ${_date(se.end.subtract(const Duration(seconds: 1)))}', style: AppTextStyles.text(12, color: AppColors.textDim)),
                const SizedBox(height: 6),
                Text(lm.translate('hall_desc'), style: AppTextStyles.text(12, color: AppColors.textDim, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(LanguageManager lm) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.emoji_events_outlined, color: AppColors.textDim, size: 40),
            const SizedBox(height: 12),
            Text(lm.translate('hall_empty'), style: AppTextStyles.text(14, color: AppColors.textDim), textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _seasonCard(LanguageManager lm, HallOfFameSeason s) {
    final info = s.info;
    final name = info.isPreSeason ? lm.translate('season_pre') : lm.translate('season_name').replaceAll('{s}', info.label);
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 20),
                const SizedBox(width: 8),
                Text(name, style: AppTextStyles.display(16)),
                const Spacer(),
                Text('${_date(s.start)} ~ ${_date(s.end?.subtract(const Duration(seconds: 1)))}',
                    style: AppTextStyles.text(11, color: AppColors.textDim)),
              ],
            ),
          ),
          for (final w in WorldData.worlds) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: w.accent, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(lm.translate(w.nameKey), style: AppTextStyles.label(color: w.accent)),
                ],
              ),
            ),
            if ((s.zones[w.rankingMapId] ?? const []).isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Text(lm.translate('no_ranking_yet'), style: AppTextStyles.text(12, color: AppColors.textDim)),
              )
            else
              for (var i = 0; i < (s.zones[w.rankingMapId]!.length.clamp(0, 3)); i++)
                RankRow(
                  rank: i + 1,
                  nickname: (s.zones[w.rankingMapId]![i]['nickname'] as String?) ?? lm.translate('unknown'),
                  flag: (s.zones[w.rankingMapId]![i]['flag'] as String?) ?? '',
                  avatar: Avatar.fromRecord(s.zones[w.rankingMapId]![i], zone: w.id),
                  zone: w.id,
                  survivalTime: ((s.zones[w.rankingMapId]![i]['survivalTime'] as num?) ?? 0).toDouble(),
                  accent: w.accent,
                  last: i == (s.zones[w.rankingMapId]!.length.clamp(0, 3)) - 1,
                ),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
