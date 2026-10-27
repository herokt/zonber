import 'package:flutter/material.dart';

import '../balance.dart';
import 'bo_charts.dart';
import 'bo_common.dart';
import 'runs_page.dart' show kNoRunsHint;

// ─────────────────────────────────────────────────────────────
// 대시보드 — 처음엔 **요약만**(2026-10-27): 핵심 숫자(서버 집계 count — 문서를 읽지 않는다) · 신규 가입자 최근 8명 ·
// 최근 플레이 10판. users 전체 · 7일 runs(최대 5,000판)를 읽는 분석(DAU/WAU · 일별 플레이 · 스테이지 비교 ·
// 존별 끝난 레벨 분포 · 가입 추이 · 캐릭터 · 코인)은 [상세보기] 를 눌러야 읽는다(_DashboardDetail).
// runs 쿼리는 collection group 'runs' 의 timestamp 단일 필드 색인이 필요하다(firestore.indexes.json).
// ─────────────────────────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with BoReloadable {
  static const int _signupShow = 8;
  static const int _feedShow = 10;

  // 핵심 숫자(서버 집계) — null = 아직 / 못 읽음
  bool _countsLoading = true;
  Object? _countsError;
  int? _total, _newToday, _new7, _new14, _runsToday, _runs7;

  bool _signupsLoading = true;
  Object? _signupsError;
  List<BoUser> _signups = [];

  bool _feedLoading = true;
  Object? _feedError;
  List<RunRow> _feed = [];

  /// 상세 분석을 열었나 — 열면 그때 _DashboardDetail 이 무거운 데이터를 읽는다
  bool _detail = false;

  @override
  Future<void> reload() async {
    await Future.wait([_loadCounts(), _loadSignups(), _loadFeed()]);
    BoData.markLoaded();
  }

  Future<void> _loadCounts() async {
    setState(() {
      _countsLoading = true;
      _countsError = null;
    });
    final today = startOfToday(), now = DateTime.now();
    try {
      final r = await Future.wait<int?>([
        BoData.src.usersCount(),
        BoData.src.usersCount(since: today),
        BoData.src.usersCount(since: now.subtract(const Duration(days: 7))),
        BoData.src.usersCount(since: now.subtract(const Duration(days: 14))),
        BoData.src.runsCount(today),
        BoData.src.runsCount(now.subtract(const Duration(days: 7))),
      ]);
      if (mounted) {
        setState(() {
          _total = r[0];
          _newToday = r[1];
          _new7 = r[2];
          _new14 = r[3];
          _runsToday = r[4];
          _runs7 = r[5];
        });
      }
    } catch (e) {
      debugPrint('Dashboard counts: $e');
      if (mounted) setState(() => _countsError = e);
    } finally {
      if (mounted) setState(() => _countsLoading = false);
    }
  }

  Future<void> _loadSignups() async {
    setState(() {
      _signupsLoading = true;
      _signupsError = null;
    });
    try {
      final list = await BoData.src.latestUsers('createdAt', _signupShow);
      BoData.remember(list);
      if (mounted) setState(() => _signups = list);
    } catch (e) {
      debugPrint('Dashboard signups: $e');
      if (mounted) setState(() => _signupsError = e);
    } finally {
      if (mounted) setState(() => _signupsLoading = false);
    }
  }

  Future<void> _loadFeed() async {
    setState(() {
      _feedLoading = true;
      _feedError = null;
    });
    try {
      final rows = await BoData.src.latestRuns(_feedShow);
      await BoData.lookup(rows.map((r) => r.uid));
      if (mounted) setState(() => _feed = rows);
    } catch (e) {
      debugPrint('Dashboard feed: $e');
      if (mounted) setState(() => _feedError = e);
    } finally {
      if (mounted) setState(() => _feedLoading = false);
    }
  }

  // ── 관리 도구 ──
  Future<void> _migrateDefaultCountry() async {
    if (!await confirmCode(context, '국가 기본값 설정', '국가(flag)가 없는 유저를 대한민국(🇰🇷)으로 설정합니다.\n계속하시겠습니까?',
        ok: '실행', okColor: Bo.accent)) {
      return;
    }
    if (!mounted) return;
    try {
      final updated = await runBusy(context, () => BoData.src.fillDefaultCountry());
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
        subtitle: '요약 — 자세한 분석은 아래 [상세보기]',
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
      // ListView 는 화면 밖 칸을 버렸다 다시 만든다(그러면 상세가 또 읽는다) — 한 번에 그리는 스크롤로
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _kpis(),
            const SizedBox(height: Bo.gap),
            BoGrid(
              minItemWidth: 460,
              maxColumns: 2,
              stretch: false,
              children: [_signupCard(), _feedCard()],
            ),
            const SizedBox(height: Bo.gap),
            _detail ? _DashboardDetail(onClose: () => setState(() => _detail = false)) : _detailCta(),
          ],
        ),
      ),
    );
  }

  // ── 핵심 숫자 ──
  Widget _kpis() {
    String v(int? n) => n != null ? fmtNum(n) : (_countsLoading ? '…' : '-');
    final prev7 = (_new14 != null && _new7 != null) ? _new14! - _new7! : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_countsError != null) BoError(error: _countsError!, onRetry: _loadCounts),
      BoGrid(
        minItemWidth: 190,
        children: [
          BoKpi(label: '전체 회원', value: v(_total), sub: '로그인 회원 · 서버 집계', icon: Icons.people_alt_outlined),
          BoKpi(
            label: '신규 가입 (오늘)',
            value: v(_newToday),
            sub: '오늘 0시부터',
            icon: Icons.person_add_alt_1_outlined,
            color: Bo.purple,
          ),
          BoKpi(
            label: '신규 가입 (7일)',
            value: v(_new7),
            delta: _new7 != null && prev7 != null ? deltaOf(_new7!, prev7) : null,
            deltaLabel: '이전 7일 대비',
            icon: Icons.group_add_outlined,
            color: Bo.purple,
          ),
          BoKpi(
            label: '오늘 판 수',
            value: v(_runsToday),
            sub: '7일 ${v(_runs7)}판 · 회원 판',
            icon: Icons.sports_esports_outlined,
            color: Bo.amber,
          ),
        ],
      ),
    ]);
  }

  // ── 신규 가입자 ──
  Widget _signupCard() {
    const cols = [
      BoCol('가입', width: 84),
      BoCol('유저', flex: 3, minWidth: 160),
      BoCol('로그인', width: 80),
      BoCol('플랫폼', width: 70),
    ];
    Widget body;
    if (_signupsLoading && _signups.isEmpty) {
      body = const BoLoading();
    } else if (_signupsError != null) {
      body = BoError(error: _signupsError!, onRetry: _loadSignups);
    } else {
      body = BoTable(
        columns: cols,
        rowCount: _signups.length,
        onRowTap: (i) => BoNav.openUser(_signups[i].id),
        empty: const BoEmpty('가입한 회원이 아직 없습니다', icon: Icons.person_add_alt_outlined),
        cells: (i) {
          final u = _signups[i];
          final at = tsOf(u.data['createdAt']);
          return [
            BoTable.text(timeAgo(at), style: Bo.muted, tooltip: fmtDateTime(at)),
            BoUserCell(uid: u.id, data: u.data),
            BoProviderBadge((u.data['loginProvider'] as String? ?? '').trim()),
            BoTable.text(u.data['platform'] as String? ?? '-', style: Bo.muted),
          ];
        },
      );
    }
    return BoCard(
      title: '신규 가입자',
      subtitle: '최근 $_signupShow명 · 행을 누르면 유저 상세',
      padding: EdgeInsets.zero,
      trailing: TextButton(onPressed: () => BoNav.go(BoSection.users), child: const Text('유저 전체')),
      child: body,
    );
  }

  // ── 최근 플레이 ──
  Widget _feedCard() {
    const cols = [
      BoCol('시각', width: 84),
      BoCol('유저', flex: 3, minWidth: 150),
      BoCol('스테이지', width: 130),
      BoCol('생존', width: 84, numeric: true),
      BoCol('레벨', width: 50, numeric: true),
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
          return [
            BoTable.text(timeAgo(r.at), style: Bo.muted, tooltip: fmtDateTimeSec(r.at)),
            BoUserCell(uid: r.uid, data: BoData.cached(r.uid), charId: r.character),
            BoStageCell(r.mapId),
            BoTable.text(fmtSec(r.time), style: Bo.cellStrong),
            BoTable.text('${r.level}'),
          ];
        },
      );
    }
    return BoCard(
      title: '최근 플레이',
      subtitle: '전체 회원 최신 $_feedShow판 · 행을 누르면 유저 상세',
      padding: EdgeInsets.zero,
      trailing: TextButton(onPressed: () => BoNav.go(BoSection.runs), child: const Text('플레이 기록 전체')),
      child: body,
    );
  }

  /// 상세 분석 열기 — 누르기 전에는 무거운 데이터를 읽지 않는다
  Widget _detailCta() => BoCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Icon(Icons.insights_outlined, color: Bo.text3, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('상세 분석', style: Bo.h2),
              const SizedBox(height: 2),
              Text(
                'DAU·WAU · 일별 플레이 · 스테이지별 비교 · 존별 끝난 레벨 분포 · 신규 가입 추이 · 캐릭터 사용 · 보유 코인 — '
                '회원 전체와 최근 7일 판(최대 ${fmtNum(_DashboardDetailState._runsCap)}판)을 읽어 조금 걸립니다',
                style: Bo.caption,
              ),
            ]),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => setState(() => _detail = true),
            icon: const Icon(Icons.expand_more_rounded, size: 18),
            label: const Text('상세보기'),
          ),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────
