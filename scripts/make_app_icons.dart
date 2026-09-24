// ignore_for_file: depend_on_referenced_packages, avoid_print
// 앱 아이콘 원본(assets/images/app_icon.png)에서 플랫폼별 아이콘 그림을 만든다.
//
//   dart run scripts/make_app_icons.dart [미리보기 폴더]
//   dart run flutter_launcher_icons        # 그다음 플랫폼 아이콘 생성
//
// 원본은 그림 안에 둥근 테두리(두께 ~21px: 본색 0~15 · 밝은 선 16~19 · 어두운 선 20)가 그려져 있고,
// 그 바깥 네 모서리는 남색 사각이다. 테두리 곡선은 모서리마다 조금 다르다(위 반지름 ~217, 아래 ~186).
//
//   assets/images/app_icon_rounded.png — 테두리 바깥 남색 모서리만 투명(Android 런처 · 웹 · Windows · macOS)
//   assets/images/app_icon_ios.png     — 알파 없음. iOS 가 깎는 모양(반지름 22.37%)에 맞춰 테두리 띠를 다시 그린 것
//   store/play_icon_512.png            — 알파 없음. Google Play 스토어 아이콘. Play 가 깎는 모양(반지름 20%)에 맞춘 것
// iOS·Play 는 아이콘을 스스로 둥글게 깎는데 그 곡선이 그림 속 테두리 곡선과 달라, 원본을 그대로 주면
// 어떤 모서리는 테두리가 잘려 나가고 어떤 모서리는 남색이 비쳤다. 그래서 테두리 띠를 깎는 모양에 맞춰
// 다시 그린다 — 둘레의 같은 자리 색·명암을 그대로 옮겨 온다. 안쪽 그림은 그대로다.
// (image 패키지는 flutter_launcher_icons 가 끌어오는 것을 쓴다)
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

const int n = 1024;

/// 깎는 모서리 반지름(1024 기준) — iOS 22.37% · Google Play 20%
const double _iosR = n * 0.2237;
const double _playR = n * 0.20;

void main(List<String> args) {
  final src = img.decodePng(File('assets/images/app_icon.png').readAsBytesSync())!;
  if (src.width != n || src.height != n) throw 'app_icon.png 는 1024×1024 여야 한다';
  final rounded = _rounded(src);
  File('assets/images/app_icon_rounded.png').writeAsBytesSync(img.encodePng(rounded));
  final ios = _refit(src, _iosR);
  File('assets/images/app_icon_ios.png').writeAsBytesSync(img.encodePng(ios));
  final play = _refit(src, _playR);
  File('store/play_icon_512.png').writeAsBytesSync(
      img.encodePng(img.copyResize(play, width: 512, height: 512, interpolation: img.Interpolation.cubic)));
  print('wrote assets/images/app_icon_rounded.png, app_icon_ios.png, store/play_icon_512.png');

  if (args.isNotEmpty) {
    // 미리보기 — 흰 바탕. 윗줄 iOS [원본을 깎은 것] [새 그림을 깎은 것] [Android 투명 모서리] · 아랫줄 Play [원본] [새 그림]
    final sheet = img.Image(width: 3 * 540, height: 2 * 540);
    img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
    final panels = [
      [_masked(src, _iosR), _masked(ios, _iosR), rounded],
      [_masked(src, _playR), _masked(play, _playR)],
    ];
    for (int r = 0; r < panels.length; r++) {
      for (int i = 0; i < panels[r].length; i++) {
        img.compositeImage(sheet, img.copyResize(panels[r][i], width: 512), dstX: i * 540 + 14, dstY: r * 540 + 14);
      }
    }
    File('${args[0]}/app_icons_preview.png').writeAsBytesSync(img.encodePng(sheet));
    print('preview → ${args[0]}/app_icons_preview.png');
  }
}

bool _navy(img.Image im, int x, int y) {
  final p = im.getPixel(x, y);
  final dr = p.r - 13, dg = p.g - 9, db = p.b - 60;
  return dr * dr + dg * dg + db * db < 30 * 30;
}

/// 네 모서리에서 이어진 남색(테두리 바깥)만 투명. 가장자리는 5×5 비율로 부드럽게
img.Image _rounded(img.Image src) {
  final out = List.filled(n * n, false);
  final q = Queue<int>();
  for (final s in [(0, 0), (n - 1, 0), (0, n - 1), (n - 1, n - 1)]) {
    if (_navy(src, s.$1, s.$2)) {
      out[s.$2 * n + s.$1] = true;
      q.add(s.$2 * n + s.$1);
    }
  }
  while (q.isNotEmpty) {
    final i = q.removeFirst();
    final x = i % n, y = i ~/ n;
    for (final d in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nx = x + d.$1, ny = y + d.$2;
      if (nx < 0 || ny < 0 || nx >= n || ny >= n) continue;
      final j = ny * n + nx;
      if (out[j] || !_navy(src, nx, ny)) continue;
      out[j] = true;
      q.add(j);
    }
  }
  final res = img.Image(width: n, height: n, numChannels: 4);
  for (int y = 0; y < n; y++) {
    for (int x = 0; x < n; x++) {
      final p = src.getPixel(x, y);
      int a = 0;
      if (!out[y * n + x]) {
        int keep = 0, tot = 0;
        for (int dy = -2; dy <= 2; dy++) {
          for (int dx = -2; dx <= 2; dx++) {
            final xx = x + dx, yy = y + dy;
            if (xx < 0 || yy < 0 || xx >= n || yy >= n) continue;
            tot++;
            if (!out[yy * n + xx]) keep++;
          }
        }
        a = (255 * keep / tot).round();
      }
      res.setPixelRgba(x, y, p.r, p.g, p.b, a);
    }
  }
  return res;
}

