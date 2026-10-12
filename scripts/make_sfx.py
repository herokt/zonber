"""효과음 합성 — assets/audio/*.wav (44.1kHz · 16bit · 모노). 녹음·외부 음원 없이 코드로 만든다.
   python scripts/make_sfx.py            (numpy · scipy — scripts/audio_dsp.py)
소리마다 몸통(낮은 울림) · 어택(짧은 딱) · 질감(노이즈·배음)을 겹치고 작은 방 잔향을 살짝 입힌다.
소리를 바꾸려면 여기 수치를 고치고 다시 돌린다. 이벤트 연결은 lib/audio_manager.dart(Sfx) 참고.
"""
import os

import numpy as np

from audio_dsp import (SR, adsr, bp, drive, expdec, fade, fm, hp, lp, noise, ns, pitch_env, reverb, saw, sine, square,
                       sweep, tri, write_wav)

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')


def mix(total, parts):
    """(시작 초, 신호, 크기) 목록을 한 트랙으로"""
    out = np.zeros(ns(total))
    for start, sig, g in parts:
        i = ns(start)
        k = min(len(sig), len(out) - i)
        out[i:i + k] += sig[:k] * g
    return out


def room(x, wet=0.12, rt60=0.35, damp=7000.0):
    """작은 방 잔향을 입히고 원래 길이로 자른다(꼬리는 페이드)"""
    w = reverb(x, rt60=rt60, predelay=0.004, damp=damp, hp_in=180).mean(1)
    return fade(x + wet * w[:len(x)], 0.0, 0.02)


def save(name, sig, peak=0.85):
    sig = fade(sig - np.mean(sig), 0.0005, 0.008)
    write_wav(os.path.join(OUT, name), sig, peak)
    print(f'{name:14s} {len(sig) / SR:.2f}s')


def bell(freq, dur, tau=0.3, bright=1.0):
    """맑은 종 — FM 두 겹(기본 + 높은 반짝임)"""
    a = fm(freq, dur, ratio=3.5, index=0.9 * bright, index_tau=0.025, amp_tau=tau)
    b = fm(freq * 2, dur, ratio=1.41, index=0.4 * bright, index_tau=0.02, amp_tau=tau * 0.5)
    return lp(a + 0.25 * b, 9000)


def brass(freq, dur, vib=False):
    """짧은 신스 브라스 — 톱니 두 개 + 필터가 열렸다 닫힌다"""
    n = ns(dur)
    k = np.arange(n) / SR
    f = np.full(n, freq)
    if vib:
        f = f * 2 ** (0.18 * np.sin(2 * np.pi * 5.5 * k) * np.clip((k - 0.12) / 0.2, 0, 1) / 12)
    s = saw(f * 1.003, n) + saw(f * 0.997, n) + 0.4 * square(f / 2, n)
    cut = 900 + 4200 * np.clip(k / 0.04, 0, 1) * np.exp(-k / 0.25) + 1400
    return sweep(s, cut, q=0.9) * adsr(dur - 0.06, 0.012, 0.15, 0.75, 0.06, n=n)


