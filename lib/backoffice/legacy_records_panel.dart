import 'package:flutter/material.dart';

import 'bo_common.dart';

// ─────────────────────────────────────────────────────────────
// 유저 탭 › [유저 ID 없는 기록] — 랭킹 기록 중 userId 가 없거나(옛 버전에서 옮겨 온 기록) 유저 문서가 없는(탈퇴 등) 것을
// 사람별(닉네임 · 옛 uid)로 묶어 보여 준다. 세 존 기록을 전부 읽어 화면에서 묶는다(BoLegacy.group).
//  - 회원에 연결: 기록에 그 회원 uid 를 붙인다(+ 더 좋으면 회원 프로필 최고 기록도 올림) → 랭킹에서 눌러 프로필이 뜬다
//  - 기록 삭제: 그 사람의 랭킹 기록을 지운다(되돌릴 수 없다)
// 줄을 누르면 기록 목록 · 닉네임이 같은 회원 후보가 뜬다. 바꾸는 동작은 모두 숫자 확인(confirmCode)을 거친다.
// ─────────────────────────────────────────────────────────────
class LegacyRecordsPanel extends StatefulWidget {
  /// 툴바 맨 앞에 둘 위젯(회원 ↔ ID 없는 기록 전환)
  final Widget leading;
  const LegacyRecordsPanel({super.key, required this.leading});

  @override
  State<LegacyRecordsPanel> createState() => _LegacyRecordsPanelState();
}

class _LegacyRecordsPanelState extends State<LegacyRecordsPanel> with BoReloadable {
  static const int _pageSize = 50;

  final _search = TextEditingController();
  List<BoLegacy> _all = [];
  List<BoUser> _users = [];
  Map<String, List<BoUser>> _byNick = {};
  bool _loading = true;
  Object? _error;
  int _sortCol = 3 + kStages.length + 2; // 마지막 기록
  bool _asc = false;
  int _page = 0;
  final Set<String> _selected = {};
  bool _busy = false;

