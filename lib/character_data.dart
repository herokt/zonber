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

}

class Character {
  final String id;
  final String name;
  final Color color;
  /// 성격 한 줄(컨셉 문서 docs/CHARACTER_CONCEPT.md). 능력치는 모두 같다.
  final String description;
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
      stats: CharacterStats.standard,
    ),

    Character(
      id: 'electric_blue',
      name: 'Zap',
      color: Color(0xFF3B8EF0),
      description: 'Restless and quick-witted. Never sits still.',
      unlockKey: 'ach_survivor',
      price: 200,
      stats: CharacterStats.standard,
    ),

    Character(
      id: 'plasma_purple',
      name: 'Luna',
      color: Color(0xFFA66BF2),
      description: 'Dreamy and mysterious. Hums while dodging.',
      unlockKey: 'ach_veteran',
      price: 200,
      stats: CharacterStats.standard,
    ),

    Character(
      id: 'cyber_red',
      name: 'Blaze',
      color: Color(0xFFF2503D),
      description: 'Fired up and puffy-cheeked. Pouts when losing.',
      unlockKey: 'ach_elite',
      price: 200,
      stats: CharacterStats.standard,
    ),

    Character(
      id: 'solar_gold',
      name: 'Sunny',
      color: Color(0xFFFFC928),
      description: 'Easygoing sunshine. Smiles even when hit.',
      unlockKey: 'ach_master',
      price: 200,
      stats: CharacterStats.standard,
    ),

    Character(
      id: 'void_dark',
      name: 'Wraith',
      color: Color(0xFF5B6272),
      description: 'Quiet night. Watches with long lashes and says nothing.',
      unlockKey: 'ach_legend',
      price: 200,
      stats: CharacterStats.standard,
    ),

    Character(
      id: 'blossom_pink',
      name: 'Cherry',
      color: Color(0xFFFF7FB0),
      description: 'Loves being looked at. Poses even mid-dodge.',
      unlockKey: 'b_runs_100',
      price: 200,
      stats: CharacterStats.standard,
    ),

    Character(
      id: 'frost_cyan',
      name: 'Coco',
      color: Color(0xFF35C9E8),
      description: 'The little one. Big round eyes, tiny cat mouth.',
      unlockKey: 'b_time_1h',
      price: 200,
      stats: CharacterStats.standard,
    ),
  ];

  static Character getCharacter(String id) {
    return availableCharacters.firstWhere(
      (c) => c.id == id,
      orElse: () => availableCharacters[0],
    );
  }

  /// 2026-09-22 코인 해금을 켰다(false). 이미 쓰던 캐릭터는 상점이 보유로 넣어 준다(ShopPage._load).
  static const bool allUnlocked = false;

  /// 해금 여부 — 기본 캐릭터 · 업적 달성 · 상점에서 코인으로 구매 중 하나
  static bool isUnlocked(Character char, List<String> achievementKeys) {
    if (allUnlocked) return true;
    final key = char.unlockKey;
    return key == null || achievementKeys.contains(key) || CoinStore.owns('char_${char.id}');
  }
}
