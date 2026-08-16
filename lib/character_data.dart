import 'package:flutter/material.dart';

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

  /// 실질 생존력 지표 — 무적 시간의 총합(초).
  /// 무적 중에는 닿는 탄환이 제거되므로 이 값이 곧 "탄막을 뚫고 지나갈 수 있는 시간"이다.
  double get invulnBudget => maxEnergy * iframeDuration;
}

class Character {
  final String id;
  final String name;
  final Color color;
  final String description;
  final String? imagePath;
  final CharacterStats stats;

  /// 해금 조건이 되는 업적 키. null이면 기본 해금.
  final String? unlockKey;

  const Character({
    required this.id,
    required this.name,
    required this.color,
    required this.description,
    required this.stats,
    this.imagePath,
    this.unlockKey,
  });
}

class CharacterData {
  static const List<Character> availableCharacters = [
    // ──────────────────────────────────────────
    // 🟢 Neon Green — 올라운더 (기본 해금)
    // 체력 ★★★  속도 ★★★  기력 ★★★  회피 ★★★   무적예산 4.5s
    // ──────────────────────────────────────────
    Character(
      id: 'neon_green',
      name: 'Neon Green',
      color: Color(0xFF45A29E),
      description: 'Balanced operator. No weakness, no peak.',
      imagePath: 'assets/images/characters/neon_green.png',
      stats: CharacterStats(
        maxEnergy: 3,
        speedMultiplier: 1.0,
        energyCooldown: 25,
        iframeDuration: 1.5,
      ),
    ),

    // ──────────────────────────────────────────
    // 🔵 Electric Blue — 속도 특화 (60초 생존)
    // 체력 ★★  속도 ★★★★★  기력 ★  회피 ★★★★   무적예산 3.2s
    // ──────────────────────────────────────────
    Character(
      id: 'electric_blue',
      name: 'Electric Blue',
      color: Color(0xFF1D8CF2),
      description: 'Blazing speed. Fragile and slow to recover.',
      imagePath: 'assets/images/characters/electric_blue.png',
      unlockKey: 'ach_survivor',
      stats: CharacterStats(
        maxEnergy: 2,
        speedMultiplier: 1.4,
        energyCooldown: 50,
        iframeDuration: 1.6,
      ),
    ),

    // ──────────────────────────────────────────
    // 🟣 Plasma Purple — 기력 특화 (120초 생존)
    // 체력 ★★  속도 ★★  기력 ★★★★★  회피 ★★   무적예산 2.6s
    // 회복이 압도적이라 무적 시간은 짧게 잡아 균형을 맞춤
    // ──────────────────────────────────────────
    Character(
      id: 'plasma_purple',
      name: 'Plasma Purple',
      color: Color(0xFFD91DF2),
      description: 'Slow and fragile, but energy refills fastest.',
      imagePath: 'assets/images/characters/plasma_purple.png',
      unlockKey: 'ach_veteran',
      stats: CharacterStats(
        maxEnergy: 2,
        speedMultiplier: 0.85,
        energyCooldown: 10,
        iframeDuration: 1.3,
      ),
    ),

    // ──────────────────────────────────────────
    // 🔴 Cyber Red — 체력+속도 (180초 생존)
    // 체력 ★★★★  속도 ★★★★  기력 ★  회피 ★★   무적예산 4.8s
    // ──────────────────────────────────────────
    Character(
      id: 'cyber_red',
      name: 'Cyber Red',
      color: Color(0xFFF21D1D),
      description: 'Tanky and fast, but energy barely recovers.',
      imagePath: 'assets/images/characters/cyber_red.png',
      unlockKey: 'ach_elite',
      stats: CharacterStats(
        maxEnergy: 4,
        speedMultiplier: 1.2,
        energyCooldown: 55,
        iframeDuration: 1.2,
      ),
    ),

    // ──────────────────────────────────────────
    // 🟡 Solar Gold — 체력 생존가 (240초 생존)
    // 체력 ★★★★★  속도 ★  기력 ★★★  회피 ★   무적예산 5.0s
    // ──────────────────────────────────────────
    Character(
      id: 'solar_gold',
      name: 'Solar Gold',
      color: Color(0xFFFFD700),
      description: 'Maximum energy. Sluggish, but nearly unkillable.',
      imagePath: 'assets/images/characters/solar_gold.png',
      unlockKey: 'ach_master',
      stats: CharacterStats(
        maxEnergy: 5,
        speedMultiplier: 0.70,
        energyCooldown: 35,
        iframeDuration: 1.0,
      ),
    ),

    // ──────────────────────────────────────────
    // 🤍 Wraith — 원히트 킬 (300초 생존)
    // 체력 ★  속도 ★★★★  기력 ★★★★  회피 ★★★★★   무적예산 2.5s
    // 에너지 1칸뿐이라 긴 무적으로 보상 — 한 번의 피격이 곧 탄막 돌파 기회
    // ──────────────────────────────────────────
    Character(
      id: 'void_dark',
      name: 'Wraith',
      color: Color(0xFFD1D5DB),
      description: 'One hit kills. Compensates with speed and a long i-frame.',
      imagePath: 'assets/images/characters/void_dark.png',
      unlockKey: 'ach_legend',
      stats: CharacterStats(
        maxEnergy: 1,
        speedMultiplier: 1.25,
        energyCooldown: 18,
        iframeDuration: 2.5,
      ),
    ),
  ];

  static Character getCharacter(String id) {
    return availableCharacters.firstWhere(
      (c) => c.id == id,
      orElse: () => availableCharacters[0],
    );
  }

  /// 스탯 등급 (1~5) — UI 스탯 바 표시용
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

  /// 보유 업적 키 목록으로 해금 여부 판정
  static bool isUnlocked(Character char, List<String> achievementKeys) {
    final key = char.unlockKey;
    return key == null || achievementKeys.contains(key);
  }
}
