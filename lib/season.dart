import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'store_shot.dart';

// ─────────────────────────────────────────────────────────────
// 시즌 — 랭킹의 단위(2026-10-26 백오피스 설정으로). 주간·월간은 없다 — 랭킹은 **시즌 하나**뿐이다.
//
// Firestore config/season 한 문서(백오피스 › 시즌 에서 쓰고, 앱이 읽는다 — 누구나):
//   { mode: 'year'|'quarter'|'month'|'days', firstStart: Timestamp, offsetHours: 9, periodDays: 90,
//     pushDays: [30, 10, 3], pushHour: 18, updatedAt, updatedBy }
//   mode        연간(1월 1일~12월 31일) · 분기(1·4·7·10월 1일) · 월간 · N일마다([periodDays], [firstStart] 부터)
//   firstStart  시즌 1 이 시작하는 순간 — 그 전은 시즌 0(프리시즌, 지금까지의 기록 전부)
//   offsetHours 시즌 경계를 자르는 시간대(UTC+h). 9 = 한국 자정. 어느 나라에서나 같은 순간에 바뀐다
//   pushDays    마감 n일 전에 자동 푸시(functions/season.js) · pushHour = 그 시간대의 몇 시에
//
// 시즌 계산([SeasonConfig.seasonAt])은 functions/logic.js seasonAt 과 **같은 식**이어야 한다 — 바꾸면 둘 다 고친다.
// 시즌이 끝나면 서버 함수가 존별 TOP 3 를 hall_of_fame/{시즌 id} 에 남긴다(명예의 전당, lib/pages/hall_of_fame_page.dart).
// 새 기록에는 season = 시즌 id(문자열) 를 남긴다. 옛 기록의 정수 season(0·1)은 그대로 둔다.
// ─────────────────────────────────────────────────────────────

enum SeasonMode { year, quarter, month, days }

SeasonMode seasonModeOf(String? s) => SeasonMode.values.firstWhere((m) => m.name == s, orElse: () => SeasonMode.year);

/// 지금(또는 어느 순간)의 시즌 — 시작·끝은 UTC 순간(끝은 포함하지 않는다)
@immutable
class SeasonInfo {
  /// 0 = 프리시즌(시즌 1 전), 1부터 정식
  final int number;
  /// 기록 문서의 season 값 · 명예의 전당 문서 id — 연간 '2026' · 분기 '2026Q4' · 월간 '2026-10' · N일 'S3' · 프리시즌 'S0'
  final String id;
  final DateTime start;
  final DateTime end;
  final SeasonMode mode;
  const SeasonInfo({required this.number, required this.id, required this.start, required this.end, required this.mode});

  bool get isPreSeason => number == 0;
  Duration get left => end.difference(Season.clock());

  /// 마감까지 남은 날(올림, 0 = 오늘)
  int get daysLeft {
    final l = left;
    if (l.isNegative) return 0;
    return (l.inMinutes / (24 * 60)).ceil();
  }

  /// 사람이 읽는 짧은 이름 — '2026' · '2026 Q4' · '2026.10' · 'S3'. 번역 키 season_name 의 {s} 에 넣는다
  String get label => switch (mode) {
        SeasonMode.year => id,
        SeasonMode.quarter => id.replaceFirst('Q', ' Q'),
        SeasonMode.month => id.replaceFirst('-', '.'),
        SeasonMode.days => id,
      };

  @override
  bool operator ==(Object other) => other is SeasonInfo && other.id == id && other.start == start && other.end == end;
  @override
  int get hashCode => Object.hash(id, start, end);
}

@immutable
class SeasonConfig {
  static const String collection = 'config';
  static const String docId = 'season';

  final SeasonMode mode;
  /// 시즌 1 시작(UTC 순간)
  final DateTime firstStart;
  /// 경계 시간대(UTC+h)
  final int offsetHours;
  /// days 모드의 한 시즌 길이(일)
  final int periodDays;
  /// 마감 n일 전 자동 푸시
  final List<int> pushDays;
  /// 푸시를 보내는 시(0~23, [offsetHours] 시간대)
  final int pushHour;
  final DateTime? updatedAt;
  final String updatedBy;

  const SeasonConfig({
    this.mode = SeasonMode.year,
    required this.firstStart,
    this.offsetHours = 0,
    this.periodDays = 90,
    this.pushDays = const [30, 10, 3],
    this.pushHour = 18,
    this.updatedAt,
    this.updatedBy = '',
  });

