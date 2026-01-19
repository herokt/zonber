import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StageStatsPage extends StatefulWidget {
  const StageStatsPage({super.key});

  @override
  State<StageStatsPage> createState() => _StageStatsPageState();
}

class _StageStatsPageState extends State<StageStatsPage> {
  // Map ID -> Play Count
  List<Map<String, dynamic>> _mapStats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _loading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('maps')
          .get();
      List<Map<String, dynamic>> loadedStats = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final mapId = doc.id;
        final totalPlays = data['playCount'] ?? 0;

        // Fetch Today's plays
        // This requires querying the subcollection 'records'
        // timestamp >= today start
        int todayPlays = 0;
        try {
          final now = DateTime.now();
          final todayStart = DateTime(now.year, now.month, now.day);

          final recordSnapshot = await FirebaseFirestore.instance
              .collection('maps')
              .doc(mapId)
              .collection('records')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
              )
              .count()
              .get();

          todayPlays = recordSnapshot.count ?? 0;
        } catch (e) {
          print("Error fetching daily stats for $mapId: $e");
        }

        loadedStats.add({
          'id': mapId,
          'totalPlays': totalPlays,
          'todayPlays': todayPlays,
        });
      }

      // Sort by Total Plays descending
      loadedStats.sort(
        (a, b) => (b['totalPlays'] as int).compareTo(a['totalPlays'] as int),
      );

      if (mounted) {
        setState(() {
          _mapStats = loadedStats;
          _loading = false;
        });
      }
    } catch (e) {
      print("Error fetching stage stats: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showLeaderboard(String mapId) {
    showDialog(
      context: context,
      builder: (context) => LeaderboardDialog(mapId: mapId),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "스테이지 통계",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _fetchStats,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _mapStats.length,
              itemBuilder: (context, index) {
                final stat = _mapStats[index];
                // Make Official Map IDs prettier (e.g. 'stage_1' -> 'Stage 1')
                String mapName = stat['id'];
                if (mapName.startsWith("stage_")) {
                  mapName = "스테이지 ${mapName.split('_').last}";
                }

                return Card(
                  color: const Color(0xFF2C2C2C),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    onTap: () => _showLeaderboard(stat['id']),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        "${index + 1}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      mapName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        "총 누적 플레이: ${stat['totalPlays']} 회",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00FF88).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF00FF88).withOpacity(0.5),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "오늘",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF00FF88),
                                ),
                              ),
                              Text(
                                "${stat['todayPlays']}회",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.white54,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class LeaderboardDialog extends StatefulWidget {
  final String mapId;
  const LeaderboardDialog({super.key, required this.mapId});

  @override
  State<LeaderboardDialog> createState() => _LeaderboardDialogState();
}

class _LeaderboardDialogState extends State<LeaderboardDialog> {
  List<DocumentSnapshot> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    try {
      // Query top 50 records by survivalTime for this map
      final snapshot = await FirebaseFirestore.instance
          .collection('maps')
          .doc(widget.mapId)
          .collection('records')
          .orderBy('survivalTime', descending: true)
          .limit(50)
          .get();

      if (mounted) {
        setState(() {
          _records = snapshot.docs;
          _loading = false;
        });
      }
    } catch (e) {
      print("Error fetching leaderboard: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("🏆 ${widget.mapId} Top 50"),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 600,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _records.isEmpty
            ? const Center(child: Text("아직 기록이 없습니다."))
            : ListView.builder(
                itemCount: _records.length,
                itemBuilder: (context, index) {
                  final data = _records[index].data() as Map<String, dynamic>;

                  // Simple styling based on rank
                  Color rankColor = Colors.white;
                  if (index == 0) rankColor = Colors.amberAccent;
                  if (index == 1) rankColor = Colors.grey.shade400;
                  if (index == 2) rankColor = Colors.brown.shade300;

                  // Date formatting (simple)
                  String dateStr = '-';
                  if (data['timestamp'] != null) {
                    final dt = (data['timestamp'] as Timestamp).toDate();
                    dateStr =
                        "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour}:${dt.minute}";
                  }

                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    child: ListTile(
                      leading: Text(
                        "#${index + 1}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: rankColor,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            data['flag'] ?? '🏳️',
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                          Text("${data['nickname'] ?? '알 수 없음'}"),
                        ],
                      ),
                      subtitle: Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white30,
                        ),
                      ),
                      trailing: Text(
                        "${(data['survivalTime'] as num).toDouble().toStringAsFixed(2)} 초",
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF00FF88),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
