"""AI 아트 시트(한 장에 여러 리소스) → 낱개 투명 PNG 로 오려 assets/images/game/ 에 넣는다.

    python scripts/cut_art_sheet.py <시트 이미지>

시트는 체크무늬(밝은 회색)가 그림에 박혀 있다 — 가장자리에서 이어진 무채색 밝은 회색을 지워 투명하게 만든다.
머리띠·모자·표정 그림에 함께 그려진 흰 머리는 채도·밝기로 걸러 낸다.
시트에 없는 색(써니 노랑·레이스 먹색, 별빛 날개, 빨간 로켓, 형광 운동화)은 비슷한 그림의 색을 바꿔 만든다.
좌표는 2026-09-21 시트 기준(2000×1091). 새 시트면 좌표를 다시 잰다.
"""
import sys
import colorsys
from collections import deque

import numpy as np
from PIL import Image

SRC = sys.argv[1]
OUT = 'assets/images/game'
SCALE = 4  # 오린 그림을 이만큼 키워 저장(원본 한 항목이 60~120px 이라 흐릿함 방지용으로 약간 여유)

sheet = np.array(Image.open(SRC).convert('RGB')).astype(np.int32)


def remove_bg(c):
    """가장자리에서 이어진 체크무늬(무채색 밝은 회색)만 지운다 → RGBA"""
    h, w, _ = c.shape
    mx, mn = c.max(2), c.min(2)
    bg = ((mx - mn) < 16) & (mn > 185)
    mask = np.zeros((h, w), bool)
    q = deque([(y, x) for y in range(h) for x in (0, w - 1)] + [(y, x) for x in range(w) for y in (0, h - 1)])
    while q:
        y, x = q.popleft()
        if y < 0 or x < 0 or y >= h or x >= w or mask[y, x] or not bg[y, x]:
            continue
        mask[y, x] = True
        q.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))
    a = np.where(mask, 0, 255).astype(np.uint8)
    return np.dstack([c.astype(np.uint8), a])


def remove_bg_all(c):
    """안쪽에 갇힌 체크무늬까지 지운다(링처럼 가운데가 뚫린 그림용)"""
    rgba = remove_bg(c)
    mx, mn = c.max(2), c.min(2)
    inner = ((mx - mn) < 16) & (mn > 185)
    rgba[:, :, 3] = np.where(inner, 0, rgba[:, :, 3])
    return rgba


def crop(box):
    x0, y0, x1, y1 = box
    return sheet[y0:y1, x0:x1].copy()


def trim(rgba, pad=2):
    a = rgba[:, :, 3]
    ys, xs = np.nonzero(a > 10)
    if len(xs) == 0:
        return rgba
    y0, y1 = max(0, ys.min() - pad), min(rgba.shape[0], ys.max() + pad + 1)
    x0, x1 = max(0, xs.min() - pad), min(rgba.shape[1], xs.max() + pad + 1)
    return rgba[y0:y1, x0:x1]


def soften(rgba):
    """알파 가장자리를 1px 부드럽게(계단 방지)"""
    im = Image.fromarray(rgba, 'RGBA')
    a = im.getchannel('A').filter(__import__('PIL.ImageFilter', fromlist=['GaussianBlur']).GaussianBlur(0.6))
    im.putalpha(a)
    return np.array(im)


def save(name, rgba, scale=SCALE):
    rgba = trim(rgba)
    im = Image.fromarray(soften(rgba), 'RGBA')
    im = im.resize((im.width * scale, im.height * scale), Image.LANCZOS)
    im.save(f'{OUT}/{name}.png', optimize=True)
    print('wrote', name, im.size)


def cut(name, box, **kw):
    rgba = remove_bg(crop(box))
    save(name, rgba, **kw)
    return rgba


def recolor(rgba, hue_to, sat_mul=1.0, val_mul=1.0, only_saturated=True):
    """채도 있는 픽셀의 색상(hue)을 바꾼다"""
    out = rgba.copy()
    h, w, _ = rgba.shape
    for y in range(h):
        for x in range(w):
            r, g, b, a = rgba[y, x]
            if a == 0:
                continue
            hh, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if only_saturated and s < 0.15:
                continue
            s = min(1.0, s * sat_mul)
            v = min(1.0, v * val_mul)
            nr, ng, nb = colorsys.hsv_to_rgb(hue_to / 360, s, v)
            out[y, x, :3] = (int(nr * 255), int(ng * 255), int(nb * 255))
    return out


