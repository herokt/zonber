import 'package:flutter/material.dart';

class CharacterStats {
  final double hitboxSize;      // 히트박스 한 변 길이 (px) — 작을수록 유리
  final double speedMultiplier; // dragInput 배수
  final int shieldCount;        // 보유 가능한 실드 개수
  final double shieldCooldown;  // 실드 1개 충전 대기 시간 (초)

  const CharacterStats({
    required this.hitboxSize,
    required this.speedMultiplier,
    required this.shieldCount,
    required this.shieldCooldown,
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
    // 피지컬 ★★★  속도 ★★★  에너지 ★★★
    // ──────────────────────────────────────────
    Character(
      id: 'neon_green',
      name: 'Neon Green',
      color: Color(0xFF45A29E),
      description: 'Balanced operator. No weakness, no peak.',
      imagePath: 'assets/images/characters/neon_green.png',
      stats: CharacterStats(
        hitboxSize: 22,
        speedMultiplier: 1.0,
        shieldCount: 1,
        shieldCooldown: 15,
      ),
    ),

    // ──────────────────────────────────────────
    // 🔵 Electric Blue — 속도+피지컬 특화 (중급)
    // 피지컬 ★★★★★  속도 ★★★★  에너지 ★
    // ──────────────────────────────────────────
    Character(
      id: 'electric_blue',
      name: 'Electric Blue',
      color: Color(0xFF1D8CF2),
      description: 'Smallest and fastest. One hit means death.',
      imagePath: 'assets/images/characters/electric_blue.png',
      stats: CharacterStats(
        hitboxSize: 14,
        speedMultiplier: 1.2,
        shieldCount: 0,
        shieldCooldown: 0,
      ),
    ),

    // ──────────────────────────────────────────
    // 🟣 Plasma Purple — 에너지 탱커 (중급)
    // 피지컬 ★★  속도 ★★  에너지 ★★★★★
    // ──────────────────────────────────────────
    Character(
      id: 'plasma_purple',
      name: 'Plasma Purple',
      color: Color(0xFFD91DF2),
      description: 'Slow and large, but survives two mistakes.',
      imagePath: 'assets/images/characters/plasma_purple.png',
      stats: CharacterStats(
        hitboxSize: 26,
        speedMultiplier: 0.85,
        shieldCount: 2,
        shieldCooldown: 10,
      ),
    ),

    // ──────────────────────────────────────────
    // 🔴 Cyber Red — 대형 속도형 (고급)
    // 피지컬 ★  속도 ★★★★★  에너지 ★★★
    // ──────────────────────────────────────────
    Character(
      id: 'cyber_red',
      name: 'Cyber Red',
      color: Color(0xFFF21D1D),
      description: 'Biggest target, but pure speed carries you through.',
      imagePath: 'assets/images/characters/cyber_red.png',
      stats: CharacterStats(
        hitboxSize: 30,
        speedMultiplier: 1.4,
        shieldCount: 1,
        shieldCooldown: 15,
      ),
    ),

    // ──────────────────────────────────────────
    // 🟡 Solar Gold — 초소형 방어형 (고급)
    // 피지컬 ★★★★★  속도 ★  에너지 ★★★
    // ──────────────────────────────────────────
    Character(
      id: 'solar_gold',
      name: 'Solar Gold',
      color: Color(0xFFFFD700),
      description: 'Micro-body with heavy armor. Nearly impossible to hit.',
      imagePath: 'assets/images/characters/neon_green.png', // TODO: replace with solar_gold.png
      stats: CharacterStats(
        hitboxSize: 14,
        speedMultiplier: 0.70,
        shieldCount: 1,
        shieldCooldown: 15,
      ),
    ),

    // ──────────────────────────────────────────
    // 🔷 Void Dark — 에너지+속도 균형 (고급)
    // 피지컬 ★★  속도 ★★★  에너지 ★★★★★
    // ──────────────────────────────────────────
    Character(
      id: 'void_dark',
      name: 'Void Dark',
      color: Color(0xFF6366F1),
      description: 'Swift and double-shielded. The hardest to master.',
      imagePath: 'assets/images/characters/plasma_purple.png', // TODO: replace with void_dark.png
      stats: CharacterStats(
        hitboxSize: 24,
        speedMultiplier: 1.0,
        shieldCount: 2,
        shieldCooldown: 8,
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
  /// 피지컬은 역방향: 히트박스가 작을수록 높은 등급
  static int hitboxRating(double hitboxSize) {
    if (hitboxSize <= 14) return 5;
    if (hitboxSize <= 18) return 4;
    if (hitboxSize <= 22) return 3;
    if (hitboxSize <= 26) return 2;
    return 1;
  }

  static int speedRating(double mult) {
    if (mult >= 1.4) return 5;
    if (mult >= 1.2) return 4;
    if (mult >= 1.0) return 3;
    if (mult >= 0.85) return 2;
    return 1;
  }

  static int shieldRating(int count, double cooldown) {
    if (count == 0) return 1;                           // ★
    if (count == 1 && cooldown >= 20) return 2;         // ★★
    if (count == 1 && cooldown < 20) return 3;          // ★★★
    if (count == 2 && cooldown >= 12) return 4;         // ★★★★
    return 5;                                           // ★★★★★
  }
}
