"""존별 배경음악 합성 — assets/audio/bgm_{cyber,dodgeball,keeper}.mp3 (32마디 · 약 1분 · 끊김 없이 반복)
   python scripts/make_bgm.py                 # 셋 다
   python scripts/make_bgm.py keeper          # 하나만
   (numpy · scipy · ffmpeg — scripts/audio_dsp.py)

녹음·외부 음원 없이 코드로 작곡·연주·믹스한다. 원칙(2026-10-13):
  - 처음 들리는 4마디 멜로디(훅)를 곡 내내 반복한다 — 홀수 번째는 열린 끝, 짝수 번째는 닫힌 끝
  - 악기는 처음부터 끝까지 같다. 8마디마다 드럼 밀도·멜로디 옥타브 겹침만 조금 바꾼다
  - 25~28마디는 드럼을 덜어 숨을 고르고, 32마디 끝의 짧은 필로 처음에 다시 붙는다
루프 끝에서 울리던 소리(잔향·긴 음)는 곡 앞에 겹쳐 넣어 이음매가 들리지 않게 한다.
  1 갤럭시   128 BPM D단조 Dm-Bb-F-C — 운석 폭풍 속에서 버티는 작은 우주선: 심장처럼 뛰는 베이스 · 아르페지오 · 신스 리드
  2 피구     116 BPM C장조 C-G-Am-F — 짓궂은 체육관 대결: 놀리는 "솔-미-라-솔-미" 실로폰 · 마림바 · 손뼉 · 공 튀는 "보잉"
  3 골키퍼   124 BPM F장조 F-C-Dm-Bb — 햇살 좋은 경기장: 3+3+2 당김 스틸드럼 · 우쿨렐레 · 수르도 · 셰이커 · 탐보림
"""
import os
import sys
from functools import lru_cache

import numpy as np

from audio_dsp import (SR, adsr, bp, delay, drive, expdec, fade, hp, ks_pluck, limiter, lp, midi_hz, modal, noise, note,
                       ns, pan, pitch_env, place, reverb, rms_db, saw, shelf, sine, square, supersaw, sweep, tri,
                       write_mp3)

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
TAIL = 4.0  # 루프 끝을 넘어 울리는 소리 — 곡 앞에 겹친다
TARGET_RMS = -17.0  # dBFS — 게임에서 0.5 볼륨으로 틀고 효과음이 위에 얹힌다


# ── 시퀀서 ────────────────────────────────────────────────────────────

class Song:
    def __init__(self, bpm, bars, swing=0.0):
        self.spb = 60.0 / bpm
        self.bars = bars
        self.n = ns(bars * 4 * self.spb)
        self.N = self.n + ns(TAIL)
        self.swing = swing  # 짝수 번째 16분음을 16분음의 이 비율만큼 늦춘다(셔플)
        self.buses = {}
        self.kicks = []

    def sec(self, beat):
        q = beat * 4
        if self.swing and abs(q - round(q)) < 1e-6 and int(round(q)) % 2 == 1:
            beat += self.swing / 4
        return beat * self.spb

    def add(self, bus, beat, sig, p=0.0, gain=1.0):
        buf = self.buses.setdefault(bus, np.zeros((self.N, 2)))
        st = sig if sig.ndim == 2 else pan(sig, p)
        place(buf, ns(self.sec(beat)), st, gain)

    def melody(self, bus, text, bar0, bars, inst, p=0.0, gain=1.0, octave=0):
        for beat, ln, m in seq(text, bar0, bars):
            self.add(bus, beat, inst(m + 12 * octave, ln * self.spb), p, gain)

    def mixdown(self, gains, sends, rt60=1.6, delay_bus=None, delay_beats=0.75, delay_fb=0.3, delay_send=0.25,
                duck=None, duck_depth=0.5):
        """버스마다 크기·잔향 보내기 → 합치기 → 루프 꼬리 접기 → 리미터·음량 맞추기"""
        duck_env = np.ones(self.N)
        for b in self.kicks:
            i = ns(self.sec(b))
            k = min(self.N - i, ns(0.35))
            duck_env[i:i + k] = np.minimum(duck_env[i:i + k], 1 - duck_depth * np.exp(-np.arange(k) / SR / 0.09))
        master = np.zeros((self.N, 2))
        send = np.zeros((self.N, 2))
        for name, buf in self.buses.items():
            if duck and name in duck:
                buf = buf * duck_env[:, None]
            master += buf * gains.get(name, 1.0)
            send += buf * sends.get(name, 0.0)
        master += reverb(send, rt60=rt60, predelay=0.02, damp=5500)[:self.N]
        if delay_bus and delay_bus in self.buses:
            master += delay(self.buses[delay_bus] * delay_send, delay_beats * self.spb, fb=delay_fb)[:self.N]
        out = master[:self.n].copy()
        out[:self.N - self.n] += master[self.n:]
        # 휴대폰 스피커 기준 — 깊은 저음은 덜고(어차피 안 나온다) 2kHz 위를 살려 또렷하게
        out = shelf(shelf(hp(out, 35), 110, -3.0, 'low'), 4500, 3.0, 'high')
        out *= 10 ** ((TARGET_RMS - rms_db(out)) / 20)
        return limiter(out, ceiling=0.9)


