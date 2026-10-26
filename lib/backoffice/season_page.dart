import 'package:flutter/material.dart';

import '../season.dart';
import 'bo_common.dart';

// ─────────────────────────────────────────────────────────────
// 시즌 — 랭킹의 단위를 정한다(config/season · lib/season.dart). 주간·월간 랭킹은 없고 시즌 하나뿐이다(2026-10-26).
//   연간(1월 1일~12월 31일) · 분기 · 월간 · N일마다 중 하나, 시즌 1 시작, 경계 시간대(UTC+h), 마감 전 자동 푸시(n일 전 · 몇 시).
//   저장하면 앱은 켤 때 읽는다(기기 캐시). 서버 함수(functions/season.js)가 매시간 보고 마감 전 푸시를 보내고,
//   시즌이 끝나면 존별 TOP 3 를 hall_of_fame/{시즌 id} 에 남긴다(명예의 전당).
//   ⚠️ 모드·시작을 바꾸면 **지금 랭킹의 범위가 바로 바뀐다** — 시즌 중간에 바꾸지 말고 시즌이 끝난 직후에.
// ─────────────────────────────────────────────────────────────
class SeasonPage extends StatefulWidget {
  const SeasonPage({super.key});

  @override
  State<SeasonPage> createState() => _SeasonPageState();
}

const _modeNames = {SeasonMode.year: '연간', SeasonMode.quarter: '분기', SeasonMode.month: '월간', SeasonMode.days: 'N일마다'};

class _SeasonPageState extends State<SeasonPage> with BoReloadable {
  SeasonConfig _saved = SeasonConfig.defaults;
  List<HallOfFameSeason> _hall = const [];
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  SeasonMode _mode = SeasonMode.year;
  DateTime _firstStart = SeasonConfig.defaults.firstStart; // UTC
  final _offset = TextEditingController(text: '0');
  final _periodDays = TextEditingController(text: '90');
  final _pushDays = TextEditingController(text: '30, 10, 3');
  final _pushHour = TextEditingController(text: '18');

  @override
  void dispose() {
    _offset.dispose();
    _periodDays.dispose();
    _pushDays.dispose();
    _pushHour.dispose();
    super.dispose();
  }

  void _fill(SeasonConfig c) {
    _mode = c.mode;
    _firstStart = c.firstStart;
    _offset.text = '${c.offsetHours}';
    _periodDays.text = '${c.periodDays}';
    _pushDays.text = c.pushDays.join(', ');
    _pushHour.text = '${c.pushHour}';
  }

  @override
  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await BoData.src.seasonConfig();
      final hall = await BoData.src.hallOfFame(24);
      if (!mounted) return;
      setState(() {
        _saved = c;
        _hall = hall;
        _fill(c);
      });
      BoData.markLoaded();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 화면 값 → 설정(틀린 값이면 null, [_problem] 이 이유)
  SeasonConfig? get _value {
    if (_problem != null) return null;
    return SeasonConfig(
      mode: _mode,
      firstStart: _firstStart,
      offsetHours: int.parse(_offset.text.trim()),
      periodDays: _mode == SeasonMode.days ? int.parse(_periodDays.text.trim()) : _saved.periodDays,
      pushDays: _parsedPushDays!,
      pushHour: int.parse(_pushHour.text.trim()),
    );
  }

  List<int>? get _parsedPushDays {
    final out = <int>[];
    for (final part in _pushDays.text.split(RegExp(r'[,\s]+'))) {
      if (part.isEmpty) continue;
      final n = int.tryParse(part);
      if (n == null || n <= 0 || n > 365) return null;
      if (!out.contains(n)) out.add(n);
    }
    out.sort((a, b) => b.compareTo(a));
    return out;
  }

  String? get _problem {
    final off = int.tryParse(_offset.text.trim());
    if (off == null || off < -12 || off > 14) return '시간대는 -12 ~ 14 사이 정수(한국 9)';
    if (_mode == SeasonMode.days) {
      final d = int.tryParse(_periodDays.text.trim());
      if (d == null || d < 1 || d > 3660) return '시즌 길이는 1 ~ 3660일';
    }
    if (_parsedPushDays == null) return '푸시 날짜는 "30, 10, 3" 처럼 1~365 사이 정수';
    final h = int.tryParse(_pushHour.text.trim());
    if (h == null || h < 0 || h > 23) return '푸시 시각은 0 ~ 23';
    return null;
  }

