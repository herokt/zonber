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
import 'editor_game.dart';
import 'user_profile.dart';
import 'map_selection_page.dart';
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
  double _initialSurvivalTime = 0.0; // Track initial time for revives

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
          _navigateTo('MapSelect');
        },
        onGameOver: (result) {
          _handleGameOver(result);
        },
      );
    }

    setState(() {
      _currentPage = page;
      _initialSurvivalTime = initialTime;
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
      case 'MapSelect':
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
                  // Top Header Bar
                  Container(
                    color: const Color(0xFF0B0C10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 64,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Back Button (Acts as Pause)
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back,
                                    color: AppColors.primary,
                                    size: 28,
                                  ),
                                  onPressed: () => _pauseGame(context, _currentGame!),
                                ),
                                // Time Display
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
                        ),
                        // 에너지 HUD — 타이머 아래 전체 너비
                        _EnergyHud(notifier: _currentGame!.energyNotifier),
                      ],
                    ),
                  ),
                  // Game Area
                  Expanded(child: GameWidget(game: _currentGame!)),
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
          onRevive: (_reviveCount < 1 &&
                  !(FirebaseAuth.instance.currentUser?.isAnonymous ?? true))
              ? () {
                  bool shown = AdManager().showRewardedAd(() {
                    // On Reward: Resume Game
                    _reviveCount++; // Increment Revive Count
                    _navigateTo(
                      'Game',
                      initialTime: _lastGameResult!['survivalTime'],
                    );
                  });

                  if (!shown) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          LanguageManager.of(context).translate('ad_not_ready'),
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
      case 'MapSelect':
        return MapSelectionPage(
          onMapSelected: (mapId) => _navigateTo('Menu', mapId: mapId),
          onShowRanking: (ctx, mapId) => _showRankingDialog(ctx, mapId),
          onBack: () => _navigateTo('Menu'),
          initialMapId: _currentMapId,
        );
      case 'CharacterSelect':
        return CharacterSelectionPage(onBack: () => _navigateTo('Menu'));
      case 'Menu':
      default:
        return MainMenu(
          onStartGame: () => _navigateTo('Game'),
          onOpenEditor: () => _navigateTo('Editor'),
          onProfile: () => _navigateTo('MyProfile'),
          onStatistics: () => _navigateTo('Statistics'),
          onMapSelect: () => _navigateTo('MapSelect'),
          onCharacterSelect: () => _navigateTo('CharacterSelect'),
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
            _navigateTo('MapSelect');
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
  final VoidCallback onOpenEditor;
  final VoidCallback onProfile;
  final VoidCallback onStatistics;
  final VoidCallback onMapSelect;
  final VoidCallback onCharacterSelect;
  final String selectedMapId;

  const MainMenu({
    super.key,
    required this.onStartGame,
    required this.onOpenEditor,
    required this.onProfile,
    required this.onStatistics,
    required this.onMapSelect,
    required this.onCharacterSelect,
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

  static const _stages = [
    ('zone_1_classic',   'zone_1_title',  Colors.cyanAccent),
    ('zone_2_obstacles', 'zone_2_title',  Colors.greenAccent),
  ];

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


  void _showSettingsSheet(BuildContext context) {
    final lm = LanguageManager.of(context);
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textDim.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _settingsTile(
              icon: Icons.bar_chart_rounded,
              label: lm.translate('statistics'),
              color: const Color(0xFF00BFFF),
              onTap: () {
                Navigator.pop(context);
                widget.onStatistics();
              },
            ),
            const SizedBox(height: 10),
            _settingsTile(
              icon: Icons.edit_rounded,
              label: lm.translate('editor'),
              color: Colors.orangeAccent,
              onTap: () {
                Navigator.pop(context);
                widget.onOpenEditor();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: color.withOpacity(0.6), size: 20),
          ],
        ),
      ),
    );
  }

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
    final currentStage = _stages.firstWhere((s) => s.$1 == widget.selectedMapId, orElse: () => _stages[0]);
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

                // ── 스테이지 선택 ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel(lm.translate('stage')),
                      _selectorCard(
                        color: currentStage.$3 as Color,
                        onTap: widget.onMapSelect,
                        child: Text(
                          lm.translate(currentStage.$2),
                          style: TextStyle(
                            color: currentStage.$3 as Color,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
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
    int height = data['height'];
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
    } else if (mapId == 'zone_3_chaos') {
      // The Cross
      double thickness = 30;
      double centerGap = 60;

      // Vertical Wall (Top)
      mapArea.add(Obstacle(Vector2(centerX - thickness / 2, 0), Vector2(thickness, centerY - centerGap)));
      // Vertical Wall (Bottom)
      mapArea.add(Obstacle(Vector2(centerX - thickness / 2, centerY + centerGap), Vector2(thickness, h - (centerY + centerGap))));
      // Horizontal Wall (Left)
      mapArea.add(Obstacle(Vector2(0, centerY - thickness / 2), Vector2(centerX - centerGap, thickness)));
      // Horizontal Wall (Right)
      mapArea.add(Obstacle(Vector2(centerX + centerGap, centerY - thickness / 2), Vector2(w - (centerX + centerGap), thickness)));
    } else if (mapId == 'zone_4_impossible') {
      // The Grid
      double size = 35;
      double gap = 55;
      double startOffset = gap / 2;

      for (double y = startOffset; y < h / 2 - 20; y += size + gap) {
        for (double x = startOffset; x < w / 2 - 20; x += size + gap) {
          int ix = ((x - startOffset) / (size + gap)).round();
          int iy = ((y - startOffset) / (size + gap)).round();
          if ((ix + iy) % 2 == 0) {
            addSymmetrical(x, y, size, size);
          }
        }
      }
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
      builder: (context, energy, _) {
        // 실드 없는 캐릭터는 빈 슬림 바
        if (energy.max == 0) return const SizedBox(height: 28);

        final fillRatio = ((energy.current + energy.chargeProgress) / energy.max).clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ENERGY',
                style: TextStyle(
                  color: energy.color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Orbitron',
                  letterSpacing: 1.2,
                  shadows: [Shadow(color: energy.color, blurRadius: 6)],
                ),
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: energy.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: energy.color.withOpacity(0.3), width: 1),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: fillRatio,
                    child: Container(
                      decoration: BoxDecoration(
                        color: energy.color,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: energy.color.withOpacity(0.8),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
class ResultPage extends StatefulWidget {
  final String mapId;
  final Map<String, dynamic> result;
  final VoidCallback onRestart;
  final VoidCallback onExit;
  final VoidCallback? onRevive; // Optional Revive Callback
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

  // Shows a disclosure dialog before the rewarded ad (AdMob policy requirement:
  // must clearly display the required action and reward before each rewarded ad).
  void _showReviveConfirmDialog(BuildContext context) {
    showNeonDialog(
      context: context,
      title: LanguageManager.of(context).translate('revive_title'),
      message: LanguageManager.of(context).translate('revive_message'),
      titleColor: AppColors.primary,
      barrierDismissible: true,
      actions: [
        NeonButton(
          text: LanguageManager.of(context).translate('cancel'),
          onPressed: () => Navigator.of(context).pop(),
          color: AppColors.textDim,
          isPrimary: false,
          isCompact: true,
        ),
        NeonButton(
          text: LanguageManager.of(context).translate('watch_ad_button'),
          onPressed: () {
            Navigator.of(context).pop();
            widget.onRevive!();
          },
          icon: Icons.videocam,
          color: AppColors.primary,
          isPrimary: true,
          isCompact: true,
        ),
      ],
    );
  }

  void _showGuestRankingAlert() {
    showNeonDialog(
      context: context,
      title: LanguageManager.of(context).translate('guest_ranking_title'),
      message: LanguageManager.of(context).translate('guest_ranking_message'),
      titleColor: AppColors.primary,
      barrierDismissible: true,
      actions: [
        NeonButton(
          text: LanguageManager.of(context).translate('confirm'),
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

      String recordId = await _rankingSystem.saveRecord(
        widget.mapId,
        nickname,
        flag,
        widget.result['survivalTime'],
      );

      if (mounted) {
        setState(() {
          _savedRecordId = recordId;
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
            onRestart: widget.onRestart,
            onClose: widget.onExit,
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
  // Define paint for the neon look
  final Paint _paint = Paint()
    ..color =
        const Color(0xFFD32F2F) // Neon Red (or restore to previous color)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

  final Paint _fillPaint = Paint()
    ..color = const Color(0xFFD32F2F).withOpacity(0.3)
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

class GridBackground extends Component {
  final Paint _linePaint = Paint()
    ..color = const Color(0xFF1F2833)
        .withOpacity(0.3) // Reduced opacity
    ..strokeWidth = 2;
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
    for (double x = 0; x <= ZonberGame.mapWidth; x += 80) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, ZonberGame.mapHeight),
        _linePaint,
      );
    }
    for (double y = 0; y <= ZonberGame.mapHeight; y += 80) {
      canvas.drawLine(Offset(0, y), Offset(ZonberGame.mapWidth, y), _linePaint);
    }
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
  // --- 런타임 상태 ---
  double _energy = 0;       // 현재 에너지 (0.0 ~ _maxShields)
  bool _isInvincible = false;
  double _invincibleTimer = 0;
  static const double _invincibleDuration = 1.5; // 실드 소모 후 무적 시간
  bool _isBlinking = false;
  double _blinkTimer = 0;
  int _blinkCount = 0;
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
    _energy = _maxShields.toDouble();

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

    // --- 무적 타이머 (실드 소모 후) ---
    if (_isInvincible) {
      _invincibleTimer += dt;
      if (_invincibleTimer >= _invincibleDuration) {
        _isInvincible = false;
        _invincibleTimer = 0;
      }
    }

    // --- 깜빡임 타이머 (충돌 후 3회) ---
    if (_isBlinking) {
      _blinkTimer += dt;
      if (_blinkTimer >= 0.1) {
        _blinkTimer = 0;
        _blinkVisible = !_blinkVisible;
        _blinkCount++;
        if (_blinkCount >= 6) {
          _isBlinking = false;
          _blinkVisible = true;
          _blinkCount = 0;
        }
      }
    }

    // --- 에너지 회복 ---
    if (_maxShields > 0 && _shieldCooldown > 0 && _energy < _maxShields) {
      _energy += dt / _shieldCooldown;
      if (_energy > _maxShields) _energy = _maxShields.toDouble();
    }

    // --- 에너지 HUD 업데이트 (매 프레임: 충전 진행도 반영) ---
    _notifyEnergy();

    // --- ROTATION EFFECT ---
    double rotationSpeed = 2.0;

    // Check if moving
    Vector2 rawDrag = gameRef.consumeDragDelta();
    Vector2 dragInput = rawDrag * _speedMult;
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

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Bullet) {
      if (_isInvincible) {
        // 무적 중 — 총알만 제거
        other.removeFromParent();
        return;
      }
      if (_energy >= 1.0) {
        // 에너지 1 소모 (모든 캐릭터 동일)
        _energy -= 1.0;
        _isInvincible = true;
        _invincibleTimer = 0;
        _isBlinking = true;
        _blinkTimer = 0;
        _blinkCount = 0;
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

  // FIXED: Removed MaskFilter to ensure visibility on all devices
  static final Paint _bulletGlow = Paint()
    ..color = AppColors.secondary
        .withOpacity(0.5) // Toned down Red
    ..style = PaintingStyle.fill;

  static final Paint _bulletCore = Paint()
    ..color = AppColors
        .secondary // Red Core
    ..style = PaintingStyle.fill;

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

            // Determine Reflection Vector
            // Simple approach: Reverse velocity based on hitting side?
            // "Diamond" walls (angle != 0) should reflect chaotically or perpendicularly.

            if (other.angle != 0) {
              // Chaos Reflection for Prisms
              // Swap X/Y and random flip to create "Unexpected Diagonal"
              double speed = velocity.length;

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
  // Manual Timer Logic
  double _timeSinceLastSpawn = 0.0;

  // Base Config
  double _baseInterval = 0.1;
  double _baseSpeed = 150.0;
  int _baseLimit = 100;

  final Random _random = Random();

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

    // DIFFICULTY RAMPING
    // Every 30 seconds
    int level = (gameRef.survivalTime / 30).floor();

    // Decrease interval by 10% per level (capped at 0.02)
    double currentInterval = _baseInterval * pow(0.9, level);
    if (currentInterval < 0.02) currentInterval = 0.02;

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
    int currentLimit = _baseLimit + (level * 10);

    if (gameRef.mapArea.children.whereType<Bullet>().length > currentLimit)
      return;

    // RAMPING: Speed increases +15 per 30s level, capped at 2x base
    double currentSpeed = (_baseSpeed + (level * 15)).clamp(0, _baseSpeed * 2);

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
