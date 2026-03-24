import 'package:flutter/material.dart';

class CharacterStats {
  final int maxEnergy;          // 체력: 총 에너지량 (1~5)
  final double speedMultiplier; // 속도: dragInput 배수
  final double energyCooldown;  // 기력: 에너지 1 회복 대기 시간 (초, 0=회복없음)

  const CharacterStats({
    required this.maxEnergy,
    required this.speedMultiplier,
    required this.energyCooldown,
  });
}

class Character {
  final String id;
  final String name;
  final Color color;
  final String description;
  final String? imagePath;
  final CharacterStats stats;

  const Character({
    required this.id,
    required this.name,
    required this.color,
    required this.description,
    required this.stats,
    this.imagePath,
  });
}

class CharacterData {
  static const List<Character> availableCharacters = [
    // ──────────────────────────────────────────
    // 🟢 Neon Green — 올라운더 (초보자 추천)
    // 체력 ★★★  속도 ★★★  기력 ★★★
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
      ),
    ),

    // ──────────────────────────────────────────
    // 🔵 Electric Blue — 속도 특화 (중급)
    // 체력 ★★  속도 ★★★★★  기력 ★
    // ──────────────────────────────────────────
    Character(
      id: 'electric_blue',
      name: 'Electric Blue',
      color: Color(0xFF1D8CF2),
      description: 'Blazing speed. Fragile and slow to recover.',
      imagePath: 'assets/images/characters/electric_blue.png',
      stats: CharacterStats(
        maxEnergy: 2,
        speedMultiplier: 1.4,
        energyCooldown: 50,
      ),
    ),

    // ──────────────────────────────────────────
    // 🟣 Plasma Purple — 기력 특화 (중급)
    // 체력 ★★  속도 ★★  기력 ★★★★★
    // ──────────────────────────────────────────
    Character(
      id: 'plasma_purple',
      name: 'Plasma Purple',
      color: Color(0xFFD91DF2),
      description: 'Slow and fragile, but energy refills fastest.',
      imagePath: 'assets/images/characters/plasma_purple.png',
      stats: CharacterStats(
        maxEnergy: 2,
        speedMultiplier: 0.85,
        energyCooldown: 10,
      ),
    ),

    // ──────────────────────────────────────────
    // 🔴 Cyber Red — 체력+속도 (고급)
    // 체력 ★★★★  속도 ★★★★  기력 ★
    // ──────────────────────────────────────────
    Character(
      id: 'cyber_red',
      name: 'Cyber Red',
      color: Color(0xFFF21D1D),
      description: 'Tanky and fast, but energy barely recovers.',
      imagePath: 'assets/images/characters/cyber_red.png',
      stats: CharacterStats(
        maxEnergy: 4,
        speedMultiplier: 1.2,
        energyCooldown: 55,
      ),
    ),

    // ──────────────────────────────────────────
    // 🟡 Solar Gold — 체력 생존가 (고급)
    // 체력 ★★★★★  속도 ★  기력 ★★★
    // ──────────────────────────────────────────
    Character(
      id: 'solar_gold',
      name: 'Solar Gold',
      color: Color(0xFFFFD700),
      description: 'Maximum energy. Sluggish, but nearly unkillable.',
      imagePath: 'assets/images/characters/solar_gold.png',
      stats: CharacterStats(
        maxEnergy: 5,
        speedMultiplier: 0.70,
        energyCooldown: 35,
      ),
    ),

    // ──────────────────────────────────────────
    // 🤍 Wraith — 속도+기력 (고급)
    // 체력 ★  속도 ★★★★  기력 ★★★★
    // ──────────────────────────────────────────
    Character(
      id: 'void_dark',
      name: 'Wraith',
      color: Color(0xFFD1D5DB),
      description: 'One hit kills. Compensates with speed and fast recovery.',
      imagePath: 'assets/images/characters/void_dark.png',
      stats: CharacterStats(
        maxEnergy: 1,
        speedMultiplier: 1.25,
        energyCooldown: 18,
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
}
