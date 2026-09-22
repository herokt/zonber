import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────
// 코인 — 판마다 버틴 시간만큼 쌓이고, 상점에서 외형(캐릭터)·변경권을 산다.
// 능력치를 파는 물건은 없다(랭킹 공정성). docs/SHOP.md
//
// SharedPreferences(로컬) + Firestore users/{uid}.coins · ownedItems(원격, 로그인 유저만).
// 값이 바뀔 때마다 원격에 덮어쓰므로 원격이 최신이다 → 로그인 시 원격 값을 따른다.
// 게스트로 모은 코인은 처음 로그인한 계정에 원격 값이 없을 때만 그대로 올라간다.
// ─────────────────────────────────────────────────────────────
class CoinStore {
  static const _keyCoins = 'coins';
  static const _keyOwned = 'owned_items';
  static const _keyEquipped = 'equipped_items'; // 'trail:trail_sparkle' 형식 목록

  /// 5초 버틸 때마다 1코인(최소 1)
  static const double secondsPerCoin = 5;

  /// 현재 잔액 — 홈·상점·결과 화면이 구독한다
  static final ValueNotifier<int> balance = ValueNotifier<int>(0);
  static Set<String> _owned = {};
  /// 꾸미기 착용 — 종류(trail/aura) → 아이템 id
  static Map<String, String> _equipped = {};
  static bool _loaded = false;

  static int coinsForRun(double survivalTime) => max(1, (survivalTime / secondsPerCoin).floor());

  /// 추가 기록 보너스 코인 — 스테이지마다 난이도를 비슷하게 맞춰서 모두 1번에 1개
  ///   (근접 회피 · 아슬 회피 · 연속 선방. 세는 기준은 Player 의 _grazeRing · _closeDodgeRing · _streakWindow)
  static int bonusFor(String statKey, int count) =>
      const {'graze', 'close_dodge', 'save_streak'}.contains(statKey) ? count : 0;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    balance.value = prefs.getInt(_keyCoins) ?? 0;
    _owned = (prefs.getStringList(_keyOwned) ?? const []).toSet();
    _equipped = {
      for (final e in prefs.getStringList(_keyEquipped) ?? const <String>[])
        if (e.contains(':')) e.substring(0, e.indexOf(':')): e.substring(e.indexOf(':') + 1),
    };
    _loaded = true;
  }

  static Future<void> _ensure() async {
    if (!_loaded) await load();
  }

  static Future<void> _save({bool remote = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCoins, balance.value);
    await prefs.setStringList(_keyOwned, _owned.toList());
    await prefs.setStringList(_keyEquipped, [for (final e in _equipped.entries) '${e.key}:${e.value}']);
    if (remote) await _syncRemote();
  }

  static Future<void> _syncRemote() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'coins': balance.value,
        'ownedItems': _owned.toList(),
        'equipped': _equipped,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('CoinStore sync failed: $e');
    }
  }

  static Future<void> add(int amount) async {
    if (amount <= 0) return;
    await _ensure();
    balance.value += amount;
    await _save();
  }

  /// 잔액이 모자라면 false (아무것도 바뀌지 않는다)
  static Future<bool> spend(int amount) async {
    await _ensure();
    if (amount < 0 || balance.value < amount) return false;
    balance.value -= amount;
    await _save();
    return true;
  }

  static bool owns(String itemId) => _owned.contains(itemId);

  /// 착용 중인 꾸미기 id (없으면 [fallback])
  static String equipped(String kind, String fallback) => _equipped[kind] ?? fallback;

  static Future<void> equip(String kind, String itemId) async {
    await _ensure();
    _equipped[kind] = itemId;
    await _save();
  }

  /// 코인으로 산다. 이미 가졌거나 잔액이 모자라면 false
  static Future<bool> buy(String itemId, int price) async {
    await _ensure();
    if (_owned.contains(itemId) || balance.value < price) return false;
    balance.value -= price;
    _owned.add(itemId);
    await _save();
    return true;
  }

  /// 로그인 시 원격과 합친다 — 원격 잔액이 있으면 그것을 따르고, 보유 목록은 합친다
  static Future<void> mergeFromRemote(Map<String, dynamic> userDoc) async {
    await _ensure();
    final remoteCoins = userDoc['coins'];
    final remoteOwned = userDoc['ownedItems'];
    if (remoteOwned is List) _owned.addAll(remoteOwned.whereType<String>());
    final remoteEquipped = userDoc['equipped'];
    if (remoteEquipped is Map) {
      remoteEquipped.forEach((k, v) {
        if (k is String && v is String) _equipped[k] = v;
      });
    }
    if (remoteCoins is num) {
      balance.value = remoteCoins.toInt();
      await _save(remote: remoteOwned is! List || remoteOwned.length != _owned.length);
    } else {
      await _save(); // 원격에 없던 계정 — 로컬 값을 올린다
    }
  }

  /// 로그아웃 — 다음 게스트/계정에 코인이 넘어가지 않게 비운다
  static Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCoins);
    await prefs.remove(_keyOwned);
    await prefs.remove(_keyEquipped);
    balance.value = 0;
    _owned = {};
    _equipped = {};
  }
}
