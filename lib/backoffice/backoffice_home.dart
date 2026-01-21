import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'user_list_page.dart';
import 'stage_stats_page.dart';

class BackofficeHome extends StatefulWidget {
  const BackofficeHome({super.key});

  @override
  State<BackofficeHome> createState() => _BackofficeHomeState();
}

class _BackofficeHomeState extends State<BackofficeHome> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    const UserListPage(),
    const StageStatsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            backgroundColor: const Color(0xFF252525),
            indicatorColor: const Color(0xFF00FF88).withOpacity(0.2),
            selectedIconTheme: const IconThemeData(color: Color(0xFF00FF88)),
            unselectedIconTheme: const IconThemeData(color: Colors.white54),
            selectedLabelTextStyle: const TextStyle(
              color: Color(0xFF00FF88),
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white54),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_rounded),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('대시보드'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline_rounded),
                selectedIcon: Icon(Icons.people_rounded),
                label: Text('사용자 관리'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bar_chart_rounded),
                selectedIcon: Icon(Icons.bar_chart),
                label: Text('스테이지 통계'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Colors.white12),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}
