import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _totalUsers = 0;
  int _totalGames = 0;
  List<DocumentSnapshot> _recentUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      // 1. Total Users
      final userCountSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .count()
          .get();
      final totalUsers = userCountSnapshot.count ?? 0;

      // 2. Total Games (Sum of playCount from maps)
      final mapsSnapshot = await FirebaseFirestore.instance
          .collection('maps')
          .get();
      int totalGames = 0;
      for (var doc in mapsSnapshot.docs) {
        totalGames += (doc.data()['playCount'] as int? ?? 0);
      }

      // 3. Recent Users (Last 5 joined/updated)
      // Assuming 'lastUpdated' or similar exists. standardizing on that.
      final recentSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('lastUpdated', descending: true)
          .limit(5)
          .get();

      if (mounted) {
        setState(() {
          _totalUsers = totalUsers;
          _totalGames = totalGames;
          _recentUsers = recentSnapshot.docs;
          _loading = false;
        });
      }
    } catch (e) {
      print("Error loading dashboard stats: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildStatCards(),
          const SizedBox(height: 48),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildRecentUsers()),
              const SizedBox(width: 32),
              Expanded(flex: 1, child: _buildQuickActions()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Dashboard (v2)",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "오늘 ${DateFormat('yyyy년 MM월 dd일').format(DateTime.now())} 현황입니다.",
          style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _buildStatCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Simple responsive layout logic
        return Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            _buildModernCard(
              title: "총 사용자",
              value: NumberFormat('#,###').format(_totalUsers),
              subtitle: "Total Users",
              icon: Icons.people_alt_rounded,
              gradientColors: [
                const Color(0xFF4FACFE),
                const Color(0xFF00F2FE),
              ],
            ),
            _buildModernCard(
              title: "총 플레이 횟수",
              value: NumberFormat('#,###').format(_totalGames),
              subtitle: "Total Plays",
              icon: Icons.games_rounded,
              gradientColors: [
                const Color(0xFF43E97B),
                const Color(0xFF38F9D7),
              ],
            ),
            _buildModernCard(
              title: "현재 상태",
              value: "정상",
              subtitle: "Server Status",
              icon: Icons.check_circle_rounded,
              gradientColors: [
                const Color(0xFFFA709A),
                const Color(0xFFFEE140),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildModernCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
  }) {
    return Container(
      width: 300,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: gradientColors.map((c) => c.withOpacity(0.2)).toList(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: gradientColors.first.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              icon,
              size: 120,
              color: gradientColors.first.withOpacity(0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: gradientColors.last, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentUsers() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "최근 활동 사용자 (All Users)",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: _loadStats,
                child: const Text(
                  "새로고침",
                  style: TextStyle(color: Color(0xFF00FF88)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_recentUsers.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  "데이터가 없습니다.",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 600,
                ), // Min width for dashboard table
                child: DataTable(
                  horizontalMargin: 24,
                  columnSpacing: 32,
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFF2C2C2C),
                  ),
                  dataRowColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return Colors.white.withOpacity(0.05);
                    }
                    return Colors.transparent;
                  }),
                  columns: const [
                    DataColumn(
                      label: Text(
                        '닉네임',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        '국가',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        '플랫폼',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        '최근 활동',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  rows: _recentUsers.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final lastUpdated = (data['lastUpdated'] as Timestamp?)
                        ?.toDate();
                    final dateStr = lastUpdated != null
                        ? DateFormat('MM/dd HH:mm').format(lastUpdated)
                        : '-';

                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.white10,
                                child: Text(
                                  (data['flag'] == null ||
                                          data['flag'].toString().isEmpty)
                                      ? '🏳️'
                                      : data['flag'],
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                data['nickname'] ?? '-',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            data['countryName'] ?? '-',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3DD9EB).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF3DD9EB).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.android,
                                  size: 12,
                                  color: const Color(
                                    0xFF3DD9EB,
                                  ).withOpacity(0.8),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Mobile',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF3DD9EB),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            dateStr,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "빠른 작업",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          _buildActionButton(
            "데이터 새로고침",
            Icons.refresh_rounded,
            const Color(0xFF00FF88),
            _loadStats,
          ),
          const SizedBox(height: 16),
          // Additional quick actions can be added here
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12),
            color: color.withOpacity(0.05),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
