import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../achievement_manager.dart';
import '../design_system.dart';
import '../coin_store.dart';
import '../ad_manager.dart';
import '../language_manager.dart';
import '../progress_store.dart';
import '../ranking_system.dart';
import '../services/analytics_service.dart';
import '../user_profile.dart';
import '../world_config.dart';

/// 결과 화면 A — 생존 시간·델타·순위 카드. 조건 충족 시 B(Hall of Fame)로 넘긴다.
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
  final void Function(PlateData plate) onHallOfFame;
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
    required this.onHallOfFame,
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
  int? _worldTotal;
  int? _countryRank;
  int? _countryTotal;
  double? _untilTop100;
  bool _hofScheduled = false;
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
  bool get _isGuest => FirebaseAuth.instance.currentUser?.isAnonymous ?? true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
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
        _unlockSurvivalAchievements();
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
    int? natTotal;
    if (flag.isNotEmpty) {
      final nat = await _ranking.getNationalRankings(mapId, flag, period: RankingPeriod.allTime, limit: 500);
      natTotal = nat.length;
      natRank = nat.where((r) => ((r['survivalTime'] as num?) ?? 0).toDouble() > _time).length + 1;
    }
    if (!mounted) return;
    setState(() {
      _worldRank = global?.rank;
      _worldTotal = global?.total;
      _countryRank = natRank;
      _countryTotal = natTotal;
      _untilTop100 = topTimes.length >= 100 ? (topTimes[99] - _time).clamp(0, double.infinity) : null;
      _rankLoading = false;
    });
    if (global != null) {
      ProgressStore.setRankCache(widget.world.id, global.rank, global.total);
    }

    // 3. Hall of Fame — 세계 TOP 100 또는 국가 TOP 10
    if (!_isGuest && global != null) {
      PlateData? plate;
      if (global.rank <= 100) {
        plate = PlateData(worldId: widget.world.id, rank: global.rank, total: global.total, survivalTime: _time, date: DateTime.now(), scope: 'world');
      } else if (natRank != null && natRank <= 10) {
        plate = PlateData(worldId: widget.world.id, rank: natRank, total: natTotal ?? 0, survivalTime: _time, date: DateTime.now(), scope: 'country');
      }
      if (plate != null) {
        final isNew = await ProgressStore.savePlate(plate);
        if (isNew && mounted) {
          _hofScheduled = true;
          final p = plate;
          Future.delayed(const Duration(milliseconds: 1100), () {
            if (mounted) widget.onHallOfFame(p);
          });
        }
      }
    }
  }

  Future<void> _unlockSurvivalAchievements() async {
    try {
      final keys = AchievementManager.survivalKeys(_time);
      final owned = (await AchievementManager.getMine()).toSet();
      final fresh = keys.where((k) => !owned.contains(k)).toList();
      await AchievementManager.unlock(keys);
      for (final k in fresh) {
        AnalyticsService().logAchievementUnlock(k);
      }
    } catch (e) {
      debugPrint('Achievement unlock failed: $e');
    }
  }

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
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(formatSurvival(_time), style: AppTextStyles.display(60).copyWith(letterSpacing: -1)),
                  const SizedBox(width: 4),
                  Text('s', style: AppTextStyles.display(20, color: AppColors.textDim, weight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: AppChip(
                  label: widget.previousBest <= 0
                      ? lm.translate('first_record')
                      : isBest
                          ? lm.translate('best_delta_up').replaceAll('{d}', formatSurvival(delta))
                          : lm.translate('best_delta_down').replaceAll('{d}', formatSurvival(-delta)),
                  icon: isBest ? Icons.arrow_upward_rounded : Icons.remove_rounded,
                  color: isBest ? AppColors.up : AppColors.textDim,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  _stat(lm.translate('level'), Text('$level', style: AppTextStyles.display(20))),
                  const SizedBox(width: 10),
                  _stat(lm.translate(widget.world.statKey), Text('$graze', style: AppTextStyles.display(20))),
                  const SizedBox(width: 10),
                  _stat(
                    lm.translate('character'),
                    FutureBuilder<Map<String, String>>(
                      future: UserProfileManager.getProfile(),
                      builder: (context, snap) => Row(
                        children: [
                          CharacterAvatar(characterId: snap.data?['characterId'] ?? 'neon_green', size: 22),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              lm.translate('char_${snap.data?['characterId'] ?? 'neon_green'}').split(' ').last,
                              style: AppTextStyles.text(13, weight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _rankCard(lm, accent),
              const SizedBox(height: 10),
              _coinRow(lm),
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
      padding: const EdgeInsets.all(18),
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
          : _isGuest
              ? _guestRank(lm, accent)
              : _memberRank(lm, accent),
    );
  }

  Widget _memberRank(LanguageManager lm, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events_rounded, size: 18, color: accent),
            const SizedBox(width: 8),
            Text(lm.translate('result_rank_title'), style: AppTextStyles.label()),
            if (_hofScheduled) ...[
              const Spacer(),
              Text(lm.translate('hof_title'), style: AppTextStyles.label(color: AppColors.gold)),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _rankCell(lm.translate('rank_world'), _worldRank, _worldTotal, lm)),
            Container(width: 1, height: 36, color: AppColors.line),
            const SizedBox(width: 12),
            Expanded(child: _rankCell(lm.translate('rank_country'), _countryRank, _countryTotal, lm)),
          ],
        ),
        if (_untilTop100 != null && _untilTop100! > 0) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Text(lm.translate('until_top').replaceAll('{n}', '100').replaceAll('{s}', formatSurvival(_untilTop100!)),
                  style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w700)),
            ],
          ),
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
      ],
    );
  }

  Widget _rankCell(String label, int? rank, int? total, LanguageManager lm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w700)),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(rank == null ? '—' : '#${formatCount(rank)}', style: AppTextStyles.display(24)),
            if (total != null) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  lm.translate('of_records').replaceAll('{n}', formatCount(total)),
                  style: AppTextStyles.text(11, color: AppColors.textDim),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _guestRank(LanguageManager lm, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _worldRank == null
              ? lm.translate('guest_no_ranking_note')
              : lm.translate('guest_lost_rank').replaceAll('{rank}', formatCount(_worldRank!)),
          style: AppTextStyles.text(14, weight: FontWeight.w700, height: 1.4),
        ),
        const SizedBox(height: 4),
        Text(lm.translate('guest_login_to_engrave'), style: AppTextStyles.text(12, color: AppColors.textDim, height: 1.4)),
        const SizedBox(height: 12),
        NeonButton(
          text: lm.translate('login'),
          icon: Icons.login_rounded,
          color: accent,
          isCompact: true,
          onPressed: widget.onNavigateToLogin,
        ),
      ],
    );
  }
}
