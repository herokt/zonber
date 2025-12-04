import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

class MapEditorGame extends FlameGame with PanDetector, TapDetector {
  // Grid settings
  static const int gridSize = 20;
  static const double tileSize = 100.0;
  static const double mapWidth = gridSize * tileSize;
  static const double mapHeight = gridSize * tileSize;

  // Map Data: 0 = Empty, 1 = Wall
  List<List<int>> mapData = List.generate(
    gridSize,
    (_) => List.filled(gridSize, 0),
  );

  // Camera control
  bool isEditMode = true; // true = Draw, false = Pan

  @override
  Color backgroundColor() => const Color(0xFF0B0C10);

  @override
  Future<void> onLoad() async {
    // Camera setup
    camera.viewfinder.anchor = Anchor.topLeft;

    // Add Grid Rendering
    world.add(EditorGrid(this));
  }

  @override
  void onTapDown(TapDownInfo info) {
    if (isEditMode) {
      // Convert screen coordinates to world coordinates
      final Vector2 localPos = camera.globalToLocal(info.eventPosition.global);

      // Calculate grid index
      int x = (localPos.x / tileSize).floor();
      int y = (localPos.y / tileSize).floor();

      if (x >= 0 && x < gridSize && y >= 0 && y < gridSize) {
        // Toggle wall
        mapData[y][x] = mapData[y][x] == 0 ? 1 : 0;
      }
    }
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (!isEditMode) {
      // Move camera (Reverse delta to drag "the world")
      camera.viewfinder.position -= info.delta.global;
    }
  }

  void toggleMode() {
    isEditMode = !isEditMode;
  }

  void clearMap() {
    for (var row in mapData) {
      row.fillRange(0, gridSize, 0);
    }
  }
}

class EditorGrid extends Component {
  final MapEditorGame game;
  final Paint linePaint = Paint()
    ..color = Colors.white.withOpacity(0.2)
    ..strokeWidth = 1;
  final Paint wallPaint = Paint()
    ..color = const Color(0xFFF21D1D); // Neon Red for walls

  EditorGrid(this.game);

  @override
  void render(Canvas canvas) {
    // Draw Walls
    for (int y = 0; y < MapEditorGame.gridSize; y++) {
      for (int x = 0; x < MapEditorGame.gridSize; x++) {
        if (game.mapData[y][x] == 1) {
          canvas.drawRect(
            Rect.fromLTWH(
              x * MapEditorGame.tileSize,
              y * MapEditorGame.tileSize,
              MapEditorGame.tileSize,
              MapEditorGame.tileSize,
            ),
            wallPaint,
          );
        }
      }
    }

    // Draw Grid Lines
    for (
      double i = 0;
      i <= MapEditorGame.mapWidth;
      i += MapEditorGame.tileSize
    ) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, MapEditorGame.mapHeight),
        linePaint,
      );
    }
    for (
      double i = 0;
      i <= MapEditorGame.mapHeight;
      i += MapEditorGame.tileSize
    ) {
      canvas.drawLine(
        Offset(0, i),
        Offset(MapEditorGame.mapWidth, i),
        linePaint,
      );
    }
  }
}

class EditorUI extends StatefulWidget {
  final MapEditorGame game;
  final VoidCallback onExit;

  const EditorUI({Key? key, required this.game, required this.onExit})
    : super(key: key);

  @override
  State<EditorUI> createState() => _EditorUIState();
}

class _EditorUIState extends State<EditorUI> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top Toolbar
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Row(
            children: [
              _buildButton(
                text: widget.game.isEditMode ? "Mode: DRAW" : "Mode: MOVE",
                color: widget.game.isEditMode
                    ? const Color(0xFFF21D1D)
                    : const Color(0xFF45A29E),
                onPressed: () {
                  setState(() {
                    widget.game.toggleMode();
                  });
                },
              ),
              const Spacer(),
              _buildButton(
                text: "CLEAR",
                color: Colors.grey,
                onPressed: () {
                  setState(() {
                    widget.game.clearMap();
                  });
                },
              ),
              const SizedBox(width: 10),
              _buildButton(
                text: "EXIT",
                color: Colors.red,
                onPressed: widget.onExit,
              ),
            ],
          ),
        ),
        // Bottom Info
        Positioned(
          bottom: 20,
          left: 20,
          child: Container(
            padding: const EdgeInsets.all(10),
            color: Colors.black54,
            child: const Text(
              "Tap to Toggle Wall / Drag to Move Camera",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
