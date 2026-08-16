import 'dart:math';
import 'package:flutter/material.dart';
import 'login_page.dart'; // Added
import 'package:firebase_auth/firebase_auth.dart'; // Added
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
import 'achievement_manager.dart';
import 'editor_game.dart';
import 'user_profile.dart';
import 'leaderboard_widget.dart';
import 'map_service.dart'; // Import MapService
import 'maze_generator.dart'; // Import MazeGenerator
import 'game_settings.dart';
import 'character_selection_page.dart';
import 'character_data.dart';
import 'audio_manager.dart';
import 'ad_manager.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // For BannerAd, AdWidget
import 'design_system.dart';
import 'shop_page.dart';
import 'services/auth_service.dart';
import 'package:provider/provider.dart'; // Added by instruction
import 'language_manager.dart'; // Added by instruction
import 'statistics_page.dart'; // Added by instruction
import 'game_config.dart'; // [NEW] Added for Stage Config
import 'backoffice/backoffice_home.dart'; // Added for Secret Admin
import 'firebase_options.dart'; // Added by instruction
import 'powerup_system.dart';
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

  // Status bar/nav bar: transparent + light icons (edge-to-edge compatible)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

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

class _ZonberAppState extends State<ZonberApp> {
  String _currentPage = 'Splash'; // Start with Splash to prevent Login flicker
  String _currentMapId = 'zone_1_classic'; // Default Map
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

    // Check for Secret Admin URL
    if (kIsWeb && Uri.base.toString().contains('/secret_admin')) {
      _currentPage = 'Backoffice';
    }

    _initializeApp();
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

      try {
        await AdManager().initialize();
        print("✅ AdMob initialized");
      } catch (e) {
        print("❌ AdMob initialization failed: $e");
      }

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

    // 3. Check Auth & Profile
    await _checkAuth();

