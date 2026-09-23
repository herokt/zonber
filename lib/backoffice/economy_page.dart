import 'package:flutter/material.dart';

import '../gear.dart';
import 'bo_common.dart';

// ─────────────────────────────────────────────────────────────
// 경제·아이템 — users 전체(BoData 캐시)에서 코인 분포 · 코인 상위 20명 · 뱃지 보유 현황 · 아이템별 보유/착용 수.
// 캐릭터 착용 = characterId, 장비 착용 = equipped['gear_{zone}_{slot}'], 꾸미기 = equipped['skin'|'trail'|'aura'].
// 뱃지 = users.achievements (회원만 계정에 저장된다 → 비율은 회원 수 대비).
// ─────────────────────────────────────────────────────────────
class EconomyPage extends StatefulWidget {
  const EconomyPage({super.key});

  @override
  State<EconomyPage> createState() => _EconomyPageState();
}

class _EconomyPageState extends State<EconomyPage> with BoReloadable {
  List<BoUser> _users = [];
  bool _loading = true;
  Object? _error;
  BadgeCategory? _badgeCat; // null = 전체
  bool _badgeAsc = false;

  @override
  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final u = await BoData.users();
      if (mounted) setState(() => _users = u);
    } catch (e) {
      debugPrint('Economy: $e');
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BoPage(
      topBar: BoTopBar(
        title: '경제 · 아이템',
        breadcrumb: const ['분석'],
        subtitle: '유저 ${fmtNum(_users.length)}명 기준',
      ),
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading && _users.isEmpty) return const BoLoading();
    if (_error != null) return Padding(padding: const EdgeInsets.all(24), child: BoError(error: _error!, onRetry: BoData.refreshAll));

    final owned = <String, int>{};
    final worn = <String, int>{};
    final badgeOwners = <String, int>{};
    final coins = <int>[];
    int members = 0, badgeSum = 0, itemSum = 0;
    for (final u in _users) {
      final d = u.data;
      members++;
      coins.add(intOf(d['coins']));
      final items = ((d['ownedItems'] as List?) ?? const []).map((e) => '$e').toSet();
      itemSum += items.length;
      for (final id in items) {
        owned[id] = (owned[id] ?? 0) + 1;
      }
      final eq = d['equipped'];
      if (eq is Map) {
        for (final v in eq.values.map((e) => '$e').toSet()) {
          if (v.isEmpty) continue;
          worn[v] = (worn[v] ?? 0) + 1;
        }
      }
      final ch = (d['characterId'] as String? ?? '').trim();
      if (ch.isNotEmpty) worn['char_$ch'] = (worn['char_$ch'] ?? 0) + 1;
      final bk = badgeKeysOf(d);
      badgeSum += bk.where((k) => Badges.byKey(k) != null).length;
      for (final k in bk) {
        badgeOwners[k] = (badgeOwners[k] ?? 0) + 1;
      }
    }
    final sum = coins.fold<int>(0, (a, b) => a + b);
    final sorted = [...coins]..sort();
    final median = sorted.isEmpty ? 0 : sorted[sorted.length ~/ 2];

    final groups = <(String, List<String>)>[
      ('캐릭터', [for (final c in kCharNames.keys) 'char_$c']),
      for (final s in kStages) ('장비 · ${s.label}', [for (final g in Gear.all.where((g) => g.zone == s.id)) g.id]),
      for (final k in const ['skin', 'trail', 'aura'])
        (kCosmeticKindNames[k]!, [for (final c in kCosmetics.where((c) => c.kind == k)) c.id]),
    ];
    final known = {for (final g in groups) ...g.$2};
    final unknown = {...owned.keys, ...worn.keys}.where((id) => !known.contains(id)).toList()..sort();
    if (unknown.isNotEmpty) groups.add(('기타 (카탈로그에 없는 id)', unknown));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        BoGrid(minItemWidth: 180, maxColumns: 4, children: [
          BoKpi(label: '보유 코인 합계', value: fmtNum(sum), sub: '유저 ${fmtNum(_users.length)}명', icon: Icons.monetization_on_outlined, color: Bo.coin),
          BoKpi(
            label: '1인당 코인',
            value: coins.isEmpty ? '0' : (sum / coins.length).toStringAsFixed(1),
            sub: '중앙값 ${fmtNum(median)}',
            icon: Icons.person_outline_rounded,
            color: Bo.amber,
          ),
          BoKpi(
            label: '회원 1인당 뱃지',
            value: members == 0 ? '0' : (badgeSum / members).toStringAsFixed(1),
            sub: '전체 ${Badges.all.length}종 · 회원 ${fmtNum(members)}명',
            icon: Icons.workspace_premium_outlined,
            color: Bo.purple,
          ),
          BoKpi(
            label: '1인당 보유 아이템',
            value: _users.isEmpty ? '0' : (itemSum / _users.length).toStringAsFixed(1),
            sub: '지급 가능 ${allGrantableItems().length}종',
            icon: Icons.inventory_2_outlined,
            color: Bo.teal,
          ),
        ]),
        const SizedBox(height: Bo.gap),
        BoGrid(
          minItemWidth: 420,
          maxColumns: 2,
          stretch: false,
          children: [_coinBuckets(coins), _topHolders()],
        ),
        const SizedBox(height: Bo.gap),
        _badgeCard(badgeOwners, members),
        const SizedBox(height: Bo.gap),
        const BoSectionHeader('아이템 보유 · 착용', subtitle: '막대 = 보유 유저 수 · 값 = 보유 / 착용', padding: EdgeInsets.fromLTRB(2, 4, 2, 10)),
        BoGrid(
          minItemWidth: 380,
          maxColumns: 3,
          stretch: false,
          children: [for (final g in groups) _itemCard(g.$1, g.$2, owned, worn)],
        ),
      ],
    );
  }

  Widget _coinBuckets(List<int> coins) {
    const buckets = [('0', 0, 0), ('1~99', 1, 99), ('100~499', 100, 499), ('500~999', 500, 999), ('1,000+', 1000, 999999999999)];
    final counts = [for (final b in buckets) coins.where((c) => c >= b.$2 && c <= b.$3).length];
    final max = counts.fold<int>(0, (m, e) => e > m ? e : m).toDouble();
    return BoCard(
      title: '코인 분포',
      subtitle: '보유 코인 구간별 유저 수',
      child: SizedBox(
        height: 300,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < buckets.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: BoHBar(
                  label: '${buckets[i].$1} 코인',
                  value: counts[i].toDouble(),
                  max: max,
                  valueText: '${fmtNum(counts[i])}명  ${fmtPct(counts[i], coins.length, digits: 0)}',
                  valueWidth: 100,
                  color: Color.lerp(Bo.isDark ? const Color(0xFF7A5A1E) : const Color(0xFFFCD34D), Bo.coin, i / (buckets.length - 1))!,
                  labelWidth: 110,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _topHolders() {
    final top = ([..._users]..sort((a, b) => intOf(b.data['coins']).compareTo(intOf(a.data['coins'])))).take(20).toList();
    return BoCard(
      title: '코인 상위 20명',
      subtitle: '보유 코인 기준 · 행을 누르면 유저 상세',
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 300 + 16,
        child: BoTable(
          scroll: true,
          rowHeight: 36,
          columns: const [
            BoCol('#', width: 40),
            BoCol('유저', flex: 3, minWidth: 160),
            BoCol('로그인', width: 86),
            BoCol('코인', width: 96, numeric: true),
          ],
          rowCount: top.length,
          onRowTap: (i) => BoNav.openUser(top[i].id),
          cells: (i) => [
            BoTable.text('${i + 1}', style: Bo.muted),
            BoUserCell(uid: top[i].id, data: top[i].data, showBadge: true),
            BoProviderBadge((top[i].data['loginProvider'] as String? ?? '').trim()),
            BoTable.text(fmtNum(intOf(top[i].data['coins'])), style: Bo.cellStrong, color: Bo.coin),
          ],
        ),
      ),
    );
  }

  // ── 뱃지 보유 현황 ──
  Widget _badgeCard(Map<String, int> owners, int members) {
    final list = Badges.all.where((b) => _badgeCat == null || b.category == _badgeCat).toList()
      ..sort((a, b) {
        final c = (owners[a.key] ?? 0).compareTo(owners[b.key] ?? 0);
        return _badgeAsc ? c : -c;
      });
    final maxOwn = owners.values.fold<int>(0, (m, v) => v > m ? v : m).toDouble();
    return BoCard(
      title: '뱃지 보유 현황',
      subtitle: '뱃지별 보유 유저 수 (users.achievements) · 비율 = 회원 ${fmtNum(members)}명 대비',
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              _catChip(null, '전체 ${Badges.all.length}'),
              for (final c in BadgeCategory.values)
                _catChip(c, '${kBadgeCategoryNames[c]} ${Badges.all.where((b) => b.category == c).length}'),
            ]),
          ),
          SizedBox(
            height: 420,
            child: BoTable(
              scroll: true,
              sortColumn: 4,
              sortAsc: _badgeAsc,
              onSort: (_) => setState(() => _badgeAsc = !_badgeAsc),
              columns: const [
                BoCol('#', width: 44),
                BoCol('뱃지', flex: 3, minWidth: 220),
                BoCol('분류', width: 96),
                BoCol('등급', width: 86),
                BoCol('보유 유저', width: 96, numeric: true, sortable: true),
                BoCol('회원 대비', flex: 2, minWidth: 180),
              ],
              rowCount: list.length,
              cells: (i) {
                final b = list[i];
                final n = owners[b.key] ?? 0;
                final desc = badgeDesc(b.key);
                return [
                  BoTable.text('${i + 1}', style: Bo.muted),
                  Tooltip(
                    message: '${b.key}${desc.isEmpty ? '' : '\n$desc'}',
                    child: Row(children: [
                      BoBadgeIcon(b, size: 24, earned: n > 0, tooltip: false),
                      const SizedBox(width: 8),
                      Flexible(child: Text(badgeName(b.key), style: Bo.cellStrong, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                  BoTable.text(kBadgeCategoryNames[b.category] ?? b.category.name, style: Bo.muted),
                  BoBadge(tierName(b.tier), color: Bo.ink(b.color, 0.2), dense: true),
                  BoTable.text(fmtNum(n), style: Bo.cellStrong, color: n == 0 ? Bo.text3 : null),
                  Row(children: [
                    Expanded(child: BoBarTrack(ratio: maxOwn <= 0 ? 0 : n / maxOwn, color: b.color, height: 6)),
                    const SizedBox(width: 8),
                    SizedBox(width: 48, child: Text(fmtPct(n, members), textAlign: TextAlign.right, style: Bo.muted)),
                  ]),
                ];
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _catChip(BadgeCategory? c, String label) {
    final sel = _badgeCat == c;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => setState(() => _badgeCat = c),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? Bo.accentSoft : Bo.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: sel ? Bo.accent.withValues(alpha: 0.4) : Bo.line),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.w500, color: sel ? Bo.accent : Bo.text2)),
      ),
    );
  }

  Widget _itemCard(String title, List<String> ids, Map<String, int> owned, Map<String, int> worn) {
    final rows = [...ids]..sort((a, b) => (owned[b] ?? 0).compareTo(owned[a] ?? 0));
    final max = rows.fold<int>(0, (m, id) => (owned[id] ?? 0) > m ? owned[id]! : m).toDouble();
    return BoCard(
      title: title,
      subtitle: '${ids.length}종',
      child: Column(children: [
        for (final id in rows)
          BoHBar(
            label: _label(id),
            value: (owned[id] ?? 0).toDouble(),
            max: max,
            valueText: '${fmtNum(owned[id] ?? 0)} / ${fmtNum(worn[id] ?? 0)}',
            color: id.startsWith('char_') ? charColor(id.substring(5)) : Bo.accent.withValues(alpha: 0.75),
            labelWidth: 150,
            tooltip: '$id · 보유 ${owned[id] ?? 0}명 · 착용 ${worn[id] ?? 0}명',
          ),
      ]),
    );
  }

  String _label(String id) {
    final g = Gear.byId(id);
    if (g != null) {
      final tag = g.price > 0 ? ' (${g.price})' : (g.needsBadge != null ? ' (뱃지: ${badgeName(g.needsBadge!)})' : '');
      return '${kSlotNames[g.slot]} · ${itemName(id)}$tag';
    }
    final c = cosmeticById(id);
    if (c != null) return '${c.name}${c.price > 0 ? ' (${c.price})' : ''}';
    return itemName(id);
  }
}
