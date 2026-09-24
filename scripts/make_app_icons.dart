// ignore_for_file: depend_on_referenced_packages, avoid_print
// 앱 아이콘 원본(assets/images/app_icon.png)에서 플랫폼별 아이콘 그림을 만든다.
//
//   dart run scripts/make_app_icons.dart [미리보기 폴더]
//   dart run flutter_launcher_icons        # 그다음 플랫폼 아이콘 생성
//
// 원본은 그림 안에 둥근 테두리(두께 ~21px: 본색 0~15 · 밝은 선 16~19 · 어두운 선 20)가 그려져 있고,
// 그 바깥 네 모서리는 남색 사각이다. 테두리 곡선은 모서리마다 조금 다르다(위 반지름 ~217, 아래 ~186).
//
//   app_icon_rounded.png — 테두리 바깥 남색 모서리만 투명(Android · 웹 · Windows · macOS)
//   app_icon_ios.png     — 알파 없음. iOS 는 아이콘을 스스로 둥글게(반지름 ~22.4%) 깎는데 그림 속 테두리
//                          곡선과 달라서 아래 모서리 테두리가 거의 잘려 나갔다. 그래서 테두리 띠를
//                          iOS 모양에 맞춰 다시 그린다 — 둘레의 같은 자리 색·명암을 그대로 옮겨 온다.
//                          안쪽 그림은 그대로다.
// (image 패키지는 flutter_launcher_icons 가 끌어오는 것을 쓴다)
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

const int n = 1024;

void main(List<String> args) {
  final src = img.decodePng(File('assets/images/app_icon.png').readAsBytesSync())!;
  if (src.width != n || src.height != n) throw 'app_icon.png 는 1024×1024 여야 한다';
  final rounded = _rounded(src);
  File('assets/images/app_icon_rounded.png').writeAsBytesSync(img.encodePng(rounded));
  final ios = _ios(src);
  File('assets/images/app_icon_ios.png').writeAsBytesSync(img.encodePng(ios));
  print('wrote assets/images/app_icon_rounded.png, app_icon_ios.png');

  if (args.isNotEmpty) {
    // 미리보기 — 흰 바탕에 [Android 투명 모서리] [iOS: 원본을 깎은 것] [iOS: 새 그림을 깎은 것]
    final sheet = img.Image(width: 3 * 540, height: 540);
    img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
    final panels = [rounded, _iosMasked(src), _iosMasked(ios)];
    for (int i = 0; i < 3; i++) {
      img.compositeImage(sheet, img.copyResize(panels[i], width: 512), dstX: i * 540 + 14, dstY: 14);
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

/// iOS 아이콘 모서리 반지름(1024 기준 22.37%)
const double _iosR = n * 0.2237;

/// 테두리 띠 두께(어두운 안쪽 선까지)
const double _band = 21;

/// 원본 그림 속 테두리 바깥 곡선 반지름 — 잰 값(위 왼·위 오른·아래 왼·아래 오른)
const List<double> _srcR = [217, 216, 186, 185];

/// 테두리 띠를 iOS 모양(반지름 [_iosR])에 맞춰 다시 그린다. 띠 바깥(깎여 나갈 곳)은 띠 바깥 색으로 채운다
img.Image _ios(img.Image src) {
  final res = img.Image(width: n, height: n);
  for (int y = 0; y < n; y++) {
    for (int x = 0; x < n; x++) {
      final px = x + 0.5, py = y + 0.5;
      // 어느 모서리 쪽인지 — 좌우 · 위아래
      final right = px > n / 2, bottom = py > n / 2;
      final ci = (bottom ? 2 : 0) + (right ? 1 : 0);
      // 모서리 좌표계로(모서리가 원점, 안쪽이 +)
      final lx = right ? n - px : px, ly = bottom ? n - py : py;
      double sx, sy; // 원본에서 가져올 자리(모서리 좌표계)
      if (lx < _iosR && ly < _iosR) {
        // 둥근 모서리 — 새 곡선 중심에서의 각도·깊이를 원본 곡선의 같은 각도·깊이로
        final dx = lx - _iosR, dy = ly - _iosR;
        final dist = sqrt(dx * dx + dy * dy);
        final depth = _iosR - dist;
        if (depth >= _band) {
          res.setPixel(x, y, src.getPixel(x, y));
          continue;
        }
        final d = max(0.0, depth);
        final r0 = _srcR[ci];
        final ux = dist == 0 ? -1 / sqrt2 : dx / dist, uy = dist == 0 ? -1 / sqrt2 : dy / dist;
        sx = r0 + ux * (r0 - d);
        sy = r0 + uy * (r0 - d);
      } else {
        // 곧은 변 — 원본 테두리와 같은 자리
        res.setPixel(x, y, src.getPixel(x, y));
        continue;
      }
      final gx = (right ? n - sx : sx) - 0.5, gy = (bottom ? n - sy : sy) - 0.5;
      final c = src.getPixelInterpolate(gx.clamp(0, n - 1.0), gy.clamp(0, n - 1.0),
          interpolation: img.Interpolation.linear);
      res.setPixelRgb(x, y, c.r, c.g, c.b);
    }
  }
  return res;
}

/// iOS 가 깎은 모습(원 반지름 근사) — 미리보기용
img.Image _iosMasked(img.Image im) {
  final res = img.Image(width: n, height: n, numChannels: 4);
  for (int y = 0; y < n; y++) {
    for (int x = 0; x < n; x++) {
      final lx = min(x + 0.5, n - x - 0.5), ly = min(y + 0.5, n - y - 0.5);
      double a = 1;
      if (lx < _iosR && ly < _iosR) {
        final d = sqrt(pow(lx - _iosR, 2) + pow(ly - _iosR, 2));
        a = (_iosR - d + 0.5).clamp(0.0, 1.0);
      }
      final p = im.getPixel(x, y);
      res.setPixelRgba(x, y, p.r, p.g, p.b, (a * 255).round());
    }
  }
  return res;
}
