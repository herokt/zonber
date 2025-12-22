import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'map_service.dart';
import 'user_profile.dart';

class MapEditorGame extends FlameGame with PanDetector, TapDetector {
  // Grid settings (Matches Game Aspect Ratio 480:720 -> 12:18 blocks of 40px)
  static const int gridSizeX = 12;
  static const int gridSizeY = 18;
  static const double tileSize = 40.0;
  static const double mapWidth = gridSizeX * tileSize;
  static const double mapHeight = gridSizeY * tileSize;

  // Map Data: 0 = Empty, 1 = Wall
  List<List<int>> mapData = List.generate(
    gridSizeY,
    (_) => List.filled(gridSizeX, 0),
  );

  // Camera control
  @override
  Color backgroundColor() => const Color(0xFF0B0C10);

  @override
  Future<void> onLoad() async {
    // Camera setup: Matches ZonberGame exactly
    camera.viewfinder.visibleGameSize = Vector2(mapWidth, mapHeight);
    camera.viewfinder.position = Vector2(mapWidth / 2, mapHeight / 2);
    camera.viewfinder.anchor = Anchor.center;

    // Add Grid Rendering
    world.add(EditorGrid(this));
  }

  @override
  void onTapDown(TapDownInfo info) {
    // Always Draw Mode
    // Convert screen coordinates to world coordinates
    final Vector2 localPos = camera.globalToLocal(info.eventPosition.global);

    // Calculate grid index
    int x = (localPos.x / tileSize).floor();
    int y = (localPos.y / tileSize).floor();

    if (x >= 0 && x < gridSizeX && y >= 0 && y < gridSizeY) {
      // Check Restriction
      if (isRestricted(x, y)) {
        // Show visual feedback potentially, or just ignore
        return;
      }
      // Toggle wall
      mapData[y][x] = mapData[y][x] == 0 ? 1 : 0;
    }
  }

  // PanDetector removed (Fixed Camera)

  bool isRestricted(int x, int y) {
    // 1. Center 4x4 (160x160)
    // Grid 12x18.
    // Center logic x in [4,7], y in [7,10]
    if (x >= 4 && x <= 7 && y >= 7 && y <= 10) return true;

    // 2. Outer Edge restriction
    if (x == 0 || x == gridSizeX - 1 || y == 0 || y == gridSizeY - 1)
      return true;

    return false;
  }

  void clearMap() {
    for (var row in mapData) {
      row.fillRange(0, gridSizeX, 0);
    }
  }
}

