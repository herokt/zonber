import 'package:flutter/material.dart';

import '../audio_manager.dart';
import '../daily_rewards.dart';
import '../haptics.dart';
import '../design_system.dart';
import '../language_manager.dart';
import '../services/auth_service.dart';
import '../world_config.dart';

// ─────────────────────────────────────────────────────────────
// 홈의 "오늘의 미션" 카드와, 누르면 올라오는 출석 · 미션 창. 규칙은 daily_rewards.dart
// ─────────────────────────────────────────────────────────────

String missionText(LanguageManager lm, DailyMission m) {
  final stageName = m.stage > 0 ? lm.translate('stage_n').replaceAll('{n}', '${m.stage}') : '';
  return switch (m.kind) {
    MissionKind.runs => lm.translate('mis_runs'),
    MissionKind.totalTime => lm.translate('mis_total_time'),
    MissionKind.stageTime => lm.translate('mis_stage_time').replaceAll('{s}', stageName),
    MissionKind.stat => lm
        .translate('mis_stat')
        .replaceAll('{s}', stageName)
        .replaceAll('{stat}', lm.translate(WorldData.worlds[m.stage - 1].statKey)),
    MissionKind.allStages => lm.translate('mis_all_stages'),
  }
      .replaceAll('{n}', '${m.target}');
}

/// 홈 카드 — 미션 완료 수 · 출석 일차 · 받을 보상이 있으면 빨간 점
class DailyCard extends StatefulWidget {
  const DailyCard({super.key});

  @override
  State<DailyCard> createState() => _DailyCardState();
}

class _DailyCardState extends State<DailyCard> {
  List<MissionState> _ms = const [];
  int _attDay = 1;
  bool _attDone = false;

  @override
  void initState() {
    super.initState();
    _load();
    DailyRewards.claimable.addListener(_load);
  }

