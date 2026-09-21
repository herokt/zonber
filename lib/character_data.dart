import 'package:flutter/material.dart';
import 'coin_store.dart';

class CharacterStats {
  final int maxEnergy;          // 체력: 총 에너지량 (1~5)
  final double speedMultiplier; // 속도: dragInput 배수
  final double energyCooldown;  // 기력: 에너지 1 회복 대기 시간 (초, 0=회복없음)
  final double iframeDuration;  // 회피: 피격 후 무적 시간 (초)

  const CharacterStats({
    required this.maxEnergy,
    required this.speedMultiplier,
    required this.energyCooldown,
    this.iframeDuration = 1.5,
  });

  /// 모든 캐릭터 공통 능력치(2026-09-21 통일). 캐릭터는 외형만 다르다 — 랭킹이 순수 실력 경쟁이 되게.
  /// ⚠️ 바꾸면 모든 존의 리더보드 기록 의미가 달라진다(시즌 리셋 검토).
  static const CharacterStats standard = CharacterStats(
    maxEnergy: 3,
    speedMultiplier: 1.0,
    energyCooldown: 25,
    iframeDuration: 1.5,
  );

  /// 실질 생존력 지표 — 무적 시간의 총합(초).
  /// 무적 중에는 닿는 탄환이 제거되므로 이 값이 곧 "탄막을 뚫고 지나갈 수 있는 시간"이다.
  double get invulnBudget => maxEnergy * iframeDuration;
}

class Character {
  final String id;
  final String name;
  final Color color;
  /// 성격 한 줄(컨셉 문서 docs/CHARACTER_CONCEPT.md). 능력치는 모두 같다.
  final String description;
  final String? imagePath;
  final CharacterStats stats;

  /// 해금 조건이 되는 업적 키. null이면 기본 해금.
  final String? unlockKey;

  /// 상점 가격(코인). 0 이면 기본 캐릭터. 업적 해금 또는 코인 구매 중 하나로 열린다
  final int price;

  const Character({
    required this.id,
    required this.name,
    required this.color,
    required this.description,
    required this.stats,
    this.imagePath,
    this.unlockKey,
    this.price = 0,
  });
}

class CharacterData {
  static const List<Character> availableCharacters = [
    Character(
      id: 'neon_green',
      name: 'Mint',
      color: Color(0xFF3FBF97),
      description: 'The original zoner. Calm, steady, always there.',
      imagePath: 'assets/images/characters/neon_green.png',
      stats: CharacterStats.standard,
    ),

    Character(
      id: 'electric_blue',
      name: 'Zap',
      color: Color(0xFF3B8EF0),
      description: 'Restless and quick-witted. Never sits still.',
      imagePath: 'assets/images/characters/electric_blue.png',
      unlockKey: 'ach_survivor',
      price: 300,
      stats: CharacterStats.standard,
    ),

    Character(
      id: 'plasma_purple',
      name: 'Luna',
      color: Color(0xFFA66BF2),
      description: 'Dreamy and mysterious. Hums while dodging.',
      imagePath: 'assets/images/characters/plasma_purple.png',
      unlockKey: 'ach_veteran',
      price: 400,
      stats: CharacterStats.standard,
    ),

    Character(
      id: 'cyber_red',
      name: 'Blaze',
      color: Color(0xFFF2503D),
      description: 'Hot-headed competitor. Hates losing.',
      imagePath: 'assets/images/characters/cyber_red.png',
      unlockKey: 'ach_elite',
      price: 500,
      stats: CharacterStats.standard,
    ),

    Character(
      id: 'solar_gold',
      name: 'Sunny',
      color: Color(0xFFFFC928),
      description: 'Easygoing sunshine. Smiles even when hit.',
      imagePath: 'assets/images/characters/solar_gold.png',
      unlockKey: 'ach_master',
      price: 700,
      stats: CharacterStats.standard,
    ),

    Character(
      id: 'void_dark',
      name: 'Wraith',
      color: Color(0xFF5B6272),
      description: 'Quiet shadow. Nobody knows where it came from.',
      imagePath: 'assets/images/characters/void_dark.png',
      unlockKey: 'ach_legend',
      price: 900,
      stats: CharacterStats.standard,
    ),
  ];

  static Character getCharacter(String id) {
    return availableCharacters.firstWhere(
      (c) => c.id == id,
      orElse: () => availableCharacters[0],
    );
  }

  /// (구) 스탯 등급 — 능력치 통일 후 UI 에서 쓰지 않는다
  static int energyRating(int maxEnergy) => maxEnergy.clamp(1, 5);

  static int speedRating(double mult) {
    if (mult >= 1.4) return 5;
    if (mult >= 1.2) return 4;
    if (mult >= 1.0) return 3;
    if (mult >= 0.80) return 2;
    return 1;
  }

  static int cooldownRating(double cooldown) {
    if (cooldown >= 45) return 1;  // 매우 느림 (50~55초)
    if (cooldown >= 30) return 2;  // 느림 (35초)
    if (cooldown >= 22) return 3;  // 보통 (25초)
    if (cooldown >= 14) return 4;  // 빠름 (18초)
    return 5;                      // 매우 빠름 (10초)
  }

  /// 회피(무적 시간) 등급
  static int iframeRating(double duration) {
    if (duration >= 2.2) return 5;  // 2.5s
    if (duration >= 1.55) return 4; // 1.6s
    if (duration >= 1.4) return 3;  // 1.5s
    if (duration >= 1.15) return 2; // 1.2~1.3s
    return 1;                       // 1.0s
  }

  /// 해금이 필요 없는 기본 캐릭터인지
  static bool isDefault(String id) => getCharacter(id).unlockKey == null;

  /// 현재는 전 캐릭터 개방 — 업적(뱃지·타이틀) 구조 개편 뒤 해금 조건을 다시 켠다.
  /// false 로 바꾸면 unlockKey 업적 보유 여부로 판정한다.
  static const bool allUnlocked = true;

  /// 해금 여부 — 기본 캐릭터 · 업적 달성 · 상점에서 코인으로 구매 중 하나
  static bool isUnlocked(Character char, List<String> achievementKeys) {
    if (allUnlocked) return true;
    final key = char.unlockKey;
    return key == null || achievementKeys.contains(key) || CoinStore.owns('char_${char.id}');
  }
}
