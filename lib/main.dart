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
import 'editor_game.dart';
import 'user_profile.dart';
import 'map_service.dart'; // Import MapService
import 'maze_generator.dart'; // Import MazeGenerator
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
import 'cosmetics.dart';
import 'gear.dart';
import 'zonber_painter.dart';
import 'game_art.dart';
import 'pages/home_page.dart';
import 'pages/ranking_page.dart';
import 'pages/result_page.dart';
import 'pages/hall_of_fame_page.dart';
import 'pages/profile_page.dart';
import 'package:provider/provider.dart'; // Added by instruction
import 'language_manager.dart'; // Added by instruction
import 'statistics_page.dart'; // Added by instruction
import 'game_config.dart'; // [NEW] Added for Stage Config
import 'backoffice/backoffice_home.dart'; // Added for Secret Admin
import 'firebase_options.dart'; // Added by instruction
import 'game_guide_sheet.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("ZONBER GAME: UPDATE VERIFIED - SYMMETRICAL CHARACTERS 2024-12-30");

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    // Moved initialization to _ZonberAppState to prevent Watchdog Timeout
  } else {
    print("Skipping Firebase/AdMob/IAP init on desktop/web");
  }

  // 테마는 첫 프레임 전에 읽는다 — 다크 사용자에게 라이트 스플래시가 번쩍이지 않게
  await GameSettings().load();
  AppColors.isDark = GameSettings().darkMode;

  // Status bar/nav bar: transparent, 아이콘 밝기는 테마를 따른다 (edge-to-edge compatible)
  SystemChrome.setSystemUIOverlayStyle(AppColors.overlayStyle);

  // Moved GameSettings, AudioManager, LanguageManager init to _ZonberAppState

  // 게임 그림(캐릭터·장비·공·이펙트)을 첫 화면 전에 읽어 둔다 — 없으면 코드 그림
  await GameArt.load();

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

class _ZonberAppState extends State<ZonberApp> {
  String _currentPage = 'Splash'; // Start with Splash to prevent Login flicker
  // ── 월드 ──
  String _currentWorldId = WorldData.defaultWorld.id;
  Map<String, double> _bestTimes = {};
  Map<String, RankCacheEntry> _rankCache = {};
  double _previousBest = 0.0; // 결과 화면 델타용 — 이번 판 이전 최고
  int _runCoins = 0; // 이번 판(부활 포함)에 이미 준 코인
  String _shopReturn = 'Menu'; // 상점에서 뒤로 가면 돌아갈 화면
  PlateData? _pendingPlate;   // Hall of Fame 진입 데이터
  /// 월드별 목표선 캐시(TOP 100/30/10/1 시간). 10분 유지.
  final Map<String, ({List<double> times, DateTime at})> _targetCache = {};

  WorldConfig get _currentWorld => WorldData.getWorld(_currentWorldId);
  String get _currentMapId => _currentWorld.rankingMapId;
  Map<String, dynamic>? _lastGameResult; // Store result data

  // Global Banner Ad State
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  bool _adsRemoved = false; // Track ad removal status

  // Verification State
  List<List<int>>? _verifyingMapData;
  String? _verifyingMapName;

  int _reviveCount = 0; // Track revives per game session

  // Current game instance (for accessing in callbacks)
  ZonberGame? _currentGame;
  BuildContext? _latestContext; // For back-button pause during game

  @override
  void initState() {
    super.initState();
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
    print(
      'Main: _handleLanguageChange triggered. Current: ${LanguageManager().currentLanguage}',
    );
    if (mounted) {
      setState(() {});
      print('Main: setState called for language change');
    }
  }

