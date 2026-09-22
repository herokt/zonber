import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../design_system.dart';
import '../language_manager.dart';
import '../progress_store.dart';
import '../ranking_system.dart';
import '../user_profile.dart';
import '../world_config.dart';

/// 랭킹 탭 — 월드 탭 × 기간 × 세계/국가, 포디움, 내 행 고정. (docs/UI_DESIGN.md §4.5)
class RankingPage extends StatefulWidget {
  final String initialWorldId;
  final Map<String, RankCacheEntry> rankCache;
  final VoidCallback onLogin;

  const RankingPage({
    super.key,
    required this.initialWorldId,
    required this.rankCache,
    required this.onLogin,
  });

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  final RankingSystem _ranking = RankingSystem();
  late String _worldId;
  int _period = 2; // 0 주 1 월 2 올해
  bool _national = false;
  bool _loading = true;
  List<Map<String, dynamic>> _records = const [];
  Map<String, dynamic>? _mine;
  int _myIndex = -1;
  String _myFlag = '';
  String _myUid = '';
  int _loadSeq = 0;

  static const _periods = [
    RankingPeriod.weekly,
    RankingPeriod.monthly,
    RankingPeriod.allTime,
  ];

  @override
  void initState() {
    super.initState();
    _worldId = widget.initialWorldId;
    _load();
  }

  bool get _isGuest => FirebaseAuth.instance.currentUser?.isAnonymous ?? true;

