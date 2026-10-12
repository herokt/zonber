import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zonber/coin_store.dart';
import 'package:zonber/game_settings.dart';
import 'package:zonber/main.dart';
import 'package:zonber/pets.dart';
import 'package:zonber/services/auth_service.dart';
import 'package:zonber/world_config.dart';

// 펫 · 게임 오버 연출을 실제 게임 루프로 돌려 본다(perf_bench_test 와 같은 방식 — 60fps 고정 dt).
//   flutter test test/pet_game_test.dart
// 그림으로 보려면 --dart-define=PET_SHOT_DIR=<폴더> — 존마다 펫이 도는 장면과 KO 장면을 PNG 로 남긴다.

const double _dt = 1 / 60;
const String _shotDir = String.fromEnvironment('PET_SHOT_DIR');

Future<ZonberGame> _start(WidgetTester tester, WorldConfig world, {bool noGameOver = true, void Function(Map<String, dynamic>)? onGameOver}) async {
  final game = ZonberGame(
    mapId: world.layoutId,
    worldConfig: world,
    onExit: () {},
    onGameOver: onGameOver ?? (_) {},
  )..debugNoGameOver = noGameOver;
  // 시안 아트는 게임이 기다리지 않고 읽는다 — 테스트는 그림이 들어간 화면을 보려고 먼저 읽어 둔다
  await tester.runAsync(() async {
    await GameSprites.load(game);
    if (_shotDir.isNotEmpty) await game.images.load('worlds/${world.id}_bg.png'); // 그림으로 볼 때만 배경도
  });
  await tester.pumpWidget(MaterialApp(
    home: Center(child: SizedBox(width: 400, height: 800, child: GameWidget(game: game))),
  ));
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  game.pauseEngine(); // 이제부터는 직접 돌린다
  return game;
}

Future<void> _step(WidgetTester tester, ZonberGame game, {Random? wiggle}) async {
  if (wiggle != null && game.player.isMounted) {
    final p = game.player.position;
    p.x = (p.x + (wiggle.nextDouble() - 0.5) * 8).clamp(40, 440);
    p.y = (p.y + (wiggle.nextDouble() - 0.5) * 8).clamp(80, 700);
  }
  game.update(_dt);
  await tester.pump(Duration.zero);
}

