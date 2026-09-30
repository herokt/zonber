import 'dart:async';

import 'package:flutter/material.dart';

import '../push.dart';
import 'bo_common.dart';
import 'bo_reward_editor.dart' show BoStep;

// ─────────────────────────────────────────────────────────────
// 푸시 — 이벤트·소식 알림을 앱 사용자에게 보낸다(docs/PUSH.md).
//   왼쪽: ① 템플릿 ② 문구(4개 언어) ③ 받는 사람 → 미리보기 → 보내기(숫자 확인)
//   오른쪽: 보낸 기록(push_campaigns) — 서버 함수가 몇 초 안에 보내고 결과를 적는다
// 보내면 되돌릴 수 없다. 먼저 [테스트(관리자 기기)] 로 보내 보고 전체로 보낸다.
// 문구·토픽 약속은 lib/push.dart, 실제 발송은 functions/index.js.
// ─────────────────────────────────────────────────────────────
class PushPage extends StatefulWidget {
  const PushPage({super.key});

  @override
  State<PushPage> createState() => _PushPageState();
}

const Map<PushAudience, String> kPushAudienceNames = {
  PushAudience.all: '전체',
  PushAudience.members: '회원만',
  PushAudience.guests: '게스트만',
  PushAudience.testers: '테스트(관리자 기기)',
};

const Map<String, String> kPushLangNames = {'ko': '한국어', 'en': '영어', 'ja': '일본어', 'zh': '중국어'};

const Map<PushStatus, (String, String)> _statusText = {
  PushStatus.pending: ('대기', 'amber'),
  PushStatus.sending: ('보내는 중', 'blue'),
  PushStatus.sent: ('보냄', 'green'),
  PushStatus.failed: ('실패', 'red'),
};

Color _statusColor(PushStatus s) => switch (_statusText[s]!.$2) {
      'green' => Bo.green,
      'red' => Bo.red,
      'blue' => Bo.blue,
      _ => Bo.amber,
    };

class _PushPageState extends State<PushPage> with BoReloadable {
  List<PushCampaign> _rows = [];
  bool _loading = true;
  Object? _error;
  bool _sending = false;
  Timer? _poll;

  String _templateId = '';
  PushAudience _audience = PushAudience.testers; // 처음엔 시험 발송부터
  final Set<String> _langs = {...PushTopics.langs};
  String _previewLang = 'ko';
  late final Map<String, TextEditingController> _title = {for (final l in PushTopics.langs) l: TextEditingController()};
  late final Map<String, TextEditingController> _body = {for (final l in PushTopics.langs) l: TextEditingController()};

