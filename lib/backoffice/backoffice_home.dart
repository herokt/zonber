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
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('대시보드'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('사용자 관리'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bar_chart),
                label: Text('스테이지 통계'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}
