import 'package:flutter/material.dart';

import '../promotions.dart';
import 'bo_common.dart';

// ─────────────────────────────────────────────────────────────
// 이벤트(프로모션) 관리 — promos/{id} 문서를 만들고 켜고 끈다. **앱 업데이트 없이 바로 반영**된다.
//   앱은 이 목록 + 코드에 박힌 기본 이벤트(promotions.dart 의 builtIn)를 합쳐서 보여 준다.
//   같은 id 면 여기(서버) 값이 이긴다 — 기본 이벤트의 보상·기간을 여기서 덮어쓸 수 있다.
// 값을 바꾸는 동작은 모두 숫자 확인(confirmCode)을 거친다.
// ─────────────────────────────────────────────────────────────
class PromoPage extends StatefulWidget {
  const PromoPage({super.key});

  @override
  State<PromoPage> createState() => _PromoPageState();
}

const Map<PromoKind, String> kPromoKindNames = {
  PromoKind.welcome: '환영(1회)',
  PromoKind.bonus: '기간 보상(1회)',
  PromoKind.code: '코드 입력',
  PromoKind.share: '자랑하기(반복)',
};

class _PromoPageState extends State<PromoPage> with BoReloadable {
  List<BoPromo> _rows = [];
  bool _loading = true;
  Object? _error;

