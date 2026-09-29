import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics 래퍼.
///
/// - 모바일(Android/iOS)에서만 활성. 웹/데스크톱과 초기화 실패 시 전부 no-op.
/// - 이벤트 이름·파라미터는 이 파일에만 둔다 (호출부에서 문자열을 만들지 않는다).
/// - 퍼널 순서: session_ready → game_start → game_over → (revive | score_submit)
/// - 성장: share · promo_claim · promo_code_redeem · sign_up/login · earn/spend_virtual_currency · unlock_achievement · review_prompt
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  FirebaseAnalytics? _analytics;
  String? _lastScreen;

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

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
  Future<void> logGuestStart() => _log('guest_start');

  /// 로그인 화면에서 게스트로 계속하기를 눌러 로그인을 건너뛴 시점.
  Future<void> logLoginSkipped() => _log('login_skipped');

  /// 로그인 성공. 처음 만든 계정이면 표준 `sign_up`, 원래 있던 계정이면 표준 `login` —
  /// 게스트 → 회원 전환(sign_up)과 재로그인을 나눠 본다.
  Future<void> logLogin(String method, {bool isNewUser = false}) async {
    final a = _analytics;
    if (a == null) return;
    try {
      if (isNewUser) {
        await a.logSignUp(signUpMethod: method);
      } else {
        await a.logLogin(loginMethod: method);
      }
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

  // ── 공유 / 이벤트 ───────────────────────────────────────────────────

  /// 표준 `share` — [src] 어디서(result · promo) · [itemId] 무엇을(맵 id · 이벤트 id) ·
  /// [method] 어느 앱으로(iOS·일부 Android 는 고른 앱, 모르면 os, 공유 창이 없으면 clipboard).
  /// 게스트 공유와 하루 두 번째 공유도 센다(백오피스 share_daily 수령 수는 회원 하루 한 번뿐).
  Future<void> logShare({required String src, required String itemId, required String method}) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logShare(contentType: src, itemId: itemId, method: _cut(method));
    } catch (e) {
      debugPrint('Analytics share failed: $e');
    }
  }

  /// 이벤트 보상을 받은 시점 — 환영 선물을 받은 사람이 더 오래 남는지 퍼널로 본다
  Future<void> logPromoClaim({required String promoId, required String kind, required int coins}) =>
      _log('promo_claim', {'promo_id': promoId, 'kind': kind, 'coins': coins});

  /// 이벤트·친구 코드 입력 — 실패도 남긴다([result] = RedeemResult 이름). 코드 원문은 남기지 않고 캠페인만
  Future<void> logPromoCodeRedeem({required String result, String? campaign, int coins = 0}) => _log('promo_code_redeem', {
        'result': result,
        'campaign': campaign ?? 'unknown',
        'coins': coins,
      });

  /// 앱 리뷰 창을 요청한 시점(OS 가 실제로 띄웠는지는 알 수 없다)
  Future<void> logReviewPrompt({required int runs}) => _log('review_prompt', {'runs': runs});

  // ── 코인 / 뱃지 ─────────────────────────────────────────────────────

  /// 표준 `earn_virtual_currency` — [source] run · ad_double · mission · all_clear · check_in · promo · friend
  Future<void> logEarnCoins({required String source, required int amount}) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logEarnVirtualCurrency(virtualCurrencyName: 'coin', value: amount, parameters: {'source': source});
    } catch (e) {
      debugPrint('Analytics earn_virtual_currency failed: $e');
    }
  }

  /// 표준 `spend_virtual_currency` — [item] 무엇에 썼나(아이템 id · name_ticket)
  Future<void> logSpendCoins({required String item, required int amount}) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logSpendVirtualCurrency(itemName: item, virtualCurrencyName: 'coin', value: amount);
    } catch (e) {
      debugPrint('Analytics spend_virtual_currency failed: $e');
    }
  }

  /// 표준 `unlock_achievement` — 뱃지를 새로 얻은 시점
  Future<void> logBadge(String badgeKey) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logUnlockAchievement(id: badgeKey);
    } catch (e) {
      debugPrint('Analytics unlock_achievement failed: $e');
    }
  }

  /// GA4 파라미터 값은 100자까지
  static String _cut(String v) => v.length <= 100 ? v : v.substring(0, 100);

  static double _round3(double v) => (v * 1000).round() / 1000;
}
