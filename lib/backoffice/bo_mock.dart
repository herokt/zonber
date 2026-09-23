import 'dart:math';

import '../badges.dart';
import '../gear.dart';
import 'bo_catalog.dart';
import 'bo_data.dart';

// ─────────────────────────────────────────────────────────────
// 미리보기 전용 가짜 데이터 — --dart-define=BO_PREVIEW=true 일 때만 쓴다(실서비스 빌드에서는 만들지 않는다).
// 고정 시드라 매번 같은 데이터: 유저 120명 · 최근 14일 회원 판 약 600개 · 스테이지별 랭킹 기록 · 뱃지.
// 수정·지급·삭제는 메모리에만 반영된다.
// ─────────────────────────────────────────────────────────────
class MockSource implements BoSource {
  MockSource() {
    _build();
  }

  final Random _r = Random(20260922);
  final List<BoUser> _users = [];
  final Map<String, String> _emails = {};
  final List<RunRow> _runs = []; // 최신순
  final Map<String, List<BoRec>> _recs = {};
  final Map<String, int> _playCounts = {};

  static const _delay = Duration(milliseconds: 120);
  Future<T> _later<T>(T Function() f) => Future.delayed(_delay, f);

  @override
  bool get isPreview => true;

  @override
  String get adminEmail => 'preview@zonber.admin';

  @override
  Future<void> signOut() async {}

  // ── 데이터 만들기 ──
  static const _nickA = [
    '별빛', '민트초코', '도지', '번개', '새벽', '고양이', '파도', '달토끼', '하늘', '불꽃', '은하', '토마토',
    'Nova', 'Zeta', 'Pixel', 'Echo', 'Luna', 'Blaze', 'Orbit', 'Mochi', 'Ghost', 'Rapid', 'Neo', 'Kiwi',
  ];
  static const _nickB = ['러너', '마스터', '킹', '장인', '요정', '곰', 'Kid', 'Pro', 'Fox', 'X', '짱', ''];
  static const _countries = [
    ('🇰🇷', 'South Korea', 46), ('🇺🇸', 'United States', 12), ('🇯🇵', 'Japan', 10), ('🇹🇼', 'Taiwan', 5),
    ('🇩🇪', 'Germany', 4), ('🇧🇷', 'Brazil', 4), ('🇬🇧', 'United Kingdom', 4), ('🇮🇩', 'Indonesia', 4),
    ('🇫🇷', 'France', 3), ('🇻🇳', 'Vietnam', 3), ('', '', 5),
  ];

  T _pickW<T>(List<(T, int)> items) {
    final total = items.fold<int>(0, (a, e) => a + e.$2);
    var x = _r.nextInt(total);
    for (final e in items) {
      if (x < e.$2) return e.$1;
      x -= e.$2;
    }
    return items.last.$1;
  }

  DateTime _ago(double days) => DateTime.now().subtract(Duration(minutes: (days * 1440).round()));

