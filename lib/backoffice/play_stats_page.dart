import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PlayStatsPage extends StatefulWidget {
  const PlayStatsPage({super.key});

  @override
  State<PlayStatsPage> createState() => _PlayStatsPageState();
}

class _PlayStatsPageState extends State<PlayStatsPage> {
  bool _loading = true;

  // Stage stats
  Map<String, int> _stageCounts = {};

  // Character stats
  Map<String, int> _characterCounts = {};

  // Per-stage character breakdown
  // stageId -> { characterId -> count }
  Map<String, Map<String, int>> _stageCharacterMap = {};

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  static const _stageOrder = [
    'zone_1_classic',
    'zone_2_obstacles',
    'zone_5_maze',
  ];

  static const _stageNames = {
    'zone_1_classic':   'Zone 1 — Classic',
    'zone_2_obstacles': 'Zone 2 — Arena',
    'zone_5_maze':      'Zone 3 — Abyss',
  };

  static const _characterNames = {
    'neon_green':    'Neon Green',
    'electric_blue': 'Electric Blue',
    'cyber_red':     'Cyber Red',
    'plasma_purple': 'Plasma Purple',
  };

  static const _characterColors = {
    'neon_green':    Color(0xFF00FF88),
    'electric_blue': Color(0xFF00E5FF),
    'cyber_red':     Color(0xFFFF1744),
    'plasma_purple': Color(0xFFE040FB),
  };

  static const _characterIcons = {
    'neon_green':    Icons.crop_square,
    'electric_blue': Icons.circle_outlined,
    'cyber_red':     Icons.change_history,
    'plasma_purple': Icons.rocket_launch,
  };

  Future<void> _fetchStats() async {
    setState(() => _loading = true);
    try {
      // Aggregate mapPlayCounts and characterPlayCounts from all users
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .limit(2000)
          .get();

      final Map<String, int> stageCounts = {};
      final Map<String, int> characterCounts = {};
      final Map<String, Map<String, int>> stageCharMap = {};

      for (final doc in usersSnap.docs) {
        final data = doc.data();

        // Map play counts
        final mapCounts = data['mapPlayCounts'];
        if (mapCounts is Map) {
          mapCounts.forEach((k, v) {
            if (v is int) stageCounts[k as String] = (stageCounts[k] ?? 0) + v;
          });
        }

        // Character play counts
        final charCounts = data['characterPlayCounts'];
        if (charCounts is Map) {
          charCounts.forEach((k, v) {
            if (v is int) characterCounts[k as String] = (characterCounts[k] ?? 0) + v;
          });
        }
      }

      // Build per-stage character breakdown from records
      for (final stageId in _stageOrder) {
        final recordsSnap = await FirebaseFirestore.instance
            .collection('maps')
            .doc(stageId)
            .collection('records')
            .limit(2000)
            .get();

        final Map<String, int> charMap = {};
        for (final r in recordsSnap.docs) {
          final charId = (r.data()['characterId'] as String?) ?? 'neon_green';
          charMap[charId] = (charMap[charId] ?? 0) + 1;
        }
        stageCharMap[stageId] = charMap;
      }

      if (mounted) {
        setState(() {
          _stageCounts = stageCounts;
          _characterCounts = characterCounts;
          _stageCharacterMap = stageCharMap;
          _loading = false;
        });
      }
    } catch (e) {
      print('PlayStatsPage error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '플레이 통계',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              IconButton(
                onPressed: _fetchStats,
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00FF88)),
                tooltip: '새로고침',
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF00FF88))))
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('스테이지 플레이 분포', Icons.map_outlined),
                    const SizedBox(height: 12),
                    _buildStageChart(),
                    const SizedBox(height: 32),
                    _buildSectionTitle('캐릭터 선호도 (전체)', Icons.person_outline),
                    const SizedBox(height: 12),
                    _buildCharacterChart(_characterCounts),
                    const SizedBox(height: 32),
                    _buildSectionTitle('스테이지별 캐릭터 사용', Icons.bar_chart_rounded),
                    const SizedBox(height: 12),
                    ..._stageOrder.map((stageId) {
                      final charMap = _stageCharacterMap[stageId] ?? {};
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _stageNames[stageId] ?? stageId,
                              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                          _buildCharacterChart(charMap),
                          const SizedBox(height: 20),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00FF88), size: 18),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Color(0xFF00FF88), fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildStageChart() {
    if (_stageCounts.isEmpty) {
      return const Text('데이터 없음', style: TextStyle(color: Colors.white38));
    }
    final total = _stageCounts.values.fold(0, (a, b) => a + b);
    final maxVal = _stageCounts.values.fold(0, (a, b) => a > b ? a : b);

    return Column(
      children: _stageOrder.map((stageId) {
        final count = _stageCounts[stageId] ?? 0;
        final pct = total > 0 ? count / total : 0.0;
        return _buildBarRow(
          label: _stageNames[stageId] ?? stageId,
          count: count,
          pct: pct,
          barRatio: maxVal > 0 ? count / maxVal : 0.0,
          color: const Color(0xFF6C63FF),
        );
      }).toList(),
    );
  }

  Widget _buildCharacterChart(Map<String, int> counts) {
    if (counts.isEmpty) {
      return const Text('데이터 없음', style: TextStyle(color: Colors.white38, fontSize: 12));
    }
    final total = counts.values.fold(0, (a, b) => a + b);
    final maxVal = counts.values.fold(0, (a, b) => a > b ? a : b);
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sorted.map((e) {
        final color = _characterColors[e.key] ?? Colors.white38;
        final pct = total > 0 ? e.value / total : 0.0;
        return _buildBarRow(
          label: _characterNames[e.key] ?? e.key,
          count: e.value,
          pct: pct,
          barRatio: maxVal > 0 ? e.value / maxVal : 0.0,
          color: color,
          icon: _characterIcons[e.key],
        );
      }).toList(),
    );
  }

  Widget _buildBarRow({
    required String label,
    required int count,
    required double pct,
    required double barRatio,
    required Color color,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
          ],
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: barRatio,
                minHeight: 12,
                backgroundColor: Colors.white10,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              '${NumberFormat('#,###').format(count)}회 (${(pct * 100).toStringAsFixed(1)}%)',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
