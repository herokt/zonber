import 'package:flutter/material.dart';

import 'map_service.dart';
import 'package:intl/intl.dart'; // For Date Formatting

class MapSelectionPage extends StatefulWidget {
  final Function(String mapId) onMapSelected;
  final Function(BuildContext context, String mapId)
  onShowRanking; // Updated Callback
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0C10),
        title: const Text(
          "SELECT ZONE",
          style: TextStyle(
            color: Color(0xFF66FCF1),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF45A29E),
          labelColor: const Color(0xFF66FCF1),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "OFFICIAL"),
            Tab(text: "CUSTOM"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildOfficialMaps(), _buildCustomMaps()],
      ),
    );
  }

  Widget _buildOfficialMaps() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMapCard(
              context,
              "ZONE 1: CLASSIC",
              "The beginning of the nightmare.",
              "zone_1_classic",
              Colors.cyan,
            ),
            const SizedBox(height: 20),
            _buildMapCard(
              context,
              "ZONE 2: HARDCORE",
              "Faster and more chaos.",
              "zone_2_hard",
              Colors.redAccent,
              locked: false,
            ),
            const SizedBox(height: 20),
            _buildMapCard(
              context,
              "ZONE 3: OBSTACLES",
              "Watch your step!",
              "zone_3_obstacles",
              Colors.amber,
              locked: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomMaps() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: MapService().getCustomMaps(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF45A29E)),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error loading maps",
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        final maps = snapshot.data ?? [];
        if (maps.isEmpty) {
          return const Center(
            child: Text(
              "No custom maps found.",
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: maps.length,
          itemBuilder: (context, index) {
            final map = maps[index];
            DateTime? date;
            if (map['createdAt'] != null) {
              date = (map['createdAt'] as Timestamp).toDate();
            }

            return _buildCustomMapCard(map, date);
          },
        );
      },
    );
  }

  Widget _buildCustomMapCard(Map<String, dynamic> map, DateTime? date) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2833),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF45A29E), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: const Icon(Icons.map, color: Color(0xFF45A29E), size: 40),
        title: Text(
          map['name'] ?? 'Untitled',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "By ${map['author'] ?? 'Unknown'}",
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            if (date != null)
              Text(
                DateFormat('yyyy-MM-dd HH:mm').format(date),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
          ],
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF45A29E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: () => widget.onMapSelected(map['id']),
          child: const Text(
            "PLAY",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildMapCard(
    BuildContext context,
    String title,
    String description,
    String mapId,
    Color color, {
    bool locked = false,
  }) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: locked
            ? []
            : [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Stack(
        children: [
          // 1. Base Card + InkWell (Main Click)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: locked ? null : () => widget.onMapSelected(mapId),
                borderRadius: BorderRadius.circular(20),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: locked
                          ? [Colors.grey[800]!, Colors.grey[900]!]
                          : [const Color(0xFF1F2833), const Color(0xFF0B0C10)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: locked ? Colors.grey : color.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: locked
                                ? Colors.grey.withOpacity(0.2)
                                : color.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            locked ? Icons.lock : Icons.public,
                            color: locked ? Colors.grey : color,
                            size: 40,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  color: locked ? Colors.grey : Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                description,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Play Icon (Visual Only, passes touches to InkWell below is tricky,
          // so we keep it purely visual inside the stack, but behind the InkWell?
          // No, InkWell is opaque to touches.
          // The Play Icon was just visual. We can leave it inside the Ink's child or on top ignoring pointer.
          if (!locked)
            Positioned(
              bottom: 15,
              right: 20,
              child: IgnorePointer(
                child: Icon(
                  Icons.play_circle_fill,
                  color: color.withOpacity(0.8),
                  size: 30,
                ),
              ),
            ),

          // 3. Ranking Button (Discrete Clickable Area)
          if (!locked)
            Positioned(
              top: 5,
              right: 5,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: const Icon(Icons.emoji_events),
                  color: Colors.amber,
                  iconSize: 30,
                  onPressed: () {
                    print("Ranking button clicked for $mapId");
                    widget.onShowRanking(context, mapId);
                  },
                  tooltip: "View Ranking",
                ),
              ),
            ),
        ],
      ),
    );
  }
}