  void _build() {
    final chars = kCharNames.keys.toList();
    final items = allGrantableItems();
    final engagement = <String, double>{};

    for (int i = 0; i < 120; i++) {
      final id = 'mock_$i';
      final eng = pow(_r.nextDouble(), 1.6).toDouble(); // 0~1, 대부분 낮음
      engagement[id] = eng;
      final provider = _pickW<String>([('Google', 70), ('Apple', 25), ('Email', 5)]);
      final country = _pickW([for (final c in _countries) ((c.$1, c.$2), c.$3)]);
      final created = _ago(pow(_r.nextDouble(), 1.8) * 90);
      final sinceCreated = DateTime.now().difference(created).inMinutes / 1440;
      final last = _ago(_r.nextDouble() * sinceCreated * (1 - eng * 0.9));
      final games = (eng * 900 + _r.nextInt(12)).round();
      final playTime = games * (35 + _r.nextDouble() * 60);
      final ch = chars[_r.nextInt(chars.length)];
      final owned = <String>{'char_$ch'};
      final nOwned = (eng * 26).round();
      while (owned.length < nOwned + 1) {
        owned.add(items[_r.nextInt(items.length)]);
      }
      final equipped = <String, String>{};
      for (final s in kStages) {
        for (final slot in Gear.slotsOf(s.id)) {
          final cands = Gear.itemsOf(s.id, slot).where((g) => owned.contains(g.id)).toList();
          if (cands.isNotEmpty && _r.nextDouble() < 0.8) equipped[Gear.slotKey(s.id, slot)] = cands[_r.nextInt(cands.length)].id;
        }
      }
      for (final k in const ['skin', 'trail', 'aura']) {
        final cands = kCosmetics.where((c) => c.kind == k && owned.contains(c.id)).toList();
        if (cands.isNotEmpty) equipped[k] = cands[_r.nextInt(cands.length)].id;
      }
      final best = <String, double>{};
      for (final s in kStages) {
        if (_r.nextDouble() < 0.35 + eng * 0.65) best[s.id] = 15 + eng * 220 * (0.5 + _r.nextDouble());
      }
      final badges = <String>[];
      for (final b in Badges.all) {
        final p = switch (b.tier) { 1 => 0.25 + eng * 0.7, 2 => 0.06 + eng * 0.55, 3 => eng * 0.35, _ => eng * eng * 0.15 };
        if (_r.nextDouble() < p) badges.add(b.key);
      }
      final charCounts = <String, int>{};
      var left = games;
      for (final c in chars) {
        if (left <= 0) break;
        final n = c == ch ? (left * 0.6).round() : _r.nextInt(left + 1) ~/ 3;
        if (n > 0) charCounts[c] = n;
        left -= n;
      }
      final today = startOfToday();
      final nick = '${_nickA[_r.nextInt(_nickA.length)]}${_nickB[_r.nextInt(_nickB.length)]}${_r.nextDouble() < 0.4 ? _r.nextInt(99) : ''}';
      final data = <String, dynamic>{
        'nickname': i == 7 ? '' : nick,
        'flag': country.$1,
        'countryName': country.$2,
        'loginProvider': provider,
        'platform': _pickW([('android', 55), ('ios', 35), ('web', 10)]),
        'characterId': ch,
        'createdAt': created,
        'lastUpdated': last,
        'coins': (pow(_r.nextDouble(), 2.2) * 2600).round(),
        'totalGamesPlayed': games,
        'totalPlayTime': playTime,
        'ownedItems': owned.toList(),
        'equipped': equipped,
        'bestTimes': best,
        'achievements': badges,
        'nicknameTickets': _r.nextInt(3),
        'countryTickets': _r.nextInt(2),
        'adsRemoved': _r.nextDouble() < 0.08,
        'characterPlayCounts': charCounts,
        'badgeStats': {
            'runs': games,
            'playTime': playTime,
            'newBests': (games * 0.04).round(),
            'allClearDays': (eng * 25).round(),
          },
        if (_r.nextDouble() < 0.7)
          'daily': {
            'date': fmtDate(today),
            'progress': {'runs3': _r.nextInt(4), 'time180': _r.nextInt(200), 's2_25': _r.nextInt(2)},
            'claimed': [if (_r.nextBool()) 'runs3'],
            'bonus': false,
            'attLast': fmtDate(today.subtract(Duration(days: _r.nextInt(2)))),
            'attStreak': (eng * 40).round(),
          },
      };
      _emails[id] = '${nick.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}$i@example.com';
      _users.add(BoUser(id, data));
    }

    // ── 최근 14일 판(약 600) — 최근일수록 조금 많다 ──
    final weighted = [
      for (final u in _users) (u, 1 + (engagement[u.id]! * 30).round()),
    ];
    for (int n = 0; n < 600; n++) {
      final u = _pickW(weighted);
      final d = u.data;
      final stage = kStages[_pickW([(0, 45), (1, 32), (2, 23)])];
      final eng = engagement[u.id]!;
      final t = 8 + pow(_r.nextDouble(), 1.7) * (60 + eng * 200);
      final days = 14 * pow(_r.nextDouble(), 1.25);
      _runs.add(RunRow.fromMap('run_$n', u.id, {
        'stage': stage.no,
        'mapId': stage.id,
        'time': t,
        'level': 1 + t ~/ 15,
        'stat': stage.stat,
        'statCount': (t / 6 * _r.nextDouble()).round(),
        'coins': (t / 3).round(),
        'bonus': _r.nextDouble() < 0.15 ? 10 + _r.nextInt(20) : 0,
        'revive': _r.nextDouble() < 0.12 ? 1 : 0,
        'character': d['characterId'],
        'gear': [
          for (final slot in Gear.slotsOf(stage.id))
            if ((d['equipped'] as Map)[Gear.slotKey(stage.id, slot)] != null) (d['equipped'] as Map)[Gear.slotKey(stage.id, slot)],
        ],
        'skin': (d['equipped'] as Map)['skin'] ?? '',
        'best': _r.nextDouble() < 0.08,
        'platform': d['platform'],
        'timestamp': _ago(days.toDouble()),
      }));
    }
    // 유저 문서가 없는 판(삭제된 계정)
    _runs.add(RunRow.fromMap('run_orphan', 'mock_deleted_1', {
      'stage': 1, 'mapId': 'cyber', 'time': 41.2, 'level': 3, 'coins': 13, 'character': 'void_dark',
      'timestamp': _ago(0.3),
    }));
    _runs.sort((a, b) => (b.at ?? DateTime(0)).compareTo(a.at ?? DateTime(0)));

    // ── 랭킹 기록 ──
    for (final s in kStages) {
      final list = <BoRec>[];
      for (final u in _users) {
        final b = (u.data['bestTimes'] as Map)[s.id];
        if (b == null) continue;
        final n = 1 + _r.nextInt(3);
        for (int k = 0; k < n; k++) {
          list.add(_rec(s.id, u, k == 0 ? b as double : (b as double) * (0.5 + _r.nextDouble() * 0.45), _r.nextDouble() * 40));
        }
      }
      _recs[s.id] = list;
      _playCounts[s.id] = 4000 + _r.nextInt(9000);
    }
    // 의심 기록 몇 개
    _recs['cyber']!.add(_rec('cyber', _users[11], 742.5, 1.2));
    _recs['dodgeball']!.add(_rec('dodgeball', _users[23], 690.1, 3));
    _recs['cyber']!.add(BoRec('rec_orphan', 'cyber', {
      'userId': 'mock_deleted_1', 'survivalTime': 120.4, 'timestamp': _ago(2), 'nickname': '탈퇴한유저', 'flag': '🇰🇷',
      'characterId': 'void_dark', 'season': 0,
    }));
  }

