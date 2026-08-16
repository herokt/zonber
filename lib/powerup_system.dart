import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 파워업 타입
// ─────────────────────────────────────────────────────────────────────────────

enum PowerUpType { speedBoost, shield, bulletClear, slowTime }

// ─────────────────────────────────────────────────────────────────────────────
// 파워업 정의 (타입별 고정 스펙)
// ─────────────────────────────────────────────────────────────────────────────

class PowerUpDef {
  final PowerUpType type;
  final String nameKey; // translations.dart 키
  final Color color;
  final double duration; // 지속 시간(초). 0 = 즉시 효과

  const PowerUpDef({
    required this.type,
    required this.nameKey,
    required this.color,
    required this.duration,
  });

  static const Map<PowerUpType, PowerUpDef> all = {
    PowerUpType.speedBoost: PowerUpDef(
      type: PowerUpType.speedBoost,
      nameKey: 'powerup_speed',
      color: Color(0xFF00E5FF),
      duration: 8.0,
    ),
    PowerUpType.shield: PowerUpDef(
      type: PowerUpType.shield,
      nameKey: 'powerup_shield',
      color: Color(0xFF69F0AE), // 녹색 — 에너지 1 즉시 추가
      duration: 0.0,
    ),
    PowerUpType.bulletClear: PowerUpDef(
      type: PowerUpType.bulletClear,
      nameKey: 'powerup_clear',
      color: Color(0xFFFF6D00), // 주황 — 화면 탄막 전체 소멸
      duration: 0.0,
    ),
    PowerUpType.slowTime: PowerUpDef(
      type: PowerUpType.slowTime,
      nameKey: 'powerup_slow',
      color: Color(0xFFCE93D8),
      duration: 8.0,
    ),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// 활성 효과 (지속 시간이 있는 파워업 추적용)
// ─────────────────────────────────────────────────────────────────────────────

class ActiveEffect {
  final PowerUpType type;
  double remaining;
  final double total;

  ActiveEffect({required this.type, required this.total})
      : remaining = total;

  /// UI 진행바용 — 0.0(소진) ~ 1.0(풀충전)
  double get progress => (remaining / total).clamp(0.0, 1.0);
}
