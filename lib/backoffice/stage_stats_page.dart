import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StageStatsPage extends StatefulWidget {
  const StageStatsPage({super.key});

  @override
  State<StageStatsPage> createState() => _StageStatsPageState();
}

class _StageStatsPageState extends State<StageStatsPage> {
  List<Map<String, dynamic>> _mapStats = [];
  bool _loading = true;
  int _maxTotalPlays = 1;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  static const _activeStages = ['zone_1_classic', 'zone_2_obstacles', 'zone_5_maze'];

  Future<void> _fetchStats() async {
    setState(() => _loading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('maps').get();
      if (snapshot.docs.isEmpty) {
        if (mounted) setState(() { _mapStats = []; _loading = false; });
        return;
      }

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      List<Map<String, dynamic>> loadedStats = [];
      int globalMax = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final mapId = doc.id;
        if (!_activeStages.contains(mapId)) continue;
        final totalPlays = data['playCount'] as int? ?? 0;
        if (totalPlays > globalMax) globalMax = totalPlays;

        final results = await Future.wait([
          FirebaseFirestore.instance
              .collection('maps').doc(mapId).collection('records')
              .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
              .count().get(),
          FirebaseFirestore.instance
              .collection('maps').doc(mapId).collection('records')
              .orderBy('survivalTime', descending: true)
              .limit(100)
              .get(),
        ]);

        final todayPlays = (results[0] as AggregateQuerySnapshot).count ?? 0;
        final recordDocs = (results[1] as QuerySnapshot).docs;

        double bestRecord = 0.0;
        String bestPlayer = '-';
        if (recordDocs.isNotEmpty) {
          final best = recordDocs.first.data() as Map<String, dynamic>;
          bestRecord = (best['survivalTime'] as num).toDouble();
          bestPlayer = best['nickname'] as String? ?? '-';
        }

        loadedStats.add({
          'id': mapId,
          'totalPlays': totalPlays,
          'todayPlays': todayPlays,
          'bestRecord': bestRecord,
          'bestPlayer': bestPlayer,
          'records': recordDocs,
        });
      }

      loadedStats.sort((a, b) =>
          _activeStages.indexOf(a['id'] as String)
          .compareTo(_activeStages.indexOf(b['id'] as String)));

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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "스테이지 통계",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              IconButton(
                onPressed: _fetchStats,
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00FF88)),
                tooltip: "새로고침",
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_mapStats.isEmpty)
            const Expanded(
              child: Center(child: Text("스테이지 데이터가 없습니다.", style: TextStyle(color: Colors.white54))),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _mapStats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return _buildStageCard(_mapStats[index], index + 1);
                },
              ),
            ),
        ],
      ),
    );
  }

  String _mapName(String mapId) {
    if (mapId == 'zone_1_classic') return 'Zone 1 — Classic';
    if (mapId == 'zone_2_obstacles') return 'Zone 2 — Obstacles';
    if (mapId == 'zone_3_chaos') return 'Zone 3 — Chaos';
    if (mapId == 'zone_4_impossible') return 'Zone 4 — Impossible';
    if (mapId == 'zone_5_maze') return 'Zone 5 — Maze';
    if (mapId.startsWith('stage_')) return 'Stage ${mapId.split('_').last}';
    return mapId;
  }

  Widget _buildStageCard(Map<String, dynamic> stat, int rank) {
    final mapId = stat['id'] as String;
    final totalPlays = stat['totalPlays'] as int;
    final progress = totalPlays / _maxTotalPlays;

    return InkWell(
      onTap: () => _showRankingDialog(stat),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildRankBadge(rank),
                const SizedBox(width: 12),
                Text(
                  _mapName(mapId),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Spacer(),
                _buildStatBadge(Icons.play_circle_outline_rounded, NumberFormat('#,###').format(totalPlays), Colors.white70),
                const SizedBox(width: 8),
                _buildStatBadge(Icons.today_rounded, "${stat['todayPlays']}회 오늘", const Color(0xFF00FF88)),
                const SizedBox(width: 8),
                _buildStatBadge(Icons.emoji_events_rounded, "${(stat['bestRecord'] as double).toStringAsFixed(3)}s", Colors.amberAccent),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white10,
                color: const Color(0xFF6C63FF),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRankingDialog(Map<String, dynamic> stat) {
    final records = stat['records'] as List<DocumentSnapshot>;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Colors.amberAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _mapName(stat['id'] as String),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              // 랭킹 테이블
              Flexible(
                child: records.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: Text("기록 없음", style: TextStyle(color: Colors.white24))),
                      )
                    : SingleChildScrollView(child: _buildRankingTable(records)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankingTable(List<DocumentSnapshot> records) {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(52),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(3),
        3: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFF252525)),
          children: [
            _tableHeader('순위'),
            _tableHeader('닉네임'),
            _tableHeader('기록'),
            _tableHeader('날짜'),
          ],
        ),
        ...records.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value.data() as Map<String, dynamic>;
          final dt = (data['timestamp'] as Timestamp?)?.toDate();
          final dateStr = dt != null ? DateFormat('MM/dd HH:mm').format(dt) : '-';

          Color rankColor = Colors.white54;
          if (index == 0) rankColor = Colors.amberAccent;
          else if (index == 1) rankColor = Colors.grey.shade400;
          else if (index == 2) rankColor = Colors.brown.shade300;

          final isTop3 = index < 3;

          return TableRow(
            decoration: BoxDecoration(
              color: isTop3 ? rankColor.withOpacity(0.04) : Colors.transparent,
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
            ),
            children: [
              _tableCell(Text(
                '#${index + 1}',
                style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 13),
                textAlign: TextAlign.center,
              )),
              _tableCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(data['flag'] as String? ?? '🏳️', style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Flexible(child: Text(
                    data['nickname'] as String? ?? '-',
                    style: TextStyle(
                      color: isTop3 ? Colors.white : Colors.white70,
                      fontWeight: isTop3 ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  )),
                ],
              )),
              _tableCell(Text(
                '${(data['survivalTime'] as num).toDouble().toStringAsFixed(3)}초',
                style: TextStyle(
                  color: index == 0 ? Colors.amberAccent : const Color(0xFF00FF88),
                  fontWeight: FontWeight.bold,
                  fontSize: index == 0 ? 15 : 13,
                ),
              )),
              _tableCell(Text(
                dateStr,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              )),
            ],
          );
        }),
      ],
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(text, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _tableCell(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: child,
    );
  }

  Widget _buildStatBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    Color color = Colors.white12;
    Color textColor = Colors.white54;
    if (rank == 1) { color = Colors.amber.withOpacity(0.2); textColor = Colors.amber; }
    else if (rank == 2) { color = Colors.grey.withOpacity(0.2); textColor = Colors.grey.shade300; }
    else if (rank == 3) { color = Colors.brown.withOpacity(0.2); textColor = Colors.brown.shade300; }

    return Container(
      width: 30, height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color, shape: BoxShape.circle,
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Text('$rank', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}