def seq(text, bar0, bars=None):
    """'D5:4 Bb4:2 r:2 …' (길이 = 16분음 개수) → [(박, 길이(박), MIDI)]. bar0 은 0부터"""
    out, pos = [], 0
    for tok in text.split():
        name, ln = tok.split(':')
        if name != 'r':
            out.append((bar0 * 4 + pos / 4, int(ln) / 4, note(name)))
        pos += int(ln)
    if bars is not None:
        assert pos == 16 * bars, f'{text!r}: 16분음 {pos}개 — {16 * bars}개여야 한다'
    return out


QUAL = {'': [0, 4, 7], 'm': [0, 3, 7], '7': [0, 4, 7, 10], 'm7': [0, 3, 7, 10], 'sus': [0, 5, 7]}


def chord(sym, octave=3):
    """'Dm' · 'Bb' · 'C7' → (근음 MIDI, 구성음 MIDI 목록)"""
    k = 2 if len(sym) > 1 and sym[1] in '#b' else 1
    root = note(sym[:k] + str(octave))
    return root, [root + i for i in QUAL[sym[k:]]]


def hz(m):
    return midi_hz(m)


def hooks(first, open_end, closed_end, bars):
    """4마디 훅을 bars 마디 동안 — [(시작 마디, 멜로디)] (홀수 번째 열린 끝 · 짝수 번째 닫힌 끝)"""
    return [(b, first + (open_end if (b // 4) % 2 == 0 else closed_end)) for b in range(0, bars, 4)]


# ── 공용 타악기 ───────────────────────────────────────────────────────

@lru_cache(None)
def kick(punch=1.0, f0=170.0, f1=48.0, tau=0.24):
    n = ns(0.45)
    body = sine(pitch_env(f0, f1, 0.035, n), n) * expdec(n, tau)
    click = hp(noise(ns(0.004)), 2500) * 0.5 * punch
    out = body.copy()
    out[:len(click)] += click
    return drive(fade(out, 0.0005, 0.02), 1.2 + punch * 0.6)


@lru_cache(None)
def snare_synth():
    n = ns(0.3)
    body = (sine(pitch_env(240, 185, 0.02, n), n) + 0.5 * sine(330, n)) * expdec(n, 0.05)
    nz = bp(noise(n), 1500, 9000) * expdec(n, 0.1)
    return fade(body * 0.7 + nz, 0.0005, 0.02)


@lru_cache(None)
def clap():
    n = ns(0.25)
    out = np.zeros(n)
    for d in (0.0, 0.009, 0.018):
        i = ns(d)
        k = n - i
        out[i:] += bp(noise(k), 900, 2600) * expdec(k, 0.006)
    out += bp(noise(n), 900, 3000) * expdec(n, 0.07) * 0.6
    return fade(out, 0.0005, 0.02)


@lru_cache(None)
def hat(open_=False):
    n = ns(0.45 if open_ else 0.08)
    metal = sum(square(f, n, 0.5) for f in (205.3, 304.4, 369.6, 522.7, 540.0, 800.0))
    s = hp(bp(metal, 6500, 14000) + 0.6 * noise(n), 7000)
    return fade(s * expdec(n, 0.16 if open_ else 0.018), 0.0003, 0.01)


@lru_cache(None)
def crash():
    n = ns(2.2)
    metal = sum(square(f, n, 0.5) for f in (305.0, 437.0, 571.0, 763.0, 919.0, 1170.0))
    s = lp(hp(bp(metal, 3500, 13000) * 0.5 + noise(n), 3500), 12000)
    return fade(s * expdec(n, 0.7), 0.001, 0.05)


@lru_cache(None)
def shaker():
    n = ns(0.09)
    k = np.arange(n) / SR
    return bp(noise(n), 4500, 11000) * np.minimum(1, k / 0.012) * expdec(n, 0.03)


# ── 1 갤럭시 ─────────────────────────────────────────────────────────

@lru_cache(None)
def g_bass(m, dur):
    f = hz(m)
    n = ns(dur + 0.05)
    k = np.arange(n) / SR
    s = saw(f, n) * 0.7 + square(f / 2, n, 0.5) * 0.45
    s = sweep(s, 260 + 1500 * np.exp(-k / 0.06), q=1.1)
    return drive(s * adsr(dur, 0.003, 0.08, 0.55, 0.05, n=n), 1.6)


@lru_cache(None)
def g_arp(m, bright=1.0):
    f = hz(m)
    n = ns(0.26)
    k = np.arange(n) / SR
    s = square(f, n, 0.3) * 0.6 + saw(f * 1.005, n) * 0.4
    return fade(sweep(s, 600 + 3800 * bright * np.exp(-k / 0.06), q=1.3) * expdec(n, 0.11), 0.002, 0.03)


@lru_cache(None)
def g_lead(m, dur):
    f = hz(m)
    n = ns(dur + 0.2)
    k = np.arange(n) / SR
    vib = 2 ** (0.16 * np.sin(2 * np.pi * 5.3 * k) * np.clip((k - 0.18) / 0.25, 0, 1) / 12)
    fr = f * vib
    s = saw(fr * 1.0035, n) + saw(fr * 0.9965, n) + 0.35 * square(fr / 2, n, 0.5)
    cut = 1700 + 2300 * np.exp(-k / 0.12) + 500 * np.clip(k / 0.6, 0, 1)
    s = sweep(s, cut, q=0.9) * adsr(dur, 0.012, 0.25, 0.7, 0.18, n=n)
    return drive(s * 0.5, 1.3)


@lru_cache(None)
def g_pad(sym, dur):
    _, notes = chord(sym, 3)
    notes = notes + [notes[0] + 12]
    n = ns(dur + 0.9)
    out = sum(supersaw(hz(m), dur + 0.9, voices=5, spread=0.14, seed=m) for m in notes) / len(notes)
    out = lp(out, 2300)
    return out * adsr(dur, 0.35, 0.6, 0.8, 0.9, n=n)[:, None]


def galaxy():
    s = Song(128, 32)
    prog = ['Dm', 'Bb', 'F', 'C'] * 8
    for bar, sym in enumerate(prog):
        b0 = bar * 4
        root, tones = chord(sym, 3)
        part = bar // 8  # 0 시작 · 1 hat 16분 · 2 멜로디 옥타브 겹침 · 3 숨 고르기 → 다시
        calm = 24 <= bar < 28

        # 드럼 — 킥은 계속 뛴다(숨 고르기에서는 반박만)
        for q in ((0, 2) if calm else (0, 1, 2, 3)):
            s.add('drums', b0 + q, kick(), 0, 1.0)
            s.kicks.append(b0 + q)
        if not calm:
            for q in (1, 3):
                s.add('drums', b0 + q, snare_synth(), 0, 0.55)
                s.add('drums', b0 + q, clap(), 0.1, 0.35)
        if part in (1, 2) or bar >= 28:
            for i in range(16):
                s.add('cym', b0 + i / 4, hat(), 0.3, 0.3 if i % 2 else 0.14)
            if part in (1, 2):
                s.add('cym', b0 + 3.5, hat(True), -0.3, 0.16)
        else:
            for q in range(4):
                s.add('cym', b0 + q + 0.5, hat(), 0.3, 0.32)
        if bar == 31:  # 처음으로 다시 붙는 짧은 스네어 필
            for i in range(4):
                s.add('drums', b0 + 3 + i / 4, snare_synth(), 0, 0.3 + 0.12 * i)
        if bar in (0, 16):
            s.add('cym', b0, crash(), 0.25, 0.3)

        # 베이스 — 쉬지 않는 8분음(심장 박동)
        for i in range(8):
            m = root - 12 + (12 if i == 7 else 0)
            s.add('bass', b0 + i / 2, g_bass(m, s.spb / 2 - 0.03), 0, 1.0 if i % 2 == 0 else 0.8)

        # 아르페지오 — 16분음, 화음 안을 오르내린다
        ar = [tones[0] + 12, tones[1] + 12, tones[2] + 12, tones[0] + 24, tones[1] + 24]
        pat = [0, 1, 2, 3, 1, 2, 3, 4, 2, 3, 4, 3, 2, 1, 2, 3]
        for i, pi in enumerate(pat):
            s.add('arp', b0 + i / 4, g_arp(ar[pi], 1.0), -0.35, (0.45 if calm else 0.5) * (1.0 if i % 4 == 0 else 0.7))

        s.add('pad', b0, g_pad(sym, 4 * s.spb), 0, 0.9 if calm else 0.7)

    # 멜로디 — 처음 4마디를 계속 되풀이한다(17~24마디는 한 옥타브 위를 살짝 겹쳐 힘을 더한다)
    first = ('D5:3 D5:1 F5:2 A5:2 r:2 G5:2 F5:2 E5:2 '
             'D5:6 r:2 Bb4:2 C5:2 D5:4 '
             'C5:3 C5:1 F5:2 A5:2 r:2 C6:2 Bb5:2 A5:2 ')
    for bar0, text in hooks(first, 'G5:8 E5:4 C5:4', 'G5:6 A5:2 G5:4 E5:4', 32):
        s.melody('lead', text, bar0, 4, g_lead, 0.1, 0.62)
        if 16 <= bar0 < 24:
            s.melody('lead', text, bar0, 4, g_lead, -0.1, 0.2, octave=1)

    return s.mixdown(
        gains={'drums': 0.5, 'cym': 0.75, 'bass': 0.35, 'arp': 0.5, 'pad': 0.75, 'lead': 0.75},
        sends={'drums': 0.04, 'cym': 0.08, 'arp': 0.3, 'pad': 0.35, 'lead': 0.32},
        rt60=2.2, delay_bus='lead', delay_beats=0.75, delay_fb=0.3, delay_send=0.25,
        duck={'bass', 'pad', 'arp'}, duck_depth=0.55)


# ── 2 피구 ───────────────────────────────────────────────────────────

@lru_cache(None)
def xylo(m, dur=0.0):
    return modal(hz(m), 0.6, [(1, 1.0, 0.22), (3.0, 0.35, 0.06), (6.0, 0.12, 0.025)], mallet=0.4, mallet_f=5000)


@lru_cache(None)
def marimba(m):
    return modal(hz(m), 1.0, [(1, 1.0, 0.45), (4.0, 0.22, 0.09), (9.9, 0.05, 0.02)], mallet=0.25, mallet_f=2500)


@lru_cache(None)
def d_bass(m, dur):
    f = hz(m)
    n = ns(dur + 0.06)
    k = np.arange(n) / SR
    fr = f * 2 ** (np.exp(-k / 0.012) * 1.0 / 12)  # 처음에 살짝 위에서 떨어지는 "통"
    s = sine(fr, n) + 0.35 * tri(fr * 2, n) + 0.15 * saw(fr, n)
    return lp(s, 1400) * adsr(dur, 0.003, 0.1, 0.45, 0.05, n=n)


@lru_cache(None)
def boing(f0, f1):
    """공이 바닥에 튀는 "보잉" — 음이 크게 떨어지는 탐 + 살짝 흔들림"""
    n = ns(0.35)
    k = np.arange(n) / SR
    fr = pitch_env(f0, f1, 0.06, n) * (1 + 0.02 * np.sin(2 * np.pi * 18 * k))
    return fade((sine(fr, n) + 0.3 * tri(fr * 2, n)) * expdec(n, 0.11), 0.001, 0.03)


def dodgeball():
    s = Song(116, 32, swing=0.2)
    prog = ['C', 'G', 'Am', 'F'] * 8
    for bar, sym in enumerate(prog):
        b0 = bar * 4
        root, tones = chord(sym, 3)
        if root >= note('A3'):
            root -= 12
            tones = [t - 12 for t in tones]
        part = bar // 8
        calm = 24 <= bar < 28

        # 드럼 — 킥 · 손뼉 · 셰이커는 처음부터 끝까지
        for i in ((0,) if calm else (0, 8, 10) if part in (1, 2) else (0, 8)):
            s.add('drums', b0 + i / 4, kick(0.5, 140, 52, 0.18), 0, 0.85)
            s.kicks.append(b0 + i / 4)
        for i in (4, 12):
            s.add('drums', b0 + i / 4, clap(), 0, 0.62)
        for i in range(2, 16, 2) if part in (1, 2) else range(2, 16, 4):
            s.add('perc', b0 + i / 4, shaker(), 0.4, 0.3 if i % 4 == 2 else 0.18)
        if bar % 4 == 3:  # 훅 끝 — 공이 "보잉 보잉"
            s.add('perc', b0 + 3, boing(420, 170), -0.3, 0.55)
            s.add('perc', b0 + 3.5, boing(340, 130), 0.3, 0.5)

        # 베이스 — 통통 튀는 근음·5도
        for i, m, ln in ((0, root - 12, 0.4), (6, root - 12, 0.3), (8, root - 5, 0.4), (14, root, 0.3)):
            s.add('bass', b0 + i / 4, d_bass(m, ln * s.spb), 0, 0.9)

        # 마림바 — 뒷박 화음
        for i in (2, 6, 10, 14):
            for m in tones:
                s.add('keys', b0 + i / 4, marimba(m + 12), -0.2, 0.15 if calm else 0.18)

    # 멜로디 — 놀리는 "솔-미-라-솔-미"를 실로폰이 계속 되풀이(17~24마디는 한 옥타브 위를 살짝 겹침)
    first = ('G5:2 r:2 E5:2 G5:2 A5:2 G5:2 E5:4 '
             'G5:2 r:2 D5:2 G5:2 A5:2 G5:2 D5:4 '
             'C6:2 B5:2 A5:2 G5:2 E5:2 G5:2 A5:4 ')
    for bar0, text in hooks(first, 'F5:2 E5:2 D5:2 C5:2 D5:4 r:4', 'F5:2 E5:2 D5:2 B4:2 C5:4 r:4', 32):
        s.melody('lead', text, bar0, 4, xylo, 0.15, 0.7)
        if 16 <= bar0 < 24:
            s.melody('lead', text, bar0, 4, xylo, -0.15, 0.22, octave=1)

    return s.mixdown(
        gains={'drums': 0.6, 'perc': 1.9, 'bass': 0.5, 'keys': 0.6, 'lead': 0.85},
        sends={'drums': 0.05, 'perc': 0.12, 'keys': 0.2, 'lead': 0.22},
        rt60=1.1, duck={'bass'}, duck_depth=0.25)


# ── 3 골키퍼 ─────────────────────────────────────────────────────────

@lru_cache(None)
def steel(m, dur):
    """스틸드럼 — 옥타브·12도 배음이 맞춰진 둥근 금속 + 처음에 살짝 높은 음에서 내려앉는다"""
    f = hz(m)
    n = ns(min(dur, 0.8) + 0.5)
    k = np.arange(n) / SR
    bend = 2 ** (0.35 * np.exp(-k / 0.015) / 12)
    out = np.zeros(n)
    for mult, amp, tau in ((1, 1.0, 0.45), (2.0, 0.55, 0.25), (3.0, 0.22, 0.12), (4.03, 0.1, 0.06)):
        ph = np.cumsum(f * mult * bend) / SR
        out += amp * np.sin(2 * np.pi * ph) * np.exp(-k / tau)
    out += lp(noise(n), 3000) * expdec(n, 0.003) * 0.3
    out *= np.minimum(1, k / 0.002)
    return fade(out, 0.0, 0.04)


@lru_cache(None)
def uke(notes, down=True):
    """우쿨렐레 스트럼 — 줄마다 15ms 씩 어긋나게"""
    order = notes if down else notes[::-1]
    n = ns(0.9)
    out = np.zeros(n)
    for i, m in enumerate(order):
        s = ks_pluck(hz(m), 0.85, bright=0.55, decay=0.995, seed=m + i)
        place(out, ns(i * 0.015), s, 0.8 if i else 1.0)
    return bp(out, 200, 6000) / len(notes)


@lru_cache(None)
def surdo(open_=True):
    n = ns(0.6 if open_ else 0.15)
    body = sine(pitch_env(95, 62, 0.04, n), n) * expdec(n, 0.3 if open_ else 0.05)
    harm = sine(pitch_env(190, 124, 0.04, n), n) * expdec(n, 0.08) * 0.4  # 휴대폰 스피커에서도 들리게
    mallet = lp(noise(n), 900) * expdec(n, 0.006) * 0.5
    return fade(body + harm + mallet, 0.0005, 0.03)


@lru_cache(None)
def tamborim():
    n = ns(0.1)
    return fade(sine(pitch_env(820, 700, 0.01, n), n) * expdec(n, 0.02) + bp(noise(n), 2000, 7000) * expdec(n, 0.012),
                0.0003, 0.01)


@lru_cache(None)
def k_bass(m, dur):
    f = hz(m)
    n = ns(dur + 0.05)
    k = np.arange(n) / SR
    s = sine(f, n) + 0.4 * saw(f, n)
    s = sweep(s, 350 + 1200 * np.exp(-k / 0.05), q=0.9)
    return s * adsr(dur, 0.004, 0.12, 0.5, 0.05, n=n)


def keeper():
    s = Song(124, 32)
    prog = ['F', 'C', 'Dm', 'Bb'] * 8
    for bar, sym in enumerate(prog):
        b0 = bar * 4
        root, tones = chord(sym, 3)
        if root >= note('A3'):
            root -= 12
            tones = [t - 12 for t in tones]
        part = bar // 8
        calm = 24 <= bar < 28

        # 삼바 타악기 — 수르도 · 셰이커 · 탐보림은 처음부터 끝까지
        for i, op, g in ((0, False, 0.45), (4, True, 0.9), (8, False, 0.45), (12, True, 0.9)):
            s.add('perc', b0 + i / 4, surdo(op), 0, g)
        for i in range(16):
            s.add('perc', b0 + i / 4, shaker(), 0.45, 0.4 if i % 4 == 3 else 0.17)
        tam = (0, 3, 6, 8, 10, 13) if part in (1, 2) else (0, 3, 6, 8)
        if not calm:
            for i in tam:
                s.add('perc', b0 + i / 4, tamborim(), -0.45, 0.32 if i in (0, 8) else 0.22)
            for i in (0, 8):
                s.add('drums', b0 + i / 4, kick(0.4, 130, 50, 0.16), 0, 0.6)
                s.kicks.append(b0 + i / 4)
        if bar == 31:  # 처음으로 다시 붙는 탐보림 연타
            for i in range(12, 16):
                s.add('perc', b0 + i / 4 + 0.125, tamborim(), -0.45, 0.25 + 0.05 * (i - 12))

        # 베이스 — 삼바: 근음 · 5도 당김
        for i, m, ln in ((0, root - 12, 0.6), (6, root - 5, 0.35), (8, root - 12, 0.6), (14, root - 5, 0.3)):
            s.add('bass', b0 + i / 4, k_bass(m, ln * s.spb), 0, 0.95)

        # 우쿨렐레
        voicing = tuple(sorted({t + 12 for t in tones} | {tones[0] + 24}))
        for i, down, g in ((0, True, 0.75), (3, False, 0.4), (6, True, 0.6), (10, False, 0.45), (12, True, 0.6)):
            s.add('uke', b0 + i / 4, uke(voicing, down), 0.3, g * (0.8 if calm else 1.0))

    # 멜로디 — 3+3+2 당김(삼바) 스틸드럼 훅을 계속 되풀이(17~24마디는 한 옥타브 아래를 살짝 겹쳐 두툼하게)
    first = ('C6:3 A5:3 F5:2 G5:3 A5:3 C6:2 '
             'E5:3 G5:3 C6:2 Bb5:3 A5:3 G5:2 '
             'F5:3 A5:3 D6:2 C6:3 A5:3 F5:2 ')
    for bar0, text in hooks(first, 'D5:3 F5:3 Bb5:2 A5:4 G5:4', 'D5:3 F5:3 A5:2 G5:4 F5:4', 32):
        s.melody('lead', text, bar0, 4, steel, -0.1, 0.6)
        if 16 <= bar0 < 24:
            s.melody('lead', text, bar0, 4, steel, 0.15, 0.25, octave=-1)

    return s.mixdown(
        gains={'drums': 0.85, 'perc': 0.65, 'bass': 0.65, 'uke': 2.0, 'lead': 0.62},
        sends={'drums': 0.05, 'perc': 0.1, 'uke': 0.15, 'lead': 0.25},
        rt60=1.3, delay_bus='lead', delay_beats=0.75, delay_fb=0.22, delay_send=0.12,
        duck={'bass'}, duck_depth=0.2)


SONGS = {'cyber': galaxy, 'dodgeball': dodgeball, 'keeper': keeper}


def main():
    names = sys.argv[1:] or list(SONGS)
    os.makedirs(OUT, exist_ok=True)
    for name in names:
        x = SONGS[name]()
        path = os.path.join(OUT, f'bgm_{name}.mp3')
        write_mp3(path, x)
        print(f'bgm_{name}.mp3  {len(x) / SR:.1f}s  rms {rms_db(x):.1f}dB  peak {np.max(np.abs(x)):.2f}  '
              f'{os.path.getsize(path) / 1024:.0f}KB')


if __name__ == '__main__':
    main()
