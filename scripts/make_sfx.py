"""효과음 합성 — assets/audio/*.wav (44.1kHz · 16bit · 스테레오). 녹음·외부 음원 없이 코드로 만든다.
   python scripts/make_sfx.py            (numpy · scipy — scripts/audio_dsp.py)

휴대폰 스피커 기준으로 만든다 — 스피커는 200Hz 아래를 거의 못 내니 '무게'는 낮은 울림을 살짝 일그러뜨려 생긴
배음(200~600Hz)으로 들리게 하고, 귀가 따가운 2~5kHz 는 덜어 낸다. 소리마다 어택(짧은 딱) · 몸통 · 질감을 겹치고
스테레오 작은 방 잔향을 입힌다.
크기는 꼭대기(peak)가 아니라 귀로 듣는 크기(LUFS 근사 — audio_dsp.loudness)로 맞춘다. 아래 LOUD 표가 소리별 목표다.
배경음악(약 -18 LUFS · 게임에서 볼륨 0.5)보다 조금 위에 오도록, 자주 나는 소리는 더 작게 잡았다.
자주 나는 소리(Sfx.busy)는 조금씩 다른 4벌을 만든다 — name.wav · name_2.wav · name_3.wav · name_4.wav.
이벤트 연결은 lib/audio_manager.dart(Sfx) 참고.
"""
import os

import numpy as np

from audio_dsp import (SR, adsr, bp, drive, expdec, fade, hp, ks_pluck, limiter, loudness, lp, modal, noise, ns,
                       pan, pitch_env, reverb, saw, shelf, sine, square, sweep, tri, write_wav)

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')

# 소리별 목표 크기(LUFS 근사, 0.1초 창 최댓값) — 게임 코드의 playSfx(volume) 가 여기에 한 번 더 곱해진다
LOUD = {
    'hit': -15, 'gameover': -16, 'throw': -19, 'kick': -17, 'save': -16, 'goal': -16, 'graze': -21,
    'coin': -17, 'badge': -16, 'purchase': -16, 'equip': -18, 'levelup': -16, 'newbest': -15,
    'heartbeat': -18, 'click': -22,
}
CEIL = 0.708  # 꼭대기 -3dBFS
VARIANTS = 4  # 자주 나는 소리의 벌 수 — lib/audio_manager.dart Sfx.busyPlayers 와 같게


# ── 섞기 · 저장 ───────────────────────────────────────────────────────

def st(x):
    return x if x.ndim == 2 else np.stack([x, x], 1)


def mix(total, parts):
    """(시작 초, 신호, 크기[, 좌우 -1~1]) 목록을 스테레오 한 트랙으로 — 겹마다 끝을 살짝 줄여 둔다"""
    out = np.zeros((ns(total), 2))
    for p in parts:
        start, sig, g = p[:3]
        s = pan(sig, p[3]) if len(p) > 3 and sig.ndim == 1 else st(sig)
        s = fade(s, 0.0, min(0.025, len(s) / SR * 0.25))  # 겹이 뚝 끊기면 '틱' 소리가 난다
        i = ns(start)
        k = min(len(s), len(out) - i)
        if k > 0:
            out[i:i + k] += s[:k] * g
    return out


def room(x, wet=0.12, rt60=0.35, damp=6500.0, predelay=0.006):
    """스테레오 작은 방 잔향을 입히고 원래 길이로 자른다"""
    x = st(x)
    w = reverb(x, rt60=rt60, predelay=predelay, damp=damp, hp_in=220)
    return x + wet * w[:len(x)]


def moving_pan(mono, p0, p1):
    """소리가 왼쪽→오른쪽으로 지나가게(등전력)"""
    a = (np.linspace(p0, p1, len(mono)) + 1) * np.pi / 4
    return np.stack([mono * np.cos(a), mono * np.sin(a)], 1) * np.sqrt(2)


