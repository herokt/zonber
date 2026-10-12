# Google Ads 앱 캠페인 동영상 — 실제 플레이 캡처에 문구·끝 화면·소리를 입혀 세 비율(9:16 · 16:9 · 1:1)로 만든다(2026-10-12).
#
#   node scripts/ad_video_capture.mjs --lang ko        # 원본 → build/ad_video/ko/{galaxy,dodgeball,keeper}/
#   python scripts/make_ad_video.py [--lang ko] [--cut full|short|all]   # → store/ad_videos/ko/zonber_{portrait_9x16,landscape_16x9,square_1x1}[_15s].mp4
#
# 흐름(full 약 22초): 갤럭시 7초(첫 2.4초는 "손가락 하나로" + 손가락 표시) → 피구 6초 → 프리킥 6초 → 끝 화면 3.5초.
# short(15초): 4.5 · 3.5 · 3.5 · 끝 3.5초 — Google 은 길이가 다른 영상을 섞어 두기를 권한다.
# 장면마다 10초 캡처 중 맞은 순간이 가장 적은 구간을 고른다. 소리 = bgm + 그 프레임에 실제로 난 효과음(assets/audio).
# 그림은 실제 플레이·히어로 아트·앱 아이콘만 쓴다. 가짜 [설치] 버튼은 넣지 않는다(설치 버튼은 Google 이 붙인다).
# ffmpeg: FFMPEG 환경변수 → PATH → imageio-ffmpeg(pip install imageio-ffmpeg). 글꼴: Noto Sans KR(Windows 글꼴) · Sora(받아서 build/ 에 둔다)
import argparse
import json
import math
import os
import shutil
import subprocess
import sys
import urllib.request
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.stdout.reconfigure(encoding='utf-8')  # Windows 콘솔에서 한글 로그가 깨지지 않게
FPS = 30
SR = 44100

TEXT = {
    'ko': {
        'hook': '손가락 하나로 버텨라',
        'title': '얼마나 버틸 수 있나요?',
        'zones': ['운석을 피해라', '피구공을 피해라', '프리킥을 막아라'],
        'end_title': '1초만 더 버텨 보세요',
        'end_sub': '무료 · 로그인 없이 바로 플레이',
    },
    'en': {
        'hook': 'One finger. Dodge everything.',
        'title': 'How long can you survive?',
        'zones': ['Dodge the meteors', 'Dodge the dodgeballs', 'Stop the free kicks'],
        'end_title': 'Survive one more second',
        'end_sub': 'Free · Play instantly, no sign-up',
    },
}
# (캡처 폴더, 쓸 길이 초, 강조색) — make_ad_images.mjs 와 같은 색
SCENES = [('galaxy', 7.0, (34, 199, 230)), ('dodgeball', 6.0, (255, 90, 78)), ('keeper', 6.0, (61, 190, 107))]
HEROES = ['cyber', 'dodgeball', 'keeper']
END_SEC = 3.5
HOOK_SEC = 2.4
# 길이 — (장면별 초, 손가락·첫 문구 초, 파일 이름 꼬리)
CUTS = {'full': ([7.0, 6.0, 6.0], 2.4, ''), 'short': ([4.5, 3.5, 3.5], 2.0, '_15s')}
FORMATS = {'portrait_9x16': (1080, 1920), 'landscape_16x9': (1920, 1080), 'square_1x1': (1080, 1080)}

FONT_BLACK = 'C:/Windows/Fonts/NotoSansKR-Black.ttf'
FONT_BOLD = 'C:/Windows/Fonts/NotoSansKR-Bold.ttf'
SORA_URL = 'https://raw.githubusercontent.com/google/fonts/main/ofl/sora/Sora%5Bwght%5D.ttf'


# ── 도구 ──────────────────────────────────────────────

def ffmpeg_exe():
    for c in [os.environ.get('FFMPEG'), shutil.which('ffmpeg')]:
        if c and os.path.exists(c):
            return c
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        sys.exit('ffmpeg 이 없다 — FFMPEG 환경변수로 경로를 주거나 pip install imageio-ffmpeg')


def font(path, size):
    if not os.path.exists(path):
        sys.exit(f'글꼴이 없다: {path}')
    return ImageFont.truetype(path, size)


