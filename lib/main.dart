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

  // Fix Status Bar (White Icons for Dark Background)
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

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

    // Normal App Flow
    User? user = FirebaseAuth.instance.currentUser;
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
        _navigateTo('Menu'); // Just go to menu for now as fallback
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
        _currentGame = ZonberGame(
          mapId: _currentMapId,
          initialSurvivalTime: _initialSurvivalTime,
          onExit: () {
            AdManager().showInterstitialIfReady();
            _navigateTo('MapSelect');
          },
          onGameOver: (result) {
            _handleGameOver(result);
          },
        );
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, dynamic result) {
            if (didPop) return;
            _pauseGame(context, _currentGame!);
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0B0C10),
            body: SafeArea(
              child: Column(
                children: [
                  // Top Header Bar
                  Container(
                    height: 80, // Increased height for larger text
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: const Color(0xFF0B0C10),
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
                              'TIME: ${value.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32, // Increased Size
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
                        // Pause Button Removed - Placeholder to keep Time centered
                        const SizedBox(width: 48), // Match IconButton size
                      ],
                    ),
                  ),
                  // Game Area
                  Expanded(child: GameWidget(game: _currentGame!)),
                ],
              ),
            ),
          ),
        );
      case 'Result':
        return ResultPage(
          mapId: _currentMapId,
          result: _lastGameResult!,
          onRestart: () => _navigateTo('Game'),
          onExit: () => _navigateTo('Menu'),
          onRevive: (_reviveCount < 3)
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
          revivesLeft: 3 - _reviveCount,
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
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, dynamic result) {
            if (didPop) return;
            _pauseGame(context, game);
          },
          child: Scaffold(
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
                              'TIME: ${value.toStringAsFixed(2)}',
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
          ),
        );
      case 'Profile':
        return UserProfilePage(onComplete: () => _navigateTo('Menu'));
      case 'MyProfile':
        return MyProfilePage(
          onBack: () => _navigateTo('Menu'),
          onOpenShop: () => _navigateTo('Shop'),
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
        return StatisticsPage(onBack: () => _navigateTo('Menu'));
      case 'Editor':
        return MapEditorPage(
          onVerify: _startVerification,
          onExit: () => _navigateTo('Menu'),
        );
      case 'MapSelect':
        return MapSelectionPage(
          onMapSelected: (mapId) => _navigateTo('Game', mapId: mapId),
          onShowRanking: (ctx, mapId) => _showRankingDialog(ctx, mapId),
          onBack: () => _navigateTo('Menu'),
          initialMapId: _currentMapId, // Pass current map ID for scrolling
        );
      case 'CharacterSelect':
        return CharacterSelectionPage(onBack: () => _navigateTo('Menu'));
      case 'Menu':
      default:
        return MainMenu(
          onStartGame: () => _navigateTo('MapSelect'),
          onOpenEditor: () => _navigateTo('Editor'),
          onProfile: () => _navigateTo('MyProfile'),
          onCharacter: () => _navigateTo('CharacterSelect'),
          // onOpenShop: () => _navigateTo('Shop'),
          onStatistics: () => _navigateTo('Statistics'),
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
              "${langManager.translate('verification_fail_message')}: ${time.toStringAsFixed(2)}s\n${langManager.translate('must_survive_30s')}",
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
      AdManager().showInterstitialIfReady();
    });
  }
}

class MainMenu extends StatefulWidget {
  final VoidCallback onStartGame;
  final VoidCallback onOpenEditor;
  final VoidCallback onProfile;
  final VoidCallback onCharacter;
  final VoidCallback? onOpenShop;
  final VoidCallback onStatistics;

