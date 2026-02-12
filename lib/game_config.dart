class StageConfig {
  final String id;
  final String nameKey; // Translation key
  final String descKey; // Translation key
  final double bulletSpeed;
  final double spawnInterval;
  final int maxBullets;
  // Visual & Map properties
  final int difficultyLevel; // 1, 2, 3
  final List<String> traits; // ["Easy", "Fast"]

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
  static const List<StageConfig> stages = [
    StageConfig(
      id: 'zone_1_classic',
      nameKey: 'zone_1_title', // "Classic"
      descKey: 'zone_1_desc', // "Open field, slow bullets"
      bulletSpeed: 145.0,
      spawnInterval: 0.1,
      maxBullets: 50,
      difficultyLevel: 1,
      traits: ['BASIC', 'OPEN'],
    ),
    StageConfig(
      id: 'zone_2_prism',
      nameKey: 'zone_2_title', // "Prism"
      descKey: 'zone_2_desc', // "Diamonds & Reflections"
      bulletSpeed: 180.0,
      spawnInterval: 0.08,
      maxBullets: 80,
      difficultyLevel: 2,
      traits: ['CHAOS', 'REFLECT'],
    ),
    StageConfig(
      id: 'zone_3_spiral',
      nameKey: 'zone_3_title', // "Spiral"
      descKey: 'zone_3_desc', // "Trapped path, high speed"
      bulletSpeed: 230.0,
      spawnInterval: 0.06,
      maxBullets: 120,
      difficultyLevel: 3,
      traits: ['HARDCORE', 'MAZE'],
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