def main():
    os.makedirs(OUT, exist_ok=True)

    # 피격 — 묵직한 "퍽" + 지글거리는 충격 + 아래로 떨어지는 짧은 전자음
    d = 0.38
    n = ns(d)
    thump = sine(pitch_env(230, 52, 0.035, n), n) * expdec(n, 0.09)
    crunch = drive(bp(noise(n), 280, 3200) * expdec(n, 0.03) * 3, 2.5)
    zap = lp(square(pitch_env(1100, 180, 0.05, n), n, 0.3), 3500) * expdec(n, 0.06)
    save('hit.wav', room(mix(d, [(0, thump, 1.0), (0, crunch, 0.45), (0.004, zap, 0.22)]), 0.1), 0.9)

    # 게임 오버 — 낮은 쿵 + 내려가는 세 음 "빠-바-밤"(마지막은 늘어지며 음이 처진다)
    d = 1.7
    boom = sine(pitch_env(95, 42, 0.12, ns(0.7)), ns(0.7)) * expdec(ns(0.7), 0.22)
    def wah(f, ln, sag=0.0):
        m = ns(ln)
        k = np.arange(m) / SR
        fr = f * 2 ** ((-sag * np.clip((k - 0.15) / (ln - 0.15), 0, 1)) / 12) * 2 ** (0.12 * np.sin(2 * np.pi * 5 * k) / 12)
        s = square(fr, m, 0.4) * 0.6 + saw(fr, m) * 0.4
        cut = 500 + 2200 * np.exp(-k / 0.18) + 600 * (0.5 + 0.5 * np.sin(2 * np.pi * 2.5 * k))
        return sweep(s, cut, q=2.2, kind='bp') * adsr(ln - 0.08, 0.01, 0.2, 0.8, 0.08, n=m)
    notes = [(0.05, 392.0, 0.2), (0.3, 349.2, 0.2), (0.55, 311.1, 0.2), (0.8, 293.7, 0.8)]
    parts = [(0, boom, 0.7)] + [(st, wah(f, ln, sag=1.2 if i == 3 else 0), 0.55) for i, (st, f, ln) in enumerate(notes)]
    save('gameover.wav', room(mix(d, parts), 0.22, rt60=0.9), 0.8)

    # 피구 던지기 — 공이 지나가는 바람(대역이 올라갔다 내려감) + 낮은 "훅"
    d = 0.34
    n = ns(d)
    k = np.arange(n) / SR
    center = 500 + 2400 * np.sin(np.pi * np.clip(k / d, 0, 1)) ** 2
    whoosh = sweep(noise(n), center, q=1.4, kind='bp') * np.sin(np.pi * np.clip(k / d, 0, 1)) ** 1.6
    fwoop = sine(pitch_env(210, 120, 0.1, n), n) * np.sin(np.pi * np.clip(k / d, 0, 1)) ** 2
    save('throw.wav', mix(d, [(0, whoosh, 1.0), (0, fwoop, 0.25)]), 0.6)

    # 골키퍼 킥 — 가죽 공 "뻥": 낮은 몸통 + 가죽 찰싹 + 짧은 "퐁"
    d = 0.3
    n = ns(d)
    body = sine(pitch_env(150, 55, 0.03, n), n) * expdec(n, 0.07)
    slap = bp(noise(n), 900, 4500) * expdec(n, 0.007)
    pock = sine(430, n) * expdec(n, 0.02)
    save('kick.wav', room(mix(d, [(0, body, 1.0), (0, slap, 0.8), (0.001, pock, 0.3)]), 0.06), 0.9)

    # 선방 — 장갑 "팡"(두툼한 손바닥 + 짧은 몸통) + 기분 좋은 작은 차임
    d = 0.5
    n = ns(d)
    glove = bp(noise(n), 350, 2600) * expdec(n, 0.016)
    palm = sine(pitch_env(190, 140, 0.03, n), n) * expdec(n, 0.05)
    chime = bell(1318.5, 0.4, tau=0.12, bright=0.6)
    save('save.wav', room(mix(d, [(0, drive(glove * 2, 1.5), 0.9), (0, palm, 0.6), (0.035, chime, 0.16)]), 0.1), 0.85)

    # 실점 — 공이 그물에 "철썩" + 그물 출렁임 + 심판 호루라기(떨리는 두 음 + 숨)
    d = 1.2
    n = ns(0.7)
    k = np.arange(n) / SR
    ripple = 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 9 * k + 2 * np.sin(2 * np.pi * 3 * k)))
    net = lp(hp(noise(n), 1400), 7500) * expdec(n, 0.22) * ripple
    impact = sine(pitch_env(120, 70, 0.04, ns(0.2)), ns(0.2)) * expdec(ns(0.2), 0.05)
    m = ns(0.55)
    km = np.arange(m) / SR
    trill = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 26 * km))
    tone = (sine(2980, m) + 0.6 * sine(3060, m) + 0.15 * sine(5960, m)) * lp(trill, 300)
    breath = bp(noise(m), 2400, 4200) * 0.25
    whistle = (tone + breath) * adsr(0.49, 0.015, 0.1, 0.9, 0.06, n=m)
    save('goal.wav', room(mix(d, [(0, net, 0.8), (0, impact, 0.5), (0.3, whistle, 0.42)]), 0.14, rt60=0.6), 0.8)

    # 추가 기록(아슬하게 피함) — 작고 맑은 "팅"(자주 나니까 귀가 따갑지 않게 G6 + 살짝 위 D7)
    d = 0.3
    save('graze.wav', room(mix(d, [(0, bell(1568.0, d, tau=0.07), 1.0), (0.012, bell(2349.3, d, tau=0.04, bright=0.5), 0.3)]), 0.12), 0.45)

    # 코인 — 두 음 "띠링"(B5 → E6): 부드러운 사각파 + 종소리
    d = 0.55
    def coin_note(f, ln, tau):
        m = ns(ln)
        sq = lp(square(f, m, 0.5), 5000) * expdec(m, tau * 0.6)
        return sq * 0.35 + bell(f, ln, tau)
    save('coin.wav', room(mix(d, [(0, coin_note(987.8, 0.12, 0.05), 0.8), (0.075, coin_note(1318.5, 0.45, 0.14), 1.0)]), 0.12), 0.7)

    # 뱃지 — 올라가는 종 아르페지오(C6 E6 G6 C7) + 밑에 깔리는 따뜻한 화음 + 반짝 노이즈
    d = 1.6
    arp = [(i * 0.065, bell(f, 1.2 - i * 0.1, tau=0.35), 0.8) for i, f in enumerate([1046.5, 1318.5, 1568.0, 2093.0])]
    padn = ns(1.3)
    pad = sum(tri(f, padn) for f in (523.3, 659.3, 784.0)) * adsr(0.7, 0.12, 0.3, 0.8, 0.6, n=padn)
    shimmer = lp(hp(noise(ns(0.9)), 6000), 11000) * adsr(0.4, 0.15, 0.2, 0.5, 0.5, n=ns(0.9))
    save('badge.wav', room(mix(d, arp + [(0.15, pad, 0.18), (0.2, shimmer, 0.05)]), 0.3, rt60=1.0), 0.75)

    # 구매 — 동전 쏟아지는 소리 + "차-링" 종 화음 + 반짝
    d = 1.0
    r = np.random.default_rng(11)
    rattle = [(r.uniform(0, 0.16), bell(r.uniform(1800, 3600), 0.08, tau=0.02, bright=0.7), r.uniform(0.15, 0.3)) for _ in range(14)]
    ching = [(0.17, bell(1568.0, 0.8, tau=0.3), 0.7), (0.17, bell(1975.5, 0.8, tau=0.28), 0.55), (0.19, bell(2637.0, 0.7, tau=0.22), 0.4)]
    sparkle = [(0.3 + i * 0.05, bell(f, 0.3, tau=0.08, bright=0.5), 0.15) for i, f in enumerate([2637.0, 3136.0, 3520.0])]
    save('purchase.wav', room(mix(d, rattle + ching + sparkle), 0.2, rt60=0.8), 0.75)

    # 장착 — 동그란 "뽁"(위로 튀는 물방울) + 아주 짧은 딸깍
    d = 0.16
    n = ns(d)
    pop = sine(380 + 1100 * (1 - expdec(n, 0.025)), n) * expdec(n, 0.03)
    tick = bp(noise(ns(0.006)), 2000, 7000) * expdec(ns(0.006), 0.0015)
    save('equip.wav', mix(d, [(0, fade(pop, 0.002, 0.01), 1.0), (0, tick, 0.3)]), 0.6)

    # 레벨업 — 빠르게 올라가는 아르페지오(C5→G6) + 위로 쓸리는 바람 + 마지막 반짝
    d = 0.9
    steps = [523.3, 659.3, 784.0, 1046.5, 1318.5, 1568.0]
    def pluck(f, ln):
        m = ns(ln)
        k = np.arange(m) / SR
        s = square(f, m, 0.35) * 0.6 + saw(f * 1.004, m) * 0.4
        return sweep(s, 1200 + 5000 * np.exp(-k / 0.05), q=1.0) * expdec(m, 0.09)
    arp = [(i * 0.045, pluck(f, 0.22), 0.5) for i, f in enumerate(steps)]
    m = ns(0.35)
    rise = sweep(noise(m), 800 + 6000 * (np.arange(m) / m) ** 1.5, q=1.2, kind='bp') * np.sin(np.pi * np.arange(m) / m)
    save('levelup.wav', room(mix(d, arp + [(0.0, rise, 0.25), (0.28, bell(2093.0, 0.5, tau=0.15), 0.35)]), 0.18, rt60=0.7), 0.6)

    # 신기록 — 짧은 브라스 팡파르(G5 C6 E6 → G6 길게) + 받쳐 주는 화음 + 팀파니 + 심벌 부풂
    d = 1.7
    fan = [(0.0, 784.0, 0.11), (0.1, 1046.5, 0.11), (0.2, 1318.5, 0.11)]
    parts = [(st, brass(f, ln + 0.06), 0.5) for st, f, ln in fan]
    parts.append((0.3, brass(1568.0, 1.05, vib=True), 0.55))
    parts += [(0.3, brass(f, 1.0), 0.18) for f in (523.3, 659.3, 784.0)]
    tm = ns(0.8)
    timp = sine(pitch_env(115, 98, 0.05, tm), tm) * expdec(tm, 0.3) + lp(noise(tm), 500) * expdec(tm, 0.03) * 0.5
    cym = lp(hp(noise(ns(1.2)), 5500), 12000) * expdec(ns(1.2), 0.45)
    parts += [(0.3, timp, 0.6), (0.3, cym, 0.12)]
    save('newbest.wav', room(mix(d, parts), 0.25, rt60=1.0), 0.75)

    # 위기 — 심장박동 "쿵-쿵"(0.8초 반복 — 끝은 조용해야 이음매가 안 들린다)
    d = 0.8
    def beat(f0, f1, g):
        m = ns(0.2)
        s = sine(pitch_env(f0, f1, 0.04, m), m) * expdec(m, 0.055)
        return (s + lp(noise(m), 180) * expdec(m, 0.02) * 0.6) * g
    save('heartbeat.wav', mix(d, [(0.0, beat(78, 40, 1.0), 1.0), (0.19, beat(88, 46, 0.75), 1.0)]), 0.8)

    # 버튼 — 부드럽고 짧은 "톡"
    d = 0.05
    n = ns(d)
    tap = sine(1750, n) * expdec(n, 0.006) + sine(620, n) * expdec(n, 0.01) * 0.5
    tick = bp(noise(n), 2500, 8000) * expdec(n, 0.0015) * 0.4
    save('click.wav', tap + tick, 0.4)


if __name__ == '__main__':
    main()
