import 'package:flutter/material.dart';

import '../promotions.dart';
import 'bo_common.dart';
import 'bo_reward_editor.dart';

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
  PromoKind.welcome: '환영 선물',
  PromoKind.bonus: '보상 이벤트',
  PromoKind.code: '코드 안내',
  PromoKind.share: 'SNS 공유',
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
      '${p.id} · ${promoTypeLabel(p)} · ${promoPeriod(p.startAt, p.endAt)}\n\n'
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
                        Text("'코드 안내' 이벤트는 앱에 안내 카드만 띄웁니다 — 코드와 보상은 [이벤트 코드] 메뉴에서 만듭니다.", style: Bo.muted),
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
                                BoCol('종류', width: 150),
                                BoCol('제목(ko)', flex: 3, minWidth: 150),
                                BoCol('보상', flex: 2, minWidth: 140),
                                BoCol('기간', width: 240),
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
      BoTable.text(promoTypeLabel(p)),
      BoTable.text(p.titleOf('ko'), style: Bo.cellStrong),
      BoTable.text(reward.isEmpty ? '-' : reward),
      BoTable.text(promoPeriod(p.startAt, p.endAt)),
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
}

/// 반복 — 0 = 한 번, 24 = 매일, 168 = 매주
const List<(int, String)> kRepeatOptions = [(0, '한 번'), (24, '매일'), (168, '매주')];

String repeatLabel(int hours) {
  for (final (h, label) in kRepeatOptions) {
    if (h == hours) return label;
  }
  return '$hours시간마다';
}

/// 표·확인창에 쓰는 종류 한 줄 — "보상 이벤트 · 매주"
String promoTypeLabel(Promotion p) => switch (p.kind) {
      PromoKind.welcome || PromoKind.code => kPromoKindNames[p.kind]!,
      _ => '${kPromoKindNames[p.kind]} · ${repeatLabel(p.cooldownHours)}',
    };

String promoPeriod(DateTime? start, DateTime? end) {
  if (start == null && end == null) return '상시';
  final days = (start != null && end != null) ? ' (${end.difference(start).inDays + 1}일)' : '';
  return '${start == null ? '지금' : fmtDate(start)} ~ ${end == null ? '계속' : fmtDate(end)}$days';
}

/// 이벤트 추가·수정 — ① 종류 ② 보상 ③ 기간 ④ 문구. 저장하면 promos/{id} 문서가 된다
class PromoDialog extends StatefulWidget {
  final Promotion? base;
  const PromoDialog({super.key, this.base});

  @override
  State<PromoDialog> createState() => _PromoDialogState();
}

class _PromoDialogState extends State<PromoDialog> {
  static const _kindHelp = {
    PromoKind.bonus: '들어오면 받는 선물 — 한 번 또는 매일·매주',
    PromoKind.welcome: '처음 온 유저가 한 번 받는 선물',
    PromoKind.share: 'SNS로 기록을 공유하면 받는 선물',
    PromoKind.code: '코드 입력 안내 카드만 — 보상은 [이벤트 코드]에서',
  };
  static const _langs = ['ko', 'en', 'ja', 'zh'];
  static final _idFormat = RegExp(r'^[a-z0-9_]{3,40}$');

  bool get _editing => widget.base != null;
  late PromoKind _kind = widget.base?.kind ?? PromoKind.bonus;
  late final _coins = TextEditingController(text: '${widget.base?.coins ?? 100}');
  late final List<String> _items = [...?widget.base?.items];
  late int _repeat = widget.base?.cooldownHours ?? 0;
  late bool _always = widget.base == null || (widget.base!.startAt == null && widget.base!.endAt == null);
  late DateTime? _start = widget.base?.startAt;
  late DateTime? _end = widget.base?.endAt;
  late bool _enabled = widget.base?.enabled ?? true;
  late final _title = {for (final l in _langs) l: TextEditingController(text: widget.base?.title[l] ?? '')};
  late final _desc = {for (final l in _langs) l: TextEditingController(text: widget.base?.desc[l] ?? '')};
  late final _id = TextEditingController();

