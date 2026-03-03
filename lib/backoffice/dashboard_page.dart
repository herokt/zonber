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
  int _customMapCount = 0;
  int _todayActiveUsers = 0;
  int _androidUsers = 0;
  int _iosUsers = 0;
  int _guestUsers = 0;
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
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final results = await Future.wait([
        // 0. Total Users
        FirebaseFirestore.instance.collection('users').count().get(),
        // 1. Maps (for total play count)
        FirebaseFirestore.instance.collection('maps').get(),
        // 2. Custom maps count
        FirebaseFirestore.instance.collection('custom_maps').count().get(),
        // 3. Today active users
        FirebaseFirestore.instance
            .collection('users')
            .where('lastUpdated', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .count()
            .get(),
        // 4. Android users
        FirebaseFirestore.instance
            .collection('users')
            .where('platform', isEqualTo: 'Android')
            .count()
            .get(),
        // 5. iOS users
        FirebaseFirestore.instance
            .collection('users')
            .where('platform', isEqualTo: 'iOS')
            .count()
            .get(),
        // 6. Guest users
        FirebaseFirestore.instance
            .collection('users')
            .where('loginProvider', isEqualTo: 'Guest')
            .count()
            .get(),
        // 7. Recent users
        FirebaseFirestore.instance
            .collection('users')
            .orderBy('lastUpdated', descending: true)
            .limit(10)
            .get(),
      ]);

      final totalUsers = (results[0] as AggregateQuerySnapshot).count ?? 0;

      int totalGames = 0;
      for (var doc in (results[1] as QuerySnapshot).docs) {
        totalGames += (doc.data() as Map<String, dynamic>)['playCount'] as int? ?? 0;
      }

      final customMapCount = (results[2] as AggregateQuerySnapshot).count ?? 0;
      final todayActiveUsers = (results[3] as AggregateQuerySnapshot).count ?? 0;
      final androidUsers = (results[4] as AggregateQuerySnapshot).count ?? 0;
      final iosUsers = (results[5] as AggregateQuerySnapshot).count ?? 0;
      final guestUsers = (results[6] as AggregateQuerySnapshot).count ?? 0;
      final recentDocs = (results[7] as QuerySnapshot).docs;

      if (mounted) {
        setState(() {
          _totalUsers = totalUsers;
          _totalGames = totalGames;
          _customMapCount = customMapCount;
          _todayActiveUsers = todayActiveUsers;
          _androidUsers = androidUsers;
          _iosUsers = iosUsers;
          _guestUsers = guestUsers;
          _recentUsers = recentDocs;
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
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildStatCards(),
          const SizedBox(height: 12),
          _buildPlatformDistribution(),
          const SizedBox(height: 16),
          _buildRecentUsers(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Dashboard",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "오늘 ${DateFormat('yyyy년 MM월 dd일').format(DateTime.now())} 현황입니다.",
              style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6)),
            ),
          ],
        ),
        _buildActionButton(
          "새로고침",
          Icons.refresh_rounded,
          const Color(0xFF00FF88),
          _loadStats,
        ),
      ],
    );
  }

  Widget _buildStatCards() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildModernCard(
          title: "총 사용자",
          value: NumberFormat('#,###').format(_totalUsers),
          subtitle: "Total Users",
          icon: Icons.people_alt_rounded,
          gradientColors: [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
        ),
        _buildModernCard(
          title: "총 플레이",
          value: NumberFormat('#,###').format(_totalGames),
          subtitle: "Total Plays",
          icon: Icons.games_rounded,
          gradientColors: [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
        ),
        _buildModernCard(
          title: "오늘 활성 유저",
          value: NumberFormat('#,###').format(_todayActiveUsers),
          subtitle: "Today Active",
          icon: Icons.bolt_rounded,
          gradientColors: [const Color(0xFFFFD700), const Color(0xFFFF8C00)],
        ),
        _buildModernCard(
          title: "게스트 유저",
          value: NumberFormat('#,###').format(_guestUsers),
          subtitle: _totalUsers > 0
              ? "전체의 ${(_guestUsers / _totalUsers * 100).toStringAsFixed(1)}%"
              : "Guest Users",
          icon: Icons.person_outline_rounded,
          gradientColors: [const Color(0xFF9B59B6), const Color(0xFF8E44AD)],
        ),
      ],
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
      width: 220,
      height: 130,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: gradientColors.map((c) => c.withOpacity(0.2)).toList(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: gradientColors.first.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(icon, size: 90, color: gradientColors.first.withOpacity(0.1)),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: gradientColors.last, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
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
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
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

  Widget _buildPlatformDistribution() {
    final unknown = (_totalUsers - _androidUsers - _iosUsers).clamp(0, _totalUsers);
    final total = _totalUsers > 0 ? _totalUsers : 1;
    final loggedIn = _totalUsers - _guestUsers;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildDistributionCard(
          title: "로그인 유형",
          items: [
            _DistItem("로그인 유저", loggedIn, total, const Color(0xFF00FF88), Icons.verified_user_rounded),
            _DistItem("게스트", _guestUsers, total, const Color(0xFF9B59B6), Icons.person_outline_rounded),
          ],
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildDistributionCard(
          title: "플랫폼 분포",
          items: [
            _DistItem("Android", _androidUsers, total, const Color(0xFF3DD9EB), Icons.android),
            _DistItem("iOS", _iosUsers, total, Colors.white, Icons.apple),
            _DistItem("Unknown", unknown, total, const Color(0xFF9E9E9E), Icons.help_outline_rounded),
          ],
        )),
      ],
    );
  }

  Widget _buildDistributionCard({required String title, required List<_DistItem> items}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
          const SizedBox(height: 14),
          Row(
            children: items.map((item) => Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(item.icon, size: 13, color: item.color),
                    const SizedBox(width: 5),
                    Text(item.label, style: TextStyle(color: item.color.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    NumberFormat('#,###').format(item.count),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "${(item.count / item.total * 100).toStringAsFixed(1)}%",
                    style: TextStyle(color: item.color.withOpacity(0.7), fontSize: 11),
                  ),
                ],
              ),
            )).toList(),
          ),
          const SizedBox(height: 14),
          // 세그먼트 바
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: items.where((i) => i.count > 0).map((item) => Flexible(
                  flex: item.count,
                  child: Container(color: item.color.withOpacity(0.75)),
                )).toList(),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: items.map((item) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: item.color.withOpacity(0.75), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                Text(item.label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ]),
            )).toList(),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              "최근 활동 사용자",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
          ),
          if (_recentUsers.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text("데이터가 없습니다.", style: TextStyle(color: Colors.white54)),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      horizontalMargin: 12,
                      columnSpacing: 16,
                      headingRowHeight: 40,
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 52,
                      headingRowColor: WidgetStateProperty.all(const Color(0xFF2C2C2C)),
                      dataRowColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.hovered)) {
                          return Colors.white.withOpacity(0.05);
                        }
                        return Colors.transparent;
                      }),
                      columns: const [
                        DataColumn(label: Text('닉네임', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13))),
                        DataColumn(label: Text('이메일 / UID', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13))),
                        DataColumn(label: Text('플랫폼', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13))),
                        DataColumn(label: Text('총 플레이', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13))),
                        DataColumn(label: Text('최근 활동', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13))),
                      ],
                      rows: _recentUsers.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final lastUpdated = (data['lastUpdated'] as Timestamp?)?.toDate();
                        final dateStr = lastUpdated != null
                            ? DateFormat('MM/dd HH:mm').format(lastUpdated)
                            : '-';
                        final email = data['email'] as String? ?? '';
                        final displayId = email.isNotEmpty ? email : doc.id;
                        return DataRow(cells: [
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                (data['flag'] == null || data['flag'].toString().isEmpty) ? '🏳️' : data['flag'],
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                data['nickname'] ?? '-',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          )),
                          DataCell(
                            Tooltip(
                              message: doc.id,
                              child: Text(
                                displayId,
                                style: TextStyle(
                                  color: email.isNotEmpty ? Colors.white70 : Colors.white30,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(_buildPlatformIcon(data)),
                          DataCell(Text(
                            NumberFormat('#,###').format(data['totalGamesPlayed'] ?? 0),
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          )),
                          DataCell(Text(
                            dateStr,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(10),
            color: color.withOpacity(0.05),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformIcon(Map<String, dynamic> data) {
    final platform = data['platform'] as String? ?? '';
    IconData icon;
    Color color;
    switch (platform) {
      case 'Android':
        icon = Icons.android;
        color = const Color(0xFF3DD9EB);
        break;
      case 'iOS':
        icon = Icons.apple;
        color = Colors.white;
        break;
      default:
        icon = Icons.help_outline_rounded;
        color = const Color(0xFF9E9E9E);
    }
    return Tooltip(
      message: platform.isEmpty ? 'Unknown' : platform,
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _buildPlatformInfo(Map<String, dynamic> data) {
    final platform = data['platform'] as String? ?? 'Unknown';
    final loginProvider = data['loginProvider'] as String? ?? 'Unknown';

    IconData platformIcon;
    Color platformColor;

    switch (platform) {
      case 'Android':
        platformIcon = Icons.android;
        platformColor = const Color(0xFF3DD9EB);
        break;
      case 'iOS':
        platformIcon = Icons.apple;
        platformColor = Colors.white;
        break;
      case 'Web':
        platformIcon = Icons.web;
        platformColor = const Color(0xFFFF9800);
        break;
      default:
        platformIcon = Icons.help_outline_rounded;
        platformColor = const Color(0xFF9E9E9E);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: platformColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: platformColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(platformIcon, size: 11, color: platformColor.withOpacity(0.8)),
              const SizedBox(width: 4),
              Text(platform, style: TextStyle(fontSize: 11, color: platformColor, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(loginProvider, style: const TextStyle(fontSize: 9, color: Colors.white54)),
      ],
    );
  }
}

class _DistItem {
  final String label;
  final int count;
  final int total;
  final Color color;
  final IconData icon;
  const _DistItem(this.label, this.count, this.total, this.color, this.icon);
}
