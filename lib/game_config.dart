class StageConfig {
  final String id;
  final String nameKey;
  final String descKey;
  final double bulletSpeed;
  final double spawnInterval;
  final int maxBullets;
  final int difficultyLevel;
  final List<String> traits;

  const StageConfig({
    required this.id,
    required this.nameKey,
    required this.descKey,
    required this.bulletSpeed,
    required this.spawnInterval,
    required this.maxBullets,
    required this.difficultyLevel,
    this.traits = const [],
  });
}

class GameConfig {
  // All stages start with the same bullet speed and spawn interval.
  // Difficulty increases over time via BulletSpawner's ramping logic.
  static const List<StageConfig> stages = [
    StageConfig(
      id: 'zone_1_classic',
      nameKey: 'zone_1_title',
      descKey: 'zone_1_desc',
      bulletSpeed: 150.0,
      spawnInterval: 0.10,
      maxBullets: 60,
      difficultyLevel: 1,
      traits: ['BASIC', 'OPEN'],
    ),
    StageConfig(
      id: 'zone_2_obstacles',
      nameKey: 'zone_2_title',
      descKey: 'zone_2_desc',
      bulletSpeed: 150.0,
      spawnInterval: 0.10,
      maxBullets: 60,
      difficultyLevel: 2,
      traits: ['PILLARS', 'COVER'],
    ),
    StageConfig(
      id: 'zone_5_maze',
      nameKey: 'zone_5_title',
      descKey: 'zone_5_desc',
      bulletSpeed: 150.0,
      spawnInterval: 0.10,
      maxBullets: 90,
      difficultyLevel: 3,
      traits: ['MAZE', 'EXTREME'],
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
