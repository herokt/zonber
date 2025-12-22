import 'package:flame_audio/flame_audio.dart';
import 'game_settings.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  bool _isBgmPlaying = false;

  // Initialize and load sounds (if needed, flame_audio caches automatically on first play usually or we can load all)
  Future<void> initialize() async {
    // Ideally we load everything here
    try {
      await FlameAudio.audioCache.loadAll([
        'bgm.mp3',
        'shoot.wav',
        'hit.wav',
        'gameover.wav',
      ]);
    } catch (e) {
      print("Audio load failed: $e (This is expected if files are missing)");
    }
  }

  void startBgm() {
    if (!GameSettings().soundEnabled) return;
    if (_isBgmPlaying) return;
    try {
      FlameAudio.bgm.play('bgm.mp3', volume: 0.5);
      _isBgmPlaying = true;
    } catch (e) {
      print("BGM play failed: $e");
    }
  }

  void stopBgm() {
    try {
      FlameAudio.bgm.stop();
      _isBgmPlaying = false;
    } catch (e) {
      print("BGM stop failed: $e");
    }
  }

  void playSfx(String name, {double volume = 1.0}) {
    if (!GameSettings().soundEnabled) return;
    try {
      FlameAudio.play(name, volume: volume);
    } catch (e) {
      // Mute errors to prevent spamming logs if file missing
    }
  }

  // Handle setting change dynamic update
  void refreshBgm() {
    if (GameSettings().soundEnabled) {
      if (!_isBgmPlaying) startBgm();
    } else {
      stopBgm();
    }
  }
}
