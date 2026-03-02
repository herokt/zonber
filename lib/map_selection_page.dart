import 'package:flutter/material.dart';
import 'dart:math'; // For MazeGenerator preview
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
    int index = 0;
    double itemHeight = 220.0; // Approx height

    switch (mapId) {
      case 'zone_1_classic':
        index = 0;
        break;
      case 'zone_2_obstacles':
        index = 1;
        break;
      case 'zone_5_maze':
        index = 2;
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
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        _buildNeonMapCard(
          title: LanguageManager.of(context).translate('zone_1_title'),
          description: LanguageManager.of(context).translate('zone_1_desc'),
          mapId: "zone_1_classic",
          color: Colors.cyanAccent,
        ),
        const SizedBox(height: 20),
        _buildNeonMapCard(
          title: LanguageManager.of(context).translate('zone_2_title'),
          description: LanguageManager.of(context).translate('zone_2_desc'),
          mapId: "zone_2_obstacles",
          color: Colors.greenAccent,
        ),
        const SizedBox(height: 20),
        _buildNeonMapCard(
          title: LanguageManager.of(context).translate('zone_5_title'),
          description: LanguageManager.of(context).translate('zone_5_desc'),
          mapId: "zone_5_maze",
          color: Colors.purpleAccent,
        ),
        const SizedBox(height: 20),
        const SizedBox(height: 20),
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
      padding: const EdgeInsets.all(20), // More internal padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Map Preview (Mini Map)
              Container(
                width: 88, // Slightly larger preview
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.1), blurRadius: 12),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CustomPaint(
                    painter: MapPreviewPainter(mapId: mapId, color: color),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: AppTextStyles.subHeader.copyWith(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textDim,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Buttons Row
          Row(
            children: [
              // Ranking Button
              Expanded(
                flex: 2,
                child: NeonButton(
                  text: LanguageManager.of(context).translate('rank'),
                  icon: Icons
                      .emoji_events_outlined, // Outlined icon for secondary
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
                  icon: Icons.play_arrow_rounded,
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
    double scaleX = size.width / 480;
    double scaleY =
        size.height /
        768; // Wait, preview is usually square or aspect? Canvas size is from Container (88x88).
    // So ratio is 1:1. Map is 480:768 (0.625).
    // We should fit the map into the square.
    // scaleX = 88 / 480 = 0.18. scaleY = 88 / 768 = 0.11.
    // To preserve aspect ratio, we should use the smaller scale and center it?
    // Or just stretch as before? Previous code used scaleX and scaleY independently.
    // Let's stick to independent scaling to fill the preview box.

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
      // 4 Pillars
      double size_ = 100 * scaleX;
      double dist = 120;

      _drawRect(canvas, paint, centerX + dist * scaleX - size_ / 2, centerY + dist * scaleY - size_ / 2, size_, size_);
      _drawRect(canvas, paint, centerX - dist * scaleX - size_ / 2, centerY - dist * scaleY - size_ / 2, size_, size_);
      _drawRect(canvas, paint, centerX + dist * scaleX - size_ / 2, centerY - dist * scaleY - size_ / 2, size_, size_);
      _drawRect(canvas, paint, centerX - dist * scaleX - size_ / 2, centerY + dist * scaleY - size_ / 2, size_, size_);
    } else if (mapId == 'zone_3_chaos') {
      // The Cross
      double thickness = 30 * scaleX;
      double centerGap = 60 * scaleY;
      double centerGapX = 60 * scaleX;

      // Vertical Wall (Top)
      _drawRect(canvas, paint, centerX - thickness / 2, centerY - 384 * scaleY, thickness, (384 - 60) * scaleY);
      // Vertical Wall (Bottom)
      _drawRect(canvas, paint, centerX - thickness / 2, centerY + centerGap, thickness, (384 - 60) * scaleY);
      // Horizontal Wall (Left)
      _drawRect(canvas, paint, centerX - 240 * scaleX, centerY - thickness / 2, (240 - 60) * scaleX, thickness * (scaleY / scaleX));
      // Horizontal Wall (Right)
      _drawRect(canvas, paint, centerX + centerGapX, centerY - thickness / 2, (240 - 60) * scaleX, thickness * (scaleY / scaleX));
    } else if (mapId == 'zone_4_impossible') {
      // The Grid
      double size = 35;
      double gap = 55;
      double startOffset = gap / 2;
      double w = 480;
      double h = 768;

      for (double y = startOffset; y < h / 2 - 20; y += size + gap) {
        for (double x = startOffset; x < w / 2 - 20; x += size + gap) {
          int ix = ((x - startOffset) / (size + gap)).round();
          int iy = ((y - startOffset) / (size + gap)).round();

          if ((ix + iy) % 2 == 0) {
            double sS = size * scaleX;
            double dx = x * scaleX;
            double dy = y * scaleY;

            _drawRect(canvas, paint, centerX + dx, centerY + dy, sS, sS);
            _drawRect(canvas, paint, centerX - dx - sS, centerY - dy - sS, sS, sS);
            _drawRect(canvas, paint, centerX + dx, centerY - dy - sS, sS, sS);
            _drawRect(canvas, paint, centerX - dx - sS, centerY + dy, sS, sS);
          }
        }
      }
    } else if (mapId == 'zone_5_maze') {
      // Zone 5: Maze (Exact Preview)
      double cellSize = 60 * scaleX;

      double availableW = 480 - 120;
      double availableH = 768 - 120;

      int cols = (availableW / 60).floor();
      int rows = (availableH / 60).floor();

      double offsetX = (480 - (cols * 60)) / 2;
      double offsetY = (768 - (rows * 60)) / 2;

      MazeGenerator generator = MazeGenerator(rows, cols, seed: 12345);
      List<List<dynamic>> walls = generator.generate();

      Random rng = Random(67890);

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

        if (isBoundary && rng.nextDouble() < 0.2) continue;

        double x = (c * 60 + offsetX) * scaleX;
        double y = (r * 60 + offsetY) * scaleY;

        double cx = c * 60 + offsetX;
        double cy = r * 60 + offsetY;
        if (cx > 480 / 2 - 80 && cx < 480 / 2 + 80 && cy > 768 / 2 - 80 && cy < 768 / 2 + 80) {
          continue;
        }

        if (isHorizontal) {
          _drawRect(canvas, paint, centerX - 480 / 2 * scaleX + x, centerY - 768 / 2 * scaleY + y, cellSize, 5 * scaleY);
        } else {
          _drawRect(canvas, paint, centerX - 480 / 2 * scaleX + x, centerY - 768 / 2 * scaleY + y, 5 * scaleX, cellSize);
        }
      }
    }

    // Always draw Player Indicator at Center (on top of everything)
    canvas.drawCircle(
      Offset(centerX, centerY),
      3.0,
      Paint()..color = AppColors.primary,
    );
  }

  void _drawRect(Canvas canvas, Paint paint, double x, double y, double width, double height) {
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