  @override
  void dispose() {
    for (final c in [_coins, _id, ..._title.values, ..._desc.values]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hasReward => _kind != PromoKind.code;
  bool get _hasRepeat => _kind == PromoKind.bonus || _kind == PromoKind.share;
  int get _coinsN => int.tryParse(_coins.text.trim()) ?? 0;

  /// 새 이벤트 id — 적지 않으면 종류 + 시작일(없으면 오늘)
  String get _autoId {
    final d = (_always ? null : _start) ?? DateTime.now();
    return '${_kind.name}_${d.year}${two(d.month)}${two(d.day)}';
  }

  String get _idOut => _editing ? widget.base!.id : (_id.text.trim().isEmpty ? _autoId : _id.text.trim());

  List<String> get _problems => [
        if (_hasReward && _coinsN <= 0 && _items.isEmpty) '보상(코인 또는 아이템)을 정하세요',
        if (!_always && _start == null && _end == null) '기간을 고르거나 [상시]로 두세요',
        if (!_always && _start != null && _end != null && !_end!.isAfter(_start!)) '종료일이 시작일보다 빠릅니다',
        if (_title['ko']!.text.trim().isEmpty) '제목(한국어)을 적으세요',
        if (_title['en']!.text.trim().isEmpty) '제목(영어)을 적으세요 — 다른 나라 유저는 영어로 봅니다',
        if (!_editing && !_idFormat.hasMatch(_idOut)) 'id 는 영문 소문자·숫자·_ 3~40자',
      ];

  Promotion _build() => Promotion(
        id: _idOut,
        kind: _kind,
        enabled: _enabled,
        startAt: _always ? null : _start,
        endAt: _always ? null : _end,
        coins: _hasReward ? _coinsN : 0,
        items: _hasReward ? [..._items] : const [],
        cooldownHours: _hasRepeat ? _repeat : 0,
        title: {for (final l in _langs) if (_title[l]!.text.trim().isNotEmpty) l: _title[l]!.text.trim()},
        desc: {for (final l in _langs) if (_desc[l]!.text.trim().isNotEmpty) l: _desc[l]!.text.trim()},
      );

  void _setKind(PromoKind k) => setState(() {
        _kind = k;
        if (k == PromoKind.share && _repeat == 0) _repeat = 24; // 공유는 보통 매일
      });

  Future<void> _pick(bool start) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: (start ? _start : _end) ?? (start ? now : (_start ?? now).add(const Duration(days: 7))),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (d == null) return;
    setState(() {
      // 시작은 그날 0시, 종료는 그날 끝(관리자 PC 시간대)
      if (start) {
        _start = DateTime(d.year, d.month, d.day);
      } else {
        _end = DateTime(d.year, d.month, d.day, 23, 59, 59);
      }
    });
  }

  Widget _kindCard(PromoKind k) {
    final on = _kind == k;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _setKind(k),
      child: Container(
        width: 270,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: on ? Bo.accentSoft : Bo.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? Bo.accent : Bo.line, width: on ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 18, color: on ? Bo.accent : Bo.text3),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(kPromoKindNames[k]!, style: Bo.body.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(_kindHelp[k]!, style: Bo.caption),
            ]),
          ),
        ]),
      ),
    );
  }

  /// 한 언어 = 제목 + 설명 한 줄
  Widget _text(String lang, String label, {bool required = false}) => Row(children: [
        SizedBox(width: 56, child: Text(label, style: Bo.muted)),
        Expanded(
          flex: 2,
          child: TextField(
            controller: _title[lang],
            decoration: InputDecoration(hintText: required ? '제목 (필수)' : '제목', isDense: true),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextField(
            controller: _desc[lang],
            maxLength: lang == 'en' ? 40 : 24,
            decoration: const InputDecoration(hintText: '설명 한 줄 (예: 코인 300 + 구름 스킨)', isDense: true, counterText: ''),
          ),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final problems = _problems;
    final p = _build();
    final reward = [if (p.coins > 0) '코인 ${fmtNum(p.coins)}', for (final id in p.items) itemName(id)].join(' + ');
    var step = 0;
    return AlertDialog(
      title: Text(_editing ? '이벤트 수정 — ${widget.base!.id}' : '새 이벤트'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ① 종류
              BoStep(++step, '종류'),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final k in _kindHelp.keys) _kindCard(k)]),
              if (_hasRepeat) ...[
                const SizedBox(height: 10),
                Row(children: [
                  SizedBox(width: 72, child: Text('받는 횟수', style: Bo.muted)),
                  BoSegmented<int>(
                    options: kRepeatOptions,
                    value: kRepeatOptions.any((o) => o.$1 == _repeat) ? _repeat : 0,
                    onChanged: (v) => setState(() => _repeat = v),
                  ),
                ]),
              ],

              // ② 보상
              if (_hasReward) ...[
                BoStep(++step, '보상'),
                BoRewardEditor(coins: _coins, items: _items, onChanged: () => setState(() {})),
              ],

              // ③ 기간
              BoStep(++step, '기간'),
              Row(children: [
                BoSegmented<bool>(
                  options: const [(true, '상시'), (false, '기간 지정')],
                  value: _always,
                  onChanged: (v) => setState(() => _always = v),
                ),
                if (!_always) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pick(true),
                      icon: const Icon(Icons.event_rounded, size: 16),
                      label: Text(_start == null ? '시작일' : fmtDate(_start)),
                    ),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('~')),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pick(false),
                      icon: const Icon(Icons.event_rounded, size: 16),
                      label: Text(_end == null ? '종료일' : fmtDate(_end)),
                    ),
                  ),
                ],
              ]),

              // ④ 문구
              BoStep(++step, '앱에 보이는 문구', hint: '설명은 앱에서 한 줄 — 짧게'),
              _text('ko', '한국어', required: true),
              const SizedBox(height: 6),
              _text('en', '영어', required: true),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 6),
                  initiallyExpanded: (widget.base?.title['ja'] ?? widget.base?.title['zh']) != null,
                  title: Text('일본어 · 중국어 (선택 — 비우면 영어로 보임)', style: Bo.muted),
                  children: [_text('ja', '일본어'), const SizedBox(height: 6), _text('zh', '중국어')],
                ),
              ),

              // 요약 — 저장될 내용 그대로
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Bo.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: Bo.line)),
                child: problems.isNotEmpty
                    ? Text(problems.map((e) => '• $e').join('\n'), style: Bo.body.copyWith(color: Bo.red, height: 1.5))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(promoTypeLabel(p), style: Bo.body.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(_hasReward ? '보상  $reward' : '보상  코드마다 다름 ([이벤트 코드] 메뉴)', style: Bo.body),
                        Text('기간  ${promoPeriod(p.startAt, p.endAt)}', style: Bo.body),
                        Text('id  ${p.id}', style: Bo.caption),
                      ]),
              ),
              const SizedBox(height: 4),
              Row(children: [
                Checkbox(value: _enabled, onChanged: (v) => setState(() => _enabled = v ?? true)),
                Text('저장하면 바로 켜기', style: Bo.body),
                const Spacer(),
                if (!_editing)
                  SizedBox(
                    width: 210,
                    child: TextField(
                      controller: _id,
                      style: Bo.mono,
                      decoration: InputDecoration(hintText: 'id (선택) · $_autoId', isDense: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(onPressed: problems.isEmpty ? () => Navigator.pop(context, p) : null, child: const Text('저장')),
      ],
    );
  }
}
