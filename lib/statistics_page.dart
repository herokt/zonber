import 'package:flutter/material.dart';
import 'design_system.dart';
import 'user_profile.dart';
import 'ranking_system.dart';
import 'language_manager.dart';

class StatisticsPage extends StatefulWidget {
  final VoidCallback onBack;

  const StatisticsPage({super.key, required this.onBack});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  Map<String, dynamic> _stats = {};
  List<String> _titles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load Stats
    final stats = await UserProfileManager.getStatistics();
    
    // Load Titles (Check Zone 1 Classic as default for now)
    // In a full implementation, we might check all unlocked maps or the favorite map.
    final profile = await UserProfileManager.getProfile();
    final nickname = profile['nickname'] ?? '';
    
    // We check the most popular map for titles to avoid spamming the DB
    // Or we could check the "Favorite Map" from stats.
    String targetMap = stats['favoriteMap'] != '-' ? stats['favoriteMap'] : 'zone_1_classic';
    
    final titles = await RankingSystem().getUserTitles(targetMap, nickname);

    if (mounted) {
      setState(() {
        _stats = stats;
        _titles = titles;
        _loading = false;
      });
    }
  }

  String _formatDuration(double seconds) {
    if (seconds == 0) return "0s";
    Duration duration = Duration(milliseconds: (seconds * 1000).toInt());
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    
    if (duration.inHours > 0) {
      return "${duration.inHours}h ${twoDigits(duration.inMinutes.remainder(60))}m";
    } else if (duration.inMinutes > 0) {
      return "${duration.inMinutes}m ${twoDigits(duration.inSeconds.remainder(60))}s";
    } else {
      return "${seconds.toStringAsFixed(1)}s";
    }
  }

  @override
  Widget build(BuildContext context) {
    // Colors for Titles
    final Map<String, Color> titleColors = {
      'Daily Ranker': Color(0xFFFF8C00), // Dark Orange
      'Weekly Ranker': Color(0xFFC0C0C0), // Silver
      'Monthly Ranker': Color(0xFFFFD700), // Gold
      'Legendary Survivor': Color(0xFFE5E4E2), // Platinum
    };

    final Map<String, IconData> titleIcons = {
      'Daily Ranker': Icons.sunny,
      'Weekly Ranker': Icons.calendar_view_week,
      'Monthly Ranker': Icons.calendar_month,
      'Legendary Survivor': Icons.workspace_premium, // Trophy
    };

    return NeonScaffold(
      title: "STATISTICS",
      showBackButton: true,
      onBack: widget.onBack,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   // --- TITLES SECTION ---
                  Text(
                    "TITLES (Top 30)",
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_titles.isEmpty)
                    NeonCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.emoji_events_outlined, color: AppColors.textDim, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            "No Titles Yet",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Rank in the Top 30 to earn titles!",
                            style: TextStyle(color: AppColors.textDim, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: _titles.map((title) {
                        Color color = titleColors[title] ?? AppColors.primary;
                        IconData icon = titleIcons[title] ?? Icons.star;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, color: color, size: 28),
                              const SizedBox(height: 8),
                              Text(
                                title.toUpperCase(),
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  shadows: [Shadow(color: color, blurRadius: 5)],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 32),
                  
                  // --- STATISTICS SECTION ---
                  Text(
                    "GAME STATS",
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Grid for Stats
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.3,
                    children: [
                      // Total Play Time
                      _buildStatCard(
                        "TOTAL PLAY TIME",
                        _formatDuration(_stats['totalPlayTime'] ?? 0.0),
                        Icons.timer,
                        AppColors.primary,
                      ),
                      // Total Games
                      _buildStatCard(
                        "GAMES PLAYED",
                        "${_stats['totalGamesPlayed'] ?? 0}",
                        Icons.videogame_asset,
                        const Color(0xFFFF00DE), // Magenta
                      ),
                      // Favorite Map
                      _buildStatCard(
                        "FAVORITE MAP",
                        (_stats['favoriteMap'] ?? '-').toString().replaceAll('_', ' ').toUpperCase(),
                        Icons.map,
                        const Color(0xFF00FF88), // Green
                      ),
                      // Avg Survival (Derived)
                      _buildStatCard(
                        "AVG SURVIVAL",
                        _formatDuration(
                          (_stats['totalGamesPlayed'] ?? 0) > 0 
                            ? (_stats['totalPlayTime'] ?? 0.0) / (_stats['totalGamesPlayed'] ?? 1) 
                            : 0
                        ),
                        Icons.functions,
                        const Color(0xFFFFD700), // Yellow
                      )
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return NeonCard(
      padding: const EdgeInsets.all(16),
      borderColor: color.withOpacity(0.3),
      backgroundColor: color.withOpacity(0.05),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textDim,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 10)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