def save(name, sig, key=None, tail=0.012):
    key = key or os.path.splitext(name)[0].split('_')[0]
    x = st(np.asarray(sig, float))
    x = hp(x, 45)  # 폰이 못 내는 초저역은 헤드룸만 먹는다
    x = shelf(x, 9500, -2.0, 'high')  # 맨 위 쉿소리를 살짝 눌러 둔다
    x = fade(x - x.mean(0), 0.0004, tail)
    x *= 10 ** ((LOUD[key] - loudness(x)) / 20)
    x = limiter(x, ceiling=CEIL, look=0.002, release=0.05)
    if np.max(np.abs(x[:, 0] - x[:, 1])) < 1e-4:
        x = x[:, 0]  # 좌우가 같으면 모노로
    write_wav(os.path.join(OUT, name), x)
    print(f'{name:16s} {len(x) / SR:.2f}s  {loudness(x):6.1f} LUFS  peak {20 * np.log10(np.abs(x).max()):5.1f} dB')


def variants(name, make):
    """자주 나는 소리 4벌 — make(v) 는 v = 0..3 마다 조금씩 다른 신호"""
    for v in range(VARIANTS):
        save(name if v == 0 else name.replace('.wav', f'_{v + 1}.wav'), make(v), key=name[:-4])


# ── 악기 ──────────────────────────────────────────────────────────────

def glock(f, dur, tau=0.4, bright=1.0, mallet=0.25):
    """글로켄슈필 막대 — 맑고 둥근 금속 '팅'(막대의 어긋난 배음 2.76 · 5.40 · 8.93)"""
    parts = [(1, 1.0, tau), (2.76, 0.30 * bright, tau * 0.35), (5.40, 0.10 * bright, tau * 0.18), (8.93, 0.04 * bright, tau * 0.1)]
    return lp(modal(f, dur, parts, mallet=mallet, mallet_f=6000), 9000)


def marimba(f, dur, tau=0.25):
    """마림바 — 나무 막대의 따뜻한 '똑'(배음 4 · 10)"""
    return lp(modal(f, dur, [(1, 1.0, tau), (3.93, 0.22, tau * 0.25), (9.9, 0.05, tau * 0.08)], mallet=0.15, mallet_f=3000), 7000)


def epiano(f, dur, tau=0.7):
    """FM 전자 피아노 — 둥근 건반(밝기가 금방 가라앉는다) + 아주 짧은 쇳소리"""
    n = ns(dur)
    k = np.arange(n) / SR
    idx = 1.3 * np.exp(-k / 0.22) + 0.25
    s = np.sin(2 * np.pi * f * k + idx * np.sin(2 * np.pi * f * k))
    if f * 14 < SR * 0.45:
        s += 0.06 * np.sin(2 * np.pi * f * 14 * k) * np.exp(-k / 0.012)
    return fade(s * np.exp(-k / tau) * np.minimum(1, k / 0.003), 0.0, 0.02)


def fm_sweep(fc, ratio, index):
    """움직이는 음높이(fc 배열)의 FM — 디지털 '지직'"""
    ph = np.concatenate([[0.0], np.cumsum(fc[:-1])]) / SR
    return np.sin(2 * np.pi * ph + index * np.sin(2 * np.pi * ratio * ph))


def thump(f0, f1, dur, tau, sat=2.0, glide=0.035):
    """낮은 '쿵' — 사인 울림을 살짝 일그러뜨려 휴대폰에서도 들리는 배음을 만든다"""
    n = ns(dur)
    s = sine(pitch_env(f0, f1, glide, n), n) * expdec(n, tau)
    return shelf(lp(drive(s * sat, sat), 2500), 160, -7.0, 'low')  # 바닥 울림은 줄이고 배음을 남긴다


def burst(dur, lo, hi, tau):
    """대역을 자른 짧은 노이즈 '탁'"""
    n = ns(dur)
    return bp(noise(n), lo, hi) * expdec(n, tau)