def strip_head(rgba):
    """머리띠·모자 그림에서 흰 머리(무채색 밝은 부분 + 그 외곽선)를 지우고 장비만 남긴다"""
    rgb = rgba[:, :, :3].astype(np.int32)
    mx, mn = rgb.max(2), rgb.min(2)
    sat = (mx - mn) / np.maximum(mx, 1)
    keep = (sat > 0.28) & (mx > 110) & (rgba[:, :, 3] > 0)  # 남색 외곽선은 채도가 높아도 어둡다 — 제외
    # 장비 둘레 외곽선(어두운 픽셀)은 장비 가까이 있는 것만 남긴다
    dark = (mx < 90) & (rgba[:, :, 3] > 0)
    near = keep.copy()
    for _ in range(3):
        n = near.copy()
        n[1:, :] |= near[:-1, :]
        n[:-1, :] |= near[1:, :]
        n[:, 1:] |= near[:, :-1]
        n[:, :-1] |= near[:, 1:]
        near = n
    # 머리 외곽선이 딸려 오지 않게 — 장비 색이 있는 줄(행) 범위 안의 외곽선만
    rows = np.nonzero(keep.any(1))[0]
    band = np.zeros_like(keep)
    if len(rows):
        band[max(0, rows.min() - 2):rows.max() + 3, :] = True
    keep |= dark & near & band
    out = rgba.copy()
    out[:, :, 3] = np.where(keep, rgba[:, :, 3], 0)
    return out


def face_only(rgba):
    """표정 그림(흰 머리 + 얼굴)에서 눈·입·볼만 남긴다"""
    h, w, _ = rgba.shape
    rgb = rgba[:, :, :3].astype(np.int32)
    mx, mn = rgb.max(2), rgb.min(2)
    yy, xx = np.mgrid[0:h, 0:w]
    inner = ((xx - w / 2) / (w * 0.40)) ** 2 + ((yy - h * 0.55) / (h * 0.36)) ** 2 < 1  # 머리 외곽선 안쪽
    dark = mx < 110
    pink = (rgb[:, :, 0] > 180) & (rgb[:, :, 1] < 185) & ((mx - mn) > 40)
    white_hi = (mn > 235) & dark.copy()  # 눈 반짝임은 어두운 눈 안에 있다 — 아래에서 따로
    keep = inner & (dark | pink)
    # 눈 속 흰 반짝임 — 어두운 픽셀로 둘러싸인 밝은 점
    shine = inner & (mn > 225)
    around = np.zeros_like(shine)
    for dy in (-3, 3):
        for dx in (-3, 3):
            around |= np.roll(np.roll(dark, dy, 0), dx, 1)
    keep |= shine & around
    out = rgba.copy()
    out[:, :, 3] = np.where(keep, 255, 0)
    return out


def split_pair(rgba):
    """한 쌍(좌우) 그림을 가운데 빈 틈에서 나눈다"""
    a = rgba[:, :, 3] > 10
    cols = a.sum(0)
    w = rgba.shape[1]
    mid = w // 2
    lo, hi = int(w * 0.3), int(w * 0.7)
    gap = lo + int(np.argmin(cols[lo:hi]))
    return rgba[:, :gap], rgba[:, gap:]


import os
os.makedirs(OUT, exist_ok=True)

# ── 캐릭터 몸통(얼굴 없음) ──
mint = cut('body_neon_green', (30, 274, 148, 395))
cut('body_electric_blue', (155, 274, 273, 395))
cut('body_plasma_purple', (280, 274, 400, 395))
cut('body_cyber_red', (407, 274, 526, 395))
m = remove_bg(crop((30, 274, 148, 395)))
save('body_solar_gold', recolor(m, 45, sat_mul=1.25, val_mul=1.35))
save('body_void_dark', recolor(m, 222, sat_mul=0.35, val_mul=0.62))

# ── 표정(눈·입·볼만) ──
for name, box in (('face_normal', (742, 306, 858, 414)), ('face_hurt', (882, 306, 998, 414)), ('face_happy', (1024, 306, 1140, 414))):
    save(name, face_only(remove_bg(crop(box))))