/// 테두리 띠 두께(어두운 안쪽 선까지)
const double _band = 21;

/// 원본 그림 속 테두리 바깥 곡선 반지름 — 잰 값(위 왼·위 오른·아래 왼·아래 오른)
const List<double> _srcR = [217, 216, 186, 185];

/// 테두리 띠를 모서리 반지름 [radius] 모양에 맞춰 다시 그린다. 띠 바깥(깎여 나갈 곳)은 띠 바깥 색으로 채운다.
/// 새 띠 안쪽인데 원본에서는 테두리였던 자리(원본 곡선이 새 곡선보다 클 때 생긴다 — Play 의 위 모서리)는
/// 원본 테두리 바로 안쪽 그림으로 채운다(안 그러면 원본 테두리 안쪽 선이 한 줄 더 보인다)
img.Image _refit(img.Image src, double radius) {
  final res = img.Image(width: n, height: n);
  for (int y = 0; y < n; y++) {
    for (int x = 0; x < n; x++) {
      final px = x + 0.5, py = y + 0.5;
      // 어느 모서리 쪽인지 — 좌우 · 위아래
      final right = px > n / 2, bottom = py > n / 2;
      final r0 = _srcR[(bottom ? 2 : 0) + (right ? 1 : 0)];
      // 모서리 좌표계로(모서리가 원점, 안쪽이 +)
      final lx = right ? n - px : px, ly = bottom ? n - py : py;
      if (lx >= radius || ly >= radius) {
        // 곧은 변 — 원본 테두리와 같은 자리
        res.setPixel(x, y, src.getPixel(x, y));
        continue;
      }
      // 둥근 모서리 — 새 곡선 중심에서의 각도·깊이
      final dx = lx - radius, dy = ly - radius;
      final dist = sqrt(dx * dx + dy * dy);
      final depth = radius - dist;
      // 원본 곡선 기준 깊이(원본 모서리 밖이면 곧은 변 기준)
      final ox = lx - r0, oy = ly - r0;
      final odist = sqrt(ox * ox + oy * oy);
      final oDepth = (lx < r0 && ly < r0) ? r0 - odist : min(lx, ly);
      double sx, sy; // 원본에서 가져올 자리(모서리 좌표계)
      if (depth >= _band) {
        if (oDepth >= _band) {
          res.setPixel(x, y, src.getPixel(x, y));
          continue;
        }
        // 원본에서는 테두리였던 자리 — 원본 테두리 바로 안쪽에서 가져온다
        final ux = odist == 0 ? -1 / sqrt2 : ox / odist, uy = odist == 0 ? -1 / sqrt2 : oy / odist;
        sx = r0 + ux * (r0 - _band - 1.5);
        sy = r0 + uy * (r0 - _band - 1.5);
      } else {
        // 새 띠 — 원본 곡선의 같은 각도·깊이에서 가져온다
        final d = max(0.0, depth);
        final ux = dist == 0 ? -1 / sqrt2 : dx / dist, uy = dist == 0 ? -1 / sqrt2 : dy / dist;
        sx = r0 + ux * (r0 - d);
        sy = r0 + uy * (r0 - d);
      }
      final gx = (right ? n - sx : sx) - 0.5, gy = (bottom ? n - sy : sy) - 0.5;
      final c = src.getPixelInterpolate(gx.clamp(0, n - 1.0), gy.clamp(0, n - 1.0),
          interpolation: img.Interpolation.linear);
      res.setPixelRgb(x, y, c.r, c.g, c.b);
    }
  }
  return res;
}

/// 반지름 [radius] 로 깎은 모습(원 근사) — 미리보기용
img.Image _masked(img.Image im, double radius) {
  final res = img.Image(width: n, height: n, numChannels: 4);
  for (int y = 0; y < n; y++) {
    for (int x = 0; x < n; x++) {
      final lx = min(x + 0.5, n - x - 0.5), ly = min(y + 0.5, n - y - 0.5);
      double a = 1;
      if (lx < radius && ly < radius) {
        final d = sqrt(pow(lx - radius, 2) + pow(ly - radius, 2));
        a = (radius - d + 0.5).clamp(0.0, 1.0);
      }
      final p = im.getPixel(x, y);
      res.setPixelRgba(x, y, p.r, p.g, p.b, (a * 255).round());
    }
  }
  return res;
}
