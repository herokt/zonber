import 'package:flutter/material.dart';

import 'bo_common.dart';
import 'runs_table.dart';

// ─────────────────────────────────────────────────────────────
// 플레이 기록 — 전체 회원의 runs(collection group) 최신순.
// 서버 쿼리는 기간(timestamp)만 걸고 스테이지는 화면에서 거른다(복합 색인을 만들지 않으려고).
// 그래서 한 페이지(200판)에 조건에 맞는 판이 적을 수 있다 → "더 보기"로 더 읽는다.
// 기간 전체 판 수는 서버 집계(count)로 따로 보여 준다.
// ─────────────────────────────────────────────────────────────
class RunsPage extends StatefulWidget {
  const RunsPage({super.key});

  @override
  State<RunsPage> createState() => _RunsPageState();
}

enum _Range { today, d7, d30 }

/// 판이 하나도 안 보일 때 — 원인 세 가지를 순서대로 짚어 준다(2026-09-25)
const String kNoRunsHint = '회원(로그인) 상태로 플레이한 판만 users/{uid}/runs 에 남습니다 — '
    '게스트 플레이·웹 플레이는 저장하지 않습니다.\n'
    '기록이 있어야 하는데 비어 있다면 Firestore 규칙·색인이 배포됐는지 확인하세요: '
    'firebase deploy --only firestore:rules,firestore:indexes';

const _rangeNames = {_Range.today: '오늘', _Range.d7: '7일', _Range.d30: '30일'};

class _RunsPageState extends State<RunsPage> with BoReloadable {
  static const int _page = 200;

  _Range _range = _Range.d7;
  String _stage = ''; // '' = 전체

  final List<RunRow> _runs = [];
  Object? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  int? _serverCount;

  DateTime get _since => switch (_range) {
        _Range.today => startOfToday(),
        _Range.d7 => DateTime.now().subtract(const Duration(days: 7)),
        _Range.d30 => DateTime.now().subtract(const Duration(days: 30)),
      };

  @override
  Future<void> reload() async {
    _runs.clear();
    _cursor = null;
    _hasMore = true;
    _serverCount = null;
    _error = null;
    _loadCount();
    await _more();
    BoData.markLoaded();
  }

  Future<void> _loadCount() async {
    try {
      final n = await BoData.src.runsCount(_since);
      if (mounted) setState(() => _serverCount = n);
    } catch (e) {
      debugPrint('Runs count: $e');
    }
  }

  Future<void> _more() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await BoData.src.runsPage(_since, _cursor, _page);
      _cursor = p.cursor;
      _hasMore = p.hasMore;
      await BoData.lookup(p.items.map((r) => r.uid));
      if (mounted) setState(() => _runs.addAll(p.items));
    } catch (e) {
      debugPrint('Runs: $e');
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<RunRow> get _filtered => _stage.isEmpty ? _runs : _runs.where((r) => r.mapId == _stage).toList();

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return BoPage(
      topBar: BoTopBar(
        title: '플레이 기록',
        breadcrumb: const ['운영'],
        subtitle: '기간 ${_rangeNames[_range]} 전체 ${_serverCount == null ? '…' : fmtNum(_serverCount)}판 (서버 집계 · 회원 판)',
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summary(rows),
            const SizedBox(height: Bo.gap),
            Expanded(
              child: BoCard(
                fill: true,
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BoToolbar(
                      filters: [
                        BoSegmented<_Range>(
                          options: [for (final r in _Range.values) (r, _rangeNames[r]!)],
                          value: _range,
                          onChanged: (v) {
                            setState(() => _range = v);
                            reload();
                          },
                        ),
                        BoSegmented<String>(
                          options: [('', '전체 스테이지'), for (final s in kStages) (s.id, s.label)],
                          value: _stage,
                          onChanged: (v) => setState(() => _stage = v),
                        ),
                      ],
                      trailing: [
                        Text('불러옴 ${fmtNum(_runs.length)}판 · 조건 일치 ${fmtNum(rows.length)}판', style: Bo.muted),
                      ],
                    ),
                    if (_error != null) BoError(error: _error!, onRetry: _more),
                    Expanded(
                      child: _runs.isEmpty && _loading
                          ? const BoLoading()
                          : RunsTable(
                              runs: rows,
                              scroll: true,
                              empty: BoEmpty(
                                _hasMore ? '불러온 판 중 조건에 맞는 판이 없습니다 — 더 보기' : '조건에 맞는 판이 없습니다',
                                hint: _hasMore || _runs.isNotEmpty ? null : kNoRunsHint,
                                icon: Icons.history_toggle_off_rounded,
                              ),
                              footer: BoTableFooter(
                                text: _hasMore
                                    ? '${fmtNum(_runs.length)}판 불러옴 · 최신순 · 행을 누르면 유저 상세'
                                    : '기간 안의 판을 모두 불러왔습니다 (${fmtNum(_runs.length)}판)',
                                actions: [
                                  if (_loading)
                                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                  if (_hasMore && !_loading)
                                    OutlinedButton.icon(
                                      onPressed: _more,
                                      icon: const Icon(Icons.expand_more_rounded, size: 16),
                                      label: Text('더 보기 (+$_page판)'),
                                    ),
                                ],
                              ),
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

  Widget _summary(List<RunRow> rows) {
    final users = <String>{};
    int coins = 0, bonus = 0, revive = 0, best = 0;
    double time = 0;
    final agg = {for (final s in kStages) s.id: StageAgg()};
    for (final r in rows) {
      users.add(r.uid);
      coins += r.coins;
      bonus += r.bonus;
      revive += r.revive;
      time += r.time;
      if (r.best) best++;
      agg[r.mapId]?.add(r);
    }
    final stageLine = kStages.where((s) => agg[s.id]!.runs > 0).map((s) => '${s.name} ${fmtNum(agg[s.id]!.runs)}').join(' · ');
    return BoGrid(
      minItemWidth: 170,
      maxColumns: 5,
      children: [
        BoKpi(label: '판 수', value: fmtNum(rows.length), sub: stageLine.isEmpty ? '조건 일치 판 기준' : stageLine, icon: Icons.sports_esports_outlined),
        BoKpi(label: '플레이 유저', value: fmtNum(users.length), sub: '고유 회원 수', icon: Icons.people_outline_rounded, color: Bo.blue),
        BoKpi(
          label: '총 생존 시간',
          value: fmtDuration(time),
          sub: '평균 ${fmtSec(rows.isEmpty ? 0 : time / rows.length, digits: 1)}',
          icon: Icons.timer_outlined,
          color: Bo.purple,
        ),
        BoKpi(label: '획득 코인', value: fmtNum(coins), sub: '보너스 ${fmtNum(bonus)}', icon: Icons.monetization_on_outlined, color: Bo.coin),
        BoKpi(label: '부활 · 신기록', value: '${fmtNum(revive)} · ${fmtNum(best)}', sub: '부활 판 · 신기록 판', icon: Icons.replay_rounded, color: Bo.amber),
      ],
    );
  }
}
