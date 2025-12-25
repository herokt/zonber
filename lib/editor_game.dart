import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'map_service.dart';
import 'user_profile.dart';
import 'design_system.dart';

class MapEditorGame extends FlameGame with PanDetector, TapDetector {
  // Grid settings (Matches Game Aspect Ratio 480:720 -> 15:24 blocks of 32px)
  static const int gridSizeX = 15; // Odd number for center alignment
  static const int gridSizeY = 24; // More grids
  static const double tileSize = 32.0; // Scaled down to fit
  static const double mapWidth = gridSizeX * tileSize; // 480.0
  static const double mapHeight = gridSizeY * tileSize; // 768.0

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
    // Camera setup: Matches ZonberGame
    camera.viewfinder.visibleGameSize = Vector2(mapWidth, mapHeight);
    // Shift map down by 100px (Reduced from 120px to close gap)
    camera.viewfinder.position = Vector2(mapWidth / 2, mapHeight / 2 - 100);
    camera.viewfinder.anchor = Anchor.center;

    // Add Grid Rendering
    world.add(EditorGrid(this));
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    // Restrict to Vertical Scrolling (Y-axis only)
    // Moving finger UP (negative delta) means Camera moves UP (negative Viewfinder delta)
    // Wait. If I drag UP, I want to see content BELOW. So World moves UP.
    // If World moves UP, Camera should move DOWN (Positive Y).
    // info.delta.global is Screen Delta.
    // Drag Up -> Delta Y is Negative.
    // If Camera Pos -= Delta Y (-neg) = += Pos. Camera moves Down. World moves Up. Correct.
    camera.viewfinder.position = Vector2(
      camera.viewfinder.position.x,
      camera.viewfinder.position.y - info.delta.global.y,
    );
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
    // 1. Center Restriction (Spawn Area)
    // Grid 15x24. Center X = 7. Center Y = 11-12.
    // Reserve 3x3 area: x in [6,8], y in [10,12]
    if (x >= 6 && x <= 8 && y >= 11 && y <= 13) return true;

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
    return SafeArea(
      child: Column(
        children: [
          // 1. App Bar (Standardized)
          NeonAppBar(
            title: "MAP EDITOR",
            showBackButton: true,
            onBack: widget.onExit,
          ),

          // 2. Toolbar (Tools & Actions)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background.withOpacity(0.8),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.primaryDim.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: NeonButton(
                    text: "CLEAR",
                    isCompact: true,
                    color: AppColors.textDim,
                    onPressed: () => setState(() => widget.game.clearMap()),
                    isPrimary: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NeonButton(
                    text: "LOAD",
                    isCompact: true,
                    color: Colors.orange,
                    onPressed: _showLoadDialog,
                    isPrimary: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NeonButton(
                    text: "SAVE",
                    isCompact: true,
                    color: Colors.blueAccent,
                    onPressed: _showSaveDialog,
                    isPrimary: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NeonButton(
                    text: "VERIFY",
                    isCompact: true,
                    onPressed: _showVerifyDialog,
                  ),
                ),
              ],
            ),
          ),

          // Bottom Instructions removed
        ],
      ),
    );
  }

  void _showVerifyDialog() {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => NeonDialog(
        title: "VERIFY & UPLOAD",
        message: "To upload a map, you must survive 30 seconds on it.",
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
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        actions: [
          NeonButton(
            text: "CANCEL",
            color: AppColors.surface,
            isPrimary: false,
            onPressed: () => Navigator.pop(context),
          ),
          NeonButton(
            text: "START TEST",
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
      barrierDismissible: true,
      builder: (context) {
        // Use StatefulBuilder to allow refreshing list inside Dialog
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: NeonCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("LOAD MAP", style: AppTextStyles.header),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.maxFinite,
                      height: 300,
                      child: maps.isEmpty
                          ? const Center(
                              child: Text(
                                "No maps found",
                                style: AppTextStyles.body,
                              ),
                            )
                          : ListView.separated(
                              itemCount: maps.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final map = maps[index];
                                bool isMine = map['author'] == currentNickname;

                                return Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceGlass,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isMine
                                          ? AppColors.primary.withOpacity(0.3)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      map['name'] ?? 'Untitled',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "by ${map['author'] ?? 'Unknown'}",
                                      style: const TextStyle(
                                        color: AppColors.textDim,
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: isMine
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: AppColors.secondary,
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
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    NeonButton(
                      text: "CANCEL",
                      color: AppColors.surface,
                      isPrimary: false,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(
    String mapId,
    String? mapName, // Re-included logic from context
    List<Map<String, dynamic>> maps,
    StateSetter setStateDialog,
  ) {
    showDialog(
      context: context,
      builder: (context) => NeonDialog(
        title: "DELETE MAP",
        titleColor: AppColors.secondary,
        message: "Are you sure you want to delete '$mapName'?",
        actions: [
          NeonButton(
            text: "CANCEL",
            color: AppColors.surface,
            isPrimary: false,
            onPressed: () => Navigator.pop(context),
          ),
          NeonButton(
            text: "DELETE",
            color: AppColors.secondary,
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
      barrierDismissible: false,
      builder: (context) => NeonDialog(
        title: "SAVE MAP",
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
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        actions: [
          NeonButton(
            text: "CANCEL",
            color: AppColors.surface,
            isPrimary: false,
            onPressed: () => Navigator.pop(context),
          ),
          NeonButton(
            text: "SAVE",
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
