import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _totalUsers = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // 1. Total Users
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .count()
          .get();

      if (mounted) {
        setState(() {
          _totalUsers = userSnapshot.count ?? 0;
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

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "대시보드",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              _buildStatCard(
                "총 가입자 수",
                "$_totalUsers 명",
                Icons.people,
                const Color(0xFF00FF88),
              ),
              // Future: Add more stats here
            ],
          ),
          const SizedBox(height: 48),
          const Text(
            "빠른 작업",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            children: [
              ElevatedButton.icon(
                onPressed: _loadStats,
                icon: const Icon(Icons.refresh),
                label: const Text("데이터 새로고침"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 32),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_forward, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            value,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
