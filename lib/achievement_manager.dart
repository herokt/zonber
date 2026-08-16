import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ---------------------------------------------------------------------------
// Achievement category
// ---------------------------------------------------------------------------

enum AchievementCategory { survival, national, global }

// ---------------------------------------------------------------------------
// Achievement definition
// ---------------------------------------------------------------------------

class AchievementDef {
  final String key;
  final String descKey;
  final IconData icon;
  final Color color;
  final AchievementCategory category;
  final bool Function(double survivalTime, int rank) check;

  const AchievementDef({
    required this.key,
    required this.descKey,
    required this.icon,
    required this.color,
    required this.category,
    required this.check,
  });
}

// ---------------------------------------------------------------------------
// Achievement registry — 9 total, ordered lowest → highest tier
// ---------------------------------------------------------------------------

// Survival (5 tiers)
const achSurvivor = AchievementDef(
  key: 'ach_survivor', descKey: 'ach_survivor_desc',
  icon: Icons.shield_outlined, color: Color(0xFF69F0AE),
  category: AchievementCategory.survival, check: _chkSurvivor,
);
const achVeteran = AchievementDef(
  key: 'ach_veteran', descKey: 'ach_veteran_desc',
  icon: Icons.shield, color: Color(0xFF00E5FF),
  category: AchievementCategory.survival, check: _chkVeteran,
);
const achElite = AchievementDef(
  key: 'ach_elite', descKey: 'ach_elite_desc',
  icon: Icons.bolt, color: Color(0xFFFF6D00),
  category: AchievementCategory.survival, check: _chkElite,
);
const achMaster = AchievementDef(
  key: 'ach_master', descKey: 'ach_master_desc',
  icon: Icons.whatshot, color: Color(0xFFE040FB),
  category: AchievementCategory.survival, check: _chkMaster,
);
const achLegend = AchievementDef(
  key: 'ach_legend', descKey: 'ach_legend_desc',
  icon: Icons.auto_awesome, color: Color(0xFFFFD700),
  category: AchievementCategory.survival, check: _chkLegend,
);

// National ranking (1 tier)
const achNatChampion = AchievementDef(
  key: 'ach_nat_champion', descKey: 'ach_nat_champion_desc',
  icon: Icons.emoji_events, color: Color(0xFFFF4081),
  category: AchievementCategory.national, check: _chkChampion,
);

// Global ranking (3 tiers)
const achGlobTop30 = AchievementDef(
  key: 'ach_glob_top30', descKey: 'ach_glob_top30_desc',
  icon: Icons.public_outlined, color: Color(0xFF448AFF),
  category: AchievementCategory.global, check: _chkTop30,
);
const achGlobTop10 = AchievementDef(
  key: 'ach_glob_top10', descKey: 'ach_glob_top10_desc',
  icon: Icons.public, color: Color(0xFF7C4DFF),
  category: AchievementCategory.global, check: _chkTop10,
);
const achGlobChampion = AchievementDef(
  key: 'ach_glob_champion', descKey: 'ach_glob_champion_desc',
  icon: Icons.stars, color: Color(0xFFFFFFFF),
  category: AchievementCategory.global, check: _chkChampion,
);

const List<AchievementDef> survivalAchs = [
  achSurvivor, achVeteran, achElite, achMaster, achLegend,
];
const List<AchievementDef> nationalAchs = [
  achNatChampion,
];
const List<AchievementDef> globalAchs = [
  achGlobTop30, achGlobTop10, achGlobChampion,
];

/// All achievements ordered lowest → highest (used for highestFrom)
const List<AchievementDef> allAchs = [
  achSurvivor, achVeteran, achElite, achMaster, achLegend,
  achNatChampion,
  achGlobTop30, achGlobTop10, achGlobChampion,
];

/// Key → definition lookup
final Map<String, AchievementDef> achByKey = {
  for (final a in allAchs) a.key: a,
};

