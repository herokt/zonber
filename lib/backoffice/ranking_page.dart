import 'package:flutter/material.dart';

import '../season.dart';
import 'bo_common.dart';

// ─────────────────────────────────────────────────────────────
// 랭킹 관리 — maps/{stage}/records (현재 스테이지 3개만). 기간 필터는 게임(RankingSystem)과 같다:
//   주 = 월요일 00:00, 월 = 1일, 올해 = 1월 1일 (현재 시즌 시작보다 앞이면 시즌 시작). 전체 = 기간 없음.
// 기간 쿼리는 timestamp 범위로 읽어 와 생존 시간순 정렬을 화면에서 한다(게임과 같은 방식, 단일 필드 색인).
// 의심 기록: 600초 초과, 다음 순위와 1.5배 이상 격차(상위 10위), 유저 문서 없음.
// ─────────────────────────────────────────────────────────────
class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

enum _Period { week, month, year, all }

const _periodNames = {_Period.week: '주간', _Period.month: '월간', _Period.year: '올해', _Period.all: '전체'};

class _RankingPageState extends State<RankingPage> with BoReloadable {
  static const int _scanLimit = 3000;
  static const int _show = 200;
  static const double _suspectTime = 600;

  String _mapId = kStages.first.id;
  _Period _period = _Period.week;
  bool _bestPerUser = true;

  bool _loading = true;
  Object? _error;
  List<BoRec> _records = [];
  int _scanned = 0;

  DateTime? _periodStart() {
    final today = startOfToday();
    final DateTime s;
    switch (_period) {
      case _Period.week:
        s = today.subtract(Duration(days: today.weekday - 1));
      case _Period.month:
        s = DateTime(today.year, today.month, 1);
      case _Period.year:
        s = DateTime(today.year, 1, 1);
      case _Period.all:
        return null;
    }
    return s.isBefore(Season.currentStart) ? Season.currentStart : s;
  }