def wordmark_font(size):
    """ZONBER 글자 — 이미지 광고와 같은 Sora 800. 못 받으면 Noto Sans KR Black"""
    f = os.path.join(ROOT, 'build', 'ad_video', 'Sora.ttf')
    if not os.path.exists(f):
        try:
            os.makedirs(os.path.dirname(f), exist_ok=True)
            urllib.request.urlretrieve(SORA_URL, f)
        except Exception as e:  # 인터넷이 없으면 대신 쓴다
            print('Sora 글꼴을 못 받았다 — Noto Sans KR 로', e)
            return font(FONT_BLACK, size)
    ft = ImageFont.truetype(f, size)
    try:
        ft.set_variation_by_axes([800])
    except Exception:
        pass
    return ft


def ease_out_back(p):
    c1, c3 = 1.70158, 2.70158
    return 1 + c3 * (p - 1) ** 3 + c1 * (p - 1) ** 2


def rounded_mask(w, h, r):
    m = Image.new('L', (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w - 1, h - 1), r, fill=255)
    return m


def shadowed(layer, blur=14, offset=(0, 6), alpha=0.45):
    """글자·칩 뒤에 부드러운 그림자"""
    pad = blur * 3
    out = Image.new('RGBA', (layer.width + pad * 2, layer.height + pad * 2), (0, 0, 0, 0))
    a = layer.getchannel('A').point(lambda v: int(v * alpha))
    sh = Image.new('RGBA', layer.size, (0, 0, 0, 0))
    sh.putalpha(a)
    out.alpha_composite(sh, (pad + offset[0], pad + offset[1]))
    out = out.filter(ImageFilter.GaussianBlur(blur))
    out.alpha_composite(layer, (pad, pad))
    return out


def wrap(text, ft, max_w):
    """띄어쓰기 기준 줄바꿈"""
    words, lines = text.split(' '), []
    cur = ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if cur and ft.getlength(t) > max_w:
            lines.append(cur)
            cur = w
        else:
            cur = t
    lines.append(cur)
    return lines


def text_layer(text, path, size, max_w=None, color=(255, 255, 255), align='center', line_gap=1.12, shadow=True):
    ft = font(path, size)
    if max_w:
        while size > 20 and max(ft.getlength(l) for l in wrap(text, ft, max_w)) > max_w:
            size -= 2
            ft = font(path, size)
        lines = wrap(text, ft, max_w)
    else:
        lines = [text]
    asc, desc = ft.getmetrics()
    lh = int(size * line_gap)
    w = int(max(ft.getlength(l) for l in lines)) + 8
    h = lh * (len(lines) - 1) + asc + desc + 8
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i, l in enumerate(lines):
        lw = ft.getlength(l)
        x = {'center': (w - lw) / 2, 'left': 4}[align]
        d.text((x, 4 + i * lh), l, font=ft, fill=color)
    return shadowed(im) if shadow else im


def chip_layer(text, size, accent, max_w=None):
    ft = font(FONT_BLACK, size)
    while max_w and size > 20 and ft.getlength(text) + size * 1.5 > max_w:  # 칸보다 넓으면 글자를 줄인다(영어 문구)
        size -= 2
        ft = font(FONT_BLACK, size)
    asc, desc = ft.getmetrics()
    px, py = int(size * 0.75), int(size * 0.34)
    w = int(ft.getlength(text)) + px * 2
    h = asc + desc + py * 2
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, w - 1, h - 1), h // 2, fill=accent + (255,))
    d.text((px, py - int(size * 0.06)), text, font=ft, fill=(255, 255, 255))
    return shadowed(im, blur=12, offset=(0, 8), alpha=0.35)


