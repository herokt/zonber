import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'map_service.dart';
import 'user_profile.dart';
import 'design_system.dart';
import 'language_manager.dart';

class MapEditorGame extends FlameGame with TapCallbacks, DragCallbacks {
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

  // Screen size for scaling
  Vector2? _screenSize;

  // Drawing mode: true = add walls, false = erase walls
  bool isDrawMode = true;

  // Wall count callback for UI
  Function(int)? onWallCountChanged;

  int get wallCount {
    int count = 0;
    for (var row in mapData) {
      for (var cell in row) {
        if (cell == 1) count++;
      }
    }
    return count;
  }

  // Camera control
  @override
  Color backgroundColor() => const Color(0xFF0A0A0F);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _screenSize = size;
    _updateCamera();
  }

  void _updateCamera() {
    if (_screenSize == null) return;
    updateCameraForSize(_screenSize!.x, _screenSize!.y);
  }

  // Store the current visible size for coordinate calculations
  Vector2 _visibleSize = Vector2(mapWidth, mapHeight);

  /// Update camera to fit the map within given dimensions
  void updateCameraForSize(double width, double height) {
    if (width <= 0 || height <= 0) return;

    // Calculate aspect ratios
    final containerAspect = width / height;
    final mapAspect = mapWidth / mapHeight;

    double visibleWidth, visibleHeight;

    if (containerAspect > mapAspect) {
      // Container is wider than map - fit by height
      visibleHeight = mapHeight;
      visibleWidth = mapHeight * containerAspect;
    } else {
      // Container is taller than map - fit by width
      visibleWidth = mapWidth;
      visibleHeight = mapWidth / containerAspect;
    }

    _visibleSize = Vector2(visibleWidth, visibleHeight);

    camera.viewfinder.visibleGameSize = _visibleSize;
    camera.viewfinder.position = Vector2(mapWidth / 2, mapHeight / 2);
    camera.viewfinder.anchor = Anchor.center;
  }

  /// Convert screen position to map grid position
  Vector2 screenToMapPosition(Vector2 screenPos) {
    // Get the viewport size
    final viewportSize = camera.viewport.size;

    // Calculate scale from screen to visible game world
    final scaleX = _visibleSize.x / viewportSize.x;
    final scaleY = _visibleSize.y / viewportSize.y;

    // Convert screen position to visible world position (centered at camera position)
    final worldX = (screenPos.x - viewportSize.x / 2) * scaleX + mapWidth / 2;
    final worldY = (screenPos.y - viewportSize.y / 2) * scaleY + mapHeight / 2;

    return Vector2(worldX, worldY);
  }

  @override
  Future<void> onLoad() async {
    _updateCamera();
    // Add Grid Rendering
    world.add(EditorGrid(this));
  }

  void _handleTileAtWorld(Vector2 worldPosition) {
    // Calculate grid index from world position
    int x = (worldPosition.x / tileSize).floor();
    int y = (worldPosition.y / tileSize).floor();

    if (x >= 0 && x < gridSizeX && y >= 0 && y < gridSizeY) {
      // Check Restriction
      if (isRestricted(x, y)) {
        return;
      }

      // Set wall based on current mode
      int newValue = isDrawMode ? 1 : 0;
      if (mapData[y][x] != newValue) {
        mapData[y][x] = newValue;
        onWallCountChanged?.call(wallCount);
      }
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    // Convert canvas position to world coordinates using camera
    final worldPos = camera.globalToLocal(event.canvasPosition);
    _handleTileAtWorld(worldPos);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    // Convert canvas position to world coordinates using camera
    final worldPos = camera.globalToLocal(event.canvasEndPosition);
    _handleTileAtWorld(worldPos);
  }

  bool isRestricted(int x, int y) {
    // 1. Center Restriction (Spawn Area)
    // Grid 15x24. Center X = 7. Center Y = 11-12.
    // Reserve 3x3 area: x in [6,8], y in [10,12]
    if (x >= 6 && x <= 8 && y >= 11 && y <= 13) return true;

    // 2. Outer Edge restriction
    if (x == 0 || x == gridSizeX - 1 || y == 0 || y == gridSizeY - 1) {
      return true;
    }

    return false;
  }

  void clearMap() {
    for (var row in mapData) {
      row.fillRange(0, gridSizeX, 0);
    }
    onWallCountChanged?.call(0);
  }
}

