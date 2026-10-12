# Gemini 시트(2x2, 단색 배경) → 게임 스프라이트(투명 PNG)
#   python scripts/cut_sprites.py
# 원본: assets/images/gemini/src_*.png (pubspec 에 등록하지 않은 폴더 — 앱 용량에 안 들어간다)
# 결과: assets/images/sprites/*.png (128px · 펫 192px, 정사각형, 가운데 정렬)
#
# 1) Gemini 워터마크(우하단 반투명 흰 별) — 세 장 모두 같은 자리라, 배경이 깨끗한 쪽에서 별의 투명도를 재서 되돌린다
# 2) 크로마키 — 배경색(초록·파랑) 비율로 투명도를 매기고, 가장자리 색은 배경을 빼서 되살린다(despill)
#    'cell' 키 = 칸마다 테두리에서 배경색을 재서 색 거리로 투명도를 매긴다(Gemini 가 칸마다 다른 파랑을 깐 시트)
# 3) 칸마다 가장 큰 덩어리만 남기고(떨어진 반짝이·워터마크 찌꺼기 제거) 정사각형으로 잘라 줄인다
import os
from collections import deque

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), '..')
SRC = os.path.join(ROOT, 'assets', 'images', 'gemini')
OUT = os.path.join(ROOT, 'assets', 'images', 'sprites')
SIZE = 128

# 시트 → (배경 키, 칸 순서대로 결과 이름, 여백 비율)
SHEETS = {
    'src_meteors.png': ('green', ['meteor_1', 'meteor_2', 'meteor_3', 'meteor_4'], 0.04),
    'src_dodge_rivals.png': ('green', ['rival_ready', 'rival_throw', 'rival_smirk', 'rival_cap'], 0.04),
    'src_balls.png': ('blue', ['ball_dodge', 'ball_dodge_fast', 'ball_soccer', 'ball_soccer_power'], 0.03),
    # 2026-10-12 2차 — 골키퍼 슈터 · 펫(이름이 None 인 칸은 쓰지 않는다: 펭귄·토끼는 예비)
    'src_keeper_shooters.png': ('cell', ['shooter_ready', 'shooter_kick', 'shooter_captain', 'shooter_point'], 0.04),
    'src_pets_1.png': ('cell', ['pet_star', 'pet_slime', 'pet_ghost', 'pet_robot'], 0.04),
    'src_pets_2.png': ('cell', ['pet_cat', 'pet_dragon', None, None], 0.04),
}
# 그림 크기(기본 SIZE) — 펫은 가방 카드에서 크게 보여서 더 크게
OUT_SIZE = {'src_pets_1.png': 192, 'src_pets_2.png': 192}
# 워터마크 투명도는 처음 세 장(배경이 한 색)에서만 잰다
WM_FROM = ('src_meteors.png', 'src_dodge_rivals.png', 'src_balls.png')
# 운석은 어두운 우주 바닥에 묻히지 않게 따뜻한 빛 번짐을 그림에 구워 넣는다(게임에서 따로 그리지 않아 가볍다)
#   (색, 세기, 번짐 반지름 — 그림 한 변 대비). 번짐이 들어갈 자리만큼 여백을 넓힌다
GLOW = {'src_meteors.png': ((255, 58, 36), 1.8, 0.09)}
# 운석 몸통을 조금 밝게(어두운 바닥에서 돌의 결이 보이게)
BRIGHTEN = {'src_meteors.png': 1.18}
PAD_GLOW = 0.16

# 공은 완전한 원 — 원 밖은 잘라 낸다. 원 크기는 보통 불투명한 곳으로 재고,
# 빛 번짐이 있는 공(배경색과 섞여 보라 테두리가 됐다)은 배경색이 전혀 안 섞인 곳으로 잰다
CIRCLE = {'ball_dodge': 'alpha', 'ball_dodge_fast': 'alpha', 'ball_soccer': 'alpha', 'ball_soccer_power': 'core'}

# 워터마크 창(2048px 기준) — 별 중심 약 (1808, 1808)
WM = (1730, 1730, 1890, 1890)


def load(name):
    return np.asarray(Image.open(os.path.join(SRC, name)).convert('RGB')).astype(np.float64)


def key_strength(a, key):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return g - np.maximum(r, b) if key == 'green' else b - np.maximum(r, g)