def brand_layer(size):
    """앱 아이콘 + ZONBER"""
    icon = Image.open(os.path.join(ROOT, 'assets/images/app_icon_rounded.png')).convert('RGBA').resize((size * 2, size * 2), Image.LANCZOS)
    ft = wordmark_font(size)
    tw = int(ft.getlength('ZONBER'))
    gap = int(size * 0.35)
    im = Image.new('RGBA', (icon.width + gap + tw + 8, icon.height), (0, 0, 0, 0))
    im.alpha_composite(icon, (0, 0))
    asc, desc = ft.getmetrics()
    ImageDraw.Draw(im).text((icon.width + gap, (icon.height - asc - desc) // 2 + int(size * 0.04)), 'ZONBER', font=ft, fill=(255, 255, 255))
    return shadowed(im, blur=12, alpha=0.4)


def hero_card(i, w, h, label, size):
    """존 히어로 아트 카드 + 왼쪽 아래 칩"""
    src = Image.open(os.path.join(ROOT, f'assets/images/worlds/{HEROES[i]}_hero.png')).convert('RGB')
    s = max(w / src.width, h / src.height)
    src = src.resize((math.ceil(src.width * s), math.ceil(src.height * s)), Image.LANCZOS)
    x, y = (src.width - w) // 2, (src.height - h) // 2
    card = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    card.paste(src.crop((x, y, x + w, y + h)), (0, 0), rounded_mask(w, h, int(h * 0.11)))
    chip = chip_layer(label, size, SCENES[i][2])
    card.alpha_composite(chip, (int(h * 0.08) - 36, h - chip.height - int(h * 0.08) + 36))
    return shadowed(card, blur=16, offset=(0, 10), alpha=0.45)


def background(w, h, accent=None):
    """짙은 남색 그라데이션 + 은은한 빛(장면 강조색)"""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = (xx / w + yy / h) / 2
    c0, c1, c2 = np.array([23, 27, 54]), np.array([34, 26, 79]), np.array([20, 26, 51])
    img = np.where(t[..., None] < 0.55, c0 + (c1 - c0) * (t[..., None] / 0.55), c1 + (c2 - c1) * ((t[..., None] - 0.55) / 0.45))

    def glow(cx, cy, rx, ry, color, a):
        g = np.exp(-(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2) * 2.2)[..., None] * a
        return img * (1 - g) + np.array(color) * g

    img = glow(w * 0.78, h * 0.3, w * 0.6, h * 0.5, accent or (34, 199, 230), 0.28)
    img = glow(w * 0.12, h * 0.85, w * 0.5, h * 0.45, (142, 112, 242), 0.35)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).convert('RGBA')


# ── 레이아웃 ──────────────────────────────────────────

class Layout:
    """비율 하나 — 고정 배경(그림자·테두리 포함)과 글자 자리"""

    def __init__(self, key, w, h, txt):
        self.key, self.w, self.h = key, w, h
        if key == 'portrait_9x16':
            ph = 1540
            self.panel = ((w - round(ph * 9 / 16)) // 2, 350, round(ph * 9 / 16), ph)
            cx, region = w // 2, (20, 334)
            title_size, title_w, chip_size = 82, 1000, 50
        elif key == 'landscape_16x9':
            ph = 1000
            pw = round(ph * 9 / 16)
            self.panel = (w - pw - 190, 40, pw, ph)
            cx, region = 600, (380, 880)
            self.brand_at = (600, 290)
            title_size, title_w, chip_size = 100, 900, 56
        else:
            ph = 1000
            pw = round(ph * 9 / 16)
            self.panel = (w - pw - 40, 40, pw, ph)
            cx, region = 252, (250, 1040)
            self.brand_at = (252, 150)
            title_size, title_w, chip_size = 76, 420, 42
        self.chips = [chip_layer(z, chip_size, SCENES[i][2], title_w) for i, z in enumerate(txt['zones'])]
        # 제목(줄 수는 언어마다 다르다)과 칩을 글자 자리 [region] 가운데에 위아래로 쌓는다 — 레이어 둘레의 그림자 여백은 뺀다.
        # 자리를 넘치면 제목 글자를 줄인다
        ch = max(c.height for c in self.chips) - 2 * 36
        gap = round(chip_size * 0.45)
        while True:
            self.titles = [text_layer(txt['hook'], FONT_BLACK, title_size, title_w), text_layer(txt['title'], FONT_BLACK, title_size, title_w)]
            th = max(t.height for t in self.titles) - 2 * 42
            if th + gap + ch <= region[1] - region[0] or title_size <= 40:
                break
            title_size -= 4
        y0 = region[0] + (region[1] - region[0] - (th + gap + ch)) / 2
        self.title_at, self.chip_at = (cx, y0 + th / 2), (cx, y0 + th + gap + ch / 2)
        self.brand = brand_layer({'portrait_9x16': 60, 'landscape_16x9': 56, 'square_1x1': 44}[key]) if key != 'portrait_9x16' else None
        x, y, pw, ph = self.panel
        self.mask = rounded_mask(pw, ph, int(pw * 0.06))
        self.bgs = []
        for _, _, accent in SCENES:
            bg = background(w, h, accent)
            sh = Image.new('RGBA', (w, h), (0, 0, 0, 0))
            ImageDraw.Draw(sh).rounded_rectangle((x - 6, y + 10, x + pw + 6, y + ph + 22), int(pw * 0.07), fill=(0, 0, 0, 150))
            bg.alpha_composite(sh.filter(ImageFilter.GaussianBlur(22)))
            ImageDraw.Draw(bg).rounded_rectangle((x - 6, y - 6, x + pw + 5, y + ph + 5), int(pw * 0.065), fill=(255, 255, 255, 255))
            if self.brand:
                put(bg, self.brand, self.brand_at)
            self.bgs.append(bg)
        self.end = self._end_parts(txt)

    def _end_parts(self, txt):
        w, h = self.w, self.h
        if self.key == 'portrait_9x16':
            parts = [
                (brand_layer(76), (w // 2, 250), 0.0),
                (text_layer(txt['end_title'], FONT_BLACK, 92, 980), (w // 2, 450), 0.15),
                *[(hero_card(i, 940, 300, txt['zones'][i], 46), (w // 2, 760 + i * 340), 0.3 + i * 0.1) for i in range(3)],
                (text_layer(txt['end_sub'], FONT_BOLD, 48, 980, color=(235, 238, 255)), (w // 2, 1790), 0.7),
            ]
        elif self.key == 'landscape_16x9':
            parts = [
                (brand_layer(66), (520, 300), 0.0),
                (text_layer(txt['end_title'], FONT_BLACK, 96, 820), (520, 520), 0.15),
                (text_layer(txt['end_sub'], FONT_BOLD, 44, 820, color=(235, 238, 255)), (520, 720), 0.7),
                *[(hero_card(i, 760, 280, txt['zones'][i], 40), (1420, 230 + i * 310), 0.3 + i * 0.1) for i in range(3)],
            ]
        else:
            parts = [
                (brand_layer(52), (w // 2, 95), 0.0),
                (text_layer(txt['end_title'], FONT_BLACK, 70, 980), (w // 2, 215), 0.15),
                *[(hero_card(i, 940, 190, txt['zones'][i], 34), (w // 2, 395 + i * 205), 0.3 + i * 0.1) for i in range(3)],
                (text_layer(txt['end_sub'], FONT_BOLD, 38, 980, color=(235, 238, 255)), (w // 2, 990), 0.7),
            ]
        return parts


def put(canvas, layer, center, t=None, dur=0.28):
    """[layer] 를 [center] 에 — [t](등장 뒤 지난 초)가 있으면 커졌다가 자리 잡는 등장"""
    if t is not None:
        if t < 0:
            return
        if t < dur:
            p = t / dur
            s = 1.22 - 0.22 * ease_out_back(p)
            a = min(1.0, t / 0.12)
            lw, lh = max(1, round(layer.width * s)), max(1, round(layer.height * s))
            layer = layer.resize((lw, lh), Image.BILINEAR)
            if a < 1:
                layer = layer.copy()
                layer.putalpha(layer.getchannel('A').point(lambda v: int(v * a)))
    canvas.alpha_composite(layer, (round(center[0] - layer.width / 2), round(center[1] - layer.height / 2)))


# ── 소리 ──────────────────────────────────────────────

def read_wav(path):
    with wave.open(path) as w:
        n, ch, sw, sr = w.getnframes(), w.getnchannels(), w.getsampwidth(), w.getframerate()
        raw = w.readframes(n)
    dt = {1: np.uint8, 2: np.int16, 4: np.int32}[sw]
    a = np.frombuffer(raw, dt).astype(np.float32)
    a = (a - 128) / 128 if sw == 1 else a / float(2 ** (8 * sw - 1))
    a = a.reshape(-1, ch)
    if ch == 1:
        a = np.repeat(a, 2, axis=1)
    if sr != SR:
        x = np.linspace(0, len(a) - 1, int(len(a) * SR / sr))
        a = np.stack([np.interp(x, np.arange(len(a)), a[:, c]) for c in range(2)], axis=1)
    return a


def decode_mp3(ff, path):
    out = subprocess.run([ff, '-v', 'error', '-i', path, '-f', 'f32le', '-ac', '2', '-ar', str(SR), '-'], capture_output=True, check=True).stdout
    return np.frombuffer(out, np.float32).reshape(-1, 2)


def mix_audio(ff, events, total_sec, out_path):
    n = int(total_sec * SR)
    mix = np.zeros((n, 2), np.float32)
    bgm = decode_mp3(ff, os.path.join(ROOT, 'assets/audio/bgm.mp3'))
    while len(bgm) < n:
        bgm = np.concatenate([bgm, bgm])
    bgm = bgm[:n] * 0.5
    fade_in, fade_out = int(0.15 * SR), int(1.2 * SR)
    bgm[:fade_in] *= np.linspace(0, 1, fade_in)[:, None]
    bgm[-fade_out:] *= np.linspace(1, 0, fade_out)[:, None]
    mix += bgm
    cache, last = {}, {}
    for t, name, vol in sorted(events):
        if t - last.get(name, -1) < 0.07:  # 같은 소리가 겹쳐 터지지 않게(게임의 minGapMs 와 비슷)
            continue
        last[name] = t
        f = os.path.join(ROOT, 'assets/audio', name)
        if not os.path.exists(f):
            continue
        if name not in cache:
            cache[name] = read_wav(f)
        s = cache[name] * (vol * 0.8)
        i = int(t * SR)
        if i >= n:
            continue
        j = min(n, i + len(s))
        mix[i:j] += s[: j - i]
    mix = np.tanh(mix * 1.1) / np.tanh(1.1)  # 부드럽게 눌러 찢어지지 않게
    with wave.open(out_path, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(mix, -1, 1) * 32767).astype(np.int16).tobytes())


# ── 구간 고르기 · 손가락 ──────────────────────────────

def pick_window(frames, n):
    """[n] 프레임 구간 중 맞은(hit)·실점(goal)이 가장 적고 막은(save)이 많은 곳"""
    score = []
    for f in frames:
        names = [s[0] for s in f['sfx']]
        score.append(names.count('hit.wav') * 10 + names.count('goal.wav') * 4 - names.count('save.wav') * 0.3)
    best, best_s = 0, None
    for s in range(0, len(frames) - n + 1):
        v = sum(score[s:s + n])
        if best_s is None or v < best_s:
            best, best_s = s, v
    return best


_HAND = None


def hand_layer(height=300):
    """가리키는 손(코드 드로잉) — 검지 끝이 (tip) 자리. 4배로 그려 줄인다"""
    global _HAND
    if _HAND:
        return _HAND
    S = 4
    W, H = 230, 262
    m = Image.new('L', (W * S, H * S), 0)
    d = ImageDraw.Draw(m)
    rr = lambda x0, y0, x1, y1, r: d.rounded_rectangle((x0 * S, y0 * S, x1 * S, y1 * S), r * S, fill=255)
    rr(70, 8, 112, 150, 21)     # 검지
    rr(108, 86, 146, 168, 19)   # 접은 손가락 셋
    rr(142, 100, 176, 176, 17)
    rr(172, 118, 202, 182, 15)
    rr(66, 128, 202, 252, 46)   # 손바닥
    th = Image.new('L', (44 * S, 96 * S), 0)  # 엄지 — 왼쪽 위로 비스듬히
    ImageDraw.Draw(th).rounded_rectangle((0, 0, 44 * S - 1, 96 * S - 1), 22 * S, fill=255)
    th = th.rotate(38, expand=True, resample=Image.BICUBIC)
    m.paste(255, (24 * S, 124 * S), th)
    outline = m.filter(ImageFilter.MaxFilter(27))
    im = Image.new('RGBA', m.size, (0, 0, 0, 0))
    im.paste((22, 26, 52, 255), (0, 0), outline)
    im.paste((252, 252, 255, 255), (0, 0), m)
    d = ImageDraw.Draw(im)
    for x, y0, y1 in [(110, 96, 150), (144, 108, 166), (174, 126, 172)]:  # 손가락 사이 주름
        d.line((x * S, y0 * S, x * S, y1 * S), fill=(22, 26, 52, 255), width=4 * S)
    k = height / H
    im = im.resize((round(W * k), height), Image.LANCZOS).rotate(-10, expand=True, resample=Image.BICUBIC)
    tip = (91 * k, 10 * k)
    # 회전 뒤 끝 자리 — 가운데를 축으로 -10° 돌렸다
    cx0, cy0 = W * k / 2, height / 2
    a = math.radians(10)
    dx, dy = tip[0] - cx0, tip[1] - cy0
    tip = (im.width / 2 + dx * math.cos(a) - dy * math.sin(a), im.height / 2 + dx * math.sin(a) + dy * math.cos(a))
    _HAND = (shadowed(im, blur=10, offset=(0, 8), alpha=0.35), tip)
    return _HAND


def draw_finger(img, x, y, alpha, t):
    """손가락 — 캐릭터 아래쪽을 같이 끄는 손 + 닿은 자리 물결"""
    if alpha <= 0 or x is None:
        return
    alpha = min(1.0, alpha)
    fx, fy = x * 3, min((y + 100) * 3, 1800)
    ov = Image.new('RGBA', img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    for ph in ((t * 1.4) % 1, (t * 1.4 + 0.5) % 1):
        r = 30 + 70 * ph
        d.ellipse((fx - r, fy - r, fx + r, fy + r), outline=(255, 255, 255, int(200 * (1 - ph) * alpha)), width=6)
    d.ellipse((fx - 22, fy - 22, fx + 22, fy + 22), fill=(255, 255, 255, int(150 * alpha)))
    hand, tip = hand_layer()
    pad = 30  # shadowed() 여백(blur 10 × 3)
    if alpha < 1:
        hand = hand.copy()
        hand.putalpha(hand.getchannel('A').point(lambda v: int(v * alpha)))
    ov.alpha_composite(hand, (round(fx - tip[0] - pad), round(fy - tip[1] - pad + 8)))
    img.alpha_composite(ov)


# ── 본체 ──────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--lang', default='ko', choices=sorted(TEXT))
    ap.add_argument('--formats', default=','.join(FORMATS))
    ap.add_argument('--cut', default='all', choices=[*CUTS, 'all'])
    args = ap.parse_args()
    for cut in (CUTS if args.cut == 'all' else [args.cut]):
        render(args, cut)


def render(args, cut):
    global HOOK_SEC
    secs, HOOK_SEC, tail = CUTS[cut]
    txt = TEXT[args.lang]
    ff = ffmpeg_exe()
    src_dir = os.path.join(ROOT, 'build', 'ad_video', args.lang)
    out_dir = os.path.join(ROOT, 'store', 'ad_videos', args.lang)
    os.makedirs(out_dir, exist_ok=True)

    # 장면 구간
    plan = []  # (장면 번호, 원본 폴더, 시작 프레임, 프레임 수, 프레임 정보)
    for k, ((name, _, _), sec) in enumerate(zip(SCENES, secs)):
        meta_path = os.path.join(src_dir, name, 'frames.json')
        if not os.path.exists(meta_path):
            sys.exit(f'캡처가 없다: {meta_path} — node scripts/ad_video_capture.mjs --lang {args.lang} 먼저')
        frames = json.load(open(meta_path, encoding='utf-8'))['frames']
        n = round(sec * FPS)
        s = pick_window(frames, n)
        plan.append((k, os.path.join(src_dir, name), s, n, frames))
        print(f'{name}: 프레임 {s}~{s + n} (생존 {frames[s]["t"]:.1f}s~)')
    game_frames = sum(p[3] for p in plan)
    end_frames = round(END_SEC * FPS)
    total = game_frames + end_frames

    # 소리 — 쓰는 구간의 효과음 + 끝 화면 신기록 소리
    events, g = [], 0
    for k, _, s, n, frames in plan:
        for i in range(n):
            for name, vol in frames[s + i]['sfx']:
                events.append(((g + i) / FPS, name, vol))
        g += n
    events.append((game_frames / FPS + 0.05, 'newbest.wav', 0.9))
    audio = os.path.join(ROOT, 'build', 'ad_video', f'{args.lang}{tail}_audio.wav')
    mix_audio(ff, events, total / FPS, audio)

    layouts = [Layout(k, *FORMATS[k], txt) for k in args.formats.split(',')]
    procs = {}
    for L in layouts:
        out = os.path.join(out_dir, f'zonber_{L.key}{tail}.mp4')
        procs[L.key] = subprocess.Popen([
            ff, '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{L.w}x{L.h}', '-r', str(FPS), '-i', '-',
            '-i', audio, '-c:v', 'libx264', '-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p', '-profile:v', 'high',
            '-c:a', 'aac', '-b:a', '192k', '-shortest', '-movflags', '+faststart', out,
        ], stdin=subprocess.PIPE)
    end_bg = {L.key: background(L.w, L.h, (142, 112, 242)) for L in layouts}
    previews = {L.key: [] for L in layouts}
    starts = [sum(p[3] for p in plan[:k]) for k in range(len(plan))]
    preview_at = {FPS} | {starts[k] + int(plan[k][3] * 0.6) for k in range(len(plan))} | {game_frames + 12, total - 6}

    g = 0
    for k, folder, s, n, frames in plan:
        for i in range(n):
            f = frames[s + i]
            src = Image.open(os.path.join(folder, f'f{s + i:04d}.png')).convert('RGBA')
            t = g / FPS
            if k == 0:  # 손가락 표시 — 첫 장면 앞부분만
                draw_finger(src, f.get('x'), f.get('y'), (HOOK_SEC + 0.6 - t) / 0.4, t)
            scaled = {}
            for L in layouts:
                x, y, pw, ph = L.panel
                if (pw, ph) not in scaled:
                    scaled[(pw, ph)] = src.resize((pw, ph), Image.LANCZOS)
                frame = L.bgs[k].copy()
                frame.paste(scaled[(pw, ph)], (x, y), L.mask)
                scene_t = i / FPS
                hook = k == 0 and t < HOOK_SEC
                put(frame, L.titles[0 if hook else 1], L.title_at, t - (0 if hook else HOOK_SEC) if (k == 0) else None)
                put(frame, L.chips[k], L.chip_at, scene_t - 0.12)
                if k > 0 and i < 6:  # 장면이 바뀔 때 번쩍
                    frame.alpha_composite(Image.new('RGBA', frame.size, (255, 255, 255, int(150 * (1 - i / 6)))))
                procs[L.key].stdin.write(frame.convert('RGB').tobytes())
                if g in preview_at:
                    previews[L.key].append(frame.convert('RGB'))
            g += 1
        print(f'{SCENES[k][0]} 합성 끝')

    for i in range(end_frames):
        t = i / FPS
        for L in layouts:
            frame = end_bg[L.key].copy()
            for layer, at, delay in L.end:
                put(frame, layer, at, t - delay)
            if i < 6:
                frame.alpha_composite(Image.new('RGBA', frame.size, (255, 255, 255, int(170 * (1 - i / 6)))))
            procs[L.key].stdin.write(frame.convert('RGB').tobytes())
            if g in preview_at:
                previews[L.key].append(frame.convert('RGB'))
        g += 1

    for L in layouts:
        procs[L.key].stdin.close()
        procs[L.key].wait()
        # 미리보기 — 장면별 한 장씩 이어 붙인 시트(build/ad_video/)
        ims = previews[L.key]
        if ims:
            sw = 360
            sh = round(sw * L.h / L.w)
            sheet = Image.new('RGB', (sw * len(ims), sh))
            for j, im in enumerate(ims):
                sheet.paste(im.resize((sw, sh), Image.LANCZOS), (j * sw, 0))
            sheet.save(os.path.join(ROOT, 'build', 'ad_video', f'{args.lang}_{L.key}{tail}_sheet.png'))
        print('만듦', os.path.relpath(os.path.join(out_dir, f'zonber_{L.key}{tail}.mp4'), ROOT), f'{total / FPS:.1f}초')


if __name__ == '__main__':
    main()