def brass(f, dur, vib=False):
    """신스 브라스 — 아래에서 살짝 올라붙는 음(scoop) · 세기에 따라 열리는 필터 · 뒤에 비브라토"""
    n = ns(dur)
    k = np.arange(n) / SR
    fr = f * 2 ** (-0.7 * np.exp(-k / 0.025) / 12)
    if vib:
        fr = fr * 2 ** (0.16 * np.sin(2 * np.pi * 5.3 * k) * np.clip((k - 0.18) / 0.25, 0, 1) / 12)
    s = saw(fr * 1.004, n) + saw(fr * 0.996, n) + 0.3 * square(fr, n, 0.3)
    amp = adsr(dur - 0.07, 0.018, 0.14, 0.72, 0.07, n=n)
    bright = adsr(dur - 0.07, 0.03, 0.22, 0.45, 0.07, n=n)
    return lp(sweep(s, 500 + 3600 * bright + f * 0.8, q=0.75), 6500) * amp


# ── 소리 ──────────────────────────────────────────────────────────────

def hit(v):
    """피격 — 묵직한 '퍽'(배음으로 들리는 몸통) + 둔탁한 '톡' + 짧은 지직(아래로 떨어지는 FM)"""
    r = 2 ** ([0, -1.2, 0.9, -0.5][v] / 12)
    d = 0.42
    n = ns(d)
    body = thump(250 * r, 82 * r, d, 0.085, sat=2.2)
    knock = modal(330 * r, 0.2, [(1, 1, 0.05), (1.58, 0.5, 0.03), (2.31, 0.25, 0.018)], mallet=0.3, mallet_f=2500)
    crunch = drive(burst(0.08, 800, 3800, 0.016) * 2.5, 2.0)
    zap = lp(fm_sweep(pitch_env(1300 * r, 240 * r, 0.05, n), 1.5, 2.2 * expdec(n, 0.04)), 4500) * expdec(n, 0.06)
    return room(mix(d, [(0, body, 1.0), (0, knock, 0.7), (0, crunch, 0.36, [-0.15, 0.15, 0.1, -0.1][v]),
                        (0.003, zap, 0.16)]), 0.1, rt60=0.3)


def graze(v):
    """추가 기록(아슬하게 피함) — 귀가 따갑지 않은 작은 '팅' + 스치는 바람. 벌마다 음이 달라 여러 번 나면 풍경 소리처럼"""
    f = [1568.0, 1760.0, 1318.5, 1174.7][v]  # G6 A6 E6 D6 (5음 음계)
    p = [-0.25, 0.25, 0.1, -0.1][v]
    d = 0.32
    m = ns(0.09)
    km = np.arange(m) / SR
    swish = sweep(noise(m), 3400 - 2200 * km / km[-1], q=1.3, kind='bp') * adsr(0.02, 0.008, 0.03, 0.5, 0.06, n=m)
    ping = glock(f, 0.3, tau=0.075, bright=0.7, mallet=0.12)
    return room(mix(d, [(0, swish, 0.35, -p), (0.008, ping, 1.0, p * 0.6)]), 0.16, rt60=0.4)


def throw_(v):
    """피구 던지기 — 손을 떠나는 '틱' + 공이 앞을 지나가는 바람(좌우로 흐른다) + 낮은 '훅'"""
    d = [0.36, 0.32, 0.4, 0.34][v]
    peak_hz = [1700, 2000, 1500, 1850][v]
    pans = [(-0.6, 0.6), (0.6, -0.6), (-0.4, 0.7), (0.5, -0.5)][v]
    n = ns(d)
    u = np.arange(n) / n
    shape = np.sin(np.pi * np.clip(u, 0, 1) ** 0.75) ** 1.8  # 앞쪽이 빨리 차오르고 천천히 사라진다
    center = 380 + (peak_hz - 380) * np.sin(np.pi * u ** 0.8) ** 2
    whoosh = lp(sweep(noise(n), center, q=2.4, kind='bp'), 5000) * shape
    air = lp(hp(noise(n), 2500), 6000) * shape ** 2 * 0.1
    fwoop = drive(sine(pitch_env(190, 115, 0.12, n), n) * 1.6, 1.6) * shape
    snap = burst(0.014, 1200, 5000, 0.0028)
    return room(mix(d, [(0, moving_pan(whoosh + air, *pans), 1.0), (0, fwoop, 0.22), (0, snap, 0.22, pans[0])]),
                0.06, rt60=0.3)