// 상세 분석 — [상세보기] 를 눌렀을 때만 만들어진다. users 전체(BoData 캐시) + 최근 7일 runs + maps.playCount.
// 접으면 사라지고(다시 열면 다시 읽는다 — users 는 캐시), 열려 있는 동안은 전역 새로고침을 따른다.
// ─────────────────────────────────────────────────────────────
class _DashboardDetail extends StatefulWidget {
  final VoidCallback onClose;
  const _DashboardDetail({required this.onClose});

  @override
  State<_DashboardDetail> createState() => _DashboardDetailState();
}

class _DashboardDetailState extends State<_DashboardDetail> with BoReloadable {
  /// 7일 runs 를 이만큼까지 읽는다(넘으면 표본 제한 표시)
  static const int _runsCap = 5000;
  static const double _chartH = 230;

  bool _usersLoading = true;
  Object? _usersError;
  List<BoUser> _users = [];

  bool _runsLoading = true;
  Object? _runsError;
  List<RunRow> _runs7d = [];

  Map<String, int> _mapPlayCounts = {};

  @override
  Future<void> reload() async {
    await Future.wait([_loadUsers(), _loadRuns(), _loadMaps()]);
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

  Future<void> _loadMaps() async {
    try {
      final m = await BoData.src.mapPlayCounts();
      if (mounted) setState(() => _mapPlayCounts = m);
    } catch (e) {
      debugPrint('Dashboard maps: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _usersLoading || _runsLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BoSectionHeader(
          '상세 분석',
          subtitle: loading
              ? '불러오는 중… (회원 전체 · 최근 7일 판)'
              : '유저 데이터 ${fmtDateTime(BoData.loadedAt)} 기준 · 최근 7일 회원 판 ${fmtNum(_runs7d.length)}${_capped ? '+' : ''}판',
          padding: const EdgeInsets.fromLTRB(4, 4, 0, 12),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (loading) const Padding(padding: EdgeInsets.only(right: 8), child: BoSpinner()),
            TextButton.icon(
              onPressed: widget.onClose,
              icon: const Icon(Icons.expand_less_rounded, size: 18),
              label: const Text('접기'),
            ),
          ]),
        ),
        _kpis(),
        const SizedBox(height: Bo.gap),
        BoGrid(
          minItemWidth: 420,
          maxColumns: 2,
          stretch: false,
          children: [_dailyCard(), _stageCard(), _levelCard(), _signupCard(), _charCard()],
        ),
      ],
    );
  }

  bool get _capped => _runs7d.length >= _runsCap;

  // ── KPI(활동·코인 — 회원 수·신규 가입은 위 요약에 있다) ──
  Widget _kpis() {
    if (_usersLoading && _users.isEmpty && _runsLoading) return const BoLoading();
    final errs = [
      if (_usersError != null) BoError(error: _usersError!, onRetry: _loadUsers),
      if (_runsError != null) BoError(error: _runsError!, onRetry: _loadRuns),
    ];
    int coinSum = 0, coinHolders = 0;
    for (final u in _users) {
      final coins = intOf(u.data['coins']);
      coinSum += coins;
      if (coins > 0) coinHolders++;
    }
    final total = _users.length;

    final now = DateTime.now();
    final today = startOfToday();
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
    final runsReady = !_runsLoading || _runs7d.isNotEmpty;
    String rv(num v) => runsReady ? fmtNum(v) : '…';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ...errs,
      BoGrid(
        minItemWidth: 190,
        children: [
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
            sub: _capped ? '표본 $_runsCap판 제한' : '최근 7일 플레이 회원',
            icon: Icons.date_range_outlined,
            color: Bo.blue,
          ),
          BoKpi(
            label: '오늘 판 수',
            value: rv(todayRuns),
            delta: runsReady ? deltaOf(todayRuns, yRunsSoFar) : null,
            deltaLabel: '어제 같은 시각 대비',
            icon: Icons.sports_esports_outlined,
            color: Bo.amber,
          ),
          BoKpi(
            label: '보유 코인 합계',
            value: _usersLoading && _users.isEmpty ? '…' : fmtNum(coinSum),
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

  // ── 존별 끝난 레벨 분포(2026-10-26) — 밸런스 확인용. docs/STAGES.md 밸런스 기록이 "다음에 판 기록으로 다시 본다"던 그 화면 ──
  Widget _levelCard() {
    final labels = [for (int l = 1; l <= Balance.maxLevel; l++) 'L$l'];
    final counts = {for (final s in kStages) s.id: List<double>.filled(Balance.maxLevel, 0)};
    final levels = {for (final s in kStages) s.id: <int>[]};
    for (final r in _runs7d) {
      final l = r.level.clamp(1, Balance.maxLevel);
      final c = counts[r.mapId];
      if (c == null) continue;
      c[l - 1] += 1;
      levels[r.mapId]!.add(l);
    }
    String median(List<int> v) {
      if (v.isEmpty) return '-';
      v.sort();
      return 'L${v[v.length ~/ 2]}';
    }
    final sub = kStages.map((s) => '${s.label} 중앙값 ${median(levels[s.id]!)}').join(' · ');
    return BoCard(
      title: '존별 끝난 레벨 분포',
      subtitle: '최근 7일 · 판이 끝난 레벨 — 한 레벨에 몰리면 그 레벨이 벽이다 · $sub',
      child: _chartBody(BoChart(
        labels: labels,
        bars: [for (final s in kStages) BoSeries(s.label, s.color, counts[s.id]!)],
        height: _chartH,
      )),
    );
  }

  // ── 신규 가입 ──
  Widget _signupCard() {
    final member = dailyCounts(_users.map((u) => tsOf(u.data['createdAt'])), 14);
    final total = member.fold<double>(0, (a, b) => a + b);
    return BoCard(
      title: '신규 가입 추이',
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
        child: _usersLoading && _users.isEmpty
            ? const BoLoading()
            : list.isEmpty
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
}
