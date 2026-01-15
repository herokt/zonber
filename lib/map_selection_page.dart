import 'package:flutter/material.dart';
import 'dart:math'; // For random in preview
import 'maze_generator.dart'; // Import MazeGenerator for accurate preview
import 'design_system.dart';
import 'language_manager.dart';
import 'ranking_system.dart';

class MapSelectionPage extends StatefulWidget {
  final Function(String mapId) onMapSelected;
  final Function(BuildContext context, String mapId) onShowRanking;
  final VoidCallback onBack;
  final String? initialMapId; // Added for scroll preservation

  const MapSelectionPage({
    super.key,
    required this.onMapSelected,
    required this.onShowRanking,
    required this.onBack,
    this.initialMapId,
  });

  @override
  State<MapSelectionPage> createState() => _MapSelectionPageState();
}

class _MapSelectionPageState extends State<MapSelectionPage> {
  final ScrollController _scrollController = ScrollController();
  Map<String, int> _playCounts = {};

  @override
  void initState() {
    super.initState();
    _loadPlayCounts();

    // Scroll to initial map if provided
    if (widget.initialMapId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToMap(widget.initialMapId!);
      });
    }
  }

  Future<void> _loadPlayCounts() async {
    final counts = await RankingSystem().getGlobalPlayCounts();
    if (mounted) {
      setState(() {
        _playCounts = counts;
      });
    }
  }

  void _scrollToMap(String mapId) {
    // Estimated item height (Card + Spacing)
    // Card content height ~150 + Padding 20 = ~170?
    // Let's approximate based on fixed list.
    double itemHeight = 200.0;
    int index = 0;

    switch (mapId) {
      case 'zone_1_classic':
        index = 0;
        break;
      case 'zone_2_obstacles':
        index = 1;
        break;
      case 'zone_3_chaos':
        index = 2;
        break;
      case 'zone_4_impossible':
        index = 3;
        break;
      case 'zone_5_maze':
        index = 4;
        break;
      default:
        return;
    }

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        index * itemHeight,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      title: LanguageManager.of(context).translate('select_zone'),
      showBackButton: true,
      onBack: widget.onBack,
      body: Column(
        children: [
          // Banner Ad removed (moved to Scaffold)
          const SizedBox(height: 10),

          // Content
          Expanded(child: _buildOfficialMaps()),
        ],
      ),
    );
  }

  // ... (unchanged)

  // In _buildNeonMapCard (implicit update via logic knowledge, but I need to target explicit lines)
  // Wait, I cannot edit _buildNeonMapCard unless I include it in range.
  // The replace call has EndLine 256.
  // _buildNeonMapCard is further down.
  // I will split into TWO checks or ONE large replace (if possible).
  // _buildNeonMapCard starts at 190.
  // Ranking Button is at 250.
  // build method is at 48.
  // This is too big.
  // I will do two edits.
  // First: Update build method (Banner Ad).
  // Second: Update Ranking Button (NeonButton).

  // Step 1: Update build method (lines 48-109).

  Widget _buildOfficialMaps() {
    // Unified List View
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        _buildNeonMapCard(
          title: LanguageManager.of(context).translate('zone_1_title'),
          description: LanguageManager.of(context).translate('zone_1_desc'),
          mapId: "zone_1_classic",
          color: Colors.cyanAccent, // Blue-ish
        ),
        const SizedBox(height: 20),
        // Zone 2 -> was Zone 3 (Obstacles)
        _buildNeonMapCard(
          title: LanguageManager.of(context).translate('zone_2_title'),
          description: LanguageManager.of(context).translate('zone_2_desc'),
          mapId: "zone_2_obstacles",
          color: Colors.greenAccent, // Green
        ),
        const SizedBox(height: 20),
        // Zone 3 -> was Zone 4 (Chaos)
        _buildNeonMapCard(
          title: LanguageManager.of(context).translate('zone_3_title'),
          description: LanguageManager.of(context).translate('zone_3_desc'),
          mapId: "zone_3_chaos",
          color: Colors.amberAccent, // Yellow
        ),
        const SizedBox(height: 20),
        // Zone 4 -> was Zone 5 (Impossible)
        _buildNeonMapCard(
          title: LanguageManager.of(context).translate('zone_4_title'),
          description: LanguageManager.of(context).translate('zone_4_desc'),
          mapId: "zone_4_impossible",
          color: Colors.deepOrangeAccent, // Orange/Red
        ),
        const SizedBox(height: 20),
        // Zone 5 -> New MAZE
        _buildNeonMapCard(
          title: LanguageManager.of(context).translate('zone_5_title'),
          description: LanguageManager.of(context).translate('zone_5_desc'),
          mapId: "zone_5_maze",
          color: Colors.purpleAccent, // Purple
        ),
        const SizedBox(height: 20), // Bottom padding
      ],
    );
  }

  Widget _buildNeonMapCard({
    required String title,
    required String description,
    required String mapId,
    required Color color,
    bool isCustom = false,
  }) {
    return NeonCard(
      borderColor: color,
      padding: const EdgeInsets.all(16), // Unified padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Map Preview (Mini Map)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.6)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: CustomPaint(
                    painter: MapPreviewPainter(mapId: mapId, color: color),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.subHeader.copyWith(color: color),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textDim,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Play Count Display
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(
                    Icons.videogame_asset,
                    color: AppColors.textDim,
                    size: 16,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${_playCounts[mapId] ?? 0}",
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Buttons Row
          Row(
            children: [
              // Ranking Button
              Expanded(
                flex: 2,
                child: NeonButton(
                  text: LanguageManager.of(context).translate('rank'),
                  icon: Icons.emoji_events,
                  isCompact: false, // Match PLAY button height
                  color: Colors.amber,
                  onPressed: () => widget.onShowRanking(context, mapId),
                  isPrimary: false,
                ),
              ),
              const SizedBox(width: 12),
              // Play Button (Bigger)
              Expanded(
                flex: 3,
                child: NeonButton(
                  text: LanguageManager.of(context).translate('play'),
                  isCompact: false, // Standard size
                  color: AppColors.primary,
                  icon: Icons.play_arrow, // Added Icon
                  onPressed: () => widget.onMapSelected(mapId),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom Painter for Map Preview (Mini Map)
class MapPreviewPainter extends CustomPainter {
  final String mapId;
  final Color color;

  MapPreviewPainter({required this.mapId, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw map border
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);

    // Draw obstacles based on map type
    // Map dimensions ratio: 480x768 (15x24 grid)
    // Canvas is 80x80, so we scale accordingly
    double scaleX = size.width / 480;
    double scaleY = size.height / 768;
    double centerX = size.width / 2;
    double centerY = size.height / 2;

    if (mapId == 'zone_1_classic') {
      // No obstacles
      canvas.drawCircle(
        Offset(centerX, centerY),
        2,
        Paint()..color = color.withOpacity(0.3),
      );
    } else if (mapId == 'zone_2_obstacles') {
      // Was Zone 3: 4 Pillars
      double size_ = 100 * scaleX;
      double dist = 120;

      _drawRect(
        canvas,
        paint,
        centerX + dist * scaleX - size_ / 2,
        centerY + dist * scaleY - size_ / 2,
        size_,
        size_,
      );
      _drawRect(
        canvas,
        paint,
        centerX - dist * scaleX - size_ / 2,
        centerY - dist * scaleY - size_ / 2,
        size_,
        size_,
      );
      _drawRect(
        canvas,
        paint,
        centerX + dist * scaleX - size_ / 2,
        centerY - dist * scaleY - size_ / 2,
        size_,
        size_,
      );
      _drawRect(
        canvas,
        paint,
        centerX - dist * scaleX - size_ / 2,
        centerY + dist * scaleY - size_ / 2,
        size_,
        size_,
      );
    } else if (mapId == 'zone_3_chaos') {
      // Zone 3: The Cross (Preview)
      double thickness = 30 * scaleX; // Scaled thickness
      double centerGap = 60 * scaleY; // Scaled gap (vertical reference)
      // Note: gap needs scaling too.
      double centerGapX = 60 * scaleX;

      // Vertical Wall (Top)
      _drawRect(
        canvas,
        paint,
        centerX - thickness / 2,
        centerY - 384 * scaleY, // Top (0 relative to center 384)
        // Wait, preview center is 0,0 relative? No, it's center of canvas.
        // Game coords: 0 to 768.
        // Preview coords: centerX - (width/2)*s to centerX + ...
        // Better to calculate relative to center.
        // Top Wall: CenterX, Top to CenterY - Gap.
        // Rect: (CenterX - Thick/2, TopEdge, Thick, Height)
        // TopEdge = centerY - (768/2)*scaleY
        // Height = (384 - 60) * scaleY = 324 * scaleY
        thickness,
        (384 - 60) * scaleY,
      );

      // Vertical Wall (Bottom)
      _drawRect(
        canvas,
        paint,
        centerX - thickness / 2,
        centerY + centerGap, // Start at CenterY + Gap
        thickness,
        (384 - 60) * scaleY,
      );

      // Horizontal Wall (Left)
      _drawRect(
        canvas,
        paint,
        centerX - 240 * scaleX, // LeftEdge
        centerY - thickness / 2, // CenterY - Thick/2
        (240 - 60) * scaleX, // Width
        thickness * (scaleY / scaleX), // Maintain Aspect Ratio for thickness?
        // Actually thickness was calculated with scaleX above.
        // If we want square thickness, usage might vary.
        // Let's stick to scaleY for height.
      );

      // Horizontal Wall (Right)
      _drawRect(
        canvas,
        paint,
        centerX + centerGapX, // Start at CenterX + Gap
        centerY - thickness / 2,
        (240 - 60) * scaleX,
        thickness * (scaleY / scaleX),
      );
    } else if (mapId == 'zone_4_impossible') {
      // Was Zone 5: The Grid
      double size = 35;
      double gap = 55;
      double startOffset = gap / 2;
      double w = 480;
      double h = 768; // Based on ratio

      for (double y = startOffset; y < h / 2 - 20; y += size + gap) {
        for (double x = startOffset; x < w / 2 - 20; x += size + gap) {
          int ix = ((x - startOffset) / (size + gap)).round();
          int iy = ((y - startOffset) / (size + gap)).round();

          if ((ix + iy) % 2 == 0) {
            // Draw Symmetrical directly
            double sS =
                size * scaleX; // Approx square if aspect ratio preserved
            double dx = x * scaleX;
            double dy = y * scaleY;

            _drawRect(canvas, paint, centerX + dx, centerY + dy, sS, sS);
            _drawRect(
              canvas,
              paint,
              centerX - dx - sS,
              centerY - dy - sS,
              sS,
              sS,
            );
            _drawRect(canvas, paint, centerX + dx, centerY - dy - sS, sS, sS);
            _drawRect(canvas, paint, centerX - dx - sS, centerY + dy, sS, sS);
          }
        }
      }
    } else if (mapId == 'zone_5_maze') {
      // Zone 5: Maze (Exact Preview)
      // Mirroring Logic from main.dart
      double cellSize = 60 * scaleX; // Scaled cell size (Base 60)
      double wallThickness = 5;

      // Calculate scaled dimensions
      // Real Map: 480x768.

      double availableW = 480 - 120; // 60*2 padding
      double availableH = 768 - 120;

      int cols = (availableW / 60).floor();
      int rows = (availableH / 60).floor();

      double offsetX = (480 - (cols * 60)) / 2;
      double offsetY = (768 - (rows * 60)) / 2;

      // Seeded Generator
      MazeGenerator generator = MazeGenerator(rows, cols, seed: 12345);
      List<List<dynamic>> walls = generator.generate();

      Random rng = Random(67890); // Seeded Entrance Random

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

        if (isBoundary && rng.nextDouble() < 0.2) {
          continue;
        }

        // Apply Scaling to coordinates
        double x = (c * 60 + offsetX) * scaleX;
        double y = (r * 60 + offsetY) * scaleY;

        // Center Safe Zone Check (Base coords)
        double cx = c * 60 + offsetX;
        double cy = r * 60 + offsetY;
        if (cx > 480 / 2 - 80 &&
            cx < 480 / 2 + 80 &&
            cy > 768 / 2 - 80 &&
            cy < 768 / 2 + 80) {
          continue;
        }

        if (isHorizontal) {
          _drawRect(
            canvas,
            paint,
            centerX - 480 / 2 * scaleX + x,
            centerY - 768 / 2 * scaleY + y,
            cellSize,
            wallThickness * scaleY,
          );
        } else {
          _drawRect(
            canvas,
            paint,
            centerX - 480 / 2 * scaleX + x,
            centerY - 768 / 2 * scaleY + y,
            wallThickness * scaleX,
            cellSize,
          );
        }
      }
    }

    // Always draw Player Indicator at Center (on top of everything)
    canvas.drawCircle(
      Offset(centerX, centerY),
      3.0, // Small dot
      Paint()..color = AppColors.primary,
    );
  }

  void _drawRect(
    Canvas canvas,
    Paint paint,
    double x,
    double y,
    double width,
    double height,
  ) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, width, height),
        const Radius.circular(2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