def kick(v):
    """골키퍼 킥 — 가죽 공 '뻥': 딱(발등) + 가죽 찰싹 + 속 빈 공의 '퐁' + 낮은 몸통 + 날아가는 바람"""
    r = [1.0, 0.94, 1.07, 0.98][v]
    d = 0.34
    click = burst(0.01, 1500, 6000, 0.0016)
    slap = drive(burst(0.06, 500, 2600, 0.008) * 2, 1.6)
    ball = modal(215 * r, 0.25, [(1, 1, 0.045), (2.1, 0.45, 0.028), (3.4, 0.18, 0.018)])
    body = thump(150 * r, 72 * r, 0.25, 0.06, sat=2.0, glide=0.03)
    m = ns(0.2)
    k = np.arange(m) / m
    fly = sweep(noise(m), 900 + 1800 * k, q=1.1, kind='bp') * np.sin(np.pi * k) ** 2
    return room(mix(d, [(0, click, 0.45), (0, slap, 0.55), (0, ball, 0.8), (0, body, 0.7),
                        (0.03, moving_pan(fly, 0, [0.5, -0.5, 0.3, -0.3][v]), 0.12)]), 0.08, rt60=0.3)


def save_(v):
    """선방 — 장갑 '팡'(두툼한 가죽 + 손바닥 몸통) + 기분 좋은 두 음 '띵-딩'"""
    r = 2 ** ([0, -0.6, 0.5, 0.2][v] / 12)
    notes = [(987.8, 1318.5), (1046.5, 1568.0), (1174.7, 1568.0), (987.8, 1479.98)][v]
    d = 0.6
    glove = drive(burst(0.08, 380, 2200, 0.013) * 2.2, 1.6)
    slap = burst(0.03, 2000, 6000, 0.004)
    palm = thump(240 * r, 150 * r, 0.2, 0.045, sat=1.8, glide=0.02)
    return room(mix(d, [(0, glove, 0.8), (0, slap, 0.25), (0, palm, 0.6),
                        (0.03, glock(notes[0], 0.3, tau=0.09, bright=0.6), 0.2, -0.2),
                        (0.085, glock(notes[1], 0.45, tau=0.14, bright=0.6), 0.24, 0.2)]), 0.12, rt60=0.45)


def goal():
    """실점 — 공이 그물에 '철썩' + 그물 출렁임(좌우로 퍼진다) + 짧은 호루라기(따갑지 않게 낮고 부드럽게)"""
    d = 1.25
    impact = mix(0.3, [(0, thump(175, 95, 0.3, 0.06, sat=2.2), 0.8), (0, burst(0.1, 300, 1600, 0.025), 0.5)])
    n = ns(0.8)
    k = np.arange(n) / SR
    ripple = 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 8 * k + 2 * np.sin(2 * np.pi * 3 * k)))
    env = expdec(n, 0.17) * ripple * np.minimum(1, k / 0.01)
    net = np.stack([lp(hp(noise(n), 900), 6000), lp(hp(noise(n), 900), 6000)], 1) * env[:, None]
    m = ns(0.42)
    km = np.arange(m) / SR
    trill = lp(0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 24 * km)), 250)
    f = 2350 * 2 ** (0.25 * np.sin(2 * np.pi * 24 * km) / 12)
    tone = (sine(f, m) + 0.18 * sine(f * 2, m)) * trill
    whistle = lp(tone + bp(noise(m), 1800, 3600) * 0.18, 4200) * adsr(0.36, 0.02, 0.1, 0.85, 0.06, n=m)
    return room(mix(d, [(0, impact, 0.9), (0, net, 0.5), (0.32, whistle, 0.22, 0.1)]), 0.16, rt60=0.6)


