import 'package:flutter/material.dart';
import 'design_system.dart';
import 'language_manager.dart';
import 'ranking_system.dart';
import 'game_config.dart'; // [NEW]

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
    // Dynamically find index
    int index = GameConfig.stages.indexWhere((s) => s.id == mapId);
    if (index == -1) return;

    double itemHeight = 220.0; // Approx height

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
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      itemCount: GameConfig.stages.length + 1, // +1 for bottom padding
      itemBuilder: (context, index) {
        if (index == GameConfig.stages.length) {
          return const SizedBox(height: 48);
        }

        final stage = GameConfig.stages[index];

        // Define colors per difficulty
        Color color;
        if (stage.difficultyLevel == 1) {
          color = Colors.cyanAccent;
        } else if (stage.difficultyLevel == 2) {
          color = Colors.amberAccent;
        } else {
          color = Colors.deepOrangeAccent;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: _buildNeonMapCard(
            title: LanguageManager.of(context).translate(stage.nameKey),
            description: LanguageManager.of(context).translate(stage.descKey),
            mapId: stage.id,
            color: color,
          ),
        );
      },
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
      // No obstacles, just center dot
    } else if (mapId == 'zone_2_prism') {
      // PRISM: Rotated Diamonds
      // 4 Diamonds around center.
      double s = 25 * scaleX;
      double d = 60 * scaleX;

      void drawDiamond(double cx, double cy) {
        Path path = Path();
        path.moveTo(cx, cy - s); // Top
        path.lineTo(cx + s, cy); // Right
        path.lineTo(cx, cy + s); // Bottom
        path.lineTo(cx - s, cy); // Left
        path.close();
        canvas.drawPath(path, paint);
      }

      drawDiamond(centerX - d, centerY - d);
      drawDiamond(centerX + d, centerY - d);
      drawDiamond(centerX - d, centerY + d);
      drawDiamond(centerX + d, centerY + d);
    } else if (mapId == 'zone_3_spiral') {
      // SPIRAL: Concentric Broken Rings
      List<double> radii = [80 * scaleX, 160 * scaleX, 240 * scaleX];

      for (int i = 0; i < radii.length; i++) {
        double r = radii[i];
        // Check bounds
        if (r > size.width / 2 - 2) r = size.width / 2 - 2;

        Rect rect = Rect.fromCenter(
          center: Offset(centerX, centerY),
          width: r * 2,
          height: r * 2,
        );

        int gap = i % 4;

        // Use Lines for "Square Rings" to match game style
        // Top
        if (gap != 0)
          canvas.drawLine(
            rect.topLeft,
            rect.topRight,
            borderPaint..strokeWidth = 3,
          );
        // Right
        if (gap != 1)
          canvas.drawLine(
            rect.topRight,
            rect.bottomRight,
            borderPaint..strokeWidth = 3,
          );
        // Bottom
        if (gap != 2)
          canvas.drawLine(
            rect.bottomRight,
            rect.bottomLeft,
            borderPaint..strokeWidth = 3,
          );
        // Left
        if (gap != 3)
          canvas.drawLine(
            rect.bottomLeft,
            rect.topLeft,
            borderPaint..strokeWidth = 3,
          );
      }
    }

    // Always draw Player Indicator at Center (on top of everything)
    canvas.drawCircle(
      Offset(centerX, centerY),
      3.0,
      Paint()..color = AppColors.primary,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
