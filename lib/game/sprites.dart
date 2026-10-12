part of '../main.dart';

// 시안 아트(2026-10-12) — Gemini 로 뽑은 그림. assets/images/sprites/(128px 투명 PNG)
//   원본 시트는 assets/images/gemini/src_*.png, 자르기·배경 지우기·워터마크 지우기는 scripts/cut_sprites.py. docs/RESOURCES.md §시안 아트
//   갤럭시 운석 4종(meteor_1~4) · 피구 공 2종 · 축구공 2종(나머지 축구공은 흰 공에 색을 입힌다) · 피구 상대 선수 4종(rival_*)
//   골키퍼 슈터 4종(shooter_*) · 펫 6종(pets.dart PetArt 가 따로 읽는다 — 가방 화면에서도 쓰므로)
// 그림을 아직 못 읽었거나 없으면 지금까지의 코드 드로잉으로 그린다 — 게임을 기다리게 하지 않는다(읽기는 기다리지 않고 건다).
// 비교용: --dart-define=ART=code 로 빌드하면 코드 드로잉만 쓴다.

class GameSprites {
  static bool enabled = const String.fromEnvironment('ART') != 'code';

  static const List<String> names = [
    'meteor_1', 'meteor_2', 'meteor_3', 'meteor_4',
    'ball_dodge', 'ball_dodge_fast', 'ball_soccer', 'ball_soccer_power',
    'rival_ready', 'rival_throw', 'rival_smirk', 'rival_cap',
    'shooter_ready', 'shooter_kick', 'shooter_captain', 'shooter_point',
  ];

  static final Map<String, ui.Image> _img = {};
  static Future<void>? _loading;

  /// 읽어 둔 그림 — 없으면 null(코드 드로잉으로)
  static ui.Image? get(String? name) => enabled && name != null ? _img[name] : null;

  /// 한 번만 읽는다(판이 바뀌어도 다시 읽지 않는다). 게임은 기다리지 않고, 테스트는 기다린다
  static Future<void> load(ZonberGame game) => _loading ??= !enabled
      ? Future.value()
      : Future.wait([
          PetArt.load(),
          for (final n in names)
            game.images.load('sprites/$n.png').then((img) => _img[n] = img).then((_) {}, onError: (_) {}), // 그림 없음 — 코드 드로잉
        ]);
}

final Paint _spritePaint = Paint()..filterQuality = FilterQuality.medium;

/// 그림 한 장을 [c] 가운데에 [side] 크기로 [angle] 만큼 돌려 그린다. [tint] 는 흰 부분에 입히는 색, [alpha] 는 흐려질 때 투명도
void paintSprite(Canvas canvas, ui.Image img, Offset c, double side, {double angle = 0, Color? tint, double alpha = 1}) {
  _spritePaint
    ..color = Color.fromRGBO(255, 255, 255, alpha)
    ..colorFilter = tint == null ? null : ColorFilter.mode(tint.withValues(alpha: alpha), BlendMode.modulate);
  canvas.save();
  canvas.translate(c.dx, c.dy);
  if (angle != 0) canvas.rotate(angle);
  canvas.drawImageRect(
    img,
    Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    Rect.fromCenter(center: Offset.zero, width: side, height: side),
    _spritePaint,
  );
  canvas.restore();
}
