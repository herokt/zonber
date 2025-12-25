import 'dart:math';
import 'package:flutter/material.dart';
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

import 'dart:io';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await Firebase.initializeApp();
    await AdManager().initialize(); // Initialize AdMob only on mobile
  } else {
    print("Skipping Firebase/AdMob init on desktop/web");
  }

  await GameSettings().load(); // Load Settings
  await AudioManager().initialize(); // Preload Audio
  runApp(const ZonberApp());
}

class ZonberApp extends StatefulWidget {
  const ZonberApp({super.key});

  @override
  State<ZonberApp> createState() => _ZonberAppState();
}

class _ZonberAppState extends State<ZonberApp> {
  String _currentPage =
      'Loading'; // Menu, MapSelect, Game, Result, Editor, Profile, Loading
  String _currentMapId = 'zone_1_classic'; // Default Map
  Map<String, dynamic>? _lastGameResult; // Store result data

  // Verification State
  List<List<int>>? _verifyingMapData;
  String? _verifyingMapName;

  @override
  void initState() {
    super.initState();
    _checkProfile();
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
      home: Scaffold(body: _buildPage()),
    );
  }

  Widget _buildPage() {
    switch (_currentPage) {
      case 'Game':
        return GameWidget(
          game: ZonberGame(
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
          ),
          overlayBuilderMap: {
            'GameUI': (context, ZonberGame game) =>
                GameUI(game: game, onExit: () => _navigateTo('Menu')),
          },
          initialActiveOverlays: const ['GameUI'],
        );
      case 'Result':
        return ResultPage(
          mapId: _currentMapId,
          result: _lastGameResult!,
          onRestart: () => _navigateTo('Game'),
          onExit: () => _navigateTo('Menu'),
        );
      case 'EditorVerify':
        return GameWidget(
          game: ZonberGame(
            mapId: 'verify_mode',
            customMapData: {
              'grid': _verifyingMapData!.expand((x) => x).toList(),
              'width': _verifyingMapData![0].length,
              'height': _verifyingMapData!.length,
            },
            onExit: () => _navigateTo('Editor'), // Abort verification
            onGameOver: _onVerificationGameOver,
          ),
          overlayBuilderMap: {
            'GameUI': (context, ZonberGame game) =>
                GameUI(game: game, onExit: () => _navigateTo('Editor')),
          },
          initialActiveOverlays: const ['GameUI'],
        );
      case 'Profile':
        return UserProfilePage(onComplete: () => _navigateTo('Menu'));
      case 'Editor':
        return GameWidget(
          game: MapEditorGame(),
          overlayBuilderMap: {
            'EditorUI': (context, MapEditorGame game) => EditorUI(
              game: game,
              onVerify: _startVerification,
              onExit: () => _navigateTo('Menu'),
            ),
          },
          initialActiveOverlays: const ['EditorUI'],
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
          onProfile: () => _navigateTo('Profile'),
          onCharacter: () => _navigateTo('CharacterSelect'),
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
          title: "VERIFICATION SUCCESS",
          titleColor: const Color(0xFF00FF88),
          message: success
              ? "Map '${_verifyingMapName!}' has been verified and uploaded!"
              : "Verification passed, but upload failed.",
          actions: [
            NeonButton(
              text: "OK",
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
          title: "VERIFICATION FAILED",
          titleColor: AppColors.secondary,
          message:
              "You survived ${time.toStringAsFixed(2)}s.\nYou must survive at least 30s to upload.",
          actions: [
            NeonButton(
              text: "TRY AGAIN",
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
}

class MainMenu extends StatefulWidget {
  final VoidCallback onStartGame;
  final VoidCallback onOpenEditor;
  final VoidCallback onProfile;
  final VoidCallback onCharacter;

  const MainMenu({
    super.key,
    required this.onStartGame,
    required this.onOpenEditor,
    required this.onProfile,
    required this.onCharacter,
  });

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      bannerAd: (_isBannerAdReady && _bannerAd != null)
          ? AdWidget(ad: _bannerAd!)
          : null,
      body: Stack(
        children: [
          // Background Elements
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),

          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Text(
                  "ZONBER",
                  style: AppTextStyles.header.copyWith(fontSize: 64),
                ),
                Text(
                  "SURVIVE THE ZONE",
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.primaryDim,
                    letterSpacing: 4.0,
                  ),
                ),
                const SizedBox(height: 60),
                NeonMenuButton(
                  text: "START GAME",
                  onPressed: widget.onStartGame,
                  isPrimary: false,
                  color: AppColors.secondary,
                ),
                NeonMenuButton(
                  text: "CHARACTER",
                  onPressed: widget.onCharacter,
                  color: const Color(0xFFD91DF2),
                ),
                NeonMenuButton(
                  text: "MAP EDITOR",
                  onPressed: widget.onOpenEditor,
                  isPrimary: true,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.person,
                    color: AppColors.primary,
                    size: 32,
                  ),
                  onPressed: widget.onProfile,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
  static const double mapHeight = 720.0; // Playable area
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

  // UI Component
  late TextComponent timeText;

  double survivalTime = 0.0;
  bool isGameOver = false;
  String? lastRecordId; // Last saved record ID

  @override
  Color backgroundColor() => const Color(0xFF0B0C10);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.center;
    world.add(GridBackground());
    mapArea = MapArea();
    world.add(mapArea);

    timeText = TextComponent(
      text: 'TIME: 0.00',
      position: Vector2(20, 40),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    camera.viewport.add(timeText);

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
    lastRecordId = null;

    overlays.remove('GameOverMenu');
    overlays.add('GameUI');

    mapArea.removeAll(mapArea.children);

    player = Player()
      ..position = Vector2(mapWidth / 2, mapHeight / 2)
      ..width = 24
      ..height = 24
      ..anchor = Anchor.center;
    mapArea.add(player);

    camera.stop();
    camera.viewfinder.visibleGameSize = Vector2(mapWidth, worldHeight);
    camera.viewfinder.position = Vector2(mapWidth / 2, worldHeight / 2);
    camera.viewfinder.anchor = Anchor.center;

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
    double tileSize = 40.0; // Matching Editor Tile Size

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
      timeText.text = 'TIME: ${survivalTime.toStringAsFixed(3)}';
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

class GameUI extends StatelessWidget {
  final ZonberGame game;
  final VoidCallback onExit;
  const GameUI({super.key, required this.game, required this.onExit});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 40,
          right: 20,
          child: IconButton(
            icon: const Icon(
              Icons.pause_circle_filled,
              color: AppColors.primary,
              size: 40,
            ),
            onPressed: () {
              game.pauseEngine();
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => NeonDialog(
                  title: "PAUSED",
                  message: "Game is paused. Resume?",
                  actions: [
                    NeonButton(
                      text: "EXIT",
                      color: AppColors.secondary,
                      onPressed: () {
                        Navigator.pop(context);
                        onExit();
                      },
                      isPrimary: false,
                    ),
                    NeonButton(
                      text: "RESUME",
                      onPressed: () {
                        Navigator.pop(context);
                        game.resumeEngine();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
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
                NeonButton(text: "SUBMIT SCORE", onPressed: _submitScore),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NeonButton(
                      text: "RETRY",
                      onPressed: widget.onRestart,
                      color: const Color(0xFF00FF88), // Green for retry
                      isPrimary: false,
                    ),
                    const SizedBox(width: 16),
                    NeonButton(
                      text: "MENU",
                      onPressed: widget.onExit,
                      color: AppColors.surface,
                      isPrimary: false,
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

class Obstacle extends PositionComponent with CollisionCallbacks {
  // Neon Crate Style Paints
  static final Paint _borderPaint = Paint()
    ..color = AppColors
        .primary // Use AppColors.primary
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..maskFilter = const MaskFilter.blur(
      BlurStyle.solid,
      3,
    ); // Reduced blur (5->3)

  static final Paint _fillPaint = Paint()
    ..color = AppColors.primary
        .withOpacity(0.1) // Reduced opacity (0.15->0.1)
    ..style = PaintingStyle.fill;

  static final Paint _detailPaint = Paint()
    ..color = AppColors.primary
        .withOpacity(0.4) // Reduced opacity
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

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
    final rect = size.toRect();

    // 1. Fill (Dark Glass look)
    canvas.drawRect(rect, _fillPaint);

    // 2. Outer Glow Border
    canvas.drawRect(rect, _borderPaint);

    // 3. Inner details (Cross brace "Crate" style)
    // Draw 'X'
    canvas.drawLine(rect.topLeft, rect.bottomRight, _detailPaint);
    canvas.drawLine(rect.topRight, rect.bottomLeft, _detailPaint);

    // Draw Inner Box
    canvas.drawRect(rect.deflate(4.0), _detailPaint);
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

class Player extends PositionComponent
    with CollisionCallbacks, HasGameRef<ZonberGame> {
  final Paint _glowPaint = Paint()
    ..color = AppColors.primary
        .withOpacity(0.4) // Reduced opacity & blur
    ..maskFilter = const MaskFilter.blur(
      BlurStyle.normal,
      10,
    ); // Reduced blur (15->10)
  final Paint _corePaint = Paint()..color = AppColors.primary;
  final double speed = 500.0; // Optimized for high sensitivity + control

  // Track Character ID for rendering
  String characterId = 'neon_green';

  @override
  Future<void> onLoad() async {
    // Reduced Player Hitbox (Radius 16 -> 12)
    add(RectangleHitbox(position: Vector2(2, 2), size: Vector2(16, 16)));

    // Load Character Skin
    final profile = await UserProfileManager.getProfile();
    characterId = profile['characterId'] ?? 'neon_green';
    Character char = CharacterData.getCharacter(characterId);

    _corePaint.color = char.color;
    _glowPaint.color = char.color.withOpacity(0.4); // Toned down glow
  }

  @override
  void render(Canvas canvas) {
    // 4 Distinct Character Designs based on ID
    if (characterId == 'neon_green') {
      // 1. NEON GREEN: Standard Square Box (Classic)
      canvas.drawRect(size.toRect(), _glowPaint);
      canvas.drawRect(size.toRect(), _corePaint);
    } else if (characterId == 'electric_blue') {
      // 2. ELECTRIC BLUE: Circle / Drone (Speed)
      double radius = size.x / 2;
      canvas.drawCircle(Offset(radius, radius), radius + 2, _glowPaint);
      canvas.drawCircle(Offset(radius, radius), radius, _corePaint);
    } else if (characterId == 'cyber_red') {
      // 3. CYBER RED: Sharp Triangle (Aggressive)
      Path path = Path();
      path.moveTo(size.x / 2, 0); // Top Center
      path.lineTo(size.x, size.y); // Bottom Right
      path.lineTo(0, size.y); // Bottom Left
      path.close();
      canvas.drawPath(path, _glowPaint);
      canvas.drawPath(path, _corePaint);
    } else if (characterId == 'plasma_purple') {
      // 4. PLASMA PURPLE: Rocket / Spaceship
      Path path = Path();
      path.moveTo(size.x / 2, 0); // Nose Tip
      path.lineTo(size.x, size.y * 0.7); // Right Wing Top
      path.lineTo(size.x, size.y); // Right Bottom
      path.lineTo(size.x / 2, size.y * 0.85); // Engine Center
      path.lineTo(0, size.y); // Left Bottom
      path.lineTo(0, size.y * 0.7); // Left Wing Top
      path.close();
      canvas.drawPath(path, _glowPaint);
      canvas.drawPath(path, _corePaint);
    } else {
      // Fallback
      canvas.drawRect(size.toRect(), _corePaint);
    }
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
        HapticFeedback.heavyImpact(); // Heavy vibration on death
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
