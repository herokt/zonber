import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../promotions.dart';
import 'bo_common.dart';
import 'bo_reward_editor.dart';

// ─────────────────────────────────────────────────────────────
// 이벤트 코드 관리 — promo_codes/{코드}. 코드마다 보상·캠페인·사용 한도·기간이 따로 있다.
//   · 만들기: 직접 입력(ZONBER) 또는 자동 생성(접두어 + 무작위, 여러 개 한 번에 — 1인 1코드 배포용)
//   · 검증: [코드 확인] 으로 유저가 넣을 코드를 그대로 넣어 보면 상태·보상을 앱과 같은 기준으로 보여 준다
//   · 사용한 사람: users/{uid}/codes/{코드} (collection group) — 누르면 유저 상세
// 앱의 사용 처리(1인 1회·한도·기간)는 firestore.rules 가 서버에서 검사한다. 규칙 시험: node scripts/test_rules.mjs
// 값을 바꾸는 동작은 모두 숫자 확인(confirmCode)을 거친다.
// ─────────────────────────────────────────────────────────────
class PromoCodesPage extends StatefulWidget {
  const PromoCodesPage({super.key});

  @override
  State<PromoCodesPage> createState() => _PromoCodesPageState();
}

enum _Filter { all, open, closed }

const Map<PromoCodeStatus, String> kCodeStatusNames = {
  PromoCodeStatus.open: '사용 가능',
  PromoCodeStatus.disabled: '꺼짐',
  PromoCodeStatus.notStarted: '시작 전',
  PromoCodeStatus.expired: '기간 끝',
  PromoCodeStatus.exhausted: '한도 소진',
};

Color codeStatusColor(PromoCodeStatus s) => switch (s) {
      PromoCodeStatus.open => Bo.green,
      PromoCodeStatus.notStarted => Bo.blue,
      PromoCodeStatus.exhausted => Bo.amber,
      PromoCodeStatus.expired => Bo.grey,
      PromoCodeStatus.disabled => Bo.grey,
    };

/// 보상 한 줄 — "코인 500 · 구름 스킨"
String codeReward(PromoCode c) => [
      if (c.coins > 0) '코인 ${fmtNum(c.coins)}',
      for (final id in c.items) itemName(id),
    ].join(' · ');

String codeUsage(PromoCode c) => c.maxUses > 0 ? '${fmtNum(c.uses)} / ${fmtNum(c.maxUses)}' : '${fmtNum(c.uses)} / ∞';

String codePeriod(PromoCode c) {
  if (c.startAt == null && c.endAt == null) return '제한 없음';
  return '${c.startAt == null ? '~' : fmtDate(c.startAt)} → ${c.endAt == null ? '~' : fmtDate(c.endAt)}';
}