class EditorGrid extends Component {
  final MapEditorGame game;
  final Paint linePaint = Paint()
    ..color = Colors.white.withOpacity(0.2)
    ..strokeWidth = 1;
  final Paint wallBorderPaint = Paint()
    ..color = const Color(0xFF00E5FF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  final Paint wallFillPaint = Paint()
    ..color = const Color(0xFF00E5FF).withOpacity(0.3)
    ..style = PaintingStyle.fill;

  EditorGrid(this.game);

  final Paint restrictedPaint = Paint()
    ..color = const Color(0xFFF21D1D)
        .withOpacity(0.2) // Red tint for restricted
    ..style = PaintingStyle.fill;

  @override
  void render(Canvas canvas) {
    // Draw Restricted Zones
    for (int y = 0; y < MapEditorGame.gridSizeY; y++) {
      for (int x = 0; x < MapEditorGame.gridSizeX; x++) {
        if (game.isRestricted(x, y)) {
          canvas.drawRect(
            Rect.fromLTWH(
              x * MapEditorGame.tileSize,
              y * MapEditorGame.tileSize,
              MapEditorGame.tileSize,
              MapEditorGame.tileSize,
            ),
            restrictedPaint,
          );
        }
      }
    }

    // Draw Walls
    for (int y = 0; y < MapEditorGame.gridSizeY; y++) {
      for (int x = 0; x < MapEditorGame.gridSizeX; x++) {
        if (game.mapData[y][x] == 1) {
          Rect rect = Rect.fromLTWH(
            x * MapEditorGame.tileSize,
            y * MapEditorGame.tileSize,
            MapEditorGame.tileSize,
            MapEditorGame.tileSize,
          );

          canvas.drawRect(rect, wallFillPaint);
          canvas.drawRect(rect, wallBorderPaint);
          // Simple X for editor
          canvas.drawLine(rect.topLeft, rect.bottomRight, wallBorderPaint);
          canvas.drawLine(rect.topRight, rect.bottomLeft, wallBorderPaint);
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
  final Function(List<List<int>> mapData, String mapName) onVerify;
  final VoidCallback onExit;

  const EditorUI({
    super.key,
    required this.game,
    required this.onVerify,
    required this.onExit,
  });

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
          top: 40,
          left: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2833).withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8, // gap between adjacent chips
              runSpacing: 8, // gap between lines
              children: [
                // Removed DRAW/MOVE button as requested
                _buildCompactButton(
                  icon: Icons.refresh,
                  text: "CLEAR",
                  color: Colors.grey,
                  onPressed: () => setState(() => widget.game.clearMap()),
                ),
                _buildCompactButton(
                  icon: Icons.file_upload,
                  text: "LOAD",
                  color: Colors.orangeAccent,
                  onPressed: _showLoadDialog,
                ),
                _buildCompactButton(
                  icon: Icons.check_circle,
                  text: "VERIFY",
                  color: Colors.greenAccent,
                  onPressed: _showVerifyDialog,
                ),
                _buildCompactButton(
                  icon: Icons.save,
                  text: "SAVE",
                  color: Colors.blueAccent,
                  onPressed: _showSaveDialog,
                ),
                _buildCompactButton(
                  icon: Icons.exit_to_app,
                  text: "EXIT",
                  color: Colors.red,
                  onPressed: widget.onExit,
                ),
              ],
            ),
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
              "Tap grids to build walls",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactButton({
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(height: 2),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showVerifyDialog() {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2833),
        title: const Text(
          "VERIFY & UPLOAD",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "To upload a map, you must survive 30 seconds on it.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Enter Map Name",
                hintStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF45A29E)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text(
              "START TEST",
              style: TextStyle(color: Color(0xFF45A29E)),
            ),
            onPressed: () {
              String name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context); // Close dialog
              widget.onVerify(widget.game.mapData, name);
            },
          ),
        ],
      ),
    );
  }

  void _showLoadDialog() async {
    // Get Current User
    final profile = await UserProfileManager.getProfile();
    final String currentNickname = profile['nickname'] ?? '';

    // Fetch maps
    var maps = await MapService().getCustomMaps();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        // Use StatefulBuilder to allow refreshing list inside Dialog
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1F2833),
              title: const Text(
                "LOAD MAP",
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: maps.isEmpty
                    ? const Center(
                        child: Text(
                          "No maps found",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: maps.length,
                        itemBuilder: (context, index) {
                          final map = maps[index];
                          bool isMine = map['author'] == currentNickname;

                          return ListTile(
                            title: Text(
                              map['name'] ?? 'Untitled',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              map['author'] ?? 'Unknown',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            trailing: isMine
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _confirmDelete(
                                      map['id'],
                                      map['name'],
                                      maps,
                                      setStateDialog,
                                    ),
                                  )
                                : null,
                            onTap: () async {
                              Navigator.pop(context);
                              _loadMapData(map['id']);
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  child: const Text(
                    "CANCEL",
                    style: TextStyle(color: Colors.grey),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(
    String mapId,
    String? mapName,
    List<Map<String, dynamic>> maps,
    StateSetter setStateDialog,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2833),
        title: const Text("DELETE MAP", style: TextStyle(color: Colors.white)),
        content: Text(
          "Are you sure you want to delete '$mapName'?",
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
            onPressed: () async {
              Navigator.pop(context); // Close confirm dialog

              bool success = await MapService().deleteCustomMap(mapId);
              if (success) {
                // Refresh List
                setStateDialog(() {
                  maps.removeWhere((m) => m['id'] == mapId);
                });

                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("Map Deleted")));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _loadMapData(String mapId) async {
    var mapData = await MapService().getMap(mapId);
    if (mapData != null) {
      List<dynamic> grid = mapData['grid'];
      int width = mapData['width'];
      // int height = mapData['height'];

      // Restore to game.mapData
      for (int i = 0; i < grid.length; i++) {
        int x = i % width;
        int y = (i / width).floor();
        if (x < MapEditorGame.gridSizeX && y < MapEditorGame.gridSizeY) {
          widget.game.mapData[y][x] = grid[i];
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Map Loaded!"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showSaveDialog() {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2833),
        title: const Text("SAVE MAP", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Enter Map Name",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF45A29E)),
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text(
              "SAVE",
              style: TextStyle(color: Color(0xFF45A29E)),
            ),
            onPressed: () async {
              String name = nameController.text.trim();
              if (name.isEmpty) return;

              Navigator.pop(context); // Close dialog

              // Get User Info
              final profile = await UserProfileManager.getProfile();
              String author = profile['nickname']!;

              // Save Map
              bool success = await MapService().saveCustomMap(
                name: name,
                author: author,
                gridData: widget.game.mapData,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? "Map Saved!" : "Failed to save map",
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
