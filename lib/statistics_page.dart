import 'package:flutter/material.dart';

import 'character_data.dart';
import 'design_system.dart';
import 'language_manager.dart';
import 'progress_store.dart';
import 'user_profile.dart';
import 'world_config.dart';

/// 통계 — 이 기기의 플레이 기록 요약. (프로필 → 설정 → 통계)
///
/// 1) 요약 카드: 총 플레이 시간 · 판 수 · 평균 생존
/// 2) 존별: 판 수 비중 막대 + 최고 기록
/// 3) 캐릭터별: 많이 쓴 순
///
/// 칭호(뱃지·타이틀)는 구조 개편 전까지 싣지 않는다.
class StatisticsPage extends StatefulWidget {
  final VoidCallback onBack;

  const StatisticsPage({super.key, required this.onBack});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  bool _loading = true;
  double _totalTime = 0;
  int _totalGames = 0;
  Map<String, int> _zonePlays = {};
  Map<String, double> _bestTimes = {};
  List<MapEntry<String, int>> _characters = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await UserProfileManager.getStatistics();
    final best = await ProgressStore.getBestTimes();

    // 판 수는 랭킹 mapId 로 쌓인다. 존 체계 이전의 mapId(zone_1_classic 등)는
    // 모두 네온 탄막 모드였으므로 ZONE 1 로 합산한다.
    final zonePlays = <String, int>{};
    final raw = Map<String, int>.from(stats['mapPlayCounts'] ?? const <String, int>{});
    raw.forEach((mapId, n) {
      final id = WorldData.byRankingMapId(mapId)?.id ?? WorldData.defaultWorld.id;
      zonePlays[id] = (zonePlays[id] ?? 0) + n;
    });

    final chars = Map<String, int>.from(stats['characterPlayCounts'] ?? const <String, int>{})
        .entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (!mounted) return;
    setState(() {
      _totalTime = (stats['totalPlayTime'] ?? 0.0).toDouble();
      _totalGames = stats['totalGamesPlayed'] ?? 0;
      _zonePlays = zonePlays;
      _bestTimes = best;
      _characters = chars;
      _loading = false;
    });
  }

  /// 1h 05m · 12m 30s · 47.8s
  String _duration(LanguageManager lm, double seconds) {
    if (seconds <= 0) return '0s';
    final d = Duration(milliseconds: (seconds * 1000).round());
    String two(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}h ${two(d.inMinutes.remainder(60))}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${two(d.inSeconds.remainder(60))}s';
    return '${seconds.toStringAsFixed(1)}s';
  }

  String _plays(LanguageManager lm, int n) => lm.translate('stats_plays').replaceAll('{n}', formatCount(n));

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    return NeonScaffold(
      title: lm.translate('stats_title'),
      showBackButton: true,
      onBack: widget.onBack,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _totalGames == 0
              ? _empty(lm)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    _overview(lm),
                    const SizedBox(height: 28),
                    SectionLabel(lm.translate('stats_by_zone')),
                    const SizedBox(height: 10),
                    for (final w in WorldData.worlds) ...[
                      _zoneRow(lm, w),
                      const SizedBox(height: 10),
                    ],
                    if (_characters.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      SectionLabel(lm.translate('stats_by_character')),
                      const SizedBox(height: 10),
                      NeonCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Column(
                          children: [
                            for (int i = 0; i < _characters.length; i++)
                              _characterRow(lm, _characters[i], i == 0, last: i == _characters.length - 1),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(lm.translate('stats_device_note'),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w500)),
                  ],
                ),
    );
  }

  Widget _empty(LanguageManager lm) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insights_rounded, color: AppColors.textDim, size: 44),
              const SizedBox(height: 14),
              Text(lm.translate('stats_empty_title'), style: AppTextStyles.display(18)),
              const SizedBox(height: 6),
              Text(lm.translate('stats_empty_desc'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.text(13, color: AppColors.textDim, weight: FontWeight.w500, height: 1.4)),
            ],
          ),
        ),
      );

  /// 요약 — 큰 숫자 하나(총 플레이 시간) + 보조 지표 둘
  Widget _overview(LanguageManager lm) {
    final avg = _totalGames > 0 ? _totalTime / _totalGames : 0.0;
    return NeonCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lm.translate('stats_total_time'), style: AppTextStyles.label()),
          const SizedBox(height: 8),
          Text(_duration(lm, _totalTime), style: AppTextStyles.display(36)),
          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.line),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _metric(lm.translate('stats_games'), formatCount(_totalGames))),
              Container(width: 1, height: 32, color: AppColors.line),
              const SizedBox(width: 16),
              Expanded(child: _metric(lm.translate('stats_avg_survival'), _duration(lm, avg))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.label()),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.display(20)),
        ],
      );

  /// 존 한 줄 — ZONE n · 이름 / 판 수 비중 막대 / 최고 기록
  Widget _zoneRow(LanguageManager lm, WorldConfig w) {
    final plays = _zonePlays[w.id] ?? 0;
    final share = _totalGames > 0 ? plays / _totalGames : 0.0;
    final best = _bestTimes[w.id] ?? 0;
    return NeonCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: w.accent, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('ZONE ${w.difficulty}', style: AppTextStyles.label(color: w.accent)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(lm.translate(w.nameKey),
                    style: AppTextStyles.text(15, weight: FontWeight.w800), overflow: TextOverflow.ellipsis),
              ),
              Text(lm.translate('stats_best'), style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w700)),
              const SizedBox(width: 6),
              Text(best > 0 ? formatSurvival(best) : '—', style: AppTextStyles.display(16)),
              if (best > 0) Text(' s', style: AppTextStyles.text(11, color: AppColors.textDim)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: share,
                    backgroundColor: AppColors.surface2,
                    valueColor: AlwaysStoppedAnimation(w.accent),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 64,
                child: Text(_plays(lm, plays),
                    textAlign: TextAlign.right,
                    style: AppTextStyles.text(12, color: AppColors.textDim, weight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _characterRow(LanguageManager lm, MapEntry<String, int> e, bool top, {required bool last}) {
    final c = CharacterData.getCharacter(e.key);
    final share = _totalGames > 0 ? e.value / _totalGames : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
      child: Row(
        children: [
          CharacterAvatar(characterId: c.id, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(lm.translate('char_${c.id}'),
                          style: AppTextStyles.text(14, weight: FontWeight.w800), overflow: TextOverflow.ellipsis),
                    ),
                    if (top) ...[
                      const SizedBox(width: 6),
                      AppChip(label: lm.translate('stats_most_used'), color: AppColors.primary, filled: true),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    value: share,
                    backgroundColor: AppColors.surface2,
                    valueColor: AlwaysStoppedAnimation(c.color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            child: Text(_plays(lm, e.value),
                textAlign: TextAlign.right,
                style: AppTextStyles.text(12, color: AppColors.textDim, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