class _PromoCodesPageState extends State<PromoCodesPage> with BoReloadable {
  List<PromoCode> _all = [];
  bool _loading = true;
  Object? _error;
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;

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
      final list = await BoData.src.promoCodes();
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      if (mounted) setState(() => _all = list);
      BoData.markLoaded();
    } catch (e) {
      debugPrint('PromoCodes: $e');
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PromoCode> get _rows {
    final q = PromoCodes.normalize(_search.text);
    final ql = _search.text.trim().toLowerCase();
    return _all.where((c) {
      final open = c.status() == PromoCodeStatus.open;
      if (_filter == _Filter.open && !open) return false;
      if (_filter == _Filter.closed && open) return false;
      if (ql.isEmpty) return true;
      return c.code.contains(q) || c.campaign.toLowerCase().contains(ql) || c.note.toLowerCase().contains(ql);
    }).toList();
  }

  Future<void> _create() async {
    final draft = await showDialog<_CodeDraft>(context: context, builder: (_) => const PromoCodeDialog());
    if (draft == null || !mounted) return;
    final many = draft.codes.length > 1 || draft.auto;
    if (!await confirmCode(
      context,
      '코드 만들기 확인',
      '${many ? '코드 ${draft.codes.length}개 (자동 생성)' : draft.codes.single}\n'
          '캠페인 ${draft.template.campaign}\n\n'
          '보상 ${codeReward(draft.template)} · 1인 1회${draft.template.maxUses > 0 ? ' · 선착순 ${fmtNum(draft.template.maxUses)}명' : ''}\n'
          '${draft.template.enabled ? '저장하면 바로 쓸 수 있습니다.' : '꺼 둔 채로 만듭니다.'}',
      ok: '만들기',
      okColor: Bo.accent,
    )) {
      return;
    }
    final made = <String>[];
    final dup = <String>[];
    try {
      for (final code in draft.codes) {
        var c = code;
        var ok = await BoData.src.createPromoCode(draft.template.withCode(c));
        // 자동 생성이 우연히 겹치면 새로 뽑는다(직접 입력은 그대로 실패)
        for (var retry = 0; !ok && draft.auto && retry < 5; retry++) {
          c = PromoCodes.generate(prefix: draft.prefix, length: draft.length);
          ok = await BoData.src.createPromoCode(draft.template.withCode(c));
        }
        (ok ? made : dup).add(c);
      }
    } catch (e) {
      if (mounted) toast(context, '만들기 실패: $e', error: true);
    }
    await reload();
    if (!mounted) return;
    if (made.isEmpty) {
      toast(context, dup.isEmpty ? '만들지 못했습니다' : '이미 있는 코드(또는 유저 친구 코드)입니다: ${dup.join(', ')}', error: true);
      return;
    }
    await showDialog<void>(context: context, builder: (_) => _CreatedDialog(made: made, dup: dup, template: draft.template));
  }

  Future<void> _edit(PromoCode c) async {
    final draft = await showDialog<_CodeDraft>(context: context, builder: (_) => PromoCodeDialog(base: c));
    if (draft == null || !mounted) return;
    final next = draft.template.withCode(c.code);
    if (!await confirmCode(
      context,
      '코드 수정 확인',
      '${c.code}\n\n보상 ${codeReward(c)} → ${codeReward(next)}\n'
          '${c.uses > 0 ? '이미 ${fmtNum(c.uses)}명이 썼습니다 — 바뀐 보상은 앞으로 쓰는 사람부터 받습니다.' : ''}',
      ok: '저장',
      okColor: Bo.accent,
    )) {
      return;
    }
    try {
      await BoData.src.updatePromoCode(next);
      if (mounted) toast(context, '저장했습니다');
      await reload();
    } catch (e) {
      if (mounted) toast(context, '저장 실패: $e', error: true);
    }
  }

  Future<void> _toggle(PromoCode c) async {
    final next = c.copyWith(enabled: !c.enabled);
    if (!await confirmCode(context, next.enabled ? '코드 켜기' : '코드 끄기',
        '${c.code}\n\n${next.enabled ? '지금부터 다시 쓸 수 있습니다.' : '더 쓸 수 없습니다(이미 받은 보상은 그대로).'}',
        ok: next.enabled ? '켜기' : '끄기')) {
      return;
    }
    try {
      await BoData.src.updatePromoCode(next);
      if (mounted) toast(context, next.enabled ? '켰습니다' : '껐습니다');
      await reload();
    } catch (e) {
      if (mounted) toast(context, '실패: $e', error: true);
    }
  }

  Future<void> _delete(PromoCode c) async {
    if (!await confirmCode(
        context,
        '코드 삭제',
        '${c.code}\n\n코드를 지웁니다. 되돌릴 수 없습니다.\n'
            '${c.uses > 0 ? '사용 기록(${fmtNum(c.uses)}명)은 유저 쪽에 남습니다. 멈추기만 하려면 [끄기]를 쓰세요.' : ''}',
        ok: '삭제')) {
      return;
    }
    try {
      await BoData.src.deletePromoCode(c.code);
      if (mounted) toast(context, '삭제했습니다');
      await reload();
    } catch (e) {
      if (mounted) toast(context, '삭제 실패: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = _all.where((c) => c.status() == PromoCodeStatus.open).length;
    final uses = _all.fold<int>(0, (a, c) => a + c.uses);
    final rows = _rows;
    return BoPage(
      topBar: BoTopBar(
        title: '이벤트 코드',
        breadcrumb: const ['운영'],
        subtitle: '코드 ${_all.length}개 · 사용 가능 $open개 · 총 사용 ${fmtNum(uses)}회 · 1인 1회는 서버 규칙이 막습니다',
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
                    hint: '코드 · 캠페인 · 메모',
                    width: 240,
                    onChanged: (_) => setState(() {}),
                  ),
                  BoSegmented<_Filter>(
                    options: const [(_Filter.all, '전체'), (_Filter.open, '사용 가능'), (_Filter.closed, '멈춤·끝')],
                    value: _filter,
                    onChanged: (v) => setState(() => _filter = v),
                  ),
                ],
                trailing: [
                  OutlinedButton.icon(
                    onPressed: () => showDialog<void>(context: context, builder: (_) => const _VerifyDialog()),
                    icon: const Icon(Icons.fact_check_outlined, size: 16),
                    label: const Text('코드 확인'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('코드 만들기'),
                  ),
                ],
              ),
              if (_error != null) BoError(error: _error!, onRetry: reload),
              Expanded(
                child: _loading && _all.isEmpty
                    ? const BoLoading()
                    : BoTable(
                        scroll: true,
                        columns: const [
                          BoCol('상태', width: 84),
                          BoCol('코드', flex: 2, minWidth: 150),
                          BoCol('캠페인', flex: 2, minWidth: 120),
                          BoCol('보상', flex: 3, minWidth: 170),
                          BoCol('사용 / 한도', width: 110, numeric: true),
                          BoCol('기간', width: 170),
                          BoCol('메모', flex: 2, minWidth: 110),
                          BoCol('', width: 170),
                        ],
                        rowCount: rows.length,
                        cells: (i) => _row(rows[i]),
                        empty: const BoEmpty('코드가 없습니다 — [코드 만들기] 로 추가하세요', icon: Icons.confirmation_number_outlined),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _row(PromoCode c) {
    final st = c.status();
    return [
      BoBadge(kCodeStatusNames[st]!, color: codeStatusColor(st), dense: true),
      Row(children: [
        Flexible(child: SelectableText(c.code, style: Bo.mono.copyWith(color: Bo.text, fontWeight: FontWeight.w600), maxLines: 1)),
        IconButton(
          tooltip: '복사',
          visualDensity: VisualDensity.compact,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: c.code));
            toast(context, '${c.code} 복사했습니다');
          },
          icon: Icon(Icons.copy_rounded, size: 14, color: Bo.text3),
        ),
      ]),
      BoTable.text(c.campaign.isEmpty ? '-' : c.campaign),
      BoTable.text(c.isEmptyReward ? '(보상 없음)' : codeReward(c), style: Bo.cellStrong, color: c.isEmptyReward ? Bo.red : null),
      BoTable.text(codeUsage(c), style: Bo.cell),
      BoTable.text(codePeriod(c)),
      BoTable.text(c.note.isEmpty ? '-' : c.note, color: Bo.text2, tooltip: c.note),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        IconButton(
          tooltip: '사용한 사람',
          onPressed: c.uses == 0 ? null : () => showDialog<void>(context: context, builder: (_) => _UsesDialog(code: c)),
          icon: const Icon(Icons.group_outlined, size: 16),
        ),
        IconButton(
          tooltip: c.enabled ? '끄기' : '켜기',
          onPressed: () => _toggle(c),
          icon: Icon(c.enabled ? Icons.toggle_on_rounded : Icons.toggle_off_outlined,
              size: 20, color: c.enabled ? Bo.green : Bo.text3),
        ),
        IconButton(tooltip: '수정', onPressed: () => _edit(c), icon: const Icon(Icons.edit_outlined, size: 16)),
        IconButton(tooltip: '삭제', onPressed: () => _delete(c), icon: const Icon(Icons.delete_outline_rounded, size: 16)),
      ]),
    ];
  }
}