def watermark_alpha(imgs):
    """배경이 깨끗한 칸에서 별의 투명도 w 를 잰다. 배경 위에서는 키가 아닌 두 채널이 w*255 만큼 오른다"""
    x0, y0, x1, y1 = WM
    est = []
    for a, key in imgs:
        win = a[y0:y1, x0:x1]
        r, g, b = win[..., 0], win[..., 1], win[..., 2]
        if key == 'green':
            on_bg = (g > 225) & (np.abs(r - b) < 30)
            w = (r + b) / 2 / 255
        else:
            on_bg = (b > 225) & (np.abs(r - g) < 30)
            w = (r + g) / 2 / 255
        est.append(np.where(on_bg, w, np.nan))
    with np.errstate(all='ignore'):
        w = np.nanmedian(np.stack(est), axis=0)
    w = np.nan_to_num(w, nan=0.0)
    # 배경색의 기본 값(초록 배경의 R·B 가 0 이 아니다)을 빼고 잡음은 버린다
    w = np.clip((w - 0.03) / 0.97, 0, 0.9)
    w[w < 0.02] = 0
    return w


def remove_watermark(a, w):
    x0, y0, x1, y1 = WM
    win = a[y0:y1, x0:x1]
    ww = w[..., None]
    a[y0:y1, x0:x1] = np.clip((win - ww * 255) / (1 - ww), 0, 255)
    return a


def chroma(a, key):
    d = key_strength(a, key)
    lo, hi = 70.0, 190.0
    alpha = np.clip((hi - d) / (hi - lo), 0, 1)
    kc = np.array([0, 255, 0] if key == 'green' else [0, 0, 255], dtype=np.float64)
    # 반투명 가장자리 — 관측색 = α·전경 + (1-α)·배경 → 전경을 되살린다
    al = alpha[..., None]
    fg = np.where(al > 0.04, (a - (1 - al) * kc) / np.maximum(al, 1e-3), a)
    fg = np.clip(fg, 0, 255)
    # 남은 번짐 제거 — 키 채널이 나머지 둘보다 크지 않게
    if key == 'green':
        fg[..., 1] = np.minimum(fg[..., 1], np.maximum(fg[..., 0], fg[..., 2]) + 10)
    else:
        fg[..., 2] = np.minimum(fg[..., 2], np.maximum(fg[..., 0], fg[..., 1]) + 10)
    return fg, alpha


def chroma_cell(a):
    """칸의 테두리 색(중앙값)을 배경으로 보고 색 거리로 투명도를 매긴다"""
    b = 12
    border = np.concatenate([a[:b].reshape(-1, 3), a[-b:].reshape(-1, 3), a[:, :b].reshape(-1, 3), a[:, -b:].reshape(-1, 3)])
    k = np.median(border, axis=0)
    dist = np.linalg.norm(a - k, axis=-1)
    lo, hi = 45.0, 130.0
    alpha = np.clip((dist - lo) / (hi - lo), 0, 1)
    al = alpha[..., None]
    fg = np.where(al > 0.04, (a - (1 - al) * k) / np.maximum(al, 1e-3), a)
    fg = np.clip(fg, 0, 255)
    # 가장자리 번짐 — 배경의 주 채널이 나머지보다 크지 않게(안쪽 불투명한 곳은 그대로)
    c = int(np.argmax(k))
    others = [i for i in range(3) if i != c]
    edge = alpha < 0.98
    fg[..., c] = np.where(edge, np.minimum(fg[..., c], np.maximum(fg[..., others[0]], fg[..., others[1]]) + 10), fg[..., c])
    return fg, alpha, dist - lo


def components(mask):
    """4-이웃 덩어리 라벨(작은 그림이라 BFS 로 충분)"""
    h, w = mask.shape
    lab = np.zeros((h, w), dtype=np.int32)
    sizes = [0]
    n = 0
    for y in range(h):
        row = mask[y]
        for x in np.nonzero(row & (lab[y] == 0))[0]:
            if lab[y, x]:
                continue
            n += 1
            q = deque([(y, x)])
            lab[y, x] = n
            cnt = 0
            while q:
                cy, cx = q.popleft()
                cnt += 1
                for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not lab[ny, nx]:
                        lab[ny, nx] = n
                        q.append((ny, nx))
            sizes.append(cnt)
    return lab, sizes


