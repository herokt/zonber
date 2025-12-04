import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // 파이어베이스 코어
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/collisions.dart';
import 'ranking_system.dart';
import 'editor_game.dart';

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
  String _currentPage = 'Menu'; // Menu, Game, Editor

  void _navigateTo(String page) {
    setState(() {
      _currentPage = page;
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
          game: ZonberGame(),
          overlayBuilderMap: {
            'GameOverMenu': (context, ZonberGame game) =>
                GameOverWidget(game: game),
            'LeaderboardMenu': (context, ZonberGame game) =>
                LeaderboardWidget(game: game),
          },
        );
      case 'Editor':
        return GameWidget(
          game: MapEditorGame(),
          overlayBuilderMap: {
            'EditorUI': (context, MapEditorGame game) =>
                EditorUI(game: game, onExit: () => _navigateTo('Menu')),
          },
          initialActiveOverlays: const ['EditorUI'],
        );
      case 'Menu':
      default:
        return MainMenu(
          onStartGame: () => _navigateTo('Game'),
          onOpenEditor: () => _navigateTo('Editor'),
        );
    }
  }
}

class MainMenu extends StatelessWidget {
  final VoidCallback onStartGame;
  final VoidCallback onOpenEditor;

  const MainMenu({
    Key? key,
    required this.onStartGame,
    required this.onOpenEditor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0C10),
      child: Center(
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
  static const double mapWidth = 2000.0;
  static const double mapHeight = 2000.0;

  late Player player;
  late BulletSpawner spawner;

  // UI 컴포넌트
  late TextComponent timeText;

  double survivalTime = 0.0;
  bool isGameOver = false;

  @override
  Color backgroundColor() => const Color(0xFF0B0C10);

  @override
  Future<void> onLoad() async {
    // 플레이어
    player = Player()
      ..position = Vector2(mapWidth / 2, mapHeight / 2)
      ..width = 32
      ..height = 32
      ..anchor = Anchor.center;
    world.add(player);

    // 카메라
    camera.viewfinder.anchor = Anchor.center;
    camera.follow(player);

    // 배경
    world.add(GridBackground());

    // 시간 표시 텍스트
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

    // 오버레이(UI) 끄기
    overlays.remove('GameOverMenu');
    overlays.remove('LeaderboardMenu');

    // 게임 재개
    resumeEngine();

    // 초기화
    world.children.whereType<Bullet>().forEach((b) => b.removeFromParent());
    if (player.isRemoved) world.add(player);
    player.position = Vector2(mapWidth / 2, mapHeight / 2);

    if (world.children.whereType<BulletSpawner>().isEmpty) {
      spawner = BulletSpawner();
      world.add(spawner);
    }
  }

  void gameOver() {
    if (isGameOver) return;
    isGameOver = true;

    // 게임 일시정지 후 UI(메뉴) 띄우기
    pauseEngine();
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

// ====================================================
// [UI] 1. 게임 오버 위젯 (닉네임 입력)
// ====================================================
class GameOverWidget extends StatefulWidget {
  final ZonberGame game;
  const GameOverWidget({Key? key, required this.game}) : super(key: key);

  @override
  State<GameOverWidget> createState() => _GameOverWidgetState();
}

class _GameOverWidgetState extends State<GameOverWidget> {
  final TextEditingController _nameController = TextEditingController();
  final RankingSystem _rankingSystem = RankingSystem();
  bool _isSaving = false;

  void _submitScore() async {
    if (_nameController.text.isEmpty) return;
    setState(() => _isSaving = true);

    // 파이어베이스에 저장
    await _rankingSystem.saveRecord(
      _nameController.text,
      widget.game.survivalTime,
    );

    if (!mounted) return;
    // 저장 끝나면 랭킹판으로 이동
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
          border: Border.all(
            color: const Color(0xFFF21D1D),
            width: 3,
          ), // Neon Red
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
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '이니셜 입력 (3글자)',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF45A29E)),
                ),
              ),
              maxLength: 8,
            ),
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
          ],
        ),
      ),
    );
  }
}

// ====================================================
// [UI] 2. 리더보드 위젯 (순위표)
// ====================================================
class LeaderboardWidget extends StatelessWidget {
  final ZonberGame game;
  const LeaderboardWidget({Key? key, required this.game}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 320,
        height: 500,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0C10).withOpacity(0.9),
          border: Border.all(
            color: const Color(0xFF45A29E),
            width: 3,
          ), // Neon Cyan
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
                future: RankingSystem().getTopRecords(),
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
                      return ListTile(
                        leading: Text(
                          "#${index + 1}",
                          style: const TextStyle(
                            color: Color(0xFFF21D1D),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        title: Text(
                          data['nickname'] ?? 'Unknown',
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: Text(
                          "${data['survivalTime'].toStringAsFixed(2)}s",
                          style: const TextStyle(
                            color: Color(0xFF45A29E),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF21D1D),
              ),
              onPressed: () => game.startGame(),
              child: const Text(
                "새 게임 시작",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 게임 오브젝트 (플레이어, 총알, 그리드) - 기존과 동일
// ==========================================
class GridBackground extends Component {
  final Paint _linePaint = Paint()
    ..color = const Color(0xFF1F2833).withOpacity(0.5)
    ..strokeWidth = 2;
  @override
  void render(Canvas canvas) {
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
}

class Bullet extends PositionComponent with HasGameRef<ZonberGame> {
  Vector2 velocity = Vector2.zero();
  final double speed = 500.0;
  static final Paint _bulletGlow = Paint()
    ..color = const Color(0xFFF21D1D).withOpacity(0.8)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
  static final Paint _bulletCore = Paint()..color = const Color(0xFFF21D1D);
  Bullet(Vector2 position, Vector2 targetPosition) {
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
}

class BulletSpawner extends Component with HasGameRef<ZonberGame> {
  late Timer _timer;
  final Random _random = Random();
  BulletSpawner() {
    _timer = Timer(0.04, onTick: _spawnBullet, repeat: true);
  }
  @override
  void onMount() {
    super.onMount();
    _timer.start();
  }

  @override
  void update(double dt) {
    _timer.update(dt);
  }

  void _spawnBullet() {
    if (gameRef.isGameOver) return;
    if (gameRef.world.children.whereType<Player>().isEmpty) return;
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
    gameRef.world.add(Bullet(spawnPos, targetPos));
  }
}