// ── 만들기·수정 ──────────────────────────────────────────────

/// 대화상자 결과 — 만들 코드들 + 공통 설정(보상·캠페인·한도·기간)
class _CodeDraft {
  final List<String> codes;
  final PromoCode template;
  final bool auto;
  final String prefix;
  final int length;
  const _CodeDraft(this.codes, this.template, {this.auto = false, this.prefix = '', this.length = 6});
}

extension on PromoCode {
  PromoCode withCode(String c) => PromoCode(
      code: c,
      campaign: campaign,
      note: note,
      coins: coins,
      items: items,
      enabled: enabled,
      startAt: startAt,
      endAt: endAt,
      maxUses: maxUses,
      uses: uses,
      createdAt: createdAt);
}

/// 코드 만들기(base == null) · 수정
class PromoCodeDialog extends StatefulWidget {
  final PromoCode? base;
  const PromoCodeDialog({super.key, this.base});

  @override
  State<PromoCodeDialog> createState() => _PromoCodeDialogState();
}

class _PromoCodeDialogState extends State<PromoCodeDialog> {
  static final _campaignFormat = RegExp(r'^[a-z0-9_]{2,40}$');
  static const int maxBatch = 200;

  bool get _editing => widget.base != null;
  late bool _auto = false;
  late final _code = TextEditingController(text: widget.base?.code ?? '');
  late final _prefix = TextEditingController();
  late final _count = TextEditingController(text: '1');
  late final _length = TextEditingController(text: '6');
  late final _campaign = TextEditingController(text: widget.base?.campaign ?? '');
  late final _note = TextEditingController(text: widget.base?.note ?? '');
  late final _coins = TextEditingController(text: '${widget.base?.coins ?? 0}');
  late final _maxUses = TextEditingController(text: '${widget.base?.maxUses ?? 0}');
  late final List<String> _items = [...?widget.base?.items];
  late bool _enabled = widget.base?.enabled ?? true;
  late DateTime? _start = widget.base?.startAt;
  late DateTime? _end = widget.base?.endAt;

