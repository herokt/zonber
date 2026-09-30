import 'dart:async';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

import 'bo_common.dart';
import 'legacy_records_panel.dart';
import 'user_detail_page.dart' show GrantItemDialog;

// ─────────────────────────────────────────────────────────────
// 유저 목록 — users 전체를 한 번 읽어(BoData 캐시) 검색·필터·정렬·페이지는 화면에서 한다. 기본 필터 = 회원.
// 이메일 검색은 옛 문서의 users.email 만 대상(새 문서는 private/account 에 있어 목록에서 읽지 않는다).
// 왼쪽 칸으로 여러 명을 골라 한꺼번에: 코인 지급·회수 · 아이템 지급 · 변경권 지급 · 국가 바꾸기 · 계정 삭제(서버 함수 adminDeleteUsers).
// [유저 ID 없는 기록] 으로 바꾸면 랭킹 기록만 있고 회원이 아닌 사람(옛 기록 · 탈퇴)을 사람별로 보고 회원에 연결하거나 지운다
// (legacy_records_panel.dart).
// 바꾸는 동작은 모두 숫자 확인(confirmCode)을 거친다.
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
  int _sortCol = 10; // 최근 활동
  bool _asc = false;
  int _page = 0;

  /// 고른 유저 uid — 페이지·검색을 바꿔도 남는다
  final Set<String> _selected = {};

  /// 일괄 작업 중 — (한 일, 전체)
  (int, int)? _progress;

  /// false = 회원 · true = 유저 ID 없는 기록
  bool _legacy = false;

  static const _cols = [
    BoCol('', width: 44),
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
        5 => badgeCountOf(d),
        6 => intOf(d['coins']),
        7 => intOf(d['totalGamesPlayed']),
        8 => dblOf(d['totalPlayTime']),
        9 => tsOf(d['createdAt'])?.millisecondsSinceEpoch ?? 0,
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
          child: _legacy
              ? LegacyRecordsPanel(leading: _modeSwitch())
              : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BoToolbar(
                filters: [
                  _modeSwitch(),
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
              _bulkBar(view),
              Expanded(child: _body(view, rows.length, page, start)),
            ],
          ),
        ),
      ),
    );
  }

  /// 회원 ↔ 유저 ID 없는 기록
  Widget _modeSwitch() => BoSegmented<bool>(
        options: const [(false, '회원'), (true, '유저 ID 없는 기록')],
        value: _legacy,
        onChanged: _progress != null ? (_) {} : (v) => setState(() => _legacy = v),
      );

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
        final on = _selected.contains(u.id);
        final provider = (d['loginProvider'] as String? ?? '').trim();
        final last = tsOf(d['lastUpdated']);
        final badges = badgeCountOf(d);
        return [
          Checkbox(
            value: on,
            visualDensity: VisualDensity.compact,
            onChanged: _progress != null ? null : (v) => setState(() => v == true ? _selected.add(u.id) : _selected.remove(u.id)),
          ),
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

  // ── 일괄 작업 ──

  List<BoUser> get _picked => [for (final u in _all) if (_selected.contains(u.id)) u];

  /// 고른 사람 한 줄(확인창) — 5명까지 이름, 나머지는 수
  String _whoLine() {
    final p = _picked;
    final names = p.take(5).map((u) => nickOf(u.data)).join(', ');
    return p.length <= 5 ? '$names (${p.length}명)' : '$names 외 ${p.length - 5}명 (${p.length}명)';
  }

  /// 선택 줄 — 이 페이지 전체 선택 · 고른 수 · 작업 버튼
  Widget _bulkBar(List<BoUser> view) {
    final allOnPage = view.isNotEmpty && view.every((u) => _selected.contains(u.id));
    final busy = _progress != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: _selected.isEmpty ? null : Bo.accentSoft,
        border: Border(bottom: BorderSide(color: Bo.lineSoft)),
      ),
      child: Row(children: [
        Checkbox(
          value: allOnPage,
          visualDensity: VisualDensity.compact,
          onChanged: busy
              ? null
              : (v) => setState(() {
                    for (final u in view) {
                      v == true ? _selected.add(u.id) : _selected.remove(u.id);
                    }
                  }),
        ),
        Text(
          busy
              ? '처리 중 ${_progress!.$1}/${_progress!.$2}…'
              : _selected.isEmpty
                  ? '이 페이지 전체 선택'
                  : '${fmtNum(_selected.length)}명 선택',
          style: Bo.body.copyWith(fontWeight: _selected.isEmpty ? FontWeight.w400 : FontWeight.w700),
        ),
        if (_selected.isNotEmpty && !busy) ...[
          TextButton(onPressed: () => setState(_selected.clear), child: const Text('선택 해제')),
          const Spacer(),
          Wrap(spacing: 6, children: [
            OutlinedButton.icon(onPressed: _bulkCoins, icon: const Icon(Icons.paid_outlined, size: 16), label: const Text('코인')),
            OutlinedButton.icon(onPressed: _bulkItem, icon: const Icon(Icons.card_giftcard_outlined, size: 16), label: const Text('아이템')),
            OutlinedButton.icon(onPressed: _bulkTickets, icon: const Icon(Icons.confirmation_number_outlined, size: 16), label: const Text('변경권')),
            OutlinedButton.icon(onPressed: _bulkCountry, icon: const Icon(Icons.flag_outlined, size: 16), label: const Text('국가')),
            FilledButton.icon(
              onPressed: _bulkDelete,
              style: FilledButton.styleFrom(backgroundColor: Bo.red),
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text('삭제'),
            ),
          ]),
        ] else
          const Spacer(),
      ]),
    );
  }

  /// 고른 사람마다 [f] — 진행을 보여 주고, 실패한 수를 돌려준다
  Future<int> _each(Future<void> Function(BoUser u) f) async {
    final list = _picked;
    var failed = 0;
    setState(() => _progress = (0, list.length));
    for (var i = 0; i < list.length; i++) {
      try {
        await f(list[i]);
      } catch (e) {
        failed++;
        debugPrint('bulk ${list[i].id}: $e');
      }
      if (mounted) setState(() => _progress = (i + 1, list.length));
    }
    if (mounted) setState(() => _progress = null);
    BoData.refreshAll();
    return failed;
  }

  void _done(String what, int failed) {
    if (!mounted) return;
    toast(context, failed == 0 ? '$what 완료' : '$what — 실패 $failed건', error: failed > 0);
  }

  /// 숫자 하나 받기(음수는 [allowNegative] 일 때만)
  Future<int?> _askInt(String title, String hint, {bool allowNegative = false}) async {
    final v = await showDialog<int>(context: context, builder: (_) => _AskIntDialog(title: title, hint: hint));
    if (v == null || v == 0 || (!allowNegative && v < 0)) return null;
    return v;
  }

  Future<void> _bulkCoins() async {
    final n = await _askInt('코인 일괄 지급', '한 사람당 코인 (음수 = 회수, 예: 500 · -200)', allowNegative: true);
    if (n == null || !mounted) return;
    if (!await confirmCode(context, n > 0 ? '코인 일괄 지급' : '코인 일괄 회수', '${_whoLine()}\n\n한 사람당 ${n > 0 ? '+' : ''}${fmtNum(n)} 코인',
        ok: n > 0 ? '지급' : '회수', okColor: Bo.amber)) {
      return;
    }
    _done(n > 0 ? '코인 지급' : '코인 회수', await _each((u) => BoData.src.grantCoins(u.id, n)));
  }

  Future<void> _bulkItem() async {
    final id = await showDialog<String>(context: context, builder: (_) => const GrantItemDialog(owned: {}));
    if (id == null || id.isEmpty || !mounted) return;
    if (!await confirmCode(context, '아이템 일괄 지급', '${_whoLine()}\n\n${itemName(id)} ($id) — 이미 가진 사람은 그대로',
        ok: '지급', okColor: Bo.purple)) {
      return;
    }
    _done('${itemName(id)} 지급', await _each((u) => BoData.src.grantItem(u.id, id)));
  }

  Future<void> _bulkTickets() async {
    final kind = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(title: const Text('변경권 일괄 지급'), children: [
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'nicknameTickets'), child: const Text('닉네임 변경권')),
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'countryTickets'), child: const Text('국가 변경권')),
      ]),
    );
    if (kind == null || !mounted) return;
    final label = kind == 'nicknameTickets' ? '닉네임 변경권' : '국가 변경권';
    final n = await _askInt('$label 일괄 지급', '한 사람당 몇 장 (1~99)');
    if (n == null || n > 99 || !mounted) return;
    if (!await confirmCode(context, '$label 일괄 지급', '${_whoLine()}\n\n한 사람당 +$n장', ok: '지급', okColor: Bo.accent)) return;
    _done('$label 지급', await _each((u) => BoData.src.incrementField(u.id, kind, n)));
  }

  Future<void> _bulkCountry() async {
    final c = await _pickCountry();
    if (c == null || !mounted) return;
    if (!await confirmCode(context, '국가 일괄 변경', '${_whoLine()}\n\n${c.flagEmoji} ${c.name} 로 바꿉니다.', ok: '변경', okColor: Bo.accent)) {
      return;
    }
    _done('국가 변경', await _each((u) => BoData.src.updateUser(u.id, {'flag': c.flagEmoji, 'countryName': c.name})));
  }

  /// 국가 고르기 창 — 고르면 그 나라, 닫으면 null
  Future<Country?> _pickCountry() {
    final done = Completer<Country?>();
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      favorite: const ['KR', 'US', 'JP'],
      onSelect: (c) {
        if (!done.isCompleted) done.complete(c);
      },
      onClosed: () {
        if (!done.isCompleted) done.complete(null);
      },
    );
    return done.future;
  }

  Future<void> _bulkDelete() async {
    final list = _picked;
    if (!await confirmCode(
      context,
      '계정 일괄 삭제',
      '${_whoLine()}\n\n로그인 계정 · 랭킹 기록 · 플레이 기록 · 친구 · 코인·아이템까지 통째로 지웁니다.\n되돌릴 수 없습니다.',
      ok: '${list.length}명 삭제',
      okColor: Bo.red,
    )) {
      return;
    }
    setState(() => _progress = (0, list.length));
    Map<String, String> res = const {};
    try {
      res = await BoData.src.deleteUsersFully([for (final u in list) u.id]);
    } catch (e) {
      if (mounted) toast(context, '삭제 실패: $e', error: true);
    }
    final ok = res.values.where((v) => v == 'ok').length;
    if (mounted) {
      setState(() {
        _progress = null;
        _selected.removeWhere((id) => res[id] == 'ok');
      });
    }
    BoData.refreshAll();
    if (res.isNotEmpty) _done('$ok명 삭제', res.length - ok);
  }

}

/// 숫자 하나 받는 창 — 입력칸은 창이 닫힌 뒤에 정리한다(닫히는 동안에도 쓰인다)
class _AskIntDialog extends StatefulWidget {
  final String title;
  final String hint;
  const _AskIntDialog({required this.title, required this.hint});

  @override
  State<_AskIntDialog> createState() => _AskIntDialogState();
}

class _AskIntDialogState extends State<_AskIntDialog> {
  final TextEditingController _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _ok() => Navigator.pop(context, int.tryParse(_c.text.trim()));

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: _c,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: InputDecoration(hintText: widget.hint, isDense: true),
            onSubmitted: (_) => _ok(),
          ),
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(onPressed: _ok, child: const Text('다음')),
        ],
      );
}