# ── 장비 ──
for name, box in (('band_red', (1450, 275, 1526, 337)), ('band_blue', (1537, 275, 1613, 337)), ('band_flame', (1624, 262, 1694, 337)),
                  ('cap_blue', (1447, 409, 1516, 472)), ('cap_red', (1522, 409, 1590, 472))):
    save('gear_' + name, strip_head(remove_bg(crop(box))))
sneaker = remove_bg(crop((1707, 292, 1781, 340)))
save('gear_sneakers_white', sneaker)
save('gear_sneakers_neon', recolor(sneaker, 85, sat_mul=1.6, val_mul=1.0, only_saturated=False))
rocket = remove_bg(crop((1872, 254, 1944, 342)))
save('gear_rocket_plasma', rocket)
save('gear_rocket_red', recolor(rocket, 4, sat_mul=1.15, val_mul=1.05))
save('gear_gloves_basic', remove_bg(crop((1602, 417, 1649, 468))))
save('gear_gloves_pro', remove_bg(crop((1659, 419, 1713, 472))))
gl, gr = split_pair(remove_bg(crop((1719, 422, 1792, 472))))
save('gear_gloves_gold', gl)
# 축구화는 한 쌍이 겹쳐 있어 나누지 않고 쌍으로 쓴다(두 발 밑에 한 장)
save('gear_boots_black', remove_bg(crop((1792, 417, 1866, 473))))
save('gear_boots_orange', remove_bg(crop((1869, 417, 1949, 476))))
wl, wr = split_pair(remove_bg(crop((1337, 94, 1438, 143))))
save('gear_wings_white', wr)  # 오른쪽 날개 한 장(왼쪽은 좌우 반전)
save('gear_wings_star', recolor(wr, 200, sat_mul=2.2, val_mul=1.0, only_saturated=False))
gwl, gwr = split_pair(remove_bg(crop((1444, 94, 1535, 143))))
save('gear_wings_gold', gwr)

# ── 꾸미기 ──
cut('fx_sparkle', (1250, 94, 1318, 130))
cut('fx_heart', (1549, 102, 1598, 142))
cut('fx_halo', (1619, 104, 1681, 132))
cut('fx_crown', (1709, 99, 1773, 142))
cut('fx_planet', (1784, 92, 1851, 142))
save('fx_neon_ring', remove_bg_all(crop((382, 622, 460, 665))))
cut('fx_bolt', (469, 609, 510, 678))

# ── 탄 · 공 ──
cut('ammo_galaxy', (44, 612, 108, 675))
cut('ammo_dodgeball', (129, 612, 195, 675))
cut('ammo_dodgeball_fast', (214, 612, 280, 675))
cut('ammo_dodgeball_pass', (297, 612, 363, 675))
cut('ammo_soccer_white', (907, 607, 973, 670))
cut('ammo_soccer_power', (987, 607, 1053, 670))
cut('ammo_soccer_wave', (1067, 607, 1130, 670))
cut('ammo_soccer_knuckle', (1142, 607, 1208, 670))
cut('ammo_soccer_rocket', (744, 729, 810, 795))
cut('ammo_soccer_curl', (639, 729, 708, 795))
cut('fx_streak', (815, 742, 955, 780))

# ── 상대 선수 ──
cut('npc_infield', (44, 739, 108, 803))
cut('npc_throw', (129, 739, 195, 803))
cut('npc_kick', (214, 739, 280, 803))

# ── 이펙트 ──
cut('fx_shard', (1297, 609, 1338, 665))
cut('fx_shock', (1357, 627, 1413, 663))
cut('fx_star', (1522, 612, 1580, 665))
cut('fx_spark', (1597, 612, 1648, 667))
cut('coin', (1784, 609, 1833, 668))
cut('text_goal', (1274, 727, 1455, 783), scale=2)
cut('text_save', (1477, 727, 1650, 783), scale=2)
cut('text_start', (1674, 722, 1948, 791), scale=2)

# ── UI ──
cut('app_icon', (47, 895, 173, 1023), scale=8)
cut('logo', (222, 922, 603, 1013), scale=3)
cut('badge_trophy', (1292, 928, 1368, 1013))
cut('badge_medal', (1382, 928, 1448, 1013))