  Future<void> _initializeApp() async {
    // 1. Initialize Core Services (Firebase, AdMob, IAP)
    if (kIsWeb) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        print("✅ Firebase initialized (Web)");
      } catch (e) {
        print("❌ Firebase initialization failed (Web): $e");
      }
    } else if (Platform.isAndroid || Platform.isIOS) {
      try {
        await Firebase.initializeApp(); // Use default for mobile (google-services.json)
        print("✅ Firebase initialized (Mobile)");
      } catch (e) {
        print("❌ Firebase initialization failed (Mobile): $e");
      }

      // 동의 폼(UMP)·ATT 가 사용자 응답을 기다릴 수 있으므로 앱 시작을 막지 않는다.
      // 배너는 _checkAdStatus 에서 AdManager().whenReady 뒤에 요청한다.
      AdManager().initialize().then(
        (_) => print("✅ AdMob initialized"),
        onError: (e) => print("❌ AdMob initialization failed: $e"),
      );

      try {
        // await IAPService().initialize();
        print("✅ IAP initialized");
      } catch (e) {
        print("❌ IAP initialization failed: $e");
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
    print('📍 Refreshing purchase status...');

    // Dispose old banner ad
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerAdReady = false;

    // Refresh AdManager status
    await AdManager().refreshAdsStatus();

    // Reload purchase status
    await _checkAdStatus();

    print('📍 Purchase status refreshed. Ads removed: $_adsRemoved');
  }

  @override
  void dispose() {
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
          print("✅ Signed in anonymously for Backoffice");
        } catch (e) {
          print("❌ Backoffice Auth failed: $e");
        }
      }
      return; // Stay on Backoffice
    }

    // Normal App Flow — wait for Firebase to restore persisted session
    User? user = await FirebaseAuth.instance.authStateChanges().first;
    if (user == null) {
      // 게스트 기본화 — 첫 실행은 로그인 화면 없이 바로 게스트로 메뉴에 들어간다.
      // 로그인은 랭킹 등록처럼 계정이 필요한 시점에만 요구한다 (ResultPage → Login).
      await _enterAsGuest();
    } else {
      await _checkProfile();
    }
  }

  /// 익명 세션 + 게스트 프로필로 메뉴에 진입한다. 최초 실행과 로그아웃 직후에 쓴다.
  /// 익명 로그인이 실패해도(오프라인 등) 게스트 플레이는 가능해야 하므로 메뉴로 보낸다.
  Future<void> _enterAsGuest() async {
    final cred = await AuthService().signInAnonymously();
    final anonymousOk = cred != null ||
        (FirebaseAuth.instance.currentUser?.isAnonymous ?? false);
    await UserProfileManager.enableGuestMode();
    AnalyticsService().logGuestStart(anonymousAuthOk: anonymousOk);
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

  Future<void> _refreshProgress() async {
    _bestTimes = await ProgressStore.getBestTimes();
    _rankCache = await ProgressStore.getRankCache();
    if (mounted) setState(() {});
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
      case 'HallOfFame':
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
      case 'Editor':
      case 'EditorVerify':
        _navigateTo('Menu');
        break;

      case 'MyProfile':
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
                onTap: (i) => _navigateTo(const ['Menu', 'Ranking', 'Shop', 'MyProfile'][i]),
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
      case 'MyProfile':
        return 3;
    }
    return null;
  }

  Widget _buildPage(BuildContext context) {
    _latestContext = context;
    switch (_currentPage) {
      case 'Backoffice':
        return const BackofficeHome();
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
      case 'HallOfFame':
        return HallOfFamePage(
          plate: _pendingPlate!,
          onViewRanking: () => _navigateTo('Ranking'),
          onClose: () => _navigateTo('Menu'),
        );
      case 'Ranking':
        return RankingPage(
          key: ValueKey('ranking_$_currentWorldId'),
          initialWorldId: _currentWorldId,
          rankCache: _rankCache,
          onLogin: () => _navigateTo('Login'),
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
          onHallOfFame: (plate) {
            _pendingPlate = plate;
            _refreshProgress();
            _navigateTo('HallOfFame');
          },
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
      case 'EditorVerify':
        final game = ZonberGame(
          mapId: 'verify_mode',
          customMapData: {
            'grid': _verifyingMapData!.expand((x) => x).toList(),
            'width': _verifyingMapData![0].length,
            'height': _verifyingMapData!.length,
          },
          onExit: () => _navigateTo('Editor'), // Abort verification
          onGameOver: _onVerificationGameOver,
        );
        return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Column(
                children: [
                  Container(
                    height: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: AppColors.background,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: AppColors.primary,
                            size: 28,
                          ),
                          onPressed: () => _pauseGame(context, game),
                        ),
                        ValueListenableBuilder<double>(
                          valueListenable: game.survivalTimeNotifier,
                          builder: (context, value, child) {
                            return Text(
                              'TIME: ${value.toStringAsFixed(3)}',
                              style: AppTextStyles.display(32),
                            );
                          },
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(child: GameWidget(game: game)),
                ],
              ),
            ),
        );
      case 'Profile':
        return UserProfilePage(onComplete: () => _navigateTo('Menu'), onCancel: _cancelSignup);
      case 'MyProfile':
        return ProfilePage(
          key: ValueKey('profile_${_bestTimes.length}_${_rankCache.length}'),
          bestTimes: _bestTimes,
          rankCache: _rankCache,
          onOpenShop: () => _navigateTo('Shop'),
          onStatistics: () => _navigateTo('Statistics'),
          onLogin: () => _navigateTo('Login'),
          onCharacterSelect: () => _navigateTo('Shop'), // 캐릭터 고르기 = 상점 캐릭터 탭(첫 탭)
          onLogout: () async {
            print('Main: onLogout called');

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
                print('Main: AuthService signed out');
              } catch (e) {
                print('Main: Logout error (Auth): $e');
              }

              // 2. Clear local profile + 진행 데이터(게스트로 돌아가므로 기록도 함께)
              try {
                await UserProfileManager.clearProfile().timeout(
                  const Duration(seconds: 1),
                );
                await ProgressStore.clearLocal();
                await CoinStore.clearLocal();
                print('Main: Profile cleared');
              } catch (e) {
                print('Main: Logout error (Profile): $e');
              }

              // 3. Wait a bit for UI to settle
              await Future.delayed(const Duration(milliseconds: 500));
            } catch (e) {
              print('Main: Critical logout error: $e');
            } finally {
              // 4. Close loading indicator (use rootNavigator to be safe)
              if (mounted &&
                  Navigator.of(context, rootNavigator: true).canPop()) {
                Navigator.of(context, rootNavigator: true).pop();
              }

              // 5. 로그아웃 = 게스트로 복귀 (게스트 기본화). 로그인 화면은 필요할 때만 띄운다.
              AnalyticsService().logLogout();
              print('Main: Re-entering as guest after logout');
              await _enterAsGuest();
            }
          },
        );
      case 'Shop':
        return ShopPage(
          showBack: false, // 하단 탭 — 뒤로 가기 버튼 없음(안드로이드 뒤로 가기는 들어온 화면으로)
          onBack: () => _navigateTo(_shopReturn),
          onPurchaseReset: refreshPurchaseStatus,
        );
      case 'Statistics':
        return StatisticsPage(onBack: () => _navigateTo('MyProfile'));
      case 'Editor':
        return MapEditorPage(
          onVerify: _startVerification,
          onExit: () => _navigateTo('Menu'),
        );
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
          onGuide: () => GameGuideSheet.show(context),
          onSettings: () => _navigateTo('MyProfile'),
          onRanking: () => _navigateTo('Ranking'),
          onShop: () => _navigateTo('Shop'),
        );
    }
  }

  void _startVerification(List<List<int>> data, String name) {
    setState(() {
      _verifyingMapData = data;
      _verifyingMapName = name;
      _currentPage = 'EditorVerify';
    });
  }

  void _onVerificationGameOver(Map<String, dynamic> result) async {
    double time = result['survivalTime'];
    final langManager = LanguageManager.of(context, listen: false);

    if (time >= 30.0) {
      // Success
      bool success = await MapService().saveCustomMap(
        name: _verifyingMapName!,
        author: (await UserProfileManager.getProfile())['nickname']!,
        gridData: _verifyingMapData!,
        verified: true,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => NeonDialog(
          title: langManager.translate('verification_success'),
          titleColor: const Color(0xFF00FF88),
          message: success
              ? langManager.translate('map_verified_message')
              : "Verification passed, but upload failed.", // Fallback if internal error
          actions: [
            NeonButton(
              text: langManager.translate('ok'),
              onPressed: () {
                Navigator.pop(dialogContext);
                _navigateTo('Menu');
              },
            ),
          ],
        ),
      );
    } else {
      // Failed
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => NeonDialog(
          title: langManager.translate('verification_failed'),
          titleColor: AppColors.secondary,
          message:
              "${langManager.translate('verification_fail_message')}: ${time.toStringAsFixed(3)}s\n${langManager.translate('must_survive_30s')}",
          actions: [
            NeonButton(
              text: langManager.translate('try_again'),
              color: AppColors.primary,
              onPressed: () {
                Navigator.pop(dialogContext);
                _navigateTo('Editor'); // Go back to editor
              },
            ),
          ],
        ),
      );
    }
  }

  void _pauseGame(BuildContext context, ZonberGame game) {
    game.pauseEngine();
    final langManager = LanguageManager.of(context, listen: false);
    showNeonDialog(
      context: context,
      title: langManager.translate('paused'),
      message: (FirebaseAuth.instance.currentUser?.isAnonymous ?? true)
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
    // 부활로 이어진 판은 이전 최고를 그대로 둔다(첫 게임 오버의 값)
    final double time = result['survivalTime'];
    final prev = await ProgressStore.updateBestTime(_currentWorldId, time);
    if (_reviveCount == 0) {
      _previousBest = prev;
      _runCoins = 0;
    }
    // 코인 — 5초당 1개 + 추가 기록 보너스. 부활로 이어진 판은 이미 준 만큼 빼고 더 준다
    final bonus = CoinStore.bonusFor(_currentWorld.statKey, (result['graze'] as num?)?.toInt() ?? 0);
    final earned = (CoinStore.coinsForRun(time) + bonus - _runCoins).clamp(0, 1 << 30);
    _runCoins += earned;
    await CoinStore.add(earned);
    result['coinsEarned'] = earned;
    result['coinsBonus'] = bonus;
    _bestTimes = await ProgressStore.getBestTimes();

    // Update Stats
    UserProfileManager.updateGameStats(
      playTime: result['survivalTime'],
      mapId: result['mapId'] ?? _currentMapId,
    );
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

// ─────────────────────────────────────────────────────────────
// 게임 화면 — HUD(타이머·에너지·목표선) + 무대 + 근접 회피 카운터
// (docs/UI_DESIGN.md §4.3)
// ─────────────────────────────────────────────────────────────
class _GameScreen extends StatelessWidget {
  final ZonberGame game;
  final WorldConfig world;
  final VoidCallback onPause;
  const _GameScreen({required this.game, required this.world, required this.onPause});

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final accent = world.accent;
    // HUD 는 존 바닥색 위에 얹는다 — 앱 테마(라이트/다크)와 무관하게 무대와 한 덩어리로 보이게.
    final floor = world.floor;
    final darkFloor = floor.computeLuminance() < 0.4;
    final ink = darkFloor ? const Color(0xFFF2F4F8) : const Color(0xFF0F172A);
    final inkDim = ink.withValues(alpha: 0.6);
    final chip = ink.withValues(alpha: darkFloor ? 0.10 : 0.08);
    final up = darkFloor ? const Color(0xFF3DD68C) : const Color(0xFF15803D);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkFloor ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: floor,
        body: SafeArea(
          child: Column(
            children: [
              // ── 상단 HUD: 일시정지 · 생존 시간(+최고 기록) · 에너지 ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppIconButton(
                      icon: Icons.pause_rounded,
                      onTap: onPause,
                      label: lm.translate('paused'),
                      color: ink,
                      background: chip,
                    ),
                    Expanded(
                      child: ValueListenableBuilder<double>(
                        valueListenable: game.survivalTimeNotifier,
                        builder: (context, value, _) {
                          final pb = game.personalBest;
                          final beaten = pb > 0 && value > pb;
                          return Column(
                            children: [
                              // 소수점 셋째 자리까지 매 프레임 바뀌므로 숫자 폭을 고정해 흔들리지 않게
                              Text(formatClock(value),
                                  style: AppTextStyles.display(40, color: beaten ? up : ink)
                                      .copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                              const SizedBox(height: 4),
                              Text(
                                beaten
                                    ? lm.translate('hud_new_best')
                                    : pb > 0
                                        ? '${lm.translate('hud_best')} ${formatClock(pb)}'
                                        : lm.translate(world.nameKey).toUpperCase(),
                                style: AppTextStyles.label(color: beaten ? up : inkDim),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: _EnergyPips(notifier: game.energyNotifier, accent: accent, empty: chip),
                    ),
                  ],
                ),
              ),
              // ── 다음 목표선 (TOP 100 → 30 → 10 → 1) ──
              // 자리는 늘 같은 높이(34) — 목표선이 늦게 뜨거나(서버 응답) 1위를 넘어 사라질 때
              // 무대 높이가 바뀌면 맵이 다시 맞춰지며 꿈틀거렸다
              SizedBox(
                height: 34,
                child: ValueListenableBuilder<({String label, double time})?>(
                valueListenable: game.targetNotifier,
                builder: (context, target, _) {
                  if (target == null) return const SizedBox.shrink();
                  final guest = FirebaseAuth.instance.currentUser?.isAnonymous ?? true;
                  return ValueListenableBuilder<double>(
                    valueListenable: game.survivalTimeNotifier,
                    builder: (context, t, _) => Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
                      child: Row(
                        children: [
                          if (guest) ...[
                            Icon(Icons.lock_rounded, size: 12, color: inkDim),
                            const SizedBox(width: 4),
                          ],
                          Text(target.label, style: AppTextStyles.label(color: guest ? inkDim : ink)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                minHeight: 5,
                                value: target.time <= 0 ? 1 : (t / target.time).clamp(0.0, 1.0),
                                backgroundColor: chip,
                                valueColor: AlwaysStoppedAnimation(guest ? inkDim : accent),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(formatClock(target.time), style: AppTextStyles.display(12, color: inkDim)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              ),
              // ── 무대 — ZonberGame 이 가운데 맞춤으로 그린다 ──
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: GameWidget(game: game)),
                    // 붉은 번쩍임 — 맞거나 골을 먹으면 가장자리부터
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ValueListenableBuilder<int>(
                          valueListenable: game.flashNotifier,
                          builder: (context, v, _) => v == 0
                              ? const SizedBox.shrink()
                              : TweenAnimationBuilder<double>(
                                  key: ValueKey(v),
                                  tween: Tween(begin: 1, end: 0),
                                  duration: const Duration(milliseconds: 420),
                                  builder: (context, a, _) => DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        radius: 0.9,
                                        colors: [Colors.transparent, const Color(0xFFE5484D).withValues(alpha: 0.55 * a)],
                                        stops: const [0.55, 1],
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    // GOAL! · SAVE! 문구
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ValueListenableBuilder<GamePop?>(
                          valueListenable: game.popNotifier,
                          builder: (context, p, _) => p == null
                              ? const SizedBox.shrink()
                              : TweenAnimationBuilder<double>(
                                  key: ValueKey(p.id),
                                  tween: Tween(begin: 0, end: 1),
                                  duration: const Duration(milliseconds: 800),
                                  builder: (context, t, _) {
                                    final big = p.text.startsWith('GOAL');
                                    final scale = t < 0.25 ? 0.6 + t / 0.25 * 0.6 : 1.2 - (t - 0.25) * 0.25;
                                    final alpha = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
                                    return Align(
                                      alignment: big ? const Alignment(0, -0.1) : const Alignment(0, 0.45),
                                      child: Opacity(
                                        opacity: alpha.clamp(0.0, 1.0),
                                        child: Transform.scale(
                                          scale: scale,
                                          // GOAL! · SAVE! 는 글자 그림(assets/images/game/text_*.png), 'SAVE ×5' 같은 문구는 글자
                                          child: (p.text == 'GOAL!' || p.text == 'SAVE!')
                                              ? GameArt.image(
                                                  'text_${p.text == 'GOAL!' ? 'goal' : 'save'}',
                                                  width: big ? 260 : 150,
                                                  fallback: () => Text(p.text,
                                                      style: AppTextStyles.display(big ? 64 : 30, color: p.color).copyWith(
                                                        shadows: const [Shadow(color: Colors.white, blurRadius: 0, offset: Offset(0, 3))],
                                                      )),
                                                )
                                              : Text(p.text,
                                                  style: AppTextStyles.display(big ? 64 : 30, color: p.color).copyWith(
                                                    shadows: const [Shadow(color: Colors.white, blurRadius: 0, offset: Offset(0, 3))],
                                                  )),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                    // 시작 연출 문구 — 나의 ZONE → START!
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ValueListenableBuilder<String?>(
                          valueListenable: game.introNotifier,
                          builder: (context, phase, _) {
                            if (phase == null) return const SizedBox.shrink();
                            final isStart = phase == 'start';
                            return Center(
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey(phase),
                                tween: Tween(begin: 0.7, end: 1),
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutBack,
                                builder: (context, s, child) => Transform.scale(scale: s, child: child),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isStart ? (GameArt.enabled ? Colors.transparent : accent) : Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: isStart
                                      ? GameArt.image('text_start',
                                          width: 230,
                                          fallback: () => Text(lm.translate('intro_start'),
                                              textAlign: TextAlign.center,
                                              style: AppTextStyles.display(44, color: Colors.white)))
                                      // 스테이지별 미션 — 존버 정체성: [존]에서 [버]텨라 · [존]에서 [생]존하라 · [존]에서 [막]아라
                                      : EmphasisText(
                                          lm.translate('intro_mission_${game.worldConfig.id}'),
                                          style: AppTextStyles.display(28, color: Colors.white),
                                          dotColor: const Color(0xFFFFD23F),
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 16,
                      child: IgnorePointer(
                        child: ValueListenableBuilder<int>(
                          valueListenable: game.grazeNotifier,
                          builder: (context, g, _) => g == 0
                              ? const SizedBox.shrink()
                              : Center(
                                  child: Container(
                                    height: 28,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: floor.withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: chip),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(lm.translate(world.statKey),
                                            style: AppTextStyles.label(color: ink)),
                                        const SizedBox(width: 6),
                                        Text('×$g', style: AppTextStyles.display(14, color: accent)),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 에너지 핍 — 캐릭터 최대치만큼, 채워진 칸은 존 색. 충전 중인 칸은 반투명.
class _EnergyPips extends StatelessWidget {
  final ValueNotifier<({int current, int max, double chargeProgress, Color color})> notifier;
  final Color accent;
  final Color empty;
  const _EnergyPips({required this.notifier, required this.accent, required this.empty});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (_, e, __) {
        if (e.max == 0) return const SizedBox();
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (int i = 0; i < e.max; i++)
              Container(
                margin: const EdgeInsets.only(left: 3),
                width: e.max > 3 ? 7 : 10,
                height: 24,
                decoration: BoxDecoration(
                  color: i < e.current
                      ? accent
                      : i == e.current
                          ? accent.withValues(alpha: 0.15 + 0.5 * e.chargeProgress)
                          : empty,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        );
      },
    );
  }
}


class ZonberGame extends FlameGame with HasCollisionDetection, PanDetector {
  /// 장애물 레이아웃 id (`GameConfig.stages`) — 월드의 layoutId
  final String mapId;
  /// 월드 — 투사체·스포너·테마. 에디터 검증 모드는 기본 월드를 쓴다.
  final WorldConfig worldConfig;
  final VoidCallback onExit;
  final Function(Map<String, dynamic>) onGameOver; // Callback for game over
  final double initialSurvivalTime;
  /// 이 판 이전의 개인 최고(초) — HUD의 BEST 표시용
  final double personalBest;

  final Map<String, dynamic>? customMapData; // Optional map data

  ZonberGame({
    required this.mapId,
    WorldConfig? worldConfig,
    required this.onExit,
    required this.onGameOver,
    this.initialSurvivalTime = 0.0,
    this.personalBest = 0.0,
    this.customMapData,
  }) : worldConfig = worldConfig ?? WorldData.defaultWorld;

  // ── 목표선 / 근접 회피 ──
  List<({String label, double time})> _targets = const [];
  final ValueNotifier<({String label, double time})?> targetNotifier = ValueNotifier(null);
  final ValueNotifier<int> grazeNotifier = ValueNotifier(0);

  void setTargets(List<({String label, double time})> targets) {
    _targets = targets;
    _updateTarget();
  }

  void _updateTarget() {
    ({String label, double time})? next;
    for (final t in _targets) {
      if (t.time > survivalTime) {
        next = t;
        break;
      }
    }
    if (targetNotifier.value != next) targetNotifier.value = next;
  }

  static const double mapWidth = 480.0;
  static const double mapHeight =
      768.0; // Updated to 24x32 grid (fits aspect ratio)
  static const double worldHeight = 800.0; // (구) 무대+하단 조이스틱 영역. 화면 밖 판정에만 쓴다
  /// 무대 바깥 여백 — 테두리와 그림자가 화면 끝에 붙지 않게
  static const double arenaMargin = 10.0;

  late Player player;
  late BulletSpawner spawner;

  // ── 나의 ZONE · 시작 연출 ──
  /// 나의 존: 캐릭터가 움직일 수 있는 영역. 갤럭시 = 맵 전체, 피구 = 우리 진영, 골키퍼 = 페널티 에어리어
  Rect get zoneRect => worldConfig.playArea ?? const Rect.fromLTWH(0, 0, mapWidth, mapHeight);
  /// 화면에 보이는 무대 창 — 피구·골키퍼는 무대 일부(반코트)만 보여 준다.
  /// 기기 화면이 세로로 더 길면 [_fitView] 가 무대 안에서 창을 위(골키퍼) 또는 위아래(피구)로 늘린다.
  Rect get viewRect => _fittedView ?? worldConfig.view ?? const Rect.fromLTWH(0, 0, mapWidth, mapHeight);
  Rect? _fittedView;

  /// 게임 영역 크기 [screen] 에 맞춰 보이는 창을 정하고 카메라를 맞춘다.
  /// 폭을 꽉 채웠을 때 남는 세로 공간만큼 창을 늘린다(무대 480×768 밖으로는 안 나간다).
  void _fitView(Vector2 screen) {
    final base = worldConfig.view ?? const Rect.fromLTWH(0, 0, mapWidth, mapHeight);
    Rect vr = base;
    if (screen.x > 0 && screen.y > 0) {
      final aspect = screen.x / screen.y;
      final wantH = (base.width + arenaMargin * 2) / aspect - arenaMargin * 2;
      if (wantH > base.height + 1) {
        final extra = wantH - base.height;
        if (worldConfig.mode == WorldMode.keeper) {
          // 골문은 무대 맨 아래라 아래로는 못 늘린다 — 위로 절반만 늘려서
          // 경기장(창)이 화면 가운데에 오게 한다(남는 위아래는 같은 잔디색 여백)
          vr = Rect.fromLTRB(base.left, max(0, base.top - extra / 2), base.right, base.bottom);
        } else {
          final top = max(0.0, base.top - extra / 2);
          final bottom = min(mapHeight, base.bottom + extra / 2);
          // 한쪽이 무대 끝에 닿으면 남은 만큼 반대쪽으로
          final short = extra - ((base.top - top) + (bottom - base.bottom));
          vr = Rect.fromLTRB(base.left, max(0, top - short), base.right, min(mapHeight, bottom + short));
        }
      }
    }
    _fittedView = vr;
    camera.viewfinder.visibleGameSize = Vector2(vr.width + arenaMargin * 2, vr.height + arenaMargin * 2);
    camera.viewfinder.position = Vector2(vr.center.dx, vr.center.dy);
    camera.viewfinder.anchor = Anchor.center;
    if (isLoaded) mapArea.clip = vr;
  }
  /// 시작 전 남은 인트로 시간(초). 이 동안은 공이 나오지 않고 시간도 흐르지 않는다.
  double introLeft = 0;
  static const double introZone = 1.8; // 존 깜빡임
  static const double introStart = 0.7; // START!
  bool get inIntro => introLeft > 0;
  /// Flutter 오버레이 문구: 'zone' | 'start' | null
  final ValueNotifier<String?> introNotifier = ValueNotifier(null);

  // ── 타격감 연출 ──
  final Random _fxRng = Random();
  double _shakeT = 0, _shakeDur = 1, _shakeMag = 0, _hitStop = 0;
  /// 붉은 번쩍임 트리거(값이 바뀔 때마다 한 번)
  final ValueNotifier<int> flashNotifier = ValueNotifier(0);
  /// 크게 떴다 사라지는 문구 (GOAL! · SAVE! 등)
  final ValueNotifier<GamePop?> popNotifier = ValueNotifier(null);
  int _popId = 0;

  void shake(double mag, double dur) {
    if (mag < _shakeMag * (_shakeT / _shakeDur)) return;
    _shakeMag = mag;
    _shakeDur = dur;
    _shakeT = dur;
  }

  /// 아주 짧게 멈춰 "맞았다"를 느끼게 한다
  void hitStop(double seconds) => _hitStop = max(_hitStop, seconds);

  /// [at] 에서 [color] 파편이 튀어 퍼진다
  void burst(Vector2 at, Color color, {int count = 16, double speed = 220, double size = 3, String? art}) {
    mapArea.add(ParticleSystemComponent(
      position: at.clone(),
      priority: 14,
      particle: Particle.generate(
        count: count,
        lifespan: 0.5,
        generator: (i) {
          final a = _fxRng.nextDouble() * 2 * pi;
          final v = Vector2(cos(a), sin(a)) * (speed * (0.5 + _fxRng.nextDouble() * 0.7));
          return AcceleratedParticle(
            speed: v,
            acceleration: -v * 1.6,
            child: ComputedParticle(renderer: (canvas, p) {
              // 그림 입자(파편·별)가 있으면 그림을 돌리며, 없으면 색 점
              if (art != null &&
                  GameArt.draw(canvas, art, Offset.zero, size * 5 * (1 - p.progress * 0.5),
                      rotation: a + p.progress * 4, opacity: 1 - p.progress)) {
                return;
              }
              canvas.drawCircle(Offset.zero, size * (1 - p.progress * 0.6),
                  Paint()..color = color.withValues(alpha: 1 - p.progress));
            }),
          );
        },
      ),
    ));
  }

  void flash() => flashNotifier.value++;

  void pop(String text, Color color) => popNotifier.value = GamePop(text, color, ++_popId);

  /// 피격(피하기 존) — 흔들림 · 멈칫 · 파편 · 붉은 번쩍임
  void fxHit(Vector2 at, Color ballColor) {
    shake(7, 0.3);
    hitStop(0.07);
    burst(at, ballColor, count: GameArt.enabled ? 10 : 18, speed: 240, art: 'fx_shard');
    burst(at, Colors.white, count: 8, speed: 140, size: 2);
    flash();
  }

  /// 실점(골키퍼) — 큰 흔들림 · 멈칫 · 그물 앞 파편(문구는 띄우지 않는다)
  void fxGoal(Vector2 at) {
    shake(11, 0.45);
    hitStop(0.12);
    burst(at, Colors.white, count: GameArt.enabled ? 10 : 22, speed: 260, size: GameArt.enabled ? 3.5 : 3, art: 'fx_star');
    burst(at, const Color(0xFFE5484D), count: 12, speed: 180);
    flash();
  }

  /// 세이브 — 가벼운 흔들림 · 파편(문구·연속 표시는 띄우지 않는다)
  void fxSave(Vector2 at) {
    shake(3.5, 0.15);
    burst(at, Colors.white, count: GameArt.enabled ? 8 : 12, speed: 200, size: GameArt.enabled ? 3 : 2.5, art: 'fx_star');
  }

  /// 골키퍼 — 페널티킥 골문·슈터 상태
  final KeeperGoal goal = KeeperGoal();
  /// 피구 — 상대 팀(내야·외야 선수) 상태
  final DodgeTeam dodgeTeam = DodgeTeam();
  late MapArea mapArea;
  // Joystick removed for touch-anywhere control

  // Direct Drag Control State
  Vector2 _dragDeltaAccumulator = Vector2.zero();

  Vector2 consumeDragDelta() {
    Vector2 delta = _dragDeltaAccumulator.clone();
    _dragDeltaAccumulator.setZero();
    return delta;
  }

  // UI Logic
  final ValueNotifier<double> survivalTimeNotifier = ValueNotifier(0.0);

  /// 에너지(실드) 상태 — Player가 매 프레임 업데이트
  final ValueNotifier<({int current, int max, double chargeProgress, Color color})>
      energyNotifier = ValueNotifier((
    current: 0,
    max: 0,
    chargeProgress: 0.0,
    color: AppColors.primary,
  ));

  double survivalTime = 0.0;
  bool isGameOver = false;
  String? lastRecordId; // Last saved record ID

  @override
  Color backgroundColor() => worldConfig.floor;

  @override
  Future<void> onLoad() async {
    // 무대 전체(+테두리 여백)를 가운데 맞춤 — 세로가 긴 폰에서는 위아래가 존 바닥색으로 고르게 남는다
    camera.viewfinder.anchor = Anchor.center;

    world.add(GridBackground()..priority = 5);
    mapArea = MapArea();
    world.add(mapArea);

    // Joystick removed

    // Check if custom map
    if (mapId.startsWith('custom_')) {
      _loadCustomMap(mapId);
    } else if (customMapData != null) {
      // Verify Mode or Direct Play
      startGame(customMapData: customMapData, initialTime: initialSurvivalTime);
    } else {
      startGame(initialTime: initialSurvivalTime);
    }
  }

  Future<void> _loadCustomMap(String id) async {
    final mapData = await MapService().getMap(id);
    if (mapData != null) {
      startGame(customMapData: mapData);
    } else {
      print("Failed to load custom map");
      onExit(); // Exit if failed
    }
  }

  void startGame({
    Map<String, dynamic>? customMapData,
    double initialTime = 0.0,
  }) {
    isGameOver = false;
    survivalTime = initialTime;
    survivalTimeNotifier.value = initialTime;
    lastRecordId = null;

    // Track Play Count
    // Track Play Count - Moved to RankingSystem.saveRecord (Global)
    // UserProfileManager.incrementMapPlayCount(mapId);

    overlays.remove('GameOverMenu');
    // overlays.add('GameUI'); // Removed old overlay

    mapArea.removeAll(mapArea.children);
    _addStageBackground();

    final bool keeper = worldConfig.mode == WorldMode.keeper;
    if (keeper) mapArea.add(GoalZone()..priority = 1);
    if (worldConfig.court != null) mapArea.add(DodgeTeamZone()..priority = 2);
    // 새 판은 존 깜빡임부터, 부활로 이어지는 판은 START! 만
    introLeft = initialSurvivalTime > 0 ? introStart : introZone + introStart;
    // introNotifier 는 여기(onLoad — Flutter 가 화면을 짓는 중)서 바꾸지 않는다. 첫 update 에서 설정된다.
    // (빌드 도중 ValueNotifier 를 바꾸면 릴리스 웹에서 HUD 갱신이 멈췄다)
    mapArea.add(ZoneIntro()..priority = 16);
    player = Player()
      ..keeperMode = keeper
      // Keeper 는 골대 바로 아래에서 시작한다
      ..position = keeper
          ? Vector2(mapWidth / 2, KeeperGoal.keeperY) // 골문 정면
          : worldConfig.playArea != null
              ? Vector2(worldConfig.playArea!.center.dx, worldConfig.playArea!.center.dy)
              : Vector2(mapWidth / 2, mapHeight / 2)
      ..width = 48
      ..height = 48
      ..anchor = Anchor.center
      ..priority = 10; // Ensure player is above trail (trail will be 0 or -1)
    mapArea.add(player);

    camera.stop();
    _fitView(size);
    mapArea.clip = viewRect;

    spawner = BulletSpawner();
    mapArea.add(spawner);


    if (customMapData != null) {
      _spawnCustomObstacles(customMapData);
    } else {
      _spawnFixedObstacles(mapId); // Config-based spawning
    }

    resumeEngine();

    // Start BGM
    AudioManager().startBgm();
  }

  /// 스테이지 배경 이미지 — `assets/images/worlds/{id}_bg.png`(더미 또는 실아트).
  /// 없으면 `worldConfig.floor` 색만 쓴다.
  Future<void> _addStageBackground() async {
    try {
      final sprite = await loadSprite('worlds/${worldConfig.id}_bg.png');
      if (isGameOver) return;
      mapArea.add(SpriteComponent(sprite: sprite, size: Vector2(mapWidth, mapHeight), priority: -1));
    } catch (_) {
      // 배경 에셋 없음 — 바닥색만
    }
  }

  void _spawnCustomObstacles(Map<String, dynamic> data) {
    List<dynamic> grid = data['grid'];
    int width = data['width'];
    // Dynamic Tile Size: Fits any grid width (12 or 15) to the fixed MapWidth (480)
    double tileSize = mapWidth / width;

    for (int i = 0; i < grid.length; i++) {
      if (grid[i] == 1) {
        int x = i % width;
        int y = (i / width).floor();

        mapArea.add(
          Obstacle(
            Vector2(x * tileSize, y * tileSize),
            Vector2(tileSize, tileSize),
          ),
        );
      }
    }
  }

  // _spawnObstacles (Random) removed in favor of fixed layouts

  void _spawnFixedObstacles(String mapId) {
    double w = mapWidth;
    double h = mapHeight;
    double centerX = w / 2;
    double centerY = h / 2;

    // Helper to add symmetrical obstacles (mirrors X and Y around center)
    void addSymmetrical(double dx, double dy, double width, double height) {
      mapArea.add(Obstacle(Vector2(centerX + dx, centerY + dy), Vector2(width, height)));
      mapArea.add(Obstacle(Vector2(centerX - dx - width, centerY - dy - height), Vector2(width, height)));
      mapArea.add(Obstacle(Vector2(centerX + dx, centerY - dy - height), Vector2(width, height)));
      mapArea.add(Obstacle(Vector2(centerX - dx - width, centerY + dy), Vector2(width, height)));
    }

    if (mapId == 'zone_2_obstacles') {
      // 4 Pillars (closer to center)
      double size = 100;
      double dist = 70;
      addSymmetrical(dist, dist, size, size);
    } else if (mapId == 'zone_5_maze') {
      // Connected Maze with Safe Border & Entrances
      double cellSize = 60;
      double wallThickness = 5;

      double availableW = mapWidth - cellSize * 2;
      double availableH = mapHeight - cellSize * 2;

      int cols = (availableW / cellSize).floor();
      int rows = (availableH / cellSize).floor();

      double offsetX = (mapWidth - (cols * cellSize)) / 2;
      double offsetY = (mapHeight - (rows * cellSize)) / 2;

      MazeGenerator generator = MazeGenerator(rows, cols, seed: 12345);
      List<List<dynamic>> walls = generator.generate();

      Random rng = Random(67890);

      for (var wall in walls) {
        int c = wall[0];
        int r = wall[1];
        bool isHorizontal = wall[2];

        bool isBoundary = false;
        if (isHorizontal) {
          if (r == 0 || r == rows) isBoundary = true;
        } else {
          if (c == 0 || c == cols) isBoundary = true;
        }

        if (isBoundary && rng.nextDouble() < 0.2) continue;

        double x = c * cellSize + offsetX;
        double y = r * cellSize + offsetY;

        if (x > mapWidth / 2 - 80 && x < mapWidth / 2 + 80 && y > mapHeight / 2 - 80 && y < mapHeight / 2 + 80) {
          continue;
        }

        if (isHorizontal) {
          mapArea.add(Obstacle(Vector2(x, y), Vector2(cellSize, wallThickness)));
        } else {
          mapArea.add(Obstacle(Vector2(x, y), Vector2(wallThickness, cellSize)));
        }
      }
    }
  }

  void gameOver() {
    if (isGameOver) return;
    isGameOver = true;

    pauseEngine();

    // Stop BGM and Play Game Over
    AudioManager().stopBgm();
    AudioManager().playSfx('gameover.wav');

    // Notify App
    onGameOver({
      'survivalTime': recordTime(survivalTime), // 소수점 셋째 자리까지
      'mapId': worldConfig.rankingMapId,
      'level': spawner.currentLevel,
      'graze': player.isMounted ? player.grazeCount : grazeNotifier.value,
    });
  }

  @override
  void update(double dt) {
    // 멈칫(hit-stop) — 모든 움직임을 아주 잠깐 멈춘다
    if (_hitStop > 0) {
      _hitStop -= dt;
      return;
    }
    super.update(dt);

    // 화면 흔들림
    final base = Vector2(viewRect.center.dx, viewRect.center.dy);
    if (_shakeT > 0) {
      _shakeT -= dt;
      final m = _shakeMag * (_shakeT / _shakeDur).clamp(0.0, 1.0);
      camera.viewfinder.position = base + Vector2((_fxRng.nextDouble() - 0.5) * 2 * m, (_fxRng.nextDouble() - 0.5) * 2 * m);
    } else {
      _shakeMag = 0;
      camera.viewfinder.position = base;
    }

    // 시작 연출 — 나의 존 깜빡임 → START! → 시작
    if (inIntro) {
      introLeft -= dt;
      final phase = introLeft > introStart ? 'zone' : (introLeft > 0 ? 'start' : null);
      if (introNotifier.value != phase) introNotifier.value = phase;
      return;
    }

    if (!isGameOver) {
      survivalTime += dt;
      survivalTimeNotifier.value = survivalTime;
      if (_targets.isNotEmpty) _updateTarget();
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // 기기·창 크기가 바뀌면 보이는 무대 창을 다시 맞춘다
    if (isLoaded) _fitView(size);
  }

  // PanDetector Implementation for Direct Touch Control
  @override
  void onPanUpdate(DragUpdateInfo info) {
    _dragDeltaAccumulator += info.delta.global;
  }
}



class MapArea extends PositionComponent {
  MapArea() : super(size: Vector2(ZonberGame.mapWidth, ZonberGame.mapHeight));

  /// 보이는 무대 창 — 이 바깥(배경 그림·공)은 그리지 않는다
  Rect? clip;

  @override
  void renderTree(Canvas canvas) {
    final c = clip;
    if (c == null) return super.renderTree(canvas);
    canvas.save();
    canvas.clipRect(c);
    super.renderTree(canvas);
    canvas.restore();
  }

  @override
  void render(Canvas canvas) {
    canvas.clipRect(size.toRect());
    super.render(canvas);
  }
}

class Obstacle extends PositionComponent
    with CollisionCallbacks, HasGameRef<ZonberGame> {
  // 장애물은 탄환(빨강)과 반드시 구분되어야 한다 — 무채색 스틸 계열 사용.
  final Paint _paint = Paint()
    ..color = AppColors.obstacle
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);

  final Paint _fillPaint = Paint()
    ..color = AppColors.obstacle.withValues(alpha: 0.22)
    ..style = PaintingStyle.fill;

  Obstacle(Vector2 position, Vector2 size) {
    this.position = position;
    this.size = size;
  }

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Draw neon box
    canvas.drawRect(size.toRect(), _fillPaint);
    canvas.drawRect(size.toRect(), _paint);
  }
}

/// 존 테두리 — 무대(배경 이미지·공) 위에 그린다. 바깥쪽은 존 바닥색이 이어진다.
class GridBackground extends Component with HasGameRef<ZonberGame> {
  @override
  void render(Canvas canvas) {
    final rect = gameRef.viewRect;
    // 바깥 가장자리를 살짝 눌러 무대가 떠 보이게
    canvas.drawRect(
      rect.inflate(3),
      Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = gameRef.worldConfig.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
}

/// Keeper 월드의 골대 존 — 맵 중앙 원. 공이 들어오면 실점(Bullet.update 가 판정). 렌더 전용.

class Player extends SpriteComponent
    with CollisionCallbacks, HasGameRef<ZonberGame> {
  String characterId = 'neon_green';
  /// Keeper 월드: 공에 닿으면 세이브, 다치지 않는다. 목숨은 월드 lives.
  bool keeperMode = false;
  Color trailColor = AppColors.primary;
  /// 꾸미기 — 착용한 잔상·오라(상점). 판정에는 영향 없음
  String trailId = Cosmetics.defaultTrail;
  String auraId = Cosmetics.defaultAura;
  String skinId = Cosmetics.defaultSkin;
  /// 존 장비 — 부위별 장착 id(gear.dart). 존에 맞춰 자동 장착, 상점에서 바꾼다
  List<String> gearIds = const [];
  double _auraT = 0;

  // --- 표정·몸짓(존버) ---
  ZonberFace _face = ZonberFace.normal;
  double _faceTimer = 0;
  double _squash = 0;
  bool _moving = false;

  /// 잠깐 표정을 바꾼다 — 아야(맞음·실점) / 신남(아슬아슬·세이브)
  void showFace(ZonberFace f, double seconds, {bool squash = false}) {
    // 아야가 신남보다 우선
    if (_face == ZonberFace.hurt && _faceTimer > 0 && f == ZonberFace.happy) return;
    _face = f;
    _faceTimer = seconds;
    if (squash) _squash = 1;
  }

  // --- 캐릭터 스탯 (onLoad에서 CharacterStats로부터 설정) ---
  double _hbHalf = 12.0;       // 히트박스 절반 크기
  double _speedMult = 1.0;     // 이동 속도 배수
  int _maxShields = 0;         // 최대 실드 개수
  double _shieldCooldown = 0;  // 기력 기반 회복 속도 (낮을수록 빠름)
  double _iframeDuration = 1.5; // 회피: 피격 후 무적 시간 (캐릭터별)
  // --- 런타임 상태 ---
  double _energy = 0;       // 현재 에너지 (0.0 ~ _maxShields)
  bool _isInvincible = false;
  double _invincibleTimer = 0;
  double _invincibleDuration = 1.5; // 이번 무적의 지속 시간 (파워업으로 연장 가능)
  bool _isBlinking = false;
  double _blinkTimer = 0;
  bool _blinkVisible = true;

  // --- 추가 기록(스테이지별, WorldConfig.statKey). 셀 때마다 보너스 코인 ---
  // 갤럭시 근접 회피 · 피구 아슬 회피: 히트박스 바깥 링을 스치고 지나간 탄(피구는 링이 더 좁다)
  int grazeCount = 0;
  final Set<Bullet> _grazing = {};
  // 난이도를 비슷하게: 탄이 많은 갤럭시는 링을 더 좁게, 공이 적은 피구는 조금 넓게
  static const double _grazeRing = 4.0;
  static const double _closeDodgeRing = 5.0;

  void _updateGraze() {
    final ring = _hbHalf + (gameRef.worldConfig.statKey == 'close_dodge' ? _closeDodgeRing : _grazeRing);
    _grazing.removeWhere((b) => !b.isMounted); // 피격·소멸된 탄은 카운트하지 않는다
    for (final c in gameRef.mapArea.children) {
      if (c is! Bullet) continue;
      final d = c.position.distanceTo(position);
      final r = ring + c.def.radius;
      if (d < r) {
        _grazing.add(c);
      } else if (_grazing.contains(c) && d > r + 6) {
        _grazing.remove(c);
        grazeCount++;
        gameRef.grazeNotifier.value = grazeCount;
        showFace(ZonberFace.happy, 0.45);
      }
    }
  }

  @override
  Future<void> onLoad() async {
    // 캐릭터 스탯 먼저 로드
    final profile = await UserProfileManager.getProfile();
    characterId = profile['characterId'] ?? 'neon_green';
    final char = CharacterData.getCharacter(characterId);
    final stats = char.stats;
    trailColor = char.color;
    await CoinStore.load();
    trailId = CoinStore.equipped(Cosmetics.kindKey(CosmeticKind.trail), Cosmetics.defaultTrail);
    auraId = CoinStore.equipped(Cosmetics.kindKey(CosmeticKind.aura), Cosmetics.defaultAura);
    skinId = CoinStore.equipped(Cosmetics.kindKey(CosmeticKind.skin), Cosmetics.defaultSkin);
    // 존 장비 — 부위마다 장착한 것(기본은 없음). 능력치 보너스를 모은다(지금은 전부 0)
    final zone = gameRef.worldConfig.id;
    var bonus = GearBonus.none;
    final ids = <String>[];
    for (final slot in Gear.slotsOf(zone)) {
      final item = Gear.byId(Gear.wornId(zone, slot, CoinStore.equipped));
      if (item == null) continue; // 안 입은 부위
      ids.add(item.id);
      bonus = bonus + item.bonus;
    }
    gearIds = ids;

    // 모든 캐릭터 동일한 시각 크기 및 히트박스
    const double visualSize = 42;
    const double hitboxSize = 22;
    size = Vector2(visualSize, visualSize);

    // 스탯 적용 — 캐릭터 공통 기본값 + 장비 보너스
    _hbHalf = 11.0; // 고정 히트박스 22px의 절반
    _speedMult = stats.speedMultiplier + bonus.speed;
    _maxShields = stats.maxEnergy + bonus.energy;
    _shieldCooldown = max(1.0, stats.energyCooldown - bonus.recovery);
    _iframeDuration = stats.iframeDuration + bonus.iframe;
    _invincibleDuration = _iframeDuration;
    _energy = _maxShields.toDouble(); // 최대치로 시작
    if (keeperMode) {
      // Keeper: 목숨 = 허용 골 수(월드 lives), 회복 없음. 무적은 쓰이지 않는다.
      // 막는 범위는 몸 크기만큼 넉넉하게(36px) — 골문 폭 280 을 한 명이 지킨다
      _hbHalf = 18.0;
      _maxShields = gameRef.worldConfig.lives;
      _shieldCooldown = 0;
      _energy = _maxShields.toDouble();
    }

    // 히트박스: 시각 크기 중앙에 배치
    const double hbOffset = (visualSize - hitboxSize) / 2;
    add(
      RectangleHitbox(
        position: Vector2(hbOffset, hbOffset),
        size: Vector2(hitboxSize, hitboxSize),
      ),
    );

    // 캐릭터는 코드로 그린다(render — paintZonber). 스프라이트 이미지는 쓰지 않는다

    // 초기 에너지 상태 HUD에 반영
    _notifyEnergy();
  }

  void _notifyEnergy() {
    final int current = _energy.floor().clamp(0, _maxShields);
    final double progress = _energy - current;
    gameRef.energyNotifier.value = (
      current: current,
      max: _maxShields,
      chargeProgress: progress,
      color: trailColor,
    );
  }

  @override
  void render(Canvas canvas) {
    // 깜빡임 중 비가시 프레임이면 스킵
    if (_isBlinking && !_blinkVisible) return;

    // 오라 — 몸이 기울어도 오라(왕관·고리)는 똑바로 서 있게 기울기를 되돌려 그린다
    final r = size.x * 0.43;
    void upright(void Function() draw) {
      canvas.save();
      canvas.translate(size.x / 2, size.y / 2);
      canvas.rotate(-angle);
      draw();
      canvas.restore();
    }
    final hasAura = auraId != Cosmetics.defaultAura;
    super.render(canvas); // 스프라이트 없음 — 규약상 호출만
    if (hasAura) upright(() => paintAura(canvas, auraId, Offset.zero, r, _auraT, trailColor, front: false));
    // 존버 — 몸 반지름 16(판정 히트박스는 22px 그대로), 손발·장비가 조금 삐져나온다
    final v = recentVelocity;
    paintZonber(
      canvas,
      Offset(size.x / 2, size.y / 2),
      16,
      ZonberLook(
        color: trailColor,
        body: characterId,
        skin: skinId,
        face: _face,
        gear: gearIds,
        t: _auraT,
        moving: _moving,
        squash: _squash,
        look: Offset(v.x / 300, v.y / 300),
      ),
    );
    if (hasAura) upright(() => paintAura(canvas, auraId, Offset.zero, r, _auraT, trailColor, front: true));
  }

  /// 최근 이동 속도(px/s, 지수 평활) — 피구 극악 단계의 예측 조준에 쓴다
  Vector2 recentVelocity = Vector2.zero();
  Vector2? _prevPos;

  @override
  void update(double dt) {
    super.update(dt);
    _auraT += dt;
    if (_prevPos != null && dt > 0) {
      recentVelocity = recentVelocity * 0.85 + (position - _prevPos!) / dt * 0.15;
    }
    _prevPos = position.clone();

    // --- 무적 타이머 ---
    // 깜빡임은 무적이 끝날 때까지 계속된다. 캐릭터마다 무적 시간이 다르므로
    // (1.0s ~ 2.5s) 고정 횟수로 끊으면 "아직 무적인지" 알 수 없게 된다.
    if (_isInvincible) {
      _invincibleTimer += dt;

      // 종료 직전 0.4초는 깜빡임을 빠르게 해 곧 풀린다는 신호를 준다
      final remaining = _invincibleDuration - _invincibleTimer;
      final blinkInterval = remaining <= 0.4 ? 0.05 : 0.12;

      _blinkTimer += dt;
      if (_blinkTimer >= blinkInterval) {
        _blinkTimer = 0;
        _blinkVisible = !_blinkVisible;
      }

      if (_invincibleTimer >= _invincibleDuration) {
        _isInvincible = false;
        _invincibleTimer = 0;
        _invincibleDuration = _iframeDuration; // 연장분 초기화
        _isBlinking = false;
        _blinkVisible = true;
      }
    }

    // --- 에너지 자동 회복 (캐릭터별 cooldown) ---
    if (_maxShields > 0 && _shieldCooldown > 0 && _energy < _maxShields) {
      _energy += dt / _shieldCooldown;
      if (_energy > _maxShields) _energy = _maxShields.toDouble();
    }

    // --- 에너지 HUD 업데이트 ---
    _notifyEnergy();

    // --- 근접 회피 ---
    if (!keeperMode && !_isInvincible && !gameRef.isGameOver) _updateGraze();

    // Check if moving
    Vector2 rawDrag = gameRef.consumeDragDelta();
    // 최종 이동량 = 손가락 이동 × 캐릭터 속도 × 유저 감도 설정
    Vector2 dragInput = rawDrag * (_speedMult * GameSettings().sensitivity);
    bool isMoving = !rawDrag.isZero();
    _moving = isMoving || recentVelocity.length2 > 400;

    // 표정·납작함이 돌아온다. 몸은 도는 대신 가는 쪽으로 살짝 기운다
    if (_faceTimer > 0) {
      _faceTimer -= dt;
      if (_faceTimer <= 0) _face = ZonberFace.normal;
    }
    _squash = max(0, _squash - dt * 5);
    angle = (recentVelocity.x * 0.0009).clamp(-0.22, 0.22);

    // --- 아이들 연기 (항상, 캐릭터 뒤편 perimeter에서 사방으로 뿜음) ---
    if (Random().nextDouble() < 0.12) {
      final idleAngle = Random().nextDouble() * 2 * pi;
      final edgeRadius = 10.0 + Random().nextDouble() * 4.0;
      final spawnPos = position + Vector2(cos(idleAngle) * edgeRadius, sin(idleAngle) * edgeRadius);
      final burstSpeed = 45.0 + Random().nextDouble() * 65.0;
      gameRef.mapArea.add(
        ParticleSystemComponent(
          priority: 0,
          particle: AcceleratedParticle(
            lifespan: 0.6 + Random().nextDouble() * 0.5,
            position: spawnPos,
            speed: Vector2(cos(idleAngle) * burstSpeed, sin(idleAngle) * burstSpeed),
            child: ComputedParticle(
              renderer: (canvas, particle) {
                final sz = 6.0 * (1.0 - particle.progress);
                canvas.drawCircle(
                  Offset.zero,
                  sz / 2,
                  Paint()
                    ..color = trailColor.withOpacity((1.0 - particle.progress) * 0.6)
                    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
                );
              },
            ),
          ),
        ),
      );
    }

    // --- MOVEMENT LOGIC ---
    if (isMoving) {
      // 이동 트레일 (적당히 — 뒤쪽에서 뿜음)
      // 꾸미기 잔상은 조금 더 촘촘하게 — 산 티가 나도록
      if (Random().nextDouble() < (trailId == Cosmetics.defaultTrail ? 0.28 : 0.45)) {
        // 이동 방향의 반대(뒤쪽)에 편향된 각도
        final backAngle = atan2(-rawDrag.y, -rawDrag.x) + (Random().nextDouble() - 0.5) * pi;
        final trailSpeed = 20.0 + Random().nextDouble() * 30.0;
        final spawnOffset = Vector2(cos(backAngle) * 8, sin(backAngle) * 8);
        final seed = Random().nextDouble();
        final style = trailId;
        gameRef.mapArea.add(
          ParticleSystemComponent(
            priority: 0,
            particle: AcceleratedParticle(
              lifespan: 0.35 + Random().nextDouble() * 0.25,
              position: position + spawnOffset,
              speed: Vector2(cos(backAngle) * trailSpeed, sin(backAngle) * trailSpeed),
              child: ComputedParticle(
                // 착용한 잔상 모양으로(상점 꾸미기). 기본은 캐릭터 색 점
                renderer: (canvas, particle) =>
                    paintTrailParticle(canvas, style, particle.progress, seed, trailColor),
              ),
            ),
          ),
        );
      }

      // Player has anchor=Anchor.center, so position = center of the sprite.
      // Clamp so the hitbox (centered at position, half=12.5) stays within map.

      // 1. Move X, then resolve all X overlaps
      position.x = (position.x + dragInput.x).clamp(_hbHalf, ZonberGame.mapWidth  - _hbHalf);
      _resolveCollisionsX();

      // 2. Move Y, then resolve all Y overlaps
      position.y = (position.y + dragInput.y).clamp(_hbHalf, ZonberGame.mapHeight - _hbHalf);
      _resolveCollisionsY();

      // 피구 등: 이동 영역(우리 편 진영) 안으로
      final pa = gameRef.worldConfig.playArea;
      if (pa != null) {
        position.x = position.x.clamp(pa.left + _hbHalf, pa.right - _hbHalf);
        position.y = position.y.clamp(pa.top + _hbHalf, pa.bottom - _hbHalf);
      }

    }
  }

  Rect _hitboxRect() => Rect.fromLTWH(
        position.x - _hbHalf,
        position.y - _hbHalf,
        _hbHalf * 2,
        _hbHalf * 2,
      );

  // Push player out of all overlapping obstacles along X axis only
  void _resolveCollisionsX() {
    final double minX = _hbHalf;
    final double maxX = ZonberGame.mapWidth - _hbHalf;
    for (int pass = 0; pass < 3; pass++) {
      bool resolved = false;
      for (final other in gameRef.mapArea.children) {
        if (other is Obstacle) {
          final Rect obs = Rect.fromLTWH(other.x, other.y, other.width, other.height);
          final Rect hb = _hitboxRect();
          if (!hb.overlaps(obs)) continue;

          final double overlapLeft  = obs.right - hb.left;  // push right
          final double overlapRight = hb.right  - obs.left; // push left
          final double push = overlapLeft < overlapRight ? overlapLeft : -overlapRight;
          position.x = (position.x + push).clamp(minX, maxX);
          resolved = true;
        }
      }
      if (!resolved) break;
    }
  }

  // Push player out of all overlapping obstacles along Y axis only
  void _resolveCollisionsY() {
    final double minY = _hbHalf;
    final double maxY = ZonberGame.mapHeight - _hbHalf;
    for (int pass = 0; pass < 3; pass++) {
      bool resolved = false;
      for (final other in gameRef.mapArea.children) {
        if (other is Obstacle) {
          final Rect obs = Rect.fromLTWH(other.x, other.y, other.width, other.height);
          final Rect hb = _hitboxRect();
          if (!hb.overlaps(obs)) continue;

          final double overlapTop    = obs.bottom - hb.top;    // push down
          final double overlapBottom = hb.bottom  - obs.top;   // push up
          final double push = overlapTop < overlapBottom ? overlapTop : -overlapBottom;
          position.y = (position.y + push).clamp(minY, maxY);
          resolved = true;
        }
      }
      if (!resolved) break;
    }
  }


  // 골키퍼 연속 선방 — 직전 세이브 후 이 시간(초) 안에 또 막으면 1 센다
  static const double _streakWindow = 1.0;
  double _lastSaveAt = -100;

  /// Keeper: 키퍼에 맞은 공이 골문을 벗어났다 — 세이브 확정
  void creditSave(Vector2 at) {
    if (gameRef.isGameOver) return;
    final now = gameRef.survivalTime;
    if (now - _lastSaveAt <= _streakWindow) {
      grazeCount++;
      gameRef.grazeNotifier.value = grazeCount;
    }
    _lastSaveAt = now;
    gameRef.fxSave(at);
    showFace(ZonberFace.happy, 0.7);
    AudioManager().playSfx('shoot.wav', volume: 0.7);
    if (GameSettings().vibrationEnabled) HapticFeedback.lightImpact();
  }

  /// Keeper: 골을 허용했다 — 목숨 1 소모. 0이면 게임 오버.
  void concedeGoal() {
    if (gameRef.isGameOver) return;
    showFace(ZonberFace.hurt, 0.9, squash: true);
    _energy = (_energy - 1.0).clamp(0.0, _maxShields.toDouble());
    _notifyEnergy();
    AudioManager().playSfx('hit.wav');
    if (GameSettings().vibrationEnabled) HapticFeedback.heavyImpact();
    if (_energy <= 0) gameRef.gameOver();
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (other is Bullet) {
      if (keeperMode) {
        // 막기 — 키퍼에 닿으면 공이 몸에서 튕긴다. 정면으로 맞으면 크게 꺾이고, 살짝 스치면 방향만 조금 바뀐다.
        // 세이브는 여기서 정하지 않는다 — 꺾이고도 골문으로 들어가면 골이다(Bullet._keeperUpdate 가 판정).
        if (other.deflected || other.scored || other.keeperCd > 0) return;
        final n = other.position - position;
        other.keeperTouch(n.length2 == 0 ? -other.velocity : n);
        other.position = position + (n.length2 == 0 ? Vector2(0, -1) : n.normalized()) * (_hbHalf + other.def.radius + 2);
        gameRef.burst(other.position.clone(), Colors.white, count: 6, speed: 120, size: 2);
        AudioManager().playSfx('shoot.wav', volume: 0.5);
        if (GameSettings().vibrationEnabled) HapticFeedback.selectionClick();
        return;
      }
      if (_isInvincible) {
        // 무적 중 — 총알만 제거
        other.removeFromParent();
        return;
      }
      if (_energy >= 1.0) {
        // 에너지 1 소모 → 캐릭터별 무적 시간 부여
        _energy -= 1.0;
        _invincibleDuration = _iframeDuration;
        _invincibleTimer = 0;
        _isInvincible = true;
        _isBlinking = true;
        _blinkTimer = 0;
        _blinkVisible = false;
        _notifyEnergy();
        showFace(ZonberFace.hurt, 0.8, squash: true);
        gameRef.fxHit(other.position.clone(), other.def.color);
        other.removeFromParent();
        AudioManager().playSfx('hit.wav');
        if (GameSettings().vibrationEnabled) HapticFeedback.heavyImpact();
        return;
      }
      // 에너지 부족 — 게임 오버 (마지막 한 방도 번쩍임·파편)
      showFace(ZonberFace.hurt, 5, squash: true);
      gameRef.fxHit(other.position.clone(), other.def.color);
      gameRef.gameOver();
      if (GameSettings().vibrationEnabled) {
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 120), () => HapticFeedback.heavyImpact());
        Future.delayed(const Duration(milliseconds: 240), () => HapticFeedback.heavyImpact());
      }
      removeFromParent();
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
  }
}

/// 피구공 무늬 — 가운데를 두르는 빨간 띠 + 띠 가장자리 흰 선. [spin] 만큼 돌린다.
/// (농구공처럼 보이던 곡선 이음매 대신, 놀이터 피구공의 단순한 띠)
void paintDodgeBallBand(Canvas canvas, Offset c, double r, double spin) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(spin);
  canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r)));
  final bandH = r * 0.62;
  canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 2.2, height: bandH),
      Paint()..color = const Color(0xFFE23B3B));
  final edge = Paint()
    ..color = Colors.white.withValues(alpha: 0.9)
    ..strokeWidth = max(1.0, r * 0.12);
  canvas.drawLine(Offset(-r * 1.1, -bandH / 2), Offset(r * 1.1, -bandH / 2), edge);
  canvas.drawLine(Offset(-r * 1.1, bandH / 2), Offset(r * 1.1, bandH / 2), edge);
  canvas.restore();
}

/// 게임 화면에 크게 떴다 사라지는 문구 (GOAL! · SAVE!)
class GamePop {
  final String text;
  final Color color;
  final int id;
  const GamePop(this.text, this.color, this.id);
}

/// 피구 상대 팀 — 상대 진영 내야 선수 + 우리 코트 주위 외야 선수. 조금씩 돌아다닌다.
class DodgeTeam {
  final Random _rng = Random();
  final List<Vector2> infield = [];
  final List<Vector2> outfield = [];
  final List<double> flash = []; // 내야 선수 던질 때 커지는 연출
  final List<Vector2> _inTarget = [];
  final List<Vector2> _outTarget = [];
  final List<int> _outSide = []; // 0 왼쪽 · 1 오른쪽 · 2 내 뒤
  Rect? _court, _own;

  static const List<int> _infieldCount = [3, 3, 4, 4, 5, 5, 6];

  /// 내야 선수가 돌아다니는 곳 — 상대 진영 전체(중앙선 바로 앞 50px 은 비운다)
  Rect _oppBack(Rect c) => Rect.fromLTRB(c.left + 20, c.top + 16, c.right - 20, c.top + c.height / 2 - 50);
  final List<double> _inSpeed = [];

  Vector2 _inSpot(Rect c) {
    final r = _oppBack(c);
    return Vector2(r.left + _rng.nextDouble() * r.width, r.top + _rng.nextDouble() * r.height);
  }

  Vector2 _outSpot(int side) {
    final c = _court!, o = _own!;
    const W = ZonberGame.mapWidth;
    switch (side) {
      case 0: return Vector2(c.left / 2, o.top + 24 + _rng.nextDouble() * (o.height - 48));
      case 1: return Vector2((c.right + W) / 2, o.top + 24 + _rng.nextDouble() * (o.height - 48));
      default: return Vector2(o.left + 40 + _rng.nextDouble() * (o.width - 80), c.bottom + 30);
    }
  }

  void update(double dt, ZonberGame game) {
    final w = game.worldConfig;
    if (w.court == null) return;
    _court = w.court;
    _own = w.playArea ?? w.court;
    final tier = _DodgeballThrower.tierAt(game.survivalTime);
    while (infield.length < _infieldCount[tier]) {
      infield.add(_inSpot(_court!));
      _inTarget.add(_inSpot(_court!));
      _inSpeed.add(40 + _rng.nextDouble() * 50);
      flash.add(0);
    }
    while (outfield.length < 3) {
      final side = outfield.length;
      outfield.add(_outSpot(side));
      _outTarget.add(_outSpot(side));
      _outSide.add(side);
    }
    // 천천히 돌아다닌다
    // 자유롭게 돌아다닌다 — 목표에 닿으면 새 목표·새 속도(가끔 빠르게 뛰어간다)
    void wander(List<Vector2> ps, List<Vector2> ts, Vector2 Function(int) pick, double Function(int) speed) {
      for (int i = 0; i < ps.length; i++) {
        final d = ts[i] - ps[i];
        if (d.length < 3) {
          ts[i] = pick(i);
        } else {
          ps[i].add(d.normalized() * min(d.length, speed(i) * dt));
        }
      }
    }
    wander(infield, _inTarget, (i) {
      _inSpeed[i] = _rng.nextDouble() < 0.25 ? 120 + _rng.nextDouble() * 60 : 40 + _rng.nextDouble() * 50;
      return _inSpot(_court!);
    }, (i) => _inSpeed[i]);
    wander(outfield, _outTarget, (i) => _outSpot(_outSide[i]), (_) => 55);
    for (int i = 0; i < flash.length; i++) {
      flash[i] = max(0, flash[i] - dt * 4);
    }
  }
}

/// 피구 상대 선수 그리기 — 빨간 유니폼 점(내야) · 조금 작은 점(외야)
class DodgeTeamZone extends Component with HasGameRef<ZonberGame> {
  @override
  void update(double dt) {
    if (!gameRef.isGameOver) gameRef.dodgeTeam.update(dt, gameRef);
  }

  @override
  void render(Canvas canvas) {
    final t = gameRef.dodgeTeam;
    void player(Vector2 p, double r, {bool throwing = false}) {
      final c = Offset(p.x, p.y);
      // 상대 선수 그림(빨간 유니폼) — 던지는 순간 팔 든 그림
      if (GameArt.draw(canvas, throwing ? 'npc_throw' : 'npc_infield', c, r * 2.3)) return;
      canvas.drawCircle(c + const Offset(1, 2), r, Paint()..color = Colors.black.withValues(alpha: 0.18));
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFFE5484D));
      canvas.drawCircle(c, r, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2);
      canvas.drawCircle(c + Offset(0, -r * 0.18), r * 0.38, Paint()..color = const Color(0xFFFFE0C2));
    }
    for (int i = 0; i < t.infield.length; i++) {
      player(t.infield[i], 11 * (1 + 0.35 * t.flash[i]), throwing: t.flash[i] > 0.2);
    }
    for (final p in t.outfield) {
      player(p, 10);
    }
  }
}

/// 시작 연출 — 나의 존을 존 색으로 깜빡여 보여 준다(문구는 Flutter 오버레이)
class ZoneIntro extends Component with HasGameRef<ZonberGame> {
  @override
  void render(Canvas canvas) {
    final g = gameRef;
    if (!g.inIntro || g.introLeft <= ZonberGame.introStart) return;
    final t = (ZonberGame.introZone + ZonberGame.introStart) - g.introLeft; // 0 → introZone
    final on = (t * 3.3).floor() % 2 == 0; // 약 3번 깜빡
    final r = g.zoneRect.deflate(2);
    final accent = g.worldConfig.accent;
    // 존 바깥은 살짝 어둡게 — 여기가 내 자리
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(const Rect.fromLTWH(0, 0, ZonberGame.mapWidth, ZonberGame.mapHeight))
      ..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)));
    canvas.drawPath(outside, Paint()..color = Colors.black.withValues(alpha: 0.28));
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)),
        Paint()..color = accent.withValues(alpha: on ? 0.30 : 0.10));
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), Paint()
      ..color = accent.withValues(alpha: on ? 1 : 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4);
  }
}

/// 축구공 무늬 — 가운데 검은 오각형 + 가장자리 조각 5개. [spin] 만큼 돌린다.
void paintSoccerPatches(Canvas canvas, Offset c, double r, double spin) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(spin);
  canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r)));
  final ink = Paint()..color = const Color(0xFF1F2937);
  Path pent(double cx, double cy, double rr, double rot) {
    final p = Path();
    for (int i = 0; i < 5; i++) {
      final a = rot + i * 2 * pi / 5 - pi / 2;
      final pt = Offset(cx + cos(a) * rr, cy + sin(a) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }
  canvas.drawPath(pent(0, 0, r * 0.36, 0), ink);
  for (int i = 0; i < 5; i++) {
    final a = i * 2 * pi / 5 - pi / 2;
    canvas.drawPath(pent(cos(a) * r * 0.95, sin(a) * r * 0.95, r * 0.3, pi / 5), ink);
  }
  canvas.restore();
}

/// 피구 외야 패스 — 코트 바깥 띠를 따라 공을 몇 번 돌린 뒤 캐릭터를 향해 빠르게 던진다.
/// 패스 중인 공은 공중에 띄운 공이라 맞지 않는다(충돌 없음). 마지막에 진짜 공(Bullet)을 쏘고 사라진다.
class _PassBall extends PositionComponent with HasGameRef<ZonberGame> {
  final List<Vector2> points;
  final ProjectileDef def;
  final double shotSpeed;
  int _i = 0;
  double _hopT = 0;
  double _hold = 0;
  double _age = 0;
  double _lift = 0;
  bool finished = false;

  /// 패스 중 공 색
  static const Color passColor = Color(0xFF22C55E);

  _PassBall({required this.points, required this.def, required this.shotSpeed}) {
    position = points.first.clone();
    size = Vector2.all(def.visualSize);
    // 경로 좌표는 외야 선수 위치 객체 그대로(선수가 움직이면 따라간다)
    anchor = Anchor.center;
    priority = 12; // 캐릭터 위로 — 머리 위로 넘어가는 패스
  }

  @override
  void update(double dt) {
    if (finished || gameRef.isGameOver) return;
    _age += dt;
    if (_i >= points.length - 1) {
      // 마지막 외야수 손에서 잠깐 멈췄다가 던진다
      _lift = 0;
      _hold += dt;
      if (_hold >= 0.25) _fire();
      return;
    }
    final a = points[_i], b = points[_i + 1];
    final dur = max(0.3, a.distanceTo(b) / 540);
    _hopT += dt;
    final p = (_hopT / dur).clamp(0.0, 1.0);
    position = a + (b - a) * p;
    _lift = sin(pi * p); // 포물선처럼 떴다가 받는다(크기로 표현)
    if (p >= 1) {
      _i++;
      _hopT = 0;
    }
  }

  void _fire() {
    finished = true;
    if (gameRef.player.isMounted) {
      gameRef.mapArea.add(Bullet(position.clone(), gameRef.player.position.clone(), speed: shotSpeed, def: def));
    }
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final r = size.x / 2;
    final c = Offset(r, r);
    final s = (_age < 0.12 ? 0.4 + 0.6 * (_age / 0.12) : 1.0) * (1 + 0.45 * _lift);
    canvas.translate(c.dx, c.dy);
    canvas.scale(s);
    canvas.translate(-c.dx, -c.dy);
    // 패스 중인 공은 초록 — 아직 날아오지 않는 공임을 표시. 던지는 순간 원래 공(주황 속공)으로 바뀐다
    if (GameArt.draw(canvas, 'ammo_dodgeball_pass', c, r * 2.1, rotation: _age * 9)) return;
    canvas.drawCircle(c, r, Paint()..color = passColor);
    paintDodgeBallBand(canvas, c, r, _age * 9);
    canvas.drawCircle(c.translate(-r * 0.32, -r * 0.34), r * 0.26, Paint()..color = Colors.white.withValues(alpha: 0.55));
    canvas.drawCircle(c, r, Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
  }
}

class Bullet extends PositionComponent
    with HasGameRef<ZonberGame>, CollisionCallbacks {
  Vector2 velocity = Vector2.zero();
  final double speed;
  /// 월드 투사체 정의 — 크기·색·거동·벽 반응
  final ProjectileDef def;
  int _bounces = 0;
  double _age = 0;
  /// curve: 휘는 방향(±1)
  final double _curveSign;
  /// 분열: 이 시간(초)이 지나면 [splitInto]개로 갈라진다. null 이면 분열 없음
  double? splitAfter;
  int splitInto = 0;

  /// 골키퍼: 막히거나(키퍼·포스트·닫힌 벽) 튕겨 나간 공 — 더는 득점·세이브 대상이 아니다
  bool deflected = false;
  double _deflectAge = 0;
  /// 골키퍼: 골망에 들어간 공 — 속도가 줄며 사라진다
  bool scored = false;

  /// wave·knuckle: 찬 방향(흔들림의 기준선)과 옆으로 움직이는 속도
  Vector2 _baseDir = Vector2(0, 1);
  static final Random _rng = Random();
  double _lat = 0, _latTarget = 0, _latOffset = 0, _knuckleT = 0;

  /// 법선 [n] 에 대해 반사하고 튕겨 나간 공으로 만든다
  void bounceOff(Vector2 n, {double keep = 0.8}) {
    final nn = n.normalized();
    velocity = (velocity - nn * (2 * velocity.dot(nn))) * keep;
    velocity.rotate((Random().nextDouble() - 0.5) * 0.3);
    if (velocity.length < 160) velocity = velocity.normalized() * 160;
    deflected = true;
    _deflectAge = _age;
  }

  /// 골키퍼: 키퍼 몸에 맞은 적이 있다 — 골문을 벗어나면 세이브, 그래도 들어가면 골
  bool keeperTouched = false;
  /// 같은 접촉이 여러 번 잡히지 않게 잠깐 쉰다(초)
  double keeperCd = 0;

  /// 법선 [n] 방향 성분만 반발계수 [e] 로 되튕긴다(접선 성분은 [friction] 만큼 유지).
  /// 정면 충돌은 크게 꺾이고, 스치듯 맞으면 방향만 조금 바뀐다. 득점 대상에서 빼지 않는다.
  void reflectSoft(Vector2 n, {double e = 0.6, double friction = 0.92}) {
    final nn = n.normalized();
    final vn = velocity.dot(nn);
    if (vn >= 0) return; // 이미 멀어지는 중
    final normal = nn * vn;
    final tangent = velocity - normal;
    velocity = tangent * friction - normal * e;
    if (velocity.length < 90) velocity = velocity.normalized() * 90;
    // 거동(휘기·흔들림)은 여기서 끝 — 튕긴 뒤엔 직선으로
    _baseDir = velocity.normalized();
    _free = true;
  }

  /// 키퍼 접촉 — 반발 후 결과는 골라인에서 정한다
  void keeperTouch(Vector2 n) {
    reflectSoft(n, e: 0.65, friction: 0.9);
    keeperTouched = true;
    keeperCd = 0.25;
  }

  /// 튕긴 뒤 — 휘기·흔들림 없이 직선으로 난다
  bool _free = false;

  /// 튕긴·골망 공은 흐려지며 사라진다
  double get _fade {
    if (scored) return (1 - (_age - _deflectAge) / 0.45).clamp(0.0, 1.0);
    if (deflected) return (1 - (_age - _deflectAge - 0.7) / 0.5).clamp(0.0, 1.0);
    return 1;
  }

  Bullet(Vector2 position, Vector2 targetPosition, {this.speed = 200.0, required this.def, double? curveSign})
      : _curveSign = curveSign ?? (Random().nextBool() ? 1.0 : -1.0) {
    this.position = position;
    size = Vector2(def.visualSize, def.visualSize);
    anchor = Anchor.center;
    Vector2 direction = targetPosition - position;
    velocity = direction.normalized() * speed;
    _baseDir = velocity.normalized();
  }

  @override
  void render(Canvas canvas) {
    final f = _fade;
    if (f < 1) {
      canvas.saveLayer(size.toRect().inflate(size.x), Paint()..color = Color.fromRGBO(0, 0, 0, f));
      _renderBall(canvas);
      canvas.restore();
    } else {
      _renderBall(canvas);
    }
  }

  void _renderBall(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    if (def.seams && _age < 0.12) {
      // 피구 — 상대 손에서 튀어나오듯 0.12초 동안 커지며 등장
      final s = 0.4 + 0.6 * (_age / 0.12);
      canvas.translate(c.dx, c.dy);
      canvas.scale(s);
      canvas.translate(-c.dx, -c.dy);
    }
    if (def.visualSize >= 14 || def.art != null) {
      // 꽉 찬 공 — 몸통 · 아래쪽 음영 · 위쪽 하이라이트. 네온 링이 아니라 "공"으로 읽히게.
      final r = size.x / 2;
      if (def.trail && !deflected && !scored && velocity.length2 > 0) {
        // 총알슛 꼬리 — 진행 반대쪽으로 흐려지는 잔상(그림이 있으면 속도선 그림)
        final back = velocity.normalized();
        final ang = atan2(-back.y, -back.x);
        if (!GameArt.draw(canvas, 'fx_streak', c + Offset(-back.x, -back.y) * (r * 2.4), r * 5.2, rotation: ang + pi)) {
          final tail = c - Offset(back.x, back.y) * (r * 4.2);
          canvas.drawLine(c, tail, Paint()
            ..shader = ui.Gradient.linear(c, tail, [def.color.withValues(alpha: 0.75), def.color.withValues(alpha: 0)])
            ..strokeWidth = r * 1.5
            ..strokeCap = StrokeCap.round);
        }
      }
      // 공 그림 — 돌면서 날아온다(무회전은 거의 돌지 않는다). 갤럭시의 작은 탄은 조금 크게
      if (def.art != null) {
        final spin = def.motion == ProjectileMotion.knuckle && !deflected ? 0.3 : _age * 6 * _curveSign;
        final w = def.visualSize < 14 ? size.x * 1.5 : size.x * 1.08;
        if (GameArt.draw(canvas, def.art!, c, w, rotation: spin)) return;
      }
      canvas.drawCircle(c, r, Paint()..color = def.color);
      canvas.drawCircle(
        c.translate(r * 0.18, r * 0.22),
        r * 0.82,
        Paint()..color = Colors.black.withValues(alpha: 0.14),
      );
      canvas.drawCircle(c, r * 0.8, Paint()..color = def.color);
      if (def.seams) paintDodgeBallBand(canvas, c, r, _age * 7 * _curveSign);
      // 무회전 슛은 돌지 않는다
      if (def.soccer) paintSoccerPatches(canvas, c, r, def.motion == ProjectileMotion.knuckle && !deflected ? 0.3 : _age * 6 * _curveSign);
      canvas.drawCircle(
        c.translate(-r * 0.32, -r * 0.34),
        r * 0.26,
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      return;
    }
    // 외곽 글로우 (작은 네온 탄 — 갤럭시)
    canvas.drawCircle(
      c,
      size.x / 1.5,
      Paint()
        ..color = def.color.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // 코어
    canvas.drawCircle(c, size.x / 3, Paint()..color = def.coreColor);
    // 링
    canvas.drawCircle(
      c,
      size.x / 2,
      Paint()
        ..color = def.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  Future<void> onLoad() async {
    add(CircleHitbox(radius: def.radius, position: size / 2, anchor: Anchor.center));
  }

  @override
  void update(double dt) {
    _age += dt;

    // --- 분열: 진행 방향 기준 좌우로 부채꼴(3개 ±16°, 5개 ±14°·±28°) ---
    if (splitAfter != null && _age >= splitAfter! && splitInto > 1) {
      final step = splitInto >= 5 ? 0.245 : 0.28; // rad
      final dir = velocity.normalized();
      for (int i = 0; i < splitInto; i++) {
        final a = (i - (splitInto - 1) / 2) * step;
        final d = dir.clone()..rotate(a);
        parent?.add(Bullet(position.clone(), position + d * 100, speed: speed * 1.05, def: def));
      }
      removeFromParent();
      return;
    }

    if (keeperCd > 0) keeperCd -= dt;

    // --- 거동 --- (키퍼·포스트에 튕긴 공은 직선)
    switch (_free ? ProjectileMotion.straight : def.motion) {
      case ProjectileMotion.curve:
        // 진행 방향에 수직인 가속 → 포물선처럼 휜다 (속도 크기는 유지)
        final perp = Vector2(-velocity.y, velocity.x).normalized();
        velocity += perp * (def.lateralAccel * _curveSign * dt);
        velocity = velocity.normalized() * speed;
        break;
      case ProjectileMotion.homing:
        if (_age < def.maxTurnTime && gameRef.player.isMounted) {
          final toPlayer = gameRef.player.position - position;
          final current = atan2(velocity.y, velocity.x);
          final target = atan2(toPlayer.y, toPlayer.x);
          double diff = (target - current + pi) % (2 * pi) - pi;
          final maxStep = def.turnRate * dt;
          diff = diff.clamp(-maxStep, maxStep);
          velocity.rotate(diff);
        }
        break;
      case ProjectileMotion.wave:
        // 꼬불꼬불 — 찬 방향을 축으로 좌우 사인파 (옆 위치 = A·sin(ωt))
        if (!deflected && !scored) {
          final w = 2 * pi * def.waveHz;
          final perp = Vector2(-_baseDir.y, _baseDir.x);
          velocity = _baseDir * speed + perp * (def.waveAmp * w * cos(w * _age) * _curveSign);
        }
        break;
      case ProjectileMotion.knuckle:
        // 무회전 — 0.12~0.3초마다 옆으로 흔들리는 방향이 바뀐다. 너무 멀리 새지 않게 기준선 쪽으로 당긴다.
        if (!deflected && !scored) {
          _knuckleT -= dt;
          if (_knuckleT <= 0) {
            _knuckleT = 0.12 + _rng.nextDouble() * 0.18;
            _latTarget = ((_rng.nextDouble() * 2 - 1) * def.waveAmp - _latOffset * 2.2)
                .clamp(-def.waveAmp, def.waveAmp);
          }
          _lat += (_latTarget - _lat) * min(1.0, dt * 9);
          _latOffset += _lat * dt;
          final perp = Vector2(-_baseDir.y, _baseDir.x);
          velocity = _baseDir * speed + perp * _lat;
        }
        break;
      case ProjectileMotion.straight:
      case ProjectileMotion.bounce:
        break;
    }

    // Raycast / Sub-step for high speed bullets
    Vector2 ds = velocity * dt;
    double dist = ds.length;
    int steps = (dist / 4).ceil(); // Check every 4 pixels

    // We check steps to find wall *before* we pass it
    bool hit = false;

    for (int i = 1; i <= steps; i++) {
      Vector2 testPos = position + (ds * (i / steps));

      /* World Bounds Check REMOVED - Bullets pass through */

      // Obstacle Check
      for (final other in gameRef.mapArea.children) {
        if (other is Obstacle) {
          // Check if bullet rect overlaps obstacle (accounts for bullet size)
          final Rect obsRect = other.toRect();
          final Rect bulletRect = Rect.fromCenter(
            center: Offset(testPos.x, testPos.y),
            width: size.x,
            height: size.y,
          );
          if (bulletRect.overlaps(obsRect)) {
            // Hit!
            if (def.onWall == WallBehavior.vanish || _bounces >= def.maxBounces) {
              removeFromParent();
              return;
            }
            _bounces++;

            // Determine Reflection Vector
            // Simple approach: Reverse velocity based on hitting side?
            // "Diamond" walls (angle != 0) should reflect chaotically or perpendicularly.

            if (other.angle != 0) {
              // Chaos Reflection for Prisms
              // Either 90 degree turn or just random skew
              // Let's simply rotate by 90 degrees + slight random noise
              // This ensures it doesn't just come back, but goes "somewhere else"
              double turn = (Random().nextBool() ? pi / 2 : -pi / 2);
              turn += (Random().nextDouble() - 0.5) * 0.5; // +/- ~15 degrees

              velocity.rotate(turn);

              // Push out slightly to avoid sticking
              position -= ds;
            } else {
              // Standard Axis-Aligned Reflection
              Rect obs = other.toRect();
              Vector2 prev = position + (ds * ((i - 1) / steps));
              final double bHalf = size.x / 2; // bullet half-size

              // Determine hit side by checking which face the bullet was
              // OUTSIDE of at the previous sub-step position.
              final bool fromLeft   = prev.x + bHalf <= obs.left;
              final bool fromRight  = prev.x - bHalf >= obs.right;
              final bool fromTop    = prev.y + bHalf <= obs.top;
              final bool fromBottom = prev.y - bHalf >= obs.bottom;

              final bool horizHit = fromLeft  || fromRight;
              final bool vertHit  = fromTop   || fromBottom;

              if (horizHit && !vertHit) {
                // Pure left/right wall hit
                velocity.x = -velocity.x;
                position.x = fromLeft
                    ? obs.left  - bHalf - 1
                    : obs.right + bHalf + 1;
              } else if (vertHit && !horizHit) {
                // Pure top/bottom wall hit
                velocity.y = -velocity.y;
                position.y = fromTop
                    ? obs.top    - bHalf - 1
                    : obs.bottom + bHalf + 1;
              } else {
                // Corner or ambiguous: reflect along dominant movement axis
                if (ds.x.abs() >= ds.y.abs()) {
                  velocity.x = -velocity.x;
                  position.x = (fromLeft || !fromRight)
                      ? obs.left  - bHalf - 1
                      : obs.right + bHalf + 1;
                } else {
                  velocity.y = -velocity.y;
                  position.y = (fromTop || !fromBottom)
                      ? obs.top    - bHalf - 1
                      : obs.bottom + bHalf + 1;
                }
              }
            }

            hit = true;
            break;
          }
        }
      }

      if (hit) break;
    }

    if (!hit) {
      position += ds;
    } else {
      // Ensure we don't get stuck by moving slightly in new velocity direction
      // to clear any corner cases
      position += velocity.normalized() * 2;
    }

    // Keeper: 포스트·닫힌 벽에 맞으면 튕기고, 열린 입구로 완전히 들어오면 실점
    final wc = gameRef.worldConfig;
    if (wc.mode == WorldMode.keeper) {
      if (_keeperUpdate(wc)) return;
    }

    // Cleanup - Tighter bounds
    if (position.x < -1000 ||
        position.x > ZonberGame.mapWidth + 1000 ||
        position.y < -1000 ||
        position.y > ZonberGame.worldHeight + 1000) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    // Logic captured in update() for tunneling prevention
  }

  /// 득점 없이 끝난 공 — 키퍼가 건드렸으면 세이브 확정, 아니면 빗나감. 흐려지며 사라진다
  void _settle() {
    deflected = true;
    _deflectAge = _age;
    if (keeperTouched && gameRef.player.isMounted) gameRef.player.creditSave(position.clone());
  }

  /// 골키퍼(페널티킥) 판정. 공을 제거했으면 true.
  bool _keeperUpdate(WorldConfig wc) {
    final br = def.radius;

    if (scored) {
      // 그물 안 — 그물 끝에서 멈추고 흐려지며 사라진다
      velocity *= 0.8;
      if (position.y > KeeperGoal.lineY + KeeperGoal.depth - br) {
        position.y = KeeperGoal.lineY + KeeperGoal.depth - br;
        velocity.setZero();
      }
      if (_age - _deflectAge > 0.5) {
        removeFromParent();
        return true;
      }
      return false;
    }

    // 1) 골포스트 — 둥근 기둥, 맞은 각도대로 튕긴다
    for (final pl in [true, false]) {
      final pc = gameRef.goal.postPos(pl);
      final off = position - pc;
      if (off.length < KeeperGoal.postRadius + br && velocity.dot(off) < 0) {
        // 포스트 — 맞은 각도대로 튕긴다. 맞고 골문 안으로 들어갈 수도 있다(득점 대상 유지)
        reflectSoft(off, e: 0.75, friction: 0.95);
        position = pc + off.normalized() * (KeeperGoal.postRadius + br + 1);
        gameRef.shake(4, 0.18);
        gameRef.burst(position.clone(), Colors.white, count: 8, speed: 150, size: 2);
        AudioManager().playSfx('hit.wav', volume: 0.35);
        return false;
      }
    }

    // 2) 골라인 통과 — 골문 안이면 실점(키퍼·포스트를 맞고 들어가도 골), 밖이면 빗나감
    if (!deflected && position.y >= KeeperGoal.lineY) {
      final inMouth = position.x > KeeperGoal.left + KeeperGoal.postRadius &&
          position.x < KeeperGoal.right - KeeperGoal.postRadius;
      if (inMouth) {
        scored = true;
        _deflectAge = _age;
        gameRef.fxGoal(position.clone());
        if (gameRef.player.isMounted) gameRef.player.concedeGoal();
      } else {
        _settle(); // 골문 옆으로 — 키퍼가 건드렸으면 세이브
      }
    }

    // 3) 튕겨서 골문 반대쪽(위)으로 가거나 무대 옆으로 나가면 끝 — 키퍼가 건드렸으면 세이브
    if (!deflected && !scored && (_free || keeperTouched)) {
      final away = velocity.y < -20;
      final outSide = position.x < -10 || position.x > ZonberGame.mapWidth + 10;
      if (away || outSide) _settle();
    }

    // 4) 튕긴·빗나간 공 정리
    if (deflected &&
        (_fade <= 0 ||
            position.x < -40 ||
            position.y < -40 ||
            position.x > ZonberGame.mapWidth + 40 ||
            position.y > ZonberGame.mapHeight + 40)) {
      removeFromParent();
      return true;
    }
    return false;
  }
}

class BulletSpawner extends Component with HasGameRef<ZonberGame> {
  // ── 난이도 곡선 튜닝 상수 ──────────────────────────────
  // ⚠️ 이 값을 바꾸면 기존 리더보드 기록과 난이도가 달라진다.
  //    변경 시 시즌 리셋을 함께 검토할 것.
  static const double _levelDuration = 25.0; // 레벨업 간격(초)
  static const int _startLevel = 1;          // 시작 레벨 (0이면 초반 무위험 구간이 길어짐)
  static const double _intervalDecay = 0.9;  // 레벨당 스폰 간격 배수
  static const double _minInterval = 0.02;   // 스폰 간격 하한
  static const double _speedPerLevel = 15.0; // 레벨당 탄속 증가
  static const int _limitPerLevel = 10;      // 레벨당 동시 탄환 상한 증가
  // ──────────────────────────────────────────────────────

  // Manual Timer Logic
  double _timeSinceLastSpawn = 0.0;

  // Base Config
  double _baseInterval = 0.1;
  double _baseSpeed = 150.0;
  int _baseLimit = 100;

  final Random _random = Random();

  /// 피구(thrower) — 한 턴에 한 번 캐릭터를 향해 던진다
  final _DodgeballThrower _thrower = _DodgeballThrower();

  /// 골키퍼(shooter) — 열린 입구를 노리고 턴마다 찬다
  final _KeeperShooter _shooter = _KeeperShooter();

  /// 현재 난이도 레벨 (경과 시간 기반)
  int get currentLevel =>
      _startLevel + (gameRef.survivalTime / _levelDuration).floor();

  @override
  void onMount() {
    super.onMount();
    StageConfig? config = GameConfig.getStage(gameRef.mapId);
    if (config != null) {
      _baseInterval = config.spawnInterval;
      _baseSpeed = config.bulletSpeed;
    }
    // 월드가 정하는 값이 우선 — 동시 탄 상한, 스폰 간격, 기본 탄속
    final world = gameRef.worldConfig;
    _baseLimit = world.maxBullets;
    _baseInterval = world.spawnInterval ?? _baseInterval;
    _baseSpeed = world.bulletSpeed ?? _baseSpeed;
  }

  @override
  void update(double dt) {
    if (gameRef.inIntro) return; // 시작 연출 중엔 공을 내지 않는다
    if (gameRef.worldConfig.spawner == SpawnStrategy.thrower) {
      _thrower.update(dt, gameRef);
      return;
    }
    if (gameRef.worldConfig.spawner == SpawnStrategy.shooter) {
      _shooter.update(dt, gameRef);
      return;
    }
    _timeSinceLastSpawn += dt;

    final int level = currentLevel;

    double currentInterval = _baseInterval * pow(_intervalDecay, level);
    if (currentInterval < _minInterval) currentInterval = _minInterval;

    if (_timeSinceLastSpawn >= currentInterval) {
      _timeSinceLastSpawn = 0;
      _spawnBullet(level);
    }
  }

  void _spawnBullet(int level) {
    if (gameRef.isGameOver) return;
    if (!gameRef.player.isMounted) return;

    // Player has anchor=Anchor.center, so position IS the center already
    // Keeper 모드는 골대(맵 중앙)를 기준으로 스폰하고 골대를 조준한다
    final bool keeper = gameRef.worldConfig.mode == WorldMode.keeper;
    Vector2 playerPos = keeper
        ? Vector2(ZonberGame.mapWidth / 2, ZonberGame.mapHeight / 2)
        : gameRef.player.position;

    // RAMPING: Increase bullet cap slightly over time
    int currentLimit = _baseLimit + (level * _limitPerLevel);

    if (gameRef.mapArea.children.whereType<Bullet>().length > currentLimit)
      return;

    // RAMPING: 레벨당 속도 +15, 기본값의 2배에서 상한
    // (slowTime 감속은 Bullet.update()에서 실시간 적용 — 여기서 곱하지 않는다)
    double currentSpeed =
        (_baseSpeed + (level * _speedPerLevel)).clamp(0, _baseSpeed * 2);

    final world = gameRef.worldConfig;
    final def = world.projectiles[_random.nextInt(world.projectiles.length)];
    final Vector2 spawnPos;
    // ring — 플레이어(또는 keeper 골대) 중심 원주
    final double range = world.spawnRadius;
    final double angle = _random.nextDouble() * 2 * pi;
    spawnPos = playerPos + Vector2(cos(angle), sin(angle)) * range;

    // Safety Check: Don't spawn inside obstacles
    bool safeToSpawn = true;
    for (final other in gameRef.mapArea.children) {
      if (other is Obstacle && other.containsPoint(spawnPos)) {
        safeToSpawn = false;
        break;
      }
    }
    if (!safeToSpawn) return;

    final double jitter = keeper ? gameRef.worldConfig.goalRadius * 1.2 : 100;
    Vector2 targetPos =
        playerPos +
        Vector2(
          (_random.nextDouble() - 0.5) * jitter,
          (_random.nextDouble() - 0.5) * jitter,
        );

    gameRef.mapArea.add(Bullet(spawnPos, targetPos, speed: currentSpeed * def.speedMult, def: def));
  }
}

// ─────────────────────────────────────────────────────────────
// 골키퍼 — 페널티킥형 (2026-09-21 개편, 같은 날 페널티 에어리어 확대·슛 종류 추가). docs/STAGES.md §3.
// 화면 아래 가로 골문. 키퍼는 페널티 에어리어(= 나의 존) 안에서 움직인다.
// 페널티 에어리어 바로 바깥의 슈터(상대 선수)들이 차는 공이 골문 안으로 들어오면 실점, 포스트에 맞으면 튕기고,
// 골문 밖으로 가면 빗나감. 키퍼에 닿으면 튕겨 낸다(세이브). 5골이면 게임 오버.
//
//   단계  시간      슈터  새로 나오는 슛
//   0     ~15s     1명   직선
//   1     ~30s     2명   + 강슛(노랑)
//   2     ~50s     3명   + 감아차기(하늘색, 휘어 들어옴)
//   3     ~70s     3명   + 꼬불꼬불 슛(분홍) · 두 명 동시
//   4     ~95s     4명   + 총알슛(주황, 꼬리) · 슈터 좌우 이동
//   5     ~125s    5명   + 무회전(보라, 어디로 흔들릴지 모름) · 세 명 동시
//   6     125s~    6명   극악: 특수 슛 위주, 키퍼 반대쪽을 노리는 비율 85%
// ⚠️ 수치를 바꾸면 골키퍼 리더보드 기록의 의미가 달라진다(시즌 리셋 검토).
// ─────────────────────────────────────────────────────────────
class KeeperGoal {
  /// 골문 좌우 포스트 x, 골라인 y, 그물 깊이 (무대 좌표 480×768)
  static const double left = 110, right = 370, lineY = 720, depth = 34;
  static const double postRadius = 7;
  /// 키퍼 시작 줄(골라인 앞)
  static const double keeperY = 690;
  /// 페널티 에어리어 = 키퍼 이동 영역 = 나의 존 (world_config 의 keeper playArea 와 같은 값).
  /// 실제 비율(깊이 16.5m · 페널티 마크 11m · 아크 9.15m · 골 에어리어 5.5m)에 맞춰 선을 긋는다.
  static const Rect penaltyBox = Rect.fromLTRB(12, 420, 468, 720);
  static const Rect goalArea = Rect.fromLTRB(70, 620, 410, 720);
  static const Offset penaltySpot = Offset(240, 520);
  static const double arcRadius = 166;

  static const List<int> _shooterCount = [1, 2, 3, 3, 4, 5, 6];

  final Random _rng = Random();
  /// 슈터 위치 · 차는 순간 커지는 연출(1→0) · 좌우 이동 속도
  final List<Vector2> shooters = [];
  final List<double> kickFlash = [];
  final List<double> _drift = [];
  final List<double> _appear = [];

  static int tierAt(double t) {
    if (t < 15) return 0;
    if (t < 30) return 1;
    if (t < 50) return 2;
    if (t < 70) return 3;
    if (t < 95) return 4;
    if (t < 125) return 5;
    return 6;
  }

  Vector2 postPos(bool leftPost) => Vector2(leftPost ? left : right, lineY);

  /// 등장 연출 0→1
  double appear(int i) => _appear[i].clamp(0.0, 1.0);

  void update(double dt, double t) {
    final tier = tierAt(t);
    while (shooters.length < _shooterCount[tier]) {
      _addShooter();
    }
    for (int i = 0; i < shooters.length; i++) {
      kickFlash[i] = max(0, kickFlash[i] - dt * 4);
      _appear[i] += dt * 3;
      if (tier >= 4) {
        // 좌우로 움직인다 — 차는 각도가 계속 바뀐다
        shooters[i].x += _drift[i] * dt;
        if (shooters[i].x < 40 || shooters[i].x > 440) _drift[i] = -_drift[i];
        shooters[i].x = shooters[i].x.clamp(40.0, 440.0);
      }
    }
  }

  void _addShooter() {
    // 페널티 에어리어 바로 바깥(아크 주변), 다른 슈터와 너무 붙지 않는 자리
    Vector2 p = Vector2(240, 360);
    for (int tries = 0; tries < 20; tries++) {
      p = Vector2(50 + _rng.nextDouble() * 380, 280 + _rng.nextDouble() * 115);
      if (shooters.every((s) => s.distanceTo(p) > 80)) break;
    }
    if (shooters.isEmpty) p = Vector2(240, 360); // 첫 슈터는 정면, 아크 바로 위
    shooters.add(p);
    kickFlash.add(0);
    _appear.add(0);
    _drift.add((_rng.nextBool() ? 1 : -1) * (35 + _rng.nextDouble() * 35));
  }
}

/// 슛 종류 — 월드의 projectiles 순서와 같다(0 직선 · 1 강슛 · 2 감아차기 · 3 꼬불꼬불 · 4 총알슛 · 5 무회전)
enum _Kick { straight, power, curl, wave, rocket, knuckle }

class _KeeperShooter {
  final Random _rng = Random();
  double _since = 0;
  double _nextBeat = 1.4;

  /// 턴 간격: 2.0s 에서 1초에 1%씩 짧아지고 0.55s 하한
  static double beatAt(double t) => max(0.55, 2.0 * pow(0.99, t).toDouble());

  /// 슛 속도: 200 → 초당 +2.2, 상한 480 (총알슛은 여기에 1.6배). 2026-09-22 꼬불꼬불 슛 구간부터 너무 빨라 조금 낮춤
  static double speedAt(double t) => min(480.0, 200.0 + 2.2 * t);

  /// 공이 골라인에 닿는 시각(예상)들 — 여러 공이 한꺼번에 도착하지 않게 이 간격 이상 벌린다(간발의 차는 허용)
  final List<double> _arrivals = [];
  static const double _arrivalGap = 0.3;

  /// 키퍼 반대쪽을 노리는 비율
  static const List<double> _smart = [0.2, 0.35, 0.5, 0.6, 0.7, 0.8, 0.85];

  /// 단계별 슛 비중
  static const Map<int, Map<_Kick, int>> _weights = {
    0: {_Kick.straight: 1},
    1: {_Kick.straight: 6, _Kick.power: 3},
    2: {_Kick.straight: 3, _Kick.power: 3, _Kick.curl: 4},
    3: {_Kick.straight: 1, _Kick.power: 2, _Kick.curl: 3, _Kick.wave: 4},
    4: {_Kick.power: 2, _Kick.curl: 3, _Kick.wave: 3, _Kick.rocket: 3},
    5: {_Kick.power: 1, _Kick.curl: 3, _Kick.wave: 2, _Kick.rocket: 3, _Kick.knuckle: 4},
    6: {_Kick.curl: 3, _Kick.wave: 3, _Kick.rocket: 4, _Kick.knuckle: 4},
  };

  /// 여러 명이 동시에 찰 확률(두 명 · 세 명)
  static const List<double> _twin = [0, 0, 0, 0.3, 0.3, 0.3, 0.35];
  static const List<double> _trio = [0, 0, 0, 0, 0.1, 0.2, 0.3];

  _Kick _pick(int tier) {
    final w = _weights[tier]!;
    int roll = _rng.nextInt(w.values.reduce((a, b) => a + b));
    for (final e in w.entries) {
      roll -= e.value;
      if (roll < 0) return e.key;
    }
    return _Kick.straight;
  }

  void update(double dt, ZonberGame game) {
    _since += dt;
    if (_since < _nextBeat) return;
    _since = 0;
    final t = game.survivalTime;
    _nextBeat = beatAt(t);
    final goal = game.goal;
    if (goal.shooters.isEmpty || game.isGameOver || !game.player.isMounted) return;
    final tier = KeeperGoal.tierAt(t);
    final order = List<int>.generate(goal.shooters.length, (i) => i)..shuffle(_rng);
    final roll = _rng.nextDouble();
    final n = roll < _trio[tier] ? 3 : roll < _trio[tier] + _twin[tier] ? 2 : 1;
    _arrivals.removeWhere((a) => a < t - 0.5);
    final world = game.worldConfig;
    final center = Vector2((KeeperGoal.left + KeeperGoal.right) / 2, KeeperGoal.lineY);
    for (int k = 0; k < min(n, order.length); k++) {
      final si = order[k];
      final kind = _pick(tier);
      final def = world.projectiles[min(kind.index, world.projectiles.length - 1)];
      // 골라인까지 걸리는 시간(휘는 공은 조금 더) — 이미 날아오는 공과 도착이 겹치면 늦게 찬다
      final fly = goal.shooters[si].distanceTo(center) / (speedAt(t) * def.speedMult) * (def.motion == ProjectileMotion.straight ? 1.0 : 1.08);
      var arrive = t + k * 0.12 + fly;
      for (bool moved = true; moved;) {
        moved = false;
        for (final a in _arrivals) {
          if ((a - arrive).abs() < _arrivalGap) {
            arrive = a + _arrivalGap;
            moved = true;
          }
        }
      }
      _arrivals.add(arrive);
      _kick(game, si, kind, t, tier, delay: arrive - fly - t);
    }
  }

  /// 골문 안 목표 x — 가끔 포스트, 단계가 오를수록 키퍼 반대쪽
  double _targetX(ZonberGame game, int tier) {
    const l = KeeperGoal.left + 14, r = KeeperGoal.right - 14;
    final roll = _rng.nextDouble();
    if (roll < 0.07) return _rng.nextBool() ? KeeperGoal.left + 2 : KeeperGoal.right - 2; // 포스트 맞기
    if (roll < 0.07 + _smart[tier]) {
      final kx = game.player.position.x;
      final leftSpan = (kx - 40) - l;
      final rightSpan = r - (kx + 40);
      if (leftSpan <= 0 && rightSpan <= 0) return l + _rng.nextDouble() * (r - l);
      final goLeft = rightSpan <= 0 || (leftSpan > 0 && _rng.nextDouble() < leftSpan / (leftSpan + rightSpan));
      return goLeft ? l + _rng.nextDouble() * leftSpan : (kx + 40) + _rng.nextDouble() * rightSpan;
    }
    return l + _rng.nextDouble() * (r - l);
  }

  /// 슈터 [si] 가 [kind] 슛을 찬다
  void _kick(ZonberGame game, int si, _Kick kind, double t, int tier, {double delay = 0}) {
    if (delay > 0) {
      game.mapArea.add(TimerComponent(
        period: delay,
        removeOnFinish: true,
        onTick: () {
          if (!game.isGameOver) _kick(game, si, kind, t, tier);
        },
      ));
      return;
    }
    final goal = game.goal;
    if (si >= goal.shooters.length) return;
    final world = game.worldConfig;
    final def = world.projectiles[min(kind.index, world.projectiles.length - 1)];
    final origin = goal.shooters[si] + Vector2(0, 14);
    final target = Vector2(_targetX(game, tier), KeeperGoal.lineY + KeeperGoal.depth * 0.5);
    final speed = speedAt(t) * def.speedMult;
    goal.kickFlash[si] = 1;
    final dir = (target - origin).normalized();
    final perp = Vector2(-dir.y, dir.x);
    final tt = target.distanceTo(origin) / speed;
    final sign = _rng.nextBool() ? 1.0 : -1.0;
    switch (def.motion) {
      case ProjectileMotion.curve:
        // 감아차기 — 휘는 만큼 반대쪽을 겨눠 차서 결국 목표로 휘어 들어오게 (d ≈ ½·a·T²)
        final d = 0.5 * def.lateralAccel * tt * tt;
        game.mapArea.add(Bullet(origin, target - perp * (sign * d), speed: speed, def: def, curveSign: sign));
        break;
      case ProjectileMotion.wave:
        // 꼬불꼬불 — 도착 순간의 옆 위치(A·sin ωT)만큼 반대로 겨눈다
        final d = def.waveAmp * sin(2 * pi * def.waveHz * tt);
        game.mapArea.add(Bullet(origin, target - perp * (sign * d), speed: speed, def: def, curveSign: sign));
        break;
      default:
        // 직선·강슛·총알슛·무회전(무회전은 흔들림이 매번 달라 보정하지 않는다)
        game.mapArea.add(Bullet(origin, target, speed: speed, def: def));
    }
    if (kind == _Kick.rocket) game.shake(2, 0.1);
  }
}

/// 골문·페널티 에어리어·슈터 그리기 + 골대 상태 갱신
class GoalZone extends Component with HasGameRef<ZonberGame> {
  @override
  void update(double dt) {
    if (!gameRef.isGameOver) gameRef.goal.update(dt, gameRef.survivalTime);
  }

  @override
  void render(Canvas canvas) {
    final goal = gameRef.goal;
    const l = KeeperGoal.left, r = KeeperGoal.right, y = KeeperGoal.lineY, d = KeeperGoal.depth;
    const box = KeeperGoal.penaltyBox;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // 페널티 에어리어 안쪽을 살짝 밝게 — 여기가 나의 존
    canvas.drawRect(box, Paint()..color = Colors.white.withValues(alpha: 0.06));
    // 페널티 에어리어 · 골 에어리어 · 페널티 마크 · 페널티 아크(박스 바깥 부분만)
    canvas.drawRect(box, line);
    canvas.drawRect(KeeperGoal.goalArea, line);
    canvas.drawCircle(KeeperGoal.penaltySpot, 4, Paint()..color = Colors.white.withValues(alpha: 0.85));
    const sp = KeeperGoal.penaltySpot;
    const ar = KeeperGoal.arcRadius;
    final half = acos((sp.dy - box.top) / ar); // 박스 윗변과 만나는 각
    canvas.drawArc(Rect.fromCircle(center: sp, radius: ar), -pi / 2 - half, half * 2, false, line);

    // 그물 — 골라인 뒤
    final netRect = Rect.fromLTRB(l, y, r, y + d);
    canvas.drawRect(netRect, Paint()..color = Colors.white.withValues(alpha: 0.28));
    final net = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (double x = l; x <= r; x += 10) {
      canvas.drawLine(Offset(x, y), Offset(x, y + d), net);
    }
    for (double yy = y; yy <= y + d; yy += 8) {
      canvas.drawLine(Offset(l, yy), Offset(r, yy), net);
    }
    final frame = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(netRect, frame);
    // 골라인 — 무대 끝까지
    canvas.drawLine(const Offset(0, y), const Offset(ZonberGame.mapWidth, y), Paint()
      ..color = Colors.white
      ..strokeWidth = 3);

    // 골포스트 2개
    for (final pl in [true, false]) {
      final p = goal.postPos(pl);
      final pc = Offset(p.x, p.y);
      canvas.drawCircle(pc + const Offset(1, 2), KeeperGoal.postRadius, Paint()..color = Colors.black.withValues(alpha: 0.25));
      canvas.drawCircle(pc, KeeperGoal.postRadius, Paint()..color = Colors.white);
      canvas.drawCircle(pc, KeeperGoal.postRadius, Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }

    // 슈터(상대 선수) — 빨간 유니폼 점. 차는 순간 커진다.
    for (int i = 0; i < goal.shooters.length; i++) {
      final s = goal.shooters[i];
      final a = goal.appear(i);
      final scale = a * (1 + 0.35 * goal.kickFlash[i]);
      if (scale <= 0) continue;
      final c = Offset(s.x, s.y);
      // 슈터 그림 — 차는 순간 차는 그림
      if (GameArt.draw(canvas, goal.kickFlash[i] > 0.2 ? 'npc_kick' : 'npc_infield', c, 30 * scale)) continue;
      canvas.drawCircle(c + const Offset(1, 2), 13 * scale, Paint()..color = Colors.black.withValues(alpha: 0.2));
      canvas.drawCircle(c, 13 * scale, Paint()..color = const Color(0xFFE5484D));
      canvas.drawCircle(c, 13 * scale, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5);
      canvas.drawCircle(c + Offset(0, -2 * scale), 5 * scale, Paint()..color = const Color(0xFFFFE0C2)); // 머리
    }
  }
}

// ─────────────────────────────────────────────────────────────
// 피구 투구 — 상대 코트(위쪽)에서 캐릭터를 향해 **한 턴에 한 번** 던진다.
// docs/STAGES.md §2. 사방 스폰(갤럭시)과 달리 방향이 하나라 "무엇이 오나"를 읽는 게임.
//
// 턴 간격과 공 속도는 시간에 따라 줄고/늘고, 던지는 패턴은 단계(tier)로 어려워진다.
//   0  워밍업   ~12s   한 개씩 천천히
//   1  분열     ~30s   한 개 + 가끔 날아오다 3개로 갈라지는 공
//   2  분열+   ~50s   분열 3 비중 ↑ (세로로 줄지어 오는 일렬 투구는 없다)
//   3  벽       ~75s   가로 한 줄 3개(나란히 평행 비행) 추가
//   4  압박     ~100s  분열 5 · 가로 4 · 빠른 공(주황)
//   5  연타     ~130s  두 곳에서 동시 투구, 가로 5
//   6  극악     130s~  예측 조준(가는 방향 앞을 노림) + 동시 투구 + 최단 턴
// ⚠️ 수치를 바꾸면 피구 리더보드 기록의 의미가 달라진다(시즌 리셋 검토).
// ─────────────────────────────────────────────────────────────
enum _Throw { single, fastSingle, split3, split5, row3, row4, row5 }

class _DodgeballThrower {
  final Random _rng = Random();
  double _sinceThrow = 0;
  /// 첫 투구는 조금 기다렸다가 — 시작하자마자 맞지 않게
  double _nextBeat = 1.2;

  // 외야 패스 — 5~10초마다. 패스 도는 동안은 일반 투구를 쉰다.
  _PassBall? _pass;
  double _sincePass = 0;
  double _nextPass = 7;

  static int tierAt(double t) {
    if (t < 12) return 0;
    if (t < 30) return 1;
    if (t < 50) return 2;
    if (t < 75) return 3;
    if (t < 100) return 4;
    if (t < 130) return 5;
    return 6;
  }

  /// 턴 간격(초): 2.0s 에서 시작해 1초에 1%씩 짧아지고 0.4s 가 하한 (~160s 도달)
  static double beatAt(double t) => max(0.4, 2.0 * pow(0.99, t).toDouble());

  /// 기본 공 속도(px/s): 150 → 초당 +2.2, 상한 460
  static double speedAt(double t) => min(460.0, 150.0 + 2.2 * t);

  static const Map<int, Map<_Throw, int>> _weights = {
    0: {_Throw.single: 1},
    1: {_Throw.single: 7, _Throw.split3: 3},
    2: {_Throw.single: 4, _Throw.split3: 6},
    3: {_Throw.single: 2, _Throw.split3: 4, _Throw.row3: 4},
    4: {_Throw.fastSingle: 3, _Throw.split3: 2, _Throw.split5: 3, _Throw.row4: 2},
    5: {_Throw.fastSingle: 3, _Throw.split5: 3, _Throw.row4: 2, _Throw.row5: 2},
    6: {_Throw.fastSingle: 3, _Throw.split5: 3, _Throw.row5: 4},
  };

  _Throw _pick(int tier) {
    final w = _weights[tier]!;
    int roll = _rng.nextInt(w.values.reduce((a, b) => a + b));
    for (final e in w.entries) {
      roll -= e.value;
      if (roll < 0) return e.key;
    }
    return _Throw.single;
  }

  void update(double dt, ZonberGame game) {
    // 외야 패스 진행 중 — 끝날 때까지 일반 투구 쉼
    if (_pass != null) {
      if (_pass!.finished) {
        _pass = null;
        _sincePass = 0;
        _nextPass = 5 + _rng.nextDouble() * 5;
        _sinceThrow = 0;
        _nextBeat = 0.9;
      }
      return;
    }
    _sincePass += dt;
    if (_sincePass >= _nextPass && game.survivalTime >= 5 && !game.isGameOver) {
      _startPass(game);
      return;
    }
    _sinceThrow += dt;
    if (_sinceThrow < _nextBeat) return;
    _sinceThrow = 0;
    final t = game.survivalTime;
    _nextBeat = beatAt(t);
    final tier = tierAt(t);
    _throw(game, _pick(tier), tier, t);
    // 5단계부터 가끔 다른 자리에서 한 번 더 (동시 투구). 극악은 절반 확률.
    if ((tier == 5 && _rng.nextDouble() < 0.3) || (tier == 6 && _rng.nextDouble() < 0.5)) {
      _throw(game, _pick(tier - 2), tier, t);
    }
  }

  /// 외야 패스: 우리 코트 주위(좌·우 외야, 내 뒤)를 1~5번(무작위) 돌다가(초록 공) 빠른 공으로 던진다
  void _startPass(ZonberGame game) {
    final world = game.worldConfig;
    // 우리 코트 주위 외야 선수들(왼쪽·오른쪽·내 뒤) 사이로 1~5번(무작위) 돈다. 선수가 움직여도 따라간다.
    final outs = game.dodgeTeam.outfield;
    if (outs.isEmpty) return;
    final hops = 1 + _rng.nextInt(5);
    final pts = <Vector2>[];
    int last = -1;
    for (int k = 0; k <= hops; k++) {
      int s;
      do {
        s = _rng.nextInt(outs.length);
      } while (s == last && outs.length > 1);
      last = s;
      pts.add(outs[s]); // 같은 Vector2 객체 — 선수가 움직이면 패스 목표도 움직인다
    }
    final def = world.projectiles.length > 1 ? world.projectiles[1] : world.projectiles.first;
    final shot = min(700.0, max(380.0, speedAt(game.survivalTime) * 1.7));
    _pass = _PassBall(points: pts, def: def, shotSpeed: shot);
    game.mapArea.add(_pass!);
  }

  void _throw(ZonberGame game, _Throw kind, int tier, double t) {
    if (game.isGameOver || !game.player.isMounted) return;
    final world = game.worldConfig;
    final ball = world.projectiles.first;
    final fast = world.projectiles.length > 1 ? world.projectiles[1] : ball;

    // 상대 선수 한 명이 던진다(던지는 순간 커진다) — 선수가 없으면 무대 위쪽 바깥
    final team = game.dodgeTeam;
    final Vector2 origin;
    if (team.infield.isNotEmpty) {
      final i = _rng.nextInt(team.infield.length);
      team.flash[i] = 1;
      origin = team.infield[i] + Vector2(0, 12);
    } else {
      origin = Vector2(60 + _rng.nextDouble() * (ZonberGame.mapWidth - 120), -30);
    }
    Vector2 target = game.player.position.clone();
    // 극악: 캐릭터가 움직이는 방향 앞을 노린다
    if (tier >= 6) target += game.player.recentVelocity * 0.35;
    final dir = (target - origin).normalized();
    final perp = Vector2(-dir.y, dir.x);
    final speed = speedAt(t);

    void add(Vector2 from, ProjectileDef def, double v, {int splitInto = 0}) {
      final b = Bullet(from, from + dir * 100, speed: v * def.speedMult, def: def);
      if (splitInto > 0) {
        // 캐릭터까지 거리의 40% 지점에서 갈라진다
        b.splitAfter = (target - from).length * 0.4 / (v * def.speedMult);
        b.splitInto = splitInto;
      }
      game.mapArea.add(b);
    }

    switch (kind) {
      case _Throw.single:
        add(origin, ball, speed);
        break;
      case _Throw.fastSingle:
        add(origin, fast, speed);
        break;
      case _Throw.split3:
        add(origin, ball, speed, splitInto: 3);
        break;
      case _Throw.split5:
        add(origin, ball, speed, splitInto: 5);
        break;
      case _Throw.row3:
      case _Throw.row4:
      case _Throw.row5:
        // 가로 한 줄로 나란히(평행) — 벽처럼 오므로 옆으로 크게 빠져야 한다
        final n = kind == _Throw.row3 ? 3 : kind == _Throw.row4 ? 4 : 5;
        const gap = 28.0;
        for (int i = 0; i < n; i++) {
          final off = perp * ((i - (n - 1) / 2) * gap);
          final from = origin + off;
          // 캐릭터 위치 + 대형 폭의 절반만큼만 벌려 조준 → 도착할 때 벽이 좁아진다
          final b = Bullet(from, target + off * 0.5, speed: speed * ball.speedMult, def: ball);
          game.mapArea.add(b);
        }
        break;
    }
  }
}

