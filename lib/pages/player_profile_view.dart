import 'package:flutter/material.dart';

import '../avatar.dart';
import '../badges.dart';
import '../design_system.dart';
import '../language_manager.dart';
import '../player_profile.dart';
import '../world_config.dart';

// ─────────────────────────────────────────────────────────────
// 프로필 보여 주기 — 내 프로필(ProfilePage)과 남의 프로필(랭킹에서 이름 누르기)이
// 같은 부품을 쓴다. 데이터는 전부 PlayerProfile(player_profile.dart) 하나에서 온다.
//   · [ProfileIdentityCard] 아바타 · 닉네임 · 국기 · 대표 뱃지 (+ 오른쪽 버튼 · 아래 통계)
//   · [StageRecordRow]      ZONE 한 줄 — 최고 기록 (+ 아는 경우 세계 순위)
//   · [ProfileBadgeStrip]   보유 뱃지 줄
//   · [showPlayerCard]      남의 프로필을 아래에서 올라오는 창으로
// ─────────────────────────────────────────────────────────────

/// yyyy.MM.dd — 가입일·최근 접속에 쓴다
String formatDay(DateTime? d) =>
    d == null ? '—' : '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

/// 신분 카드 — 아바타 · 이름 · 국기 · 대표 뱃지
class ProfileIdentityCard extends StatelessWidget {
  final PlayerProfile profile;

  /// 이 존 장비를 입은 아바타로 보여 준다(null 이면 맨몸)
  final String? zone;
  final double avatarSize;

  /// 오른쪽 끝 버튼(내 프로필의 '편집' 같은 것)
  final Widget? trailing;

  /// 카드 아래 작은 통계 칸
  final List<Widget> stats;

  const ProfileIdentityCard({
    super.key,
    required this.profile,
    this.zone,
    this.avatarSize = 60,
    this.trailing,
    this.stats = const [],
  });

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final top = profile.topBadge;
    return NeonCard(
      padding: EdgeInsets.fromLTRB(16, 16, trailing == null ? 16 : 8, 14),
      child: Column(
        children: [
          Row(
            children: [
              AvatarView(
                avatar: profile.avatar,
                zone: zone,
                size: avatarSize,
                borderColor: top != null && top.tier >= 3 ? top.color : profile.avatar.color,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(profile.nickname,
                              style: AppTextStyles.display(22), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (profile.flag.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          CountryChip(flag: profile.flag),
                        ],
                      ],
                    ),
                    if (top != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          BadgeIcon(badge: top, size: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              lm.translate(top.nameKey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.text(12, color: top.color, weight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(children: stats),
          ],
        ],
      ),
    );
  }
}

/// 작은 통계 한 칸 — 신분 카드 아래 줄
class ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  const ProfileStat({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value, style: AppTextStyles.display(18)),
            const SizedBox(height: 3),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.text(10.5, color: AppColors.textDim, weight: FontWeight.w700)),
          ],
        ),
      );
}

/// 가입일 · 최근 접속
class ProfileMetaLine extends StatelessWidget {
  final PlayerProfile profile;
  const ProfileMetaLine({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    Widget cell(String label, DateTime? d) => Expanded(
          child: Row(
            children: [
              Text('$label ', style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w700)),
              Text(formatDay(d), style: AppTextStyles.display(12, color: AppColors.textDim)),
            ],
          ),
        );
    return Row(children: [
      cell(lm.translate('joined'), profile.joinedAt),
      cell(lm.translate('last_seen'), profile.lastSeenAt),
    ]);
  }
}

/// ZONE 기록 한 줄 — 최고 기록 · (아는 경우) 세계 순위
class StageRecordRow extends StatelessWidget {
  final WorldConfig world;
  final double? best;

  /// 세계 순위 — 남의 프로필에서는 모르므로 칸을 그리지 않는다
  final int? worldRank;
  final bool showRank;

  /// 기록 칸 이름 — 내 것이면 '내 최고 기록', 남의 것이면 '최고 기록'
  final String bestLabel;

