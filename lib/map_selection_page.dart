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

  const MapSelectionPage({
    super.key,
    required this.onMapSelected,
    required this.onShowRanking,
    required this.onBack,
  });

  @override
  State<MapSelectionPage> createState() => _MapSelectionPageState();
}

class _MapSelectionPageState extends State<MapSelectionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Banner Ad handled globally
  }

  @override
  void dispose() {
    _tabController.dispose();
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

          // Custom Tabs
          const SizedBox(height: 10), // Spacing from banner
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryDim.withOpacity(0.5)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary),
              ),
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textDim,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent, // Remove default divider
              tabs: [
                Tab(
                  text: LanguageManager.of(context).translate('official_maps'),
                ),
                Tab(text: LanguageManager.of(context).translate('custom_maps')),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildOfficialMaps(), _buildCustomMaps()],
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        _buildNeonMapCard(
          title: "ZONE 1: CLASSIC",
          description: "The beginning of the nightmare.",
          mapId: "zone_1_classic",
          color: Colors.cyan,
        ),
        const SizedBox(height: 20),
        _buildNeonMapCard(
          title: "ZONE 2: HARDCORE",
          description: "Faster and more chaos.",
          mapId: "zone_2_hard",
          color: Colors.redAccent,
        ),
        const SizedBox(height: 20),
        const SizedBox(height: 20),
        _buildNeonMapCard(
          title: "ZONE 3: OBSTACLES",
          description: "Watch your step!",
          mapId: "zone_3_obstacles",
          color: Colors.amber,
        ),
        const SizedBox(height: 20),
        _buildNeonMapCard(
          title: "ZONE 4: CHAOS",
          description: "No way out.",
          mapId: "zone_4_chaos",
          color: Colors.deepOrange,
        ),
        const SizedBox(height: 20),
        _buildNeonMapCard(
          title: "ZONE 5: IMPOSSIBLE",
          description: "Good luck.",
          mapId: "zone_5_impossible",
          color: Colors.purpleAccent,
        ),
        const SizedBox(height: 20), // Bottom padding
      ],
    );
  }

  Widget _buildCustomMaps() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: MapService().getCustomMaps(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error loading maps",
              style: AppTextStyles.body.copyWith(color: AppColors.secondary),
            ),
          );
        }
        final maps = snapshot.data ?? [];
        if (maps.isEmpty) {
          return const Center(
            child: Text("No custom maps found.", style: AppTextStyles.body),
          );
        }

        // Use standard ListView builder for consistency
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: maps.length,
          separatorBuilder: (_, __) => const SizedBox(height: 20),
          itemBuilder: (context, index) {
            final map = maps[index];
            DateTime? date;
            if (map['createdAt'] != null) {
              date = (map['createdAt'] as Timestamp).toDate();
            }
            return _buildNeonMapCard(
              title: map['name'] ?? 'Untitled',
              description:
                  "By ${map['author'] ?? 'Unknown'} • ${date != null ? DateFormat('MM/dd').format(date) : ''}",
              mapId: map['id'],
              color: const Color(0xFFD91DF2), // Purple for custom
              isCustom: true,
            );
          },
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
                flex: 1,
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
                flex: 2,
                child: NeonButton(
                  text: LanguageManager.of(context).translate('play'),
                  isCompact: false, // Standard size
                  color: AppColors.primary,
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