  List<BoCol> get _cols => [
        const BoCol('', width: 44),
        const BoCol('이름(기록에 적힌 닉네임)', flex: 3, minWidth: 200),
        const BoCol('구분', width: 120),
        const BoCol('기록', width: 70, numeric: true, sortable: true),
        for (final s in kStages) BoCol('${s.name} 최고', width: 100, numeric: true, sortable: true),
        const BoCol('같은 닉네임 회원', width: 150),
        const BoCol('마지막 기록', width: 100, numeric: true, sortable: true),
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
      final users = await BoData.users();
      final recs = await Future.wait([for (final s in kStages) BoData.src.allRecords(s.id)]);
      final groups = BoLegacy.group(recs.expand((l) => l), {for (final u in users) u.id});
      final byNick = <String, List<BoUser>>{};
      for (final u in users) {
        final n = BoLegacy.normNick(u.data['nickname'] as String?);
        if (n.isNotEmpty) (byNick[n] ??= []).add(u);
      }
      BoData.markLoaded();
      if (mounted) {
        setState(() {
          _users = users;
          _byNick = byNick;
          _all = groups;
          _selected.retainWhere((k) => groups.any((g) => g.key == k));
        });
      }
    } catch (e) {
      debugPrint('LegacyRecords: $e');
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<BoUser> _sameNick(BoLegacy g) => _byNick[BoLegacy.normNick(g.nickname)] ?? const [];

  num _sortKey(BoLegacy g) {
    final c = _sortCol;
    if (c == 3) return g.records.length;
    if (c >= 4 && c < 4 + kStages.length) return g.best(kStages[c - 4].id) ?? -1;
    return g.last?.millisecondsSinceEpoch ?? 0;
  }

  List<BoLegacy> get _filtered {
    final q = _search.text.trim().toLowerCase();
    final list = _all.where((g) => q.isEmpty || g.nickname.toLowerCase().contains(q) || g.oldUid.toLowerCase().contains(q)).toList();
    list.sort((a, b) {
      final c = _sortKey(a).compareTo(_sortKey(b));
      return _asc ? c : -c;
    });
    return list;
  }

  List<BoLegacy> get _picked => [for (final g in _all) if (_selected.contains(g.key)) g];

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    final pages = rows.isEmpty ? 1 : (rows.length + _pageSize - 1) ~/ _pageSize;
    final page = _page.clamp(0, pages - 1);
    final view = rows.skip(page * _pageSize).take(_pageSize).toList();
    final recCount = rows.fold<int>(0, (n, g) => n + g.records.length);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BoToolbar(
        filters: [
          widget.leading,
          BoSearchField(controller: _search, hint: '닉네임 · 옛 UID 검색', onChanged: (_) => setState(() => _page = 0)),
        ],
        trailing: [Text('${fmtNum(rows.length)}명 · 기록 ${fmtNum(recCount)}건', style: Bo.muted)],
      ),
      _bulkBar(view),
      Expanded(child: _body(view, rows.length, page)),
    ]);
  }

  Widget _bulkBar(List<BoLegacy> view) {
    final allOnPage = view.isNotEmpty && view.every((g) => _selected.contains(g.key));
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
          onChanged: _busy
              ? null
              : (v) => setState(() {
                    for (final g in view) {
                      v == true ? _selected.add(g.key) : _selected.remove(g.key);
                    }
                  }),
        ),
        Text(
          _busy
              ? '처리 중…'
              : _selected.isEmpty
                  ? '이 페이지 전체 선택'
                  : '${fmtNum(_selected.length)}명 선택 · 기록 ${fmtNum(_picked.fold<int>(0, (n, g) => n + g.records.length))}건',
          style: Bo.body.copyWith(fontWeight: _selected.isEmpty ? FontWeight.w400 : FontWeight.w700),
        ),
        if (_selected.isNotEmpty && !_busy) ...[
          TextButton(onPressed: () => setState(_selected.clear), child: const Text('선택 해제')),
          const Spacer(),
          Wrap(spacing: 6, children: [
            OutlinedButton.icon(
              onPressed: () => _link(_picked),
              icon: const Icon(Icons.link_rounded, size: 16),
              label: const Text('회원에 연결'),
            ),
            FilledButton.icon(
              onPressed: () => _delete(_picked),
              style: FilledButton.styleFrom(backgroundColor: Bo.red),
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text('기록 삭제'),
            ),
          ]),
        ] else
          const Spacer(),
      ]),
    );
  }

  Widget _body(List<BoLegacy> view, int total, int page) {
    if (_loading && _all.isEmpty) return const BoLoading();
    if (_error != null) return BoError(error: _error!, onRetry: reload);
    return BoTable(
      columns: _cols,
      scroll: true,
      rowCount: view.length,
      sortColumn: _sortCol,
      sortAsc: _asc,
      onSort: (c) => setState(() {
        if (_sortCol == c) {
          _asc = !_asc;
        } else {
          _sortCol = c;
          _asc = false;
        }
        _page = 0;
      }),
      onRowTap: (i) => _open(view[i]),
      empty: const BoEmpty('유저 ID 없는 랭킹 기록이 없습니다', icon: Icons.verified_outlined),
      footer: BoPager(total: total, page: page, pageSize: _pageSize, unit: '명', onPage: (p) => setState(() => _page = p)),
      cells: (i) {
        final g = view[i];
        final same = _sameNick(g);
        return [
          Checkbox(
            value: _selected.contains(g.key),
            visualDensity: VisualDensity.compact,
            onChanged: _busy ? null : (v) => setState(() => v == true ? _selected.add(g.key) : _selected.remove(g.key)),
          ),
          Row(children: [
            if (g.flag.isNotEmpty) ...[BoFlag(g.flag), const SizedBox(width: 6)],
            Flexible(child: Text(g.nickname, style: Bo.cellStrong, overflow: TextOverflow.ellipsis)),
          ]),
          g.oldUid.isEmpty
              ? BoTable.text('ID 없음', color: Bo.amber, tooltip: '옛 버전 기록 — userId 가 없다')
              : BoTable.text('탈퇴(문서 없음)', color: Bo.red, tooltip: '옛 uid ${g.oldUid}'),
          BoTable.text(fmtNum(g.records.length)),
          for (final s in kStages)
            BoTable.text(g.best(s.id) == null ? '-' : fmtSec(g.best(s.id), digits: 1), color: g.best(s.id) == null ? Bo.text3 : null),
          same.isEmpty
              ? BoTable.text('없음', color: Bo.text3)
              : BoTable.text('${same.length}명', color: Bo.accent, tooltip: same.map((u) => u.id).join('\n')),
          BoTable.text(fmtDate(g.last), style: Bo.muted),
        ];
      },
    );
  }

  // ── 한 사람 상세 ──
  Future<void> _open(BoLegacy g) async {
    final action = await showDialog<String>(
      context: context,
      builder: (_) => _LegacyDialog(group: g, candidates: _sameNick(g)),
    );
    if (action == null || !mounted) return;
    if (action == 'delete') return _delete([g]);
    if (action == 'pick') return _link([g]);
    if (action.startsWith('link:')) return _link([g], uid: action.substring(5));
  }

  String _names(List<BoLegacy> list) {
    final names = list.take(5).map((g) => g.nickname).join(', ');
    return list.length <= 5 ? names : '$names 외 ${list.length - 5}명';
  }

  Future<void> _link(List<BoLegacy> list, {String? uid}) async {
    if (list.isEmpty) return;
    final target = uid ??
        await showDialog<String>(
          context: context,
          builder: (_) => _MemberPicker(users: _users, initial: list.first.nickname),
        );
    if (target == null || target.isEmpty || !mounted) return;
    final member = _users.where((u) => u.id == target).firstOrNull;
    final recs = [for (final g in list) ...g.records];
    if (!await confirmCode(
      context,
      '회원에 기록 연결',
      '${_names(list)} — 랭킹 기록 ${fmtNum(recs.length)}건을\n${nickOf(member?.data)} ($target) 회원에게 붙입니다.\n\n'
          '그 회원의 존 최고 기록보다 좋은 기록이 있으면 프로필 최고 기록도 올라갑니다.',
      ok: '연결',
      okColor: Bo.accent,
    )) {
      return;
    }
    await _run('기록 ${fmtNum(recs.length)}건 연결', () => BoData.src.linkRecords(recs, target));
  }

  Future<void> _delete(List<BoLegacy> list) async {
    if (list.isEmpty) return;
    final recs = [for (final g in list) ...g.records];
    if (!await confirmCode(
      context,
      '랭킹 기록 삭제',
      '${_names(list)} (${list.length}명) — 랭킹 기록 ${fmtNum(recs.length)}건을 지웁니다.\n되돌릴 수 없습니다.',
      ok: '${fmtNum(recs.length)}건 삭제',
      okColor: Bo.red,
    )) {
      return;
    }
    await _run('기록 ${fmtNum(recs.length)}건 삭제', () => BoData.src.deleteRecords(recs));
  }

  Future<void> _run(String what, Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
      if (mounted) {
        setState(_selected.clear);
        toast(context, '$what 완료');
      }
    } catch (e) {
      if (mounted) toast(context, '$what 실패: $e', error: true);
    }
    if (mounted) setState(() => _busy = false);
    BoData.refreshAll();
  }
}