  /// 설정 문서가 없을 때 — 연간, 시즌 1 = 2026-11-01 UTC(2.1.2 와 함께 랭킹을 새로 시작)
  static final SeasonConfig defaults = SeasonConfig(firstStart: DateTime.utc(2026, 11, 1));

  Duration get _off => Duration(hours: offsetHours);
  DateTime _toS(DateTime utc) => utc.add(_off); // 시즌 시간대의 벽시계(UTC DateTime 으로 표현)
  DateTime _fromS(DateTime s) => s.subtract(_off);

  /// [nowUtc] 순간의 시즌
  SeasonInfo seasonAt(DateTime nowUtc) {
    final now = nowUtc.toUtc();
    if (now.isBefore(firstStart)) {
      return SeasonInfo(number: 0, id: 'S0', start: DateTime.utc(2000), end: firstStart, mode: mode);
    }
    final s = _toS(now);
    final fs = _toS(firstStart);
    DateTime startS, endS;
    String id;
    int number;
    switch (mode) {
      case SeasonMode.year:
        startS = DateTime.utc(s.year, 1, 1);
        endS = DateTime.utc(s.year + 1, 1, 1);
        id = '${s.year}';
        number = s.year - fs.year + 1;
      case SeasonMode.quarter:
        final q = (s.month - 1) ~/ 3;
        startS = DateTime.utc(s.year, q * 3 + 1, 1);
        endS = DateTime.utc(s.year, q * 3 + 4, 1);
        id = '${s.year}Q${q + 1}';
        number = (s.year - fs.year) * 4 + q - (fs.month - 1) ~/ 3 + 1;
      case SeasonMode.month:
        startS = DateTime.utc(s.year, s.month, 1);
        endS = DateTime.utc(s.year, s.month + 1, 1);
        id = '${s.year}-${s.month.toString().padLeft(2, '0')}';
        number = (s.year - fs.year) * 12 + s.month - fs.month + 1;
      case SeasonMode.days:
        final len = Duration(days: periodDays < 1 ? 1 : periodDays);
        final n = s.difference(fs).inMilliseconds ~/ len.inMilliseconds;
        startS = fs.add(len * n);
        endS = startS.add(len);
        id = 'S${n + 1}';
        number = n + 1;
    }
    if (startS.isBefore(fs)) startS = fs; // 첫 시즌은 시즌 1 시작부터
    return SeasonInfo(number: number, id: id, start: _fromS(startS), end: _fromS(endS), mode: mode);
  }

  /// [info] 바로 앞 시즌(프리시즌이면 null)
  SeasonInfo? previous(SeasonInfo info) => info.number <= 0 ? null : seasonAt(info.start.subtract(const Duration(milliseconds: 1)));

  /// [info] 다음 시즌
  SeasonInfo next(SeasonInfo info) => seasonAt(info.end);

  /// 마감 전 푸시가 나가는 순간들(UTC) — pushDays 일 전, 시즌 시간대 pushHour 시
  List<(int days, DateTime at)> pushMoments(SeasonInfo info) {
    final endS = _toS(info.end);
    return [
      for (final d in pushDays)
        (d, _fromS(DateTime.utc(endS.year, endS.month, endS.day - d, pushHour))),
    ];
  }

  Map<String, Object> toMap() => {
        'mode': mode.name,
        'firstStart': Timestamp.fromDate(firstStart),
        'offsetHours': offsetHours,
        'periodDays': periodDays,
        'pushDays': pushDays,
        'pushHour': pushHour,
      };

  /// Firestore 문서 · 기기 캐시(JSON, firstStart 는 ISO) 둘 다 받는다
  static SeasonConfig fromMap(Map<String, dynamic>? d) {
    if (d == null) return defaults;
    final fsRaw = d['firstStart'];
    final fs = fsRaw is Timestamp
        ? fsRaw.toDate().toUtc()
        : fsRaw is String
            ? (DateTime.tryParse(fsRaw)?.toUtc() ?? defaults.firstStart)
            : defaults.firstStart;
    final updRaw = d['updatedAt'];
    return SeasonConfig(
      mode: seasonModeOf(d['mode'] as String?),
      firstStart: fs,
      offsetHours: ((d['offsetHours'] as num?)?.toInt() ?? 0).clamp(-12, 14),
      periodDays: ((d['periodDays'] as num?)?.toInt() ?? 90).clamp(1, 3660),
      pushDays: (d['pushDays'] as List?)?.whereType<num>().map((n) => n.toInt()).where((n) => n > 0).toList() ?? const [30, 10, 3],
      pushHour: ((d['pushHour'] as num?)?.toInt() ?? 18).clamp(0, 23),
      updatedAt: updRaw is Timestamp ? updRaw.toDate() : null,
      updatedBy: d['updatedBy'] as String? ?? '',
    );
  }