def cut_cell(fg, alpha, pad, circle=None, glow=None, size=SIZE):
    # 덩어리 판정은 1/4 로 줄여서(빠르게) 한다
    small = alpha[::4, ::4] > 0.5
    lab, sizes = components(small)
    if len(sizes) <= 1:
        raise RuntimeError('빈 칸')
    big = max(sizes)
    keep_ids = [i for i, s in enumerate(sizes) if i and s >= big * 0.15]
    keep = np.isin(lab, keep_ids)
    # 원래 크기로 늘리고 가장자리 여유(반투명 테두리)를 위해 조금 부풀린다
    keep = np.kron(keep, np.ones((4, 4), dtype=bool))[: alpha.shape[0], : alpha.shape[1]]
    grow = keep.copy()
    for _ in range(3):
        g2 = grow.copy()
        g2[1:] |= grow[:-1]
        g2[:-1] |= grow[1:]
        g2[:, 1:] |= grow[:, :-1]
        g2[:, :-1] |= grow[:, 1:]
        grow = g2
    alpha = alpha * grow
    if circle is not None:
        method, ks = circle
        core = ((ks < 0) & grow) if method == 'core' else (alpha > 0.95)
        ys, xs = np.nonzero(core)
        cy, cx = (ys.min() + ys.max()) / 2, (xs.min() + xs.max()) / 2
        r = max(ys.max() - ys.min(), xs.max() - xs.min()) / 2
        yy, xx = np.mgrid[0 : alpha.shape[0], 0 : alpha.shape[1]]
        dist = np.sqrt((yy - cy) ** 2 + (xx - cx) ** 2)
        alpha = np.minimum(alpha, np.clip(r + 1.5 - dist, 0, 1))
    ys, xs = np.nonzero(alpha > 0.02)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    side = max(y1 - y0, x1 - x0) + 1
    side = int(side * (1 + 2 * pad))
    cy, cx = (y0 + y1) / 2, (x0 + x1) / 2
    rgba = np.zeros((side, side, 4), dtype=np.float64)
    sy, sx = int(round(cy - side / 2)), int(round(cx - side / 2))
    for yy in range(side):
        py = sy + yy
        if not (0 <= py < alpha.shape[0]):
            continue
        lo = max(0, -sx)
        hi = min(side, alpha.shape[1] - sx)
        rgba[yy, lo:hi, :3] = fg[py, sx + lo : sx + hi]
        rgba[yy, lo:hi, 3] = alpha[py, sx + lo : sx + hi] * 255
    if glow is not None:
        color, strength, frac = glow
        a0 = rgba[..., 3] / 255
        r = max(2, int(side * frac))
        g = Image.fromarray((a0 * 255).astype(np.uint8), 'L').filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(r))
        g = np.minimum(1.0, np.asarray(g).astype(np.float64) / 255 * strength)
        # 빛 번짐이 그림 네모 가장자리에서 잘려 네모 테두리로 보이지 않게 — 안에 맞는 원 끝으로 갈수록 0
        yy, xx = np.mgrid[0:side, 0:side]
        dist = np.sqrt((yy - side / 2) ** 2 + (xx - side / 2) ** 2)
        g *= np.clip((side / 2 - 2 - dist) / (side * 0.1), 0, 1)
        out_a = a0 + g * (1 - a0)
        col = np.array(color, dtype=np.float64)
        rgb = (rgba[..., :3] * a0[..., None] + col * (g * (1 - a0))[..., None]) / np.maximum(out_a, 1e-6)[..., None]
        rgba[..., :3] = rgb
        rgba[..., 3] = out_a * 255
    # Pillow 는 RGBA 를 줄일 때 알파를 곱해서(RGBa) 줄인다 — 가장자리가 검게 번지지 않는다
    # 완전히 투명한 곳의 색은 이웃 색으로 채워 둔다(밉맵·필터에서 테두리가 어두워지지 않게)
    a = rgba[..., 3] > 0
    rgba[~a, :3] = np.mean(rgba[a, :3], axis=0)
    im = Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), 'RGBA')
    return im.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    loaded = {n: (load(n), k) for n, (k, _, _) in SHEETS.items()}
    w = watermark_alpha([loaded[n] for n in WM_FROM])
    for name, (key, outs, pad) in SHEETS.items():
        a, _ = loaded[name]
        a = remove_watermark(a.copy(), w)
        h, wd = a.shape[:2]
        cells = [(0, 0), (0, wd // 2), (h // 2, 0), (h // 2, wd // 2)]
        if key != 'cell':
            fg, alpha = chroma(a, key)
            if name in BRIGHTEN:
                fg = np.clip(fg * BRIGHTEN[name], 0, 255)
            ks = key_strength(a, key)
        for (cy, cx), out in zip(cells, outs):
            if out is None:
                continue
            sl = (slice(cy, cy + h // 2), slice(cx, cx + wd // 2))
            if key == 'cell':
                cfg, calpha, cks = chroma_cell(a[sl])
            else:
                cfg, calpha, cks = fg[sl], alpha[sl], ks[sl]
            img = cut_cell(cfg, calpha, PAD_GLOW if name in GLOW else pad,
                           (CIRCLE[out], cks) if out in CIRCLE else None, GLOW.get(name), OUT_SIZE.get(name, SIZE))
            img.save(os.path.join(OUT, f'{out}.png'), optimize=True)
            print('ok', out)


if __name__ == '__main__':
    main()