def coin(v):
    """코인 — '띠링'(B5 → E6): 글로켄 + 살짝 레트로한 사각파, 끝에 작은 반짝. 벌마다 아주 조금씩 다르게"""
    r = 2 ** ([0, 0.12, -0.1, 0.05][v] / 12)
    d = 0.6

    def note(f, ln, tau):
        m = ns(ln)
        sq = lp(square(f, m, 0.5), 3800) * expdec(m, tau * 0.45)
        return sq * 0.18 + glock(f, ln, tau=tau, bright=0.8, mallet=0.15)

    m = ns(0.25)
    sparkle = lp(hp(noise(m), 7000), 11000) * adsr(0.05, 0.02, 0.06, 0.3, 0.15, n=m)
    return room(mix(d, [(0, note(987.8 * r, 0.14, 0.05), 0.75, -0.15), (0.07, note(1318.5 * r, 0.5, 0.15), 1.0, 0.15),
                        (0.09, sparkle, 0.05, [0.4, -0.4, 0.2, -0.2][v])]), 0.14, rt60=0.5)


def badge():
    """뱃지 — 좌우로 퍼지며 올라가는 종 아르페지오(C6 E6 G6 C7) + 밑에 깔리는 부드러운 화음 + 반짝"""
    d = 1.9
    arp = []
    for i, (f, p) in enumerate(zip([1046.5, 1318.5, 1568.0, 2093.0], [-0.45, -0.15, 0.15, 0.45])):
        arp.append((i * 0.07, glock(f, 1.3 - i * 0.12, tau=0.45, bright=0.8), 0.7, p))
        arp.append((i * 0.07, epiano(f / 2, 1.0, tau=0.4), 0.18, p))
    n = ns(1.4)
    pad = np.zeros((n, 2))
    for i, f in enumerate((523.3, 659.3, 784.0)):
        for det, p in ((-0.06, -0.5), (0.06, 0.5)):
            pad += pan(saw(f * 2 ** (det / 12), n), p)
    pad = lp(pad, 1600) * adsr(0.75, 0.18, 0.3, 0.8, 0.6, n=n)[:, None]
    m = ns(1.0)
    km = np.arange(m) / SR
    trem = 0.5 + 0.5 * np.sin(2 * np.pi * 11 * km)
    sparkle = np.stack([lp(hp(noise(m), 6500), 11000), lp(hp(noise(m), 6500), 11000)], 1) * \
        (adsr(0.4, 0.15, 0.2, 0.5, 0.5, n=m) * trem)[:, None]
    return room(mix(d, arp + [(0.12, pad, 0.05), (0.22, sparkle, 0.035)]), 0.3, rt60=1.2, damp=7500)


def purchase():
    """구매 — 동전이 좌우로 쏟아지는 소리 + '차-링' 종 화음(G6 B6 D7) + 올라가는 반짝"""
    d = 1.2
    rr = np.random.default_rng(11)
    rattle = [(rr.uniform(0, 0.16), glock(rr.uniform(2100, 3400), 0.1, tau=0.025, bright=0.5, mallet=0.3),
               rr.uniform(0.12, 0.25), rr.uniform(-0.7, 0.7)) for _ in range(14)]
    ching = [(0.17, glock(f, 0.9, tau=0.32, bright=0.9), g, p) for f, g, p in
             ((1568.0, 0.7, -0.2), (1975.5, 0.55, 0.2), (2349.3, 0.4, 0.0))]
    ching.append((0.17, epiano(784.0, 0.8, tau=0.35), 0.25, 0.0))
    sparkle = [(0.32 + i * 0.05, glock(f, 0.3, tau=0.08, bright=0.4), 0.14, p) for i, (f, p) in
               enumerate(zip([2637.0, 3136.0, 3520.0], [-0.4, 0.0, 0.4]))]
    return room(mix(d, rattle + ching + sparkle), 0.22, rt60=0.8, damp=7500)