  @override
  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await BoData.src.promos();
      // 서버에 없는 기본 이벤트도 같이 보여 준다(앱에는 이미 떠 있다)
      final ids = rows.map((e) => e.promo.id).toSet();
      final merged = [
        ...rows,
        for (final p in Promotions.builtIn)
          if (!ids.contains(p.id)) BoPromo(p, -1), // -1 = 서버에 문서 없음(수령 수 모름)
      ];
      merged.sort((a, b) => a.promo.kind.index.compareTo(b.promo.kind.index));
      if (mounted) setState(() => _rows = merged);
      BoData.markLoaded();
    } catch (e) {
      debugPrint('Promos: $e');
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(Promotion? base) async {
    final p = await showDialog<Promotion>(context: context, builder: (_) => PromoDialog(base: base));
    if (p == null || !mounted) return;
    if (!await confirmCode(
      context,
      base == null ? '이벤트 추가 확인' : '이벤트 수정 확인',
      '${p.id} · ${kPromoKindNames[p.kind]}\n\n'
          '보상 ${p.coins > 0 ? '코인 ${fmtNum(p.coins)}' : ''}${p.items.isEmpty ? '' : ' ${p.items.join(', ')}'}\n'
          '${p.enabled ? '켠 상태로' : '끈 상태로'} 저장합니다 — 앱에 바로 반영됩니다.',
      ok: '저장',
    )) {
      return;
    }
    try {
      await BoData.src.savePromo(p);
      if (mounted) toast(context, '저장했습니다');
      await reload();
    } catch (e) {
      if (mounted) toast(context, '저장 실패: $e', error: true);
    }
  }

  Future<void> _toggle(BoPromo row) async {
    final p = row.promo;
    final next = Promotion(
      id: p.id,
      kind: p.kind,
      enabled: !p.enabled,
      startAt: p.startAt,
      endAt: p.endAt,
      coins: p.coins,
      items: p.items,
      code: p.code,
      cooldownHours: p.cooldownHours,
      title: p.title,
      desc: p.desc,
    );
    if (!await confirmCode(context, next.enabled ? '이벤트 켜기' : '이벤트 끄기',
        '${p.id}\n\n${next.enabled ? '지금부터 앱에 보입니다.' : '앱에서 사라집니다(받은 기록은 남습니다).'}',
        ok: next.enabled ? '켜기' : '끄기')) {
      return;
    }
    try {
      await BoData.src.savePromo(next);
      if (mounted) toast(context, next.enabled ? '켰습니다' : '껐습니다');
      await reload();
    } catch (e) {
      if (mounted) toast(context, '실패: $e', error: true);
    }
  }

  Future<void> _delete(BoPromo row) async {
    if (!await confirmCode(context, '이벤트 삭제', '${row.promo.id}\n\n문서를 지웁니다. 되돌릴 수 없습니다.', ok: '삭제')) return;
    try {
      await BoData.src.deletePromo(row.promo.id);
      if (mounted) toast(context, '삭제했습니다');
      await reload();
    } catch (e) {
      if (mounted) toast(context, '삭제 실패: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = _rows.where((r) => r.promo.isLive).length;
    return BoPage(
      topBar: BoTopBar(
        title: '이벤트',
        breadcrumb: const ['운영'],
        subtitle: '진행 중 $live개 · 전체 ${_rows.length}개 · 저장하면 앱에 바로 반영',
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: BoCard(
                fill: true,
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BoToolbar(
                      filters: [
                        Text('코드 이벤트는 코드를 SNS·커뮤니티에 뿌리고, 유저가 앱에서 입력해 받습니다.', style: Bo.muted),
                      ],
                      trailing: [
                        FilledButton.icon(
                          onPressed: () => _edit(null),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('새 이벤트'),
                        ),
                      ],
                    ),
                    if (_error != null) BoError(error: _error!, onRetry: reload),
                    Expanded(
                      child: _loading && _rows.isEmpty
                          ? const BoLoading()
                          : BoTable(
                              scroll: true,
                              columns: const [
                                BoCol('상태', width: 76),
                                BoCol('id', flex: 2, minWidth: 130),
                                BoCol('종류', width: 110),
                                BoCol('제목(ko)', flex: 3, minWidth: 150),
                                BoCol('보상', flex: 2, minWidth: 140),
                                BoCol('코드', width: 100),
                                BoCol('기간', width: 170),
                                BoCol('받은 수', width: 80, numeric: true),
                                BoCol('', width: 130),
                              ],
                              rowCount: _rows.length,
                              cells: (i) => _row(_rows[i]),
                              empty: const BoEmpty('이벤트가 없습니다 — [새 이벤트] 로 추가하세요',
                                  icon: Icons.celebration_outlined),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _row(BoPromo r) {
    final p = r.promo;
    final reward = [
      if (p.coins > 0) '코인 ${fmtNum(p.coins)}',
      for (final id in p.items) itemName(id),
    ].join(' · ');
    return [
      BoBadge(p.isLive ? '진행 중' : (p.enabled ? '기간 밖' : '꺼짐'),
          color: p.isLive ? Bo.green : (p.enabled ? Bo.amber : Bo.grey), dense: true),
      BoTable.text(p.id, style: Bo.mono),
      BoTable.text(kPromoKindNames[p.kind] ?? p.kind.name),
      BoTable.text(p.titleOf('ko'), style: Bo.cellStrong),
      BoTable.text(reward.isEmpty ? '-' : reward),
      BoTable.text(p.code.isEmpty ? '-' : p.code, style: Bo.mono),
      BoTable.text(_period(p)),
      BoTable.text(r.claims < 0 ? '-' : fmtNum(r.claims), style: Bo.cell),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        IconButton(
          tooltip: p.enabled ? '끄기' : '켜기',
          onPressed: () => _toggle(r),
          icon: Icon(p.enabled ? Icons.toggle_on_rounded : Icons.toggle_off_outlined,
              size: 20, color: p.enabled ? Bo.green : Bo.text3),
        ),
        IconButton(tooltip: '수정', onPressed: () => _edit(p), icon: const Icon(Icons.edit_outlined, size: 16)),
        IconButton(
          tooltip: r.claims < 0 ? '서버에 없는 기본 이벤트입니다' : '삭제',
          onPressed: r.claims < 0 ? null : () => _delete(r),
          icon: const Icon(Icons.delete_outline_rounded, size: 16),
        ),
      ]),
    ];
  }

  String _period(Promotion p) {
    if (p.startAt == null && p.endAt == null) return '제한 없음';
    return '${p.startAt == null ? '~' : fmtDate(p.startAt)} → ${p.endAt == null ? '~' : fmtDate(p.endAt)}';
  }
}

/// 이벤트 추가·수정 — 저장하면 promos/{id} 문서가 된다
class PromoDialog extends StatefulWidget {
  final Promotion? base;
  const PromoDialog({super.key, this.base});

  @override
  State<PromoDialog> createState() => _PromoDialogState();
}

class _PromoDialogState extends State<PromoDialog> {
  late final _id = TextEditingController(text: widget.base?.id ?? '');
  late final _coins = TextEditingController(text: '${widget.base?.coins ?? 0}');
  late final _items = TextEditingController(text: widget.base?.items.join(', ') ?? '');
  late final _code = TextEditingController(text: widget.base?.code ?? '');
  late final _cooldown = TextEditingController(text: '${widget.base?.cooldownHours ?? 0}');
  late final _titleKo = TextEditingController(text: widget.base?.title['ko'] ?? '');
  late final _titleEn = TextEditingController(text: widget.base?.title['en'] ?? '');
  late final _descKo = TextEditingController(text: widget.base?.desc['ko'] ?? '');
  late final _descEn = TextEditingController(text: widget.base?.desc['en'] ?? '');
  late PromoKind _kind = widget.base?.kind ?? PromoKind.bonus;
  late bool _enabled = widget.base?.enabled ?? true;
  late DateTime? _start = widget.base?.startAt;
  late DateTime? _end = widget.base?.endAt;

  @override
  void dispose() {
    for (final c in [_id, _coins, _items, _code, _cooldown, _titleKo, _titleEn, _descKo, _descEn]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _id.text.trim().isNotEmpty &&
      _titleKo.text.trim().isNotEmpty &&
      (_kind != PromoKind.code || _code.text.trim().isNotEmpty) &&
      ((int.tryParse(_coins.text.trim()) ?? 0) > 0 || _items.text.trim().isNotEmpty);

  Promotion _build() => Promotion(
        id: _id.text.trim(),
        kind: _kind,
        enabled: _enabled,
        startAt: _start,
        endAt: _end,
        coins: int.tryParse(_coins.text.trim()) ?? 0,
        items: _items.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        code: _code.text.trim().toUpperCase(),
        cooldownHours: int.tryParse(_cooldown.text.trim()) ?? 0,
        title: {'ko': _titleKo.text.trim(), if (_titleEn.text.trim().isNotEmpty) 'en': _titleEn.text.trim()},
        desc: {
          if (_descKo.text.trim().isNotEmpty) 'ko': _descKo.text.trim(),
          if (_descEn.text.trim().isNotEmpty) 'en': _descEn.text.trim(),
        },
      );

  Future<void> _pick(bool start) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: (start ? _start : _end) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (d == null) return;
    setState(() {
      // 시작은 그날 0시, 종료는 그날 끝
      if (start) {
        _start = DateTime(d.year, d.month, d.day);
      } else {
        _end = DateTime(d.year, d.month, d.day, 23, 59, 59);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.base == null ? '새 이벤트' : '이벤트 수정'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _id,
                    enabled: widget.base == null,
                    decoration: const InputDecoration(labelText: 'id (영문·숫자·_)', hintText: '예: autumn_2026'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<PromoKind>(
                    initialValue: _kind,
                    decoration: const InputDecoration(labelText: '종류'),
                    items: [
                      for (final k in PromoKind.values) DropdownMenuItem(value: k, child: Text(kPromoKindNames[k]!)),
                    ],
                    onChanged: (v) => setState(() => _kind = v ?? _kind),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _coins,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '코인'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _items,
                    decoration: const InputDecoration(labelText: '아이템 id (쉼표)', hintText: 'skin_cloud, char_frost_cyan'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: '코드',
                      hintText: _kind == PromoKind.code ? '예: ZONBER' : '코드 이벤트일 때만',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _cooldown,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '다시 받기(시간)', hintText: '0 = 평생 한 번'),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => _pick(true), child: Text('시작 ${_start == null ? '없음' : fmtDate(_start)}'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => _pick(false), child: Text('종료 ${_end == null ? '없음' : fmtDate(_end)}'))),
                const SizedBox(width: 8),
                TextButton(onPressed: () => setState(() => _start = _end = null), child: const Text('기간 지우기')),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: _titleKo,
                decoration: const InputDecoration(labelText: '제목 (한국어)', hintText: '예: 가을 맞이 선물'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              TextField(controller: _titleEn, decoration: const InputDecoration(labelText: '제목 (영어, 없으면 한국어로 보임)')),
              const SizedBox(height: 8),
              TextField(controller: _descKo, decoration: const InputDecoration(labelText: '설명 (한국어)')),
              const SizedBox(height: 8),
              TextField(controller: _descEn, decoration: const InputDecoration(labelText: '설명 (영어)')),
              const SizedBox(height: 10),
              SwitchListTile(
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                title: const Text('켜기'),
                subtitle: Text(_enabled ? '저장하면 앱에 바로 보입니다' : '꺼 둔 채로 저장합니다', style: Bo.caption),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(onPressed: _valid ? () => Navigator.pop(context, _build()) : null, child: const Text('저장')),
      ],
    );
  }
}
