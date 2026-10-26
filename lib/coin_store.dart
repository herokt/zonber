import 'balance.dart';
import 'cosmetics.dart';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/analytics_service.dart';
import 'services/auth_service.dart';
import 'store_shot.dart';

// ─────────────────────────────────────────────────────────────
// 코인 — 판마다 버틴 시간 · 추가 기록 · 일일 미션으로 쌓이고, 상점에서 캐릭터·장비·꾸미기·펫을 산다(전부 외형). docs/SHOP.md
//
// SharedPreferences(로컬) + Firestore users/{uid}.coins · ownedItems · equipped(원격, 회원만).
// 값이 바뀔 때마다 원격에 덮어쓰므로 원격이 최신이다 → 로그인 시 원격 값을 따른다.
// 게스트(로그인 안 함)는 판 코인을 **이 기기에만**(coins_guest) 모은다 — 쓰지는 못하고, 로그인하면 계정 잔액에 합쳐진다(2026-10-26).
// ─────────────────────────────────────────────────────────────
class CoinStore {
  static const _keyCoins = 'coins';
  static const _keyOwned = 'owned_items';
  static const _keyEquipped = 'equipped_items'; // 'trail:trail_sparkle' 형식 목록
  static const _keyGuest = 'coins_guest'; // 게스트가 이 기기에서 모은 코인 — 로그인하면 잔액에 합치고 지운다

  /// 5초 버틸 때마다 1코인(최소 1)
  static const double secondsPerCoin = Balance.secondsPerCoin;

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
      const {'graze', 'close_dodge', 'save_streak'}.contains(statKey) ? count * Balance.bonusCoinsPerStat : 0;

  static Future<void> load() async {
    if (kStoreShot && _loaded) return; // 스토어 스크린샷 — storeShotReset 값을 유지
    final prefs = await SharedPreferences.getInstance();
    if (AuthService.isGuest) {
      // 게스트 — 이 기기에서 모은 코인만. 보유·착용은 없다
      balance.value = prefs.getInt(_keyGuest) ?? 0;
      _owned = {};
      _equipped = {};
      _loaded = true;
      return;
    }
    balance.value = prefs.getInt(_keyCoins) ?? 0;
    _owned = (prefs.getStringList(_keyOwned) ?? const []).toSet();
    _equipped = {
      for (final e in prefs.getStringList(_keyEquipped) ?? const <String>[])
        if (e.contains(':')) e.substring(0, e.indexOf(':')): e.substring(e.indexOf(':') + 1),
    };
    _loaded = true;
    // 예전 펫 슬롯 → 오라(2026-10-26). 옮겼으면 기기·서버에 다시 쓴다
    if (Cosmetics.migrateEquipped(_equipped)) await _save();
  }

  /// 스토어 스크린샷 모드 — 처음 시작한 사람처럼(코인 0 · 기본 아이템만). 메모리만 바꾸고 저장하지 않는다
  static void storeShotReset() {
    balance.value = 0;
    _owned = {};
    _equipped = {'aura': 'pet_cat'}; // 스크린샷에 펫(오라)이 같이 돈다
    _loaded = true;
  }

  static Future<void> _ensure() async {
    if (!_loaded) await load();
  }

  static Future<void> _save({bool remote = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (AuthService.isGuest) {
      await prefs.setInt(_keyGuest, balance.value); // 게스트는 기기에만
      return;
    }
    await prefs.setInt(_keyCoins, balance.value);
    await prefs.setStringList(_keyOwned, _owned.toList());
    await prefs.setStringList(_keyEquipped, [for (final e in _equipped.entries) '${e.key}:${e.value}']);
    if (remote) await _syncRemote();
  }

  static Future<void> _syncRemote() async {
    try {
      // Firebase 가 없거나(초기화 실패·테스트) 로그인 전이면 기기에만 둔다
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) return;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'coins': balance.value,
        'ownedItems': _owned.toList(),
        // 예전 펫 슬롯은 지운다(2026-10-26 오라로 합침) — merge 라서 지우지 않으면 남는다
        'equipped': {..._equipped, 'pet': FieldValue.delete()},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('CoinStore sync failed: $e');
    }
  }

  /// [source] = 어디서 얻었나(분석용 — run · ad_double · mission · all_clear · check_in · promo · friend)
  static Future<void> add(int amount, {required String source}) async {
    if (amount <= 0) return;
    await _ensure();
    balance.value += amount;
    await _save();
    AnalyticsService().logEarnCoins(source: source, amount: amount);
  }

  /// 잔액이 모자라면 false (아무것도 바뀌지 않는다). [item] = 무엇에 썼나(분석용)
  static Future<bool> spend(int amount, {required String item}) async {
    await _ensure();
    if (amount < 0 || balance.value < amount) return false;
    balance.value -= amount;
    await _save();
    AnalyticsService().logSpendCoins(item: item, amount: amount);
    return true;
  }

  static bool owns(String itemId) => _owned.contains(itemId);
  static Iterable<String> get ownedIds => _owned;

  /// 무료로 준다(이미 쓰던 캐릭터 인정 등)
  static Future<void> grant(String itemId) async {
    await _ensure();
    if (_owned.add(itemId)) await _save();
  }

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
    AnalyticsService().logSpendCoins(item: itemId, amount: price);
    return true;
  }

  /// 로그인 시 원격과 합친다 — 원격 잔액이 있으면 그것을 따르고, 보유 목록은 합친다.
  /// 게스트로 이 기기에서 모은 코인(coins_guest)이 있으면 잔액에 더하고 지운다(한 번만)
  static Future<void> mergeFromRemote(Map<String, dynamic> userDoc) async {
    _loaded = false; // 게스트로 읽어 둔 값(보유 없음)을 버리고 회원 값으로 다시 읽는다
    await _ensure();
    final prefs = await SharedPreferences.getInstance();
    final guestCoins = prefs.getInt(_keyGuest) ?? 0;
    if (guestCoins > 0) {
      await prefs.remove(_keyGuest);
      AnalyticsService().logEarnCoins(source: 'guest_merge', amount: guestCoins);
    }
    final remoteCoins = userDoc['coins'];
    final remoteOwned = userDoc['ownedItems'];
    if (remoteOwned is List) _owned.addAll(remoteOwned.whereType<String>());
    final remoteEquipped = userDoc['equipped'];
    if (remoteEquipped is Map) {
      remoteEquipped.forEach((k, v) {
        if (k is String && v is String) _equipped[k] = v;
      });
    }
    final migrated = Cosmetics.migrateEquipped(_equipped); // 예전 펫 슬롯 → 오라
    if (remoteCoins is num) {
      balance.value = remoteCoins.toInt() + guestCoins;
      await _save(remote: migrated || guestCoins > 0 || remoteOwned is! List || remoteOwned.length != _owned.length);
    } else {
      balance.value += guestCoins;
      await _save(); // 원격에 없던 계정 — 로컬 값을 올린다
    }
  }

  /// 로그아웃 — 다음 게스트/계정에 코인이 넘어가지 않게 비운다
  static Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCoins);
    await prefs.remove(_keyOwned);
    await prefs.remove(_keyEquipped);
    await prefs.remove(_keyGuest);
    balance.value = 0;
    _owned = {};
    _equipped = {};
  }
}