Future<void> _shot(WidgetTester tester, ZonberGame game, String name) async {
  if (_shotDir.isEmpty) return;
  await tester.runAsync(() async {
    // 휴대폰 화면처럼 3배 밀도로 찍는다
    const k = 3.0;
    final rec = ui.PictureRecorder();
    game.render(Canvas(rec)..scale(k));
    final img = await rec.endRecording().toImage((game.size.x * k).round(), (game.size.y * k).round());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$_shotDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // 소리 플러그인이 없는 테스트 환경 — 게임 오버 효과음 호출이 예외를 내지 않게
    for (final ch in ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(ch), (_) async => null);
    }
    AuthService.debugIsGuest = false;
    SharedPreferences.setMockInitialValues({
      'sound_enabled': false,
      'vibration_enabled': false,
      'equipped_items': ['${Pets.slotKey}:pet_dragon'],
    });
    await GameSettings().load();
    await CoinStore.load();
  });

  for (final world in WorldData.worlds) {
    testWidgets('펫: ${world.id} — 데리고 가면 나오고, 같은 빠르기로 돌며, 쳐낸 공은 바깥으로 나간다', (tester) async {
      final game = await _start(tester, world);
      final pets = game.mapArea.children.whereType<PetHelper>().toList();
      expect(pets.length, 1);
      final pet = pets.first;
      final keeper = world.mode == WorldMode.keeper;

      final rng = Random(3);
      double minGap = double.infinity, maxGap = 0;
      // 쳐낸 공 — 쳐낸 순간의 캐릭터와 거리 · 0.2초 뒤에 더 멀어졌는지 본다
      final swatAt = <Bullet, (int, double)>{};
      int checked = 0;
      // 슛·투구는 무작위라(골키퍼는 특히 드물다) 40초에 못 쳐내면 최대 2분까지 더 돌린다
      for (int f = 0; f < (120 / _dt).round(); f++) {
        if (f >= (40 / _dt).round() && pet.swats > 0 && checked > 0) break;
        await _step(tester, game, wiggle: rng);
        if (!game.inIntro) {
          final gap = pet.position.distanceTo(game.player.position);
          minGap = min(minGap, gap);
          maxGap = max(maxGap, gap);
        }
        for (final b in game.mapArea.children.whereType<Bullet>()) {
          if (!b.petTouched) continue;
          final d = b.position.distanceTo(game.player.position);
          final seen = swatAt[b];
          if (seen == null) {
            swatAt[b] = (f, d);
          } else if (f - seen.$1 == 12) {
            expect(d, greaterThan(seen.$2), reason: '쳐낸 공이 캐릭터 쪽으로 왔다');
            checked++;
          }
        }
        if (f == (12 / _dt).round()) await _shot(tester, game, 'pet_${world.id}');
      }
      // ignore: avoid_print
      print('[pet:${world.id}] 쳐낸 공 ${pet.swats}(바깥으로 나간 것 확인 $checked) · 캐릭터와 거리 ${minGap.toStringAsFixed(1)}~${maxGap.toStringAsFixed(1)}');
      expect(pet.swats, greaterThan(0));
      expect(checked, greaterThan(0));
      // 늘 같은 원 위를 돈다 · 쳐내는 범위(펫 중심에서 reach)가 캐릭터 히트박스(반 11)에 닿지 않는다
      expect(minGap, closeTo(Pets.orbitRadius, 0.5));
      expect(maxGap, closeTo(Pets.orbitRadius, 0.5));
      expect(minGap - Pets.byId('pet_dragon')!.power.reach, greaterThan(11));
      if (keeper) expect(game.mapArea.children.whereType<Bullet>().where((b) => b.petTouched && b.velocity.y > 0), isEmpty);
      if (_shotDir.isNotEmpty) {
        // 기절한 모습(소리를 내는 gameOver() 대신 캐릭터만 — 테스트 환경엔 소리 플러그인이 없다)
        game.player.knockOut();
        for (int f = 0; f < (0.8 / _dt).round(); f++) {
          await _step(tester, game);
        }
        await _shot(tester, game, 'ko_${world.id}');
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final world in WorldData.worlds) {
    testWidgets('펫이 쳐낸 공은 어느 쪽에 맞아도 바깥으로(${world.id})', (tester) async {
      final game = await _start(tester, world);
      while (game.inIntro) {
        await _step(tester, game);
      }
      final p = game.player.position.clone();
      final keeper = world.mode == WorldMode.keeper;
      // (공 위치 — 캐릭터 기준, 속도) — 바깥에서 곧장 · 펫 안쪽을 스치듯 · 비스듬히 · 캐릭터 아래(골대 쪽)
      final cases = [
        (Vector2(40, 0), Vector2(-260, 0)),
        (Vector2(30, 8), Vector2(-150, -230)),
        (Vector2(-28, -24), Vector2(240, 60)),
        (Vector2(5, 34), Vector2(-20, 260)),
        (Vector2(0, 30), Vector2(0, 250)),
      ];
      for (final (off, v) in cases) {
        final b = Bullet(p + off, p, def: world.projectiles.first);
        game.mapArea.add(b);
        await tester.pump(Duration.zero);
        b.velocity.setFrom(v);
        b.petSwat(b.position - p);
        final out = (b.position - p).normalized();
        // 캐릭터에서 멀어진다(골키퍼에서 캐릭터 바로 아래로 떨어지던 공은 옆으로 — 다가오지도 골대로 가지도 않는다)
        expect(b.velocity.dot(out), keeper ? greaterThanOrEqualTo(0) : greaterThan(0), reason: '$off $v → ${b.velocity}');
        if (keeper) expect(b.velocity.y, lessThanOrEqualTo(0), reason: '골대 쪽으로 갔다 $off $v');
        b.removeFromParent();
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('게임 오버 — 바로 멈추지 않고 KO 연출 뒤에 결과를 한 번만 넘긴다', (tester) async {
    int sent = 0;
    final game = await _start(tester, WorldData.worlds.first, noGameOver: false, onGameOver: (_) => sent++);
    while (game.inIntro) {
      await _step(tester, game);
    }
    for (int f = 0; f < (8 / _dt).round(); f++) {
      await _step(tester, game);
    }
    if (!game.isGameOver) game.gameOver();
    expect(game.gameOverNotifier.value, isTrue);
    expect(game.player.isMounted, isTrue); // 캐릭터는 남아서 기절한다

    final t0 = game.survivalTime;
    for (int f = 0; f < (ZonberGame.koDuration * 0.7 / _dt).round(); f++) {
      await _step(tester, game);
    }
    expect(sent, 0); // 연출 중
    expect(game.survivalTime, t0); // 기록 시간은 멈춘다
    for (int f = 0; f < (ZonberGame.koDuration / _dt).round(); f++) {
      await _step(tester, game);
    }
    expect(sent, 1);
    game.gameOver(); // 두 번 불러도
    for (int f = 0; f < (ZonberGame.koDuration * 2 / _dt).round(); f++) {
      await _step(tester, game);
    }
    expect(sent, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
