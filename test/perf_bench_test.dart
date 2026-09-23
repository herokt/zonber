import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zonber/game_settings.dart';
import 'package:zonber/main.dart';
import 'package:zonber/services/auth_service.dart';
import 'package:zonber/world_config.dart';

// 게임 루프 성능 측정 — 존마다 몇 분을 60fps 고정 dt 로 돌리며
// 프레임별 update·render(그림 기록) 시간, 멈춘 프레임(hit-stop), 컴포넌트 수를 잰다.
//   flutter test test/perf_bench_test.dart
// 판이 끝나지 않게(debugNoGameOver) 해서 늦은 판(탄 최대치)까지 간다. 소리·진동은 끈다.
// JIT(디버그) 실행이라 절대값은 실기기와 다르다 — 수정 전후 비교와 튀는 프레임을 보는 용도.
// 길이: --dart-define=PERF_SECONDS=240 (기본 90). print 는 테스트가 끝나야 한꺼번에 나온다 —
// 멈춘 것처럼 보이면 로그가 아니라 CPU 사용으로 판단할 것(2026-09-23 골키퍼 무한 루프를 이걸로 찾았다).
// 존마다 따로 돌리는 편이 안전하다: --plain-name "perf: keeper"

const double _dt = 1 / 60;
const int _seconds = int.fromEnvironment('PERF_SECONDS', defaultValue: 90);

class _Stats {
  final List<double> frameUs = [];
  double updUs = 0, renUs = 0;
  int frozen = 0;
  int maxChildren = 0;
  int maxParticles = 0;
  int endChildren = 0;

  double pct(double p) {
    final s = [...frameUs]..sort();
    return s[min(s.length - 1, (s.length * p).floor())];
  }

  String line(String id) {
    final avg = frameUs.reduce((a, b) => a + b) / frameUs.length;
    final over8 = frameUs.where((u) => u > 8000).length;
    final n = frameUs.length;
    return '${id.padRight(10)} update ${(updUs / n / 1000).toStringAsFixed(2)}ms'
        ' render ${(renUs / n / 1000).toStringAsFixed(2)}ms'
        ' | avg ${(avg / 1000).toStringAsFixed(2)}ms'
        '  p99 ${(pct(0.99) / 1000).toStringAsFixed(2)}ms'
        '  max ${(pct(1) / 1000).toStringAsFixed(2)}ms'
        '  >8ms $over8'
        '  멈춘프레임 $frozen'
        '  최대컴포넌트 $maxChildren(파티클 $maxParticles)  끝 $endChildren';
  }
}

void main() {
  setUpAll(() async {
    AuthService.debugIsGuest = false;
    SharedPreferences.setMockInitialValues({'sound_enabled': false, 'vibration_enabled': false});
    await GameSettings().load();
  });

  for (final world in WorldData.worlds) {
    testWidgets('perf: ${world.id}', (tester) async {
      final game = ZonberGame(
        mapId: world.layoutId,
        worldConfig: world,
        onExit: () {},
        onGameOver: (_) {},
      )..debugNoGameOver = true;

      await tester.pumpWidget(MaterialApp(
        home: Center(child: SizedBox(width: 400, height: 800, child: GameWidget(game: game))),
      ));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      // 이제부터는 직접 돌린다(위젯 티커는 멈춘다)
      game.pauseEngine();
      expect(game.player.isMounted, isTrue);

      final rng = Random(7);
      final stats = _Stats();
      final frames = (_seconds / _dt).round();
      final sw = Stopwatch();
      for (int f = 0; f < frames; f++) {
        // 캐릭터를 조금씩 움직인다(근접 회피·키퍼 세이브가 생기게)
        if (game.player.isMounted) {
          final p = game.player.position;
          p.x += (rng.nextDouble() - 0.5) * 8;
          p.y += (rng.nextDouble() - 0.5) * 8;
        }
        final before = game.survivalTime;
        final inIntro = game.inIntro;

        sw
          ..reset()
          ..start();
        game.update(_dt);
        final tu = sw.elapsedMicroseconds;
        final rec = ui.PictureRecorder();
        game.render(Canvas(rec));
        rec.endRecording().dispose();
        sw.stop();

        if (f > 30) {
          stats.frameUs.add(sw.elapsedMicroseconds.toDouble());
          stats.updUs += tu;
          stats.renUs += sw.elapsedMicroseconds - tu;
        }
        if (f % 1800 == 0) {
          final byType = <String, int>{};
          for (final c in game.mapArea.children) {
            byType.update('${c.runtimeType}', (v) => v + 1, ifAbsent: () => 1);
          }
          // ignore: avoid_print
          print('[perf:${world.id}] ${(f * _dt).round()}s 컴포넌트 ${game.mapArea.children.length} $byType');
        }
        if (!inIntro && !game.inIntro && game.survivalTime == before) stats.frozen++;
        final kids = game.mapArea.children;
        stats.maxChildren = max(stats.maxChildren, kids.length);
        stats.maxParticles = max(stats.maxParticles, kids.whereType<ParticleSystemComponent>().length);
        // 매 프레임 마이크로태스크를 비운다(측정 밖) — 실제 앱처럼 onLoad 가 바로 끝나야 컴포넌트 추가·제거가
        // 밀리지 않는다. (60프레임마다만 비웠더니 제거 대기 중인 분열 공이 계속 분열해 가짜 누수가 보였다)
        await tester.pump(Duration.zero);
      }
      stats.endChildren = game.mapArea.children.length;
      // ignore: avoid_print
      print('[perf] ${stats.line(world.id)}  (${game.survivalTime.toStringAsFixed(0)}s)');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
