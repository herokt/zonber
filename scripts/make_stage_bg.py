"""존 배경 생성 — 피구 코트 / 골키퍼(페널티킥) 잔디.

게임 판정 좌표(world_config.dart 의 court·playArea, KeeperGoal)와 정확히 맞도록
코트 라인을 코드로 그린다. 무대 480×768 의 @2x = 960×1536.

    python scripts/make_stage_bg.py            # 두 장 모두
    python scripts/make_stage_bg.py dodgeball  # 하나만

AI 로 뽑은 배경으로 바꾸고 싶으면 같은 파일명으로 덮어쓰면 된다
(단 피구 코트 라인 위치가 달라지면 world_config 의 court/playArea 를 다시 잴 것).
"""
import sys
import numpy as np
from PIL import Image, ImageDraw

W, H = 960, 1536
OUT = 'assets/images/worlds'
rng = np.random.default_rng(7)


def noise(shape, scale=1.0):
    return rng.normal(0, scale, shape)


def dodgeball():
    # ── 원목 마루: 세로 널판 64px, 널판마다 톤·결·이음매 ──
    base = np.array([233, 207, 166], dtype=np.float32)  # #E9CFA6
    img = np.zeros((H, W, 3), dtype=np.float32)
    ys = np.arange(H)[:, None]
    plank = 64
    for i, x0 in enumerate(range(0, W, plank)):
        x1 = min(W, x0 + plank)
        tone = rng.uniform(-9, 9)
        freq = rng.uniform(1 / 70, 1 / 38)
        phase = rng.uniform(0, 6.28)
        grain = 5 * np.sin(ys * freq + phase) + 2.5 * np.sin(ys * freq * 3.1 + phase * 2)
        block = base + tone + grain[..., None]
        block = np.repeat(block, x1 - x0, axis=1)
        block += noise((H, x1 - x0, 1), 2.2)
        # 가는 결선
        for _ in range(3):
            gx = rng.integers(2, x1 - x0 - 2)
            block[:, gx:gx + 1] -= rng.uniform(4, 8)
        img[:, x0:x1] = block
        img[:, x0:x0 + 2] -= 20  # 널판 이음매
        # 널판 끝 이음(엇갈림)
        for jy in rng.integers(0, H, size=2):
            img[jy:jy + 2, x0:x1] -= 16

    # ── 코트 좌표(@2x) — world_config: court 46,230,434,690 / 중앙선 460 (보이는 창 y 190~750) ──
    L, T, R, B = 92, 460, 868, 1380
    MID = 920
    # 외야(코트 바깥)는 살짝 어둡게
    mask = np.ones((H, W, 1), dtype=np.float32) * 0.9
    mask[T:B, L:R] = 1.0
    img *= mask
    # 진영 — 칠한 코트 바닥(나뭇결 25%만 비침). 상대 진영 옅은 하늘색, 우리 진영(나의 ZONE) 옅은 민트
    grain = img[T:B, L:R] - img[T:B, L:R].mean(axis=(0, 1))
    sky = np.array([196, 216, 240], dtype=np.float32)
    mint = np.array([196, 234, 214], dtype=np.float32)
    img[T:MID, L:R] = sky + grain[: MID - T] * 0.25
    img[MID:B, L:R] = mint + grain[MID - T:] * 0.25

    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), 'RGB')
    d = ImageDraw.Draw(im)
    white = (255, 255, 255)
    lw = 8
    d.rectangle([L - lw, T - lw, R + lw - 1, B + lw - 1], outline=white, width=lw)  # 코트 외곽(안쪽 가장자리 = court)
    d.rectangle([L, MID - lw // 2, R, MID + lw // 2 - 1], fill=white)  # 중앙선
    for ay in (766, 1074):  # 공격선(중앙선에서 반 코트의 1/3)
        d.rectangle([L, ay - 3, R, ay + 3], fill=white)
    cr = 118
    d.ellipse([W // 2 - cr, MID - cr, W // 2 + cr, MID + cr], outline=white, width=lw)  # 센터 서클
    im.save(f'{OUT}/dodgeball_bg.png', optimize=True)
    print('wrote dodgeball_bg.png')


def keeper():
    # ── 잔디: 가로 깎은 줄무늬 8개(페널티 에어리어를 가까이서 본 크기) + 잔디결 ──
    light = np.array([171, 222, 146], dtype=np.float32)
    dark = np.array([155, 208, 130], dtype=np.float32)
    band = H / 8
    idx = (np.arange(H) // band).astype(int) % 2
    img = np.where(idx[:, None, None] == 0, light, dark).astype(np.float32)
    img = np.repeat(img, W, axis=1)
    img += noise((H, W, 1), 3.0)
    # 잔디결 — 짧은 세로 획
    blades = np.zeros((H, W), dtype=np.float32)
    n = 34000
    xs = rng.integers(0, W, n)
    ys0 = rng.integers(0, H - 9, n)
    for dy in range(8):
        np.add.at(blades, (ys0 + dy, xs), rng.uniform(-11, 6, n) * (1 - dy / 8))
    img += blades[..., None] * np.array([0.8, 1.0, 0.7])
    # 위쪽(슈터가 서는 먼 쪽)은 살짝 어둡게, 페널티 에어리어(아래 60%)는 밝게 — 시선이 골문 앞에 모이게
    grad = np.interp(np.arange(H), [0, H * 0.45, H], [-12, 4, 6])[:, None, None]
    img += grad
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), 'RGB').save(f'{OUT}/keeper_bg.png', optimize=True)
    print('wrote keeper_bg.png')


if __name__ == '__main__':
    which = sys.argv[1:] or ['dodgeball', 'keeper']
    for w in which:
        {'dodgeball': dodgeball, 'keeper': keeper}[w]()
