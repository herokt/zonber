import 'dart:math';
import 'dart:ui' as ui; // Gradient (총알슛 꼬리)
import 'package:flutter/material.dart';
import 'login_page.dart'; // Added
import 'package:firebase_auth/firebase_auth.dart'; // Added
import 'package:flutter/gestures.dart'; // PointerDeviceKind (마우스 드래그 스와이프)
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_core/firebase_core.dart'; // 파이어베이스 코어
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/particles.dart'; // Added for trail effect
import 'package:flame/collisions.dart';
import 'package:flame/input.dart'; // Required for PanDetector
import 'package:flame/events.dart'; // Required for DragStartInfo etc?

import 'ranking_system.dart';
import 'user_profile.dart';
import 'game_settings.dart';
import 'character_data.dart';
import 'audio_manager.dart';
import 'ad_manager.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // For BannerAd, AdWidget
import 'design_system.dart';
import 'shop_page.dart';
import 'services/auth_service.dart';
import 'services/analytics_service.dart';
import 'world_config.dart';
import 'progress_store.dart';
import 'coin_store.dart';
import 'avatar.dart';
import 'cosmetics.dart';
import 'gear.dart';
import 'playtest_log.dart';
import 'balance.dart';
import 'haptics.dart';
import 'run_history.dart';
import 'daily_rewards.dart';
import 'badges.dart';
import 'zonber_painter.dart';
import 'pages/home_page.dart';
import 'pages/ranking_page.dart';
import 'pages/result_page.dart';
import 'pages/badges_page.dart';
import 'pages/profile_page.dart';
import 'pages/promo_page.dart';
import 'package:provider/provider.dart'; // Added by instruction
import 'language_manager.dart'; // Added by instruction
import 'statistics_page.dart'; // Added by instruction
import 'backoffice/admin_gate.dart';
import 'backoffice/backoffice_home.dart'; // Added for Secret Admin
import 'firebase_options.dart'; // Added by instruction
import 'store_shot.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';

part 'game/game_screen.dart';
part 'game/zonber_game.dart';
part 'game/player.dart';
part 'game/projectiles.dart';
part 'game/keeper.dart';
part 'game/dodgeball.dart';
part 'store_shot_run.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("ZONBER GAME: UPDATE VERIFIED - SYMMETRICAL CHARACTERS 2024-12-30");

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    // Moved initialization to _ZonberAppState to prevent Watchdog Timeout
  } else {
    debugPrint("Skipping Firebase/AdMob/IAP init on desktop/web");
  }

  // 테마는 첫 프레임 전에 읽는다 — 다크 사용자에게 라이트 스플래시가 번쩍이지 않게
  await GameSettings().load();
  if (kStoreShot) {
    // 스토어 스크린샷 — 소리·진동 끔 · 라이트 테마 · 시스템 바 숨김(상태바는 합성할 때 그린다)
    GameSettings().storeShotDefaults();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  AppColors.isDark = GameSettings().darkMode;

  // Status bar/nav bar: transparent, 아이콘 밝기는 테마를 따른다 (edge-to-edge compatible)
  SystemChrome.setSystemUIOverlayStyle(AppColors.overlayStyle);

  // Moved GameSettings, AudioManager, LanguageManager init to _ZonberAppState

  runApp(
    ChangeNotifierProvider(
      create: (_) => LanguageManager(),
      child: const ZonberApp(),
    ),
  );
}

class ZonberApp extends StatefulWidget {
  const ZonberApp({super.key});

  @override
  State<ZonberApp> createState() => _ZonberAppState();
}

class _ZonberAppState extends State<ZonberApp> with WidgetsBindingObserver {
  String _currentPage = 'Splash'; // Start with Splash to prevent Login flicker
  // ── 월드 ──
  String _currentWorldId = WorldData.defaultWorld.id;
  Map<String, double> _bestTimes = {};
  Map<String, RankCacheEntry> _rankCache = {};
  double _previousBest = 0.0; // 결과 화면 델타용 — 이번 판 이전 최고
  int _runCoins = 0; // 이번 판(부활 포함)에 이미 준 코인
  double _runTimeCounted = 0; // 일일 미션에 이미 더한 시간 · 추가 기록(부활로 이어진 판은 늘어난 만큼만)
  int _runStatCounted = 0;
  String _shopReturn = 'Menu'; // 상점에서 뒤로 가면 돌아갈 화면
  /// 월드별 목표선 캐시(TOP 100/30/10/1 시간). 10분 유지.
  final Map<String, ({List<double> times, DateTime at})> _targetCache = {};

