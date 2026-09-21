import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:country_picker/country_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'design_system.dart';

import 'language_manager.dart';
import 'achievement_manager.dart';
import 'progress_store.dart';
import 'coin_store.dart';

class UserProfileManager {
  static const String _keyNickname = 'user_nickname';
  static const String _keyFlag = 'user_flag_code';
  static const String _keyCountryName = 'user_country_name';
  static const String _keyCharacterId = 'user_character_id';
  static const String _keyInitialSetupDone = 'initial_setup_done';
  static const String _keyNicknameTicket = 'nickname_change_ticket';
  static const String _keyCountryTicket = 'country_change_ticket';
  static const String _keyAdsRemoved = 'ads_removed';
  static const String _keyManuallyResetPurchases = 'manually_reset_purchases';
  static const String _keyIsGuest = 'is_guest_mode';
  static const String _keyFirstEdit = 'first_edit_available';

  // Statistics Keys
  static const String _keyTotalPlayTime = 'stats_total_play_time';
  static const String _keyTotalGamesPlayed = 'stats_total_games_played';
  static const String _keyMapPlayCounts =
      'stats_map_play_counts'; // JSON encoded map
  static const String _keyCharacterPlayCounts =
      'stats_character_play_counts'; // JSON encoded map

  // Helper method to detect current platform
  static String _getCurrentPlatform() {
    if (kIsWeb) {
      return 'Web';
    } else if (!kIsWeb) {
      if (Platform.isAndroid) {
        return 'Android';
      } else if (Platform.isIOS) {
        return 'iOS';
      } else if (Platform.isMacOS) {
        return 'macOS';
      } else if (Platform.isWindows) {
        return 'Windows';
      } else if (Platform.isLinux) {
        return 'Linux';
      }
    }
    return 'Unknown';
  }

  // Helper method to detect login provider
  static String _getLoginProvider(User? user) {
    if (user == null) return 'None';

    if (user.isAnonymous) {
      return 'Guest';
    }

    for (var info in user.providerData) {
      if (info.providerId == 'google.com') {
        return 'Google';
      }
      if (info.providerId == 'apple.com') {
        return 'Apple';
      }
      if (info.providerId == 'password') {
        return 'Email';
      }
    }

    return 'Unknown';
  }

  /// 가입 완료 조건 — 닉네임과 국가(국기·이름)를 모두 골랐다
  static bool isCompleteProfile(String? nickname, String? flag, String? countryName) {
    final n = (nickname ?? '').trim();
    return n.isNotEmpty && n != 'Unknown' && (flag ?? '').isNotEmpty && (countryName ?? '').isNotEmpty;
  }

