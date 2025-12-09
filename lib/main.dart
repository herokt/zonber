import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // 파이어베이스 코어
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/collisions.dart';
import 'ranking_system.dart';
import 'editor_game.dart';
import 'user_profile.dart';
import 'map_selection_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ZonberApp());
}

class ZonberApp extends StatefulWidget {
  const ZonberApp({Key? key}) : super(key: key);

  @override
  State<ZonberApp> createState() => _ZonberAppState();
}

class _ZonberAppState extends State<ZonberApp> {
  String _currentPage =
      'Loading'; // Menu, MapSelect, Game, Editor, Profile, Loading
  String _currentMapId = 'zone_1_classic'; // Default Map

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Scaffold(body: _buildPage()));
  }

  Widget _buildPage() {
    switch (_currentPage) {
      case 'Game':
        return GameWidget(
          game: ZonberGame(
            mapId: _currentMapId,
            onExit: () => _navigateTo('Menu'),
          ),
          overlayBuilderMap: {
            'GameOverMenu': (context, ZonberGame game) =>
                GameOverWidget(game: game),
            'LeaderboardMenu': (context, ZonberGame game) => LeaderboardWidget(
              game: game,
              highlightRecordId: game.lastRecordId,
            ),
            'GameUI': (context, ZonberGame game) =>
                GameUI(game: game, onExit: () => _navigateTo('Menu')),
          },
          initialActiveOverlays: const ['GameUI'],
        );
      case 'Profile':
        return UserProfilePage(onComplete: () => _navigateTo('Menu'));
      case 'Editor':
        return GameWidget(
          game: MapEditorGame(),
          overlayBuilderMap: {
            'EditorUI': (context, MapEditorGame game) =>
                EditorUI(game: game, onExit: () => _navigateTo('Menu')),
          },
          initialActiveOverlays: const ['EditorUI'],
        );
      case 'MapSelect':
        return MapSelectionPage(
          onMapSelected: (mapId) => _navigateTo('Game', mapId: mapId),
          onBack: () => _navigateTo('Menu'),
        );
      case 'Menu':
      default:
        return MainMenu(
          onStartGame: () => _navigateTo('MapSelect'),
          onOpenEditor: () => _navigateTo('Editor'),
          onProfile: () => _navigateTo('Profile'),
        );
    }
  }
}

class MainMenu extends StatelessWidget {
  final VoidCallback onStartGame;
  final VoidCallback onOpenEditor;
  final VoidCallback onProfile;

