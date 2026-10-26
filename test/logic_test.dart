import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zonber/app_release.dart';
import 'package:zonber/audio_manager.dart';
import 'package:zonber/avatar.dart';
import 'package:zonber/badges.dart';
import 'package:zonber/balance.dart';
import 'package:zonber/coin_store.dart';
import 'package:zonber/cosmetics.dart';
import 'package:zonber/daily_rewards.dart';
import 'package:zonber/design_system.dart';
import 'package:zonber/player_profile.dart';
import 'package:zonber/friends.dart';
import 'package:zonber/inbox.dart';
import 'package:zonber/promotions.dart';
import 'package:zonber/push.dart';
import 'package:zonber/gear.dart';
import 'package:zonber/loadout.dart';
import 'package:zonber/pets.dart';
import 'package:zonber/season.dart';
import 'package:zonber/services/auth_service.dart';
import 'package:zonber/services/new_user_service.dart';
import 'package:zonber/services/share_service.dart';
import 'package:zonber/translations.dart';
import 'package:zonber/world_config.dart';

// Firebase 없이 도는 규칙 테스트 — flutter test
void main() {
  // 회원 기준으로 돈다(게스트는 아무것도 저장하지 않는다 — 아래 '게스트' 묶음)
  setUpAll(() => AuthService.debugIsGuest = false);

  group('게스트', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AuthService.debugIsGuest = true;
    });
    tearDown(() => AuthService.debugIsGuest = false);

    test('판을 해도 미션·출석은 없고, 코인만 이 기기(coins_guest)에 쌓인다 — 로그인하면 잔액에 합친다(2026-10-26)', () async {
      await DailyRewards.recordRun(stage: 1, time: 40, addedTime: 40, addedStat: 3, continued: false);
      await CoinStore.add(50, source: 'test');
      expect((await DailyRewards.missions()).every((s) => s.progress == 0), isTrue);
      expect(CoinStore.balance.value, 50);
      expect(await DailyRewards.claimAttendance(), 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('daily_progress'), isNull);
      expect(prefs.getInt('coins'), isNull); // 계정 코인은 아니다
      expect(prefs.getInt('coins_guest'), 50);
      // 로그인 — 계정 잔액에 더하고 기기 몫은 지운다(한 번만)
      AuthService.debugIsGuest = false;
      await CoinStore.mergeFromRemote({'coins': 120});
      expect(CoinStore.balance.value, 170);
      expect(prefs.getInt('coins_guest'), isNull);
      await CoinStore.mergeFromRemote({'coins': 170});
      expect(CoinStore.balance.value, 170); // 두 번 합치지 않는다
      await CoinStore.clearLocal();
    });
  });

  group('기록 시간', () {
    test('소수점 셋째 자리까지 버림', () {
      expect(recordTime(12.3456), 12.345);
      expect(recordTime(12.345), 12.345); // 12.345*1000 = 12344.999… 오차 보정
      expect(formatSurvival(7), '7.000');
    });
  });

  group('코인', () {
    test('5초마다 1개, 최소 1', () {
      expect(CoinStore.coinsForRun(0), 1);
      expect(CoinStore.coinsForRun(4.9), 1);
      expect(CoinStore.coinsForRun(25), 25 ~/ Balance.secondsPerCoin);
    });
    test('추가 기록 보너스는 스테이지 기록만', () {
      expect(CoinStore.bonusFor('graze', 7), 7 * Balance.bonusCoinsPerStat);
      expect(CoinStore.bonusFor('close_dodge', 3), 3 * Balance.bonusCoinsPerStat);
      expect(CoinStore.bonusFor('save_streak', 2), 2 * Balance.bonusCoinsPerStat);
      expect(CoinStore.bonusFor('unknown', 5), 0);
    });
  });

  group('스테이지', () {
    test('스테이지별 추가 기록 항목', () {
      final keys = {for (final w in WorldData.worlds) w.id: w.statKey};
      expect(keys, {'cyber': 'graze', 'dodgeball': 'close_dodge', 'keeper': 'save_streak'});
    });
    test('난이도 1~3 순서', () {
      expect([for (final w in WorldData.worlds) w.difficulty], [1, 2, 3]);
    });
    test('시안 아트 — 탄·공 그림 파일이 있고, 판정은 그림보다 작다', () {
      for (final w in WorldData.worlds) {
        for (final p in w.projectiles) {
          expect(p.weight, greaterThan(0), reason: '${w.id}/${p.id}');
          expect(p.radius * 2, lessThanOrEqualTo(p.visualSize), reason: '${w.id}/${p.id}');
          if (p.sprite != null) {
            expect(File('assets/images/sprites/${p.sprite}.png').existsSync(), isTrue, reason: p.sprite);
          }
        }
      }
      for (final n in ['rival_ready', 'rival_throw', 'rival_smirk', 'rival_cap', 'shooter_ready', 'shooter_kick', 'shooter_captain', 'shooter_point',
        for (final p in Pets.all) p.id]) {
        expect(File('assets/images/sprites/$n.png').existsSync(), isTrue, reason: n);
      }
    });
    test('갤럭시 운석 — 평균 판정·속도는 예전 탄(반지름 3.5 · 배수 1.0)과 비슷하다', () {
      final defs = WorldData.getWorld('cyber').projectiles;
      final total = defs.fold<int>(0, (s, d) => s + d.weight);
      final r = defs.fold<double>(0, (s, d) => s + d.radius * d.weight) / total;
      final v = defs.fold<double>(0, (s, d) => s + d.speedMult * d.weight) / total;
      expect(r, closeTo(3.5, 0.2));
      expect(v, closeTo(1.0, 0.03));
    });
  });

  group('장비', () {
    test('id 는 겹치지 않는다', () {
      final ids = Gear.all.map((g) => g.id).toList();
      expect(ids.toSet().length, ids.length);
    });
    test('모든 존의 부위마다 아이템이 있다', () {
      for (final w in WorldData.worlds) {
        final slots = Gear.slotsOf(w.id);
        expect(slots, isNotEmpty, reason: w.id);
        for (final s in slots) {
          expect(Gear.itemsOf(w.id, s), isNotEmpty);
        }
      }
    });
    test('무료 기본 장비는 보너스가 없다 · 보너스는 코인 +% 뿐이고 작다(15% 이하)', () {
      for (final g in Gear.all) {
        if (g.price == 0 && g.needsBadge == null) expect(g.bonus.isZero, isTrue, reason: g.id);
        expect(g.bonus.coin, lessThanOrEqualTo(0.15), reason: g.id);
      }
    });
    test('상점에는 판매 종료 장비가 안 보이고, 가진 사람에게만 보인다 · 부위마다 기본 + 코인 2~3개', () {
      for (final w in WorldData.worlds) {
        for (final s in Gear.slotsOf(w.id)) {
          final shown = Gear.shopItemsOf(w.id, s, (_) => false);
          expect(shown.where((g) => g.retired), isEmpty, reason: '${w.id} ${s.name}');
          expect(shown.where((g) => g.price == 0 && g.needsBadge == null).length, 1, reason: '${w.id} ${s.name}');
          final coin = shown.where((g) => g.price > 0).length;
          expect(coin, inInclusiveRange(2, 3), reason: '${w.id} ${s.name}');
        }
      }
      final retired = Gear.all.firstWhere((g) => g.retired);
      expect(Gear.shopItemsOf(retired.zone, retired.slot, (id) => id == retired.id), contains(retired));
      // 가진 사람은 그대로 입는다
      expect(Gear.wornId(retired.zone, retired.slot, (k, f) => k == Gear.slotKey(retired.zone, retired.slot) ? retired.id : f), retired.id);
    });
    test('안 입었거나 모르는 id 는 빈 부위', () {
      expect(Gear.wornId('cyber', GearSlot.back, (k, f) => f), Gear.none);
      expect(Gear.wornId('cyber', GearSlot.back, (k, f) => 'no_such_item'), Gear.none);
      expect(Gear.wornId('cyber', GearSlot.back, (k, f) => 'wings_star'), 'wings_star');
    });
    test('보너스 라벨', () {
      expect(const GearBonus(coin: 0.05).labels, [('bonus_coin', '5')]);
      expect(GearBonus.none.labels, isEmpty);
      expect((const GearBonus(coin: 0.1) + const GearBonus(coin: 0.05)).coin, closeTo(0.15, 1e-9));
    });
  });

  group('앱 버전 · 업데이트 안내', () {
    test('스토어 빌드보다 낮으면 안내, 필수 빌드보다 낮으면 필수', () {
      const r = PlatformRelease(version: '2.1.0', build: 210, minBuild: 205);
      expect(r.needFor(210), UpdateNeed.none);
      expect(r.needFor(211), UpdateNeed.none); // 더 새 빌드(심사 중인 앱 등)
      expect(r.needFor(209), UpdateNeed.optional);
      expect(r.needFor(204), UpdateNeed.required);
      expect(r.needFor(0), UpdateNeed.none); // 버전을 못 읽었으면 묻지 않는다
      expect(const PlatformRelease(version: '2.1.0', build: 210).needFor(100), UpdateNeed.optional); // 필수 없음
    });
    test('문서 읽기 — 빈 칸·잘못된 값은 안내하지 않는다', () {
      final a = AppRelease.fromMap({
        'android': {'version': '2.1.0', 'build': 210, 'minBuild': 0},
        'ios': {'version': '', 'build': 0},
      });
      expect(a.of('android')?.build, 210);
      expect(a.of('ios'), isNull);
      expect(a.of('web'), isNull);
      expect(AppRelease.fromMap(null).android, isNull);
      expect(const PlatformRelease(version: 'x', build: 3, minBuild: 1).toMap(), {'version': 'x', 'build': 3, 'minBuild': 1});
      final m = const PlatformRelease(version: '2.1.1', build: 213, minBuild: 210, minVersion: '2.1.0').toMap();
      expect(m['minVersion'], '2.1.0');
      expect(PlatformRelease.fromMap(m)?.minVersion, '2.1.0');
    });
    test('버전 이름 → 빌드(백오피스는 이름만 적는다) — 안내는 가장 큰 빌드, 필수는 가장 작은 빌드', () {
      expect(PlatformRelease.buildFor([210, 212], lowest: false), 212); // 2.1.0(210) 앱도 212 를 받게
      expect(PlatformRelease.buildFor([210, 212], lowest: true), 210); // 2.1.0 은 막지 않게
      expect(PlatformRelease.buildFor([0], lowest: false), isNull);
      expect(PlatformRelease.buildFor(const [], lowest: true), isNull);
    });
    test('화면 표시 — v이름 (빌드)', () {
      expect(const AppVersion('2.1.0', 210).label, 'v2.1.0 (210)');
      expect(const AppVersion('2.1.0', 210).fields, {'appVersion': '2.1.0', 'appBuild': 210});
      expect(const AppVersion('', 0).fields, isEmpty);
    });
    test('pubspec 버전이 이름+빌드 꼴', () {
      final v = RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync());
      expect(v, isNotNull);
      expect(int.parse(v!.group(2)!), greaterThan(208)); // 2.0.6+208 다음부터
    });
  });

  group('착용 한 벌(Loadout)', () {
    String Function(String, String) eq(Map<String, String> m) => (k, f) => m[k] ?? f;
    test('장비 + 꾸미기의 코인 보너스를 합친다', () {
      final e = eq({'gear_cyber_back': 'wings_comet', 'skin': 'skin_silver', 'trail': 'trail_note', 'aura': 'aura_crown'});
      final b = Loadout.bonusOf('cyber', e);
      expect(b.coin, closeTo(0.1 + 0.03 + 0.02 + 0.05, 1e-9));
      // 다른 존의 장비는 세지 않는다
      expect(Loadout.bonusOf('keeper', e).coin, closeTo(0.03 + 0.02 + 0.05, 1e-9));
    });
    test('예전 펫 슬롯이 남아 있으면 그 펫 오라가 이긴다(아직 안 옮긴 남의 문서)', () {
      expect(Loadout.auraOf(eq({'aura': 'aura_star', Pets.legacySlotKey: 'pet_star'})), 'pet_star');
      expect(Loadout.auraOf(eq({'aura': 'aura_ring', Pets.legacySlotKey: 'pet_cat'})), 'pet_cat');
      expect(Loadout.auraOf(eq({'aura': 'aura_star', Pets.legacySlotKey: ''})), 'aura_star');
      expect(Loadout.auraOf(eq({'aura': 'pet_dragon'})), 'pet_dragon');
    });
    test('아무것도 안 입으면 0', () {
      for (final w in WorldData.worlds) {
        expect(Loadout.bonusOf(w.id, eq({})).isZero, isTrue, reason: w.id);
      }
    });
  });

  group('펫 오라(2026-10-26 펫을 오라로 합침)', () {
    test('펫 6종이 도는 오라로 있다 — id·가격은 예전 그대로, 이름 번역·그림이 있다', () {
      final pets = Cosmetics.ofKind(CosmeticKind.aura).where((c) => c.pet).toList();
      expect(pets.map((c) => c.id), Pets.all.map((p) => p.id));
      expect(pets.map((c) => c.price), [600, 800, 1000, 1200, 1500, 1800]);
      for (final c in pets) {
        expect(c.orbits, isTrue, reason: c.id);
        expect(c.bonus.isZero, isTrue, reason: c.id);
        for (final lang in ['en', 'ko', 'zh', 'ja']) {
          expect(appTranslations[lang]![c.nameKey], isNotNull, reason: '$lang ${c.id}');
        }
      }
      final list = [...Pets.all];
      for (var i = 1; i < list.length; i++) {
        expect(list[i].orbitSpeed, greaterThan(list[i - 1].orbitSpeed), reason: list[i].id);
      }
      // 도는 길(게임 몸 반지름 약 20.6 × 배수)은 캐릭터 히트박스(반 11) + 펫 몸보다 바깥
      expect(20.6 * (Pets.orbitScale - Pets.bodyScale), greaterThan(11));
    });
    test('예전 착용 슬롯 pet → 오라로 옮긴다(펫이 이긴다) · 모르는 값이면 슬롯만 지운다', () {
      final e = {'aura': 'aura_ring', 'pet': 'pet_cat', 'skin': 'skin_gold'};
      expect(Cosmetics.migrateEquipped(e), isTrue);
      expect(e, {'aura': 'pet_cat', 'skin': 'skin_gold'});
      expect(Cosmetics.migrateEquipped(e), isFalse); // 두 번째는 할 일 없음
      final none = {'aura': 'aura_star', 'pet': ''};
      expect(Cosmetics.migrateEquipped(none), isTrue);
      expect(none, {'aura': 'aura_star'});
    });
    test('기기에 남은 예전 착용도 읽을 때 옮긴다', () async {
      SharedPreferences.setMockInitialValues({'equipped_items': ['aura:aura_star', 'pet:pet_slime']});
      await CoinStore.clearLocal();
      SharedPreferences.setMockInitialValues({'equipped_items': ['aura:aura_star', 'pet:pet_slime']});
      await CoinStore.load();
      expect(CoinStore.equipped('aura', ''), 'pet_slime');
      expect(CoinStore.equipped('pet', 'none'), 'none');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('equipped_items'), ['aura:pet_slime']);
      await CoinStore.clearLocal();
    });
  });

  group('뱃지', () {
    test('키는 겹치지 않고 이름·설명 번역이 있다', () {
      final keys = Badges.all.map((b) => b.key).toList();
      expect(keys.toSet().length, keys.length);
      for (final k in keys) {
        expect(appTranslations['en']![k], isNotNull, reason: k);
        expect(appTranslations['en']!['${k}_desc'], isNotNull, reason: '${k}_desc');
      }
    });
    test('뱃지 장비의 뱃지가 실제로 있다', () {
      for (final g in Gear.all.where((g) => g.needsBadge != null)) {
        expect(Badges.byKey(g.needsBadge!), isNotNull, reason: g.id);
      }
    });
    test('조건 — 생존·스테이지·기술·랭킹', () {
      final st = BadgeStats();
      bool ok(String k, BadgeContext c) => Badges.byKey(k)!.check(c);
      expect(ok('ach_survivor', BadgeContext(stats: st, time: 61)), isTrue);
      expect(ok('b_s2_75', BadgeContext(stats: st, stage: 2, time: 80)), isTrue);
      expect(ok('b_s2_75', BadgeContext(stats: st, stage: 1, time: 80)), isFalse);
      expect(ok('b_streak_3', BadgeContext(stats: st, statKey: 'save_streak', statCount: 3)), isTrue);
      expect(ok('ach_glob_top10', BadgeContext(stats: st, worldRank: 7)), isTrue);
      expect(ok('ach_glob_top10', BadgeContext(stats: st)), isFalse); // 순위 모름(0)
    });
    test('대표 뱃지 = 가장 높은 등급', () {
      expect(Badges.best(['ach_survivor', 'b_s1_180', 'b_runs_10'])?.key, 'b_s1_180');
      expect(Badges.best(const []), isNull);
    });
  });

  group('꾸미기', () {
    test('id 는 겹치지 않고 기본값이 목록에 있다', () {
      final ids = Cosmetics.all.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final k in CosmeticKind.values) {
        expect(Cosmetics.byId(Cosmetics.defaultOf(k))?.kind, k);
      }
    });
    test('기본(무료)은 보너스가 없고, 보너스는 코인 +% 뿐이다(12% 이하)', () {
      for (final c in Cosmetics.all) {
        if (c.price == 0) expect(c.bonus.isZero, isTrue, reason: c.id);
        expect(c.bonus.coin, lessThanOrEqualTo(0.12), reason: c.id);
      }
    });
  });

  group('국기', () {
    test('이모지 국기와 옛 코드(KR) 둘 다 ISO 코드로 바뀐다', () {
      expect(flagToIso('\u{1F1F0}\u{1F1F7}'), 'KR');
      expect(flagToIso('KR'), 'KR');
      expect(flagToIso('kr'), 'KR');
      expect(flagToIso(''), '');
      expect(flagToIso('대한민국'), '');
    });
  });

  group('아바타', () {
    test('착용 목록에서 만들면 종류마다 하나씩 · 존 장비는 그 존에만', () {
      const worn = {
        'skin': 'skin_gold',
        'trail': 'trail_heart',
        'aura': 'aura_halo',
        'gear_cyber_head': 'goggles_space',
        'gear_dodgeball_feet': 'sneakers_neon',
      };
      final a = Avatar.fromEquipped('solar_gold', (k, f) => worn[k] ?? f);
      expect(a.characterId, 'solar_gold');
      expect(a.skinId, 'skin_gold');
      expect(a.trailId, 'trail_heart');
      expect(a.auraId, 'aura_halo');
      expect(a.gearOf('cyber'), ['goggles_space']);
      expect(a.gearOf('dodgeball'), ['sneakers_neon']);
      expect(a.gearOf('keeper'), isEmpty);
      expect(a.gearOf(null), isEmpty);
      // 그림 한 장 — 존을 주면 그 존 장비만 입는다
      expect(a.look(zone: 'cyber').gear, ['goggles_space']);
      expect(a.look().gear, isEmpty);
    });

    test('모르는 값은 기본값으로 떨어진다', () {
      final a = Avatar.fromEquipped('없는캐릭터', (k, f) => k == 'gear_cyber_head' ? '없는장비' : f);
      expect(a.character.id, Avatar.defaultCharacterId); // CharacterData 가 기본으로 돌려준다
      expect(a.skinId, Cosmetics.defaultSkin);
      expect(a.gearOf('cyber'), isEmpty);
    });

    test('유저 문서·랭킹 기록에서 같은 아바타가 나온다', () {
      final doc = {
        'characterId': 'plasma_purple',
        'equipped': {'skin': 'skin_ice', 'gear_keeper_hands': 'gloves_pro'},
      };
      final fromDoc = Avatar.fromUserDoc(doc);
      final fromRecord = Avatar.fromRecord(
        {'characterId': 'plasma_purple', 'skin': 'skin_ice', 'gear': ['gloves_pro']},
        zone: 'keeper',
      );
      expect(fromDoc.characterId, fromRecord.characterId);
      expect(fromDoc.skinId, fromRecord.skinId);
      expect(fromDoc.gearOf('keeper'), fromRecord.gearOf('keeper'));
      expect(Avatar.fromUserDoc(const {}).characterId, Avatar.defaultCharacterId);
    });
  });

  group('플레이어 프로필', () {
    test('유저 문서 한 장에서 아바타·기록·가입일·뱃지를 읽는다', () {
      final p = PlayerProfile.fromUserDoc('u1', {
        'nickname': '존버',
        'flag': 'KR',
        'characterId': 'cyber_red',
        'equipped': {'skin': 'skin_lava'},
        'achievements': ['ach_survivor', 'ach_legend', '없는뱃지'],
        'bestTimes': {'cyber': 61.5, 'keeper': 'x'},
        'createdAt': DateTime.utc(2026, 9, 1).millisecondsSinceEpoch,
        'totalGamesPlayed': 42,
      });
      expect(p.uid, 'u1');
      expect(p.nickname, '존버');
      expect(p.avatar.characterId, 'cyber_red');
      expect(p.avatar.skinId, 'skin_lava');
      expect(p.bestOf('cyber'), 61.5);
      expect(p.bestOf('keeper'), isNull); // 숫자가 아닌 값은 버린다
      expect(p.badges.map((b) => b.key), ['ach_survivor', 'ach_legend']);
      expect(p.topBadge?.key, 'ach_legend'); // 등급이 가장 높은 것
      expect(p.joinedAt?.year, 2026);
      expect(p.totalGames, 42);
      expect(p.isEmpty, isFalse);
    });

    test('빈 문서도 터지지 않는다', () {
      final p = PlayerProfile.fromUserDoc('u2', const {});
      expect(p.isEmpty, isTrue);
      expect(p.topBadge, isNull);
      expect(p.avatar, Avatar.fallback);
      expect(p.joinedAt, isNull);
    });
  });

  group('이벤트(프로모션)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      PromoService.invalidate();
    });

    test('기간·켜짐으로 진행 여부가 갈린다', () {
      final now = DateTime.now();
      const always = Promotion(id: 'a', kind: PromoKind.bonus, coins: 10);
      expect(always.isLive, isTrue);
      expect(const Promotion(id: 'b', kind: PromoKind.bonus, enabled: false).isLive, isFalse);
      expect(Promotion(id: 'c', kind: PromoKind.bonus, startAt: now.add(const Duration(days: 1))).isLive, isFalse);
      expect(Promotion(id: 'd', kind: PromoKind.bonus, endAt: now.subtract(const Duration(days: 1))).isLive, isFalse);
      expect(Promotion(id: 'e', kind: PromoKind.bonus, startAt: now.subtract(const Duration(days: 1)), endAt: now.add(const Duration(days: 2))).isLive, isTrue);
    });

    test('문서 ↔ 모델이 오간다(모르는 값은 기본)', () {
      const p = Promotion(
        id: 'autumn',
        kind: PromoKind.bonus,
        coins: 500,
        items: ['skin_cloud'],
        cooldownHours: 24,
        title: {'ko': '가을 이벤트'},
      );
      final back = Promotion.fromDoc('autumn', p.toDoc());
      expect(back.kind, PromoKind.bonus);
      expect(back.coins, 500);
      expect(back.items, ['skin_cloud']);
      expect(back.cooldownHours, 24);
      expect(back.titleOf('ko'), '가을 이벤트');
      expect(back.titleOf('en'), '가을 이벤트'); // 영어가 없으면 한국어로
      expect(const Promotion(id: 'g', kind: PromoKind.bonus, title: {'ko': '가', 'en': 'A'}).titleOf('ja'), 'A'); // 없는 언어는 영어
      expect(Promotion.fromDoc('x', const {}).kind, PromoKind.bonus);
      expect(Promotion.fromDoc('x', const {}).isLive, isTrue);
    });

    test('한 번짜리는 다시 못 받고, 쿨다운은 시간이 지나야 받는다', () async {
      const once = Promotion(id: 'once', kind: PromoKind.bonus, coins: 100);
      expect(await PromoService.canClaim(once), isTrue);
      expect(await PromoService.claim(once), isTrue);
      expect(await PromoService.canClaim(once), isFalse);
      expect(await PromoService.claim(once), isFalse); // 두 번 눌러도 한 번
      expect(CoinStore.balance.value, 100);

      const daily = Promotion(id: 'daily', kind: PromoKind.share, coins: 50, cooldownHours: 24);
      expect(await PromoService.claim(daily), isTrue);
      expect(await PromoService.canClaim(daily), isFalse); // 오늘은 끝
      expect(CoinStore.balance.value, 150);
    });

    test('게스트는 받지 못한다', () async {
      AuthService.debugIsGuest = true;
      const p = Promotion(id: 'guest', kind: PromoKind.bonus, coins: 100);
      expect(await PromoService.canClaim(p), isFalse);
      expect(await PromoService.claim(p), isFalse);
      AuthService.debugIsGuest = false;
    });

    test('코드 입력은 대소문자·공백·하이픈을 정리하고 형식을 본다', () async {
      expect(PromoCodes.normalize(' zon-ber 7 '), 'ZONBER7');
      expect(PromoCodes.isValidFormat('ZONBER7'), isTrue);
      expect(PromoCodes.isValidFormat('ZB'), isFalse); // 너무 짧다
      expect(PromoCodes.isValidFormat('ZONBER!'), isFalse);
      expect(PromoCodes.isValidFormat('A' * 21), isFalse);
      // 형식이 틀리면 서버에 묻지 않고 없는 코드
      expect((await PromoService.redeem('!!')).$1, RedeemResult.invalid);
    });

    test('게스트는 코드를 쓸 수 없다', () async {
      AuthService.debugIsGuest = true;
      expect((await PromoService.redeem('ZONBER')).$1, RedeemResult.guest);
      AuthService.debugIsGuest = false;
    });

    test('자동 생성 코드는 헷갈리는 글자가 없고 접두어가 붙는다', () {
      final codes = {for (var i = 0; i < 300; i++) PromoCodes.generate(prefix: 'insta-', length: 6)};
      expect(codes.length, greaterThan(295)); // 거의 겹치지 않는다
      for (final c in codes) {
        expect(c.startsWith('INSTA'), isTrue);
        expect(c.length, 11);
        expect(PromoCodes.isValidFormat(c), isTrue);
        expect(RegExp('[0O1IL]').hasMatch(c.substring(5)), isFalse);
      }
    });

    test('친구 코드는 영문 대문자·숫자 4~5자이고 헷갈리는 글자가 없다', () {
      for (final len in FriendCodes.tryLengths) {
        final c = FriendCodes.generate(len);
        expect(c.length, len);
        expect(FriendCodes.isValidFormat(c), isTrue, reason: c);
        expect(PromoCodes.isValidFormat(c), isTrue, reason: c); // 같은 입력칸(이벤트 코드 형식)도 통과
        expect(RegExp('[0O1IL]').hasMatch(c), isFalse, reason: c);
      }
      expect(FriendCodes.tryLengths.first, 4); // 짧은 것부터
      expect(FriendCodes.isValidFormat('ABC'), isFalse);
      expect(FriendCodes.isValidFormat('ABCDEF'), isFalse);
      expect(FriendCodes.isValidFormat('ab3k'), isFalse); // 정리(normalize) 뒤에 본다
      expect(FriendCodes.isValidFormat(PromoCodes.normalize(' ab-3k ')), isTrue);
    });

    test('게스트는 친구 코드가 없고 넣을 수도 없다', () async {
      AuthService.debugIsGuest = true;
      expect(await FriendService.myCode(), isNull);
      expect((await FriendService.redeem('AB3K')).$1, RedeemResult.guest);
      expect(await FriendService.collectRewards(), 0);
      AuthService.debugIsGuest = false;
    });

    test('코드 상태 — 꺼짐·시작 전·기간 끝·한도 소진', () {
      final now = DateTime(2026, 10, 1);
      expect(const PromoCode(code: 'A1B2', coins: 100).status(now), PromoCodeStatus.open);
      expect(const PromoCode(code: 'A1B2', coins: 100, enabled: false).status(now), PromoCodeStatus.disabled);
      expect(PromoCode(code: 'A1B2', coins: 100, startAt: DateTime(2026, 10, 2)).status(now), PromoCodeStatus.notStarted);
      expect(PromoCode(code: 'A1B2', coins: 100, endAt: DateTime(2026, 9, 30)).status(now), PromoCodeStatus.expired);
      expect(const PromoCode(code: 'A1B2', coins: 100, maxUses: 10, uses: 10).status(now), PromoCodeStatus.exhausted);
      expect(const PromoCode(code: 'A1B2', coins: 100, maxUses: 10, uses: 9).remaining, 1);
      expect(const PromoCode(code: 'A1B2', coins: 100).remaining, isNull);
    });

    test('코드 문서 ↔ 모델(사용 수는 저장값에 안 넣는다)', () {
      final c = PromoCode(
          code: 'YTZONE', campaign: 'youtube', note: 'n', coins: 300, items: const ['trail_flame'], maxUses: 50,
          endAt: DateTime(2026, 10, 31));
      final doc = c.toDoc();
      expect(doc.containsKey('uses'), isFalse); // 수정해도 사용 수는 그대로
      final back = PromoCode.fromDoc('YTZONE', {...doc, 'uses': 7});
      expect(back.campaign, 'youtube');
      expect(back.coins, 300);
      expect(back.items, ['trail_flame']);
      expect(back.maxUses, 50);
      expect(back.uses, 7);
      expect(back.endAt, DateTime(2026, 10, 31));
    });

    test('앱 기본 이벤트는 id 가 겹치지 않고 보상이 있다', () {
      final ids = Promotions.builtIn.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final p in Promotions.builtIn) {
        // 코드 안내 카드는 보상이 없다(보상은 코드마다)
        expect(p.isEmptyReward, p.kind == PromoKind.code, reason: p.id);
        // 글로벌 — 4개 언어 제목·설명을 모두 채운다
        for (final lang in ['ko', 'en', 'ja', 'zh']) {
          expect(p.title[lang]?.isNotEmpty, isTrue, reason: '${p.id} title $lang');
          expect(p.desc[lang]?.isNotEmpty, isTrue, reason: '${p.id} desc $lang');
        }
        // 아이템은 게임에 있는 것만
        for (final id in p.items) {
          expect(Cosmetics.byId(id) != null || Gear.byId(id) != null || id.startsWith('char_'), isTrue, reason: id);
        }
      }
    });

    test('받은 수 카운터만 든 서버 문서는 기본 이벤트를 덮지 않는다', () {
      // 기본 이벤트를 받으면 promos/{id} 에 claims 만 생긴다 — 그대로 읽으면 빈 이벤트가 된다
      final welcome = Promotions.fromServer('welcome_pack', const {'claims': 3})!;
      expect(welcome.kind, PromoKind.welcome);
      expect(welcome.coins, 300);
      expect(Promotions.fromServer('nobody', const {'claims': 1}), isNull);
      // 운영자가 저장한 문서(kind 있음)는 서버 값이 이긴다
      final edited = Promotions.fromServer('welcome_pack', const {'kind': 'welcome', 'coins': 500, 'claims': 3})!;
      expect(edited.coins, 500);
    });

    test('코드 안내 카드는 받을 게 없다', () async {
      final card = Promotions.builtIn.firstWhere((p) => p.kind == PromoKind.code);
      expect(await PromoService.isFresh(card), isFalse);
      expect(await PromoService.claim(card), isFalse);
    });

    test('게스트 로그인 선물 = 환영 선물 + 진행 중인 기간 보상(공유·코드는 빼고)', () async {
      final (coins, items) = await PromoService.loginGifts();
      final live = Promotions.live(Promotions.builtIn).where((p) => p.kind == PromoKind.welcome || p.kind == PromoKind.bonus);
      expect(coins, live.fold<int>(0, (s, p) => s + p.coins));
      expect(coins, greaterThanOrEqualTo(300));
      expect(items, contains('skin_cloud'));
    });

    test('공유 링크 — 언어 폴더 · 출처 · 친구 코드', () {
      expect(ShareLinks.url(lang: 'ko', src: 'result'), '${ShareLinks.landing}/ko/?src=result');
      expect(ShareLinks.url(lang: 'fr', src: 'promo', code: 'AB12'), '${ShareLinks.landing}/en/?src=promo&c=AB12');
    });

    test('기간 이벤트는 그 기간에만 보인다(UTC)', () {
      final halloween = Promotions.builtIn.firstWhere((p) => p.id == 'halloween_2026');
      expect(halloween.startAt!.isUtc, isTrue);
      expect(halloween.endAt!.isAfter(halloween.startAt!), isTrue);
    });
  });

  group('일일 미션', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('하루 3개 · 같은 종류/스테이지는 하나씩 · 하루 동안 같다', () {
      final a = DailyRewards.todays();
      expect(a.length, 3);
      expect(a.map((m) => m.kind).toSet().length, 3);
      final stages = a.where((m) => m.stage != 0).map((m) => m.stage).toList();
      expect(stages.toSet().length, stages.length);
      expect(DailyRewards.todays().map((m) => m.id), a.map((m) => m.id));
    });

    test('판 기록이 진행에 반영되고, 부활로 이어진 판은 판 수를 세지 않는다', () async {
      await DailyRewards.recordRun(stage: 1, time: 40, addedTime: 40, addedStat: 3, continued: false);
      await DailyRewards.recordRun(stage: 1, time: 60, addedTime: 20, addedStat: 1, continued: true);
      for (final s in await DailyRewards.missions()) {
        final m = s.mission;
        final expected = switch (m.kind) {
          MissionKind.runs => 1,
          MissionKind.totalTime => 60,
          MissionKind.stageTime => m.stage == 1 ? 60 : 0,
          MissionKind.stat => m.stage == 1 ? 4 : 0,
          MissionKind.allStages => 1,
        };
        expect(s.progress, expected < m.target ? expected : m.target, reason: m.id);
      }
    });

    test('출석 — 처음은 1일차', () async {
      final a = await DailyRewards.attendance();
      expect(a.day, 1);
      expect(a.claimedToday, isFalse);
    });
  });

  group('친구', () {
    test('서버 함수가 돌려주는 결과 코드를 앱이 모두 안다', () {
      final js = File('functions/friends.js').readAsStringSync();
      final codes = RegExp(r"result: '([a-z_]+)'").allMatches(js).map((m) => m.group(1)!).toSet();
      expect(codes, isNotEmpty);
      for (final c in codes) {
        expect(friendResultOf(c), isNot(FriendResult.error), reason: '앱이 모르는 결과 $c');
      }
    });

    test('결과 안내 문구 키가 번역에 있다', () {
      for (final r in FriendResult.values) {
        final key = friendResultKey(r);
        for (final lang in ['en', 'ko', 'ja', 'zh']) {
          expect(appTranslations[lang]!.containsKey(key), isTrue, reason: '$lang $key');
        }
      }
    });

    test('제한 값이 서버와 같다(친구 100 · 대기 요청 50 · 요청 7일)', () {
      final js = File('functions/logic.js').readAsStringSync();
      int n(String name) => int.parse(RegExp('const $name = (\\d+);').firstMatch(js)!.group(1)!);
      expect(n('MAX_FRIENDS'), Friends.maxFriends);
      expect(n('MAX_PENDING'), Friends.maxPending);
      expect(n('REQUEST_DAYS'), Friends.requestDays);
    });
  });

  group('알림함', () {
    test('친구 알림 종류가 서버와 같고, 4개 언어 제목·본문이 있다', () {
      final js = File('functions/logic.js').readAsStringSync();
      for (final kind in kInboxFriendKinds) {
        expect(js.contains('  $kind: {'), isTrue, reason: '서버에 없는 종류 $kind');
        for (final lang in ['en', 'ko', 'ja', 'zh']) {
          expect(appTranslations[lang]!.containsKey('inbox_${kind}_t'), isTrue, reason: '$lang $kind 제목');
          expect(appTranslations[lang]!.containsKey('inbox_${kind}_b'), isTrue, reason: '$lang $kind 본문');
        }
      }
    });

    test('소식은 언어가 없으면 영어로', () {
      const item = InboxItem(id: 'n', kind: 'news', title: {'ko': '가', 'en': 'A'}, body: {'en': 'B'});
      expect(item.newsTitle('ja'), 'A');
      expect(item.newsTitle('ko'), '가');
      expect(item.newsBody('ko'), 'B');
      expect(item.asRead().read, isTrue);
    });
  });

  group('푸시', () {
    test('템플릿은 4개 언어 모두 채우고 백오피스 입력 한도 안(제목 40 · 본문 120)', () {
      final ids = <String>{};
      for (final t in PushTemplates.all) {
        expect(ids.add(t.id), isTrue, reason: '중복 id ${t.id}');
        for (final l in PushTopics.langs) {
          expect(t.title[l]?.trim().isNotEmpty ?? false, isTrue, reason: '${t.id} 제목 $l');
          expect(t.body[l]?.trim().isNotEmpty ?? false, isTrue, reason: '${t.id} 본문 $l');
          expect(t.title[l]!.length, lessThanOrEqualTo(40), reason: '${t.id} 제목 $l');
          expect(t.body[l]!.length, lessThanOrEqualTo(120), reason: '${t.id} 본문 $l');
        }
      }
    });

    test('기기 토픽 — 언어 하나 + 회원/게스트 하나 (+ 관리자면 tester)', () {
      expect(PushTopics.forDevice(lang: 'ko', member: true, tester: false), {'lang_ko', 'member'});
      expect(PushTopics.forDevice(lang: 'fr', member: false, tester: false), {'lang_en', 'guest'});
      expect(PushTopics.forDevice(lang: 'ja', member: true, tester: true), {'lang_ja', 'member', 'tester'});
    });

    test('보낼 조건 — functions/index.js condition() 과 같은 모양', () {
      expect(PushTopics.condition('ko', PushAudience.all), "'lang_ko' in topics");
      expect(PushTopics.condition('en', PushAudience.members), "'lang_en' in topics && 'member' in topics");
      expect(PushTopics.condition('zh', PushAudience.testers), "'lang_zh' in topics && 'tester' in topics");
      final js = File('functions/index.js').readAsStringSync();
      expect(js.contains("const base = `'lang_\${lang}' in topics`;"), isTrue);
      expect(js.contains("members: 'member', guests: 'guest', testers: 'tester'"), isTrue);
    });

    test('비운 언어는 영어 문구로 간다', () {
      const c = PushCampaign(id: 'x', title: {'ko': '가', 'en': 'A'}, body: {'ko': '나', 'en': 'B', 'ja': 'に'});
      expect(c.titleFor('ja'), 'A');
      expect(c.bodyFor('ja'), 'に');
      expect(c.titleFor('ko'), '가');
      expect(c.targetLangs, PushTopics.langs);
    });
  });

  group('난이도 레벨', () {
    test('15초마다 1씩 오르고 최고 레벨에서 멈춘다', () {
      expect(Balance.levelAt(0), 1);
      expect(Balance.levelAt(14.9), 1);
      expect(Balance.levelAt(15), 2);
      final top = (Balance.maxLevel - 1) * Balance.levelSeconds;
      expect(Balance.levelAt(top), Balance.maxLevel);
      expect(Balance.levelAt(top * 5), Balance.maxLevel); // 그 뒤로는 그대로
    });

    test('최고 레벨 뒤로는 30초마다 2%씩 아주 천천히, 최대 1.5배(2026-10-26)', () {
      final top = (Balance.maxLevel - 1) * Balance.levelSeconds;
      expect(Balance.lateGrowth(0), 1);
      expect(Balance.lateGrowth(top), 1);
      expect(Balance.lateGrowth(top + Balance.lateStepSeconds - 0.1), 1);
      expect(Balance.lateGrowth(top + Balance.lateStepSeconds), closeTo(1 + Balance.lateStep, 1e-9));
      expect(Balance.lateGrowth(top + Balance.lateStepSeconds * 10), closeTo(1 + Balance.lateStep * 10, 1e-9));
      expect(Balance.lateGrowth(top + 3600), Balance.lateMax);
      // 한 칸이 레벨 한 칸(갤럭시 초당 탄 약 +0.7)보다 훨씬 작다
      expect(Balance.cyberRate(Balance.maxLevel) * Balance.lateStep, lessThan(Balance.cyberRate(2) - Balance.cyberRate(1)));
    });

    test('레벨마다 같은 폭으로 조금씩 어려워진다(급한 계단 없음)', () {
      // 존별 "빈도"(초당 탄·투구·슛) — 매 레벨 오르고, 한 번에 전체 폭의 1/(최고-1) 만큼만
      final curves = <String, double Function(int)>{
        'cyberRate': Balance.cyberRate,
        'dodgeRate': (l) => 1 / Balance.dodgeBeat(l),
        'keeperRate': (l) => 1 / Balance.keeperBeat(l),
      };
      for (final e in curves.entries) {
        final f = e.value;
        final step = (f(Balance.maxLevel) - f(1)) / (Balance.maxLevel - 1);
        for (var l = 2; l <= Balance.maxLevel; l++) {
          expect(f(l) - f(l - 1), closeTo(step, 1e-9), reason: '${e.key} L$l');
          expect(f(l) > f(l - 1), isTrue, reason: e.key);
        }
        expect(f(Balance.maxLevel + 5), f(Balance.maxLevel), reason: '${e.key} 최고 레벨 이후 그대로');
      }
    });

    test('속도는 중반부터 덜 오른다 — 레벨 speedKnee 뒤로 한 칸 폭이 speedLateStep 배', () {
      final curves = <String, double Function(int)>{
        'cyberSpeed': Balance.cyberSpeed,
        'dodgeSpeed': Balance.dodgeSpeed,
        'keeperSpeed': Balance.keeperSpeed,
      };
      for (final e in curves.entries) {
        final f = e.value;
        final early = f(2) - f(1);
        for (var l = 2; l <= Balance.maxLevel; l++) {
          final want = l <= Balance.speedKnee ? early : early * Balance.speedLateStep;
          expect(f(l) - f(l - 1), closeTo(want, 1e-9), reason: '${e.key} L$l');
        }
        expect(f(Balance.maxLevel + 5), f(Balance.maxLevel), reason: '${e.key} 최고 레벨 이후 그대로');
      }
    });

    test('패턴 단계는 레벨 순서대로 0~6', () {
      var last = 0;
      for (var l = 1; l <= Balance.maxLevel; l++) {
        final t = Balance.tierOf(l);
        expect(t >= last && t - last <= 1, isTrue, reason: 'L$l');
        last = t;
      }
      expect(Balance.tierOf(1), 0);
      expect(Balance.tierOf(Balance.maxLevel), 6);
      expect(Balance.dodgeTwin.length, 7);
    });
  });

  group('새로 깐 사람', () {
    test('첫날 = 설치 24시간 안 — 전면 광고 없음 · runs_3', () {
      expect(NewUser.isFirstDayAge(Duration.zero), isTrue);
      expect(NewUser.isFirstDayAge(const Duration(hours: 23, minutes: 59)), isTrue);
      expect(NewUser.isFirstDayAge(const Duration(hours: 24)), isFalse);
      expect(NewUser.isFirstDayAge(const Duration(minutes: -5)), isFalse); // 기기 시계가 틀린 경우
    });
    test('2일 차 복귀 = 설치 24~48시간', () {
      expect(NewUser.isDay2Age(const Duration(hours: 23)), isFalse);
      expect(NewUser.isDay2Age(const Duration(hours: 24)), isTrue);
      expect(NewUser.isDay2Age(const Duration(hours: 47, minutes: 59)), isTrue);
      expect(NewUser.isDay2Age(const Duration(hours: 48)), isFalse);
    });
    test('설치 시각을 모르면(모바일 밖) 첫날이 아니다', () {
      expect(NewUser.isFirstDay, isFalse);
    });
  });

  group('시즌(functions/test/logic.test.js 와 같은 경우들)', () {
    final first = DateTime.utc(2026, 11, 1);
    test('연간 — 첫 시즌은 시즌 1 시작부터, 그 뒤는 1월 1일마다 · 프리시즌', () {
      final c = SeasonConfig(firstStart: first);
      final pre = c.seasonAt(DateTime.utc(2026, 10, 31, 23));
      expect((pre.number, pre.id, pre.end), (0, 'S0', first));
      expect(pre.isPreSeason, isTrue);
      final s1 = c.seasonAt(DateTime.utc(2026, 12, 15));
      expect((s1.number, s1.id, s1.start, s1.end), (1, '2026', first, DateTime.utc(2027, 1, 1)));
      final s2 = c.seasonAt(DateTime.utc(2027, 6, 1));
      expect((s2.number, s2.id, s2.start, s2.end), (2, '2027', DateTime.utc(2027, 1, 1), DateTime.utc(2028, 1, 1)));
      expect(c.previous(s2)!.id, '2026');
      expect(c.previous(s1)!.id, 'S0');
      expect(c.previous(pre), isNull);
      expect(c.next(s1).id, '2027');
      expect(s1.label, '2026');
    });
    test('분기 · 월간 · N일 · 시간대(한국 자정)', () {
      final q = SeasonConfig(mode: SeasonMode.quarter, firstStart: DateTime.utc(2026, 10, 1));
      final q4 = q.seasonAt(DateTime.utc(2026, 11, 26));
      expect((q4.number, q4.id, q4.start, q4.end), (1, '2026Q4', DateTime.utc(2026, 10, 1), DateTime.utc(2027, 1, 1)));
      expect(q.seasonAt(DateTime.utc(2027, 4, 2)).id, '2027Q2');
      expect(q.seasonAt(DateTime.utc(2027, 4, 2)).number, 3);
      expect(q4.label, '2026 Q4');

      final m = SeasonConfig(mode: SeasonMode.month, firstStart: DateTime.utc(2026, 10, 15));
      final m1 = m.seasonAt(DateTime.utc(2026, 10, 20));
      expect((m1.id, m1.start, m1.end), ('2026-10', DateTime.utc(2026, 10, 15), DateTime.utc(2026, 11, 1)));
      expect(m.seasonAt(DateTime.utc(2026, 12, 31)).number, 3);
      expect(m1.label, '2026.10');

      final d = SeasonConfig(mode: SeasonMode.days, periodDays: 14, firstStart: first);
      final d3 = d.seasonAt(first.add(const Duration(days: 29)));
      expect((d3.number, d3.id, d3.start, d3.end), (3, 'S3', DateTime.utc(2026, 11, 29), DateTime.utc(2026, 12, 13)));

      // 한국 자정(UTC+9) 경계 — 12월 31일 24:00 KST = 12월 31일 15:00 UTC
      final k = SeasonConfig(firstStart: DateTime.utc(2026, 10, 31, 15), offsetHours: 9);
      final k1 = k.seasonAt(DateTime.utc(2026, 12, 31, 14, 59));
      expect(k1.id, '2026');
      expect(k1.end, DateTime.utc(2026, 12, 31, 15));
      expect(k.seasonAt(DateTime.utc(2026, 12, 31, 15)).id, '2027');
    });
    test('마감 전 푸시 순간 — pushDays 일 전 pushHour 시(시즌 시간대)', () {
      final c = SeasonConfig(firstStart: first, offsetHours: 9, pushHour: 18);
      final s = c.seasonAt(DateTime.utc(2026, 12, 1));
      final m = c.pushMoments(s);
      expect(m.map((x) => x.$1), [30, 10, 3]);
      expect(m.first.$2, DateTime.utc(2026, 12, 2, 9)); // 2026-12-02 18:00 KST
      expect(m.last.$2, DateTime.utc(2026, 12, 29, 9));
    });
    test('설정 문서 ↔ 모델 · 캐시(JSON)', () {
      final c = SeasonConfig(mode: SeasonMode.quarter, firstStart: first, offsetHours: 9, pushDays: const [14, 1], pushHour: 20);
      final back = SeasonConfig.fromMap(c.toCache());
      expect((back.mode, back.firstStart, back.offsetHours, back.pushHour), (SeasonMode.quarter, first, 9, 20));
      expect(back.pushDays, [14, 1]);
      expect(SeasonConfig.fromMap(null).mode, SeasonMode.year);
      expect(SeasonConfig.fromMap(const {'mode': 'nope', 'offsetHours': 99}).offsetHours, 14);
      expect(Season.now.id, isNotEmpty);
    });
  });

  group('효과음', () {
    test('자주 나는 소리는 4벌, 나머지는 한 벌 — 파일이 모두 있다', () {
      expect(Sfx.fileFor(Sfx.hit, 0), 'hit.wav');
      expect(Sfx.fileFor(Sfx.hit, 3), 'hit_4.wav');
      expect(Sfx.fileFor(Sfx.hit, 4), 'hit.wav');
      expect(Sfx.fileFor(Sfx.badge, 1), 'badge.wav');
      final missing = Sfx.files.where((f) => !File('assets/audio/$f').existsSync()).toList();
      expect(missing, isEmpty, reason: 'python scripts/make_sfx.py 로 만든다');
    });
  });

  group('번역', () {
    final ph = RegExp(r'\{[a-z]+\}');
    Set<String> holders(String v) => ph.allMatches(v).map((m) => m.group(0)!).toSet();
    for (final lang in ['ko', 'zh', 'ja']) {
      test('$lang — 영어 키가 모두 있고 자리표시자가 같다', () {
        final en = appTranslations['en']!, other = appTranslations[lang]!;
        final missing = en.keys.where((k) => !other.containsKey(k)).toList();
        expect(missing, isEmpty, reason: '$lang 에 없는 키: $missing');
        for (final k in en.keys) {
          expect(holders(other[k]!), holders(en[k]!), reason: '$lang.$k');
        }
      });
    }
  });
}