def equip():
    """장착 — 동그란 '뽁'(위로 튀는 물방울) + 나무 '똑' + 아주 짧은 철컥"""
    d = 0.24
    n = ns(0.16)
    pop = fade(sine(380 + 1000 * (1 - expdec(n, 0.025)), n) * expdec(n, 0.03), 0.002, 0.01)
    wood = marimba(659.3, 0.2, tau=0.06)
    shing = burst(0.05, 4000, 9000, 0.012)
    return room(mix(d, [(0, pop, 0.8), (0, wood, 0.45), (0.004, shing, 0.08, 0.2)]), 0.1, rt60=0.3)


def levelup():
    """레벨업 — 좌우를 오가며 빠르게 올라가는 현 아르페지오(C5→G6) + 위로 쓸리는 바람 + 마지막 종 화음"""
    d = 1.05
    steps = [523.3, 659.3, 784.0, 1046.5, 1318.5, 1568.0]
    arp = []
    for i, f in enumerate(steps):
        p = -0.4 + 0.8 * i / (len(steps) - 1)
        m = ns(0.35)
        pl = ks_pluck(f, 0.35, bright=0.55, decay=0.995, seed=i)[:m] * expdec(m, 0.12)
        soft = lp(square(f, m, 0.3), 2600) * expdec(m, 0.05) * 0.15
        arp.append((i * 0.045, lp(pl, 5000) + soft, 0.5, p))
    m = ns(0.36)
    k = np.arange(m) / m
    rise = sweep(noise(m), 700 + 3800 * k ** 1.5, q=1.2, kind='bp') * np.sin(np.pi * k)
    top = [(0.28, glock(2093.0, 0.7, tau=0.2, bright=0.7), 0.3, 0.2), (0.28, glock(1568.0, 0.7, tau=0.22, bright=0.7), 0.25, -0.2)]
    return room(mix(d, arp + top + [(0.0, moving_pan(rise, -0.5, 0.5), 0.16)]), 0.2, rt60=0.75)


def newbest():
    """신기록 — 브라스 팡파르(G5 C6 E6 → G6 길게) + 받치는 화음 · 종 겹침 + 팀파니 + 심벌 부풂"""
    d = 1.9
    parts = []
    for st_, f, ln in [(0.0, 784.0, 0.11), (0.1, 1046.5, 0.11), (0.2, 1318.5, 0.11)]:
        parts += [(st_, brass(f, ln + 0.07), 0.45, 0.0), (st_, glock(f, 0.3, tau=0.1, bright=0.6), 0.12, 0.25)]
    parts += [(0.3, brass(1568.0, 1.1, vib=True), 0.5, 0.0), (0.3, glock(1568.0, 1.0, tau=0.4, bright=0.6), 0.16, 0.0)]
    parts += [(0.3, brass(f, 1.05), 0.17, p) for f, p in ((523.3, -0.35), (659.3, 0.35), (784.0, 0.0), (261.6, 0.0))]
    timp = modal(98, 0.9, [(1, 1, 0.35), (1.5, 0.5, 0.22), (1.98, 0.3, 0.16), (2.44, 0.15, 0.1)], mallet=0.4, mallet_f=1200)
    parts += [(0.29, shelf(lp(drive(timp * 1.6, 1.6), 1800), 130, -5.0, 'low'), 0.5, 0.0)]
    m = ns(1.3)
    km = np.arange(m) / SR
    cym = np.stack([lp(hp(noise(m), 5000), 11000), lp(hp(noise(m), 5000), 11000)], 1) * \
        (np.minimum(1, km / 0.02) * np.exp(-km / 0.45))[:, None]
    parts += [(0.3, cym, 0.07)]
    return room(mix(d, parts), 0.24, rt60=1.1, damp=7000)