  Future<void> _load() async {
    final seq = ++_loadSeq;
    setState(() => _loading = true);
    final world = WorldData.getWorld(_worldId);
    final mapId = world.rankingMapId;
    final profile = await UserProfileManager.getProfile();
    _myFlag = profile['flag'] ?? '';
    _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final period = _periods[_period];

    List<Map<String, dynamic>> records;
    if (_national && _myFlag.isNotEmpty) {
      records = await _ranking.getNationalRankings(mapId, _myFlag, period: period);
    } else {
      records = await _ranking.getTopRecords(mapId, period: period);
    }
    Map<String, dynamic>? mine;
    if (!_isGuest && _myUid.isNotEmpty) {
      mine = await _ranking.getMyRank(mapId, _myUid, period: period);
    }
    if (!mounted || seq != _loadSeq) return;
    int myIndex = -1;
    if (mine != null) {
      myIndex = records.indexWhere((r) => r['id'] == mine!['id']);
      if (myIndex < 0) {
        // 다른 판의 기록이 리스트에 있을 수도 있다 — userId 로 최상단 것을 찾는다
        myIndex = records.indexWhere((r) => r['userId'] == _myUid);
      }
    }
    setState(() {
      _records = records;
      _mine = mine;
      _myIndex = myIndex;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final world = WorldData.getWorld(_worldId);
    final accent = world.accent;
    final cache = widget.rankCache[world.id];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(lm.translate('ranking'), style: AppTextStyles.display(22)),
                  const Spacer(),
                  if (cache != null)
                    Text(
                      lm.translate('records_count').replaceAll('{n}', formatCount(cache.total)),
                      style: AppTextStyles.text(12, color: AppColors.textDim, weight: FontWeight.w700),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: StageFilter(
                selectedId: _worldId,
                onChanged: (id) {
                  setState(() => _worldId = id);
                  _load();
                },
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: AppSegmented(
                      items: [
                        lm.translate('period_week'),
                        lm.translate('period_month'),
                        lm.translate('period_year'),
                      ],
                      index: _period,
                      onChanged: (i) {
                        setState(() => _period = i);
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 116,
                    child: AppSegmented(
                      items: [lm.translate('rank_world'), flagToIso(_myFlag).isNotEmpty ? flagToIso(_myFlag) : lm.translate('rank_country')],
                      index: _national ? 1 : 0,
                      onChanged: (i) {
                        if (_myFlag.isEmpty && i == 1) {
                          widget.onLogin();
                          return;
                        }
                        setState(() => _national = i == 1);
                        _load();
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: accent))
                  : _records.isEmpty
                      ? _empty(lm)
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                          children: [
                            _Podium(records: _records.take(3).toList(), accent: accent, myIndex: _myIndex),
                            if (_records.length > 3) ...[
                              const SizedBox(height: 14),
                              // 4위 이하 — 한 장의 카드 안에 줄로
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.line),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  children: [
                                    for (int i = 3; i < _records.length; i++)
                                      RankRow(
                                        rank: i + 1,
                                        nickname: (_records[i]['nickname'] as String?) ?? lm.translate('unknown'),
                                        flag: (_records[i]['flag'] as String?) ?? '',
                                        characterId: (_records[i]['characterId'] as String?) ?? 'neon_green',
                                        gear: _gearOf(_records[i]),
                                        skin: _records[i]['skin'] as String?,
                                        survivalTime: ((_records[i]['survivalTime'] as num?) ?? 0).toDouble(),
                                        highlighted: i == _myIndex,
                                        accent: accent,
                                        plate: plateOfRecord(_records[i]),
                                        last: i == _records.length - 1,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
            ),
            _myBar(lm, accent),
          ],
        ),
      ),
    );
  }

  Widget _empty(LanguageManager lm) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_outlined, color: AppColors.textDim, size: 40),
              const SizedBox(height: 12),
              Text(lm.translate('no_ranking_yet'),
                  style: AppTextStyles.text(14, color: AppColors.textDim), textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  /// 하단 고정 — 내 기록(리스트 밖이면 TOP 30까지 남은 시간), 게스트면 로그인 유도
  Widget _myBar(LanguageManager lm, Color accent) {
    if (_isGuest) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: GestureDetector(
          onTap: widget.onLogin,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OneLineText(lm.translate('guest_no_ranking_note'),
                      style: AppTextStyles.text(12, color: AppColors.textDim)),
                ),
                Text(lm.translate('login'), style: AppTextStyles.text(13, weight: FontWeight.w800)),
                Icon(Icons.chevron_right_rounded, color: AppColors.textDim, size: 18),
              ],
            ),
          ),
        ),
      );
    }
    if (_loading || _mine == null) return const SizedBox(height: 12);
    final myTime = ((_mine!['survivalTime'] as num?) ?? 0).toDouble();
    String sub;
    if (_myIndex >= 0) {
      sub = '#${_myIndex + 1}';
    } else if (_records.isNotEmpty) {
      final last = ((_records.last['survivalTime'] as num?) ?? 0).toDouble();
      final diff = (last - myTime).clamp(0, double.infinity);
      sub = lm.translate('until_top').replaceAll('{n}', '${_records.length}').replaceAll('{s}', formatSurvival(diff.toDouble()));
    } else {
      sub = lm.translate('outside_top30');
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent),
        ),
        child: Row(
          children: [
            Text(_myIndex >= 0 ? '#${_myIndex + 1}' : lm.translate('my_record'), style: AppTextStyles.display(14)),
            const SizedBox(width: 10),
            CharacterAvatar(characterId: (_mine!['characterId'] as String?) ?? 'neon_green', gear: _gearOf(_mine!), skin: _mine!['skin'] as String?, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text((_mine!['nickname'] as String?) ?? '',
                        style: AppTextStyles.text(14, weight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (plateOfRecord(_mine!) != null) ...[
                    const SizedBox(width: 6),
                    PlateBadge(tier: plateOfRecord(_mine!)!, size: 18),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatSurvival(myTime), style: AppTextStyles.display(15)),
                if (_myIndex < 0) Text(sub, style: AppTextStyles.text(10, color: AppColors.textDim, weight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 기록에 붙은 명패 등급(ranking_system 이 users.plates 에서 붙인 값). 없으면 null
PlateTier? plateOfRecord(Map<String, dynamic> r) {
  final rank = (r['plateRank'] as num?)?.toInt();
  if (rank == null) return null;
  return plateTierOf((r['plateScope'] as String?) ?? 'world', rank);
}

/// 1~3위 포디움 — 메달 색 받침대 위에 캐릭터·이름·국기·기록
class _Podium extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final Color accent;
  final int myIndex;
  const _Podium({required this.records, required this.accent, required this.myIndex});

  @override
  Widget build(BuildContext context) {
    Widget slot(int i, double height, Color medal) {
      if (i >= records.length) return const Expanded(child: SizedBox());
      final r = records[i];
      final first = i == 0;
      final plate = plateOfRecord(r);
      final flag = (r['flag'] as String?) ?? '';
      final avatar = first ? 64.0 : 52.0;
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (first) Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 26),
            if (first) const SizedBox(height: 2),
            // 캐릭터 + 아래쪽 순위 메달
            SizedBox(
              width: avatar + 8,
              height: avatar + 12,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [medal.withValues(alpha: 0.5), medal, medal.withValues(alpha: 0.7)],
                      ),
                    ),
                    child: CharacterAvatar(
                      characterId: (r['characterId'] as String?) ?? 'neon_green',
                      gear: _gearOf(r),
                      skin: r['skin'] as String?,
                      size: avatar,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: medal,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text('${i + 1}', style: AppTextStyles.display(11, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text((r['nickname'] as String?) ?? '',
                      style: AppTextStyles.text(first ? 13 : 12, weight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (plate != null) ...[
                  const SizedBox(width: 4),
                  PlateBadge(tier: plate, size: 15),
                ],
              ],
            ),
            if (flag.isNotEmpty) ...[
              const SizedBox(height: 4),
              CountryChip(flag: flag, height: 11),
            ],
            const SizedBox(height: 8),
            // 받침대 — 메달 색 금속, 기록은 받침대 위에 새긴다
            Container(
              height: height,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [medal.withValues(alpha: 0.30), medal.withValues(alpha: 0.06)],
                ),
                border: Border(top: BorderSide(color: medal, width: 2)),
              ),
              alignment: Alignment.center,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: formatSurvival(((r['survivalTime'] as num?) ?? 0).toDouble()),
                    style: AppTextStyles.display(first ? 15 : 13, color: i == myIndex ? accent : AppColors.text),
                  ),
                  TextSpan(text: 's', style: AppTextStyles.text(10, color: AppColors.textDim, weight: FontWeight.w700)),
                ]),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          slot(1, 58, AppColors.silver),
          const SizedBox(width: 8),
          slot(0, 78, AppColors.gold),
          const SizedBox(width: 8),
          slot(2, 44, AppColors.bronze),
        ],
      ),
    );
  }
}

/// 기록 주인이 지금 이 존에서 입은 장비(ranking_system 이 유저 문서에서 채운다)
List<String> _gearOf(Map<String, dynamic> r) => (r['gear'] as List?)?.whereType<String>().toList() ?? const [];
