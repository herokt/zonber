import 'package:flutter/material.dart';

import 'bo_common.dart';
import 'dashboard_page.dart';
import 'economy_page.dart';
import 'ranking_page.dart';
import 'promo_codes_page.dart';
import 'promo_page.dart';
import 'runs_page.dart';
import 'user_detail_page.dart';
import 'user_list_page.dart';

// ─────────────────────────────────────────────────────────────
// 백오피스 셸 — 왼쪽 사이드바(그룹 메뉴, 1180px 미만이면 아이콘만) + 오른쪽 화면.
// 한 번 연 화면은 상태(필터·페이지)를 유지한다. 유저 상세는 현재 화면 위에 열리고 뒤로 가면 돌아온다.
// ─────────────────────────────────────────────────────────────
class BackofficeHome extends StatefulWidget {
  const BackofficeHome({super.key});

  @override
  State<BackofficeHome> createState() => _BackofficeHomeState();
}

class _NavItem {
  final BoSection section;
  final IconData icon;
  final IconData iconOn;
  final String label;
  const _NavItem(this.section, this.icon, this.iconOn, this.label);
}

const _groups = <(String, List<_NavItem>)>[
  ('개요', [_NavItem(BoSection.dashboard, Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, '대시보드')]),
  (
    '운영',
    [
      _NavItem(BoSection.users, Icons.people_outline_rounded, Icons.people_rounded, '유저'),
      _NavItem(BoSection.ranking, Icons.emoji_events_outlined, Icons.emoji_events_rounded, '랭킹 관리'),
      _NavItem(BoSection.runs, Icons.history_rounded, Icons.history_rounded, '플레이 기록'),
      _NavItem(BoSection.promos, Icons.celebration_outlined, Icons.celebration_rounded, '이벤트'),
      _NavItem(BoSection.codes, Icons.confirmation_number_outlined, Icons.confirmation_number_rounded, '이벤트 코드'),
    ]
  ),
  ('분석', [_NavItem(BoSection.economy, Icons.insights_outlined, Icons.insights_rounded, '경제·아이템')]),
];

class _BackofficeHomeState extends State<BackofficeHome> {
  final Set<BoSection> _visited = {};
  bool? _userCollapsed;

  Widget _page(BoSection s) => switch (s) {
        BoSection.dashboard => const DashboardPage(),
        BoSection.users => const UserListPage(),
        BoSection.ranking => const RankingPage(),
        BoSection.runs => const RunsPage(),
        BoSection.promos => const PromoPage(),
        BoSection.codes => const PromoCodesPage(),
        BoSection.economy => const EconomyPage(),
      };

  @override
  Widget build(BuildContext context) {
    final auto = MediaQuery.sizeOf(context).width < 1180;
    final collapsed = _userCollapsed ?? auto;
    return Scaffold(
      backgroundColor: Bo.bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder<BoSection>(
            valueListenable: BoNav.section,
            builder: (context, section, _) => _Sidebar(
              section: section,
              collapsed: collapsed,
              onToggle: () => setState(() => _userCollapsed = !collapsed),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<BoSection>(
              valueListenable: BoNav.section,
              builder: (context, section, _) => ValueListenableBuilder<String?>(
                valueListenable: BoNav.userUid,
                builder: (context, uid, _) {
                  _visited.add(section);
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      for (final s in BoSection.values)
                        if (_visited.contains(s))
                          Offstage(
                            offstage: s != section || uid != null,
                            child: TickerMode(enabled: s == section && uid == null, child: _page(s)),
                          ),
                      if (uid != null) UserDetailPage(key: ValueKey(uid), uid: uid),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final BoSection section;
  final bool collapsed;
  final VoidCallback onToggle;
  const _Sidebar({required this.section, required this.collapsed, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: collapsed ? 68 : 240,
      decoration: BoxDecoration(color: Bo.surface, border: Border(right: BorderSide(color: Bo.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 로고
          Container(
            height: 68,
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 20),
            alignment: collapsed ? Alignment.center : Alignment.centerLeft,
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Bo.line))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF6366F1), Bo.accent]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Z', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Text('ZONBER', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Bo.text, letterSpacing: 0.4)),
                  const SizedBox(width: 5),
                  Text('Admin', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Bo.text3)),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 12, vertical: 12),
              children: [
                for (final g in _groups) ...[
                  if (!collapsed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
                      child: Text(g.$1, style: Bo.caption.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                    )
                  else
                    Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Bo.lineSoft)),
                  for (final it in g.$2) _NavTile(item: it, selected: it.section == section, collapsed: collapsed),
                ],
              ],
            ),
          ),
          if (BoData.src.isPreview && !collapsed)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Bo.warnSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Bo.warnBorder),
              ),
              child: Row(children: [
                Icon(Icons.visibility_outlined, size: 15, color: Bo.amber),
                SizedBox(width: 6),
                Expanded(child: Text('미리보기 · 가짜 데이터', style: TextStyle(fontSize: 12, color: Bo.warnText))),
              ]),
            ),
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Bo.line))),
            padding: const EdgeInsets.all(8),
            alignment: collapsed ? Alignment.center : Alignment.centerRight,
            child: IconButton(
              tooltip: collapsed ? '메뉴 펼치기' : '메뉴 접기',
              onPressed: onToggle,
              icon: Icon(collapsed ? Icons.keyboard_double_arrow_right_rounded : Icons.keyboard_double_arrow_left_rounded, size: 18),
              color: Bo.text3,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final bool collapsed;
  const _NavTile({required this.item, required this.selected, required this.collapsed});

  @override
  Widget build(BuildContext context) {
    final color = selected ? Bo.accent : Bo.text2;
    final tile = Material(
      color: selected ? Bo.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        hoverColor: Bo.hoverStrong,
        onTap: () => BoNav.go(item.section),
        child: SizedBox(
          height: 38,
          child: Row(
            mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              if (!collapsed) const SizedBox(width: 10),
              Icon(selected ? item.iconOn : item.icon, size: 19, color: color),
              if (!collapsed) ...[
                const SizedBox(width: 11),
                Text(item.label,
                    style: TextStyle(fontSize: 13.5, color: selected ? Bo.accent : Bo.text, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
              ],
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: collapsed ? Tooltip(message: item.label, preferBelow: false, child: tile) : tile,
    );
  }
}
