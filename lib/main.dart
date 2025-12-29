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
import 'package:flame/collisions.dart';
import 'package:flame/input.dart'; // Required for PanDetector
import 'package:flame/events.dart'; // Required for DragStartInfo etc?

import 'ranking_system.dart';
import 'editor_game.dart';
import 'user_profile.dart';
import 'map_selection_page.dart';
import 'leaderboard_widget.dart';
import 'map_service.dart'; // Import MapService
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

import 'dart:io';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("ZONBER GAME: UPDATE VERIFIED - SYMMETRICAL CHARACTERS 2024-12-30");

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await Firebase.initializeApp();
    await AdManager().initialize(); // Initialize AdMob only on mobile
  } else {
    print("Skipping Firebase/AdMob init on desktop/web");
  }

  // Fix Status Bar (White Icons for Dark Background)
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  await GameSettings().load(); // Load Settings
  await AudioManager().initialize(); // Preload Audio
  await LanguageManager().init(); // Initialize Language

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

  // Verification State
  List<List<int>>? _verifyingMapData;
  String? _verifyingMapName;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _loadGlobalBannerAd();
  }

  void _loadGlobalBannerAd() {
    _bannerAd = AdManager().loadBannerAd(() {
      setState(() {
        _isBannerAdReady = true;
      });
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    // Wait for Firebase to initialize if needed (already done in main)
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
    bool hasProfile = await UserProfileManager.hasProfile();
    setState(() {
      _currentPage = hasProfile ? 'Menu' : 'Profile';
    });
  }

  void _navigateTo(String page, {String? mapId}) {
    setState(() {
      _currentPage = page;
      if (mapId != null) {
        _currentMapId = mapId;
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
        // Game usually has its own pause menu, but if back is pressed:
        // Trigger pause logic if possible, or just ignore and let game UI handle it.
        // For now, simpler: Navigate to Menu? No, ask for confirmation.
        // Actually, passing 'null' to onBack for Game might be tricky if we want a specific behavior.
        // Let's make GameWidget handle the back internally or make _handleBack modify state.
        // But AppScaffold needs a callback.

        // If we want to pause:
        // This is hard to trigger inside the FlameGame from here without a controller.
        // So for Game, we might pass a specific handler?
        // Or simply:
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

      case 'Shop':
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
    // For Game, we might want to prevent accidental back?
    // User requested "Andoird back button works as previous page".
    return () => _handleBack();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [
        CountryLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AppScaffold(
        bannerAd: (_isBannerAdReady && _bannerAd != null)
            ? AdWidget(ad: _bannerAd!)
            : null,
        showBanner: true, // Always show top banner
        onBack: _getBackHandler(),
        child: Builder(builder: (context) => _buildPage(context)),
      ),
    );
  }

  Widget _buildPage(BuildContext context) {
    switch (_currentPage) {
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
        );
      case 'Game':
        final game = ZonberGame(
          mapId: _currentMapId,
          onExit: () {
            AdManager().showInterstitialIfReady();
            _navigateTo('Menu');
          },
          onGameOver: (result) {
            setState(() {
              _lastGameResult = result;
              _currentPage = 'Result';
              AdManager().showInterstitialIfReady();
            });
          },
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
                          onPressed: () => _pauseGame(context, game),
                        ),
                        // Time Display
                        ValueListenableBuilder<double>(
                          valueListenable: game.survivalTimeNotifier,
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
                  Expanded(child: GameWidget(game: game)),
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
            await AuthService().signOut();
            _navigateTo('Login');
          },
        );
      case 'Shop':
        return ShopPage(onBack: () => _navigateTo('MyProfile'));
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
          onOpenShop: () => _navigateTo('Shop'),
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
        builder: (context) => NeonDialog(
          title: LanguageManager.of(context).translate('verification_success'),
          titleColor: const Color(0xFF00FF88),
          message: success
              ? LanguageManager.of(context).translate('map_verified_message')
              : "Verification passed, but upload failed.", // Fallback if internal error
          actions: [
            NeonButton(
              text: LanguageManager.of(context).translate('ok'),
              onPressed: () {
                Navigator.pop(context);
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
        builder: (context) => NeonDialog(
          title: LanguageManager.of(context).translate('verification_failed'),
          titleColor: AppColors.secondary,
          message:
              "${LanguageManager.of(context).translate('verification_fail_message')}: ${time.toStringAsFixed(2)}s\n${LanguageManager.of(context).translate('must_survive_30s')}",
          actions: [
            NeonButton(
              text: LanguageManager.of(context).translate('try_again'),
              color: AppColors.primary,
              onPressed: () {
                Navigator.pop(context);
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
    showNeonDialog(
      context: context,
      title: LanguageManager.of(context).translate('paused'),
      message: null,
      actions: [
        NeonButton(
          text: LanguageManager.of(context).translate('exit'),
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
          text: LanguageManager.of(context).translate('resume'),
          onPressed: () {
            Navigator.pop(context);
            game.resumeEngine();
          },
        ),
      ],
    );
  }
}

class MainMenu extends StatefulWidget {
  final VoidCallback onStartGame;
  final VoidCallback onOpenEditor;
  final VoidCallback onProfile;
  final VoidCallback onCharacter;
  final VoidCallback onOpenShop;

  const MainMenu({
    super.key,
    required this.onStartGame,
    required this.onOpenEditor,
    required this.onProfile,
    required this.onCharacter,
    required this.onOpenShop,
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
                        Icons.grid_on,
                        'map_editor',
                        widget.onOpenEditor,
                        const Color(0xFF00E676), // Neon Green
                      ),
                      _buildMenuIcon(
                        context,
                        Icons.shopping_bag_outlined,
                        'shop',
                        widget.onOpenShop,
                        const Color(0xFFFFD700),
                      ),
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

  final Map<String, dynamic>? customMapData; // Optional map data

  ZonberGame({
    required this.mapId,
    required this.onExit,
    required this.onGameOver,
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
      startGame(customMapData: customMapData);
    } else {
      startGame();
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

  void startGame({Map<String, dynamic>? customMapData}) {
    isGameOver = false;
    survivalTime = 0.0;
    survivalTimeNotifier.value = 0.0;
    lastRecordId = null;

    overlays.remove('GameOverMenu');
    // overlays.add('GameUI'); // Removed old overlay

    mapArea.removeAll(mapArea.children);

    player = Player()
      ..position = Vector2(mapWidth / 2, mapHeight / 2)
      ..width = 54
      ..height = 54
      ..anchor = Anchor.center;
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
    } else if (mapId == 'zone_3_obstacles') {
      _spawnObstacles();
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

  void _spawnObstacles() {
    final r = Random();
    int count = 0;
    int maxAttempts = 100;

    while (count < 5 && maxAttempts > 0) {
      maxAttempts--;

      double w = 50 + r.nextDouble() * 100;
      double h = 50 + r.nextDouble() * 100;

      // 1. Outer Edge Constraint (Exclude 40px border - strict)
      // User requested "No placement in outer edge".
      // Assuming 1 tile = 40.0. Margin = 40.0 ensures it starts AFTER the first tile.
      // We will add a small epsilon to be safe or keep 40.
      double margin = 45.0; // Increased slightly to be visually clear
      double x = margin + r.nextDouble() * (mapWidth - margin * 2 - w);
      double y = margin + r.nextDouble() * (mapHeight - margin * 2 - h);

      Rect newRect = Rect.fromLTWH(x, y, w, h);

      // 2. Center 9-Tile Exclusion (3x3 tiles = 120x120)
      // Increased buffer significantly to 160x160 (4x4 area almost)
      Rect safeZone = Rect.fromCenter(
        center: Offset(mapWidth / 2, mapHeight / 2),
        width: 160,
        height: 160,
      );

      // Check Safe Zone
      if (newRect.overlaps(safeZone)) continue;

      // Check Existing Obstacles
      bool overlaps = false;
      for (final component in mapArea.children) {
        if (component is Obstacle) {
          Rect existing = component.toRect();
          // Add padding to prevent touching
          if (newRect.inflate(10).overlaps(existing)) {
            overlaps = true;
            break;
          }
        }
      }

      if (!overlaps) {
        mapArea.add(Obstacle(Vector2(x, y), Vector2(w, h)));
        count++;
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

  const ResultPage({
    super.key,
    required this.mapId,
    required this.result,
    required this.onRestart,
    required this.onExit,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "GAME OVER",
                style: AppTextStyles.header.copyWith(
                  color: AppColors.secondary,
                  fontSize: 48,
                  shadows: [
                    const Shadow(color: AppColors.secondary, blurRadius: 15),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Text(
                "SURVIVAL TIME",
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textDim,
                  fontSize: 16,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "${widget.result['survivalTime'].toStringAsFixed(3)}s",
                style: AppTextStyles.header.copyWith(
                  fontSize: 56,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 48),
              if (_isSaving)
                const CircularProgressIndicator(color: AppColors.primary)
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: NeonButton(
                    text: "SUBMIT SCORE",
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
                        text: "RETRY",
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
                        text: "EXIT",
                        onPressed: widget.onExit,
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

  @override
  Future<void> onLoad() async {
    // Increased Player Visual Size (24 -> 36 -> 54) for better visibility
    size = Vector2(54, 54);

    // Keep hitbox smaller than visual size for fair gameplay (30x30 centered)
    add(
      RectangleHitbox(
        position: Vector2(12, 12), // Centered: (54-30)/2 = 12
        size: Vector2(30, 30),
      ),
    );

    // Load Character Skin
    final profile = await UserProfileManager.getProfile();
    characterId = profile['characterId'] ?? 'neon_green';
    Character char = CharacterData.getCharacter(characterId);

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
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas); // Draw Sprite
    // Optional: Add a subtle glow/shadow if needed in future
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Direct 1:1 Drag Control
    // No speed multiplier, no acceleration.
    // Position moves exactly as much as the finger moved.
    Vector2 dragInput = gameRef.consumeDragDelta();
    if (!dragInput.isZero()) {
      // Separate X and Y axis movement for robust sliding

      // 1. Try moving X
      double nextX = position.x + dragInput.x;
      // Clamp for Center Anchor: half size ~ map - half size
      nextX = nextX.clamp(width / 2, ZonberGame.mapWidth - width / 2);

      // Calculate collision rect (Shift from Center to TopLeft)
      Rect rectX = Rect.fromLTWH(
        nextX - width / 2,
        position.y - height / 2,
        width,
        height,
      );

      if (!_checkCollision(rectX)) {
        position.x = nextX;
      }

      // 2. Try moving Y
      double nextY = position.y + dragInput.y;
      nextY = nextY.clamp(height / 2, ZonberGame.mapHeight - height / 2);

      Rect rectY = Rect.fromLTWH(
        position.x - width / 2,
        nextY - height / 2,
        width,
        height,
      );

      if (!_checkCollision(rectY)) {
        position.y = nextY;
      }
    }
  }

  bool _checkCollision(Rect rect) {
    for (final other in gameRef.mapArea.children) {
      if (other is Obstacle) {
        if (rect.inflate(-0.1).overlaps(other.toRect())) {
          // Deflate slightly to prevent sticky walls
          return true;
        }
      }
    }
    return false;
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
        // User requested stronger vibration. Using selectionClick or heavyImpact.
        // heavyImpact is already present. Let's make sure it's used.
        HapticFeedback.heavyImpact();
        // Or if user wants VERY strong, we can do multiple? No, sticking to heavy for now.
      }
      removeFromParent();
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    // Logic moved to update() for robust anti-tunneling
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
      Rect bulletRect = Rect.fromCenter(
        center: testPos.toOffset(),
        width: size.x,
        height: size.y,
      );

      /* World Bounds Check REMOVED - Bullets pass through */

      // Obstacle Check
      for (final other in gameRef.mapArea.children) {
        if (other is Obstacle) {
          if (bulletRect.overlaps(other.toRect())) {
            // Hit logic
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
  void render(Canvas canvas) {
    double radius = size.x / 2;
    canvas.drawCircle(Offset(radius, radius), radius + 2, _bulletGlow);
    canvas.drawCircle(Offset(radius, radius), radius, _bulletCore);
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
  late Timer _timer;
  final Random _random = Random();

  @override
  void onMount() {
    super.onMount();
    double interval = gameRef.mapId == 'zone_2_hard' ? 0.05 : 0.08;
    if (gameRef.mapId == 'zone_3_obstacles') interval = 0.07;

    _timer = Timer(interval, onTick: _spawnBullet, repeat: true);
    _timer.start();
  }

  @override
  void update(double dt) {
    _timer.update(dt);
  }

  void _spawnBullet() {
    if (gameRef.isGameOver) return;

    if (!gameRef.player.isMounted) return;

    Vector2 playerPos = gameRef.player.position;

    // Limits
    int limit = 80; // Further Reduced limit (120 -> 80)
    if (gameRef.mapArea.children.whereType<Bullet>().length > limit) return;

    // Reduced Range
    double range = 450.0;
    double angle = _random.nextDouble() * 2 * pi;
    Vector2 spawnPos = playerPos + Vector2(cos(angle), sin(angle)) * range;

    // Safety Check: Don't spawn inside obstacles
    bool safeToSpawn = true;
    Rect spawnRect = Rect.fromCenter(
      center: spawnPos.toOffset(),
      width: 10,
      height: 10,
    );
    for (final other in gameRef.mapArea.children) {
      if (other is Obstacle && other.toRect().overlaps(spawnRect)) {
        safeToSpawn = false;
        break;
      }
    }
    if (!safeToSpawn) return; // Skip this spawn attempt

    Vector2 targetPos =
        playerPos +
        Vector2(
          (_random.nextDouble() - 0.5) * 100,
          (_random.nextDouble() - 0.5) * 100,
        );

    // Speed Reduced: 300->220, 200->150
    double bulletSpeed = gameRef.mapId == 'zone_2_hard' ? 220.0 : 150.0;
    gameRef.mapArea.add(Bullet(spawnPos, targetPos, speed: bulletSpeed));
  }
}
