import 'package:flutter/material.dart';

class CharacterStats {
  final double hitboxSize;      // 히트박스 한 변 길이 (px) — 작을수록 유리
  final double speedMultiplier; // dragInput 배수
  final int shieldCount;        // 보유 가능한 실드 개수
  final double shieldCooldown;  // 실드 1개 충전 대기 시간 (초)
  final double repelRadius;     // 반발력 유효 반경 (px)
  final double repelForce;      // 반발 힘 (px/s)

  const CharacterStats({
    required this.hitboxSize,
    required this.speedMultiplier,
    required this.shieldCount,
    required this.shieldCooldown,
    required this.repelRadius,
    required this.repelForce,
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
    // 덩치 ★★☆  속도 ★★★★☆  체력 ★★☆  반발력 ★★☆
    // ──────────────────────────────────────────
    Character(
      id: 'neon_green',
      name: 'Neon Green',
      color: Color(0xFF45A29E),
      description: 'Balanced operator. No weakness, no peak.',
      imagePath: 'assets/images/characters/neon_green.png',
      stats: CharacterStats(
        hitboxSize: 18,
        speedMultiplier: 1.2,
        shieldCount: 1,
        shieldCooldown: 20,
        repelRadius: 40,
        repelForce: 20,
      ),
    ),

    // ──────────────────────────────────────────
    // 🔴 Cyber Red — 반발력 특화 (고급)
    // 덩치 ★★★★★  속도 ★☆  체력 ★★★☆  반발력 ★★★★★
    // ──────────────────────────────────────────
    Character(
      id: 'cyber_red',
      name: 'Cyber Red',
      color: Color(0xFFF21D1D),
      description: 'Biggest target, but bullets bend away.',
      imagePath: 'assets/images/characters/cyber_red.png',
      stats: CharacterStats(
        hitboxSize: 30,
        speedMultiplier: 0.70,
        shieldCount: 1,
        shieldCooldown: 12,
        repelRadius: 100,
        repelForce: 70,
      ),
    ),

    // ──────────────────────────────────────────
    // 🔵 Electric Blue — 속도 특화 (중급)
    // 덩치 ★☆  속도 ★★★★★  체력 ★☆  반발력 ★★★★☆
    // ──────────────────────────────────────────
    Character(
      id: 'electric_blue',
      name: 'Electric Blue',
      color: Color(0xFF1D8CF2),
      description: 'Smallest and fastest. One hit means death.',
      imagePath: 'assets/images/characters/electric_blue.png',
      stats: CharacterStats(
        hitboxSize: 14,
        speedMultiplier: 1.4,
        shieldCount: 0,
        shieldCooldown: 0,
        repelRadius: 80,
        repelForce: 50,
      ),
    ),

    // ──────────────────────────────────────────
    // 🟣 Plasma Purple — 체력 특화 (중급)
    // 덩치 ★★★★☆  속도 ★★☆  체력 ★★★★★  반발력 ★★★☆
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
        repelRadius: 60,
        repelForce: 35,
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
  /// 덩치는 역방향: 히트박스가 작을수록 높은 등급
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
    if (count == 0) return 1;
    if (count == 1 && cooldown >= 20) return 2;
    if (count == 1 && cooldown >= 12) return 3;
    if (count == 2 && cooldown >= 10) return 4;
    return 5;
  }

  static int repelRating(double radius) {
    if (radius <= 0) return 1;
    if (radius <= 40) return 2;
    if (radius <= 60) return 3;
    if (radius <= 80) return 4;
    return 5;
  }
}
