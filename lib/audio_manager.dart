import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flame_audio/flame_audio.dart';
import 'game_settings.dart';

/// 효과음 이름 — assets/audio/*.wav. 새 효과음은 scripts/make_sfx.py 로 합성한다.
class Sfx {
  static const hit = 'hit.wav'; // 피격
  static const gameOver = 'gameover.wav';
  static const throwBall = 'throw.wav'; // 피구 던지기
  static const kick = 'kick.wav'; // 골키퍼 킥
  static const save = 'save.wav'; // 선방 · 키퍼 터치
  static const goal = 'goal.wav'; // 실점(골망 + 호루라기)
  static const graze = 'graze.wav'; // 추가 기록
  static const coin = 'coin.wav';
  static const badge = 'badge.wav';
  static const purchase = 'purchase.wav';
  static const equip = 'equip.wav';
  static const levelUp = 'levelup.wav';
  static const newBest = 'newbest.wav';
  static const heartbeat = 'heartbeat.wav'; // 위기(반복)
  static const click = 'click.wav';

  static const all = [hit, gameOver, throwBall, kick, save, goal, graze, coin, badge, purchase, equip, levelUp, newBest, heartbeat, click];

  /// 자주 겹쳐 나는 소리 — 플레이어를 더 많이 만들어 둔다(동시에 [busyPlayers]개까지 겹쳐 난다)
  static const busy = [hit, save, graze, kick, throwBall, coin];
  static const busyPlayers = 4;
  static const otherPlayers = 2;
}

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  bool _isBgmPlaying = false;
  /// 효과음마다 미리 만든 저지연 플레이어 몇 개 — 차례로 돌려 쓴다.
  /// 게임 중에는 플레이어를 새로 만들지 않는다. (예전 AudioPool·FlameAudio.play 는 겹칠 때마다
  /// 플레이어를 새로 만들고 버리지 않아서, 맞거나 막는 순간 멈칫하고 오래 하면 쌓였다)
  final Map<String, List<AudioPlayer>> _players = {};
  final Map<String, int> _next = {};
  final Map<String, int> _lastPlayed = {};
  AudioPlayer? _heart;
  bool _heartWanted = false;
  bool _heartStarting = false;

  AppLifecycleListener? _life;

  Future<void> initialize() async {
    // 앱이 가려지면 반복 중인 심장박동을 멈추고, 다시 보이면 잇는다
    _life ??= AppLifecycleListener(
      onHide: () => _heart?.pause(),
      onShow: () {
        if (_heartWanted) _heart?.resume();
      },
    );
    try {
      await FlameAudio.audioCache.loadAll(['bgm.mp3', ...Sfx.all]);
    } catch (e) {
      debugPrint("Audio load failed: $e (This is expected if files are missing)");
    }
    // 플레이어는 기다리지 않고 뒤에서 만든다 — 앱 시작을 늦추지 않게. 다 되기 전의 효과음은 건너뛴다
    unawaited(Future.wait([
      for (final name in Sfx.all)
        for (int i = 0; i < (Sfx.busy.contains(name) ? Sfx.busyPlayers : Sfx.otherPlayers); i++) _addPlayer(name),
    ]));
  }

  static final AudioContext _sfxContext = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();

  Future<void> _addPlayer(String name) async {
    try {
      final p = AudioPlayer()..audioCache = FlameAudio.audioCache;
      await p.setAudioContext(_sfxContext);
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setSource(AssetSource(name));
      (_players[name] ??= []).add(p);
    } catch (e) {
      debugPrint('Sfx player failed ($name): $e');
    }
  }

  void startBgm() {
    if (!GameSettings().soundEnabled) return;
    if (_isBgmPlaying) return;
    try {
      FlameAudio.bgm.play('bgm.mp3', volume: 0.5);
      _isBgmPlaying = true;
    } catch (e) {
      debugPrint("BGM play failed: $e");
    }
  }

  void stopBgm() {
    try {
      FlameAudio.bgm.stop();
      _isBgmPlaying = false;
    } catch (e) {
      debugPrint("BGM stop failed: $e");
    }
  }

  /// 효과음. [minGapMs] 안에 같은 소리가 또 오면 건너뛴다(연달아 쌓이는 소리 방지)
  void playSfx(String name, {double volume = 1.0, int minGapMs = 0}) {
    if (!GameSettings().soundEnabled) return;
    if (minGapMs > 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - (_lastPlayed[name] ?? 0) < minGapMs) return;
      _lastPlayed[name] = now;
    }
    final list = _players[name];
    if (list == null || list.isEmpty) return; // 아직 준비 전이거나 파일 없음
    final i = (_next[name] ?? 0) % list.length;
    _next[name] = i + 1;
    unawaited(_restart(list[i], volume));
  }

  /// 처음부터 다시 — 저지연 플레이어는 멈췄다가(stop) 다시 틀어야(resume) 새로 난다
  Future<void> _restart(AudioPlayer p, double volume) async {
    try {
      await p.stop();
      await p.setVolume(volume);
      await p.resume();
    } catch (_) {
      // 소리 하나 못 낸 것은 넘어간다
    }
  }

  /// 위기 심장박동(반복) 켜기/끄기 — 에너지 1칸일 때 게임이 켠다. 멈춤·게임 오버·나가기에서 끈다
  Future<void> setHeartbeat(bool on) async {
    _heartWanted = on && GameSettings().soundEnabled;
    if (_heartWanted && _heart == null && !_heartStarting) {
      _heartStarting = true; // 켜는 중 — 겹쳐 두 번 켜지지 않게
      try {
        final p = await FlameAudio.loop(Sfx.heartbeat, volume: 0.55);
        if (_heartWanted) {
          _heart = p;
        } else {
          await p.stop(); // 켜는 사이에 꺼달라는 요청이 왔다
        }
      } catch (e) {
        debugPrint('Heartbeat failed: $e');
      } finally {
        _heartStarting = false;
      }
    } else if (!_heartWanted && _heart != null) {
      final p = _heart!;
      _heart = null;
      try {
        await p.stop();
        await p.dispose();
      } catch (_) {}
    }
  }

}
