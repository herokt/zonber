// ─────────────────────────────────────────────────────────────
// 스토어 스크린샷 모드 — `--dart-define=STORE_SHOT=true` 로 빌드했을 때만 켜진다(보통 빌드에서는 상수 false 라
// 관련 코드가 빠진다). 켜지면 앱이 언어 4개 × 화면 10개(갤럭시·피구·프리킥 플레이 · 결과 · 이 기록 깨러 가기 · 랭킹 · 가방 · 뱃지 · 이벤트 · 홈)를 차례로 띄우고
// 화면마다 로그에 `STORESHOT <언어>/<번호_이름>` 을 찍는다. 호스트 스크립트(scripts/store_shots.sh)가 그 줄을 보고
// adb 로 캡처한 뒤 scripts/compose_store_shots.mjs 가 문구·틀을 입혀 스토어 이미지로 만든다.
//
//   · 랭킹·목표선·세계 신기록은 아래 가짜 기록을 쓴다(실제 유저 닉네임이 홍보 이미지에 나오지 않게)
//   · 로그인·광고·분석·소리·진동은 쓰지 않는다. 기기에 저장된 데이터도 바꾸지 않는다(언어는 끝나고 되돌린다)
//   · 판은 빠르게 돌려 공이 많은 순간에서 멈춘다 — 캐릭터는 맞지 않고, 골키퍼는 골을 먹어도 목숨이 줄지 않는다
// ─────────────────────────────────────────────────────────────
const bool kStoreShot = bool.fromEnvironment('STORE_SHOT');

class StoreShot {
  /// 앱 위쪽에 비워 두는 상태바 자리(dp) — 합성할 때 이 자리에 상태바를 그린다
  static const double statusBarDp = 34;

  /// 찍는 언어 순서
  static const List<String> langs = ['ko', 'en', 'ja', 'zh'];

  /// 판 화면 — (존 id, 멈출 생존 시간)
  static const List<(String, double)> games = [('cyber', 124.36), ('dodgeball', 96.15), ('keeper', 88.42)];

  static const List<String> _names = [
    'Nova', 'Mochi', 'Blaze', 'Kiwi', 'Pixel', 'Luna', 'Dash', 'Echo', 'Orbit', 'Zeta',
    'Rapid', 'Sora', 'Juno', 'Aria', 'Remy', 'Yuki', 'Toby', 'Neo', 'Ghost', 'Milo',
  ];
  static const List<String> _flags = [
    '🇰🇷', '🇺🇸', '🇯🇵', '🇹🇼', '🇧🇷', '🇩🇪', '🇫🇷', '🇨🇦', '🇬🇧', '🇮🇩',
    '🇪🇸', '🇲🇽', '🇹🇭', '🇻🇳', '🇮🇹', '🇦🇺', '🇵🇭', '🇰🇷', '🇺🇸', '🇯🇵',
  ];
  static const List<String> _chars = [
    'neon_green', 'electric_blue', 'plasma_purple', 'cyber_red', 'solar_gold', 'blossom_pink', 'frost_cyan', 'void_dark',
  ];
  static const List<String> _skins = ['skin_galaxy', 'skin_none', 'skin_gold', 'skin_candy', 'skin_neon', 'skin_none', 'skin_ice'];
  static const List<String> _auras = ['aura_crown', 'aura_none', 'aura_star', 'aura_none', 'aura_halo', 'aura_none', 'aura_orbit'];
  static const List<String?> _badges = ['ach_legend', 'ach_master', null, 'ach_elite', null, 'ach_veteran', null];

  /// 존별 1위 기록
  static double _topOf(String mapId) => switch (mapId) {
        'dodgeball' => 212.480,
        'keeper' => 186.905,
        _ => 291.116,
      };

  /// 순위 i(0부터)의 기록 — 위쪽은 촘촘하고 아래로 갈수록 벌어진다. 매번 같은 값
  static double _timeAt(String mapId, int i) {
    final top = _topOf(mapId);
    final jitter = ((i * 37) % 11) * 0.137;
    return double.parse((top * (1 - 0.022 * i - 0.0004 * i * i) - jitter).clamp(20, top).toStringAsFixed(3));
  }