// Check stubs (top-level required for const)
bool _chkSurvivor(double t, int r)    => t >= 60;
bool _chkVeteran(double t, int r)     => t >= 120;
bool _chkElite(double t, int r)       => t >= 180;
bool _chkMaster(double t, int r)      => t >= 240;
bool _chkLegend(double t, int r)      => t >= 300;
bool _chkTop30(double t, int r)       => r > 0 && r <= 30;
bool _chkTop10(double t, int r)       => r > 0 && r <= 10;
bool _chkChampion(double t, int r)    => r == 1;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Fallback: survival achievements only from time (no rank needed).
List<AchievementDef> survivalEarned(double survivalTime) {
  final earned = survivalAchs.where((a) => a.check(survivalTime, 0)).toList();
  return earned.isNotEmpty ? earned : [];
}

/// Returns earned achievements from stored keys.
/// Falls back to survival-only computation if keys empty.
List<AchievementDef> earnedFromKeys(
  List<String> storedKeys,
  double survivalTime,
) {
  if (storedKeys.isNotEmpty) {
    final defs = storedKeys
        .map((k) => achByKey[k])
        .whereType<AchievementDef>()
        .toList();
    if (defs.isNotEmpty) {
      final order = { for (final a in allAchs) a.key: allAchs.indexOf(a) };
      defs.sort((a, b) => (order[a.key] ?? 0).compareTo(order[b.key] ?? 0));
      return defs;
    }
  }
  return survivalEarned(survivalTime);
}

/// Returns the single highest achievement from a list (last = highest tier).
/// Falls back to achSurvivor if list is empty.
AchievementDef highestFrom(List<AchievementDef> earned) =>
    earned.isNotEmpty ? earned.last : achSurvivor;

// ---------------------------------------------------------------------------
// AchievementManager — persistence
// ---------------------------------------------------------------------------

class AchievementManager {
  static const String _keyAchievements = 'user_achievements';

  /// Adds new keys to the user's permanent achievement set.
  static Future<void> unlock(List<String> newKeys) async {
    if (newKeys.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = Set<String>.from(
      prefs.getStringList(_keyAchievements) ?? [],
    );
    final merged = {...existing, ...newKeys}.toList();
    await prefs.setStringList(_keyAchievements, merged);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'achievements': merged}, SetOptions(merge: true));
      } catch (e) {
        print('Achievement sync failed: $e');
      }
    }
  }

  /// Returns the current user's locally cached achievement keys.
  static Future<List<String>> getMine() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyAchievements) ?? [];
  }

  /// Fetches another user's achievements from Firestore by their UID.
  static Future<List<String>> getForUser(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        return List<String>.from(doc.data()?['achievements'] ?? []);
      }
    } catch (e) {
      print('Failed to fetch achievements for $userId: $e');
    }
    return [];
  }

  /// Syncs achievements from Firestore to local cache (called on login/sync).
  static Future<void> syncFromFirestore(List<String> remoteKeys) async {
    if (remoteKeys.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final local = Set<String>.from(
      prefs.getStringList(_keyAchievements) ?? [],
    );
    final merged = {...local, ...remoteKeys}.toList();
    await prefs.setStringList(_keyAchievements, merged);
  }

  /// Clears local cache (called on logout).
  static Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAchievements);
  }

  /// Survival achievement keys for a given time.
  static List<String> survivalKeys(double survivalTime) {
    return survivalAchs
        .where((a) => a.check(survivalTime, 0))
        .map((a) => a.key)
        .toList();
  }

  /// National ranking achievement keys (only champion).
  static List<String> nationalRankKeys(int rank) {
    return nationalAchs
        .where((a) => a.check(0, rank))
        .map((a) => a.key)
        .toList();
  }

  /// Global ranking achievement keys (top30, top10, champion).
  static List<String> globalRankKeys(int rank) {
    return globalAchs
        .where((a) => a.check(0, rank))
        .map((a) => a.key)
        .toList();
  }
}