/// 한 사람 — 기록 목록 · 닉네임이 같은 회원 후보 · 연결/삭제. 고른 동작을 돌려준다('link:uid' · 'pick' · 'delete')
class _LegacyDialog extends StatelessWidget {
  final BoLegacy group;
  final List<BoUser> candidates;
  const _LegacyDialog({required this.group, required this.candidates});

  @override
  Widget build(BuildContext context) {
    final g = group;
    final recs = [...g.records]..sort((a, b) => b.time.compareTo(a.time));
    return AlertDialog(
      title: Row(children: [
        if (g.flag.isNotEmpty) ...[BoFlag(g.flag, height: 16), const SizedBox(width: 8)],
        Flexible(child: Text(g.nickname, overflow: TextOverflow.ellipsis)),
      ]),
      content: SizedBox(
        width: 560,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            g.oldUid.isEmpty ? '옛 버전 기록 — userId 가 없습니다' : '유저 문서가 없는 uid(탈퇴 등) — ${g.oldUid}',
            style: Bo.muted,
          ),
          const SizedBox(height: 14),
          Text('닉네임이 같은 회원', style: Bo.body.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (candidates.isEmpty)
            Text('없음 — [다른 회원 찾기]로 직접 고를 수 있습니다', style: Bo.muted)
          else
            for (final u in candidates)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Expanded(child: BoUserCell(uid: u.id, data: u.data)),
                  Text('가입 ${fmtDate(tsOf(u.data['createdAt']))}', style: Bo.muted),
                  const SizedBox(width: 10),
                  FilledButton(onPressed: () => Navigator.pop(context, 'link:${u.id}'), child: const Text('이 회원에 연결')),
                ]),
              ),
          const SizedBox(height: 14),
          Text('랭킹 기록 ${fmtNum(recs.length)}건', style: Bo.body.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView(shrinkWrap: true, children: [
              for (final r in recs)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    SizedBox(width: 150, child: BoStageCell(r.mapId)),
                    SizedBox(width: 90, child: Text(fmtSec(r.time, digits: 1), style: Bo.cellStrong)),
                    Text(fmtDateTime(r.at), style: Bo.muted),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context, 'pick'),
          icon: const Icon(Icons.person_search_outlined, size: 16),
          label: const Text('다른 회원 찾기'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, 'delete'),
          style: FilledButton.styleFrom(backgroundColor: Bo.red),
          icon: const Icon(Icons.delete_outline_rounded, size: 16),
          label: const Text('기록 삭제'),
        ),
      ],
    );
  }
}

