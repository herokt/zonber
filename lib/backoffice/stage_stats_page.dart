import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StageStatsPage extends StatefulWidget {
  const StageStatsPage({super.key});

  @override
  State<StageStatsPage> createState() => _StageStatsPageState();
}

class _StageStatsPageState extends State<StageStatsPage> {
  // Map ID -> Play Count
  List<Map<String, dynamic>> _mapStats = [];
  bool _loading = true;
  int _maxTotalPlays = 1; // For relative progress bar

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
      int globalMax = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final mapId = doc.id;
        final totalPlays = data['playCount'] ?? 0;
        if (totalPlays > globalMax) globalMax = totalPlays;

        // Fetch Today's plays
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
          // print("Error fetching daily stats for $mapId: $e");
        }

        // Fetch Best Record (Max Survival Time)
        double bestRecord = 0.0;
        String bestPlayer = '-';
        try {
          final bestQuery = await FirebaseFirestore.instance
              .collection('maps')
              .doc(mapId)
              .collection('records')
              .orderBy('survivalTime', descending: true)
              .limit(1)
              .get();

          if (bestQuery.docs.isNotEmpty) {
            final bestData = bestQuery.docs.first.data();
            bestRecord = (bestData['survivalTime'] as num).toDouble();
            bestPlayer = bestData['nickname'] ?? 'Unknown';
          }
        } catch (e) {
          // Ignore
        }

        loadedStats.add({
          'id': mapId,
          'totalPlays': totalPlays,
          'todayPlays': todayPlays,
          'bestRecord': bestRecord,
          'bestPlayer': bestPlayer,
        });
      }

      // Sort by Total Plays descending
      loadedStats.sort(
        (a, b) => (b['totalPlays'] as int).compareTo(a['totalPlays'] as int),
      );

      if (mounted) {
        setState(() {
          _mapStats = loadedStats;
          _maxTotalPlays = globalMax > 0 ? globalMax : 1;
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
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: _fetchStats,
                icon: const Icon(Icons.refresh, color: Color(0xFF00FF88)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 400,
                childAspectRatio: 1.4,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
              ),
              itemCount: _mapStats.length,
              itemBuilder: (context, index) {
                return _buildStageCard(_mapStats[index], index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageCard(Map<String, dynamic> stat, int rank) {
    // Determine Map Name
    String mapName = stat['id'];
    if (mapName.startsWith("stage_")) {
      mapName = "Stage ${mapName.split('_').last}";
    }

    final totalPlays = stat['totalPlays'] as int;
    final progress = totalPlays / _maxTotalPlays;

    return Card(
      color: const Color(0xFF2C2C2C),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => _showLeaderboard(stat['id']),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      mapName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _buildRankBadge(rank),
                ],
              ),
              const Spacer(),
              _buildInfoRow(
                Icons.play_circle_fill,
                "총 플레이",
                NumberFormat('#,###').format(totalPlays),
                Colors.white,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.today,
                "오늘 플레이",
                "${stat['todayPlays']}회",
                const Color(0xFF00FF88),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.emoji_events,
                "최고 기록",
                "${(stat['bestRecord'] as double).toStringAsFixed(2)}s",
                Colors.amberAccent,
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.black26,
                  color: const Color(0xFF6C63FF),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "인기도 ${(progress * 100).toInt()}%",
                  style: const TextStyle(fontSize: 10, color: Colors.white38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    Color color = Colors.white12;
    Color textColor = Colors.white70;
    if (rank == 1) {
      color = Colors.amber.withOpacity(0.2);
      textColor = Colors.amber;
    } else if (rank == 2) {
      color = Colors.grey.withOpacity(0.2);
      textColor = Colors.grey.shade300;
    } else if (rank == 3) {
      color = Colors.brown.withOpacity(0.2);
      textColor = Colors.brown.shade300;
    }

    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Text(
        "$rank",
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white38),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
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
      backgroundColor: const Color(0xFF2C2C2C),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "🏆 ${widget.mapId} Top 50",
            style: const TextStyle(color: Colors.white),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 600,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _records.isEmpty
            ? const Center(
                child: Text(
                  "아직 기록이 없습니다.",
                  style: TextStyle(color: Colors.white54),
                ),
              )
            : ListView.builder(
                itemCount: _records.length,
                itemBuilder: (context, index) {
                  final data = _records[index].data() as Map<String, dynamic>;
                  Color rankColor = Colors.white;
                  if (index == 0) rankColor = Colors.amberAccent;
                  if (index == 1) rankColor = Colors.grey.shade400;
                  if (index == 2) rankColor = Colors.brown.shade300;

                  String dateStr = '-';
                  if (data['timestamp'] != null) {
                    final dt = (data['timestamp'] as Timestamp).toDate();
                    dateStr = DateFormat('yy-MM-dd HH:mm').format(dt);
                  }

                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    child: ListTile(
                      leading: SizedBox(
                        width: 40,
                        child: Text(
                          "#${index + 1}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: rankColor,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            data['flag'] ?? '🏳️',
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "${data['nickname'] ?? '알 수 없음'}",
                            style: const TextStyle(color: Colors.white),
                          ),
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
