import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zonber/avatar.dart';
import 'package:zonber/badges.dart';
import 'package:zonber/balance.dart';
import 'package:zonber/coin_store.dart';
import 'package:zonber/cosmetics.dart';
import 'package:zonber/daily_rewards.dart';
import 'package:zonber/design_system.dart';
import 'package:zonber/player_profile.dart';
import 'package:zonber/promotions.dart';
import 'package:zonber/gear.dart';
import 'package:zonber/season.dart';
import 'package:zonber/services/auth_service.dart';
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

    test('판을 해도 미션·코인·기기 저장이 없다', () async {
      await DailyRewards.recordRun(stage: 1, time: 40, addedTime: 40, addedStat: 3, continued: false);
      await CoinStore.add(50);
      expect((await DailyRewards.missions()).every((s) => s.progress == 0), isTrue);
      expect(CoinStore.balance.value, 0);
      expect(await DailyRewards.claimAttendance(), 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('daily_progress'), isNull);
      expect(prefs.getInt('coins'), isNull);
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
    test('무료 기본 장비는 능력치가 없다 · 유료/뱃지 장비만 있다', () {
      for (final g in Gear.all) {
        if (g.price == 0 && g.needsBadge == null) expect(g.bonus.isZero, isTrue, reason: g.id);
      }
    });
    test('능력치는 작다(속도 6% · 회복 3초 · 무적 0.3초 · 범위 5 이하)', () {
      for (final g in Gear.all) {
        expect(g.bonus.speed, lessThanOrEqualTo(0.06), reason: g.id);
        expect(g.bonus.recovery, lessThanOrEqualTo(3), reason: g.id);
        expect(g.bonus.iframe, lessThanOrEqualTo(0.3), reason: g.id);
        expect(g.bonus.reach, lessThanOrEqualTo(5), reason: g.id);
      }
    });
    test('안 입었거나 모르는 id 는 빈 부위', () {
      expect(Gear.wornId('cyber', GearSlot.back, (k, f) => f), Gear.none);
      expect(Gear.wornId('cyber', GearSlot.back, (k, f) => 'no_such_item'), Gear.none);
      expect(Gear.wornId('cyber', GearSlot.back, (k, f) => 'wings_star'), 'wings_star');
    });
    test('능력치 라벨', () {
      expect(const GearBonus(speed: 0.05).labels, [('bonus_speed', '5')]);
      expect(const GearBonus(reach: 3).labels, [('bonus_reach', '3')]);
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

  group('시즌', () {
    test('현재 시즌 번호 = 마지막 시작', () {
      expect(Season.current, Season.starts.length - 1);
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
