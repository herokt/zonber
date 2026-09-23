import 'package:flutter/material.dart';

import '../badges.dart';
import '../audio_manager.dart';
import '../haptics.dart';
import '../design_system.dart';
import '../coin_store.dart';
import '../ad_manager.dart';
import '../language_manager.dart';
import '../progress_store.dart';
import '../ranking_system.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../user_profile.dart';
import '../world_config.dart';

/// 결과 화면 — 생존 시간·델타·순위 카드·새로 얻은 뱃지.
/// (docs/UI_DESIGN.md §4.4)
class ResultPage extends StatefulWidget {
  final WorldConfig world;
  final Map<String, dynamic> result;
  /// 이 판 이전의 개인 최고(초). 0 이면 첫 기록.
  final double previousBest;
  final VoidCallback onRestart;
  final VoidCallback onExit;
  final VoidCallback onNavigateToLogin;
  final VoidCallback onShowRanking;
  /// 부활 콜백 — 보상 지급 시 삭제해야 할 제출 기록 id를 함께 넘긴다.
  final void Function(String? submittedRecordId)? onRevive;
  final int revivesLeft;

  const ResultPage({
    super.key,
    required this.world,
    required this.result,
    required this.previousBest,
    required this.onRestart,
    required this.onExit,
    required this.onNavigateToLogin,
    required this.onShowRanking,
    this.onRevive,
    this.revivesLeft = 0,
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  final RankingSystem _ranking = RankingSystem();
  String? _savedRecordId;
  bool _rankLoading = true;
  int? _worldRank;
  int? _countryRank;
  double? _untilTop100;
  bool _coinsDoubled = false;

  int get _coinsEarned => (widget.result['coinsEarned'] as num?)?.toInt() ?? 0;
  int get _coinsBonus => (widget.result['coinsBonus'] as num?)?.toInt() ?? 0;

  /// 보상형 광고를 보면 이번 판 코인을 한 번 더 준다(2배)
  void _doubleCoins(LanguageManager lm) {
    if (_coinsDoubled || _coinsEarned <= 0) return;
    final shown = AdManager().showRewardedAd(() async {
      await CoinStore.add(_coinsEarned);
      if (mounted) setState(() => _coinsDoubled = true);
    });
    if (!shown && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lm.translate('ad_not_ready'))));
    }
  }

  Widget _coinRow(LanguageManager lm) {
    final earned = _coinsEarned * (_coinsDoubled ? 2 : 1);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const CoinIcon(size: 22),
          const SizedBox(width: 10),
          Text('+${formatCount(earned)}', style: AppTextStyles.display(18, color: AppColors.coin)),
          if (_coinsBonus > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: AppColors.coin.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
              child: Text(lm.translate('coin_bonus').replaceAll('{n}', formatCount(_coinsBonus * (_coinsDoubled ? 2 : 1))),
                  style: AppTextStyles.text(11, color: AppColors.coin, weight: FontWeight.w800)),
            ),
          ],
          const SizedBox(width: 8),
          Flexible(
            child: ValueListenableBuilder<int>(
              valueListenable: CoinStore.balance,
              builder: (context, b, _) => Text(
                lm.translate('coin_balance').replaceAll('{n}', formatCount(b)),
                style: AppTextStyles.text(12, color: AppColors.textDim, weight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const Spacer(),
          if (_coinsDoubled)
            Text(lm.translate('coin_doubled'), style: AppTextStyles.text(12, color: AppColors.coin, weight: FontWeight.w800))
          else if (_coinsEarned > 0)
            GestureDetector(
              onTap: () => _doubleCoins(lm),
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.coin,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 5),
                    Text(lm.translate('coin_double_ad'), style: AppTextStyles.text(12, color: Colors.white, weight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  double get _time => (widget.result['survivalTime'] as num).toDouble();
  bool get _isGuest => AuthService.isGuest;

  int _badgeSounded = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    // 보상 소리 — 코인 받음(0.35초 뒤) · 새 뱃지(0.9초 뒤, 순위 뱃지가 나중에 오면 그때 한 번 더)
    if (_coinsEarned > 0) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) AudioManager().playSfx(Sfx.coin, volume: 0.7);
      });
    }
    Future.delayed(const Duration(milliseconds: 900), _soundBadges);
    Badges.fresh.addListener(_soundBadges);
  }

  void _soundBadges() {
    if (!mounted) return;
    final n = Badges.fresh.value.length;
    if (n > _badgeSounded) {
      _badgeSounded = n;
      AudioManager().playSfx(Sfx.badge, volume: 0.8);
      Haptics.medium();
    }
  }

  Future<void> _run() async {
    final mapId = widget.world.rankingMapId;
    final profile = await UserProfileManager.getProfile();
    final flag = profile['flag'] ?? '';
    final characterId = profile['characterId'] ?? 'neon_green';

    // 1. 가입을 마친(닉네임·국가) 로그인 유저만 기록 제출 (게스트 기록은 남지 않는다)
    if (!_isGuest && UserProfileManager.isCompleteProfile(profile['nickname'], flag, profile['countryName'])) {
      try {
        _savedRecordId = await _ranking.saveRecord(mapId, _time, characterId: characterId, flag: flag);
        AnalyticsService().logScoreSubmit(mapId: mapId, characterId: characterId, survivalTime: _time);
      } catch (e) {
        debugPrint('Score submit failed: $e');
      }
    } else {
      AnalyticsService().logGuestRankingBlocked(survivalTime: _time);
    }

    // 2. 순위 계산 — 게스트도 "잃어버린 순위"를 보여준다
    final global = await _ranking.getGlobalRank(mapId, _time);
    final topTimes = await _ranking.getTopTimes(mapId, limit: 100);
    int? natRank;
    if (flag.isNotEmpty) {
      final nat = await _ranking.getNationalRankings(mapId, flag, period: RankingPeriod.allTime, limit: 500);
      natRank = nat.where((r) => ((r['survivalTime'] as num?) ?? 0).toDouble() > _time).length + 1;
    }
    if (!mounted) return;
    setState(() {
      _worldRank = global?.rank;
      _countryRank = natRank;
      _untilTop100 = topTimes.length >= 100 ? (topTimes[99] - _time).clamp(0, double.infinity) : null;
      _rankLoading = false;
    });
    if (global != null) {
      ProgressStore.setRankCache(widget.world.id, global.rank, global.total);
    }

    // 3. 랭킹 뱃지 — 기록을 낸 회원만(세계 TOP 100 · 30 · 10 · 1위, 국가 TOP 10 · 1위)
    if (!_isGuest && _savedRecordId != null && global != null) {
      try {
        await Badges.evaluate(BadgeContext(stats: await BadgeStatsStore.load(), worldRank: global.rank, countryRank: natRank ?? 0));
      } catch (e) {
        debugPrint('Rank badge check failed: $e');
      }
    }
  }

  @override
  void dispose() {
    Badges.fresh.removeListener(_soundBadges);
    Badges.fresh.value = const []; // 보여 준 새 뱃지는 비운다
    super.dispose();
  }

  /// 이번 판에 새로 얻은 뱃지 — 아이콘 · 이름 · 조건(3개까지, 나머지는 +N)
  Widget _newBadges(LanguageManager lm) => ValueListenableBuilder<List<BadgeDef>>(
        valueListenable: Badges.fresh,
        builder: (context, list, _) => list.isEmpty
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.military_tech_rounded, size: 18, color: AppColors.gold),
                          const SizedBox(width: 6),
                          Text(lm.translate('new_badges'), style: AppTextStyles.label(color: AppColors.gold)),
                          const Spacer(),
                          Text('${list.length}', style: AppTextStyles.display(14, color: AppColors.gold)),
                        ],
                      ),
                      for (final b in list.take(3))
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            children: [
                              BadgeIcon(badge: b, size: 34),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(lm.translate(b.nameKey), style: AppTextStyles.text(14, weight: FontWeight.w900)),
                                    Text(lm.translate(b.descKey),
                                        maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.text(11.5, color: AppColors.textDim)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (list.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(lm.translate('result_badges_more').replaceAll('{n}', '${list.length - 3}'),
                              style: AppTextStyles.text(12, color: AppColors.textDim, weight: FontWeight.w800)),
                        ),
                    ],
                  ),
                ),
              ),
      );

  /// 생존 시간 | 세계 순위 — 같은 크기
  Widget _hero(LanguageManager lm, Color accent, bool isBest, double delta) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lm.translate('survival_time'), style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(formatSurvival(_time), style: AppTextStyles.display(36).copyWith(letterSpacing: -0.5)),
                        const SizedBox(width: 2),
                        Text('s', style: AppTextStyles.display(15, color: AppColors.textDim)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 6),
                  // 게스트는 이전 기록이 없다 — 최고 기록 비교를 보이지 않는다
                  if (!_isGuest)
                  Row(
                    children: [
                      Icon(isBest ? Icons.arrow_upward_rounded : Icons.remove_rounded, size: 13, color: isBest ? AppColors.up : AppColors.textDim),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          widget.previousBest <= 0
                              ? lm.translate('first_record')
                              : isBest
                                  ? lm.translate('best_delta_up').replaceAll('{d}', formatSurvival(delta))
                                  : lm.translate('best_delta_down').replaceAll('{d}', formatSurvival(-delta)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.text(11, color: isBest ? AppColors.up : AppColors.textDim, weight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 14), color: AppColors.line),
            Expanded(child: _heroRank(lm, accent)),
          ],
        ),
      ),
    );
  }

  Widget _heroRank(LanguageManager lm, Color accent) {
    final label = Text(lm.translate('rank_world'), style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w800));
    if (_rankLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [label, const Spacer(), SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: accent)), const Spacer()],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label,
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(_worldRank == null ? '—' : '#${formatCount(_worldRank!)}',
              style: AppTextStyles.display(36, color: _isGuest ? AppColors.textDim : accent).copyWith(letterSpacing: -0.5)),
        ),
        const Spacer(),
        const SizedBox(height: 6),
        Text(
          _isGuest
              ? lm.translate('result_guest_rank_note')
              : [
                  if (_countryRank != null) '${lm.translate('rank_country')} #${formatCount(_countryRank!)}',
                ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w800),
        ),
      ],
    );
  }

  /// TOP 100 까지 남은 시간
  Widget _top100(LanguageManager lm, Color accent) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lm.translate('until_top').replaceAll('{n}', '100').replaceAll('{s}', formatSurvival(_untilTop100!)),
              style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: (_time / (_time + _untilTop100!)).clamp(0.0, 1.0),
              backgroundColor: AppColors.surface2,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        ],
      );

  void _showReviveConfirmDialog() {
    final t = LanguageManager.of(context, listen: false);
    showNeonDialog(
      context: context,
      title: t.translate('revive_title'),
      message: t.translate('revive_message'),
      actions: [
        NeonButton(
          text: t.translate('cancel'),
          onPressed: () => Navigator.of(context).pop(),
          isPrimary: false,
          isCompact: true,
        ),
        NeonButton(
          text: t.translate('watch_ad_button'),
          onPressed: () {
            Navigator.of(context).pop();
            widget.onRevive!(_savedRecordId);
          },
          icon: Icons.videocam_rounded,
          color: widget.world.accent,
          isCompact: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final accent = widget.world.accent;
    final delta = _time - widget.previousBest;
    final isBest = widget.previousBest <= 0 || delta > 0;
    final level = (widget.result['level'] as num?)?.toInt() ?? 0;
    final graze = (widget.result['graze'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FillScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(lm.translate('game_over'), style: AppTextStyles.label().copyWith(letterSpacing: 2)),
                  const Spacer(),
                  AppChip(
                    label: lm.translate(widget.world.nameKey).toUpperCase(),
                    icon: Icons.circle,
                    color: accent,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // 생존 시간과 세계 순위를 같은 무게로
              _hero(lm, accent, isBest, delta),
              const SizedBox(height: 10),
              Row(
                children: [
                  _stat(
                    lm.translate(widget.world.statKey),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('$graze', style: AppTextStyles.display(22)),
                        if (_coinsBonus > 0) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(lm.translate('coin_bonus').replaceAll('{n}', formatCount(_coinsBonus)),
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.text(11, color: AppColors.coin, weight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _stat(lm.translate('level'), Text('$level', style: AppTextStyles.display(22))),
                ],
              ),
              if (_isGuest) ...[
                const SizedBox(height: 10),
                _rankCard(lm, accent),
              ] else if (!_rankLoading && _untilTop100 != null && _untilTop100! > 0) ...[
                const SizedBox(height: 12),
                _top100(lm, accent),
              ],
              _newBadges(lm),
              const SizedBox(height: 10),
              _coinRow(lm), // 게스트는 +0 · 잔액 0
              const Spacer(),
              NeonButton(
                text: lm.translate('retry'),
                color: accent,
                onPressed: widget.onRestart,
                fontSize: 18,
              ),
              if (widget.onRevive != null) ...[
                const SizedBox(height: 10),
                NeonButton(
                  text: '${lm.translate('revive_watch_ad')} (${widget.revivesLeft})',
                  icon: Icons.replay_rounded,
                  isPrimary: false,
                  isCompact: true,
                  onPressed: _showReviveConfirmDialog,
                ),
              ],
              SizedBox(
                height: 44,
                child: TextButton(
                  onPressed: widget.onExit,
                  child: Text(lm.translate('home'), style: AppTextStyles.text(14, color: AppColors.textDim, weight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, Widget value) => Expanded(
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w700)),
              const Spacer(),
              value,
            ],
          ),
        ),
      );

  Widget _rankCard(LanguageManager lm, Color accent) {
    final borderColor = _isGuest ? AppColors.line : accent;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: _rankLoading
          ? SizedBox(
              height: 64,
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: accent))),
            )
          : _guestRank(lm, accent),
    );
  }

  /// 게스트 안내는 한 줄 — 이번 판이 몇 위였는지만 알려 주고 로그인으로 보낸다
  Widget _guestRank(LanguageManager lm, Color accent) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onNavigateToLogin,
      child: Row(
        children: [
          Expanded(
            child: OneLineText(
              _worldRank == null
                  ? lm.translate('guest_no_ranking_note')
                  : lm.translate('guest_lost_rank').replaceAll('{rank}', formatCount(_worldRank!)),
              style: AppTextStyles.text(13, weight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Text(lm.translate('login'), style: AppTextStyles.text(13, color: accent, weight: FontWeight.w800)),
          Icon(Icons.chevron_right_rounded, color: accent, size: 18),
        ],
      ),
    );
  }
}
