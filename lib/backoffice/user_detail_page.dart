import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

import '../gear.dart';
import 'bo_charts.dart';
import 'bo_common.dart';
import 'runs_page.dart' show kNoRunsHint;
import 'runs_table.dart';

// ─────────────────────────────────────────────────────────────
// 유저 상세(셸 안 페이지) — 헤더 카드(아바타·닉네임·로그인·UID·핵심 수치·관리 버튼) + 탭:
//   개요(프로필·경제·착용·보유 아이템·뱃지 누적 기록·일일 미션) / 뱃지·기록(뱃지 격자·최고 기록·랭킹 기록) /
//   플레이 기록(runs) / 관리.
// 수정·삭제는 BoData.refreshAll() 로 열린 화면을 모두 다시 읽게 한다.
// ─────────────────────────────────────────────────────────────
class UserDetailPage extends StatefulWidget {
  final String uid;
  const UserDetailPage({super.key, required this.uid});

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> with BoReloadable {
  Map<String, dynamic>? _data;
  bool _loaded = false;
  final int _initialTab = BoNav.takeUserTab();
  String _privateEmail = '';
  bool _loading = true;
  Object? _error;

  @override
  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object?>([
        BoData.src.user(widget.uid),
        BoData.src.privateEmail(widget.uid),
      ]);
      if (mounted) {
        setState(() {
          _data = results[0] as Map<String, dynamic>?;
          _privateEmail = (results[1] as String? ?? '').trim();
          _loaded = true;
        });
      }
      BoData.markLoaded();
    } catch (e) {
      debugPrint('UserDetail: $e');
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _exists => _data != null;
  Map<String, dynamic> get _d => _data ?? const {};

  Future<void> _edit() async {
    if (!_exists) return;
    final ok = await showDialog<bool>(context: context, builder: (_) => EditUserDialog(uid: widget.uid, data: _d));
    if (ok == true) {
      BoData.refreshAll();
      if (mounted) toast(context, '저장했습니다');
    }
  }

  Future<void> _grant() async {
    if (!_exists) return;
    final owned = ((_d['ownedItems'] as List?) ?? const []).map((e) => '$e').toSet();
    final id = await showDialog<String>(context: context, builder: (_) => GrantItemDialog(owned: owned));
    if (id == null || id.isEmpty) return;
    if (!mounted) return;
    if (!await confirmCode(context, '아이템 지급 확인',
        '${nickOf(_d)} (${widget.uid})\n\n${itemName(id)} ($id) 을(를) 지급합니다.',
        ok: '지급', okColor: Bo.purple)) {
      return;
    }
    try {
      await BoData.src.grantItem(widget.uid, id);
      BoData.refreshAll();
      if (mounted) toast(context, '${itemName(id)} 지급 완료');
    } catch (e) {
      if (mounted) toast(context, '지급 실패: $e', error: true);
    }
  }

  /// 코인 지급 — 음수를 넣으면 회수한다(coins 증감)
  Future<void> _grantCoins() async {
    if (!_exists) return;
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => GrantCoinsDialog(current: intOf(_d['coins'])),
    );
    if (amount == null || amount == 0) return;
    if (!mounted) return;
    if (!await confirmCode(
      context,
      amount > 0 ? '코인 지급 확인' : '코인 회수 확인',
      '${nickOf(_d)} (${widget.uid})\n\n지금 ${fmtNum(intOf(_d['coins']))} → ${fmtNum((intOf(_d['coins']) + amount).clamp(0, 10000000))}',
      ok: amount > 0 ? '지급' : '회수',
      okColor: Bo.amber,
    )) {
      return;
    }
    try {
      await BoData.src.grantCoins(widget.uid, amount);
      BoData.refreshAll();
      if (mounted) toast(context, amount > 0 ? '코인 ${fmtNum(amount)} 지급 완료' : '코인 ${fmtNum(-amount)} 회수 완료');
    } catch (e) {
      if (mounted) toast(context, '코인 지급 실패: $e', error: true);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmCode(
      context,
      '계정 삭제 확인',
      '${nickOf(_d)} (${widget.uid})\n\n정말로 이 사용자 문서를 삭제하시겠습니까? 되돌릴 수 없습니다.\n'
          '(플레이 기록·비공개 문서 등 하위 컬렉션과 랭킹 기록은 남습니다)',
      ok: '삭제',
    );
    if (!ok) return;
    try {
      await BoData.src.deleteUser(widget.uid);
      if (mounted) toast(context, '삭제했습니다');
      BoNav.closeUser();
      BoData.refreshAll();
    } catch (e) {
      if (mounted) toast(context, '삭제 실패: $e', error: true);
    }
  }

  String get _sectionName => switch (BoNav.section.value) {
        BoSection.dashboard => '대시보드',
        BoSection.users => '유저',
        BoSection.ranking => '랭킹 관리',
        BoSection.runs => '플레이 기록',
        BoSection.promos => '이벤트',
        BoSection.codes => '이벤트 코드',
        BoSection.economy => '경제·아이템',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Bo.bg,
      child: BoPage(
        topBar: BoTopBar(
          title: _exists ? nickOf(_d) : '유저 상세',
          breadcrumb: [_sectionName, '유저 상세'],
          onBack: BoNav.closeUser,
        ),
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading && !_loaded) return const BoLoading();
    if (_error != null) return Padding(padding: const EdgeInsets.all(24), child: BoError(error: _error!, onRetry: reload));
    return DefaultTabController(
      length: 4,
      initialIndex: _initialTab,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(24, 20, 24, 0), child: _header()),
          Container(
            margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Bo.line))),
            child: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerHeight: 0,
              labelPadding: EdgeInsets.symmetric(horizontal: 14),
              tabs: [Tab(text: '개요', height: 42), Tab(text: '뱃지·기록', height: 42), Tab(text: '플레이 기록', height: 42), Tab(text: '관리', height: 42)],
            ),
          ),
          Expanded(
            child: TabBarView(children: [
              _exists
                  ? _overview()
                  : BoEmpty('유저 문서가 없습니다 (${widget.uid}) — 삭제된 계정일 수 있습니다',
                      icon: Icons.person_off_outlined),
              _BadgesRecordsTab(uid: widget.uid, data: _d),
              _RunsTab(uid: widget.uid),
              _exists ? _manage() : const BoEmpty('유저 문서가 없어 관리할 수 없습니다', icon: Icons.person_off_outlined),
            ]),
          ),
        ],
      ),
    );
  }

  // ── 헤더 카드 ──
  Widget _header() {
    final d = _d;
    final provider = (d['loginProvider'] as String? ?? '').trim();
    final email = _privateEmail.isNotEmpty ? _privateEmail : (d['email'] as String? ?? '').trim();
    final best = bestBadgeOf(d);
    final flag = flagOf(d);
    final country = (d['countryName'] as String? ?? '').trim();
    final narrow = MediaQuery.sizeOf(context).width < 1180;
    final actions = [
      OutlinedButton.icon(onPressed: _exists ? _edit : null, icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('정보 수정')),
      OutlinedButton.icon(onPressed: _exists ? _grant : null, icon: const Icon(Icons.card_giftcard_outlined, size: 16), label: const Text('아이템 지급')),
      OutlinedButton.icon(onPressed: _exists ? _grantCoins : null, icon: const Icon(Icons.paid_outlined, size: 16), label: const Text('코인 지급')),
      OutlinedButton.icon(
        onPressed: _exists ? _delete : null,
        style: OutlinedButton.styleFrom(foregroundColor: Bo.red, side: BorderSide(color: Bo.dangerBorder)),
        icon: const Icon(Icons.delete_outline_rounded, size: 16),
        label: const Text('삭제'),
      ),
    ];
    return BoCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BoAvatar.ofUser(_exists ? d : null, size: 60),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (flag.isNotEmpty) BoFlag(flag, height: 16),
                          Text(_exists ? nickOf(d) : '(문서 없음)', style: Bo.h1.copyWith(fontSize: 20)),
                          if (_exists) BoProviderBadge(provider),
                          if (d['adsRemoved'] == true) BoBadge('광고 제거', color: Bo.green, dense: true, icon: Icons.check_rounded),
                          if (best != null)
                            Tooltip(
                              message: '대표 뱃지 · ${tierName(best.tier)}',
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(3, 3, 9, 3),
                                decoration: BoxDecoration(
                                  color: best.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  BoBadgeIcon(best, size: 20, tooltip: false),
                                  const SizedBox(width: 5),
                                  Text(badgeName(best.key),
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Bo.ink(best.color, 0.35))),
                                ]),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 14,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(widget.uid, style: Bo.mono),
                            BoCopyButton(widget.uid),
                          ]),
                          if (email.isNotEmpty) _meta(Icons.mail_outline_rounded, email),
                          if (country.isNotEmpty) _meta(Icons.public_rounded, country),
                          if ((d['platform'] as String? ?? '').isNotEmpty) _meta(Icons.devices_other_rounded, d['platform'] as String),
                          _meta(Icons.face_retouching_natural_outlined, '캐릭터 ${charName(d['characterId'] as String?)}'),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!narrow) ...[const SizedBox(width: 12), Wrap(spacing: 8, children: actions)],
              ],
            ),
          ),
          if (narrow) Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 14), child: Wrap(spacing: 8, runSpacing: 8, children: actions)),
          const Divider(),
          _statStrip(d),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Bo.text3),
        const SizedBox(width: 4),
        Text(text, style: Bo.muted),
      ]);

  Widget _statStrip(Map<String, dynamic> d) {
    final owned = badgeCountOf(d);
    final stats = <(String, String, String?)>[
      ('보유 코인', fmtNum(intOf(d['coins'])), null),
      ('총 판 수', fmtNum(intOf(d['totalGamesPlayed'])), null),
      ('총 플레이 시간', fmtDuration(dblOf(d['totalPlayTime'])), null),
      ('뱃지', '$owned / ${Badges.all.length}', fmtPct(owned, Badges.all.length, digits: 0)),
      ('가입일', fmtDate(tsOf(d['createdAt'])), null),
      ('최근 활동', timeAgo(tsOf(d['lastUpdated'])), fmtDateTime(tsOf(d['lastUpdated']))),
    ];
    return Container(
      color: Bo.subtle,
      child: Row(
        children: [
          for (int i = 0; i < stats.length; i++)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(border: i == 0 ? null : Border(left: BorderSide(color: Bo.line))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(stats[i].$1, style: Bo.caption),
                  const SizedBox(height: 3),
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Flexible(
                      child: Text(stats[i].$2,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Bo.text, fontFeatures: Bo.tabular),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (stats[i].$3 != null) ...[
                      const SizedBox(width: 6),
                      Flexible(child: Text(stats[i].$3!, style: Bo.caption, overflow: TextOverflow.ellipsis)),
                    ],
                  ]),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  // ── 개요 ──
  Widget _overview() {
    final d = _d;
    final email = _privateEmail.isNotEmpty ? _privateEmail : (d['email'] as String? ?? '').trim();
    final profile = BoCard(
      title: '프로필',
      child: Column(children: [
        BoKv('닉네임', v: nickOf(d)),
        BoKv('국가',
            child: Row(children: [
              if (flagOf(d).isNotEmpty) ...[BoFlag(flagOf(d)), const SizedBox(width: 6)],
              Text('${d['countryName'] ?? '-'}', style: Bo.cell),
            ])),
        BoKv('UID', v: widget.uid, mono: true, copy: true),
        BoKv('이메일',
            v: email.isEmpty ? '(미등록)' : email,
            copy: email.isNotEmpty,
            note: _privateEmail.isEmpty && email.isNotEmpty ? '옛 문서(users.email)' : null),
        BoKv('로그인', child: Align(alignment: Alignment.centerLeft, child: BoProviderBadge((d['loginProvider'] as String? ?? '').trim()))),
        BoKv('플랫폼', v: d['platform'] as String? ?? '-'),
        BoKv('캐릭터', child: Row(children: [CharDot(d['characterId'] as String?), const SizedBox(width: 6), Text(charName(d['characterId'] as String?), style: Bo.cell)])),
        BoKv('가입일', v: fmtDateTime(tsOf(d['createdAt']))),
        BoKv('최근 활동', v: '${fmtDateTime(tsOf(d['lastUpdated']))}  (${timeAgo(tsOf(d['lastUpdated']))})'),
        BoKv('닉네임 변경권', v: '${intOf(d['nicknameTickets'])}장'),
        BoKv('국가 변경권', v: '${intOf(d['countryTickets'])}장'),
        BoKv('광고 제거', v: d['adsRemoved'] == true ? '구매함' : '아니오'),
      ]),
    );

    final bs = d['badgeStats'];
    final daily = d['daily'];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        BoGrid(
          minItemWidth: 400,
          maxColumns: 2,
          stretch: false,
          children: [
            profile,
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _equippedCard(d),
              if (bs is Map) ...[const SizedBox(height: Bo.gap), _badgeStatsCard(bs)],
              if (daily is Map) ...[const SizedBox(height: Bo.gap), _dailyCard(daily)],
            ]),
          ],
        ),
        const SizedBox(height: Bo.gap),
        _ownedCard(d),
      ],
    );
  }

  Widget _equippedCard(Map<String, dynamic> d) {
    final equippedRaw = d['equipped'];
    final equipped = <String, String>{
      if (equippedRaw is Map) for (final e in equippedRaw.entries) '${e.key}': '${e.value}',
    };
    return BoCard(
      title: '착용 중',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in kStages)
            BoKv(
              s.label,
              keyWidth: 130,
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                for (final slot in Gear.slotsOf(s.id))
                  (() {
                    final id = equipped[Gear.slotKey(s.id, slot)] ?? '';
                    return BoBadge('${kSlotNames[slot]} · ${id.isEmpty ? '없음' : itemName(id)}',
                        color: id.isEmpty ? Bo.text3 : s.color, dense: true);
                  })(),
              ]),
            ),
          BoKv(
            '꾸미기',
            keyWidth: 130,
            child: Wrap(spacing: 6, runSpacing: 4, children: [
              for (final k in const ['skin', 'trail', 'aura'])
                (() {
                  final id = equipped[k] ?? '';
                  return BoBadge('${kCosmeticKindNames[k]} · ${id.isEmpty ? '기본' : itemName(id)}',
                      color: id.isEmpty ? Bo.text3 : Bo.purple, dense: true);
                })(),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _badgeStatsCard(Map bs) {
    Widget stat(String label, String value) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Bo.caption),
            const SizedBox(height: 3),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Bo.text, fontFeatures: Bo.tabular)),
          ]),
        );
    return BoCard(
      title: '뱃지 누적 기록',
      subtitle: 'users.badgeStats — 경력·특별 뱃지 조건',
      child: Row(children: [
        stat('판 수', fmtNum(intOf(bs['runs']))),
        stat('플레이 시간', fmtDuration(dblOf(bs['playTime']))),
        stat('신기록 횟수', fmtNum(intOf(bs['newBests']))),
        stat('미션 올클리어', '${fmtNum(intOf(bs['allClearDays']))}일'),
      ]),
    );
  }

  Widget _dailyCard(Map daily) {
    final progress = daily['progress'];
    final claimed = (daily['claimed'] is List) ? (daily['claimed'] as List).map((e) => '$e').toList() : const <String>[];
    return BoCard(
      title: '일일 미션 · 출석',
      subtitle: 'users.daily',
      child: Column(children: [
        BoKv('미션 날짜', v: '${daily['date'] ?? '-'}'),
        BoKv(
          '진행',
          child: progress is Map && progress.isNotEmpty
              ? Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final e in progress.entries)
                    BoBadge('${e.key} · ${e.value}', color: claimed.contains('${e.key}') ? Bo.green : Bo.grey, dense: true),
                ])
              : Text('-', style: Bo.cell),
        ),
        BoKv('보상 받음', v: claimed.isEmpty ? '-' : claimed.join(', ')),
        if (daily.containsKey('bonus')) BoKv('올클리어 보너스', v: daily['bonus'] == true ? '받음' : '아니오'),
        BoKv('마지막 출석', v: '${daily['attLast'] ?? '-'}'),
        BoKv('연속 출석', v: '${intOf(daily['attStreak'])}일'),
      ]),
    );
  }

  Widget _ownedCard(Map<String, dynamic> d) {
    final owned = ((d['ownedItems'] as List?) ?? const []).map((e) => '$e').toList();
    final equippedRaw = d['equipped'];
    final equippedIds = {
      if (equippedRaw is Map) ...equippedRaw.values.map((e) => '$e'),
      'char_${d['characterId'] ?? ''}',
    };
    final groups = <String, List<String>>{};
    for (final id in owned) {
      groups.putIfAbsent(itemGroup(id), () => []).add(id);
    }
    final order = ['char', ...kStages.map((s) => 'gear:${s.id}'), 'skin', 'trail', 'aura', 'etc'];
    final keys = [...order.where(groups.containsKey), ...groups.keys.where((k) => !order.contains(k))];
    return BoCard(
      title: '보유 아이템',
      subtitle: '${owned.length}개 · 초록 = 착용 중',
      child: owned.isEmpty
          ? const BoEmpty('보유 아이템 없음')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final g in keys)
                  BoKv(
                    '${itemGroupLabel(g)} (${groups[g]!.length})',
                    keyWidth: 200,
                    child: Wrap(spacing: 6, runSpacing: 4, children: [
                      for (final id in groups[g]!)
                        Tooltip(
                          message: id,
                          child: BoBadge(itemName(id),
                              color: equippedIds.contains(id) ? Bo.green : Bo.grey,
                              icon: equippedIds.contains(id) ? Icons.check_rounded : null,
                              dense: true),
                        ),
                    ]),
                  ),
              ],
            ),
    );
  }

  // ── 관리 ──
  Widget _manage() {
    Widget action(IconData icon, String title, String desc, Widget button, {Color? color}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Bo.lineSoft))),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: (color ?? Bo.accent).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: color ?? Bo.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Bo.body.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(desc, style: Bo.muted),
              ]),
            ),
            button,
          ]),
        );
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              BoCard(
                title: '관리 액션',
                child: Column(children: [
                  action(Icons.edit_outlined, '정보 수정', '닉네임 · 국가 · 닉네임/국가 변경권 · 코인',
                      FilledButton(onPressed: _edit, child: const Text('수정'))),
                  action(Icons.card_giftcard_outlined, '아이템 지급', 'ownedItems 에 추가(arrayUnion). 착용은 유저가 직접 합니다.',
                      OutlinedButton(onPressed: _grant, child: const Text('지급')),
                      color: Bo.purple),
                  action(Icons.paid_outlined, '코인 지급', 'coins 를 더합니다(increment). 음수를 넣으면 회수합니다.',
                      OutlinedButton(onPressed: _grantCoins, child: const Text('지급')),
                      color: Bo.amber),
                  action(Icons.delete_outline_rounded, '유저 삭제', 'users 문서만 지웁니다. 되돌릴 수 없습니다.',
                      OutlinedButton(
                        onPressed: _delete,
                        style: OutlinedButton.styleFrom(foregroundColor: Bo.red, side: BorderSide(color: Bo.dangerBorder)),
                        child: const Text('삭제'),
                      ),
                      color: Bo.red),
                ]),
              ),
              const SizedBox(height: Bo.gap),
              BoCard(
                title: '참고',
                child: Text(
                  '· 수정은 users 문서만 바꿉니다. 게임이 실행 중이면 앱이 로컬 값으로 다시 덮어쓸 수 있습니다.\n'
                  '· 아이템 지급은 ownedItems 에 추가(arrayUnion)합니다. 착용은 유저가 직접 합니다.\n'
                  '· 코인 지급은 coins 를 더합니다(increment). 음수를 넣으면 회수합니다.\n'
                  '· 삭제는 users 문서만 지웁니다. 하위 컬렉션(runs·private)과 랭킹 기록은 남습니다.',
                  style: Bo.body.copyWith(color: Bo.text2, height: 1.7),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 뱃지·기록 탭 — 뱃지 격자(분류별, 보유=등급 색 / 미보유=회색) · bestTimes · 스테이지별 랭킹 기록
// ─────────────────────────────────────────────────────────────
class _BadgesRecordsTab extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> data;
  const _BadgesRecordsTab({required this.uid, required this.data});

  @override
  State<_BadgesRecordsTab> createState() => _BadgesRecordsTabState();
}

class _BadgesRecordsTabState extends State<_BadgesRecordsTab> with AutomaticKeepAliveClientMixin, BoReloadable {
  List<BoRec> _records = [];
  bool _loading = true;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lists = await Future.wait(kStages.map((s) => BoData.src.userRecords(s.id, widget.uid, 500)));
      final all = [for (final l in lists) ...l]..sort((a, b) => b.time.compareTo(a.time));
      if (mounted) setState(() => _records = all);
    } catch (e) {
      debugPrint('UserRecords: $e');
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteRecord(BoRec r) async {
    final ok = await confirmCode(
        context, '랭킹 기록 삭제', '${stageLabel(r.mapId)} · ${fmtSec(r.time)} 기록(${fmtDateTime(r.at)})을 삭제합니다.',
        ok: '삭제');
    if (!ok) return;
    try {
      await BoData.src.deleteRecord(r);
      if (mounted) toast(context, '삭제했습니다');
      reload();
    } catch (e) {
      if (mounted) toast(context, '삭제 실패: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _badgesCard(),
        const SizedBox(height: Bo.gap),
        BoGrid(
          minItemWidth: 380,
          maxColumns: 2,
          stretch: false,
          children: [_bestCard(), _recordsCard()],
        ),
      ],
    );
  }

  Widget _badgesCard() {
    final keys = badgeKeysOf(widget.data).toSet();
    final owned = Badges.all.where((b) => keys.contains(b.key)).length;
    final unknown = keys.where((k) => Badges.byKey(k) == null).toList()..sort();
    final tierCounts = List<int>.filled(5, 0);
    for (final b in Badges.all) {
      if (keys.contains(b.key)) tierCounts[b.tier.clamp(1, 4)]++;
    }
    return BoCard(
      title: '뱃지',
      subtitle: 'users.achievements · 한 번 얻으면 영구',
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        for (int t = 1; t <= 4; t++) ...[
          Container(width: 9, height: 9, decoration: BoxDecoration(color: BadgeDef.tierColor(t), shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('${tierName(t)} ${tierCounts[t]}', style: Bo.muted),
          const SizedBox(width: 12),
        ],
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('$owned', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Bo.text, fontFeatures: Bo.tabular)),
            Text(' / ${Badges.all.length}', style: TextStyle(fontSize: 16, color: Bo.text3, fontFeatures: Bo.tabular)),
            const SizedBox(width: 16),
            Expanded(child: BoBarTrack(ratio: Badges.all.isEmpty ? 0 : owned / Badges.all.length, height: 8)),
            const SizedBox(width: 12),
            Text(fmtPct(owned, Badges.all.length, digits: 0), style: Bo.cellStrong),
          ]),
          const SizedBox(height: 8),
          for (final cat in BadgeCategory.values) _categoryRow(cat, keys),
          if (unknown.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('정의에 없는 키 (${unknown.length})', style: Bo.muted),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [for (final k in unknown) BoBadge(k, dense: true)]),
          ],
        ],
      ),
    );
  }

  Widget _categoryRow(BadgeCategory cat, Set<String> keys) {
    final list = Badges.all.where((b) => b.category == cat).toList();
    if (list.isEmpty) return const SizedBox();
    final n = list.where((b) => keys.contains(b.key)).length;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Bo.lineSoft))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(kBadgeCategoryNames[cat] ?? cat.name, style: Bo.body.copyWith(fontWeight: FontWeight.w600)),
                Text('$n / ${list.length}', style: Bo.caption),
              ]),
            ),
          ),
          Expanded(
            child: Wrap(spacing: 8, runSpacing: 8, children: [for (final b in list) _BadgeTile(b, earned: keys.contains(b.key))]),
          ),
        ],
      ),
    );
  }

  Widget _bestCard() {
    final best = widget.data['bestTimes'];
    return BoCard(
      title: '스테이지 최고 기록',
      subtitle: 'users.bestTimes',
      child: Column(children: [
        for (final s in kStages)
          BoKv(
            s.label,
            keyWidth: 150,
            child: Text(best is Map && best[s.id] != null ? fmtSec(dblOf(best[s.id])) : '기록 없음',
                style: best is Map && best[s.id] != null ? Bo.cellStrong : Bo.muted.copyWith(color: Bo.text3)),
          ),
      ]),
    );
  }

  Widget _recordsCard() {
    Widget body;
    if (_loading && _records.isEmpty) {
      body = const BoLoading();
    } else if (_error != null) {
      body = BoError(error: _error!, onRetry: reload);
    } else {
      final shown = _records.take(30).toList();
      body = BoTable(
        columns: const [
          BoCol('스테이지', flex: 2, minWidth: 130),
          BoCol('기록', width: 96, numeric: true),
          BoCol('일시', width: 130),
          BoCol('시즌', width: 50, numeric: true),
          BoCol('', width: 44),
        ],
        rowCount: shown.length,
        empty: const BoEmpty('랭킹 기록 없음'),
        footer: _records.length > shown.length ? BoTableFooter(text: '최고 기록순 30건 표시 · 전체 ${_records.length}건') : null,
        cells: (i) {
          final r = shown[i];
          return [
            BoStageCell(r.mapId),
            BoTable.text(fmtSec(r.time), style: Bo.cellStrong),
            BoTable.text(fmtDateTime(r.at), style: Bo.muted),
            BoTable.text(r.data['season'] == null ? '-' : '${r.data['season']}', style: Bo.muted),
            IconButton(
              tooltip: '기록 삭제',
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              onPressed: () => _deleteRecord(r),
              icon: Icon(Icons.delete_outline_rounded, color: Bo.red),
            ),
          ];
        },
      );
    }
    return BoCard(
      title: '랭킹 기록',
      subtitle: 'maps/{stage}/records · ${_records.length}건',
      padding: EdgeInsets.zero,
      child: body,
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final BadgeDef badge;
  final bool earned;
  const _BadgeTile(this.badge, {required this.earned});

  @override
  Widget build(BuildContext context) {
    final desc = badgeDesc(badge.key);
    return Tooltip(
      message: '${badgeName(badge.key)} · ${tierName(badge.tier)}${desc.isEmpty ? '' : '\n$desc'}\n${badge.key}',
      child: Container(
        width: 176,
        padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
        decoration: BoxDecoration(
          color: earned ? badge.color.withValues(alpha: 0.07) : Bo.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: earned ? badge.color.withValues(alpha: 0.35) : Bo.lineSoft),
        ),
        child: Row(children: [
          BoBadgeIcon(badge, size: 28, earned: earned, tooltip: false),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(badgeName(badge.key),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: earned ? Bo.text : Bo.text3),
                  overflow: TextOverflow.ellipsis),
              Text(tierName(badge.tier),
                  style: TextStyle(fontSize: 11, color: earned ? Bo.ink(badge.color, 0.3) : Bo.text3)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 플레이 기록 탭 — users/{uid}/runs (timestamp 내림차순, 50개씩) + 스테이지 요약 + 최근 14일 일별
// 단일 컬렉션 쿼리라 자동 색인으로 충분하다.
// ─────────────────────────────────────────────────────────────
class _RunsTab extends StatefulWidget {
  final String uid;
  const _RunsTab({required this.uid});

  @override
  State<_RunsTab> createState() => _RunsTabState();
}

class _RunsTabState extends State<_RunsTab> with AutomaticKeepAliveClientMixin, BoReloadable {
  static const int _page = 50;
  final List<RunRow> _runs = [];
  Object? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  List<RunRow> _recent14 = [];
  Object? _recentError;

  @override
  bool get wantKeepAlive => true;

  @override
  Future<void> reload() async {
    _runs.clear();
    _cursor = null;
    _hasMore = true;
    await Future.wait([_more(), _load14()]);
  }

  Future<void> _more() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await BoData.src.userRunsPage(widget.uid, _cursor, _page);
      _cursor = p.cursor;
      _hasMore = p.hasMore;
      if (mounted) setState(() => _runs.addAll(p.items));
    } catch (e) {
      debugPrint('UserRuns: $e');
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load14() async {
    try {
      final rows = await BoData.src.userRunsSince(widget.uid, startOfToday().subtract(const Duration(days: 13)), 3000);
      if (mounted) setState(() => _recent14 = rows);
    } catch (e) {
      debugPrint('UserRuns14: $e');
      if (mounted) setState(() => _recentError = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        BoGrid(minItemWidth: 400, maxColumns: 2, stretch: false, children: [_summary(), _chart()]),
        const SizedBox(height: Bo.gap),
        BoCard(
          title: '플레이 기록',
          subtitle: '${_runs.length}판 불러옴 · 최신순',
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) BoError(error: _error!, onRetry: _more),
              if (_runs.isEmpty && _loading) const BoLoading(),
              if (!(_runs.isEmpty && _loading))
                RunsTable(
                  runs: _runs,
                  showUser: false,
                  empty: const BoEmpty('플레이 기록이 없습니다', hint: kNoRunsHint),
                  footer: _runs.isEmpty
                      ? null
                      : BoTableFooter(
                          text: '${fmtNum(_runs.length)}판 표시${_hasMore ? '' : ' · 마지막'}',
                          actions: [
                            if (_loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            if (_hasMore && !_loading)
                              OutlinedButton.icon(
                                onPressed: _more,
                                icon: const Icon(Icons.expand_more_rounded, size: 16),
                                label: const Text('더 보기'),
                              ),
                          ],
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summary() {
    final agg = <String, StageAgg>{};
    for (final r in _runs) {
      agg.putIfAbsent(r.mapId, StageAgg.new).add(r);
    }
    final ids = [...kStages.map((s) => s.id), ...agg.keys.where((k) => stageById(k) == null)];
    return BoCard(
      title: '스테이지 요약',
      subtitle: '불러온 ${_runs.length}판 기준',
      padding: EdgeInsets.zero,
      child: BoTable(
        columns: const [
          BoCol('스테이지', flex: 2, minWidth: 140),
          BoCol('판 수', width: 64, numeric: true),
          BoCol('평균', width: 80, numeric: true),
          BoCol('최고', width: 90, numeric: true),
          BoCol('총 시간', width: 100, numeric: true),
        ],
        rowCount: ids.length,
        cells: (i) {
          final a = agg[ids[i]];
          return [
            BoStageCell(ids[i]),
            BoTable.text(fmtNum(a?.runs ?? 0)),
            BoTable.text(a == null ? '-' : fmtSec(a.avg, digits: 1), style: Bo.muted),
            BoTable.text(a == null ? '-' : fmtSec(a.best), style: Bo.cellStrong),
            BoTable.text(a == null ? '-' : fmtDuration(a.total), style: Bo.muted),
          ];
        },
      ),
    );
  }

  Widget _chart() {
    return BoCard(
      title: '최근 14일 일별 판 수',
      child: _recentError != null
          ? BoError(error: _recentError!)
          : SizedBox(
              height: 150,
              child: BoChart(
                labels: dayLabels(14),
                bars: [BoSeries('판 수', Bo.accent.withValues(alpha: 0.85), dailyCounts(_recent14.map((r) => r.at), 14))],
                height: 150,
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 정보 수정 — 닉네임 · 국가 · 변경권 · 코인
// ─────────────────────────────────────────────────────────────
class EditUserDialog extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> data;
  const EditUserDialog({super.key, required this.uid, required this.data});

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  late final TextEditingController _nick = TextEditingController(text: widget.data['nickname'] as String? ?? '');
  late final TextEditingController _nickTicket = TextEditingController(text: '${intOf(widget.data['nicknameTickets'])}');
  late final TextEditingController _countryTicket = TextEditingController(text: '${intOf(widget.data['countryTickets'])}');
  late final TextEditingController _coins = TextEditingController(text: '${intOf(widget.data['coins'])}');
  late String _flag = widget.data['flag'] as String? ?? '';
  late String _country = widget.data['countryName'] as String? ?? '';
  bool _saving = false;

  @override
  void dispose() {
    _nick.dispose();
    _nickTicket.dispose();
    _countryTicket.dispose();
    _coins.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nick = _nick.text.trim();
    final coins = int.tryParse(_coins.text.trim());
    final nt = int.tryParse(_nickTicket.text.trim());
    final ct = int.tryParse(_countryTicket.text.trim());
    if (nick.isEmpty || nick.length > 40) return toast(context, '닉네임은 1~40자', error: true);
    if (coins == null || coins < 0 || coins > 10000000) return toast(context, '코인은 0 ~ 10,000,000', error: true);
    if (nt == null || nt < 0 || nt > 999 || ct == null || ct < 0 || ct > 999) {
      return toast(context, '변경권은 0 ~ 999', error: true);
    }
    if (!await confirmCode(context, '정보 수정 확인',
        '$nick (${widget.uid})\n\n코인 ${fmtNum(coins)} · 닉네임권 $nt · 국가권 $ct 로 저장합니다.',
        ok: '저장', okColor: Bo.accent)) {
      return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await BoData.src.updateUser(widget.uid, {
        'nickname': nick,
        'flag': _flag,
        'countryName': _country,
        'nicknameTickets': nt,
        'countryTickets': ct,
        'coins': coins,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        toast(context, '저장 실패: $e', error: true);
      }
    }
  }

  void _pickCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      favorite: ['KR', 'US', 'JP'],
      countryListTheme: CountryListThemeData(
        backgroundColor: Bo.surface,
        textStyle: TextStyle(color: Bo.text),
        searchTextStyle: TextStyle(color: Bo.text),
        inputDecoration: InputDecoration(hintText: '국가 검색…', prefixIcon: Icon(Icons.search)),
      ),
      onSelect: (Country c) => setState(() {
        _flag = c.flagEmoji;
        _country = c.name;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label) => InputDecoration(labelText: label);
    return AlertDialog(
      title: const Text('유저 정보 수정'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _nick, decoration: deco('닉네임')),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickCountry,
                child: InputDecorator(
                  decoration: deco('국가'),
                  child: Text(_country.isEmpty ? '국가 선택' : '$_flag  $_country', style: Bo.body),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _nickTicket, decoration: deco('닉네임 변경권'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _countryTicket, decoration: deco('국가 변경권'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 12),
              TextField(controller: _coins, decoration: deco('코인'), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('게임 앱이 켜져 있으면 로컬 값으로 다시 덮어쓸 수 있습니다.', style: Bo.caption),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('취소')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? '저장 중…' : '저장')),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 아이템 지급 — 목록에서 고르거나 id 직접 입력. 반환값 = 아이템 id
// ─────────────────────────────────────────────────────────────
class GrantItemDialog extends StatefulWidget {
  final Set<String> owned;
  const GrantItemDialog({super.key, required this.owned});

  @override
  State<GrantItemDialog> createState() => _GrantItemDialogState();
}

class _GrantItemDialogState extends State<GrantItemDialog> {
  String? _selected;
  final _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = allGrantableItems().where((id) => !widget.owned.contains(id)).toList();
    return AlertDialog(
      title: const Text('아이템 지급'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selected,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '미보유 아이템'),
              items: [
                for (final id in items)
                  DropdownMenuItem(
                    value: id,
                    child: Text('[${itemGroupLabel(itemGroup(id))}] ${itemName(id)}  ($id)', style: Bo.body, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() {
                _selected = v;
                _custom.clear();
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _custom,
              decoration: const InputDecoration(labelText: '또는 아이템 id 직접 입력', hintText: '예: wings_star, char_solar_gold'),
              onChanged: (_) => setState(() => _selected = null),
            ),
            const SizedBox(height: 10),
            Text('ownedItems 에 추가(arrayUnion)합니다.', style: Bo.caption),
          ],
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          onPressed: () {
            final id = _custom.text.trim().isNotEmpty ? _custom.text.trim() : _selected;
            if (id == null || id.isEmpty) return;
            Navigator.pop(context, id);
          },
          child: const Text('지급'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 코인 지급 — 더할 양을 넣는다(음수면 회수). 반환값 = 증감량
// ─────────────────────────────────────────────────────────────

class GrantCoinsDialog extends StatefulWidget {
  /// 지금 잔액 — 지급 뒤 얼마가 되는지 보여 준다
  final int current;
  const GrantCoinsDialog({super.key, required this.current});

  @override
  State<GrantCoinsDialog> createState() => _GrantCoinsDialogState();
}

class _GrantCoinsDialogState extends State<GrantCoinsDialog> {
  final _amount = TextEditingController();

  int get _value => int.tryParse(_amount.text.trim().replaceAll(',', '')) ?? 0;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _add(int n) => setState(() => _amount.text = '${_value + n}');

  @override
  Widget build(BuildContext context) {
    final after = (widget.current + _value).clamp(0, 10000000);
    return AlertDialog(
      title: const Text('코인 지급'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(labelText: '지급할 코인', hintText: '예: 1000 (음수면 회수)'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final n in [100, 500, 1000, 5000])
                  OutlinedButton(onPressed: () => _add(n), child: Text('+${fmtNum(n)}')),
                OutlinedButton(onPressed: () => _add(-100), child: const Text('-100')),
                TextButton(onPressed: () => setState(() => _amount.clear()), child: const Text('지우기')),
              ],
            ),
            const SizedBox(height: 12),
            Text('지금 ${fmtNum(widget.current)} → 지급 뒤 ${fmtNum(after)}', style: Bo.body),
            const SizedBox(height: 6),
            Text('coins 를 더합니다(increment). 0~1,000만 범위를 벗어나면 규칙이 막습니다.', style: Bo.caption),
          ],
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          onPressed: _value == 0 ? null : () => Navigator.pop(context, _value),
          child: Text(_value < 0 ? '회수' : '지급'),
        ),
      ],
    );
  }
}