  /// 랭킹 목록(가짜) — RankingSystem 이 돌려주는 기록 한 줄과 같은 모양
  static List<Map<String, dynamic>> records(String mapId, {int limit = 30}) => [
        for (int i = 0; i < limit && i < _names.length; i++)
          {
            'id': 'shot_${mapId}_$i',
            'userId': 'shot_user_$i',
            'nickname': _names[i],
            'flag': _flags[i],
            'survivalTime': _timeAt(mapId, i),
            'characterId': _chars[i % _chars.length],
            'skin': _skins[i % _skins.length],
            'trail': 'trail_basic',
            'aura': _auras[i % _auras.length],
            'gear': const <String>[],
            if (_badges[i % _badges.length] != null) 'badge': _badges[i % _badges.length],
          },
      ];

  /// 올해 상위 기록 시간(내림차순) — 목표선·세계 신기록
  static List<double> topTimes(String mapId, {int limit = 100}) =>
      [for (int i = 0; i < limit; i++) _timeAt(mapId, i ~/ 5)];

  /// 이 시간의 세계 순위(가짜 기록 기준) — 결과 화면
  static ({int rank, int total}) rankOf(String mapId, double time) =>
      (rank: records(mapId).where((r) => (r['survivalTime'] as double) > time).length + 1, total: 12840);

  // ── 회원 화면(결과·뱃지) ──
  // 스크린샷 모드는 늘 게스트다. 결과 화면 한 장만 회원처럼 보이게 [member] 를 잠깐 켠다.
  // 켜 있어도 저장은 없다 — 프로필이 비어 기록 제출을 건너뛰고, 뱃지 저장(AchievementManager.unlock)은 스크린샷 모드에서 막힌다

  static bool member = false;

  /// 결과 화면 — 갤럭시 신기록 · 세계 순위 · 바로 아래 순위 랭커 돌파
  static const double resultTime = 261.524;
  static const double resultPrevBest = 255.018;
  /// 결과·이벤트 화면에서 보이는 코인 잔액(메모리만 — 저장하지 않는다)
  static const int shownCoins = 1240;
  /// 이번 판 기록보다 낮은 첫 랭커 — 결과 화면이 "돌파"로 나오게
  static int get resultRivalIndex =>
      records('cyber').indexWhere((r) => (r['survivalTime'] as double) < resultTime);
  static double get resultRivalTime => _timeAt('cyber', resultRivalIndex);
  static String get resultRivalName => _names[resultRivalIndex];

  /// 이 기록 깨러 가기 — 랭킹에서 누른 상대(1위 Nova)
  static const int rivalIndex = 0;
  static String rivalUid() => 'shot_user_$rivalIndex';
  static double rivalTime() => _timeAt('cyber', rivalIndex);

  /// 뱃지 화면·결과 화면에서 보이는 내 뱃지
  static const List<String> myBadges = [
    'ach_survivor', 'ach_veteran', 'ach_elite', 'ach_master', 'b_s1_30', 'b_s1_90', 'b_s1_180', 'b_s2_30', 'b_s2_75',
    'b_s3_30', 'b_s3_75', 'b_graze_15', 'b_graze_40', 'b_close_5', 'b_close_15', 'b_streak_3', 'b_streak_8', 'b_runs_10',
    'b_runs_100', 'b_time_1h', 'b_nat_top10', 'b_world_top100', 'ach_glob_top30', 'b_items_5', 'b_items_15', 'b_att_7',
    'b_mission_1', 'b_mission_10', 'b_newbest_10', 'ach_glob_top10',
  ];

  /// 이번 판에 새로 얻은 뱃지(결과 화면)
  static const List<String> freshBadges = ['ach_glob_top10', 'b_newbest_10'];

  /// 남의 프로필(users/{uid} 모양) — 랭킹에서 누른 사람
  static Map<String, dynamic> userDoc(String uid) {
    final i = int.tryParse(uid.replaceFirst('shot_user_', '')) ?? 0;
    final n = i % _names.length;
    return {
      'nickname': _names[n],
      'flag': _flags[n],
      'characterId': _chars[n % _chars.length],
      'equipped': {'skin': _skins[n % _skins.length], 'aura': _auras[n % _auras.length]},
      'createdAt': DateTime(2026, 9, 18),
      'lastUpdated': DateTime(2026, 9, 29, 21, 40),
      'achievements': ['ach_legend', 'ach_glob_champion', 'ach_master', 'b_s1_180', 'b_s2_150', 'b_s3_150', 'b_graze_80', 'b_runs_500', 'b_time_10h'],
      'bestTimes': {'cyber': _timeAt('cyber', n), 'dodgeball': _timeAt('dodgeball', n + 2), 'keeper': _timeAt('keeper', n + 1)},
      'totalGamesPlayed': 1284 - n * 37,
      'totalPlayTime': 61234.0 - n * 900,
    };
  }
}
