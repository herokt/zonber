import 'package:flutter/material.dart';

import 'bo_common.dart';

// ─────────────────────────────────────────────────────────────
// 유저 목록 — users 전체를 한 번 읽어(BoData 캐시) 검색·필터·정렬·페이지는 화면에서 한다. 기본 필터 = 회원.
// 이메일 검색은 옛 문서의 users.email 만 대상(새 문서는 private/account 에 있어 목록에서 읽지 않는다).
// ─────────────────────────────────────────────────────────────
class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> with BoReloadable {
  static const int _pageSize = 50;

  final _search = TextEditingController();
  List<BoUser> _all = [];
  bool _loading = true;
  Object? _error;

  String _country = ''; // '' = 전체
  int _sortCol = 9; // 최근 활동
  bool _asc = false;
  int _page = 0;

  static const _cols = [
    BoCol('유저', flex: 3, minWidth: 220),
    BoCol('UID', width: 150),
    BoCol('로그인', width: 86),
    BoCol('플랫폼', width: 76),
    BoCol('뱃지 수', width: 76, numeric: true, sortable: true, tooltip: '정의된 뱃지 중 보유 수'),
    BoCol('코인', width: 86, numeric: true, sortable: true),
    BoCol('판 수', width: 76, numeric: true, sortable: true),
    BoCol('플레이 시간', width: 110, numeric: true, sortable: true),
    BoCol('가입일', width: 100, numeric: true, sortable: true),
    BoCol('최근 활동', width: 96, numeric: true, sortable: true),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final u = await BoData.users();
      if (mounted) setState(() => _all = u);
    } catch (e) {
      debugPrint('UserList: $e');
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  num _sortKey(Map<String, dynamic> d) => switch (_sortCol) {
        4 => badgeCountOf(d),
        5 => intOf(d['coins']),
        6 => intOf(d['totalGamesPlayed']),
        7 => dblOf(d['totalPlayTime']),
        8 => tsOf(d['createdAt'])?.millisecondsSinceEpoch ?? 0,
        _ => tsOf(d['lastUpdated'])?.millisecondsSinceEpoch ?? 0,
      };

  List<BoUser> get _filtered {
    final q = _search.text.trim().toLowerCase();
    final list = _all.where((u) {
      final d = u.data;
      if (_country.isNotEmpty && (d['countryName'] as String? ?? '') != _country) return false;
      if (q.isEmpty) return true;
      return (d['nickname'] as String? ?? '').toLowerCase().contains(q) ||
          u.id.toLowerCase().contains(q) ||
          (d['email'] as String? ?? '').toLowerCase().contains(q);
    }).toList();
    list.sort((a, b) {
      final c = _sortKey(a.data).compareTo(_sortKey(b.data));
      return _asc ? c : -c;
    });
    return list;
  }

  List<(String, String)> get _countries {
    final m = <String, int>{};
    for (final u in _all) {
      final c = (u.data['countryName'] as String? ?? '').trim();
      if (c.isNotEmpty) m[c] = (m[c] ?? 0) + 1;
    }
    final l = m.keys.toList()..sort((a, b) => m[b]!.compareTo(m[a]!));
    return [('', '전체'), for (final c in l) (c, '$c (${m[c]})')];
  }

  void _set(VoidCallback f) => setState(() {
        f();
        _page = 0;
      });

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    final pages = rows.isEmpty ? 1 : (rows.length + _pageSize - 1) ~/ _pageSize;
    final page = _page.clamp(0, pages - 1);
    final start = page * _pageSize;
    final view = rows.skip(start).take(_pageSize).toList();

    return BoPage(
      topBar: BoTopBar(
        title: '유저',
        breadcrumb: const ['운영'],
        subtitle: _loading && _all.isEmpty
            ? '불러오는 중…'
            : '회원 ${fmtNum(_all.length)}명',
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: BoCard(
          fill: true,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BoToolbar(
                filters: [
                  BoSearchField(
                    controller: _search,
                    hint: '닉네임 · UID · 이메일 검색',
                    onChanged: (_) => _set(() {}),
                  ),
                  BoDropdown<String>(
                    label: '국가',
                    value: _country,
                    items: _countries,
                    onChanged: (v) => _set(() => _country = v),
                  ),
                ],
                trailing: [Text('${fmtNum(rows.length)}명', style: Bo.muted)],
              ),
              Expanded(child: _body(view, rows.length, page, start)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(List<BoUser> view, int total, int page, int start) {
    if (_loading && _all.isEmpty) return const BoLoading();
    if (_error != null) return BoError(error: _error!, onRetry: () => BoData.refreshAll());
    return BoTable(
      columns: _cols,
      scroll: true,
      rowCount: view.length,
      sortColumn: _sortCol,
      sortAsc: _asc,
      onSort: (c) => _set(() {
        if (_sortCol == c) {
          _asc = !_asc;
        } else {
          _sortCol = c;
          _asc = false;
        }
      }),
      onRowTap: (i) => BoNav.openUser(view[i].id),
      empty: const BoEmpty('조건에 맞는 유저가 없습니다', icon: Icons.person_search_outlined),
      footer: BoPager(total: total, page: page, pageSize: _pageSize, unit: '명', onPage: (p) => setState(() => _page = p)),
      cells: (i) {
        final u = view[i];
        final d = u.data;
        final provider = (d['loginProvider'] as String? ?? '').trim();
        final last = tsOf(d['lastUpdated']);
        final badges = badgeCountOf(d);
        return [
          BoUserCell(uid: u.id, data: d, showBadge: true),
          BoTable.text(u.id, style: Bo.mono, tooltip: u.id),
          BoProviderBadge(provider),
          BoTable.text(d['platform'] as String? ?? '-', style: Bo.muted),
          BoTable.text(badges == 0 ? '-' : '$badges', color: badges == 0 ? Bo.text3 : null),
          BoTable.text(fmtNum(intOf(d['coins'])), color: Bo.coin),
          BoTable.text(fmtNum(intOf(d['totalGamesPlayed']))),
          BoTable.text(fmtDuration(dblOf(d['totalPlayTime'])), style: Bo.muted),
          BoTable.text(fmtDate(tsOf(d['createdAt'])), style: Bo.muted),
          BoTable.text(timeAgo(last), tooltip: '최근 활동 ${fmtDateTime(last)}'),
        ];
      },
    );
  }
}
