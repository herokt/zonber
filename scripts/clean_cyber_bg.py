# 갤럭시 배경 정리(2026-10-12) — 궤도 원 · 가운데 원판 · X 자 성운을 빼고 "깔끔한 그라데이션 + 별"만 남긴다
#   python scripts/clean_cyber_bg.py
# 원본(성운·궤도 원이 있던 그림): assets/images/gemini/src_cyber_bg_rings.png
# 결과: assets/images/worlds/cyber_bg.png (960×1536)
#
# 별은 원본에서 그대로 옮긴다 — 둘레(중앙값)보다 밝은 작은 점만 골라(긴 선·성운 결은 크기로 거른다) 새 그라데이션 위에 더한다.
import os
from collections import deque

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), '..')
SRC = os.path.join(ROOT, 'assets', 'images', 'gemini', 'src_cyber_bg_rings.png')
OUT = os.path.join(ROOT, 'assets', 'images', 'worlds', 'cyber_bg.png')

# 바닥색(world_config cyber floor #141A33) 둘레로 — 가운데가 아주 조금 밝고 가장자리로 어두워진다. 위는 살짝 보라, 아래는 살짝 청록
CENTER = np.array([26, 33, 64], dtype=np.float64)
EDGE = np.array([14, 18, 38], dtype=np.float64)
TOP_TINT = np.array([4, 0, 8], dtype=np.float64)
BOTTOM_TINT = np.array([0, 4, 6], dtype=np.float64)

STAR_MIN = 26  # 둘레보다 이만큼 밝으면 별 후보(밝기 0~255)
STAR_MAX_AREA = 90  # 이보다 큰 덩어리는 별이 아니다(선·성운 결)


def gradient(h, w):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    cx, cy = (w - 1) / 2, (h - 1) / 2
    d = np.sqrt(((xx - cx) / (w * 0.62)) ** 2 + ((yy - cy) / (h * 0.62)) ** 2)
    t = np.clip(d, 0, 1)[..., None]
    t = t * t * (3 - 2 * t)
    g = CENTER * (1 - t) + EDGE * t
    v = (yy / (h - 1))[..., None]
    g = g + TOP_TINT * (1 - v) + BOTTOM_TINT * v
    # 띠(밴딩)가 보이지 않게 아주 작은 잡음
    g += np.random.default_rng(7).uniform(-0.6, 0.6, size=g.shape)
    return g


def stars(a):
    lum = a.mean(axis=2)
    bg = np.asarray(Image.fromarray(lum.astype(np.uint8)).filter(ImageFilter.MedianFilter(11))).astype(np.float64)
    lift = lum - bg
    mask = lift > STAR_MIN
    # 작은 덩어리만 — 덩어리마다 크기를 센다
    h, w = mask.shape
    lab = np.zeros((h, w), dtype=np.int32)
    keep = np.zeros((h, w), dtype=bool)
    n = 0
    for y, x in zip(*np.nonzero(mask)):
        if lab[y, x]:
            continue
        n += 1
        q = deque([(y, x)])
        lab[y, x] = n
        pts = []
        while q:
            cy, cx = q.popleft()
            pts.append((cy, cx))
            for ny in range(cy - 1, cy + 2):
                for nx in range(cx - 1, cx + 2):
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not lab[ny, nx]:
                        lab[ny, nx] = n
                        q.append((ny, nx))
        if len(pts) <= STAR_MAX_AREA:
            for p in pts:
                keep[p] = True
    # 별 둘레의 은은한 빛까지 — 조금 부풀려서 그 안의 "둘레보다 밝은 만큼"을 옮긴다
    halo = np.asarray(Image.fromarray(keep.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(5))) > 0
    bgc = np.stack([np.asarray(Image.fromarray(a[..., c].astype(np.uint8)).filter(ImageFilter.MedianFilter(11))) for c in range(3)],
                   axis=-1).astype(np.float64)
    add = np.clip(a - bgc, 0, 255) * halo[..., None]
    return add, int(keep.sum()), n


def main():
    a = np.asarray(Image.open(SRC).convert('RGB')).astype(np.float64)
    h, w, _ = a.shape
    add, px, n = stars(a)
    out = gradient(h, w) + add
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(OUT, optimize=True)
    print(f'ok {w}x{h} stars {px}px ({n} blobs)')


if __name__ == '__main__':
    main()