  Map<String, Object> toCache() => {
        'mode': mode.name,
        'firstStart': firstStart.toIso8601String(),
        'offsetHours': offsetHours,
        'periodDays': periodDays,
        'pushDays': pushDays,
        'pushHour': pushHour,
      };
}

/// 명예의 전당 한 시즌 — hall_of_fame/{시즌 id}, 서버 함수(functions/season.js)가 시즌이 끝나면 쓴다
@immutable
class HallOfFameSeason {
  final String id;
  final int number;
  final SeasonMode mode;
  final DateTime? start;
  final DateTime? end;
  /// 존(rankingMapId) → TOP 3 기록 {userId, nickname, flag, survivalTime, characterId, skin}
  final Map<String, List<Map<String, dynamic>>> zones;
  const HallOfFameSeason({required this.id, required this.number, required this.mode, this.start, this.end, required this.zones});

  SeasonInfo get info => SeasonInfo(number: number, id: id, start: start ?? DateTime.utc(2000), end: end ?? DateTime.utc(2000), mode: mode);

  static HallOfFameSeason fromDoc(String id, Map<String, dynamic> d) {
    final zones = <String, List<Map<String, dynamic>>>{};
    final z = d['zones'];
    if (z is Map) {
      z.forEach((k, v) {
        if (k is String && v is List) zones[k] = [for (final e in v) if (e is Map) Map<String, dynamic>.from(e)];
      });
    }
    return HallOfFameSeason(
      id: id,
      number: (d['number'] as num?)?.toInt() ?? 0,
      mode: seasonModeOf(d['mode'] as String?),
      start: (d['start'] as Timestamp?)?.toDate(),
      end: (d['end'] as Timestamp?)?.toDate(),
      zones: zones,
    );
  }
}

class Season {
  static const _cacheKey = 'season_config';

  /// 지금 쓰는 설정 — 앱 시작 때 [load] 가 채운다(그 전엔 기본값)
  static SeasonConfig config = SeasonConfig.defaults;

  /// 화면(랭킹 머리)이 구독한다 — 설정을 읽거나 시즌이 바뀌면 바뀐다
  static final ValueNotifier<SeasonInfo> notifier = ValueNotifier(config.seasonAt(clock()));

  /// 지금 시즌 — 부를 때마다 계산한다(앱을 켜 둔 채 시즌이 넘어가도 맞게)
  /// 지금 시각(UTC) — 스토어 스크린샷 모드는 시즌 1 한가운데로 고정한다(프리시즌 칩이 홍보 이미지에 나오지 않게)
  static DateTime clock() => kStoreShot ? StoreShot.seasonNow : DateTime.now().toUtc();

  static SeasonInfo get now {
    final s = config.seasonAt(clock());
    if (notifier.value != s) notifier.value = s;
    return s;
  }

  static bool get _hasFirebase => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// 기기 캐시 → 서버(config/season) 순서로 읽는다. 서버를 못 읽어도(오프라인) 캐시·기본값으로 간다
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null) config = SeasonConfig.fromMap(Map<String, dynamic>.from(jsonDecode(raw)));
    } catch (_) {}
    notifier.value = config.seasonAt(clock());
    if (!_hasFirebase) return;
    try {
      final d = await FirebaseFirestore.instance
          .collection(SeasonConfig.collection)
          .doc(SeasonConfig.docId)
          .get()
          .timeout(const Duration(seconds: 8));
      if (d.exists) {
        config = SeasonConfig.fromMap(d.data());
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode(config.toCache()));
      }
    } catch (e) {
      debugPrint('Season load failed: $e');
    }
    notifier.value = config.seasonAt(clock());
  }
}