  @override
  void dispose() {
    for (final c in [_code, _prefix, _count, _length, _campaign, _note, _coins, _maxUses]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _coinsN => int.tryParse(_coins.text.trim()) ?? -1;
  int get _maxUsesN => int.tryParse(_maxUses.text.trim()) ?? -1;
  int get _countN => int.tryParse(_count.text.trim()) ?? 0;
  int get _lengthN => int.tryParse(_length.text.trim()) ?? 0;
  String get _codeN => PromoCodes.normalize(_code.text);
  String get _prefixN => PromoCodes.normalize(_prefix.text).replaceAll(RegExp('[^A-Z0-9]'), '');

  /// 입력마다 무엇이 틀렸는지 — 비어 있으면 저장 가능
  List<String> get _problems => [
        if (!_editing && !_auto && !PromoCodes.isValidFormat(_codeN))
          '코드는 영문 대문자·숫자 ${PromoCodes.minLength}~${PromoCodes.maxLength}자',
        if (!_editing && _auto && (_countN < 1 || _countN > maxBatch)) '개수는 1~$maxBatch',
        if (!_editing && _auto && (_lengthN < 4 || _lengthN > 12)) '무작위 길이는 4~12',
        if (!_editing && _auto && _prefixN.length + _lengthN > PromoCodes.maxLength)
          '접두어 + 길이가 ${PromoCodes.maxLength}자를 넘습니다',
        if (!_campaignFormat.hasMatch(_campaign.text.trim())) '캠페인은 영문 소문자·숫자·_ (예: insta_launch)',
        if (_coinsN < 0 || _coinsN > 100000) '코인은 0~100,000',
        if (_coinsN <= 0 && _items.isEmpty) '보상(코인 또는 아이템)이 없습니다',
        if (_maxUsesN < 0) '한도는 0(무제한) 이상',
        if (_start != null && _end != null && !_end!.isAfter(_start!)) '종료가 시작보다 빠릅니다',
      ];

  PromoCode get _template => PromoCode(
        code: _editing ? widget.base!.code : '',
        campaign: _campaign.text.trim(),
        note: _note.text.trim(),
        coins: _coinsN < 0 ? 0 : _coinsN,
        items: [..._items],
        enabled: _enabled,
        startAt: _start,
        endAt: _end,
        maxUses: _maxUsesN < 0 ? 0 : _maxUsesN,
        uses: widget.base?.uses ?? 0,
        createdAt: widget.base?.createdAt,
      );

  _CodeDraft _build() {
    if (_editing) return _CodeDraft([widget.base!.code], _template);
    if (!_auto) return _CodeDraft([_codeN], _template);
    final set = <String>{};
    while (set.length < _countN) {
      set.add(PromoCodes.generate(prefix: _prefixN, length: _lengthN));
    }
    return _CodeDraft(set.toList(), _template, auto: true, prefix: _prefixN, length: _lengthN);
  }

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
      // 시작은 그날 0시, 종료는 그날 끝(관리자 PC 시간대)
      if (start) {
        _start = DateTime(d.year, d.month, d.day);
      } else {
        _end = DateTime(d.year, d.month, d.day, 23, 59, 59);
      }
    });
  }

  Widget _field(TextEditingController c, String label, {String? hint, bool number = false, bool upper = false}) => TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : null,
        inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
        textCapitalization: upper ? TextCapitalization.characters : TextCapitalization.none,
        decoration: InputDecoration(labelText: label, hintText: hint),
        onChanged: (_) => setState(() {}),
      );

  @override
  Widget build(BuildContext context) {
    final problems = _problems;
    final t = _template;
    return AlertDialog(
      title: Text(_editing ? '코드 수정 — ${widget.base!.code}' : '코드 만들기'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 코드 ──
              if (!_editing) ...[
                Text('코드', style: Bo.h2),
                const SizedBox(height: 8),
                BoSegmented<bool>(
                  options: const [(false, '직접 입력(모두가 같은 코드)'), (true, '자동 생성(여러 개 · 1인 1코드 배포)')],
                  value: _auto,
                  onChanged: (v) => setState(() => _auto = v),
                ),
                const SizedBox(height: 10),
                if (!_auto)
                  _field(_code, '코드', hint: '예: ZONBER2026 — 소문자·공백·하이픈은 자동으로 정리', upper: true)
                else
                  Row(children: [
                    Expanded(flex: 2, child: _field(_prefix, '접두어(선택)', hint: '예: INSTA', upper: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_length, '무작위 길이', number: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_count, '개수(최대 $maxBatch)', number: true)),
                  ]),
                const SizedBox(height: 4),
                Text(
                  _auto
                      ? '예시: ${PromoCodes.generate(prefix: _prefixN, length: _lengthN.clamp(4, 12))} — 헷갈리는 글자(0 O 1 I L)는 쓰지 않습니다'
                      : (_code.text.isEmpty ? '' : '저장될 코드: $_codeN'),
                  style: Bo.caption,
                ),
                const SizedBox(height: 16),
              ],
              // ── 구분 ──
              Text('구분', style: Bo.h2),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _field(_campaign, '캠페인(채널)', hint: '예: insta_launch · youtube_abc')),
                const SizedBox(width: 12),
                Expanded(child: _field(_note, '메모(앱에 안 보임)', hint: '예: 10/1 인스타 게시물')),
              ]),
              const SizedBox(height: 16),
              // ── 보상 ──
              Text('보상', style: Bo.h2),
              const SizedBox(height: 8),
              BoRewardEditor(coins: _coins, items: _items, onChanged: () => setState(() {})),
              const SizedBox(height: 16),
              // ── 조건 ──
              Text('조건', style: Bo.h2),
              const SizedBox(height: 8),
              _field(_maxUses, '전체 사용 한도(선착순)', hint: '0 = 무제한 · 한 사람은 늘 한 번', number: true),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => _pick(true), child: Text('시작 ${_start == null ? '없음' : fmtDate(_start)}'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => _pick(false), child: Text('종료 ${_end == null ? '없음' : fmtDate(_end)}'))),
                const SizedBox(width: 8),
                TextButton(onPressed: () => setState(() => _start = _end = null), child: const Text('기간 지우기')),
              ]),
              SwitchListTile(
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                title: const Text('켜기'),
                subtitle: Text(_enabled ? '저장하면 바로 쓸 수 있습니다' : '꺼 둔 채로 저장합니다', style: Bo.caption),
                contentPadding: EdgeInsets.zero,
              ),
              // ── 미리보기 · 문제 ──
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Bo.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: Bo.line)),
                child: Text(
                  problems.isEmpty
                      ? '유저가 이 코드를 넣으면 → ${codeReward(t)}\n'
                          '1인 1회${t.maxUses > 0 ? ' · 선착순 ${fmtNum(t.maxUses)}명' : ' · 인원 제한 없음'} · ${codePeriod(t)}'
                      : problems.map((p) => '• $p').join('\n'),
                  style: Bo.body.copyWith(color: problems.isEmpty ? Bo.text : Bo.red, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          onPressed: problems.isEmpty ? () => Navigator.pop(context, _build()) : null,
          child: Text(_editing ? '저장' : (_auto ? '${_countN.clamp(0, maxBatch)}개 만들기' : '만들기')),
        ),
      ],
    );
  }
}