  WorldConfig get _currentWorld => WorldData.getWorld(_currentWorldId);
  String get _currentMapId => _currentWorld.rankingMapId;
  Map<String, dynamic>? _lastGameResult; // Store result data

  // Global Banner Ad State
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  bool _adsRemoved = false; // Track ad removal status

  int _reviveCount = 0; // Track revives per game session

  // Current game instance (for accessing in callbacks)
  ZonberGame? _currentGame;
  BuildContext? _latestContext; // For back-button pause during game

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LanguageManager().addListener(_handleLanguageChange);
    GameSettings().addListener(_applyTheme);

    // Check for Secret Admin URL
    if (kIsWeb && Uri.base.toString().contains('/secret_admin')) {
      _currentPage = 'Backoffice';
    }

    _initializeApp();
  }

  /// 설정의 다크 모드 전환 — AppColors 를 바꾸고 트리 전체를 다시 빌드한다.
  /// const 위젯은 부모 setState 로는 다시 빌드되지 않으므로 모든 Element 를 직접 표시한다(상태는 유지).
  void _applyTheme() {
    if (AppColors.isDark == GameSettings().darkMode) return;
    AppColors.isDark = GameSettings().darkMode;
    SystemChrome.setSystemUIOverlayStyle(AppColors.overlayStyle);
    if (!mounted) return;
    void rebuild(Element el) {
      el.markNeedsBuild();
      el.visitChildren(rebuild);
    }
    (context as Element).visitChildren(rebuild);
    setState(() {});
  }

  void _handleLanguageChange() {
    debugPrint(
      'Main: _handleLanguageChange triggered. Current: ${LanguageManager().currentLanguage}',
    );
    if (mounted) {
      setState(() {});
      debugPrint('Main: setState called for language change');
    }
  }

  Future<void> _initializeApp() async {
    if (kStoreShot) return _startStoreShots();
    // 1. Initialize Core Services (Firebase, AdMob, IAP)
    if (kIsWeb) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint("✅ Firebase initialized (Web)");
      } catch (e) {
        debugPrint("❌ Firebase initialization failed (Web): $e");
      }
    } else if (Platform.isAndroid || Platform.isIOS) {
      try {
        await Firebase.initializeApp(); // Use default for mobile (google-services.json)
        debugPrint("✅ Firebase initialized (Mobile)");
      } catch (e) {
        debugPrint("❌ Firebase initialization failed (Mobile): $e");
      }

      // 동의 폼(UMP)·ATT 가 사용자 응답을 기다릴 수 있으므로 앱 시작을 막지 않는다.
      // 배너는 _checkAdStatus 에서 AdManager().whenReady 뒤에 요청한다.
      AdManager().initialize().then(
        (_) => debugPrint("✅ AdMob initialized"),
        onError: (e) => debugPrint("❌ AdMob initialization failed: $e"),
      );

      try {
        // await IAPService().initialize();
        debugPrint("✅ IAP initialized");
      } catch (e) {
        debugPrint("❌ IAP initialization failed: $e");
      }
    }

    // 2. Initialize App Settings & Resources
    await GameSettings().load();
    await AudioManager().initialize();
    await LanguageManager().init();
    await AnalyticsService().initialize();

    // 3. Check Auth & Profile
    await _checkAuth();

    // 4. Check Ads
    await _checkAdStatus();
  }

  Future<void> _checkAdStatus() async {
    await AdManager().whenReady;
    final adsRemoved = await UserProfileManager.isAdsRemoved();
    if (!mounted) return;
    setState(() {
      _adsRemoved = adsRemoved;
    });

    if (!adsRemoved) {
      _loadGlobalBannerAd();
    }
  }

  void _loadGlobalBannerAd() {
    _bannerAd = AdManager().loadBannerAd(() {
      if (!mounted) return;
      setState(() {
        _isBannerAdReady = true;
      });
    }, onFailed: () {
      // 실패한 배너는 AdManager 가 dispose 했다 — 참조를 버리고 잠시 뒤 다시 요청
      _bannerAd = null;
      _isBannerAdReady = false;
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted && !_adsRemoved && _bannerAd == null) _loadGlobalBannerAd();
      });
    });
  }

  Future<void> refreshPurchaseStatus() async {
    debugPrint('📍 Refreshing purchase status...');

    // Dispose old banner ad
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerAdReady = false;

    // Refresh AdManager status
    await AdManager().refreshAdsStatus();

    // Reload purchase status
    await _checkAdStatus();

    debugPrint('📍 Purchase status refreshed. Ads removed: $_adsRemoved');
  }

  /// 앱으로 돌아올 때 원격을 다시 읽는다 — 백오피스에서 준 코인·아이템이 여기서 들어온다
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || AuthService.isGuest) return;
    UserProfileManager.syncProfile().then((_) async {
      await _loadProgress();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LanguageManager().removeListener(_handleLanguageChange);
    GameSettings().removeListener(_applyTheme);
    _bannerAd?.dispose();
    // IAPService().dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    // If we are in Backoffice mode, ensure we are signed in (Anonymously is fine for admin rules if configured, or user will just see empty data if rules are strict)
    // But importantly, DO NOT redirect to Login/Menu.
    if (_currentPage == 'Backoffice') {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        try {
          await FirebaseAuth.instance.signInAnonymously();
          debugPrint("✅ Signed in anonymously for Backoffice");
        } catch (e) {
          debugPrint("❌ Backoffice Auth failed: $e");
        }
      }
      return; // Stay on Backoffice
    }

    // Normal App Flow — wait for Firebase to restore persisted session
    User? user = await FirebaseAuth.instance.authStateChanges().first;
    if (user != null && user.isAnonymous) {
      // 예전 버전이 만든 익명 세션 — 게스트는 로그인 없이 쓰므로 끊는다
      try {
        await AuthService().signOut();
      } catch (e) {
        debugPrint('Main: anonymous sign-out error: $e');
      }
      user = null;
    }
    if (user == null) {
      // 게스트 기본화 — 첫 실행은 로그인 화면 없이 바로 게스트로 메뉴에 들어간다.
      // 로그인은 랭킹 등록처럼 계정이 필요한 시점에만 요구한다 (ResultPage → Login).
      await _enterAsGuest();
    } else {
      await _checkProfile();
    }
  }

  /// 게스트로 메뉴에 진입한다. 최초 실행과 로그아웃 직후에 쓴다.
  /// 게스트는 로그인 없이 게임 맛보기만 한다 — 기기에 남은 이전 데이터(예전 게스트 기록 포함)는 지운다.
  Future<void> _enterAsGuest() async {
    await _clearLocalData();
    AnalyticsService().logGuestStart();
    AnalyticsService().logSessionReady(
      isGuest: true,
      provider: 'Guest',
      firstPage: 'Menu',
    );
    AnalyticsService().logScreen('Menu');
    await _loadProgress();
    if (!mounted) return;
    setState(() => _currentPage = 'Menu');
  }

  /// 기기에 저장된 유저 데이터(프로필·기록·코인·미션·뱃지)를 지운다 — 게스트 진입·로그아웃 때
  Future<void> _clearLocalData() async {
    try {
      await UserProfileManager.clearProfile().timeout(const Duration(seconds: 1));
      await ProgressStore.clearLocal();
      await CoinStore.clearLocal();
      await DailyRewards.clearLocal();
    } catch (e) {
      debugPrint('Main: clear local data error: $e');
    }
  }

  Future<void> _loadProgress() async {
    await CoinStore.load();
    _bestTimes = await ProgressStore.getBestTimes();
    _rankCache = await ProgressStore.getRankCache();
    // 저장된 월드가 잠겨 있으면 플레이 가능한 기본 월드로
    if (!WorldData.isUnlocked(_currentWorld, _bestTimes)) {
      _currentWorldId = WorldData.defaultWorld.id;
    }
  }

  static String _providerName(User? user) {
    if (user == null || user.isAnonymous) return 'Guest';
    for (final info in user.providerData) {
      if (info.providerId == 'google.com') return 'Google';
      if (info.providerId == 'apple.com') return 'Apple';
    }
    return 'Unknown';
  }

  Future<void> _checkProfile() async {
    // Sync profile from Firestore first
    await UserProfileManager.syncProfile();

    bool hasProfile = await UserProfileManager.hasProfile();
    final firstPage = hasProfile ? 'Menu' : 'Profile';
    final user = FirebaseAuth.instance.currentUser;
    AnalyticsService().logSessionReady(
      isGuest: user?.isAnonymous ?? true,
      provider: _providerName(user),
      firstPage: firstPage,
    );
    AnalyticsService().logScreen(firstPage);
    await _loadProgress();
    if (!mounted) return;
    setState(() {
      _currentPage = firstPage;
    });
  }

  /// 화면만 바꾼다(분석·게임 준비 없이) — 스토어 스크린샷 시작용
  void _showPage(String page) => setState(() => _currentPage = page);

  void _navigateTo(String page, {String? mapId, double initialTime = 0.0}) {
    if (page == 'Shop' && _currentPage != 'Shop') _shopReturn = _currentPage;
    // Create the game object here (before setState) so that build() always
    // reuses the same instance. Creating it inside build() causes a new game
    // to be instantiated on every rebuild (e.g. when the banner ad loads),
    // which makes Flame's GameWidget restart the game mid-session.
    if (page == 'Game') {
      final world = _currentWorld;
      _currentGame = ZonberGame(
        mapId: world.layoutId,
        worldConfig: world,
        initialSurvivalTime: initialTime,
        personalBest: _bestTimes[world.id] ?? 0.0,
        onExit: () {
          AdManager().showInterstitialIfReady();
          _navigateTo('Menu');
        },
        onGameOver: (result) {
          _handleGameOver(result);
        },
      );
      _loadTargets(world, _currentGame!);
    }

    AnalyticsService().logScreen(page);
    if (page == 'Game' && initialTime == 0.0) {
      final gameMapId = _currentMapId;
      UserProfileManager.getProfile().then(
        (p) => AnalyticsService().logGameStart(
          mapId: gameMapId,
          characterId: p['characterId'] ?? 'neon_green',
        ),
      );
    }

    setState(() {
      _currentPage = page;
      if (mapId != null) {
        // 하위 호환: 랭킹 mapId 로 월드를 고른다
        final w = WorldData.byRankingMapId(mapId);
        if (w != null) _currentWorldId = w.id;
      }
      // Reset revive count when starting a NEW game from MapSelect (Time 0)
      if (page == 'Game' && initialTime == 0.0) {
        _reviveCount = 0;
      }
    });
  }

  /// 목표선(TOP 100/30/10/1 시간) — 게임 시작 시 비동기로 실어 준다. 10분 캐시.
  Future<void> _loadTargets(WorldConfig world, ZonberGame game) async {
    final cached = _targetCache[world.id];
    List<double> times;
    if (cached != null && DateTime.now().difference(cached.at).inMinutes < 10) {
      times = cached.times;
    } else {
      times = await RankingSystem().getTopTimes(world.rankingMapId, limit: 100);
      _targetCache[world.id] = (times: times, at: DateTime.now());
    }
    final targets = <({String label, double time})>[];
    for (final n in [100, 30, 10, 1]) {
      if (times.length >= n) targets.add((label: 'TOP $n', time: times[n - 1]));
    }
    targets.sort((a, b) => a.time.compareTo(b.time));
    if (_currentGame == game) game.setTargets(targets);
  }

  /// 가입(닉네임·국가 설정) 취소 — 로그아웃하고 게스트로 돌아간다
  Future<void> _cancelSignup() async {
    try {
      await AuthService().signOut().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Main: cancel signup sign-out error: $e');
    }
    try {
      await UserProfileManager.clearProfile().timeout(const Duration(seconds: 1));
    } catch (_) {}
    await _enterAsGuest();
  }

  /// Handles Android Back Button
  void _handleBack() {
    switch (_currentPage) {
      case 'Login':
        // 로그인 화면은 루트가 아니다 — 게스트 세션 위에 떠 있으므로 메뉴로 돌아간다.
        _navigateTo('Menu');
        break;

      case 'Menu':
        // Let AppScaffold trigger Exit Dialog
        // Returning here allows onBack to be null, signalling AppScaffold to show quit dialog
        return;

      case 'Ranking':
        _navigateTo('Menu');
        break;

      case 'Game':
        if (_currentGame != null && _latestContext != null) {
          _pauseGame(_latestContext!, _currentGame!);
        }
        break;

      case 'Result':
      case 'Profile':
        // 가입 중 뒤로 가기 = 가입 취소. 닉네임·국가 없이 로그인 상태로 남지 않게 게스트로 되돌린다
        _cancelSignup();
        break;

      case 'MyProfile':
      case 'Badges':
        _navigateTo('Menu');
        break;

      case 'Statistics':
        _navigateTo('Menu');
        break;

      case 'Shop':
        _navigateTo(_shopReturn);
        break;

      default:
        _navigateTo('Menu');
        break;
    }
  }

  /// Returns the Back Callback based on current page.
  /// Returns null if we represent the "Root" (to trigger exit dialog).
  VoidCallback? _getBackHandler() {
    if (_currentPage == 'Menu') {
      return null; // Root -> Exit Dialog
    }
    return () => _handleBack();
  }

  @override
  Widget build(BuildContext context) {
    // Manual listener ensures rebuild, so we can access singleton directly
    return MaterialApp(
      // 마우스·트랙패드 드래그로도 캐러셀을 넘길 수 있게 (웹 미리보기·데스크톱)
      scrollBehavior: const MaterialScrollBehavior().copyWith(dragDevices: {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      }),
      locale: Locale(LanguageManager().currentLanguage),
      // 스토어 스크린샷 — 시스템 바를 숨겼으니 위쪽에 상태바 자리를 비워 둔다(합성 때 그 자리에 상태바를 그린다)
      builder: kStoreShot
          ? (context, child) {
              final mq = MediaQuery.of(context);
              const inset = EdgeInsets.only(top: StoreShot.statusBarDp);
              return MediaQuery(data: mq.copyWith(padding: inset, viewPadding: inset), child: child!);
            }
          : null,
      supportedLocales: const [Locale('en'), Locale('ko'), Locale('zh'), Locale('ja')],
      localizationsDelegates: const [
        CountryLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AppScaffold(
        backgroundColor: _currentPage == 'Game' ? _currentWorld.floor : null,
        bannerAd: (_isBannerAdReady && _bannerAd != null && !_adsRemoved)
            ? AdWidget(ad: _bannerAd!)
            : null,
        // 플레이 중에는 숨긴다 — 드래그 조작 중 오클릭은 AdMob 무효 트래픽(계정 제재) 사유
        showBanner: !_adsRemoved && _currentPage != 'Game',
        onBack: _getBackHandler(),
        bottomNav: _bottomNavIndex() == null
            ? null
            : AppBottomNav(
                index: _bottomNavIndex()!,
                accent: _currentWorld.accent,
                onTap: (i) => _navigateTo(const ['Menu', 'Ranking', 'Shop', 'Badges', 'MyProfile'][i]),
              ),
        child: Builder(builder: (context) => _buildPage(context)),
      ),
    );
  }

  int? _bottomNavIndex() {
    switch (_currentPage) {
      case 'Menu':
        return 0;
      case 'Ranking':
        return 1;
      case 'Shop':
        return 2;
      case 'Badges':
        return 3;
      case 'MyProfile':
        return 4;
    }
    return null;
  }

  Widget _buildPage(BuildContext context) {
    _latestContext = context;
    switch (_currentPage) {
      case 'Backoffice':
        return const AdminGate(child: BackofficeHome()); // 관리자 Google 계정만
      case 'Splash':
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "ZONBER",
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    letterSpacing: 6.0,
                  ),
                ),
                SizedBox(height: 32),
                SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textDim)),
              ],
            ),
          ),
        );
      case 'Login':
        return LoginPage(
          onLoginSuccess: () {
            _checkProfile();
          },
          onGuestContinue: () {
            _navigateTo('Menu');
          },
        );
      case 'Game':
        return _GameScreen(
          game: _currentGame!,
          world: _currentWorld,
          onPause: () => _pauseGame(context, _currentGame!),
        );
      case 'Ranking':
        return RankingPage(
          key: ValueKey('ranking_$_currentWorldId'),
          initialWorldId: _currentWorldId,
          rankCache: _rankCache,
          onLogin: () => _navigateTo('Login'),
          onBack: () => _navigateTo('Menu'),
        );
      case 'Result':
        return ResultPage(
          world: _currentWorld,
          result: _lastGameResult!,
          previousBest: _previousBest,
          onRestart: () => _navigateTo('Game'),
          onExit: () => _navigateTo('Menu'),
          onNavigateToLogin: () => _navigateTo('Login'),
          onShowRanking: () => _navigateTo('Ranking'),
          // 부활은 게스트에게도 허용한다 — 광고 수익 관점에서 게스트를
          // 제외할 이유가 없고, 랭킹 등록과 달리 계정이 필요한 기능도 아니다.
          onRevive: (_reviveCount < 1)
              ? (String? submittedRecordId) {
                  bool shown = AdManager().showRewardedAd(() {
                    // On Reward: Resume Game
                    _reviveCount++; // Increment Revive Count
                    AnalyticsService().logRevive(
                      mapId: _currentMapId,
                      survivalTime: _lastGameResult!['survivalTime'],
                    );
                    // 부활로 판이 이어지므로 방금 제출한 기록은 삭제한다 —
                    // 같은 판이 랭킹에 두 번 남지 않게.
                    if (submittedRecordId != null &&
                        submittedRecordId.isNotEmpty) {
                      RankingSystem().deleteRecord(
                        _currentMapId,
                        submittedRecordId,
                      );
                    }
                    _navigateTo(
                      'Game',
                      initialTime: _lastGameResult!['survivalTime'],
                    );
                  });

                  if (!shown) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          LanguageManager.of(
                            context,
                            listen: false,
                          ).translate('ad_not_ready'),
                        ),
                      ),
                    );
                  }
                }
              : null,
          revivesLeft: 1 - _reviveCount,
        );
      case 'Profile':
        return UserProfilePage(onComplete: () => _navigateTo('Menu'), onCancel: _cancelSignup);
      case 'Badges':
        return BadgesPage(onBack: () => _navigateTo('Menu'));
      case 'MyProfile':
        return ProfilePage(
          key: ValueKey('profile_${_bestTimes.length}_${_rankCache.length}'),
          bestTimes: _bestTimes,
          rankCache: _rankCache,
          onOpenShop: () => _navigateTo('Shop'),
          onStatistics: () => _navigateTo('Statistics'),
          onBack: () => _navigateTo('Menu'),
          onLogin: () => _navigateTo('Login'),
          onLogout: () async {
            debugPrint('Main: onLogout called');

            // Show loading indicator
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );

            try {
              // 1. Sign out from Firebase
              try {
                await AuthService().signOut().timeout(
                  const Duration(seconds: 2),
                );
                debugPrint('Main: AuthService signed out');
              } catch (e) {
                debugPrint('Main: Logout error (Auth): $e');
              }

              // 2. Clear local profile + 진행 데이터(게스트로 돌아가므로 기록도 함께)
              try {
                await UserProfileManager.clearProfile().timeout(
                  const Duration(seconds: 1),
                );
                await ProgressStore.clearLocal();
                await CoinStore.clearLocal();
                debugPrint('Main: Profile cleared');
              } catch (e) {
                debugPrint('Main: Logout error (Profile): $e');
              }

              // 3. Wait a bit for UI to settle
              await Future.delayed(const Duration(milliseconds: 500));
            } catch (e) {
              debugPrint('Main: Critical logout error: $e');
            } finally {
              // 4. Close loading indicator (use rootNavigator to be safe)
              if (mounted &&
                  Navigator.of(context, rootNavigator: true).canPop()) {
                Navigator.of(context, rootNavigator: true).pop();
              }

              // 5. 로그아웃 = 게스트로 복귀 (게스트 기본화). 로그인 화면은 필요할 때만 띄운다.
              AnalyticsService().logLogout();
              debugPrint('Main: Re-entering as guest after logout');
              await _enterAsGuest();
            }
          },
        );
      case 'Shop':
        return ShopPage(
          showBack: true, // 머리 통일 — 뒤로 가기는 들어온 화면으로
          onBack: () => _navigateTo(_shopReturn),
          onPurchaseReset: refreshPurchaseStatus,
        );
      case 'Statistics':
        return StatisticsPage(onBack: () => _navigateTo('MyProfile'));
      case 'Promo':
        return PromoPage(onBack: () => _navigateTo('Menu'));
      case 'Menu':
      default:
        return HomePage(
          key: ValueKey('home_${_bestTimes.length}_${_rankCache.length}'),
          selectedWorldId: _currentWorldId,
          bestTimes: _bestTimes,
          rankCache: _rankCache,
          onWorldSelected: (id) => _currentWorldId = id,
          onStart: () => _navigateTo('Game'),
          onCharacterSelect: () => _navigateTo('Shop'), // 캐릭터 고르기 = 상점 캐릭터 탭(첫 탭)
          onLogin: () => _navigateTo('Login'),
          onSettings: () => _navigateTo('MyProfile'),
          onRanking: () => _navigateTo('Ranking'),
          onShop: () => _navigateTo('Shop'),
          onPromo: () => _navigateTo('Promo'),
        );
    }
  }

  void _pauseGame(BuildContext context, ZonberGame game) {
    game.pauseEngine();
    game.quietDanger();
    final langManager = LanguageManager.of(context, listen: false);
    showNeonDialog(
      context: context,
      title: langManager.translate('paused'),
      message: AuthService.isGuest
          ? langManager.translate('guest_no_ranking_note')
          : null,
      barrierDismissible: false, // 바깥 탭으로 닫히면 게임이 멈춘 채 남는다
      actions: [
        NeonButton(
          text: langManager.translate('exit'),
          color: AppColors.secondary,
          onPressed: () {
            Navigator.pop(context);
            // Trigger game's onClose/onExit logic if needed,
            // or just navigate manually since we are outside.
            // But game logic might need cleanup?
            // ZonberGame doesn't have explicit cleanup other than onExit callback.
            // We can call the onExit we passed to ZonberGame, but we need reference.
            // Or just navigate:
            AdManager().showInterstitialIfReady();
            _navigateTo('Menu');
          },
          isPrimary: false,
        ),
        NeonButton(
          text: langManager.translate('resume'),
          onPressed: () {
            Navigator.pop(context);
            game.resumeEngine();
          },
        ),
      ],
    );
  }

  void _handleGameOver(Map<String, dynamic> result) async {
    // 게스트 — 게임 맛보기만. 기록·코인·미션·뱃지·통계를 어디에도 남기지 않고 결과만 보여 준다
    if (AuthService.isGuest) {
      _previousBest = 0;
      result['coinsEarned'] = 0;
      result['coinsBonus'] = 0;
      AnalyticsService().logGameOver(
        mapId: result['mapId'] ?? _currentMapId,
        characterId: 'neon_green',
        survivalTime: result['survivalTime'],
        level: result['level'] ?? 0,
        reviveCount: _reviveCount,
      );
      if (!mounted) return;
      AnalyticsService().logScreen('Result');
      setState(() {
        _lastGameResult = result;
        _currentPage = 'Result';
      });
      AdManager().showInterstitialIfReady();
      return;
    }
    // 부활로 이어진 판은 이전 최고를 그대로 둔다(첫 게임 오버의 값)
    final double time = result['survivalTime'];
    final prev = await ProgressStore.updateBestTime(_currentWorldId, time);
    if (_reviveCount == 0) {
      _previousBest = prev;
      _runCoins = 0;
      _runTimeCounted = 0;
      _runStatCounted = 0;
    }
    // 일일 미션 진행
    final statNow = (result['graze'] as num?)?.toInt() ?? 0;
    final addedTime = max(0.0, time - _runTimeCounted);
    DailyRewards.recordRun(
      stage: _currentWorld.difficulty,
      time: time,
      addedTime: addedTime,
      addedStat: max(0, statNow - _runStatCounted),
      continued: _reviveCount > 0,
    );
    _runTimeCounted = time;
    _runStatCounted = statNow;
    // 코인 — 5초당 1개 + 추가 기록 보너스. 장비의 코인 보너스(gear.dart)를 합계에 곱한다.
    // 부활로 이어진 판은 이미 준 만큼 빼고 더 준다
    final bonus = CoinStore.bonusFor(_currentWorld.statKey, (result['graze'] as num?)?.toInt() ?? 0);
    final coinMult = 1 + Gear.bonusOf(_currentWorldId, CoinStore.equipped).coin;
    final earned = (((CoinStore.coinsForRun(time) + bonus) * coinMult).round() - _runCoins).clamp(0, 1 << 30);
    _runCoins += earned;
    await CoinStore.add(earned);
    result['coinsEarned'] = earned;
    result['coinsBonus'] = bonus;
    _bestTimes = await ProgressStore.getBestTimes();

    // 뱃지 — 판 결과(생존·스테이지·기술·경력·특별). 새로 얻은 건 결과 화면이 보여 준다(Badges.fresh)
    try {
      final isNewBest = time > prev;
      final bStats = await BadgeStatsStore.load();
      if (_reviveCount == 0) bStats.runs++;
      bStats.playTime += addedTime;
      if (isNewBest) bStats.newBests++;
      await BadgeStatsStore.save(bStats);
      final owned = CoinStore.ownedIds;
      await Badges.evaluate(BadgeContext(
        stage: _currentWorld.difficulty,
        time: time,
        statKey: _currentWorld.statKey,
        statCount: statNow,
        revive: _reviveCount,
        newBest: isNewBest,
        stats: bStats,
        ownedItems: owned.where((id) => !id.startsWith('char_')).length,
        ownedCharacters: CharacterData.availableCharacters.where((ch) => ch.price == 0 || owned.contains('char_${ch.id}')).length,
        attendanceStreak: (await DailyRewards.attendance()).streak,
        bestTimes: _bestTimes,
      ));
    } catch (e) {
      debugPrint('Badge check failed: $e');
    }

    // Update Stats
    UserProfileManager.updateGameStats(
      playTime: result['survivalTime'],
      mapId: result['mapId'] ?? _currentMapId,
    );
    // 유저별 플레이 기록(서버, 백오피스용) — 판마다 한 줄
    UserProfileManager.getProfile().then((p) => RunHistory.save({
          'stage': _currentWorld.difficulty,
          'mapId': _currentMapId,
          'time': time,
          'level': result['level'] ?? 0,
          'stat': _currentWorld.statKey,
          'statCount': result['graze'] ?? 0,
          'coins': earned,
          'bonus': bonus,
          'revive': _reviveCount,
          'character': p['characterId'] ?? '',
          'gear': [
            for (final slot in Gear.slotsOf(_currentWorld.id))
              if (Gear.wornId(_currentWorld.id, slot, CoinStore.equipped).isNotEmpty) Gear.wornId(_currentWorld.id, slot, CoinStore.equipped),
          ],
          'skin': CoinStore.equipped(Cosmetics.kindKey(CosmeticKind.skin), Cosmetics.defaultSkin),
          'best': time >= _previousBest && _reviveCount == 0,
        }));
    // 밸런스 확인용 플레이 로그(이 기기에만) — 통계 화면에서 CSV 로 복사
    UserProfileManager.getProfile().then((p) => PlaytestLog.add({
          'stage': _currentWorld.difficulty,
          'time': time,
          'level': result['level'] ?? 0,
          'stat': _currentWorld.statKey,
          'statCount': result['graze'] ?? 0,
          'coins': earned,
          'bonus': bonus,
          'revive': _reviveCount,
          'character': p['characterId'] ?? '',
        }));
    UserProfileManager.getProfile().then(
      (p) => AnalyticsService().logGameOver(
        mapId: result['mapId'] ?? _currentMapId,
        characterId: p['characterId'] ?? 'neon_green',
        survivalTime: result['survivalTime'],
        level: result['level'] ?? 0,
        reviveCount: _reviveCount,
      ),
    );

    if (!mounted) return;
    AnalyticsService().logScreen('Result');
    setState(() {
      _lastGameResult = result;
      _currentPage = 'Result';
    });
    // Show interstitial after state update, not inside setState callback
    AdManager().showInterstitialIfReady();
  }
}