  @override
  void dispose() {
    _poll?.cancel();
    for (final c in [..._title.values, ..._body.values]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await BoData.src.pushCampaigns(50);
      if (mounted) setState(() => _rows = rows);
      BoData.markLoaded();
      // 보내는 중인 게 있으면 몇 초 뒤 다시 본다(서버 함수가 결과를 적는다)
      _poll?.cancel();
      if (rows.any((r) => r.status == PushStatus.pending || r.status == PushStatus.sending)) {
        _poll = Timer(const Duration(seconds: 3), () {
          if (mounted) reload();
        });
      }
    } catch (e) {
      debugPrint('Push: $e');
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _useTemplate(PushTemplate? t) => setState(() {
        _templateId = t?.id ?? '';
        for (final l in PushTopics.langs) {
          _title[l]!.text = t?.title[l] ?? '';
          _body[l]!.text = t?.body[l] ?? '';
        }
      });

  PushCampaign _build() => PushCampaign(
        id: '',
        title: {for (final l in PushTopics.langs) if (_title[l]!.text.trim().isNotEmpty) l: _title[l]!.text.trim()},
        body: {for (final l in PushTopics.langs) if (_body[l]!.text.trim().isNotEmpty) l: _body[l]!.text.trim()},
        langs: _langs.length == PushTopics.langs.length ? const [] : (PushTopics.langs.where(_langs.contains).toList()),
        audience: _audience,
        templateId: _templateId,
        createdBy: BoData.src.adminEmail,
      );

  List<String> get _problems => [
        for (final l in ['ko', 'en']) ...[
          if (_title[l]!.text.trim().isEmpty) '제목(${kPushLangNames[l]})을 적으세요',
          if (_body[l]!.text.trim().isEmpty) '본문(${kPushLangNames[l]})을 적으세요',
        ],
        if (_langs.isEmpty) '받을 언어를 하나 이상 고르세요',
      ];

  Future<void> _send() async {
    final c = _build();
    final who = kPushAudienceNames[c.audience]!;
    final langs = c.targetLangs.map((l) => kPushLangNames[l]).join('·');
    final fallback = [
      for (final l in c.targetLangs)
        if (!(c.title[l]?.isNotEmpty ?? false) || !(c.body[l]?.isNotEmpty ?? false)) kPushLangNames[l],
    ];
    if (!await confirmCode(
      context,
      c.audience == PushAudience.testers ? '테스트 푸시 보내기' : '푸시 보내기',
      '받는 사람  $who · $langs 기기\n'
          '${fallback.isEmpty ? '' : '${fallback.join('·')} 기기에는 영어 문구가 갑니다.\n'}\n'
          '${c.titleFor('ko')}\n${c.bodyFor('ko')}\n\n'
          '${c.audience == PushAudience.testers ? '관리자 계정으로 로그인한 기기에만 갑니다.' : '보내면 되돌릴 수 없습니다.'}',
      ok: '보내기',
      okColor: c.audience == PushAudience.testers ? null : Bo.red,
    )) {
      return;
    }
    setState(() => _sending = true);
    try {
      await BoData.src.sendPush(c);
      if (mounted) toast(context, c.audience == PushAudience.testers ? '테스트 푸시를 보냈습니다' : '푸시를 보냈습니다 — 결과는 오른쪽 기록에');
      await reload();
    } catch (e) {
      if (mounted) toast(context, '보내기 실패: $e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = _rows.where((r) => r.status == PushStatus.sent && r.audience != PushAudience.testers).length;
    return BoPage(
      topBar: BoTopBar(
        title: '푸시',
        breadcrumb: const ['운영'],
        subtitle: '이벤트·소식 알림 · 알림을 켜 둔 기기에 언어별로 · 최근 발송 $sent건',
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(builder: (context, box) {
          final compose = _compose();
          final history = _history();
          if (box.maxWidth < 1100) {
            return ListView(children: [compose, const SizedBox(height: 16), SizedBox(height: 520, child: history)]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(width: 520, child: SingleChildScrollView(child: compose)),
            const SizedBox(width: 16),
            Expanded(child: history),
          ]);
        }),
      ),
    );
  }

  // ── 작성 ──

  Widget _compose() {
    final problems = _problems;
    final c = _build();
    var step = 0;
    return BoCard(
      title: '새 푸시',
      subtitle: '먼저 테스트로 보내 보고, 전체로 보내세요',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ① 템플릿
        BoStep(++step, '템플릿', hint: '고르면 문구가 채워집니다 — 고쳐서 보내도 됩니다'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final t in PushTemplates.all)
            ChoiceChip(label: Text(t.name), selected: _templateId == t.id, onSelected: (_) => _useTemplate(t)),
          ChoiceChip(label: const Text('직접 쓰기'), selected: _templateId.isEmpty, onSelected: (_) => _useTemplate(null)),
        ]),

        // ② 문구
        BoStep(++step, '문구', hint: '한국어·영어 필수 · 비운 언어는 영어로 갑니다'),
        for (final l in PushTopics.langs) ...[
          _langFields(l),
          const SizedBox(height: 8),
        ],

        // ③ 받는 사람
        BoStep(++step, '받는 사람'),
        BoSegmented<PushAudience>(
          options: [for (final a in PushAudience.values) (a, kPushAudienceNames[a]!)],
          value: _audience,
          onChanged: (v) => setState(() => _audience = v),
        ),
        const SizedBox(height: 10),
        Row(children: [
          SizedBox(width: 72, child: Text('기기 언어', style: Bo.muted)),
          Expanded(
            child: Wrap(spacing: 6, children: [
              for (final l in PushTopics.langs)
                FilterChip(
                  label: Text(kPushLangNames[l]!),
                  selected: _langs.contains(l),
                  onSelected: (on) => setState(() => on ? _langs.add(l) : _langs.remove(l)),
                ),
            ]),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          _audience == PushAudience.testers
              ? '관리자 계정(${BoData.src.adminEmail})으로 로그인한 기기에만 갑니다.'
              : '알림을 켜 둔 기기 중 고른 언어로 앱을 쓰는 기기에 갑니다. 기기 토큰은 저장하지 않아 정확한 받는 수는 모릅니다.',
          style: Bo.caption,
        ),

        // 미리보기
        BoStep(++step, '미리보기'),
        Row(children: [
          BoSegmented<String>(
            options: [for (final l in PushTopics.langs) (l, kPushLangNames[l]!)],
            value: _previewLang,
            onChanged: (v) => setState(() => _previewLang = v),
          ),
        ]),
        const SizedBox(height: 10),
        _preview(c.titleFor(_previewLang), c.bodyFor(_previewLang)),

        const SizedBox(height: 14),
        if (problems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(problems.map((e) => '• $e').join('\n'), style: Bo.body.copyWith(color: Bo.red, height: 1.5)),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: problems.isEmpty && !_sending ? _send : null,
            style: _audience == PushAudience.testers ? null : FilledButton.styleFrom(backgroundColor: Bo.red),
            icon: _sending
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded, size: 16),
            label: Text(_audience == PushAudience.testers ? '테스트로 보내기' : '${kPushAudienceNames[_audience]}에게 보내기'),
          ),
        ),
      ]),
    );
  }