/// 만든 결과 — 코드 목록을 한 번에 복사(배포용)
class _CreatedDialog extends StatelessWidget {
  final List<String> made;
  final List<String> dup;
  final PromoCode template;
  const _CreatedDialog({required this.made, required this.dup, required this.template});

  @override
  Widget build(BuildContext context) {
    final text = made.join('\n');
    return AlertDialog(
      title: Text('코드 ${made.length}개를 만들었습니다'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${template.campaign} · ${codeReward(template)}', style: Bo.muted),
            if (dup.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('이미 있어서 건너뜀: ${dup.join(', ')}', style: Bo.caption.copyWith(color: Bo.red)),
            ],
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 280),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Bo.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: Bo.line)),
              child: SingleChildScrollView(child: SelectableText(text, style: Bo.mono.copyWith(color: Bo.text, height: 1.6))),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: text));
            toast(context, '${made.length}개 복사했습니다');
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('모두 복사'),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
      ],
    );
  }
}

/// 코드 확인 — 유저가 넣을 글자 그대로 넣어 보면 앱과 같은 기준으로 판정한다
class _VerifyDialog extends StatefulWidget {
  const _VerifyDialog();

  @override
  State<_VerifyDialog> createState() => _VerifyDialogState();
}

class _VerifyDialogState extends State<_VerifyDialog> {
  final _input = TextEditingController();
  bool _busy = false;
  String? _checked; // 정리된 코드
  PromoCode? _found;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final code = PromoCodes.normalize(_input.text);
    if (code.isEmpty) return;
    setState(() => _busy = true);
    PromoCode? found;
    if (PromoCodes.isValidFormat(code)) {
      try {
        found = await BoData.src.promoCode(code);
      } catch (e) {
        if (mounted) toast(context, '확인 실패: $e', error: true);
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _checked = code;
      _found = found;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _found;
    final st = c?.status();
    return AlertDialog(
      title: const Text('코드 확인'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '유저가 넣을 코드', hintText: '소문자·공백·하이픈도 그대로'),
                  onSubmitted: (_) => _check(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _busy ? null : _check, child: const Text('확인')),
            ]),
            const SizedBox(height: 14),
            if (_checked != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Bo.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: Bo.line)),
                child: c == null
                    ? Text(
                        PromoCodes.isValidFormat(_checked!)
                            ? '$_checked — 없는 코드입니다. 앱에서는 "없는 코드예요"'
                            : '"${_input.text}" — 형식이 틀렸습니다(영문·숫자 ${PromoCodes.minLength}~${PromoCodes.maxLength}자). 앱에서는 "없는 코드예요"',
                        style: Bo.body.copyWith(color: Bo.red))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(c.code, style: Bo.mono.copyWith(color: Bo.text, fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(width: 8),
                          BoBadge(kCodeStatusNames[st]!, color: codeStatusColor(st!), dense: true),
                        ]),
                        const SizedBox(height: 8),
                        Text('보상  ${c.isEmptyReward ? '(없음)' : codeReward(c)}', style: Bo.body),
                        Text('캠페인  ${c.campaign.isEmpty ? '-' : c.campaign}${c.note.isEmpty ? '' : ' · ${c.note}'}', style: Bo.body),
                        Text('사용  ${codeUsage(c)}${c.remaining == null ? '' : ' (남은 ${fmtNum(c.remaining)})'}', style: Bo.body),
                        Text('기간  ${codePeriod(c)}', style: Bo.body),
                        const SizedBox(height: 6),
                        Text(
                          st == PromoCodeStatus.open
                              ? '지금 넣으면 받을 수 있습니다(이미 쓴 계정은 "이미 사용한 코드예요").'
                              : '지금은 받을 수 없습니다 — 앱에는 "${_appMessage(st)}"',
                          style: Bo.caption.copyWith(color: st == PromoCodeStatus.open ? Bo.green : Bo.amber),
                        ),
                      ]),
              ),
          ],
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))],
    );
  }

  static String _appMessage(PromoCodeStatus s) => switch (s) {
        PromoCodeStatus.disabled => '사용이 중지된 코드예요',
        PromoCodeStatus.notStarted => '아직 쓸 수 없는 코드예요',
        PromoCodeStatus.expired => '기간이 끝난 코드예요',
        PromoCodeStatus.exhausted => '선착순이 모두 끝난 코드예요',
        PromoCodeStatus.open => '',
      };
}

