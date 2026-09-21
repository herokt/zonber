import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics 래퍼.
///
/// - 모바일(Android/iOS)에서만 활성. 웹/데스크톱과 초기화 실패 시 전부 no-op.
/// - 이벤트 이름·파라미터는 이 파일에만 둔다 (호출부에서 문자열을 만들지 않는다).
/// - 퍼널 순서: session_ready → game_start → game_over → (revive | score_submit)
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  FirebaseAnalytics? _analytics;
  String? _lastScreen;

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool get isEnabled => _analytics != null;

  Future<void> initialize() async {
    if (!_isMobile) return;
    try {
      _analytics = FirebaseAnalytics.instance;
      await _analytics!.setAnalyticsCollectionEnabled(true);
      debugPrint('✅ Analytics initialized');
    } catch (e) {
      debugPrint('❌ Analytics initialization failed: $e');
      _analytics = null;
    }
  }

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('Analytics event "$name" failed: $e');
    }
  }

  Future<void> _setUserProperty(String name, String? value) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('Analytics user property "$name" failed: $e');
    }
  }

  // ── 화면 ────────────────────────────────────────────────────────────

  /// `_currentPage` 문자열을 그대로 화면 이름으로 쓴다. 같은 화면 연속 호출은 무시.
  Future<void> logScreen(String page) async {
    if (page == _lastScreen) return;
    _lastScreen = page;
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logScreenView(screenName: page);
    } catch (e) {
      debugPrint('Analytics screen "$page" failed: $e');
    }
  }

  // ── 세션 / 인증 ─────────────────────────────────────────────────────

  /// 부트스트랩이 끝나 첫 화면이 결정된 시점. 게스트 여부와 로그인 제공자를
  /// 유저 속성으로 남겨 이후 모든 이벤트를 게스트/계정으로 나눠 볼 수 있게 한다.
  Future<void> logSessionReady({
    required bool isGuest,
    required String provider,
    required String firstPage,
  }) async {
    await _setUserProperty('login_provider', provider);
    await _setUserProperty('is_guest', isGuest ? 'true' : 'false');
    await _log('session_ready', {
      'is_guest': isGuest ? 1 : 0,
      'provider': provider,
      'first_page': firstPage,
    });
  }

  /// 최초 실행에서 자동 게스트 세션이 만들어진 시점 (설치 → 첫 진입 퍼널의 시작).
  Future<void> logGuestStart({required bool anonymousAuthOk}) =>
      _log('guest_start', {'anonymous_auth': anonymousAuthOk ? 1 : 0});

  /// 로그인 화면에서 게스트로 계속하기를 눌러 로그인을 건너뛴 시점.
  Future<void> logLoginSkipped() => _log('login_skipped');

  Future<void> logLogin(String method) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logLogin(loginMethod: method);
      await _setUserProperty('login_provider', method);
      await _setUserProperty('is_guest', 'false');
    } catch (e) {
      debugPrint('Analytics login failed: $e');
    }
  }

  Future<void> logLogout() => _log('logout');

  // ── 게임 루프 ───────────────────────────────────────────────────────

  Future<void> logGameStart({
    required String mapId,
    required String characterId,
  }) =>
      _log('game_start', {'map_id': mapId, 'character_id': characterId});

  Future<void> logGameOver({
    required String mapId,
    required String characterId,
    required double survivalTime,
    required int level,
    required int reviveCount,
  }) async {
    await _log('game_over', {
      'map_id': mapId,
      'character_id': characterId,
      'survival_time': _round3(survivalTime),
      'level': level,
      'revive_count': reviveCount,
    });
    final a = _analytics;
    if (a == null) return;
    try {
      // 표준 이벤트 — 콘솔 기본 리포트에서 점수 분포를 바로 볼 수 있다.
      await a.logPostScore(
        score: (survivalTime * 1000).round(),
        level: level,
        character: characterId,
      );
    } catch (e) {
      debugPrint('Analytics post_score failed: $e');
    }
  }

  /// 리워드 광고를 보고 실제로 부활한 시점 (보상 지급 콜백).
  Future<void> logRevive({
    required String mapId,
    required double survivalTime,
  }) =>
      _log('revive', {'map_id': mapId, 'survival_time': _round3(survivalTime)});

  // ── 랭킹 / 업적 ─────────────────────────────────────────────────────

  Future<void> logScoreSubmit({
    required String mapId,
    required String characterId,
    required double survivalTime,
  }) =>
      _log('score_submit', {
        'map_id': mapId,
        'character_id': characterId,
        'survival_time': _round3(survivalTime),
      });

  /// 게스트가 점수 제출을 눌렀다가 로그인 안내를 받은 시점 — 게스트→계정 전환 퍼널의 입구.
  Future<void> logGuestRankingBlocked({required double survivalTime}) =>
      _log('guest_ranking_blocked', {'survival_time': _round3(survivalTime)});

  Future<void> logRankingView(String mapId) =>
      _log('ranking_view', {'map_id': mapId});

  Future<void> logAchievementUnlock(String key) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logUnlockAchievement(id: key);
    } catch (e) {
      debugPrint('Analytics achievement failed: $e');
    }
  }

  static double _round3(double v) => (v * 1000).round() / 1000;
}