  Widget _langFields(String l) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: SizedBox(width: 56, child: Text(kPushLangNames[l]!, style: Bo.muted)),
        ),
        Expanded(
          child: Column(children: [
            TextField(
              controller: _title[l],
              maxLength: 40,
              decoration: InputDecoration(hintText: l == 'ko' || l == 'en' ? '제목 (필수)' : '제목 (비우면 영어)', isDense: true, counterText: ''),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _body[l],
              maxLength: 120,
              minLines: 1,
              maxLines: 2,
              decoration: InputDecoration(hintText: l == 'ko' || l == 'en' ? '본문 (필수)' : '본문 (비우면 영어)', isDense: true, counterText: ''),
              onChanged: (_) => setState(() {}),
            ),
          ]),
        ),
      ]);

  /// 휴대폰 알림처럼 — 아이콘 · 앱 이름 · 제목 · 본문
  Widget _preview(String title, String body) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Bo.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: Bo.line)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF0B0D12), borderRadius: BorderRadius.circular(8)),
            child: const Text('Z', style: TextStyle(color: Color(0xFF37E0FF), fontWeight: FontWeight.w900, fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ZONBER · 지금', style: Bo.caption),
              const SizedBox(height: 2),
              Text(title.isEmpty ? '(제목)' : title, style: Bo.body.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(body.isEmpty ? '(본문)' : body, style: Bo.body.copyWith(color: Bo.text2)),
            ]),
          ),
        ]),
      );

  // ── 보낸 기록 ──

  Widget _history() => BoCard(
        title: '보낸 기록',
        subtitle: '최근 50건 · 보내는 중이면 저절로 새로 고칩니다',
        trailing: IconButton(tooltip: '새로 고침', onPressed: reload, icon: const Icon(Icons.refresh_rounded, size: 18)),
        fill: true,
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_error != null) BoError(error: _error!, onRetry: reload),
          Expanded(
            child: _loading && _rows.isEmpty
                ? const BoLoading()
                : BoTable(
                    scroll: true,
                    columns: const [
                      BoCol('보낸 시각', width: 118),
                      BoCol('상태', width: 72),
                      BoCol('받는 사람', width: 120),
                      BoCol('제목(ko)', flex: 3, minWidth: 110),
                      BoCol('언어별 결과', flex: 2, minWidth: 140),
                    ],
                    rowCount: _rows.length,
                    cells: (i) => _row(_rows[i]),
                    empty: const BoEmpty('아직 보낸 푸시가 없습니다', icon: Icons.notifications_none_rounded),
                  ),
          ),
        ]),
      );

  List<Widget> _row(PushCampaign r) {
    final (label, _) = _statusText[r.status]!;
    final langs = r.targetLangs.length == PushTopics.langs.length ? '전 언어' : r.targetLangs.map((l) => kPushLangNames[l]).join('·');
    final results = [
      for (final l in r.targetLangs)
        '${kPushLangNames[l]} ${switch (r.results[l]) {
          null => r.status == PushStatus.sent || r.status == PushStatus.failed ? '-' : '…',
          final v when v.startsWith('ok') => '성공',
          final v when v.startsWith('skip') => '건너뜀',
          _ => '실패',
        }}',
    ].join('  ');
    return [
      BoTable.text(fmtDateTime(r.createdAt)),
      BoBadge(label, color: _statusColor(r.status), dense: true),
      BoTable.text('${kPushAudienceNames[r.audience]} · $langs'),
      Tooltip(
        message: '${r.titleFor('ko')}\n${r.bodyFor('ko')}${r.templateId.isEmpty ? '' : '\n템플릿 ${r.templateId}'}',
        child: BoTable.text(r.titleFor('ko'), style: Bo.cellStrong),
      ),
      Tooltip(
        message: r.results.isEmpty ? '결과 없음' : r.results.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
        child: BoTable.text(results),
      ),
    ];
  }
}
