class StageConfig {
  final String id;
  final double bulletSpeed;
  final double spawnInterval;

  const StageConfig({
    required this.id,
    required this.bulletSpeed,
    required this.spawnInterval,
  });
}

class GameConfig {
  // 장애물 레이아웃 — 모든 월드가 zone_1_classic(장애물 없음)을 쓴다.
  // All stages start with the same bullet speed and spawn interval.
  // Difficulty increases over time via BulletSpawner's ramping logic.
  static const List<StageConfig> stages = [
    StageConfig(
      id: 'zone_1_classic',
      bulletSpeed: 150.0,
      spawnInterval: 0.10,
    ),
  ];

  static StageConfig? getStage(String id) {
    try {
      return stages.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }
}