  @override
  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final start = _periodStart();
      final raw = await BoData.src.records(_mapId, start, start == null ? (_bestPerUser ? 1000 : _show) : _scanLimit);
      var docs = raw.toList()..sort((a, b) => b.time.compareTo(a.time));
      if (_bestPerUser) {
        final seen = <String>{};
        docs = docs.where((d) => d.userId.isEmpty || seen.add(d.userId)).toList();
      }
      docs = docs.take(_show).toList();
      await BoData.users().catchError((Object e) {
        debugPrint('Ranking users: $e');
        return <BoUser>[];
      });
      await BoData.lookup(docs.map((d) => d.userId));
      if (mounted) {
        setState(() {
          _records = docs;
          _scanned = raw.length;
        });
      }
      BoData.markLoaded();
    } catch (e) {
      debugPrint('Ranking: $e');
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<(String, Color)> _flags(int i) {
    final r = _records[i];
    final t = r.time;
    final out = <(String, Color)>[];
    if (t > _suspectTime) out.add(('600초 초과', Bo.red));
    if (i + 1 < _records.length) {
      final next = _records[i + 1].time;
      if (i < 10 && next > 0 && t >= next * 1.5) out.add(('다음 순위와 ${(t / next).toStringAsFixed(1)}배', Bo.red));
    }
    if (r.userId.isEmpty) {
      out.add(('userId 없음', Bo.red));
    } else if (BoData.cached(r.userId) == null) {
      out.add(('유저 문서 없음', Bo.amber));
    }
    return out;
  }

  bool _suspect(int i) => _flags(i).any((f) => f.$2 == Bo.red);

  Future<void> _delete(BoRec r) async {
    final nick = nickOf(BoData.cached(r.userId));
    final ok = await confirmCode(context, '랭킹 기록 삭제',
        '$nick · ${fmtSec(r.time)} · ${fmtDateTime(r.at)}\n${stageLabel(_mapId)} 기록을 삭제합니다. 되돌릴 수 없습니다.', ok: '삭제');
    if (!ok) return;
    try {
      await BoData.src.deleteRecord(r);
      if (mounted) toast(context, '삭제했습니다');
      reload();
    } catch (e) {
      if (mounted) toast(context, '삭제 실패: $e', error: true);
    }
  }

  void _change(VoidCallback f) {
    setState(f);
    reload();
  }

  @override
  Widget build(BuildContext context) {
    final start = _periodStart();
    final suspects = [for (int i = 0; i < _records.length; i++) if (_suspect(i)) i].length;
    final users = _records.map((r) => r.userId).where((u) => u.isNotEmpty).toSet().length;
    return BoPage(
      topBar: BoTopBar(
        title: '랭킹 관리',
        breadcrumb: const ['운영'],
        subtitle: '${stageLabel(_mapId)} · ${_periodNames[_period]}${start == null ? '' : ' (${fmtDate(start)} ~)'}',
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BoGrid(
              minItemWidth: 180,
              maxColumns: 4,
              children: [
                BoKpi(
                  label: '표시 기록',
                  value: fmtNum(_records.length),
                  sub: '읽은 기록 ${fmtNum(_scanned)}건${_scanned >= _scanLimit ? ' (상한)' : ''}',
                  icon: Icons.format_list_numbered_rounded,
                ),
                BoKpi(
                  label: '1위 기록',
                  value: _records.isEmpty ? '-' : fmtSec(_records.first.time, digits: 2),
                  sub: _records.isEmpty ? null : nickOf(BoData.cached(_records.first.userId)),
                  icon: Icons.emoji_events_outlined,
                  color: Bo.amber,
                ),
                BoKpi(label: '참여 유저', value: fmtNum(users), sub: _bestPerUser ? '유저당 최고 기록만' : '모든 기록', icon: Icons.people_outline_rounded, color: Bo.blue),
                BoKpi(
                  label: '의심 기록',
                  value: fmtNum(suspects),
                  sub: '600초 초과 · 상위권 급격한 격차',
                  icon: Icons.report_gmailerrorred_rounded,
                  color: suspects > 0 ? Bo.red : Bo.green,
                ),
              ],
            ),
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
                        BoSegmented<String>(
                          options: [for (final s in kStages) (s.id, s.label)],
                          value: _mapId,
                          onChanged: (v) => _change(() => _mapId = v),
                        ),
                        BoSegmented<_Period>(
                          options: [for (final p in _Period.values) (p, _periodNames[p]!)],
                          value: _period,
                          onChanged: (v) => _change(() => _period = v),
                        ),
                        BoToggle(label: '유저당 최고 기록만', value: _bestPerUser, onChanged: (v) => _change(() => _bestPerUser = v)),
                      ],
                      trailing: [if (_loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))],
                    ),
                    Expanded(child: _body()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _records.isEmpty) return const BoLoading();
    if (_error != null) return BoError(error: _error!, onRetry: reload);
    return BoTable(
      scroll: true,
      columns: const [
        BoCol('순위', width: 64),
        BoCol('유저', flex: 3, minWidth: 190),
        BoCol('UID', width: 150),
        BoCol('생존 시간', width: 110, numeric: true),
        BoCol('기록 일시', width: 140),
        BoCol('시즌', width: 56, numeric: true),
        BoCol('점검', flex: 3, minWidth: 200),
        BoCol('', width: 48),
      ],
      rowCount: _records.length,
      rowTint: (i) => _suspect(i) ? Bo.dangerSoft : null,
      onRowTap: (i) => BoNav.openUser(_records[i].userId),
      empty: const BoEmpty('기간 안의 기록이 없습니다', icon: Icons.emoji_events_outlined),
      footer: BoTableFooter(
        text: '상위 ${fmtNum(_records.length)}건 표시 (최대 $_show) · 붉은 행 = 의심 기록 · 행을 누르면 유저 상세',
      ),
      cells: (i) {
        final r = _records[i];
        final u = BoData.cached(r.userId);
        final flags = _flags(i);
        return [
          _RankCell(i + 1),
          BoUserCell(
            uid: r.userId,
            data: u,
            charId: r.data['characterId'] as String?,
            showBadge: true,
            fallbackName: '${r.data['flag'] ?? ''} ${r.data['nickname'] as String? ?? '(알 수 없음)'}'.trim(),
          ),
          BoTable.text(r.userId.isEmpty ? '-' : r.userId, style: Bo.mono, tooltip: r.userId),
          BoTable.text(fmtSec(r.time), style: Bo.cellStrong, color: r.time > _suspectTime ? Bo.red : null),
          BoTable.text(fmtDateTime(r.at), style: Bo.muted),
          BoTable.text(r.data['season'] == null ? '-' : 'S${r.data['season']}', style: Bo.muted),
          flags.isEmpty
              ? const SizedBox()
              : Wrap(spacing: 4, children: [for (final f in flags) BoBadge(f.$1, color: f.$2, dense: true)]),
          IconButton(
            tooltip: '기록 삭제',
            visualDensity: VisualDensity.compact,
            onPressed: () => _delete(r),
            icon: Icon(Icons.delete_outline_rounded, color: Bo.red, size: 18),
          ),
        ];
      },
    );
  }
}

class _RankCell extends StatelessWidget {
  final int rank;
  const _RankCell(this.rank);

  @override
  Widget build(BuildContext context) {
    const medal = [Color(0xFFF2B928), Color(0xFF9FB2C8), Color(0xFFCD8B4E)];
    if (rank > 3) return Text('$rank', style: Bo.cell.copyWith(color: Bo.text2));
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: medal[rank - 1].withValues(alpha: 0.18), shape: BoxShape.circle),
      child: Text('$rank',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Bo.ink(medal[rank - 1], 0.35))),
    );
  }
}