  const MainMenu({
    super.key,
    required this.onStartGame,
    required this.onOpenEditor,
    required this.onProfile,
    required this.onCharacter,
    this.onOpenShop,
    required this.onStatistics,
  });

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Map<String, String> _profile = {};

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
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      // bannerAd handled globally by AppScaffold
      body: Stack(
        children: [
          // Background Elements
          Positioned.fill(
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
          // Grid Pattern (Optional Simplistic)
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

          // Content
          SafeArea(
            child: Column(
              children: [
                // TOP BAR: Profile Pill (Left) & Settings (Right)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left: Profile Info
                      GestureDetector(
                        onTap: widget.onProfile,
                        child: NeonCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          borderRadius: 30,
                          backgroundColor: AppColors.surfaceGlass,
                          borderColor: AppColors.primary.withOpacity(0.5),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _profile['flag'] ?? '',
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                (_profile['nickname'] ?? 'Player')
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Right: Settings Button
                      GestureDetector(
                        onTap: widget.onProfile,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGlass,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.textDim.withOpacity(0.5),
                            ),
                          ),
                          child: const Icon(
                            Icons.settings,
                            color: AppColors.textDim,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // CENTER: Title & Start Button
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      LanguageManager.of(context).translate('title'),
                      style: AppTextStyles.header.copyWith(
                        fontSize: 64,
                        shadows: [
                          Shadow(
                            blurRadius: 20,
                            color: AppColors.primary,
                            offset: Offset(0, 0),
                          ),
                          Shadow(
                            blurRadius: 40,
                            color: AppColors.primary.withOpacity(0.5),
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      LanguageManager.of(context).translate('subtitle'),
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.primaryDim,
                        letterSpacing: 6.0,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 80),
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: GestureDetector(
                        onTap: widget.onStartGame,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 24,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Text(
                            LanguageManager.of(context).translate('start_game'),
                            style: AppTextStyles.header.copyWith(
                              fontSize: 24,
                              color: Colors.white,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // BOTTOM: Secondary Menu (Row)
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMenuIcon(
                        context,
                        Icons.person_outline,
                        'character',
                        widget.onCharacter,
                        const Color(0xFFD91DF2),
                      ),
                      _buildMenuIcon(
                        context,
                        Icons.bar_chart,
                        'statistics', // key needs to be added to language manager or just use literal for now if key not exists
                        widget.onStatistics,
                        const Color(0xFF00BFFF), // Deep Sky Blue
                      ),
                      // Map Editor Removed (Local change respected)
                      // _buildMenuIcon(
                      //   context,
                      //   Icons.shopping_bag_outlined,
                      //   'shop',
                      //   widget.onOpenShop,
                      //   const Color(0xFFFFD700),
                      // ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuIcon(
    BuildContext context,
    IconData icon,
    String labelKey,
    VoidCallback onTap,
    Color color,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            LanguageManager.of(context).translate(labelKey),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
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

    if (mapId == 'zone_2_prism') {
      // Zone 2: PRISM (Diamonds & Chaos) - REFINED ALIGNMENT
      // 3x5 Grid Centered
      double size = 60.0;
      double colSpacing = 140.0;
      double rowSpacing = 140.0;

      // Offsets relative to Center (0, 0)
      List<double> xOffsets = [-colSpacing, 0, colSpacing];
      List<double> yOffsets = [
        -rowSpacing * 2,
        -rowSpacing,
        0,
        rowSpacing,
        rowSpacing * 2,
      ];

      for (double dy in yOffsets) {
        for (double dx in xOffsets) {
          // Skip center for player safety
          if (dx == 0 && dy == 0) continue;

          // Add Diamond
          var obs = Obstacle(
            Vector2(centerX + dx, centerY + dy),
            Vector2(size, size),
          );
          obs.angle = pi / 4; // 45 degrees
          obs.anchor = Anchor.center;
          mapArea.add(obs);
        }
      }
    } else if (mapId == 'zone_3_spiral') {
      // Zone 3: MAZE (Deterministic)
      int cols = 15;
      int rows = 25;
      double tileSize = 32.0;

      // Instantiate MazeGenerator (Random)
      var generator = MazeGenerator(rows, cols);
      List<List<dynamic>> walls = generator.generate();

      double wallThickness = 4.0; // Thin walls for maze

      // Center Safe Zone (Cell check)
      int cx = cols ~/ 2;
      int cy = rows ~/ 2;

      for (var wall in walls) {
        int c = wall[0] as int;
        int r = wall[1] as int;
        bool isHorizontal = wall[2] as bool;

        // Skip walls near center
        if (c >= cx - 1 && c <= cx + 1 && r >= cy - 1 && r <= cy + 1) continue;

        double wx = c * tileSize;
        double wy = r * tileSize;

        if (isHorizontal) {
          // Horizontal Wall at Top of cell (c, r)
          mapArea.add(
            Obstacle(
              Vector2(wx, wy - wallThickness / 2),
              Vector2(tileSize + wallThickness, wallThickness),
            ),
          );
        } else {
          // Vertical Wall at Left of cell (c, r)
          mapArea.add(
            Obstacle(
              Vector2(wx - wallThickness / 2, wy),
              Vector2(wallThickness, tileSize + wallThickness),
            ),
          );
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

class ResultPage extends StatefulWidget {
  final String mapId;
  final Map<String, dynamic> result;
  final VoidCallback onRestart;
  final VoidCallback onExit;
  final VoidCallback? onRevive; // Optional Revive Callback
  final int revivesLeft;

  const ResultPage({
    super.key,
    required this.mapId,
    required this.result,
    required this.onRestart,
    required this.onExit,
    this.onRevive,
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

  void _submitScore() async {
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
                            "${LanguageManager.of(context).translate('revive')} (${widget.revivesLeft})",
                        onPressed: widget.onRevive!,
                        icon: Icons.play_arrow,
                        color: AppColors.primary,
                        isPrimary: true, // Make it prominent
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
  // Removed Paint objects as we now use Sprites.
  // Removed unused speed variable.

  // Track Character ID for rendering
  String characterId = 'neon_green';
  Color trailColor = AppColors.primary; // Default trail color

  @override
  Future<void> onLoad() async {
    // Increased Player Visual Size (24 -> 36 -> 54) -> Reduced to 45
    size = Vector2(45, 45);

    // Keep hitbox smaller than visual size for fair gameplay (25x25 centered)
    add(
      RectangleHitbox(
        position: Vector2(10, 10), // Centered: (45-25)/2 = 10
        size: Vector2(25, 25),
      ),
    );

    // Load Character Skin
    final profile = await UserProfileManager.getProfile();
    characterId = profile['characterId'] ?? 'neon_green';
    Character char = CharacterData.getCharacter(characterId);
    trailColor = char.color; // Set trail color to character color

    if (char.imagePath != null) {
      // Flame expects path relative to assets/images/
      // Our path is assets/images/characters/..., so we strip the prefix
      final spritePath = char.imagePath!.replaceFirst('assets/images/', '');
      try {
        sprite = await gameRef.loadSprite(spritePath);
      } catch (e) {
        print("Error loading sprite: $e");
      }
    }

    // Scale Optimization: Set filter quality for smoother downsampling
    paint.filterQuality = FilterQuality.medium;
    paint.isAntiAlias = true;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas); // Draw Sprite
    // Optional: Add a subtle glow/shadow if needed in future
  }

  @override
  void update(double dt) {
    super.update(dt);

    // --- ROTATION EFFECT ---
    // Base rotation speed (radians per second)
    double rotationSpeed = 2.0;

    // Check if moving
    Vector2 dragInput = gameRef.consumeDragDelta();
    bool isMoving = !dragInput.isZero();

    // Spin faster when moving
    if (isMoving) {
      rotationSpeed = 8.0;
    }

    // Apply rotation
    angle += rotationSpeed * dt;
    angle %= 2 * pi; // Keep angle within 0~2PI range

    // --- MOVEMENT LOGIC (Existing) ---
    if (isMoving) {
      // PARTICLE TRAIL EFFECT
      // Emit particle every few frames (or random chance) to optimize
      if (Random().nextDouble() < 0.3) {
        // 30% chance per frame (~20 particles/sec)
        Vector2 trailPos = position.clone();
        // Add random slight offset for natural spread
        trailPos.add(
          Vector2(
            (Random().nextDouble() - 0.5) * 10,
            (Random().nextDouble() - 0.5) * 10,
          ),
        );

        gameRef.mapArea.add(
          ParticleSystemComponent(
            priority: 0, // Lower than player (10)
            particle: AcceleratedParticle(
              lifespan: 0.6,
              position: trailPos,
              speed: Vector2.zero(), // Stays where it was dropped
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  // Draw fading neon square/circle
                  final paint = Paint()
                    ..color = trailColor.withOpacity(1.0 - particle.progress)
                    ..style = PaintingStyle.fill;

                  // Shrinking size
                  double size = 6.0 * (1.0 - particle.progress);
                  canvas.drawCircle(Offset.zero, size / 2, paint);
                },
              ),
            ),
          ),
        );
      }

      // Separate X and Y axis movement for robust sliding

      // 1. Try moving X
      double nextX = position.x + dragInput.x;
      nextX = nextX.clamp(0, ZonberGame.mapWidth - width);
      position.x = nextX;

      // Resolve Collision X (MTV)
      Rect rectX = Rect.fromLTWH(position.x + 10, position.y + 10, 25, 25);
      Vector2? mtvX = _getMTV(rectX);
      if (mtvX != null) {
        position += mtvX;
      }

      // 2. Try moving Y
      double nextY = position.y + dragInput.y;
      nextY = nextY.clamp(0, ZonberGame.mapHeight - height);
      position.y = nextY;

      // Resolve Collision Y (MTV)
      Rect rectY = Rect.fromLTWH(position.x + 10, position.y + 10, 25, 25);
      Vector2? mtvY = _getMTV(rectY);
      if (mtvY != null) {
        position += mtvY;
      }
    }
  }

  // Returns Minimum Translation Vector to resolve collision
  Vector2? _getMTV(Rect rect) {
    // Player vertices (Axis Aligned)
    List<Vector2> playerPoly = [
      Vector2(rect.left, rect.top),
      Vector2(rect.right, rect.top),
      Vector2(rect.right, rect.bottom),
      Vector2(rect.left, rect.bottom),
    ];

    // Player Center for direction check
    Vector2 playerCenter = Vector2(rect.center.dx, rect.center.dy);

    for (final other in gameRef.mapArea.children) {
      if (other is Obstacle) {
        List<Vector2> obstaclePoly = _getRotatedVertices(other);

        // Calculate Obstacle Center (rough approx for direction)
        Vector2 obsCenter = other.position;
        if (other.anchor == Anchor.topLeft) obsCenter += other.size / 2;

        Vector2? mtv = _getPolyMTV(
          playerPoly,
          obstaclePoly,
          playerCenter,
          obsCenter,
        );
        if (mtv != null) {
          return mtv; // Return first significant collision correction
        }
      }
    }
    return null;
  }

  List<Vector2> _getRotatedVertices(PositionComponent pc) {
    Vector2 center;
    double w = pc.width;
    double h = pc.height;

    if (pc.anchor == Anchor.center) {
      center = pc.position;
    } else {
      center = pc.position + Vector2(w / 2, h / 2);
    }

    double hw = w / 2;
    double hh = h / 2;

    List<Vector2> corners = [
      Vector2(-hw, -hh),
      Vector2(hw, -hh),
      Vector2(hw, hh),
      Vector2(-hw, hh),
    ];

    double sinA = sin(pc.angle);
    double cosA = cos(pc.angle);

    return corners.map((p) {
      double rX = p.x * cosA - p.y * sinA;
      double rY = p.x * sinA + p.y * cosA;
      return center + Vector2(rX, rY);
    }).toList();
  }

  // Returns MTV if overlap, null if separated
  Vector2? _getPolyMTV(
    List<Vector2> polyA,
    List<Vector2> polyB,
    Vector2 centerA,
    Vector2 centerB,
  ) {
    List<Vector2> axes = [..._getAxes(polyA), ..._getAxes(polyB)];

    double minOverlap = double.infinity;
    Vector2 bestAxis = Vector2.zero();

    for (Vector2 axis in axes) {
      double? overlap = _getProjectionOverlap(axis, polyA, polyB);
      if (overlap == null) return null; // Found separating axis -> No collision

      if (overlap < minOverlap) {
        minOverlap = overlap;
        bestAxis = axis;
      }
    }

    // Ensure direction points from B to A (Push A out)
    Vector2 direction = centerA - centerB;
    if (direction.dot(bestAxis) < 0) {
      bestAxis = -bestAxis;
    }

    return bestAxis * minOverlap;
  }

  List<Vector2> _getAxes(List<Vector2> poly) {
    List<Vector2> axes = [];
    for (int i = 0; i < poly.length; i++) {
      Vector2 p1 = poly[i];
      Vector2 p2 = poly[(i + 1) % poly.length];
      Vector2 edge = p1 - p2;
      axes.add(Vector2(-edge.y, edge.x).normalized());
    }
    return axes;
  }

  double? _getProjectionOverlap(
    Vector2 axis,
    List<Vector2> polyA,
    List<Vector2> polyB,
  ) {
    double minA = double.infinity, maxA = double.negativeInfinity;
    double minB = double.infinity, maxB = double.negativeInfinity;

    for (Vector2 p in polyA) {
      double proj = p.dot(axis);
      if (proj < minA) minA = proj;
      if (proj > maxA) maxA = proj;
    }

    for (Vector2 p in polyB) {
      double proj = p.dot(axis);
      if (proj < minB) minB = proj;
      if (proj > maxB) maxB = proj;
    }

    // Check for gap
    if (maxB < minA || maxA < minB) return null;

    // Overlap amount
    double overlap1 = maxB - minA;
    double overlap2 = maxA - minB;
    return min(overlap1, overlap2);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Bullet) {
      gameRef.gameOver();
      if (GameSettings().vibrationEnabled) {
        HapticFeedback.heavyImpact();
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
    add(CircleHitbox());
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
          // Precise Check including Rotation
          if (other.containsPoint(testPos)) {
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

              // Determine side
              Rect testX = Rect.fromCenter(
                center: Offset(testPos.x, prev.y),
                width: size.x,
                height: size.y,
              );

              if (testX.overlaps(obs)) {
                velocity.x = -velocity.x;
                // Push out horizontally
                if (position.x < other.position.x) {
                  position.x = other.position.x - size.x / 2 - 1;
                } else {
                  position.x = other.position.x + other.size.x + size.x / 2 + 1;
                }
              } else {
                velocity.y = -velocity.y;
                // Push out vertically
                if (position.y < other.position.y) {
                  position.y = other.position.y - size.y / 2 - 1;
                } else {
                  position.y = other.position.y + other.size.y + size.y / 2 + 1;
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

    Vector2 playerPos = gameRef.player.position;

    // RAMPING: Increase Limit
    int currentLimit =
        _baseLimit + (level * 20); // Add 20 bullets cap per level

    if (gameRef.mapArea.children.whereType<Bullet>().length > currentLimit)
      return;

    // RAMPING: Increase Speed
    // Add 20 speed per level
    double currentSpeed = _baseSpeed + (level * 20);

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