  static Future<bool> hasProfile() async {
    print('=== CHECKING PROFILE ===');
    final prefs = await SharedPreferences.getInstance();
    final localSetupDone = prefs.getBool(_keyInitialSetupDone) ?? false;
    print('Local setup done: $localSetupDone');

    if (localSetupDone) {
      final guestFlagSet = prefs.getBool(_keyIsGuest) ?? false;
      final authUser = FirebaseAuth.instance.currentUser;
      final isAnonymous = authUser == null || authUser.isAnonymous;

      if (guestFlagSet && isAnonymous) {
        // 게스트는 랭킹 등록 자체가 불가능하므로 국가를 강제하지 않는다.
        // (첫 플레이 전 폼 입력은 하이퍼캐주얼에서 이탈로 직결됨 —
        //  실제 계정으로 전환하는 시점에 받는다)
        return true;
      }

      if (guestFlagSet && !isAnonymous) {
        // 게스트 → 정식 계정 전환. 닉네임·국가를 새로 받아야 하므로
        // 최초 설정 화면으로 되돌린다.
        print('Guest upgraded to a real account — requiring profile setup');
        await prefs.setBool(_keyIsGuest, false);
        await prefs.setBool(_keyInitialSetupDone, false);
        return false;
      }

      final nickname = prefs.getString(_keyNickname) ?? '';
      final flag = prefs.getString(_keyFlag) ?? '';
      final countryName = prefs.getString(_keyCountryName) ?? '';
      if (isCompleteProfile(nickname, flag, countryName)) {
        print('Profile found locally');
        return true;
      }
      // 닉네임·국가 중 하나라도 비었으면 로컬로는 가입 미완료 — 원격을 확인하고, 거기도 없으면 설정 화면
      print('Local profile incomplete — checking remote');
    }

    // Check remote if not found locally
    final user = FirebaseAuth.instance.currentUser;
    print('Firebase user: ${user?.uid ?? "not logged in"}');

    if (user != null) {
      try {
        print('Fetching profile from Firestore...');
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        print('Firestore document exists: ${doc.exists}');

        if (doc.exists) {
          final data = doc.data()!;
          print('Profile data from Firestore: $data');

          await prefs.setString(_keyNickname, data['nickname'] ?? 'Unknown');
          await prefs.setString(_keyFlag, data['flag'] ?? '');
          await prefs.setString(_keyCountryName, data['countryName'] ?? '');
          await prefs.setString(
            _keyCharacterId,
            data['characterId'] ?? 'neon_green',
          );
          // Sync First Edit Status
          if (data['firstEditUsed'] == true) {
            await prefs.setBool(_keyFirstEdit, false);
          }
          await prefs.setInt(_keyNicknameTicket, data['nicknameTickets'] ?? 0);
          await prefs.setInt(_keyCountryTicket, data['countryTickets'] ?? 0);
          await prefs.setBool(_keyAdsRemoved, data['adsRemoved'] ?? false);

          // Stats Sync
          await prefs.setDouble(
            _keyTotalPlayTime,
            (data['totalPlayTime'] ?? 0).toDouble(),
          );
          await prefs.setInt(
            _keyTotalGamesPlayed,
            data['totalGamesPlayed'] ?? 0,
          );
          if (data['mapPlayCounts'] != null) {
            await prefs.setString(_keyMapPlayCounts, jsonEncode(data['mapPlayCounts']));
          }
          if (data['characterPlayCounts'] != null) {
            await prefs.setString(_keyCharacterPlayCounts, jsonEncode(data['characterPlayCounts']));
          }

          // Sync manual reset flags
          if (data['manuallyResetPurchases'] != null) {
            List<String> resetList = List<String>.from(
              data['manuallyResetPurchases'],
            );
            await prefs.setStringList(_keyManuallyResetPurchases, resetList);
          }

          // 닉네임·국가를 다 고른 계정만 가입 완료. 하나라도 비었으면 설정 화면으로
          if (!isCompleteProfile(data['nickname'] as String?, data['flag'] as String?, data['countryName'] as String?)) {
            print('Firestore profile incomplete — requiring profile setup');
            await prefs.setBool(_keyInitialSetupDone, false);
            return false;
          }

          await prefs.setBool(_keyInitialSetupDone, true);

          // Sync achievements from Firestore to local cache
          final remoteAchievements =
              List<String>.from(data['achievements'] ?? []);
          if (remoteAchievements.isNotEmpty) {
            await AchievementManager.syncFromFirestore(remoteAchievements);
          }
          // 월드별 최고 기록·명패 병합
          {
            await ProgressStore.mergeFromRemote(data);
            await CoinStore.mergeFromRemote(data);
          }

          // Update platform and login info on sync
          try {
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'platform': _getCurrentPlatform(),
              'loginProvider': _getLoginProvider(user),
              'email': user.email ?? '',
              'lastUpdated': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (e) {
            print("Error updating platform info: $e");
          }

          print('Profile synced from Firestore to local');
          return true;
        } else {
          print('No profile found in Firestore');
        }
      } catch (e) {
        print("ERROR fetching profile from Firestore: $e");
      }
    }

    print('No profile found');
    return false;
  }

  // Force sync from remote to local
  static Future<void> syncProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyNickname, data['nickname'] ?? 'Unknown');
        await prefs.setString(_keyFlag, data['flag'] ?? '');
        await prefs.setString(_keyCountryName, data['countryName'] ?? '');
        await prefs.setString(
          _keyCharacterId,
          data['characterId'] ?? 'neon_green',
        );
        // Sync First Edit Status
        if (data['firstEditUsed'] == true) {
          await prefs.setBool(_keyFirstEdit, false);
        }
        await prefs.setInt(_keyNicknameTicket, data['nicknameTickets'] ?? 0);
        await prefs.setInt(_keyCountryTicket, data['countryTickets'] ?? 0);
        await prefs.setBool(_keyAdsRemoved, data['adsRemoved'] ?? false);