class EditorGrid extends Component {
  final MapEditorGame game;

  // Grid line paints
  final Paint gridLinePaint = Paint()
    ..color = const Color(0xFF1A2030)
    ..strokeWidth = 1;

  final Paint gridLineMajorPaint = Paint()
    ..color = const Color(0xFF2A3545)
    ..strokeWidth = 1.5;

  // Map border paint
  final Paint borderPaint = Paint()
    ..color = AppColors.primary
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);

  // Wall paints
  final Paint wallFillPaint = Paint()
    ..color = AppColors.primary.withOpacity(0.4)
    ..style = PaintingStyle.fill;

  final Paint wallBorderPaint = Paint()
    ..color = AppColors.primary
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  // Restricted zone paints
  final Paint restrictedFillPaint = Paint()
    ..color = const Color(0xFFFF3366).withOpacity(0.15)
    ..style = PaintingStyle.fill;

  final Paint restrictedBorderPaint = Paint()
    ..color = const Color(0xFFFF3366).withOpacity(0.4)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  // Spawn area paint (center)
  final Paint spawnFillPaint = Paint()
    ..color = const Color(0xFF00FF88).withOpacity(0.1)
    ..style = PaintingStyle.fill;

  final Paint spawnBorderPaint = Paint()
    ..color = const Color(0xFF00FF88).withOpacity(0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  EditorGrid(this.game);

  @override
  void render(Canvas canvas) {
    final tileSize = MapEditorGame.tileSize;
    final mapWidth = MapEditorGame.mapWidth;
    final mapHeight = MapEditorGame.mapHeight;
    final gridX = MapEditorGame.gridSizeX;
    final gridY = MapEditorGame.gridSizeY;

    // 1. Draw grid background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, mapWidth, mapHeight),
      Paint()..color = const Color(0xFF0D1015),
    );

    // 2. Draw grid lines
    for (int i = 0; i <= gridX; i++) {
      double x = i * tileSize;
      bool isMajor = i % 5 == 0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, mapHeight),
        isMajor ? gridLineMajorPaint : gridLinePaint,
      );
    }
    for (int i = 0; i <= gridY; i++) {
      double y = i * tileSize;
      bool isMajor = i % 5 == 0;
      canvas.drawLine(
        Offset(0, y),
        Offset(mapWidth, y),
        isMajor ? gridLineMajorPaint : gridLinePaint,
      );
    }

    // 3. Draw outer edge restriction zone (border tiles)
    for (int y = 0; y < gridY; y++) {
      for (int x = 0; x < gridX; x++) {
        if (x == 0 || x == gridX - 1 || y == 0 || y == gridY - 1) {
          Rect rect = Rect.fromLTWH(
            x * tileSize,
            y * tileSize,
            tileSize,
            tileSize,
          );
          canvas.drawRect(rect, restrictedFillPaint);
        }
      }
    }

    // 4. Draw spawn area (center 3x3)
    Rect spawnArea = Rect.fromLTWH(
      6 * tileSize,
      11 * tileSize,
      3 * tileSize,
      3 * tileSize,
    );
    canvas.drawRect(spawnArea, spawnFillPaint);
    canvas.drawRect(spawnArea, spawnBorderPaint);

    // Draw spawn icon (player silhouette)
    final spawnCenter = Offset(7.5 * tileSize, 12.5 * tileSize);
    canvas.drawCircle(
      spawnCenter,
      8,
      Paint()..color = const Color(0xFF00FF88).withOpacity(0.6),
    );

    // 5. Draw walls
    for (int y = 0; y < gridY; y++) {
      for (int x = 0; x < gridX; x++) {
        if (game.mapData[y][x] == 1) {
          Rect rect = Rect.fromLTWH(
            x * tileSize + 1,
            y * tileSize + 1,
            tileSize - 2,
            tileSize - 2,
          );

          // Fill
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            wallFillPaint,
          );

          // Border
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            wallBorderPaint,
          );

          // Inner cross pattern
          Paint crossPaint = Paint()
            ..color = AppColors.primary.withOpacity(0.5)
            ..strokeWidth = 1;
          canvas.drawLine(
            rect.topLeft + const Offset(4, 4),
            rect.bottomRight - const Offset(4, 4),
            crossPaint,
          );
          canvas.drawLine(
            rect.topRight + const Offset(-4, 4),
            rect.bottomLeft + const Offset(4, -4),
            crossPaint,
          );
        }
      }
    }

    // 6. Draw map border with glow
    canvas.drawRect(Rect.fromLTWH(0, 0, mapWidth, mapHeight), borderPaint);
  }
}