  const StageRecordRow({
    super.key,
    required this.world,
    required this.best,
    required this.bestLabel,
    this.worldRank,
    this.showRank = true,
  });

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    // 테두리는 한 색(둥근 모서리), 스테이지 색은 안쪽 왼쪽 막대로
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: world.accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 86,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lm.translate('stage_n').replaceAll('{n}', '${world.difficulty}'),
                            style: AppTextStyles.text(10.5, color: world.accent, weight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lm.translate(world.nameKey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.text(13, weight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _cell(bestLabel, best == null ? '—' : formatSurvival(best!), best == null ? null : 's'),
                    ),
                    if (showRank) ...[
                      Container(width: 1, height: 34, color: AppColors.line),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _cell(lm.translate('rank_world'), worldRank == null ? '—' : '#${formatCount(worldRank!)}', null),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String label, String value, String? suffix) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.text(10.5, color: AppColors.textDim, weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppTextStyles.display(20)),
              if (suffix != null) ...[
                const SizedBox(width: 3),
                Flexible(child: Text(suffix, style: AppTextStyles.text(11, color: AppColors.textDim, weight: FontWeight.w700))),
              ],
            ],
          ),
        ],
      );
}

/// 보유 뱃지 줄 — 등급이 높은 것부터, 넘치면 +n
class ProfileBadgeStrip extends StatelessWidget {
  final PlayerProfile profile;
  final int max;
  const ProfileBadgeStrip({super.key, required this.profile, this.max = 8});

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final badges = [...profile.badges]..sort((a, b) => b.tier.compareTo(a.tier));
    if (badges.isEmpty) {
      return Text(lm.translate('badges_empty'), style: AppTextStyles.text(12, color: AppColors.textDim));
    }
    final shown = badges.take(max).toList();
    return Row(
      children: [
        for (final b in shown) Padding(padding: const EdgeInsets.only(right: 6), child: BadgeIcon(badge: b, size: 28)),
        if (badges.length > shown.length)
          Text('+${badges.length - shown.length}', style: AppTextStyles.display(13, color: AppColors.textDim)),
      ],
    );
  }
}

/// 남의 프로필 — 랭킹에서 이름을 누르면 아래에서 올라온다
Future<void> showPlayerCard(BuildContext context, {required String uid, String? zone}) => showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => PlayerCardSheet(uid: uid, zone: zone),
    );

class PlayerCardSheet extends StatefulWidget {
  final String uid;
  final String? zone;
  const PlayerCardSheet({super.key, required this.uid, this.zone});

  @override
  State<PlayerCardSheet> createState() => _PlayerCardSheetState();
}

class _PlayerCardSheetState extends State<PlayerCardSheet> {
  PlayerProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await PlayerProfileService.fetch(widget.uid);
    if (!mounted) return;
    setState(() {
      _profile = p;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final p = _profile;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3)),
              )
            else if (p == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(lm.translate('profile_not_found'), style: AppTextStyles.text(13, color: AppColors.textDim)),
                ),
              )
            else ...[
              ProfileIdentityCard(
                profile: p,
                zone: widget.zone,
                stats: [
                  ProfileStat(label: lm.translate('stats_games'), value: formatCount(p.totalGames)),
                  ProfileStat(label: lm.translate('badges'), value: '${p.badges.length}/${Badges.all.length}'),
                ],
              ),
              const SizedBox(height: 10),
              ProfileMetaLine(profile: p),
              const SizedBox(height: 18),
              SectionLabel(lm.translate('world_records')),
              const SizedBox(height: 10),
              for (final w in WorldData.worlds) ...[
                StageRecordRow(world: w, best: p.bestOf(w.id), bestLabel: lm.translate('record_best'), showRank: false),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 10),
              SectionLabel(lm.translate('badges')),
              const SizedBox(height: 10),
              ProfileBadgeStrip(profile: p),
            ],
          ],
        ),
      ),
    );
  }
}