/// 이 코드를 쓴 사람 — 누르면 유저 상세
class _UsesDialog extends StatefulWidget {
  final PromoCode code;
  const _UsesDialog({required this.code});

  @override
  State<_UsesDialog> createState() => _UsesDialogState();
}

class _UsesDialogState extends State<_UsesDialog> {
  static const int limit = 300;
  List<BoCodeUse>? _uses;
  Map<String, Map<String, dynamic>?> _users = {};
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uses = await BoData.src.promoCodeUses(widget.code.code, limit);
      final users = await BoData.lookup(uses.map((u) => u.uid));
      if (!mounted) return;
      setState(() {
        _uses = uses;
        _users = users;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uses = _uses;
    return AlertDialog(
      title: Text('${widget.code.code} 사용한 사람'),
      content: SizedBox(
        width: 480,
        height: 420,
        child: _error != null
            ? BoError(error: _error!, onRetry: () {
                setState(() => _error = null);
                _load();
              })
            : uses == null
                ? const BoLoading()
                : uses.isEmpty
                    ? const BoEmpty('아직 쓴 사람이 없습니다', icon: Icons.group_outlined)
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text('${fmtNum(uses.length)}명${uses.length >= limit ? ' (최근 $limit명까지)' : ''} · 누르면 유저 상세', style: Bo.muted),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.separated(
                            itemCount: uses.length,
                            separatorBuilder: (_, _) => Divider(height: 1, color: Bo.lineSoft),
                            itemBuilder: (_, i) {
                              final u = uses[i];
                              return InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  BoNav.openUser(u.uid);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  child: Row(children: [
                                    Expanded(child: BoUserCell(uid: u.uid, data: _users[u.uid])),
                                    Text(fmtDateTime(u.at), style: Bo.caption),
                                  ]),
                                ),
                              );
                            },
                          ),
                        ),
                      ]),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))],
    );
  }
}