  int _recN = 0;
  BoRec _rec(String mapId, BoUser u, double time, double daysAgo) => BoRec('rec_${_recN++}', mapId, {
        'userId': u.id,
        'survivalTime': time,
        'timestamp': _ago(daysAgo),
        'nickname': u.data['nickname'],
        'flag': _r.nextDouble() < 0.9 ? u.data['flag'] : '',
        'characterId': u.data['characterId'],
        'season': 0,
      });

  // ── 유저 ──
  @override
  Future<List<BoUser>> users() => _later(() => List.of(_users));

  BoUser? _find(String uid) {
    for (final u in _users) {
      if (u.id == uid) return u;
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> user(String uid) => _later(() => _find(uid)?.data);

  @override
  Future<String> privateEmail(String uid) => _later(() => _emails[uid] ?? '');

  @override
  Future<void> updateUser(String uid, Map<String, dynamic> fields) => _later(() => _find(uid)?.data.addAll(fields));

  @override
  Future<void> grantItem(String uid, String itemId) => _later(() {
        final d = _find(uid)?.data;
        if (d == null) return;
        final owned = ((d['ownedItems'] as List?) ?? const []).map((e) => '$e').toList();
        if (!owned.contains(itemId)) owned.add(itemId);
        d['ownedItems'] = owned;
      });

  @override
  Future<void> grantCoins(String uid, int amount) => _later(() {
        final d = _find(uid)?.data;
        if (d == null) return;
        d['coins'] = max(0, intOf(d['coins']) + amount);
      });

  @override
  Future<void> deleteUser(String uid) => _later(() => _users.removeWhere((u) => u.id == uid));

  // ── runs ──
  Iterable<RunRow> _since(DateTime since) => _runs.where((r) => r.at != null && !r.at!.isBefore(since));

  @override
  Future<List<RunRow>> runsSince(DateTime since, int limit) => _later(() => _since(since).take(limit).toList());

  @override
  Future<List<RunRow>> latestRuns(int limit) => _later(() => _runs.take(limit).toList());

  BoChunk<RunRow> _page(List<RunRow> all, Object? cursor, int limit) {
    final start = cursor is int ? cursor : 0;
    final items = all.skip(start).take(limit).toList();
    return BoChunk(items, start + items.length, items.length == limit);
  }

  @override
  Future<BoChunk<RunRow>> runsPage(DateTime since, Object? cursor, int limit) =>
      _later(() => _page(_since(since).toList(), cursor, limit));

  @override
  Future<int?> runsCount(DateTime since) => _later(() => _since(since).length);

  @override
  Future<BoChunk<RunRow>> userRunsPage(String uid, Object? cursor, int limit) =>
      _later(() => _page(_runs.where((r) => r.uid == uid).toList(), cursor, limit));

  @override
  Future<List<RunRow>> userRunsSince(String uid, DateTime since, int limit) =>
      _later(() => _since(since).where((r) => r.uid == uid).take(limit).toList());

  @override
  Future<Map<String, int>> mapPlayCounts() => _later(() => Map.of(_playCounts));

  // ── 랭킹 기록 ──
  @override
  Future<List<BoRec>> records(String mapId, DateTime? since, int limit) => _later(() {
        final list = _recs[mapId] ?? const <BoRec>[];
        if (since == null) {
          return ([...list]..sort((a, b) => b.time.compareTo(a.time))).take(limit).toList();
        }
        return list.where((r) => r.at != null && !r.at!.isBefore(since)).take(limit).toList();
      });

  @override
  Future<List<BoRec>> userRecords(String mapId, String uid, int limit) =>
      _later(() => (_recs[mapId] ?? const <BoRec>[]).where((r) => r.userId == uid).take(limit).toList());

  @override
  Future<void> deleteRecord(BoRec r) => _later(() => _recs[r.mapId]?.removeWhere((e) => e.id == r.id));

  // ── 관리 도구 ──
  @override
  Future<int> fillDefaultCountry() => _later(() {
        int n = 0;
        for (final u in _users) {
          if ((u.data['flag'] as String? ?? '').isEmpty) {
            u.data['flag'] = '🇰🇷';
            u.data['countryName'] = 'South Korea';
            n++;
          }
        }
        return n;
      });
}