        // Stats Sync
        await prefs.setDouble(
          _keyTotalPlayTime,
          (data['totalPlayTime'] ?? 0).toDouble(),
        );
        await prefs.setInt(_keyTotalGamesPlayed, data['totalGamesPlayed'] ?? 0);
        if (data['mapPlayCounts'] != null) {
          await prefs.setString(_keyMapPlayCounts, jsonEncode(data['mapPlayCounts']));
        }
        if (data['characterPlayCounts'] != null) {
          await prefs.setString(_keyCharacterPlayCounts, jsonEncode(data['characterPlayCounts']));
        }

        // Sync manual reset flags
        if (data['manuallyResetPurchases'] != null) {
          List<String> resetList = List<String>.from(
            data['manuallyResetPurchases'],
          );
          await prefs.setStringList(_keyManuallyResetPurchases, resetList);
        }

        await prefs.setBool(_keyInitialSetupDone, true);
      }
    } catch (e) {
      print("Error syncing profile: $e");
    }
  }

  static Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyNickname);
    await prefs.remove(_keyFlag);
    await prefs.remove(_keyCountryName);
    await prefs.remove(_keyCharacterId);
    await prefs.remove(_keyInitialSetupDone);
    await prefs.remove(_keyNicknameTicket);
    await prefs.remove(_keyCountryTicket);
    await prefs.remove(_keyAdsRemoved);
    await prefs.remove(_keyManuallyResetPurchases);
    await prefs.remove(_keyTotalPlayTime);
    await prefs.remove(_keyTotalGamesPlayed);
    await prefs.remove(_keyMapPlayCounts);
    await prefs.remove(_keyCharacterPlayCounts);
    await prefs.remove(_keyIsGuest);
    await prefs.remove(_keyFirstEdit);
    await AchievementManager.clearLocal();
  }

  // Guest Mode Methods
  static Future<bool> isGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsGuest) ?? false;
  }

  static Future<void> enableGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsGuest, true);
    // 게스트는 국가 선택 없이 바로 플레이할 수 있게 한다.
    // 국가는 로그인 후 점수를 등록하는 시점에 InitialSetupPage에서 받는다.
    await prefs.setBool(_keyInitialSetupDone, true);
    await prefs.setString(_keyNickname, 'Guest');
    await prefs.setString(_keyCharacterId, 'neon_green');
    await prefs.setBool(
      _keyFirstEdit,
      true,
    ); // Guest can edit profile once logged in
  }

  static Future<void> disableGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsGuest, false);
  }

  // First Edit (Free edit for first-time users)
  static Future<bool> isFirstEditAvailable() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFirstEdit) ?? true; // Default: available
  }

  static Future<void> useFirstEdit() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstEdit, false);

    // Sync to Firebase
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'firstEditUsed': true,
        }, SetOptions(merge: true));
      } catch (e) {
        print("Error syncing firstEdit to Firebase: $e");
      }
    }
  }

  static Future<Map<String, String>> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'nickname': prefs.getString(_keyNickname) ?? 'Unknown',
      'flag': prefs.getString(_keyFlag) ?? '',
      'countryName': prefs.getString(_keyCountryName) ?? 'Unknown Region',
      'characterId': prefs.getString(_keyCharacterId) ?? 'neon_green',
    };
  }

  static Future<Map<String, int>> getMapPlayCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyMapPlayCounts);
    if (jsonString != null) {
      try {
        final decoded = jsonDecode(jsonString);
        return Map<String, int>.from(decoded);
      } catch (e) {
        print("Error decoding play counts: $e");
      }
    }
    return {};
  }

  static Future<void> incrementMapPlayCount(String mapId) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, int> counts = await getMapPlayCounts();
    counts[mapId] = (counts[mapId] ?? 0) + 1;

    // Save Local
    await prefs.setString(_keyMapPlayCounts, jsonEncode(counts));

    // Attempt Sync Remote
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Use atomic increment for the specific map field
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'mapPlayCounts.$mapId': FieldValue.increment(1),
              'totalGamesPlayed': FieldValue.increment(1),
              'platform': _getCurrentPlatform(),
              'loginProvider': _getLoginProvider(user),
              'email': user.email ?? '',
              'lastUpdated': FieldValue.serverTimestamp(),
            });
      } catch (e) {
        print("Error syncing play count: $e");
      }
    }

    // Update local total games played too
    int total = prefs.getInt(_keyTotalGamesPlayed) ?? 0;
    await prefs.setInt(_keyTotalGamesPlayed, total + 1);
  }

  static Future<void> saveProfile(
    String nickname,
    String flag,
    String countryName, {
    String? characterId,
  }) async {
    print('=== SAVING PROFILE ===');
    print('Nickname: $nickname');
    print('Flag: $flag');
    print('Country: $countryName');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNickname, nickname);
    await prefs.setString(_keyFlag, flag);
    await prefs.setString(_keyCountryName, countryName);
    if (characterId != null) {
      await prefs.setString(_keyCharacterId, characterId);
    }
    await prefs.setBool(_keyInitialSetupDone, true);
    print('Profile saved to local storage');

    // Sync to Firestore
    final user = FirebaseAuth.instance.currentUser;
    print('Firebase user for sync: ${user?.uid ?? "not logged in"}');

    if (user != null) {
      try {
        print('Syncing to Firestore...');
        final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final existingDoc = await docRef.get();
        final Map<String, dynamic> profileData = {
          'nickname': nickname,
          'flag': flag,
          'countryName': countryName,
          'characterId':
              characterId ?? prefs.getString(_keyCharacterId) ?? 'neon_green',
          'nicknameTickets': prefs.getInt(_keyNicknameTicket) ?? 0,
          'countryTickets': prefs.getInt(_keyCountryTicket) ?? 0,
          'platform': _getCurrentPlatform(),
          'loginProvider': _getLoginProvider(user),
          'email': user.email ?? '',
          'lastUpdated': FieldValue.serverTimestamp(),
        };
        if (!existingDoc.exists || (existingDoc.data() as Map?)?.containsKey('createdAt') != true) {
          profileData['createdAt'] = FieldValue.serverTimestamp();
        }
        await docRef.set(profileData, SetOptions(merge: true));
        print('Profile synced to Firestore successfully');
      } catch (e) {
        print("ERROR saving to Firestore: $e");
      }
    } else {
      print('WARNING: Not logged in, skipping Firestore sync');
    }

    print('=== SAVE PROFILE END ===');
  }

  // markInitialSetupDone is now implicit in saveProfile but kept for compatibility
  static Future<void> markInitialSetupDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyInitialSetupDone, true);
  }

  static Future<int> getNicknameTickets() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyNicknameTicket) ?? 0;
  }

  static Future<int> getCountryTickets() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCountryTicket) ?? 0;
  }

  static Future<void> addNicknameTicket(int count) async {
    final prefs = await SharedPreferences.getInstance();
    int current = (prefs.getInt(_keyNicknameTicket) ?? 0) + count;
    await prefs.setInt(_keyNicknameTicket, current);
    _syncTickets(nickname: current);
  }

  static Future<void> addCountryTicket(int count) async {
    final prefs = await SharedPreferences.getInstance();
    int current = (prefs.getInt(_keyCountryTicket) ?? 0) + count;
    await prefs.setInt(_keyCountryTicket, current);
    _syncTickets(country: current);
  }

  static Future<void> setNicknameTickets(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyNicknameTicket, count);
    _syncTickets(nickname: count);
  }

  static Future<void> setCountryTickets(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCountryTicket, count);
    _syncTickets(country: count);
  }

  static Future<bool> useNicknameTicket() async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_keyNicknameTicket) ?? 0;
    if (current > 0) {
      int newVal = current - 1;
      await prefs.setInt(_keyNicknameTicket, newVal);
      _syncTickets(nickname: newVal);
      return true;
    }
    return false;
  }

  static Future<bool> useCountryTicket() async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_keyCountryTicket) ?? 0;
    if (current > 0) {
      int newVal = current - 1;
      await prefs.setInt(_keyCountryTicket, newVal);
      _syncTickets(country: newVal);
      return true;
    }
    return false;
  }

  static Future<void> _syncTickets({int? nickname, int? country}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        Map<String, dynamic> updates = {};
        if (nickname != null) updates['nicknameTickets'] = nickname;
        if (country != null) updates['countryTickets'] = country;
        if (updates.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(updates, SetOptions(merge: true));
        }
      } catch (e) {
        print("Error syncing tickets: $e");
      }
    }
  }

  static Future<bool> isAdsRemoved() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAdsRemoved) ?? false;
  }

  static Future<void> setAdsRemoved(bool value) async {
    print('📍 UserProfile: setAdsRemoved called with value=$value');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAdsRemoved, value);
    print('📍 UserProfile: Local storage updated, adsRemoved=$value');

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        print('📍 UserProfile: Syncing to Firebase for user ${user.uid}');
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'adsRemoved': value,
        }, SetOptions(merge: true));
        print('📍 UserProfile: Firebase sync SUCCESS, adsRemoved=$value');
      } catch (e) {
        print("❌ UserProfile: Error syncing adsRemoved to Firebase: $e");
      }
    } else {
      print('⚠️ UserProfile: No Firebase user, skipping remote sync');
    }
  }

  // Manual reset tracking (for testing purposes)
  static Future<void> markPurchaseAsManuallyReset(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> resetList =
        prefs.getStringList(_keyManuallyResetPurchases) ?? [];
    if (!resetList.contains(productId)) {
      resetList.add(productId);
      await prefs.setStringList(_keyManuallyResetPurchases, resetList);
      print('📍 Marked $productId as manually reset');
    }

    // Sync to Firebase
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'manuallyResetPurchases': resetList,
        }, SetOptions(merge: true));
        print('📍 Synced manual reset flags to Firebase');
      } catch (e) {
        print("❌ Error syncing manual reset to Firebase: $e");
      }
    }
  }

  static Future<bool> isPurchaseManuallyReset(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> resetList =
        prefs.getStringList(_keyManuallyResetPurchases) ?? [];
    return resetList.contains(productId);
  }

  static Future<void> clearManualResetFlag(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> resetList =
        prefs.getStringList(_keyManuallyResetPurchases) ?? [];
    if (resetList.contains(productId)) {
      resetList.remove(productId);
      await prefs.setStringList(_keyManuallyResetPurchases, resetList);
      print('📍 Cleared manual reset flag for $productId');
    }

    // Sync to Firebase
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'manuallyResetPurchases': resetList,
        }, SetOptions(merge: true));
        print('📍 Synced manual reset flags to Firebase');
      } catch (e) {
        print("❌ Error syncing manual reset to Firebase: $e");
      }
    }
  }

  // --- STATISTICS METHODS ---

  static Future<Map<String, dynamic>> getStatistics() async {
    final prefs = await SharedPreferences.getInstance();
    double totalTime = prefs.getDouble(_keyTotalPlayTime) ?? 0.0;
    int totalGames = prefs.getInt(_keyTotalGamesPlayed) ?? 0;

    Map<String, int> mapCounts = {};
    String? mapCountsJson = prefs.getString(_keyMapPlayCounts);
    if (mapCountsJson != null) {
      try {
        mapCounts = Map<String, int>.from(jsonDecode(mapCountsJson));
      } catch (e) {
        print("Error parsing map counts: $e");
      }
    }

    Map<String, int> characterCounts = {};
    String? charCountsJson = prefs.getString(_keyCharacterPlayCounts);
    if (charCountsJson != null) {
      try {
        characterCounts = Map<String, int>.from(jsonDecode(charCountsJson));
      } catch (e) {
        print("Error parsing character counts: $e");
      }
    }

    String favoriteMap = '-';
    int maxMapCount = 0;
    mapCounts.forEach((key, value) {
      if (value > maxMapCount) { maxMapCount = value; favoriteMap = key; }
    });

    String favoriteCharacter = '-';
    int maxCharCount = 0;
    characterCounts.forEach((key, value) {
      if (value > maxCharCount) { maxCharCount = value; favoriteCharacter = key; }
    });

    return {
      'totalPlayTime': totalTime,
      'totalGamesPlayed': totalGames,
      'favoriteMap': favoriteMap,
      'mapPlayCounts': mapCounts,
      'favoriteCharacter': favoriteCharacter,
      'characterPlayCounts': characterCounts,
    };
  }

  static Future<void> updateGameStats({
    required double playTime,
    required String mapId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    double currentTotalTime = prefs.getDouble(_keyTotalPlayTime) ?? 0.0;
    int currentTotalGames = prefs.getInt(_keyTotalGamesPlayed) ?? 0;

    currentTotalTime += playTime;
    currentTotalGames += 1;

    Map<String, int> mapCounts = {};
    String? mapCountsJson = prefs.getString(_keyMapPlayCounts);
    if (mapCountsJson != null) {
      try { mapCounts = Map<String, int>.from(jsonDecode(mapCountsJson)); } catch (_) {}
    }
    mapCounts[mapId] = (mapCounts[mapId] ?? 0) + 1;

    // Track character play counts
    final characterId = prefs.getString(_keyCharacterId) ?? 'neon_green';
    Map<String, int> characterCounts = {};
    String? charCountsJson = prefs.getString(_keyCharacterPlayCounts);
    if (charCountsJson != null) {
      try { characterCounts = Map<String, int>.from(jsonDecode(charCountsJson)); } catch (_) {}
    }
    characterCounts[characterId] = (characterCounts[characterId] ?? 0) + 1;

    await prefs.setDouble(_keyTotalPlayTime, currentTotalTime);
    await prefs.setInt(_keyTotalGamesPlayed, currentTotalGames);
    await prefs.setString(_keyMapPlayCounts, jsonEncode(mapCounts));
    await prefs.setString(_keyCharacterPlayCounts, jsonEncode(characterCounts));

    // Sync to Firebase
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final Map<String, dynamic> statsData = {
          'totalPlayTime': currentTotalTime,
          'totalGamesPlayed': currentTotalGames,
          'mapPlayCounts': mapCounts,
          'characterPlayCounts': characterCounts,
          'platform': _getCurrentPlatform(),
          'loginProvider': _getLoginProvider(user),
          'email': user.email ?? '',
          'lastUpdated': FieldValue.serverTimestamp(),
        };
        final docSnap = await docRef.get();
        if (!docSnap.exists || !(docSnap.data() as Map).containsKey('createdAt')) {
          statsData['createdAt'] = FieldValue.serverTimestamp();
        }
        await docRef.set(statsData, SetOptions(merge: true));
      } catch (e) {
        print("Error syncing stats: $e");
      }
    }

    // Increment global play count for this map (all plays, not just score submissions)
    try {
      await FirebaseFirestore.instance
          .collection('maps')
          .doc(mapId)
          .set({'playCount': FieldValue.increment(1)}, SetOptions(merge: true));
    } catch (e) {
      print("Error syncing map play count: $e");
    }
  }
}

