import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// ─────────────────────────────────────────────────────────────
// 게임 아트 — assets/images/game/*.png (AI 아트 시트에서 오린 낱개 그림, scripts/cut_art_sheet.py)
// 앱 시작 때 한 번 읽어 두고 캔버스에 바로 그린다(게임 Flame·위젯 CustomPaint 공용).
// 그림이 아직 없거나 못 읽으면 null — 그리는 쪽은 코드 그림으로 대신한다.
// ─────────────────────────────────────────────────────────────
class GameArt {
  static const List<String> names = [
    // 캐릭터
    'body_neon_green', 'body_electric_blue', 'body_plasma_purple', 'body_cyber_red', 'body_solar_gold', 'body_void_dark',
    'face_normal', 'face_hurt', 'face_happy',
    // 장비
    'gear_wings_white', 'gear_wings_star', 'gear_wings_gold', 'gear_rocket_red', 'gear_rocket_plasma',
    'gear_band_red', 'gear_band_blue', 'gear_band_flame', 'gear_sneakers_white', 'gear_sneakers_neon',
    'gear_cap_blue', 'gear_cap_red', 'gear_gloves_basic', 'gear_gloves_pro', 'gear_gloves_gold',
    'gear_boots_black', 'gear_boots_orange',
    // 탄·공
    'ammo_galaxy', 'ammo_dodgeball', 'ammo_dodgeball_fast', 'ammo_dodgeball_pass',
    'ammo_soccer_white', 'ammo_soccer_power', 'ammo_soccer_curl', 'ammo_soccer_wave', 'ammo_soccer_rocket', 'ammo_soccer_knuckle',
    // 상대 선수
    'npc_infield', 'npc_throw', 'npc_kick',
    // 이펙트·꾸미기
    'fx_shard', 'fx_shock', 'fx_star', 'fx_spark', 'fx_streak', 'fx_sparkle', 'fx_heart', 'fx_halo', 'fx_crown',
    'fx_planet', 'fx_neon_ring', 'fx_bolt',
    'coin',
  ];

  static final Map<String, ui.Image> _images = {};
  static Future<void>? _loading;

  static ui.Image? img(String name) => _images[name];

  /// 한 번만 읽는다(여러 번 불러도 같은 Future)
  static Future<void> load() => _loading ??= _loadAll();

  static Future<void> _loadAll() async {
    await Future.wait(names.map((n) async {
      try {
        final data = await rootBundle.load('assets/images/game/$n.png');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        _images[n] = (await codec.getNextFrame()).image;
      } catch (_) {
        // 없으면 코드 그림으로 대신한다
      }
    }));
  }

  static final Paint _paint = Paint()..filterQuality = FilterQuality.medium;

  /// [name] 그림을 [center] 에 폭 [width] 로(비율 유지) 그린다. 그렸으면 true.
  static bool draw(Canvas canvas, String name, Offset center, double width,
      {double rotation = 0, bool flipX = false, double opacity = 1}) {
    final im = _images[name];
    if (im == null) return false;
    final h = width * im.height / im.width;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (rotation != 0) canvas.rotate(rotation);
    if (flipX) canvas.scale(-1, 1);
    final paint = opacity >= 1 ? _paint : (Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0)));
    canvas.drawImageRect(im, Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()),
        Rect.fromCenter(center: Offset.zero, width: width, height: h), paint);
    canvas.restore();
    return true;
  }

  /// 그림의 세로/가로 비율(없으면 1)
  static double aspect(String name) {
    final im = _images[name];
    return im == null ? 1 : im.height / im.width;
  }

  static double rand01(int seed) => (sin(seed * 12.9898) * 43758.5453) % 1.0;
}