  const MainMenu({
    Key? key,
    required this.onStartGame,
    required this.onOpenEditor,
    required this.onProfile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0C10),
      child: Stack(
        children: [
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.person, color: Colors.white, size: 30),
              onPressed: onProfile,
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "ZONBER",
                  style: TextStyle(
                    color: Color(0xFF45A29E),
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 50),
                _buildMenuButton(
                  "START GAME",
                  const Color(0xFFF21D1D),
                  onStartGame,
                ),
                const SizedBox(height: 20),
                _buildMenuButton(
                  "MAP EDITOR",
                  const Color(0xFF45A29E),
                  onOpenEditor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(String text, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: 200,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class ZonberGame extends FlameGame with PanDetector, HasCollisionDetection {
  final String mapId;
  final VoidCallback onExit;
  ZonberGame({required this.mapId, required this.onExit});

  static const double mapWidth = 480.0;
  static const double mapHeight = 800.0;

  late Player player;
  late BulletSpawner spawner;
  late MapArea mapArea;

  // UI 컴포넌트
  late TextComponent timeText;

  double survivalTime = 0.0;
  bool isGameOver = false;
  String? lastRecordId; // 마지막 저장된 기록 ID

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

    startGame();
  }

  void startGame() {
    isGameOver = false;
    survivalTime = 0.0;
    lastRecordId = null;

    overlays.remove('GameOverMenu');
    overlays.remove('LeaderboardMenu');
    overlays.add('GameUI');

    mapArea.removeAll(mapArea.children);

    player = Player()
      ..position = Vector2(mapWidth / 2, mapHeight / 2)
      ..width = 32
      ..height = 32
      ..anchor = Anchor.center;
    mapArea.add(player);

    camera.stop();
    camera.viewfinder.visibleGameSize = Vector2(mapWidth, mapHeight);
    camera.viewfinder.position = Vector2(mapWidth / 2, mapHeight / 2);
    camera.viewfinder.anchor = Anchor.center;

    spawner = BulletSpawner();
    mapArea.add(spawner);

    if (mapId == 'zone_3_obstacles') {
      _spawnObstacles();
    }

    resumeEngine();
  }

  void _spawnObstacles() {
    final r = Random();
    for (int i = 0; i < 5; i++) {
      double w = 50 + r.nextDouble() * 100;
      double h = 50 + r.nextDouble() * 100;
      double x = r.nextDouble() * (mapWidth - w);
      double y = r.nextDouble() * (mapHeight - h);

      if ((x - mapWidth / 2).abs() < 100 && (y - mapHeight / 2).abs() < 100)
        continue;

      mapArea.add(Obstacle(Vector2(x, y), Vector2(w, h)));
    }
  }

  void gameOver() {
    if (isGameOver) return;
    isGameOver = true;

    pauseEngine();
    overlays.remove('GameUI');
    overlays.add('GameOverMenu');
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isGameOver) {
      survivalTime += dt;
      timeText.text = 'TIME: ${survivalTime.toStringAsFixed(2)}';
    }
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (!isGameOver) {
      Vector2 newPos = player.position + info.delta.global;
      newPos.x = newPos.x.clamp(0, mapWidth);
      newPos.y = newPos.y.clamp(0, mapHeight);
      player.position = newPos;
    }
  }
}

class GameUI extends StatelessWidget {
  final ZonberGame game;
  final VoidCallback onExit;
  const GameUI({Key? key, required this.game, required this.onExit})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 40,
          right: 20,
          child: IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white, size: 30),
            onPressed: () {
              game.pauseEngine();
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1F2833),
                  title: const Text(
                    "PAUSE",
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    "게임을 종료하고 나가시겠습니까?",
                    style: TextStyle(color: Colors.grey),
                  ),
                  actions: [
                    TextButton(
                      child: const Text(
                        "계속하기",
                        style: TextStyle(color: Color(0xFF45A29E)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        game.resumeEngine();
                      },
                    ),
                    TextButton(
                      child: const Text(
                        "나가기",
                        style: TextStyle(color: Color(0xFFF21D1D)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        onExit();
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

class GameOverWidget extends StatefulWidget {
  final ZonberGame game;
  const GameOverWidget({Key? key, required this.game}) : super(key: key);

  @override
  State<GameOverWidget> createState() => _GameOverWidgetState();
}

class _GameOverWidgetState extends State<GameOverWidget> {
  final RankingSystem _rankingSystem = RankingSystem();
  bool _isSaving = false;

  void _submitScore() async {
    setState(() => _isSaving = true);

    final profile = await UserProfileManager.getProfile();
    final nickname = profile['nickname']!;
    final flag = profile['flag']!;

    String recordId = await _rankingSystem.saveRecord(
      widget.game.mapId,
      nickname,
      flag,
      widget.game.survivalTime,
    );
    widget.game.lastRecordId = recordId;

    if (!mounted) return;
    widget.game.overlays.remove('GameOverMenu');
    widget.game.overlays.add('LeaderboardMenu');
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          border: Border.all(color: const Color(0xFFF21D1D), width: 3),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "GAME OVER",
              style: TextStyle(
                color: Color(0xFFF21D1D),
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "기록: ${widget.game.survivalTime.toStringAsFixed(2)}초",
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 20),
            const Text("기록을 저장하시겠습니까?", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            _isSaving
                ? const CircularProgressIndicator(color: Color(0xFF45A29E))
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF45A29E),
                    ),
                    onPressed: _submitScore,
                    child: const Text(
                      "랭킹 등록",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            TextButton(
              onPressed: () => widget.game.startGame(),
              child: const Text("다시 하기", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => widget.game.onExit(),
              child: const Text("나가기", style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}

class LeaderboardWidget extends StatelessWidget {
  final ZonberGame game;
  final String? highlightRecordId;
  const LeaderboardWidget({
    Key? key,
    required this.game,
    this.highlightRecordId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 320,
        height: 500,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0C10).withOpacity(0.9),
          border: Border.all(color: const Color(0xFF45A29E), width: 3),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            const Text(
              "TOP 10 RANKING",
              style: TextStyle(
                color: Color(0xFF45A29E),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(color: Colors.grey),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: RankingSystem().getTopRecords(game.mapId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF45A29E),
                      ),
                    );
                  var records = snapshot.data!;

                  if (records.isEmpty)
                    return const Center(
                      child: Text(
                        "아직 등록된 랭킹이 없습니다!",
                        style: TextStyle(color: Colors.white),
                      ),
                    );

                  return ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      var data = records[index];
                      bool isMine =
                          highlightRecordId != null &&
                          data['id'] == highlightRecordId;

                      return Container(
                        decoration: isMine
                            ? BoxDecoration(
                                color: const Color(0xFFF21D1D).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              )
                            : null,
                        child: ListTile(
                          leading: Text(
                            "#${index + 1}",
                            style: const TextStyle(
                              color: Color(0xFFF21D1D),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                data['flag'] ?? '🏳️',
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                data['nickname'] ?? 'Unknown',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                          trailing: Text(
                            "${data['survivalTime'].toStringAsFixed(2)}s",
                            style: const TextStyle(
                              color: Color(0xFF45A29E),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF21D1D),
                  ),
                  onPressed: () => game.startGame(),
                  child: const Text(
                    "재시작",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F2833),
                  ),
                  onPressed: () => game.onExit(),
                  child: const Text(
                    "나가기",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MapArea extends PositionComponent {
  MapArea() : super(size: Vector2(ZonberGame.mapWidth, ZonberGame.mapHeight));

  @override
  void render(Canvas canvas) {
    canvas.clipRect(size.toRect());
    super.render(canvas);
  }
}

class Obstacle extends PositionComponent with CollisionCallbacks {
  final Paint _paint = Paint()..color = Colors.amber;

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
    canvas.drawRect(size.toRect(), _paint);
  }
}

class GridBackground extends Component {
  final Paint _linePaint = Paint()
    ..color = const Color(0xFF1F2833).withOpacity(0.5)
    ..strokeWidth = 2;
  final Paint _borderPaint = Paint()
    ..color = const Color(0xFF45A29E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4;

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, ZonberGame.mapWidth, ZonberGame.mapHeight),
      _borderPaint,
    );
    for (double x = 0; x <= ZonberGame.mapWidth; x += 100) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, ZonberGame.mapHeight),
        _linePaint,
      );
    }
    for (double y = 0; y <= ZonberGame.mapHeight; y += 100) {
      canvas.drawLine(Offset(0, y), Offset(ZonberGame.mapWidth, y), _linePaint);
    }
  }
}

class Player extends PositionComponent
    with CollisionCallbacks, HasGameRef<ZonberGame> {
  final Paint _glowPaint = Paint()
    ..color = const Color(0xFF45A29E).withOpacity(0.6)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
  final Paint _corePaint = Paint()..color = const Color(0xFF45A29E);

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(position: Vector2(4, 4), size: Vector2(24, 24)));
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), _glowPaint);
    canvas.drawRect(size.toRect(), _corePaint);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Bullet) {
      gameRef.gameOver();
      removeFromParent();
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is Obstacle) {
      if (intersectionPoints.isNotEmpty) {
        // 충돌 해결: 플레이어를 밀어냄 (장애물 안으로 진입 불가)
        // 충돌 직전 위치로 되돌리거나, 깊이만큼 밀어내야 함.
        // 여기선 간단하게 중심 차이 벡터 방향으로 밀어냄.

        // final collisionPoint = intersectionPoints.first; // Unused
        final center = absolutePosition + size / 2;
        final otherCenter = other.absolutePosition + other.size / 2;

        // AABB 충돌 면 판별 (간단 버전)
        Vector2 diff = center - otherCenter;

        // X, Y 중 어디가 더 깊게 겹쳤는지 확인 대신 단순히 방향 밀기
        // (정교한 물리 엔진이 아니라서 단순 분리)
        if (diff.isZero()) diff = Vector2(1, 0);
        position += diff.normalized() * 5;
      }
    }
  }
}

class Bullet extends PositionComponent
    with HasGameRef<ZonberGame>, CollisionCallbacks {
  Vector2 velocity = Vector2.zero();
  final double speed;
  static final Paint _bulletGlow = Paint()
    ..color = const Color(0xFFF21D1D).withOpacity(0.8)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
  static final Paint _bulletCore = Paint()..color = const Color(0xFFF21D1D);

  Bullet(Vector2 position, Vector2 targetPosition, {this.speed = 200.0}) {
    this.position = position;
    size = Vector2(8, 8);
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
    super.update(dt);
    position += velocity * dt;
    if (position.x < -200 ||
        position.x > ZonberGame.mapWidth + 200 ||
        position.y < -200 ||
        position.y > ZonberGame.mapHeight + 200)
      removeFromParent();
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
    if (other is Obstacle) {
      // 튕겨나가기 (Ricochet)
      if (intersectionPoints.isNotEmpty) {
        // 충돌 면 법선 벡터(Normal) 구하기
        // AABB 기준: 중심 좌표 차이를 이용해 X축 충돌인지 Y축 충돌인지 판별
        Vector2 myCenter = absolutePosition + size / 2;
        Vector2 otherCenter = other.absolutePosition + other.size / 2;
        Vector2 delta = myCenter - otherCenter;

        // 상대 크기로 정규화하여 어느 축이 더 많이 겹쳤는지(충돌했는지) 판단
        double dx = delta.x / (other.size.x / 2);
        double dy = delta.y / (other.size.y / 2);

        if (dx.abs() > dy.abs()) {
          // X축(좌우) 충돌 -> X 속도 반전
          velocity.x = -velocity.x;
          // 충돌 깊이 해소 (살짝 밀어줌)
          position.x += (dx > 0 ? 1 : -1) * 2;
        } else {
          // Y축(상하) 충돌 -> Y 속도 반전
          velocity.y = -velocity.y;
          position.y += (dy > 0 ? 1 : -1) * 2;
        }
      }
    }
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
    if (gameRef.mapArea.children.whereType<Player>().isEmpty) return;
    Vector2 playerPos = gameRef.player.position;

    double range = 600.0;
    double angle = _random.nextDouble() * 2 * pi;
    Vector2 spawnPos = playerPos + Vector2(cos(angle), sin(angle)) * range;
    Vector2 targetPos =
        playerPos +
        Vector2(
          (_random.nextDouble() - 0.5) * 100,
          (_random.nextDouble() - 0.5) * 100,
        );

    double bulletSpeed = gameRef.mapId == 'zone_2_hard' ? 300.0 : 200.0;
    gameRef.mapArea.add(Bullet(spawnPos, targetPos, speed: bulletSpeed));
  }
}