/// 회원 고르기 — 닉네임 · UID 검색, 누르면 uid 를 돌려준다
class _MemberPicker extends StatefulWidget {
  final List<BoUser> users;
  final String initial;
  const _MemberPicker({required this.users, required this.initial});

  @override
  State<_MemberPicker> createState() => _MemberPickerState();
}

class _MemberPickerState extends State<_MemberPicker> {
  late final TextEditingController _q = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.text.trim().toLowerCase();
    final hits = q.isEmpty
        ? const <BoUser>[]
        : widget.users
            .where((u) => (u.data['nickname'] as String? ?? '').toLowerCase().contains(q) || u.id.toLowerCase().contains(q))
            .take(30)
            .toList();
    return AlertDialog(
      title: const Text('연결할 회원 고르기'),
      content: SizedBox(
        width: 480,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: _q,
            autofocus: true,
            decoration: const InputDecoration(hintText: '닉네임 · UID', isDense: true, prefixIcon: Icon(Icons.search, size: 18)),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: hits.isEmpty
                ? Padding(padding: const EdgeInsets.all(16), child: Text(q.isEmpty ? '검색어를 넣으세요' : '맞는 회원이 없습니다', style: Bo.muted))
                : ListView(shrinkWrap: true, children: [
                    for (final u in hits)
                      InkWell(
                        onTap: () => Navigator.pop(context, u.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(children: [
                            Expanded(child: BoUserCell(uid: u.id, data: u.data)),
                            Text(u.id.length > 10 ? '${u.id.substring(0, 10)}…' : u.id, style: Bo.mono),
                          ]),
                        ),
                      ),
                  ]),
          ),
        ]),
      ),
      actions: [OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('취소'))],
    );
  }
}
