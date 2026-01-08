import 'package:flutter/material.dart';
import 'map_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'design_system.dart';
import 'language_manager.dart';

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

  @override
  void initState() {
    super.initState();
    
    // Scroll to initial map if provided
    if (widget.initialMapId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToMap(widget.initialMapId!);
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
      case 'zone_1_classic': index = 0; break;
      case 'zone_2_hard': index = 1; break;
      case 'zone_3_obstacles': index = 2; break;
      case 'zone_4_chaos': index = 3; break;
      case 'zone_5_impossible': index = 4; break;
      default: return;
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
          Expanded(
            child: _buildOfficialMaps(),
          ),
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
        _buildNeonMapCard(
          title: LanguageManager.of(context).translate('zone_2_title'),
          description: LanguageManager.of(context).translate('zone_2_desc'),
          mapId: "zone_2_hard",
          color: Colors.greenAccent, // Green
        ),
        const SizedBox(height: 20),
        _buildNeonMapCard(
          title: LanguageManager.of(context).translate('zone_3_title'),
          description: LanguageManager.of(context).translate('zone_3_desc'),
          mapId: "zone_3_obstacles",
          color: Colors.amberAccent, // Yellow
        ),
        const SizedBox(height: 20),
        _buildNeonMapCard(
          title: LanguageManager.of(context).translate('zone_4_title'),
          description: LanguageManager.of(context).translate('zone_4_desc'),
          mapId: "zone_4_chaos",
          color: Colors.deepOrangeAccent, // Orange/Red
        ),
        const SizedBox(height: 20),
        _buildNeonMapCard(
          title: LanguageManager.of(context).translate('zone_5_title'),
          description: LanguageManager.of(context).translate('zone_5_desc'),
          mapId: "zone_5_impossible",
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
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.6)),
                ),
                child: Icon(
                  isCustom ? Icons.public : Icons.token,
                  color: color,
                  size: 28,
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