  bool get _dirty {
    final v = _value;
    if (v == null) return true;
    return v.mode != _saved.mode ||
        v.firstStart != _saved.firstStart ||
        v.offsetHours != _saved.offsetHours ||
        v.periodDays != _saved.periodDays ||
        v.pushDays.join(',') != _saved.pushDays.join(',') ||
        v.pushHour != _saved.pushHour;
  }

  Future<void> _pickFirstStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _firstStart,
      firstDate: DateTime(2026),
      lastDate: DateTime(2036),
      helpText: '시즌 1 시작일(시즌 시간대 자정)',
    );
    if (d == null) return;
    final off = int.tryParse(_offset.text.trim()) ?? 0;
    // 시즌 시간대 자정 = UTC 로는 off 시간 전
    setState(() => _firstStart = DateTime.utc(d.year, d.month, d.day).subtract(Duration(hours: off)));
  }

  Future<void> _save() async {
    final v = _value;
    if (v == null) {
      toast(context, _problem ?? '값을 확인해 주세요', error: true);
      return;
    }
    final cur = v.seasonAt(DateTime.now().toUtc());
    final ok = await confirmCode(
      context,
      '시즌 설정 저장',
      '${_modeNames[v.mode]} · 시즌 1 시작 ${_fmtS(v, v.firstStart)} · UTC${v.offsetHours >= 0 ? '+' : ''}${v.offsetHours}\n'
      '지금 시즌: ${cur.id} (${_fmtS(v, cur.start)} ~ ${_fmtS(v, cur.end)})\n'
      '마감 ${v.pushDays.join('·')}일 전 ${v.pushHour}시에 자동 푸시\n\n'
      '⚠️ 저장하면 앱 랭킹의 범위가 바로 바뀝니다. 시즌 중간에 바꾸지 마세요.',
      ok: '저장',
      okColor: Bo.blue,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await BoData.src.saveSeasonConfig(v);
      if (mounted) toast(context, '저장했습니다 — 앱은 켤 때 읽습니다');
      await reload();
    } catch (e) {
      if (mounted) toast(context, '저장 실패: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// UTC 순간 → 시즌 시간대 벽시계 문자열
  String _fmtS(SeasonConfig c, DateTime utc) {
    final s = utc.toUtc().add(Duration(hours: c.offsetHours));
    return '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')} ${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return BoPage(
      topBar: BoTopBar(
        title: '시즌',
        breadcrumb: const ['운영'],
        subtitle: '랭킹의 단위 — 연간·분기·월간·N일. 시즌이 끝나면 존별 TOP 3 가 명예의 전당에 남고, 마감 전에 자동 푸시가 나갑니다',
        actions: [
          FilledButton.icon(
            onPressed: _loading || _saving || !_dirty || _problem != null ? null : _save,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text(_saving ? '저장 중…' : '저장'),
          ),
        ],
      ),
      child: _error != null
          ? Center(child: Text('불러오지 못했습니다: $_error', style: Bo.muted))
          : _loading
              ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)))
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    LayoutBuilder(builder: (context, c) {
                      final wide = c.maxWidth > 900;
                      final f = _formCard();
                      final p = _previewCard();
                      return wide
                          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: f), const SizedBox(width: 16), Expanded(child: p)])
                          : Column(children: [f, const SizedBox(height: 16), p]);
                    }),
                    const SizedBox(height: 16),
                    _hallCard(),
                  ],
                ),
    );
  }

  InputDecoration _deco(String label, {String? hint}) => InputDecoration(labelText: label, hintText: hint, isDense: true, border: const OutlineInputBorder());

  Widget _formCard() {
    final problem = _problem;
    return BoCard(
      title: '설정',
      subtitle: _saved.updatedAt == null ? '아직 저장한 적 없음 — 기본값(연간 · 시즌 1 = 2026-11-01 UTC)' : '${fmtDateTime(_saved.updatedAt)} · ${_saved.updatedBy}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('시즌 단위', style: Bo.th),
          const SizedBox(height: 6),
          BoSegmented<SeasonMode>(
            options: [for (final m in SeasonMode.values) (m, _modeNames[m]!)],
            value: _mode,
            onChanged: (v) => setState(() => _mode = v),
          ),
          const SizedBox(height: 6),
          Text(
            switch (_mode) {
              SeasonMode.year => '1월 1일 ~ 12월 31일. 시즌 id = 연도(2026)',
              SeasonMode.quarter => '1·4·7·10월 1일에 시작. 시즌 id = 2026Q4',
              SeasonMode.month => '매달 1일. 시즌 id = 2026-10',
              SeasonMode.days => '시즌 1 시작부터 N일마다. 시즌 id = S1, S2 …',
            },
            style: Bo.muted,
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: _pickFirstStart,
                child: InputDecorator(
                  decoration: _deco('시즌 1 시작일'),
                  child: Text(_fmtS(SeasonConfig(firstStart: _firstStart, offsetHours: int.tryParse(_offset.text.trim()) ?? 0), _firstStart), style: Bo.body),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 150,
              child: TextField(
                controller: _offset,
                decoration: _deco('경계 시간대 UTC+', hint: '한국 9'),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text('그 전 기록은 전부 프리시즌(S0). 연간·분기·월간은 첫 시즌만 이 날부터 시작하고 그 뒤는 달력대로.', style: Bo.muted),
          if (_mode == SeasonMode.days) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _periodDays,
              decoration: _deco('시즌 길이(일)'),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 18),
          Text('마감 전 자동 푸시', style: Bo.th),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _pushDays,
                decoration: _deco('며칠 전에(쉼표로)', hint: '30, 10, 3'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 150,
              child: TextField(
                controller: _pushHour,
                decoration: _deco('몇 시에(0~23)'),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text('"명예의 전당에 오를 기회가 얼마 안 남았어요" 문구로 알림을 켠 모든 기기에 갑니다(4개 언어, functions/season.js). 비우면 보내지 않습니다.', style: Bo.muted),
          if (problem != null) ...[
            const SizedBox(height: 12),
            Text(problem, style: Bo.muted.copyWith(color: Bo.red)),
          ],
        ],
      ),
    );
  }

  Widget _previewCard() {
    final c = _value ?? _saved;
    final now = DateTime.now().toUtc();
    final cur = c.seasonAt(now);
    final rows = <Widget>[];
    var s = cur;
    for (var i = 0; i < 4; i++) {
      final pushes = c.pushMoments(s).where((m) => m.$2.isAfter(now)).map((m) => '${m.$1}일 전 ${_fmtS(c, m.$2)}').join(' · ');
      rows.add(BoKv(
        i == 0 ? '지금 시즌 ${s.id}' : '다음 ${s.id}',
        v: '${_fmtS(c, s.start)} ~ ${_fmtS(c, s.end)}${i == 0 ? '  (D-${s.daysLeft})' : ''}',
        note: s.number == 0 ? '프리시즌 — 푸시 없음' : (pushes.isEmpty ? '남은 푸시 없음' : '푸시 $pushes'),
        keyWidth: 150,
      ));
      s = c.next(s);
    }
    return BoCard(
      title: '미리보기',
      subtitle: _dirty ? '화면 값 기준(아직 저장 안 함)' : '저장된 값 기준',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
    );
  }

  Widget _hallCard() {
    return BoCard(
      title: '명예의 전당',
      subtitle: '끝난 시즌마다 존별 TOP 3 (hall_of_fame/{시즌 id}) — 서버 함수가 시즌이 끝난 뒤 첫 실행에 쓴다',
      child: _hall.isEmpty
          ? Text('아직 끝난 시즌이 없습니다', style: Bo.muted)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final h in _hall)
                  BoKv(
                    h.id,
                    keyWidth: 110,
                    v: h.zones.entries
                        .map((e) => '${stageLabel(e.key)} ${e.value.isEmpty ? '-' : e.value.take(3).map((r) => '${r['nickname'] ?? '?'} ${fmtSec(((r['survivalTime'] as num?) ?? 0).toDouble(), digits: 3)}').join(' / ')}')
                        .join('   ·   '),
                    note: '${fmtDate(h.start)} ~ ${fmtDate(h.end?.subtract(const Duration(seconds: 1)))}',
                  ),
              ],
            ),
    );
  }
}