def heartbeat():
    """위기 — 심장박동 '쿵-쿵'(0.8초 반복). 낮은 울림을 일그러뜨려 휴대폰 스피커에서도 들리게, 끝은 조용히(이음매)"""
    d = 0.8

    def beat(f0, f1, g):
        m = ns(0.3)
        s = sine(pitch_env(f0, f1, 0.03, m), m) * expdec(m, 0.07)
        s = drive(s * 3.0, 3.0)  # 3·5배음(150~400Hz)이 생긴다
        thud = lp(noise(m), 380) * expdec(m, 0.025) * 0.5
        return shelf(lp(s + thud, 700), 130, -6.0, 'low') * g

    return mix(d, [(0.0, beat(72, 44, 1.0), 1.0), (0.2, beat(80, 48, 0.75), 1.0)])


def gameover():
    """게임 오버 — KO '쾅' + 전원이 꺼지듯 내려가는 음 + 슬픈 전자 피아노 네 음(G4 F4 Eb4 → D4 길게, 마지막은 처진다)"""
    d = 1.9
    ko = thump(200, 60, 0.6, 0.14, sat=2.4, glide=0.06)
    crunch = drive(burst(0.12, 500, 3000, 0.025) * 2, 1.8)
    n = ns(0.55)
    k = np.arange(n) / SR
    fr = 880 * 2 ** (-36 * (k / k[-1]) ** 0.7 / 12)
    down = sweep(saw(fr, n) * 0.6 + square(fr, n, 0.4) * 0.4, 400 + 3000 * np.exp(-k / 0.2), q=1.2) * np.exp(-k / 0.25)
    parts = [(0, ko, 0.8), (0, crunch, 0.3), (0.02, down, 0.18)]
    for i, (s, f, ln) in enumerate([(0.38, 392.0, 0.25), (0.58, 349.2, 0.25), (0.78, 311.1, 0.25), (0.98, 293.7, 0.9)]):
        m = ns(ln)
        km = np.arange(m) / SR
        sag = 2 ** (-0.9 * np.clip((km - 0.25) / 0.6, 0, 1) / 12) if i == 3 else 1.0
        tone = epiano(f, ln, tau=0.5 if i == 3 else 0.25) * adsr(ln - 0.05, 0.003, 0.3, 0.9, 0.05, n=m)
        pad = lp(tri(f * sag, m), 1500) * adsr(ln - 0.1, 0.02, 0.2, 0.7, 0.1, n=m) * 0.35
        parts.append((s, tone + pad, 0.5, [-0.15, 0.15, -0.1, 0.0][i]))
    parts.append((0.98, lp(tri(146.8, ns(0.9)), 800) * adsr(0.7, 0.03, 0.3, 0.8, 0.2, n=ns(0.9)), 0.25))
    return room(mix(d, parts), 0.22, rt60=1.0)


def click():
    """버튼 — 부드럽고 짧은 나무 '톡'"""
    d = 0.05
    wood = modal(1450, d, [(1, 1, 0.012), (2.57, 0.25, 0.006)])
    body = sine(560, ns(d)) * expdec(ns(d), 0.008)
    tick = hp(noise(ns(d)), 3000) * expdec(ns(d), 0.0012)
    return mix(d, [(0, wood, 1.0), (0, body, 0.35), (0, tick, 0.12)])


def main():
    os.makedirs(OUT, exist_ok=True)
    variants('hit.wav', hit)
    variants('graze.wav', graze)
    variants('throw.wav', throw_)
    variants('kick.wav', kick)
    variants('save.wav', save_)
    variants('coin.wav', coin)
    save('goal.wav', goal(), tail=0.08)
    save('badge.wav', badge(), tail=0.2)
    save('purchase.wav', purchase(), tail=0.15)
    save('equip.wav', equip())
    save('levelup.wav', levelup(), tail=0.12)
    save('newbest.wav', newbest(), tail=0.2)
    save('heartbeat.wav', heartbeat(), tail=0.02)
    save('gameover.wav', gameover(), tail=0.2)
    save('click.wav', click(), tail=0.006)


if __name__ == '__main__':
    main()