/// Full Map Editor Page that embeds the game properly
class MapEditorPage extends StatefulWidget {
  final Function(List<List<int>> mapData, String mapName) onVerify;
  final VoidCallback onExit;

  const MapEditorPage({
    super.key,
    required this.onVerify,
    required this.onExit,
  });

  @override
  State<MapEditorPage> createState() => _MapEditorPageState();
}

class _MapEditorPageState extends State<MapEditorPage> {
  late MapEditorGame _game;
  int _wallCount = 0;

  @override
  void initState() {
    super.initState();
    _game = MapEditorGame();
    _game.onWallCountChanged = (count) {
      if (mounted) setState(() => _wallCount = count);
    };
  }

  @override
  void dispose() {
    _game.onWallCountChanged = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      title: LanguageManager.of(context).translate('map_editor'),
      showBackButton: true,
      onBack: widget.onExit,
      actions: [Center(child: _buildModeToggle())],
      // Wrap body in PopScope to intercept hardware back button locally
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          widget.onExit();
        },
        child: Column(
          children: [
            // Info Bar
            // Info Bar Removed for maximize space
            // Draw/Erase Mode moved to AppBar Actions

            // Map Area - Game Widget embedded here

            // Map Area - Game Widget embedded here
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.primaryDim.withOpacity(0.5),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Update camera when layout changes
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _game.updateCameraForSize(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                      });
                      return GameWidget(game: _game);
                    },
                  ),
                ),
              ),
            ),

            // Bottom Toolbar
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Action Buttons Row
                  Row(
                    children: [
                      Expanded(
                        child: NeonButton(
                          text: LanguageManager.of(context).translate('clear'),
                          icon: Icons.refresh,
                          isCompact: true,
                          color: AppColors.textDim,
                          isPrimary: false,
                          onPressed: () {
                            setState(() => _game.clearMap());
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: NeonButton(
                          text: LanguageManager.of(context).translate('load'),
                          icon: Icons.folder_open,
                          isCompact: true,
                          color: Colors.orange,
                          isPrimary: false,
                          onPressed: _showLoadDialog,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: NeonButton(
                          text: LanguageManager.of(context).translate('save'),
                          icon: Icons.save,
                          isCompact: true,
                          color: Colors.blueAccent,
                          isPrimary: false,
                          onPressed: _showSaveDialog,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Verify Button - Full Width
                  SizedBox(
                    width: double.infinity,
                    child: NeonButton(
                      text: LanguageManager.of(
                        context,
                      ).translate('verify_upload'),
                      icon: Icons.play_arrow,
                      onPressed: _showVerifyDialog,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryDim.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeButton(
            icon: Icons.brush,
            isActive: _game.isDrawMode,
            onTap: () => setState(() => _game.isDrawMode = true),
            activeColor: AppColors.primary,
          ),
          _buildModeButton(
            icon: Icons.delete_outline,
            isActive: !_game.isDrawMode,
            onTap: () => setState(() => _game.isDrawMode = false),
            activeColor: AppColors.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          color: isActive ? activeColor : AppColors.textDim,
          size: 20,
        ),
      ),
    );
  }

  void _showVerifyDialog() {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => NeonDialog(
        title: LanguageManager.of(context).translate('verify_upload'),
        message: LanguageManager.of(context).translate('verify_message'),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: LanguageManager.of(context).translate('enter_map_name'),
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
            text: LanguageManager.of(context).translate('cancel'),
            color: AppColors.surface,
            isPrimary: false,
            onPressed: () => Navigator.pop(context),
          ),
          NeonButton(
            text: LanguageManager.of(context).translate('start_test'),
            onPressed: () {
              String name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context); // Close dialog
              widget.onVerify(_game.mapData, name);
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

    String? selectedMapId;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: NeonCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.folder_open, color: Colors.orange, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          LanguageManager.of(context).translate('load_map'),
                          style: AppTextStyles.header.copyWith(fontSize: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Map List
                    Container(
                      height: 320,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primaryDim.withOpacity(0.3),
                        ),
                      ),
                      child: maps.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.map_outlined,
                                    color: AppColors.textDim,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    LanguageManager.of(
                                      context,
                                    ).translate('no_maps'),
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.textDim,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: maps.length,
                              itemBuilder: (context, index) {
                                final map = maps[index];
                                bool isMine = map['author'] == currentNickname;
                                bool isSelected = selectedMapId == map['id'];

                                return GestureDetector(
                                  onTap: () {
                                    setStateDialog(() {
                                      selectedMapId = map['id'];
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary.withOpacity(0.15)
                                          : AppColors.surfaceGlass,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : isMine
                                            ? AppColors.primary.withOpacity(0.3)
                                            : Colors.transparent,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Map Icon
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color:
                                                (isMine
                                                        ? AppColors.primary
                                                        : Colors.purple)
                                                    .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            isMine
                                                ? Icons.person
                                                : Icons.public,
                                            color: isMine
                                                ? AppColors.primary
                                                : Colors.purple,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Map Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                map['name'] ??
                                                    LanguageManager.of(
                                                      context,
                                                    ).translate('untitled'),
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? AppColors.primary
                                                      : Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                "${LanguageManager.of(context).translate('by')} ${map['author'] ?? LanguageManager.of(context).translate('unknown')}",
                                                style: TextStyle(
                                                  color: AppColors.textDim,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Delete Button (only for own maps)
                                        if (isMine)
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete_outline,
                                              color: AppColors.secondary,
                                              size: 20,
                                            ),
                                            onPressed: () => _confirmDelete(
                                              map['id'],
                                              map['name'],
                                              maps,
                                              setStateDialog,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: NeonButton(
                            text: LanguageManager.of(
                              context,
                            ).translate('cancel'),
                            color: AppColors.textDim,
                            isPrimary: false,
                            isCompact: true,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: NeonButton(
                            text: LanguageManager.of(context).translate('load'),
                            icon: Icons.download,
                            color: selectedMapId != null
                                ? AppColors.primary
                                : AppColors.textDim,
                            isCompact: true,
                            onPressed: selectedMapId != null
                                ? () {
                                    Navigator.pop(context);
                                    _loadMapData(selectedMapId!);
                                  }
                                : null,
                          ),
                        ),
                      ],
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
        message: "Are you sure you want to delete '\$mapName'?",
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

      // Restore to game.mapData
      for (int i = 0; i < grid.length; i++) {
        int x = i % width;
        int y = (i / width).floor();
        if (x < MapEditorGame.gridSizeX && y < MapEditorGame.gridSizeY) {
          _game.mapData[y][x] = grid[i];
        }
      }

      // Update wall count
      setState(() => _wallCount = _game.wallCount);

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
        title: LanguageManager.of(context).translate('save'),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: LanguageManager.of(context).translate('enter_map_name'),
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
            text: LanguageManager.of(context).translate('cancel'),
            color: AppColors.surface,
            isPrimary: false,
            onPressed: () => Navigator.pop(context),
          ),
          NeonButton(
            text: LanguageManager.of(context).translate('save'),
            onPressed: () async {
              String name = nameController.text.trim();
              if (name.isEmpty) return;

              if (_game.wallCount == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      LanguageManager.of(
                        context,
                      ).translate('invalid_map_message'),
                    ),
                  ),
                );
                return;
              }

              Navigator.pop(context); // Close dialog

              // Get User Info
              final profile = await UserProfileManager.getProfile();
              String author = profile['nickname']!;

              // Save Map
              bool success = await MapService().saveCustomMap(
                name: name,
                author: author,
                gridData: _game.mapData,
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