    // 4. Check Ads
    await _checkAdStatus();
  }

  Future<void> _checkAdStatus() async {
    final adsRemoved = await UserProfileManager.isAdsRemoved();
    setState(() {
      _adsRemoved = adsRemoved;
    });

    if (!adsRemoved) {
      _loadGlobalBannerAd();
    }
  }

  void _loadGlobalBannerAd() {
    _bannerAd = AdManager().loadBannerAd(() {
      setState(() {
        _isBannerAdReady = true;
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
      setState(() {
        _currentPage = 'Login';
      });
    } else {
      _checkProfile();
    }
  }

  Future<void> _checkProfile() async {
    // Sync profile from Firestore first
    await UserProfileManager.syncProfile();

    bool hasProfile = await UserProfileManager.hasProfile();
    setState(() {
      _currentPage = hasProfile ? 'Menu' : 'Profile';
    });
  }

  void _navigateTo(String page, {String? mapId, double initialTime = 0.0}) {
    // Create the game object here (before setState) so that build() always
    // reuses the same instance. Creating it inside build() causes a new game
    // to be instantiated on every rebuild (e.g. when the banner ad loads),
    // which makes Flame's GameWidget restart the game mid-session.
    if (page == 'Game') {
      final effectiveMapId = mapId ?? _currentMapId;
      _currentGame = ZonberGame(
        mapId: effectiveMapId,
        initialSurvivalTime: initialTime,
        onExit: () {
          AdManager().showInterstitialIfReady();
          _navigateTo('Menu');
        },
        onGameOver: (result) {
          _handleGameOver(result);
        },
      );
    }

    setState(() {
      _currentPage = page;
      if (mapId != null) {
        _currentMapId = mapId;
      }
      // Reset revive count when starting a NEW game from MapSelect (Time 0)
      if (page == 'Game' && initialTime == 0.0) {
        _reviveCount = 0;
      }
    });
  }

  void _showRankingDialog(BuildContext dialogContext, String mapId) {
    print("Showing ranking dialog for $mapId");
    showDialog(
      context: dialogContext,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        child: LeaderboardWidget(
          mapId: mapId,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  /// Handles Android Back Button
  void _handleBack() {
    switch (_currentPage) {
      case 'Login':
      case 'Menu':
        // Let AppScaffold trigger Exit Dialog
        // Returning here allows onBack to be null, signalling AppScaffold to show quit dialog
        return;

      case 'Game':
        if (_currentGame != null && _latestContext != null) {
          _pauseGame(_latestContext!, _currentGame!);
        }
        break;

      case 'Result':
      case 'Profile':
      case 'Editor':
      case 'CharacterSelect':
      case 'EditorVerify':
        _navigateTo('Menu');
        break;

      case 'MyProfile':
        _navigateTo('Menu');
        break;

      case 'Statistics':
        _navigateTo('Menu');
        break;

      default:
        _navigateTo('Menu');
        break;
    }
  }

  /// Returns the Back Callback based on current page.
  /// Returns null if we represent the "Root" (to trigger exit dialog).
  VoidCallback? _getBackHandler() {
    if (_currentPage == 'Menu' || _currentPage == 'Login') {
      return null; // Root -> Exit Dialog
    }
    return () => _handleBack();
  }

  @override
  Widget build(BuildContext context) {
    // Manual listener ensures rebuild, so we can access singleton directly
    return MaterialApp(
      locale: Locale(LanguageManager().currentLanguage),
      supportedLocales: const [Locale('en'), Locale('ko')],
      localizationsDelegates: const [
        CountryLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AppScaffold(
        bannerAd: (_isBannerAdReady && _bannerAd != null && !_adsRemoved)
            ? AdWidget(ad: _bannerAd!)
            : null,
        showBanner: !_adsRemoved, // Show banner only if ads not removed
        onBack: _getBackHandler(),
        child: Builder(builder: (context) => _buildPage(context)),
      ),
    );
  }

  Widget _buildPage(BuildContext context) {
    _latestContext = context;
    switch (_currentPage) {
      case 'Backoffice':
        return const BackofficeHome();
      case 'Splash':
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "ZONBER",
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontFamily: 'Orbitron',
                    letterSpacing: 4.0,
                    shadows: [Shadow(color: AppColors.primary, blurRadius: 20)],
                  ),
                ),
                SizedBox(height: 32),
                CircularProgressIndicator(color: AppColors.primary),
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
        return Scaffold(
            backgroundColor: const Color(0xFF0B0C10),
            body: SafeArea(
              child: Column(
                children: [
                  // ── 상단 HUD (고정 레이아웃) ──
                  Container(
                    color: const Color(0xFF0B0C10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 타이머 + 뒤로가기
                        SizedBox(
                          height: 64,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back,
                                    color: AppColors.primary,
                                    size: 28,
                                  ),
                                  onPressed: () => _pauseGame(context, _currentGame!),
                                ),
                                ValueListenableBuilder<double>(
                                  valueListenable: _currentGame!.survivalTimeNotifier,
                                  builder: (context, value, child) {
                                    return Text(
                                      'TIME: ${value.toStringAsFixed(3)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Orbitron',
                                        shadows: [
                                          Shadow(color: AppColors.primary, blurRadius: 10),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 48),
                              ],
                            ),
                          ),
                        ),
                        // 에너지 바 (눈금 = 캐릭터 최대 에너지)
                        _EnergyHud(notifier: _currentGame!.energyNotifier),
                      ],
                    ),
                  ),
                  // ── 게임 영역 + 활성 아이템 오버레이 ──
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(child: GameWidget(game: _currentGame!)),
                        // 활성 아이템은 레이아웃을 차지하지 않는 상단 중앙 오버레이로 표시.
                        // IgnorePointer — 드래그 조작을 절대 가로채지 않는다.
                        Positioned(
                          top: 8,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: _ActiveEffectOverlay(
                              notifier: _currentGame!.powerUpNotifier,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        );
      case 'Result':
        return ResultPage(
          mapId: _currentMapId,
          result: _lastGameResult!,
          onRestart: () => _navigateTo('Game'),
          onExit: () => _navigateTo('Menu'),
          onNavigateToLogin: () => _navigateTo('Login'),
          // 부활은 게스트에게도 허용한다 — 광고 수익 관점에서 게스트를
          // 제외할 이유가 없고, 랭킹 등록과 달리 계정이 필요한 기능도 아니다.
          onRevive: (_reviveCount < 1)
              ? (String? submittedRecordId) {
                  bool shown = AdManager().showRewardedAd(() {
                    // On Reward: Resume Game
                    _reviveCount++; // Increment Revive Count
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
            backgroundColor: const Color(0xFF0B0C10),
            body: SafeArea(
              child: Column(
                children: [
                  Container(
                    height: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: const Color(0xFF0B0C10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Orbitron',
                                shadows: [
                                  Shadow(
                                    color: AppColors.primary,
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
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
        return UserProfilePage(onComplete: () => _navigateTo('Menu'));
      case 'MyProfile':
        return MyProfilePage(
          onBack: () => _navigateTo('Menu'),
          onOpenShop: () => _navigateTo('Shop'),
          onStatistics: () => _navigateTo('Statistics'),
          onLogout: () async {
            print('Main: onLogout called');

            // Show loading indicator
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const Center(
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

              // 2. Clear local profile
              try {
                await UserProfileManager.clearProfile().timeout(
                  const Duration(seconds: 1),
                );
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

              // 5. Navigate to Login
              print('Main: Navigating to Login');
              _navigateTo('Login');
            }
          },
        );
      case 'Shop':
        return ShopPage(
          onBack: () => _navigateTo('MyProfile'),
          onPurchaseReset: refreshPurchaseStatus,
        );
      case 'Statistics':
        return StatisticsPage(onBack: () => _navigateTo('MyProfile'));
      case 'Editor':
        return MapEditorPage(
          onVerify: _startVerification,
          onExit: () => _navigateTo('Menu'),
        );
      case 'CharacterSelect':
        return CharacterSelectionPage(onBack: () => _navigateTo('Menu'));
      case 'Menu':
      default:
        return MainMenu(
          onStartGame: () => _navigateTo('Game'),
          onProfile: () => _navigateTo('MyProfile'),
          onCharacterSelect: () => _navigateTo('CharacterSelect'),
          onShowRanking: () => _showRankingDialog(context, _currentMapId),
          selectedMapId: _currentMapId,
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
      message: null,
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

  void _handleGameOver(Map<String, dynamic> result) {
    // Update Stats
    UserProfileManager.updateGameStats(
      playTime: result['survivalTime'],
      mapId: result['mapId'] ?? _currentMapId,
    );

    setState(() {
      _lastGameResult = result;
      _currentPage = 'Result';
    });
    // Show interstitial after state update, not inside setState callback
    AdManager().showInterstitialIfReady();
  }
}

class MainMenu extends StatefulWidget {
  final VoidCallback onStartGame;
  final VoidCallback onProfile;
  final VoidCallback onCharacterSelect;
  final VoidCallback onShowRanking;
  final String selectedMapId;

  const MainMenu({
    super.key,
    required this.onStartGame,
    required this.onProfile,
    required this.onCharacterSelect,
    required this.onShowRanking,
    required this.selectedMapId,
  });

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Map<String, String> _profile = {};
  String _selectedCharacterId = 'neon_green';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadProfile() async {
    final profile = await UserProfileManager.getProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _selectedCharacterId = profile['characterId'] ?? 'neon_green';
      });

    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }


  Widget _guideButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 10)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontFamily: 'Orbitron',
                ),
              ),
            ],
          ),
        ),
      );

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textDim,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      );

  Widget _selectorCard({
    required Widget child,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.55), width: 1.5),
          ),
          child: Row(children: [
            Expanded(child: child),
            Icon(
              Icons.chevron_right_rounded,
              color: color.withOpacity(0.7),
              size: 22,
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final lm = LanguageManager.of(context);
    final currentChar = CharacterData.getCharacter(_selectedCharacterId);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    AppColors.primary.withOpacity(0.15),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
          IgnorePointer(child: CustomPaint(painter: _GridPainter())),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 상단 바 ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onProfile,
                        child: NeonCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          borderRadius: 30,
                          backgroundColor: AppColors.surfaceGlass,
                          borderColor: AppColors.primary.withOpacity(0.5),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_profile['flag'] ?? '', style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Text(
                                (_profile['nickname'] ?? 'Player').toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onProfile,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGlass,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.textDim.withOpacity(0.5)),
                          ),
                          child: const Icon(Icons.settings, color: AppColors.textDim, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 타이틀 ──
                const Spacer(flex: 1),
                Text(
                  lm.translate('title'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.header.copyWith(
                    fontSize: 52,
                    shadows: [
                      Shadow(blurRadius: 20, color: AppColors.primary, offset: Offset.zero),
                      Shadow(blurRadius: 40, color: AppColors.primary.withOpacity(0.5), offset: Offset.zero),
                    ],
                  ),
                ),
                Text(
                  lm.translate('subtitle'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.primaryDim,
                    letterSpacing: 6.0,
                    fontSize: 12,
                  ),
                ),

                const Spacer(flex: 1),

                // ── 가이드 / 랭킹 버튼 ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _guideButton(
                          icon: Icons.help_outline_rounded,
                          label: lm.translate('guide_rules_title'),
                          color: AppColors.primary,
                          onTap: () => GameGuideSheet.show(context, tab: 0),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _guideButton(
                          icon: Icons.flash_on_rounded,
                          label: lm.translate('guide_items_title'),
                          color: const Color(0xFFFFD700),
                          onTap: () => GameGuideSheet.show(context, tab: 1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _guideButton(
                          icon: Icons.leaderboard_rounded,
                          label: lm.translate('ranking'),
                          color: const Color(0xFF00FF88),
                          onTap: widget.onShowRanking,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── 캐릭터 선택 ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel(lm.translate('character')),
                      _selectorCard(
                        color: currentChar.color,
                        onTap: widget.onCharacterSelect,
                        child: Row(
                          children: [
                            currentChar.imagePath != null
                                ? Image.asset(currentChar.imagePath!, width: 32, height: 32, fit: BoxFit.contain)
                                : Icon(Icons.rocket_launch, color: currentChar.color, size: 28),
                            const SizedBox(width: 10),
                            Text(
                              lm.translate('char_${currentChar.id}'),
                              style: TextStyle(
                                color: currentChar.color,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // ── 게임 시작 버튼 ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onStartGame,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primary, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Text(
                          lm.translate('start_game'),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.header.copyWith(
                            fontSize: 20,
                            color: Colors.white,
                            letterSpacing: 2.0,
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
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryDim.withOpacity(0.2)
      ..strokeWidth = 1.0;

    const double step = 40.0;

    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ZonberGame extends FlameGame with HasCollisionDetection, PanDetector {
  final String mapId;
  final VoidCallback onExit;
  final Function(Map<String, dynamic>) onGameOver; // Callback for game over
  final double initialSurvivalTime;

  final Map<String, dynamic>? customMapData; // Optional map data

  ZonberGame({
    required this.mapId,
    required this.onExit,
    required this.onGameOver,
    this.initialSurvivalTime = 0.0,
    this.customMapData,
  });

  static const double mapWidth = 480.0;
  static const double mapHeight =
      768.0; // Updated to 24x32 grid (fits aspect ratio)
  static const double worldHeight = 800.0; // Total screen height

  late Player player;
  late BulletSpawner spawner;
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

  // 파워업 상태 — PowerUpManager가 매 프레임 업데이트
  final ValueNotifier<List<ActiveEffect>> powerUpNotifier =
      ValueNotifier(const []);

  PowerUpManager? powerUpManager;

  double survivalTime = 0.0;
  bool isGameOver = false;
  String? lastRecordId; // Last saved record ID

  @override
  Color backgroundColor() => const Color(0xFF0B0C10);

  @override
  Future<void> onLoad() async {
    // FIXED: Align Map to Top Center to reduce gap with HUD
    camera.viewfinder.anchor = Anchor.topCenter;

    world.add(GridBackground());
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

    player = Player()
      ..position = Vector2(mapWidth / 2, mapHeight / 2)
      ..width = 48
      ..height = 48
      ..anchor = Anchor.center
      ..priority = 10; // Ensure player is above trail (trail will be 0 or -1)
    mapArea.add(player);

    camera.stop();
    camera.viewfinder.visibleGameSize = Vector2(mapWidth, worldHeight);
    // FIXED: Update Viewfinder Position for Top Alignment
    camera.viewfinder.position = Vector2(mapWidth / 2, 0);
    camera.viewfinder.anchor = Anchor.topCenter;

    spawner = BulletSpawner();
    mapArea.add(spawner);

    powerUpNotifier.value = const [];
    powerUpManager = PowerUpManager();
    mapArea.add(powerUpManager!);

    // 진입 경고는 장애물·탄환 위에 그려야 하므로 플레이어(10)보다 높은 우선순위
    mapArea.add(BulletWarningOverlay()..priority = 15);

    if (customMapData != null) {
      _spawnCustomObstacles(customMapData);
    } else {
      _spawnFixedObstacles(mapId); // Config-based spawning
    }

    resumeEngine();

    // Start BGM
    AudioManager().startBgm();
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
    onGameOver({'survivalTime': survivalTime, 'mapId': mapId});
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isGameOver) {
      survivalTime += dt;
      survivalTimeNotifier.value = survivalTime;
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Joystick positioning removed
  }

  // PanDetector Implementation for Direct Touch Control
  @override
  void onPanUpdate(DragUpdateInfo info) {
    _dragDeltaAccumulator += info.delta.global;
  }
}

// ── 게임 화면 에너지 HUD ────────────────────────────────────
class _EnergyHud extends StatelessWidget {
  final ValueNotifier<({int current, int max, double chargeProgress, Color color})> notifier;

  const _EnergyHud({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (_, energy, __) {
        if (energy.max == 0) return const SizedBox(height: 32);

        // 칸 경계(눈금)는 캐릭터 최대 에너지 수만큼. 회복은 별도 표시 없이
        // 게이지가 그대로 차오른다.
        final fill =
            ((energy.current + energy.chargeProgress) / energy.max).clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SizedBox(
            height: 16,
            width: double.infinity,
            child: CustomPaint(
              painter: _EnergyBarPainter(
                fill: fill,
                segments: energy.max,
                color: energy.color,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 에너지 바 — 하나의 연속 게이지 + 칸 경계 눈금.
/// 눈금 개수(= `segments - 1`)가 캐릭터 최대 에너지를 나타낸다.
class _EnergyBarPainter extends CustomPainter {
  final double fill; // 0.0 ~ 1.0
  final int segments;
  final Color color;

  const _EnergyBarPainter({
    required this.fill,
    required this.segments,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );

    // 트랙
    canvas.drawRRect(
      rrect,
      Paint()..color = color.withValues(alpha: 0.10),
    );

    // 채움 (모서리 밖으로 새지 않게 클립)
    if (fill > 0) {
      final filled = Rect.fromLTWH(0, 0, size.width * fill, size.height);
      canvas.save();
      canvas.clipRRect(rrect);
      // 네온 글로우
      canvas.drawRect(
        filled,
        Paint()
          ..color = color.withValues(alpha: 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawRect(filled, Paint()..color = color);
      canvas.restore();
    }

    // 칸 경계 눈금 — 배경색으로 잘라내 채움/빈 구간 모두에서 보이게 한다
    if (segments > 1) {
      final tick = Paint()
        ..color = AppColors.background
        ..strokeWidth = 2;
      for (int i = 1; i < segments; i++) {
        final x = size.width * i / segments;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), tick);
      }
    }

    // 테두리
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_EnergyBarPainter old) =>
      old.fill != fill || old.segments != segments || old.color != color;
}

// ─────────────────────────────────────────────────────────────
/// 활성 아이템을 스테이지 상단 중앙에 작게 오버레이.
/// 지속형은 남은 시간이 원형 게이지로 줄어든다.
class _ActiveEffectOverlay extends StatelessWidget {
  final ValueNotifier<List<ActiveEffect>> notifier;
  const _ActiveEffectOverlay({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ActiveEffect>>(
      valueListenable: notifier,
      builder: (_, effects, __) {
        // 효과가 없으면 아무것도 그리지 않는다 — 플레이 화면을 가리지 않도록
        if (effects.isEmpty) return const SizedBox.shrink();
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: effects
              .map((e) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _EffectRing(effect: e),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _EffectRing extends StatelessWidget {
  final ActiveEffect effect;
  const _EffectRing({required this.effect});

  // 스테이지 위에 얹히는 오버레이 — 시야를 가리지 않도록 작게 유지한다
  static const double _size = 28;

  static const _icons = {
    PowerUpType.speedBoost: Icons.flash_on_rounded,
    PowerUpType.shield: Icons.favorite_rounded,
    PowerUpType.bulletClear: Icons.blur_on_rounded,
    PowerUpType.slowTime: Icons.hourglass_bottom_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final def = PowerUpDef.all[effect.type]!;
    final icon = _icons[effect.type] ?? Icons.star;
    // 지속형만 남은 시간 게이지를 줄인다. 즉시형은 꽉 찬 링으로 잠깐 표시만.
    final timed = def.duration > 0;
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 남은 시간 원형 게이지 (매 프레임 갱신되어 시계 방향으로 줄어든다)
          SizedBox(
            width: _size,
            height: _size,
            child: CustomPaint(
              painter: _CountdownRingPainter(
                progress: timed ? effect.progress : 1.0,
                color: def.color,
                strokeWidth: 2.5,
              ),
            ),
          ),
          // 아이콘 배경 — 탄막 위에서도 읽히게 어두운 원판을 깐다
          Container(
            width: _size - 10,
            height: _size - 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.65),
            ),
            child: Icon(icon, color: def.color, size: 11),
          ),
        ],
      ),
    );
  }
}

/// 남은 시간 링 — **시계 방향으로 줄어든다.**
///
/// 남은 호의 끝을 12시에 고정하고 시작점을 시계 방향으로 밀어내므로,
/// 소진되는 지점이 12시에서 출발해 시계 방향으로 이동한다.
/// (`CircularProgressIndicator`는 시작 각도를 지정할 수 없어 직접 그린다)
class _CountdownRingPainter extends CustomPainter {
  final double progress; // 1.0 = 꽉 참, 0.0 = 소진
  final Color color;
  final double strokeWidth;

  const _CountdownRingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    // 트랙 (남은 시간이 빠진 자리)
    canvas.drawArc(
      rect,
      0,
      pi * 2,
      false,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;

    const top = -pi / 2; // 12시 방향
    final sweep = pi * 2 * p;
    canvas.drawArc(
      rect,
      top + (pi * 2 - sweep), // 소진될수록 시작점이 시계 방향으로 이동
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(_CountdownRingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}

// ─────────────────────────────────────────────────────────────
class ResultPage extends StatefulWidget {
  final String mapId;
  final Map<String, dynamic> result;
  final VoidCallback onRestart;
  final VoidCallback onExit;
  /// 부활 콜백. 보상 지급 시 삭제해야 할 제출 기록 id를 함께 넘긴다.
  final void Function(String? submittedRecordId)? onRevive;
  final VoidCallback? onNavigateToLogin; // Navigate to Login Page
  final int revivesLeft;
  const ResultPage({
    super.key,
    required this.mapId,
    required this.result,
    required this.onRestart,
    required this.onExit,
    this.onRevive,
    this.onNavigateToLogin,
    this.revivesLeft = 0,
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  final RankingSystem _rankingSystem = RankingSystem();
  bool _isSaving = false;
  bool _showLeaderboard = false;
  String? _savedRecordId;
  /// 방금 제출한 기록 — 리더보드 상위 30 밖일 때 하단에 그대로 보여준다.
  Map<String, dynamic>? _submittedRecord;

  @override
  void initState() {
    super.initState();
    // 게임이 끝나면 곧바로 기록을 제출하고 랭킹 팝업으로 넘어간다 —
    // 플레이어가 자기 순위를 즉시 확인할 수 있어야 한다.
    // 게스트는 제출 대상이 아니므로 기존 결과 카드를 그대로 보여준다.
    final isGuest = FirebaseAuth.instance.currentUser?.isAnonymous ?? true;
    if (!isGuest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _submitScore());
    }
  }

  // Shows a disclosure dialog before the rewarded ad (AdMob policy requirement:
  // must clearly display the required action and reward before each rewarded ad).
  void _showReviveConfirmDialog(BuildContext context) {
    // 이벤트 핸들러에서 호출되므로 listen: false — 아니면 provider assertion으로 죽는다
    final t = LanguageManager.of(context, listen: false);
    showNeonDialog(
      context: context,
      title: t.translate('revive_title'),
      message: t.translate('revive_message'),
      titleColor: AppColors.primary,
      barrierDismissible: true,
      actions: [
        NeonButton(
          text: t.translate('cancel'),
          onPressed: () => Navigator.of(context).pop(),
          color: AppColors.textDim,
          isPrimary: false,
          isCompact: true,
        ),
        NeonButton(
          text: t.translate('watch_ad_button'),
          onPressed: () {
            Navigator.of(context).pop();
            // 보상 지급 시 이 판의 제출 기록을 지워야 하므로 id를 넘긴다
            widget.onRevive!(_savedRecordId);
          },
          icon: Icons.videocam,
          color: AppColors.primary,
          isPrimary: true,
          isCompact: true,
        ),
      ],
    );
  }

  Future<void> _unlockAchievements(
    double survivalTime,
    String nickname,
    String flag,
  ) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final keys = <String>{};

      // Survival achievements (immediate, no query)
      keys.addAll(AchievementManager.survivalKeys(survivalTime));

      // Rank achievements — check all periods for both global and national
      for (final period in RankingPeriod.values) {
        final globalList = await _rankingSystem.getTopRecords(
          widget.mapId,
          period: period,
        );
        final globalRank = userId.isNotEmpty
            ? globalList.indexWhere((r) => r['userId'] == userId) + 1
            : globalList.indexWhere((r) => r['nickname'] == nickname) + 1;
        if (globalRank > 0) {
          keys.addAll(AchievementManager.globalRankKeys(globalRank));
        }

        final natList = await _rankingSystem.getNationalRankings(
          widget.mapId,
          flag,
          period: period,
        );
        final natRank = userId.isNotEmpty
            ? natList.indexWhere((r) => r['userId'] == userId) + 1
            : natList.indexWhere((r) => r['nickname'] == nickname) + 1;
        if (natRank > 0) {
          keys.addAll(AchievementManager.nationalRankKeys(natRank));
        }
      }

      await AchievementManager.unlock(keys.toList());
    } catch (e) {
      print('Achievement unlock failed: $e');
    }
  }

  void _showGuestRankingAlert() {
    // 이벤트 핸들러 경로에서 호출된다 — listen: false 필수
    final t = LanguageManager.of(context, listen: false);
    showNeonDialog(
      context: context,
      title: t.translate('guest_ranking_title'),
      message: t.translate('guest_ranking_message'),
      titleColor: AppColors.primary,
      barrierDismissible: true,
      actions: [
        NeonButton(
          text: t.translate('confirm'),
          onPressed: () {
            Navigator.of(context).pop();
            widget.onNavigateToLogin?.call();
          },
          color: AppColors.primary,
          isPrimary: true,
          isCompact: true,
        ),
      ],
    );
  }

  void _submitScore() async {
    final isGuest = FirebaseAuth.instance.currentUser?.isAnonymous ?? true;
    if (isGuest) {
      _showGuestRankingAlert();
      return;
    }

    setState(() => _isSaving = true);

    try {
      final profile = await UserProfileManager.getProfile();
      final nickname = profile['nickname']!;
      final flag = profile['flag']!;
      final characterId = profile['characterId'] ?? 'neon_green';

      final double survivalTime = widget.result['survivalTime'];

      String recordId = await _rankingSystem.saveRecord(
        widget.mapId,
        survivalTime,
        characterId: characterId,
        flag: flag,
      );

      // Compute and persist achievements
      _unlockAchievements(survivalTime, nickname, flag);

      if (mounted) {
        setState(() {
          _savedRecordId = recordId;
          _submittedRecord = {
            'id': recordId,
            'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
            'nickname': nickname,
            'flag': flag,
            'characterId': characterId,
            'survivalTime': survivalTime,
          };
          _showLeaderboard = true;
          _isSaving = false;
        });
      }
    } catch (e) {
      print("Score submit failed: $e");
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showLeaderboard) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: LeaderboardWidget(
            mapId: widget.mapId,
            highlightRecordId: _savedRecordId,
            currentRecord: _submittedRecord,
            onRestart: widget.onRestart,
            onClose: widget.onExit,
            onRevive: widget.onRevive == null
                ? null
                : () => _showReviveConfirmDialog(context),
            revivesLeft: widget.revivesLeft,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: NeonCard(
          padding: const EdgeInsets.all(32),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  LanguageManager.of(context).translate('game_over'),
                  style: AppTextStyles.header.copyWith(
                    color: AppColors.secondary,
                    fontSize: 48,
                    decoration:
                        TextDecoration.none, // Fix: Remove yellow underline
                    shadows: [
                      const Shadow(color: AppColors.secondary, blurRadius: 15),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  LanguageManager.of(context).translate('survival_time'),
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textDim,
                    fontSize: 16,
                    decoration: TextDecoration.none,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "${widget.result['survivalTime'].toStringAsFixed(3)}s",
                  style: AppTextStyles.header.copyWith(
                    fontSize: 56,
                    decoration: TextDecoration.none,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 48),
                if (_isSaving)
                  const CircularProgressIndicator(color: AppColors.primary)
                else ...[
                  if (widget.onRevive != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: NeonButton(
                        text:
                            "${LanguageManager.of(context).translate('revive_watch_ad')} (${widget.revivesLeft})",
                        onPressed: () =>
                            _showReviveConfirmDialog(context),
                        icon: Icons.videocam,
                        color: AppColors.primary,
                        isPrimary: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: NeonButton(
                      text: LanguageManager.of(
                        context,
                      ).translate('submit_score'),
                      onPressed: _submitScore,
                      icon: Icons.emoji_events,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: NeonButton(
                          text: LanguageManager.of(context).translate('retry'),
                          onPressed: widget.onRestart,
                          color: const Color(0xFF00FF88), // Green
                          isPrimary: false,
                          icon: Icons.refresh,
                          isCompact: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: NeonButton(
                          text: LanguageManager.of(context).translate('exit'),
                          onPressed: () {
                            widget.onExit();
                          },
                          color: AppColors.secondary, // Red for Exit
                          isPrimary: false,
                          icon: Icons.logout,
                          isCompact: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// LeaderboardWidget moved to leaderboard_widget.dart

class MapArea extends PositionComponent {
  MapArea() : super(size: Vector2(ZonberGame.mapWidth, ZonberGame.mapHeight));

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

/// 존 테두리와 맵 하단 UI 영역만 그린다. (격자 배경은 제거됨)
class GridBackground extends Component {
  final Paint _borderPaint = Paint()
    ..color = AppColors
        .primaryDim // Use Primary Dim for less header glare
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4;

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, ZonberGame.mapWidth, ZonberGame.mapHeight),
      _borderPaint,
    );
    // Draw UI background for the joystick area
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        ZonberGame.mapHeight,
        ZonberGame.mapWidth,
        ZonberGame.worldHeight - ZonberGame.mapHeight,
      ),
      Paint()..color = AppColors.background,
    );
  }
}

class Player extends SpriteComponent
    with CollisionCallbacks, HasGameRef<ZonberGame> {
  String characterId = 'neon_green';
  Color trailColor = AppColors.primary;

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

  @override
  Future<void> onLoad() async {
    // 캐릭터 스탯 먼저 로드
    final profile = await UserProfileManager.getProfile();
    characterId = profile['characterId'] ?? 'neon_green';
    final char = CharacterData.getCharacter(characterId);
    final stats = char.stats;
    trailColor = char.color;

    // 모든 캐릭터 동일한 시각 크기 및 히트박스
    const double visualSize = 42;
    const double hitboxSize = 22;
    size = Vector2(visualSize, visualSize);

    // 스탯 적용
    _hbHalf = 11.0; // 고정 히트박스 22px의 절반
    _speedMult = stats.speedMultiplier;
    _maxShields = stats.maxEnergy;
    _shieldCooldown = stats.energyCooldown;
    _iframeDuration = stats.iframeDuration;
    _invincibleDuration = stats.iframeDuration;
    _energy = stats.maxEnergy.toDouble(); // 캐릭터 최대치로 시작

    // 히트박스: 시각 크기 중앙에 배치
    const double hbOffset = (visualSize - hitboxSize) / 2;
    add(
      RectangleHitbox(
        position: Vector2(hbOffset, hbOffset),
        size: Vector2(hitboxSize, hitboxSize),
      ),
    );

    // 스프라이트 로드
    if (char.imagePath != null) {
      final spritePath = char.imagePath!.replaceFirst('assets/images/', '');
      try {
        sprite = await gameRef.loadSprite(spritePath);
      } catch (e) {
        print("Error loading sprite: $e");
      }
    }

    paint.filterQuality = FilterQuality.medium;
    paint.isAntiAlias = true;

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

    super.render(canvas);
  }

  @override
  void update(double dt) {
    super.update(dt);

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

    // --- ROTATION EFFECT ---
    double rotationSpeed = 2.0;

    // Check if moving
    Vector2 rawDrag = gameRef.consumeDragDelta();
    final powerSpeedMult =
        gameRef.powerUpManager?.playerSpeedMultiplier ?? 1.0;
    // 최종 이동량 = 손가락 이동 × 캐릭터 속도 × 파워업 × 유저 감도 설정
    Vector2 dragInput =
        rawDrag * (_speedMult * powerSpeedMult * GameSettings().sensitivity);
    bool isMoving = !rawDrag.isZero();

    // Spin faster when moving
    if (isMoving) {
      rotationSpeed = 8.0;
    }

    // Apply rotation
    angle += rotationSpeed * dt;
    angle %= 2 * pi; // Keep angle within 0~2PI range

    // --- 아이들 연기 (항상, 캐릭터 뒤편 perimeter에서 사방으로 뿜음) ---
    if (Random().nextDouble() < 0.35) {
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
      if (Random().nextDouble() < 0.28) {
        // 이동 방향의 반대(뒤쪽)에 편향된 각도
        final backAngle = atan2(-rawDrag.y, -rawDrag.x) + (Random().nextDouble() - 0.5) * pi;
        final trailSpeed = 20.0 + Random().nextDouble() * 30.0;
        final spawnOffset = Vector2(cos(backAngle) * 8, sin(backAngle) * 8);
        gameRef.mapArea.add(
          ParticleSystemComponent(
            priority: 0,
            particle: AcceleratedParticle(
              lifespan: 0.35 + Random().nextDouble() * 0.25,
              position: position + spawnOffset,
              speed: Vector2(cos(backAngle) * trailSpeed, sin(backAngle) * trailSpeed),
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  final sz = 6.0 * (1.0 - particle.progress);
                  canvas.drawCircle(
                    Offset.zero,
                    sz / 2,
                    Paint()
                      ..color = trailColor.withOpacity(0.85 * (1.0 - particle.progress))
                      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
                  );
                },
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

  /// 파워업 픽업 시 에너지 추가.
  /// 이미 최대치라 흡수할 수 없으면 버려지지 않고 **무적 시간으로 전환**된다.
  /// (에너지 1칸짜리 캐릭터에게 shield 파워업이 죽은 픽업이 되는 문제를 방지)
  void addEnergy(int amount) {
    final before = _energy;
    _energy = (_energy + amount).clamp(0.0, _maxShields.toDouble());
    if (_energy > before) {
      _notifyEnergy();
      return;
    }
    // 초과분 → 무적 부여/연장
    grantInvincibility(_iframeDuration * 1.5);
  }

  /// 지정한 시간만큼 무적을 부여한다. 이미 무적이면 남은 시간에 더한다.
  void grantInvincibility(double seconds) {
    final remaining =
        _isInvincible ? (_invincibleDuration - _invincibleTimer) : 0.0;
    _invincibleDuration = remaining + seconds;
    _invincibleTimer = 0;
    _isInvincible = true;
    _isBlinking = true;
    _blinkTimer = 0;
    _blinkVisible = false;
    if (GameSettings().vibrationEnabled) HapticFeedback.lightImpact();
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    // 파워업 픽업
    if (other is PowerUpComponent) {
      other.pickup(gameRef.powerUpManager!);
      return;
    }

    if (other is Bullet) {
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
        other.removeFromParent();
        if (GameSettings().vibrationEnabled) HapticFeedback.heavyImpact();
        return;
      }
      // 에너지 부족 — 게임 오버
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

class Bullet extends PositionComponent
    with HasGameRef<ZonberGame>, CollisionCallbacks {
  Vector2 velocity = Vector2.zero();
  final double speed;

  Bullet(Vector2 position, Vector2 targetPosition, {this.speed = 200.0}) {
    this.position = position;
    // FIXED: Reduced Size (12 -> 9)
    size = Vector2(9, 9);
    anchor = Anchor.center;
    Vector2 direction = targetPosition - position;
    velocity = direction.normalized() * speed;
  }

  @override
  void render(Canvas canvas) {
    // Sophisticated Bullet Design: Core + Outer Glow + Trail hint
    // Outer Glow
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 1.5, // Larger glow
      Paint()
        ..color = AppColors.secondary.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Core
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 3,
      Paint()..color = Colors.white, // White hot core
    );

    // Inner Ring
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2,
      Paint()
        ..color = AppColors.secondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  Future<void> onLoad() async {
    // Radius 3.5 (vs default 4.5) — matches the visible inner ring more closely
    add(CircleHitbox(radius: 3.5, position: Vector2(4.5, 4.5), anchor: Anchor.center));
  }

  @override
  void update(double dt) {
    // slowTime 파워업은 이미 날아오는 탄환에도 즉시 적용되어야 한다.
    // (스폰 시점에 velocity를 깎으면 비행 시간 1.5~3초 때문에 효과가 늦게 체감되고,
    //  버프가 끝난 뒤에도 느린 탄환이 영구히 남는다)
    final slowMult = gameRef.powerUpManager?.bulletSpeedMultiplier ?? 1.0;

    // Raycast / Sub-step for high speed bullets
    Vector2 ds = velocity * dt * slowMult;
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
              const double bHalf = 4.5; // bullet half-size (9px / 2)

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
      _baseLimit = config.maxBullets;
    }
  }

  @override
  void update(double dt) {
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
    Vector2 playerPos = gameRef.player.position;

    // RAMPING: Increase bullet cap slightly over time
    int currentLimit = _baseLimit + (level * _limitPerLevel);

    if (gameRef.mapArea.children.whereType<Bullet>().length > currentLimit)
      return;

    // RAMPING: 레벨당 속도 +15, 기본값의 2배에서 상한
    // (slowTime 감속은 Bullet.update()에서 실시간 적용 — 여기서 곱하지 않는다)
    double currentSpeed =
        (_baseSpeed + (level * _speedPerLevel)).clamp(0, _baseSpeed * 2);

    // Reduced Range
    double range = 450.0;
    double angle = _random.nextDouble() * 2 * pi;
    Vector2 spawnPos = playerPos + Vector2(cos(angle), sin(angle)) * range;

    // Safety Check: Don't spawn inside obstacles
    bool safeToSpawn = true;
    for (final other in gameRef.mapArea.children) {
      if (other is Obstacle && other.containsPoint(spawnPos)) {
        safeToSpawn = false;
        break;
      }
    }
    if (!safeToSpawn) return;

    Vector2 targetPos =
        playerPos +
        Vector2(
          (_random.nextDouble() - 0.5) * 100,
          (_random.nextDouble() - 0.5) * 100,
        );

    gameRef.mapArea.add(Bullet(spawnPos, targetPos, speed: currentSpeed));
  }
}

// ─────────────────────────────────────────────────────────────
// BulletWarningOverlay — 맵 밖에서 진입 중인 탄환을 테두리에 표시
//
// 탄환은 플레이어 기준 반경 450px 원주에서 스폰되는데 맵 폭이 480이라
// 좌우 스폰 지점 상당수가 맵 밖이다. MapArea에 clipRect가 걸려 있어
// 플레이어 입장에서는 "보이지 않는 곳에서 갑자기" 튀어나온다.
// 이 컴포넌트가 진입 지점을 미리 알려 최소한의 공정성을 보장한다.
// ─────────────────────────────────────────────────────────────
class BulletWarningOverlay extends Component with HasGameRef<ZonberGame> {
  /// 이 거리 안쪽으로 접근한 탄환만 표시 (너무 멀면 화면이 지저분해진다)
  static const double _showRange = 320.0;
  static const double _markerLength = 14.0;

  @override
  void render(Canvas canvas) {
    if (gameRef.isGameOver) return;

    const double w = ZonberGame.mapWidth;
    const double h = ZonberGame.mapHeight;

    for (final bullet in gameRef.mapArea.children.whereType<Bullet>()) {
      final p = bullet.position;
      final outside = p.x < 0 || p.x > w || p.y < 0 || p.y > h;
      if (!outside) continue;

      // 맵 경계에서 가장 가까운 지점 = 진입 예상 위치
      final edgeX = p.x.clamp(0.0, w);
      final edgeY = p.y.clamp(0.0, h);
      final dx = edgeX - p.x;
      final dy = edgeY - p.y;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist > _showRange) continue;

      // 맵을 향해 오는 탄환만 (멀어지는 탄환은 무시)
      if (bullet.velocity.x * dx + bullet.velocity.y * dy <= 0) continue;

      // 가까울수록 진하고 굵게
      final t = 1.0 - (dist / _showRange); // 0(먼) ~ 1(코앞)
      final alpha = (0.25 + t * 0.65).clamp(0.0, 0.9);

      // 경계선에 수직인 짧은 막대로 진입 지점 표시
      final bool vertical = edgeX == 0.0 || edgeX == w;
      final half = _markerLength / 2 * (0.6 + t * 0.4);
      final Offset a, b;
      if (vertical) {
        a = Offset(edgeX, edgeY - half);
        b = Offset(edgeX, edgeY + half);
      } else {
        a = Offset(edgeX - half, edgeY);
        b = Offset(edgeX + half, edgeY);
      }

      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = AppColors.secondary.withValues(alpha: alpha)
          ..strokeWidth = 2.5 + t * 1.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────
// PowerUpComponent — 맵 위에 스폰되는 파워업 오브
// ─────────────────────────────────────────────────────────────
class PowerUpComponent extends PositionComponent
    with HasGameRef<ZonberGame> {
  final PowerUpType type;
  double _pulseTimer = 0.0;
  bool _pickedUp = false;

  static const double _size = 28.0;
  static const double _lifetime = 15.0;   // 총 수명
  static const double _blinkStart = 11.0; // 이 시간 이후 깜빡임 시작
  static const double _blinkInterval = 0.25;

  double _lifetimer = 0.0;
  double _blinkTimer = 0.0;
  bool _blinkVisible = true;

  PowerUpComponent({required this.type, required Vector2 spawnPos})
      : super(
          position: spawnPos,
          size: Vector2.all(_size),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    add(CircleHitbox(radius: _size / 2, collisionType: CollisionType.passive));
  }

  void pickup(PowerUpManager manager) {
    if (_pickedUp) return;
    _pickedUp = true;
    manager.applyEffect(type);
    removeFromParent();
  }

  @override
  void update(double dt) {
    _pulseTimer += dt;
    _lifetimer += dt;

    // 수명 초과 → 제거
    if (_lifetimer >= _lifetime) {
      removeFromParent();
      return;
    }

    // 깜빡임 구간
    if (_lifetimer >= _blinkStart) {
      _blinkTimer += dt;
      if (_blinkTimer >= _blinkInterval) {
        _blinkTimer -= _blinkInterval;
        _blinkVisible = !_blinkVisible;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_blinkVisible) return; // 깜빡임 비가시 프레임 스킵

    final def = PowerUpDef.all[type]!;
    final center = Offset(_size / 2, _size / 2);
    // 수명이 끝날수록 투명도 감소
    final lifeFade = ((_lifetime - _lifetimer) / (_lifetime - _blinkStart)).clamp(0.3, 1.0);
    final pulse = 0.85 + sin(_pulseTimer * 3.0) * 0.15;
    final r = (_size / 2) * pulse;

    // 외부 글로우
    canvas.drawCircle(
      center, r + 5,
      Paint()
        ..color = def.color.withOpacity(0.25 * lifeFade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // 코어 원
    canvas.drawCircle(center, r, Paint()..color = def.color.withOpacity(0.85 * lifeFade));
    // 링
    canvas.drawCircle(
      center, r,
      Paint()
        ..color = Colors.white.withOpacity(0.55 * lifeFade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Material 아이콘 렌더링
    final iconDef = _iconForType(type);
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconDef.codePoint),
        style: TextStyle(
          fontFamily: iconDef.fontFamily,
          package: iconDef.fontPackage,
          color: Colors.white.withOpacity(lifeFade),
          fontSize: 13,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  static IconData _iconForType(PowerUpType t) {
    switch (t) {
      case PowerUpType.speedBoost:  return Icons.flash_on;
      case PowerUpType.shield:      return Icons.favorite;
      case PowerUpType.bulletClear: return Icons.blur_on;
      case PowerUpType.slowTime:    return Icons.hourglass_bottom;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// PowerUpManager — 스폰 타이밍 및 활성 효과 관리
// ─────────────────────────────────────────────────────────────
class PowerUpManager extends Component with HasGameRef<ZonberGame> {
  final _rng = Random();
  double _spawnTimer = 0.0;
  late double _nextSpawnIn;

  PowerUpManager() {
    _nextSpawnIn = _randomInterval();
  }

  double _randomInterval() => 8.0 + _rng.nextDouble() * 22.0 + _rng.nextDouble() * 10.0; // 8~40초 이중 랜덤

  // ── Player에 전달하는 속도 배수
  double get playerSpeedMultiplier {
    final active = gameRef.powerUpNotifier.value;
    return active.any((e) => e.type == PowerUpType.speedBoost) ? 1.6 : 1.0;
  }

  // ── Bullet에 전달하는 속도 배수
  double get bulletSpeedMultiplier {
    final active = gameRef.powerUpNotifier.value;
    return active.any((e) => e.type == PowerUpType.slowTime) ? 0.5 : 1.0;
  }

  /// 즉시형 효과를 HUD에 남겨두는 시간 (게임플레이에는 영향 없음, 표시 전용)
  static const double instantDisplayDuration = 1.4;

  /// 파워업 획득 시 호출 (PowerUpComponent → Player → 여기).
  ///
  /// **모든 아이템은 먹는 즉시 발동된다.** 보관 슬롯은 없다.
  /// - 지속형(speedBoost / slowTime) → 지속 시간만큼 효과 유지, HUD에 남은 시간 게이지
  /// - 즉시형(shield / bulletClear) → 곧바로 발동하고, 무엇을 먹었는지 알 수 있게
  ///   짧게 HUD에만 남긴다 (타이머 게이지 없음)
  void applyEffect(PowerUpType type) {
    final def = PowerUpDef.all[type]!;

    if (def.duration > 0) {
      _activateTimed(type, def.duration);
      return;
    }

    _fireInstant(type);
    _activateTimed(type, instantDisplayDuration);
  }

  void _activateTimed(PowerUpType type, double duration) {
    final current = List<ActiveEffect>.from(gameRef.powerUpNotifier.value);
    current.removeWhere((e) => e.type == type); // 재획득 시 타이머 갱신
    current.add(ActiveEffect(type: type, total: duration));
    gameRef.powerUpNotifier.value = List.unmodifiable(current);
  }

  void _fireInstant(PowerUpType type) {
    switch (type) {
      case PowerUpType.bulletClear:
        for (final b in gameRef.mapArea.children.whereType<Bullet>().toList()) {
          b.removeFromParent();
        }
        if (GameSettings().vibrationEnabled) HapticFeedback.mediumImpact();
      case PowerUpType.shield:
        if (gameRef.player.isMounted) gameRef.player.addEnergy(1);
      default:
        break;
    }
  }

  @override
  void update(double dt) {
    if (gameRef.isGameOver) return;

    // 지속 효과 타이머 감소
    final current = List<ActiveEffect>.from(gameRef.powerUpNotifier.value);
    if (current.isNotEmpty) {
      for (final e in current) {
        e.remaining -= dt;
      }
      // ⚠️ 새 리스트로 매 프레임 재할당해야 HUD 게이지가 실제로 줄어든다.
      // (같은 객체를 수정하면 ValueNotifier가 알리지 않아 링이 멈춰 보인다)
      gameRef.powerUpNotifier.value =
          List.unmodifiable(current.where((e) => e.remaining > 0));
    }

    // 스폰 타이머
    _spawnTimer += dt;
    if (_spawnTimer >= _nextSpawnIn) {
      _spawnTimer = 0;
      _nextSpawnIn = _randomInterval();
      _trySpawn();
    }
  }

  void _trySpawn() {
    // 동시 최대 2개
    final existing =
        gameRef.mapArea.children.whereType<PowerUpComponent>().length;
    if (existing >= 2) return;

    final type = PowerUpType.values[_rng.nextInt(PowerUpType.values.length)];
    final pos = _safePosition();
    if (pos != null) {
      gameRef.mapArea.add(PowerUpComponent(type: type, spawnPos: pos));
    }
  }

  Vector2? _safePosition() {
    const margin = 60.0;
    for (int i = 0; i < 10; i++) {
      final x = margin + _rng.nextDouble() * (ZonberGame.mapWidth - margin * 2);
      final y = margin + _rng.nextDouble() * (ZonberGame.mapHeight - margin * 2);
      final pos = Vector2(x, y);

      // 플레이어와 너무 가까우면 제외
      if (gameRef.player.isMounted &&
          gameRef.player.position.distanceTo(pos) < 80) continue;

      // 장애물 내부 제외
      bool safe = true;
      for (final child in gameRef.mapArea.children) {
        if (child is Obstacle) {
          final rect = Rect.fromLTWH(
            child.position.x, child.position.y,
            child.size.x, child.size.y,
          ).inflate(8);
          if (rect.contains(Offset(pos.x, pos.y))) {
            safe = false;
            break;
          }
        }
      }
      if (safe) return pos;
    }
    return null;
  }
}
