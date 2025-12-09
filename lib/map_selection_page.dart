import 'package:flutter/material.dart';

class MapSelectionPage extends StatelessWidget {
  final Function(String mapId) onMapSelected;
  final VoidCallback onBack;

  const MapSelectionPage({
    Key? key,
    required this.onMapSelected,
    required this.onBack,
  }) : super(key: key);

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
          onPressed: onBack,
        ),
      ),
      body: Center(
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
    return GestureDetector(
      onTap: locked ? null : () => onMapSelected(mapId),
      child: Container(
        width: double.infinity,
        height: 120,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2833),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: locked ? Colors.grey : color, width: 2),
          boxShadow: locked
              ? []
              : [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(
              locked ? Icons.lock : Icons.public,
              color: locked ? Colors.grey : color,
              size: 50,
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
            if (!locked)
              const Icon(Icons.arrow_forward_ios, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
