# 명예의 전당 트로피 — Gemini 시안(단색 초록 배경 한 장) → 투명 PNG
#   python scripts/cut_hall.py
# 원본: assets/images/gemini/src_hall_trophy.png (pubspec 에 등록하지 않은 폴더)
# 결과: assets/images/hall/trophy.png (512px 정사각형, 가운데 정렬) — lib/pages/hall_of_fame_page.dart 머리가 읽는다(없으면 코드 드로잉)
#
# cut_sprites.py 와 같은 요령(크로마키 + 가장자리 색 되살리기 + 가장 큰 덩어리만)이되, 2×2 시트가 아니라 한 장이라 따로 둔다.
import os
from collections import deque

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), '..')
SRC = os.path.join(ROOT, 'assets', 'images', 'gemini', 'src_hall_trophy.png')
OUT = os.path.join(ROOT, 'assets', 'images', 'hall', 'trophy.png')
SIZE = 512
PAD = 0.04


def largest_component(mask):
    """mask(bool) 에서 가장 큰 연결 덩어리만 남긴다 — 떨어진 워터마크·반짝이 찌꺼기 제거"""
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    best, best_n = None, 0
    for y in range(h):
        for x in range(w):
            if not mask[y, x] or seen[y, x]:
                continue
            q = deque([(y, x)])
            seen[y, x] = True
            pts = []
            while q:
                cy, cx = q.popleft()
                pts.append((cy, cx))
                for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        q.append((ny, nx))
            if len(pts) > best_n:
                best, best_n = pts, len(pts)
    out = np.zeros_like(mask)
    if best:
        ys, xs = zip(*best)
        out[list(ys), list(xs)] = True
    return out


def main():
    a = np.asarray(Image.open(SRC).convert('RGB')).astype(np.float64)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    # 초록 키 세기 — 배경은 g 가 r·b 보다 훨씬 크다. 0(물체) ~ 1(배경)
    key = (g - np.maximum(r, b)) / 255.0
    alpha = np.clip(1 - (key - 0.08) / 0.5, 0, 1)
    # 가장자리 색 되살리기(despill) — 반투명한 곳은 초록이 섞여 있으니 g 를 r·b 평균 이하로 누른다
    spill = g > (r + b) / 2
    g2 = np.where(spill & (alpha < 1), (r + b) / 2, g)
    rgb = np.stack([r, g2, b], axis=-1)

    # 작업 해상도를 줄여 덩어리 찾기(2048² 파이썬 루프는 느리다)
    small = Image.fromarray((alpha * 255).astype(np.uint8)).resize((256, 256), Image.BILINEAR)
    keep_small = largest_component(np.asarray(small) > 40)
    keep = np.asarray(Image.fromarray(keep_small.astype(np.uint8) * 255).resize(a.shape[1::-1], Image.NEAREST)) > 0
    # 덩어리 바깥 8px 까지는 살려 둔다(가장자리 반투명)
    keep = np.asarray(Image.fromarray(keep.astype(np.uint8) * 255).filter(__import__('PIL.ImageFilter', fromlist=['MaxFilter']).MaxFilter(17))) > 0
    alpha = np.where(keep, alpha, 0)

    ys, xs = np.where(alpha > 0.02)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    side = int(max(y1 - y0, x1 - x0) * (1 + PAD * 2))
    cy, cx = (y0 + y1) // 2, (x0 + x1) // 2
    canvas = np.zeros((side, side, 4), dtype=np.uint8)
    sy0, sx0 = cy - side // 2, cx - side // 2
    for y in range(side):
        yy = sy0 + y
        if not (0 <= yy < a.shape[0]):
            continue
        xa, xb = max(0, sx0), min(a.shape[1], sx0 + side)
        canvas[y, xa - sx0:xb - sx0, :3] = np.clip(rgb[yy, xa:xb], 0, 255)
        canvas[y, xa - sx0:xb - sx0, 3] = (alpha[yy, xa:xb] * 255).astype(np.uint8)
    img = Image.fromarray(canvas, 'RGBA').resize((SIZE, SIZE), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT, optimize=True)
    print('wrote', OUT, img.size, os.path.getsize(OUT) // 1024, 'KB')


if __name__ == '__main__':
    main()
