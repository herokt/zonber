import 'package:flutter/material.dart';

import 'bo_charts.dart';
import 'bo_common.dart';
import 'runs_page.dart' show kNoRunsHint;

// ─────────────────────────────────────────────────────────────
// 대시보드 — KPI 줄 → 차트 2열(일별 플레이 · 스테이지 비교 · 신규 가입 · 캐릭터 사용) → 최근 플레이 표.
// 데이터: users 전체(BoData 캐시) + runs(collection group, 최근 7일, 회원 판만 기록됨) + 최신 30판 + maps.playCount.
// runs 쿼리는 collection group 'runs' 의 timestamp 단일 필드 색인이 필요하다(firestore.indexes.json).
// ─────────────────────────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with BoReloadable {
  /// 7일 runs 를 이만큼까지 읽는다(넘으면 표본 제한 표시)
  static const int _runsCap = 5000;
  static const double _chartH = 230;

  bool _usersLoading = true;
  Object? _usersError;
  List<BoUser> _users = [];

  bool _runsLoading = true;
  Object? _runsError;
  List<RunRow> _runs7d = [];

  bool _feedLoading = true;
  Object? _feedError;
  List<RunRow> _feed = [];

  Map<String, int> _mapPlayCounts = {};

  @override
  Future<void> reload() async {
    await Future.wait([_loadUsers(), _loadRuns(), _loadFeed(), _loadMaps()]);
    BoData.markLoaded();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _usersLoading = true;
      _usersError = null;
    });
    try {
      final u = await BoData.users();
      if (mounted) setState(() => _users = u);
    } catch (e) {
      debugPrint('Dashboard users: $e');
      if (mounted) setState(() => _usersError = e);
    } finally {
      if (mounted) setState(() => _usersLoading = false);
    }
  }

  Future<void> _loadRuns() async {
    setState(() {
      _runsLoading = true;
      _runsError = null;
    });
    try {
      final rows = await BoData.src.runsSince(DateTime.now().subtract(const Duration(days: 7)), _runsCap);
      if (mounted) setState(() => _runs7d = rows);
    } catch (e) {
      debugPrint('Dashboard runs: $e');
      if (mounted) setState(() => _runsError = e);
    } finally {
      if (mounted) setState(() => _runsLoading = false);
    }
  }

  Future<void> _loadFeed() async {
    setState(() {
      _feedLoading = true;
      _feedError = null;
    });
    try {
      final rows = await BoData.src.latestRuns(30);
      await BoData.lookup(rows.map((r) => r.uid));
      if (mounted) setState(() => _feed = rows);
    } catch (e) {
      debugPrint('Dashboard feed: $e');
      if (mounted) setState(() => _feedError = e);
    } finally {
      if (mounted) setState(() => _feedLoading = false);
    }
  }

  Future<void> _loadMaps() async {
    try {
      final m = await BoData.src.mapPlayCounts();
      if (mounted) setState(() => _mapPlayCounts = m);
    } catch (e) {
      debugPrint('Dashboard maps: $e');
    }
  }

  // ── 관리 도구 ──
  Future<void> _migrateDefaultCountry() async {
    if (!await confirmCode(context, '국가 기본값 설정', '국가(flag)가 없는 유저를 대한민국(🇰🇷)으로 설정합니다.\n계속하시겠습니까?',
        ok: '실행', okColor: Bo.accent)) {
      return;
    }
    try {
      final updated = await BoData.src.fillDefaultCountry();
      if (mounted) toast(context, '완료: $updated명 업데이트됨');
      BoData.refreshAll();
    } catch (e) {
      if (mounted) toast(context, '오류: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BoPage(
      topBar: BoTopBar(
        title: '대시보드',
        breadcrumb: const ['개요'],
        subtitle: BoData.loadedAt == null ? null : '유저 데이터 ${fmtDateTime(BoData.loadedAt)} 기준',
        actions: [
          PopupMenuButton<String>(
            tooltip: '관리 도구',
            position: PopupMenuPosition.under,
            onSelected: (_) => _migrateDefaultCountry(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'country', height: 36, child: Text('국가 없는 유저 → 대한민국')),
            ],
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.build_outlined, size: 17, color: Bo.text2),
                SizedBox(width: 6),
                Text('관리 도구', style: TextStyle(fontSize: 13, color: Bo.text2, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _kpis(),
          const SizedBox(height: Bo.gap),
          BoGrid(
            minItemWidth: 420,
            maxColumns: 2,
            stretch: false,
            children: [_dailyCard(), _stageCard(), _signupCard(), _charCard()],
          ),
          const SizedBox(height: Bo.gap),
          _feedCard(),
        ],
      ),
    );
  }

  // ── KPI ──
  Widget _kpis() {
    if (_usersLoading && _users.isEmpty && _runsLoading) return const BoLoading();
    final errs = [
      if (_usersError != null) BoError(error: _usersError!, onRetry: _loadUsers),
      if (_runsError != null) BoError(error: _runsError!, onRetry: _loadRuns),
    ];
    final now = DateTime.now();
    final today = startOfToday();
    final w1 = now.subtract(const Duration(days: 7)), w2 = now.subtract(const Duration(days: 14));
    int newToday = 0, new7 = 0, newPrev7 = 0, coinSum = 0, coinHolders = 0;
    for (final u in _users) {
      final d = u.data;
      final c = tsOf(d['createdAt']);
      if (c != null) {
        if (!c.isBefore(today)) newToday++;
        if (c.isAfter(w1)) {
          new7++;
        } else if (c.isAfter(w2)) {
          newPrev7++;
        }
      }
      final coins = intOf(d['coins']);
      coinSum += coins;
      if (coins > 0) coinHolders++;
    }
    final total = _users.length;

    final d1 = now.subtract(const Duration(hours: 24)), d2 = now.subtract(const Duration(hours: 48));
    final yesterdaySameTime = now.subtract(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));
    final dau = <String>{}, dauPrev = <String>{}, wau = <String>{};
    int todayRuns = 0, yRunsSoFar = 0;
    for (final r in _runs7d) {
      wau.add(r.uid);
      final at = r.at;
      if (at == null) continue;
      if (at.isAfter(d1)) {
        dau.add(r.uid);
      } else if (at.isAfter(d2)) {
        dauPrev.add(r.uid);
      }
      if (!at.isBefore(today)) todayRuns++;
      if (!at.isBefore(yesterday) && at.isBefore(yesterdaySameTime)) yRunsSoFar++;
    }
    final capped = _runs7d.length >= _runsCap;
    final runsReady = !_runsLoading || _runs7d.isNotEmpty;
    String rv(num v) => runsReady ? fmtNum(v) : '…';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ...errs,
      BoGrid(
        minItemWidth: 170,
        children: [
          BoKpi(
            label: '전체 유저',
            value: fmtNum(total),
            sub: '로그인 회원',
            icon: Icons.people_alt_outlined,
          ),
          BoKpi(
            label: '신규 가입 (7일)',
            value: fmtNum(new7),
            delta: deltaOf(new7, newPrev7),
            deltaLabel: '이전 7일 대비',
            sub: '오늘 ${fmtNum(newToday)}명',
            icon: Icons.person_add_alt_outlined,
            color: Bo.purple,
          ),
          BoKpi(
            label: 'DAU (24시간)',
            value: rv(dau.length),
            delta: runsReady ? deltaOf(dau.length, dauPrev.length) : null,
            deltaLabel: '전일 대비',
            sub: '판을 끝낸 회원 수',
            icon: Icons.today_outlined,
            color: Bo.green,
          ),
          BoKpi(
            label: 'WAU (7일)',
            value: rv(wau.length),
            sub: capped ? '표본 $_runsCap판 제한' : '최근 7일 플레이 회원',
            icon: Icons.date_range_outlined,
            color: Bo.blue,
          ),
          BoKpi(
            label: '오늘 판 수',
            value: rv(todayRuns),
            delta: runsReady ? deltaOf(todayRuns, yRunsSoFar) : null,
            deltaLabel: '어제 같은 시각 대비',
            sub: '7일 ${fmtNum(_runs7d.length)}${capped ? '+' : ''}판',
            icon: Icons.sports_esports_outlined,
            color: Bo.amber,
          ),
          BoKpi(
            label: '보유 코인 합계',
            value: fmtNum(coinSum),
            sub: '평균 ${total == 0 ? 0 : (coinSum / total).toStringAsFixed(1)} · 보유자 ${fmtNum(coinHolders)}명',
            icon: Icons.monetization_on_outlined,
            color: Bo.coin,
          ),
        ],
      ),
    ]);
  }

  Widget _chartBody(Widget child, {bool runs = true}) {
    if (runs && _runsLoading && _runs7d.isEmpty) return const SizedBox(height: _chartH, child: BoLoading());
    if (runs && _runsError != null) return const SizedBox(height: _chartH, child: BoEmpty('플레이 기록을 불러오지 못했습니다'));
    return SizedBox(height: _chartH, child: child);
  }

  // ── 일별 플레이 ──
  Widget _dailyCard() {
    final today = startOfToday();
    final runs = dailyCounts(_runs7d.map((r) => r.at), 7);
    final users = List<Set<String>>.generate(7, (_) => <String>{});
    for (final r in _runs7d) {
      if (r.at == null) continue;
      final i = 6 - today.difference(dayOf(r.at!)).inDays;
      if (i >= 0 && i < 7) users[i].add(r.uid);
    }
    final total = runs.fold<double>(0, (a, b) => a + b);
    return BoCard(
      title: '일별 플레이',
      subtitle: '최근 7일(날짜별) · ${fmtNum(total)}판 · 회원 판 기준',
      child: _chartBody(BoChart(
        labels: dayLabels(7),
        bars: [BoSeries('판 수', Bo.accent.withValues(alpha: 0.85), runs)],
        line: BoSeries('플레이 유저', Bo.amber, [for (final s in users) s.length.toDouble()]),
        height: _chartH - 28,
      )),
    );
  }

  // ── 스테이지 비교 ──
  Widget _stageCard() {
    final today = startOfToday();
    final week = {for (final s in kStages) s.id: StageAgg()};
    final todayAgg = {for (final s in kStages) s.id: StageAgg()};
    for (final r in _runs7d) {
      week[r.mapId]?.add(r);
      if (r.at != null && !r.at!.isBefore(today)) todayAgg[r.mapId]?.add(r);
    }
    final maxRuns = week.values.fold<int>(0, (m, a) => a.runs > m ? a.runs : m).toDouble();
    Widget head(String t, {bool num = true, int flex = 2}) =>
        Expanded(flex: flex, child: Text(t, style: Bo.th, textAlign: num ? TextAlign.right : TextAlign.left));
    Widget cell(String t, {int flex = 2, TextStyle? style}) =>
        Expanded(flex: flex, child: Text(t, style: style ?? Bo.cell, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis));
    return BoCard(
      title: '스테이지별 비교',
      subtitle: '최근 7일 판 수 · 평균/최고 생존 · 오늘 · 누적(maps.playCount)',
      child: _chartBody(Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 34,
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Bo.line))),
            child: Row(children: [
              head('스테이지', num: false, flex: 5),
              head('유저'),
              head('평균'),
              head('최고'),
              head('오늘'),
              head('누적', flex: 3),
            ]),
          ),
          for (final s in kStages)
            Expanded(
              child: Container(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Bo.lineSoft))),
                child: Row(children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(s.label, style: Bo.cellStrong, overflow: TextOverflow.ellipsis)),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(child: BoBarTrack(ratio: maxRuns <= 0 ? 0 : week[s.id]!.runs / maxRuns, color: s.color, height: 6)),
                          const SizedBox(width: 8),
                          Text('${fmtNum(week[s.id]!.runs)}판', style: Bo.muted),
                        ]),
                      ],
                    ),
                  ),
                  cell(fmtNum(week[s.id]!.users.length)),
                  cell(fmtSec(week[s.id]!.avg, digits: 1)),
                  cell(fmtSec(week[s.id]!.best, digits: 1), style: Bo.cellStrong),
                  cell(fmtNum(todayAgg[s.id]!.runs)),
                  cell(fmtNum(_mapPlayCounts[s.id] ?? 0), flex: 3, style: Bo.muted),
                ]),
              ),
            ),
        ],
      )),
    );
  }

  // ── 신규 가입 ──
  Widget _signupCard() {
    final member = dailyCounts(_users.map((u) => tsOf(u.data['createdAt'])), 14);
    final total = member.fold<double>(0, (a, b) => a + b);
    return BoCard(
      title: '신규 가입',
      subtitle: '최근 14일 · ${fmtNum(total)}명 (users.createdAt)',
      child: _usersLoading && _users.isEmpty
          ? const SizedBox(height: _chartH, child: BoLoading())
          : SizedBox(
              height: _chartH,
              child: BoChart(
                labels: dayLabels(14),
                bars: [BoSeries('회원', Bo.accent.withValues(alpha: 0.85), member)],
                height: _chartH - 28,
              ),
            ),
    );
  }

  // ── 캐릭터 사용 ──
  Widget _charCard() {
    final counts = <String, int>{};
    for (final u in _users) {
      final m = u.data['characterPlayCounts'];
      if (m is Map) m.forEach((k, v) => counts['$k'] = (counts['$k'] ?? 0) + intOf(v));
    }
    final list = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = list.fold<int>(0, (a, e) => a + e.value);
    return BoCard(
      title: '캐릭터 사용',
      subtitle: '누적 판 수 (users.characterPlayCounts 합)',
      child: SizedBox(
        height: _chartH,
        child: list.isEmpty
            ? const BoEmpty('캐릭터 사용 기록 없음')
            : Center(
                child: BoDonut(
                  size: 150,
                  center: fmtNum(total),
                  centerSub: '판',
                  slices: [for (final e in list) BoSlice(charName(e.key), e.value.toDouble(), charColor(e.key))],
                ),
              ),
      ),
    );
  }

  // ── 최근 플레이 ──
  Widget _feedCard() {
    const cols = [
      BoCol('시각', width: 96),
      BoCol('유저', flex: 3, minWidth: 180),
      BoCol('스테이지', width: 150),
      BoCol('생존', width: 100, numeric: true),
      BoCol('레벨', width: 60, numeric: true),
      BoCol('추가 기록', flex: 2, minWidth: 120),
      BoCol('코인', width: 100, numeric: true),
      BoCol('신기록', width: 56),
    ];
    Widget body;
    if (_feedLoading && _feed.isEmpty) {
      body = const BoLoading();
    } else if (_feedError != null) {
      body = BoError(error: _feedError!, onRetry: _loadFeed);
    } else {
      body = BoTable(
        columns: cols,
        rowCount: _feed.length,
        onRowTap: (i) => BoNav.openUser(_feed[i].uid),
        empty: const BoEmpty('플레이 기록이 아직 없습니다', hint: kNoRunsHint),
        cells: (i) {
          final r = _feed[i];
          final u = BoData.cached(r.uid);
          return [
            BoTable.text(timeAgo(r.at), style: Bo.muted, tooltip: fmtDateTimeSec(r.at)),
            BoUserCell(uid: r.uid, data: u, charId: r.character),
            BoStageCell(r.mapId),
            BoTable.text(fmtSec(r.time), style: Bo.cellStrong),
            BoTable.text('${r.level}'),
            BoTable.text(r.statText, style: Bo.muted),
            BoTable.text(r.coinText, color: Bo.coin),
            r.best ? Icon(Icons.star_rounded, color: Bo.amber, size: 17) : const SizedBox(),
          ];
        },
      );
    }
    return BoCard(
      title: '최근 플레이',
      subtitle: '전체 회원 최신 30판 · 행을 누르면 유저 상세',
      padding: EdgeInsets.zero,
      trailing: TextButton(onPressed: () => BoNav.go(BoSection.runs), child: const Text('플레이 기록 전체 보기')),
      child: body,
    );
  }
}