class InitialSetupPage extends StatefulWidget {
  final VoidCallback onComplete;
  /// 가입 취소(게스트로 계속) — 닉네임·국가를 다 고르기 전에는 가입이 끝나지 않는다
  final VoidCallback? onCancel;

  const InitialSetupPage({super.key, required this.onComplete, this.onCancel});

  @override
  State<InitialSetupPage> createState() => _InitialSetupPageState();
}

class _InitialSetupPageState extends State<InitialSetupPage> {
  final TextEditingController _nicknameController = TextEditingController();
  String _selectedFlag = '';
  String _selectedCountryName = '';

  Future<void> _saveAndContinue() async {
    if (_nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(LanguageManager.of(context, listen: false).translate('setup_need_nickname'))));
      return;
    }
    if (_selectedCountryName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(LanguageManager.of(context, listen: false).translate('setup_need_country'))));
      return;
    }


    // Grant Initial Tickets (1 of each)
    await UserProfileManager.setNicknameTickets(1);
    await UserProfileManager.setCountryTickets(1);

    await UserProfileManager.saveProfile(
      _nicknameController.text.trim(),
      _selectedFlag,
      _selectedCountryName,
    );
    await UserProfileManager.markInitialSetupDone();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                LanguageManager.of(context).translate('welcome'),
                style: AppTextStyles.header.copyWith(fontSize: 48),
              ),
              const SizedBox(height: 8),
              Text(
                LanguageManager.of(context).translate('setup_profile'),
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textDim,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 40),
              NeonCard(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: 300,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _nicknameController,
                        style: AppTextStyles.body.copyWith(fontSize: 16),
                        maxLength: 8,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: LanguageManager.of(
                            context,
                          ).translate('setup_nickname_label'),
                          labelStyle: TextStyle(color: AppColors.textDim),
                          hintText: LanguageManager.of(
                            context,
                          ).translate('setup_nickname_hint'),
                          hintStyle: TextStyle(
                            color: AppColors.textDim.withOpacity(0.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.textDim),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          counterStyle: TextStyle(color: AppColors.textDim),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        LanguageManager.of(
                          context,
                        ).translate('setup_country_label'),
                        style: TextStyle(
                          color: AppColors.textDim,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _showCountryPicker(),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedFlag.isNotEmpty
                                  ? AppColors.primary
                                  : AppColors.textDim,
                              width: _selectedFlag.isNotEmpty ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_selectedFlag.isEmpty)
                                Text(
                                  LanguageManager.of(
                                    context,
                                  ).translate('tap_to_select'),
                                  style: TextStyle(
                                    color: AppColors.textDim,
                                    fontSize: 16,
                                  ),
                                )
                              else ...[
                                CountryChip(flag: _selectedFlag, height: 20),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    _selectedCountryName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_drop_down,
                                color: _selectedFlag.isNotEmpty
                                    ? AppColors.primary
                                    : AppColors.textDim,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: NeonButton(
                          text: LanguageManager.of(context).translate('start'),
                          onPressed: _saveAndContinue,
                          icon: Icons.play_arrow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.onCancel != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(
                    LanguageManager.of(context).translate('continue_guest'),
                    style: TextStyle(color: AppColors.textDim, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                LanguageManager.of(context).translate('setup_warning'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textDim.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      favorite: ['KR', 'US', 'JP'],
      onSelect: (Country country) {
        setState(() {
          _selectedFlag = country.flagEmoji;
          _selectedCountryName = country.name;
        });
      },
      countryListTheme: CountryListThemeData(
        backgroundColor: AppColors.surface,
        textStyle: const TextStyle(color: Colors.white),
        searchTextStyle: const TextStyle(color: Colors.white),
        bottomSheetHeight: 500,
        borderRadius: BorderRadius.circular(20),
        inputDecoration: InputDecoration(
          hintText: LanguageManager.of(context).translate('search_country'),
          hintStyle: TextStyle(color: AppColors.textDim),
          prefixIcon: Icon(Icons.search, color: AppColors.textDim),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.textDim),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}


class UserProfilePage extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback? onCancel;
  const UserProfilePage({super.key, required this.onComplete, this.onCancel});
  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  @override
  Widget build(BuildContext context) =>
      InitialSetupPage(onComplete: widget.onComplete, onCancel: widget.onCancel);
}
