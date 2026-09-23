import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_service.dart';

// 뱃지(업적) 저장소 — 얻은 뱃지 키를 prefs + users/{uid}.achievements 에 둔다.
// 뱃지 정의·조건은 badges.dart(Badges). 옛 업적 키(ach_*)는 그대로 뱃지로 이어진다.

// ---------------------------------------------------------------------------
// AchievementManager — persistence
// ---------------------------------------------------------------------------

class AchievementManager {
  static const String _keyAchievements = 'user_achievements';

  /// Adds new keys to the user's permanent achievement set.
  static Future<void> unlock(List<String> newKeys) async {
    if (newKeys.isEmpty || AuthService.isGuest) return; // 게스트는 뱃지를 얻지 않는다
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
        debugPrint('Achievement sync failed: $e');
      }
    }
  }

  /// Returns the current user's locally cached achievement keys.
  static Future<List<String>> getMine() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyAchievements) ?? [];
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
}
