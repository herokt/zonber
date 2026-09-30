import 'package:flutter/material.dart';

import '../avatar.dart';
import '../badges.dart';
import '../design_system.dart';
import '../friends.dart';
import '../language_manager.dart';
import '../player_profile.dart';
import '../services/auth_service.dart';
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
/// [challenge] 가 있으면 아래에 "이 기록 깨러 가기" 버튼 — 누르면 창을 닫고 [challenge].onTap
/// (그 기록을 목표로 판을 연다). 기록은 랭킹 줄에 보이던 값
Future<void> showPlayerCard(BuildContext context,
        {required String uid, String? zone, ({double time, VoidCallback onTap})? challenge}) =>
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => PlayerCardSheet(uid: uid, zone: zone, challenge: challenge),
    );

class PlayerCardSheet extends StatefulWidget {
  final String uid;
  final String? zone;
  final ({double time, VoidCallback onTap})? challenge;
  const PlayerCardSheet({super.key, required this.uid, this.zone, this.challenge});

  @override
  State<PlayerCardSheet> createState() => _PlayerCardSheetState();
}

class _PlayerCardSheetState extends State<PlayerCardSheet> {
  PlayerProfile? _profile;
  bool _loading = true;

  /// 나와 이 사람 사이(친구 버튼) — 게스트·못 읽음이면 null(버튼 없음)
  FriendState? _friend;
  bool _friendBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait<Object?>([PlayerProfileService.fetch(widget.uid), Friends.stateOf(widget.uid)]);
    if (!mounted) return;
    setState(() {
      _profile = results[0] as PlayerProfile?;
      final st = results[1] as FriendState;
      _friend = st == FriendState.self || AuthService.isGuest ? null : st;
      _loading = false;
    });
  }

  Future<void> _friendAction(Future<FriendResult> Function() f) async {
    if (_friendBusy) return;
    final lm = LanguageManager.of(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _friendBusy = true);
    final r = await f();
    final st = await Friends.stateOf(widget.uid);
    if (!mounted) return;
    setState(() {
      _friendBusy = false;
      _friend = st == FriendState.self ? null : st;
    });
    messenger.showSnackBar(SnackBar(content: Text(lm.translate(friendResultKey(r))), duration: const Duration(seconds: 2)));
  }

  Future<void> _confirmRemove() async {
    final lm = LanguageManager.of(context, listen: false);
    final name = _profile?.nickname ?? '';
    final ok = await showNeonDialog<bool>(
      context: context,
      title: lm.translate('friend_remove'),
      message: lm.translate('friend_remove_confirm').replaceAll('{name}', name),
      actions: [
        NeonButton(text: lm.translate('cancel'), isPrimary: false, isCompact: true, onPressed: () => Navigator.of(context).pop(false)),
        NeonButton(text: lm.translate('friend_remove'), isCompact: true, color: AppColors.secondary, onPressed: () => Navigator.of(context).pop(true)),
      ],
    );
    if (ok == true) await _friendAction(() => Friends.remove(widget.uid));
  }

  /// 친구 버튼 한 줄 — 요청 / 요청 보냄 / 수락 / 친구(삭제)
  Widget _friendRow(LanguageManager lm) {
    final st = _friend;
    if (st == null) return const SizedBox.shrink();
    return switch (st) {
      FriendState.friend => Row(children: [
          Icon(Icons.people_alt_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(lm.translate('friend_is_friend'), style: AppTextStyles.text(13, color: AppColors.primary, weight: FontWeight.w800)),
          const Spacer(),
          TextButton(
            onPressed: _friendBusy ? null : _confirmRemove,
            child: Text(lm.translate('friend_remove'), style: AppTextStyles.text(12.5, color: AppColors.textDim, weight: FontWeight.w700)),
          ),
        ]),
      FriendState.requested => NeonButton(text: lm.translate('friend_requested_btn'), icon: Icons.schedule_rounded, isPrimary: false, onPressed: null),
      FriendState.incoming => NeonButton(
          text: lm.translate('friend_accept_btn'),
          icon: Icons.person_add_alt_1_rounded,
          onPressed: _friendBusy ? null : () => _friendAction(() => Friends.answer(widget.uid, accept: true)),
        ),
      _ => NeonButton(
          text: lm.translate('friend_request_btn'),
          icon: Icons.person_add_alt_1_rounded,
          isPrimary: false,
          onPressed: _friendBusy ? null : () => _friendAction(() => Friends.request(widget.uid)),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final p = _profile;
    return SafeArea(
      child: SingleChildScrollView( // 도전 버튼까지 작은 화면에 다 안 들어가면 밀어 올린다
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
              if (_friend != null) ...[const SizedBox(height: 12), _friendRow(lm)],
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
            // 프로필을 못 읽어도(탈퇴 등) 랭킹 기록에는 도전할 수 있다
            if (!_loading && widget.challenge != null) ...[
              const SizedBox(height: 18),
              NeonButton(
                text: '${lm.translate('rival_challenge')} · ${formatSurvival(widget.challenge!.time)}s',
                icon: Icons.sports_score_rounded,
                color: widget.zone == null ? null : WorldData.getWorld(widget.zone!).accent,
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.challenge!.onTap();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