  @override
  void dispose() {
    DailyRewards.claimable.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final ms = await DailyRewards.missions();
    final a = await DailyRewards.attendance();
    if (!mounted) return;
    setState(() {
      _ms = ms;
      _attDay = a.day;
      _attDone = a.claimedToday;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final done = _ms.where((s) => s.done).length;
    final total = _ms.isEmpty ? 3 : _ms.length;
    final allDone = _ms.isNotEmpty && done == total;
    return ValueListenableBuilder<int>(
      valueListenable: DailyRewards.claimable,
      builder: (context, claimable, _) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          await showDailySheet(context);
          _load();
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.coin.withValues(alpha: claimable > 0 ? 0.28 : 0.16),
                AppColors.coin.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.coin.withValues(alpha: claimable > 0 ? 0.55 : 0.3)),
          ),
          child: Row(
            children: [
              // 진행 고리 — 오늘 미션을 몇 개 했는지 한눈에
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        value: total == 0 ? 0 : done / total,
                        strokeWidth: 4,
                        strokeCap: StrokeCap.round,
                        backgroundColor: AppColors.coin.withValues(alpha: 0.18),
                        valueColor: AlwaysStoppedAnimation(AppColors.coin),
                      ),
                    ),
                    allDone
                        ? Icon(Icons.check_rounded, size: 20, color: AppColors.coin)
                        : Text('$done/$total', style: AppTextStyles.display(13, color: AppColors.coin)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: OneLineText(lm.translate('daily_title'), style: AppTextStyles.text(15, weight: FontWeight.w900)),
                        ),
                        // 받을 게 있으면 빨간 점
                        if (claimable > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: Color(0xFFE5484D), shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    OneLineText(
                      _attDone
                          ? lm.translate('att_done_today')
                          : lm.translate('att_day').replaceAll('{n}', '$_attDay'),
                      style: AppTextStyles.text(12,
                          color: _attDone ? AppColors.textDim : AppColors.coin, weight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.coin.withValues(alpha: 0.8), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showDailySheet(BuildContext context) => showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _DailySheet(),
    );

class _DailySheet extends StatefulWidget {
  const _DailySheet();

  @override
  State<_DailySheet> createState() => _DailySheetState();
}

class _DailySheetState extends State<_DailySheet> {
  List<MissionState> _ms = const [];
  bool _bonusClaimed = false;
  ({int day, bool claimedToday, int streak}) _att = (day: 1, claimedToday: false, streak: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ms = await DailyRewards.missions();
    final b = await DailyRewards.bonusClaimed();
    final a = await DailyRewards.attendance();
    if (!mounted) return;
    setState(() {
      _ms = ms;
      _bonusClaimed = b;
      _att = a;
    });
  }

  void _got(LanguageManager lm, int coins) {
    if (coins <= 0) {
      // 게스트는 보상을 받지 않는다(아무것도 저장하지 않음) — 로그인 안내
      if (AuthService.isGuest) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(lm.translate('guest_login_to_save')), duration: const Duration(seconds: 2)));
      }
      return;
    }
    AudioManager().playSfx(Sfx.coin, volume: 0.7);
    Haptics.medium();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(lm.translate('reward_got').replaceAll('{n}', '$coins')), duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final allClaimed = _ms.isNotEmpty && _ms.every((s) => s.claimed);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 14),
            // ── 출석 ──
            Row(
              children: [
                Text(lm.translate('att_title'), style: AppTextStyles.text(16, weight: FontWeight.w900)),
                const Spacer(),
                Text(lm.translate('att_hint'), style: AppTextStyles.text(11, color: AppColors.textDim)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (int d = 1; d <= 7; d++) ...[
                  if (d > 1) const SizedBox(width: 5),
                  Expanded(child: _attBox(lm, d)),
                ],
              ],
            ),
            const SizedBox(height: 10),
            _claimButton(
              lm,
              label: _att.claimedToday
                  ? lm.translate('att_done_today')
                  : lm.translate('att_claim').replaceAll('{n}', '${DailyRewards.attendanceRewards[_att.day - 1]}'),
              enabled: !_att.claimedToday,
              onTap: () async {
                _got(lm, await DailyRewards.claimAttendance());
                _load();
              },
            ),
            const SizedBox(height: 22),
            // ── 미션 ──
            Row(
              children: [
                Text(lm.translate('daily_title'), style: AppTextStyles.text(16, weight: FontWeight.w900)),
                const Spacer(),
                Text(lm.translate('daily_reset'), style: AppTextStyles.text(11, color: AppColors.textDim)),
              ],
            ),
            const SizedBox(height: 10),
            for (final s in _ms) ...[
              _missionRow(lm, s),
              const SizedBox(height: 8),
            ],
            // 모두 완료 보너스
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.coin.withValues(alpha: allClaimed && !_bonusClaimed ? 0.16 : 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.emoji_events_rounded, size: 20, color: AppColors.coin),
                  const SizedBox(width: 10),
                  Expanded(child: Text(lm.translate('daily_all_bonus'), style: AppTextStyles.text(13, weight: FontWeight.w800))),
                  _rewardPill(lm, DailyRewards.allClearBonus,
                      state: _bonusClaimed ? 2 : (allClaimed ? 1 : 0),
                      onTap: () async {
                        _got(lm, await DailyRewards.claimBonus());
                        _load();
                      }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 출석 칸 — 받은 날은 체크, 오늘 받을 칸은 강조
  Widget _attBox(LanguageManager lm, int d) {
    final got = _att.claimedToday ? d <= _att.day : d < _att.day;
    final today = d == _att.day && !_att.claimedToday;
    return AspectRatio(
      aspectRatio: 0.8,
      child: Container(
        decoration: BoxDecoration(
          color: got ? AppColors.coin.withValues(alpha: 0.18) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: today ? AppColors.coin : AppColors.line, width: today ? 2 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$d', style: AppTextStyles.text(10, color: AppColors.textDim, weight: FontWeight.w800)),
            const SizedBox(height: 2),
            got
                ? Icon(Icons.check_rounded, size: 16, color: AppColors.coin)
                : const CoinIcon(size: 14),
            const SizedBox(height: 2),
            Text('${DailyRewards.attendanceRewards[d - 1]}', style: AppTextStyles.display(10, color: got ? AppColors.coin : AppColors.textDim)),
          ],
        ),
      ),
    );
  }

  Widget _missionRow(LanguageManager lm, MissionState s) {
    final m = s.mission;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: s.claimable ? AppColors.coin : AppColors.line, width: s.claimable ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(missionText(lm, m),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.text(13, weight: FontWeight.w800, color: s.claimed ? AppColors.textDim : null)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: s.progress / m.target,
                          minHeight: 6,
                          backgroundColor: AppColors.surface2,
                          color: s.done ? AppColors.coin : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${s.progress}/${m.target}', style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _rewardPill(lm, m.reward, state: s.claimed ? 2 : (s.done ? 1 : 0), onTap: () async {
            _got(lm, await DailyRewards.claimMission(m.id));
            _load();
          }),
        ],
      ),
    );
  }

  /// state 0 = 진행 중(보상만 표시) · 1 = 받기 · 2 = 받음
  Widget _rewardPill(LanguageManager lm, int coins, {required int state, required VoidCallback onTap}) {
    final ready = state == 1;
    return GestureDetector(
      onTap: ready ? onTap : null,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: ready ? AppColors.coin : AppColors.surface2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state == 2)
              Icon(Icons.check_rounded, size: 15, color: AppColors.textDim)
            else
              const CoinIcon(size: 14),
            const SizedBox(width: 4),
            Text(
              state == 2 ? lm.translate('claimed') : (ready ? '${lm.translate('claim')} +$coins' : '+$coins'),
              style: AppTextStyles.text(12, color: ready ? Colors.white : AppColors.textDim, weight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _claimButton(LanguageManager lm, {required String label, required bool enabled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppColors.coin : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(label, style: AppTextStyles.text(14, color: enabled ? Colors.white : AppColors.textDim, weight: FontWeight.w900)),
      ),
    );
  }
}
