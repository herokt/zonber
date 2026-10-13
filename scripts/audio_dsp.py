"""오디오 합성 공용 도구 — scripts/make_sfx.py(효과음) · scripts/make_bgm.py(존별 배경음악)가 쓴다.
   pip install numpy scipy imageio-ffmpeg   (mp3 는 ffmpeg — FFMPEG 환경변수 → PATH → imageio-ffmpeg)
녹음·외부 음원 없이 코드로만 만든다. 신호는 float(-1~1), 모노는 (n,), 스테레오는 (n, 2).
"""
import os
import shutil
import subprocess
import sys
import tempfile
import wave
from functools import lru_cache

import numpy as np
from scipy import signal
from scipy.ndimage import maximum_filter1d, uniform_filter1d

SR = 44100
rng = np.random.default_rng(7)


def ns(sec):
    return max(0, int(round(sec * SR)))


def tt(sec):
    return np.arange(ns(sec)) / SR


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


_NOTE = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def note(name):
    """'C4' · 'F#5' · 'Bb3' → MIDI 번호"""
    base = _NOTE[name[0]]
    i = 1
    while i < len(name) and name[i] in '#b':
        base += 1 if name[i] == '#' else -1
        i += 1
    return base + 12 * (int(name[i:]) + 1)


# ── 오실레이터 ─────────────────────────────────────────────────────────

def _freq(freq, n):
    return np.full(n, float(freq)) if np.ndim(freq) == 0 else np.asarray(freq, float)[:n]


def _phase(freq, n, ph0=0.0):
    f = _freq(freq, n)
    return (ph0 + np.concatenate([[0.0], np.cumsum(f[:-1])]) / SR) % 1.0, f / SR


def _blep(ph, dt):
    out = np.zeros_like(ph)
    a = ph < dt
    x = ph[a] / dt[a]
    out[a] = x + x - x * x - 1
    b = ph > 1 - dt
    x = (ph[b] - 1) / dt[b]
    out[b] = x * x + x + x + 1
    return out


def sine(freq, n, ph0=0.0):
    ph, _ = _phase(freq, n, ph0)
    return np.sin(2 * np.pi * ph)


def saw(freq, n, ph0=0.0):
    """에일리어싱을 줄인(polyBLEP) 톱니파"""
    ph, dt = _phase(freq, n, ph0)
    return 2 * ph - 1 - _blep(ph, dt)


def square(freq, n, pw=0.5, ph0=0.0):
    ph, dt = _phase(freq, n, ph0)
    sq = np.where(ph < pw, 1.0, -1.0)
    return sq + _blep(ph, dt) - _blep((ph + 1 - pw) % 1.0, dt)


def tri(freq, n, ph0=0.0):
    ph, _ = _phase(freq, n, ph0)
    return 2 * np.abs(2 * ph - 1) - 1


def noise(n):
    return rng.uniform(-1, 1, n)


# ── 엔벨로프 ───────────────────────────────────────────────────────────

def expdec(n, tau):
    return np.exp(-np.arange(n) / SR / tau)


def adsr(dur, a=0.005, d=0.1, s=0.7, r=0.1, n=None):
    """dur 동안 누르고(a·d·s) 뗀 뒤 r 만큼 줄어든다. 길이 = dur + r (n 을 주면 그 길이로 자르거나 0 으로 채운다)"""
    if n is not None:
        env = adsr(dur, a, d, s, r)
        return env[:n] if len(env) >= n else np.r_[env, np.zeros(n - len(env))]
    n, nr = ns(dur), ns(r)
    na = max(1, min(ns(a), n))
    env = np.empty(n + nr)
    env[:na] = np.linspace(0, 1, na)
    k = np.arange(n - na) / SR
    env[na:n] = s + (1 - s) * np.exp(-k / max(d, 1e-4))
    last = env[n - 1] if n else 0.0
    env[n:] = last * np.exp(-np.arange(nr) / SR / max(r / 4, 1e-4))
    return env


def fade(x, a=0.002, r=0.01):
    x = x.copy()
    na, nr = min(len(x), ns(a)), min(len(x), ns(r))
    if na:
        x[:na] *= np.linspace(0, 1, na)[:, None] if x.ndim == 2 else np.linspace(0, 1, na)
    if nr:
        x[-nr:] *= np.linspace(1, 0, nr)[:, None] if x.ndim == 2 else np.linspace(1, 0, nr)
    return x


def pitch_env(f0, f1, tau, n):
    """f0 에서 f1 로 지수로 내려가는(또는 올라가는) 주파수 곡선"""
    return f1 + (f0 - f1) * expdec(n, tau)


# ── 필터 ──────────────────────────────────────────────────────────────

def _sos(kind, f, order=2):
    nyq = SR / 2 * 0.999
    if kind == 'bandpass':
        lo, hi = max(10.0, f[0]), min(nyq, f[1])
        return signal.butter(order, [lo, hi], 'bandpass', fs=SR, output='sos')
    return signal.butter(order, min(nyq, max(10.0, f)), kind, fs=SR, output='sos')


def lp(x, f, order=2):
    return signal.sosfilt(_sos('lowpass', f, order), x, axis=0)


def hp(x, f, order=2):
    return signal.sosfilt(_sos('highpass', f, order), x, axis=0)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(_sos('bandpass', (lo, hi), order), x, axis=0)


def _rbj(kind, f, q):
    w = 2 * np.pi * min(f, SR * 0.45) / SR
    cw, al = np.cos(w), np.sin(w) / (2 * q)
    if kind == 'lp':
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
    else:  # bp (constant 0 dB peak)
        b = [al, 0, -al]
    a = [1 + al, -2 * cw, 1 - al]
    return np.array(b) / a[0], np.array(a) / a[0]


def sweep(x, cutoff, q=0.8, kind='lp', block=64):
    """시간에 따라 움직이는 필터 — cutoff 는 x 와 같은 길이의 배열(Hz)"""
    y = np.empty_like(x)
    zi = np.zeros(2)
    for i in range(0, len(x), block):
        b, a = _rbj(kind, float(cutoff[min(i + block // 2, len(x) - 1)]), q)
        y[i:i + block], zi = signal.lfilter(b, a, x[i:i + block], zi=zi)
    return y


def shelf(x, f, gain_db, kind='high', q=0.707):
    """셸빙 EQ — kind='low' 는 f 아래, 'high' 는 f 위를 gain_db 만큼"""
    A = 10 ** (gain_db / 40)
    w = 2 * np.pi * f / SR
    cw, al = np.cos(w), np.sin(w) / (2 * q)
    sq = 2 * np.sqrt(A) * al
    sg = 1 if kind == 'low' else -1
    b = np.array([A * ((A + 1) - sg * (A - 1) * cw + sq), sg * 2 * A * ((A - 1) - sg * (A + 1) * cw),
                  A * ((A + 1) - sg * (A - 1) * cw - sq)])
    a = np.array([(A + 1) + sg * (A - 1) * cw + sq, -sg * 2 * ((A - 1) + sg * (A + 1) * cw),
                  (A + 1) + sg * (A - 1) * cw - sq])
    return signal.lfilter(b / a[0], a / a[0], x, axis=0)


def peak_eq(x, f, gain_db, q=1.0):
    A = 10 ** (gain_db / 40)
    w = 2 * np.pi * f / SR
    al = np.sin(w) / (2 * q)
    b = np.array([1 + al * A, -2 * np.cos(w), 1 - al * A])
    a = np.array([1 + al / A, -2 * np.cos(w), 1 - al / A])
    return signal.lfilter(b / a[0], a / a[0], x, axis=0)


# ── 효과 ──────────────────────────────────────────────────────────────

def drive(x, amount=1.5):
    return np.tanh(x * amount) / np.tanh(amount)


@lru_cache(maxsize=16)
def reverb_ir(rt60=1.6, predelay=0.012, damp=6000.0, length=None, seed=3):
    """합성 잔향 응답(스테레오) — 지수로 줄어드는 노이즈 + 초기 반사 몇 개, 뒤로 갈수록 어둡게"""
    length = length or rt60 * 1.1
    r = np.random.default_rng(seed)
    n = ns(length)
    tl = np.arange(n) / SR
    env = np.exp(-6.9 * tl / rt60)
    ir = r.standard_normal((n, 2)) * env[:, None]
    dark = lp(ir, damp, 1)
    mixw = np.clip(tl / length, 0, 1)[:, None]
    ir = ir * (1 - mixw) + dark * mixw
    for d, g in ((0.007, 0.5), (0.013, 0.35), (0.021, 0.28), (0.029, 0.2)):
        k = ns(d)
        ir[k, 0] += g * r.choice([-1, 1])
        ir[ns(d * 1.13), 1] += g * r.choice([-1, 1])
    ir = np.concatenate([np.zeros((ns(predelay), 2)), ir])
    return ir / np.sqrt(np.sum(ir ** 2) / 2)


def reverb(x, rt60=1.6, predelay=0.012, damp=6000.0, hp_in=250.0):
    """x(모노·스테레오) → 젖은 신호만(스테레오, 길이 = len(x) + 잔향)"""
    st = x if x.ndim == 2 else np.stack([x, x], 1)
    st = hp(st, hp_in)
    ir = reverb_ir(rt60, predelay, damp)
    return np.stack([signal.fftconvolve(st[:, c], ir[:, c]) for c in range(2)], 1) * 0.35


def delay(x, sec, fb=0.35, damp=4500.0, pingpong=True):
    """피드백 딜레이(젖은 신호만) — 스테레오면 좌우를 번갈아 튄다"""
    st = x if x.ndim == 2 else np.stack([x, x], 1)
    d = ns(sec)
    a = np.zeros(d + 1)
    a[0], a[d] = 1.0, -fb
    src = lp(st, damp, 1)
    out = np.zeros((len(st) + d * 6, 2))
    if pingpong:
        mono = src.mean(1)
        y = signal.lfilter([1.0], np.r_[1.0, np.zeros(2 * d - 1), -fb], np.r_[mono, np.zeros(d * 6)])
        out[d:, 0] += y[:len(out) - d]
        out[2 * d:, 1] += y[:len(out) - 2 * d]
    else:
        for c in range(2):
            y = signal.lfilter([1.0], a, np.r_[src[:, c], np.zeros(d * 6)])
            out[d:, c] = y[:len(out) - d]
    return out


def limiter(x, ceiling=0.89, look=0.004, release=0.08):
    """앞을 내다보는 피크 리미터 + 마지막 소프트 클립"""
    w = max(1, ns(look))
    peak = maximum_filter1d(np.abs(x).max(1) if x.ndim == 2 else np.abs(x), size=2 * w + 1)
    g = np.minimum(1.0, ceiling / np.maximum(peak, 1e-9))
    g = uniform_filter1d(g, size=w)
    rel = np.exp(-1 / (release * SR))
    g = np.minimum(g, signal.lfilter([1 - rel], [1, -rel], g, zi=[g[0] * rel])[0])
    y = x * (g[:, None] if x.ndim == 2 else g)
    return np.tanh(y / ceiling) * ceiling


def rms_db(x):
    return 20 * np.log10(np.sqrt(np.mean(np.asarray(x) ** 2)) + 1e-12)


def loudness(x, win=0.1):
    """귀로 듣는 크기(LUFS 근사) — K-가중 후 win 초 창의 최댓값. 짧은 효과음끼리 크기를 맞출 때 쓴다(채널은 평균)"""
    st = np.asarray(x, float)
    st = st if st.ndim == 2 else st[:, None]
    k = shelf(hp(st, 38), 1681, 4.0, 'high')
    e = uniform_filter1d((k ** 2).mean(1), size=max(1, ns(win)))
    return -0.691 + 10 * np.log10(e.max() + 1e-12)


def pan(mono, p=0.0):
    """등전력 팬 — p = -1(왼쪽) ~ 1(오른쪽)"""
    a = (p + 1) * np.pi / 4
    return np.stack([mono * np.cos(a), mono * np.sin(a)], 1) * np.sqrt(2)


def place(buf, start, sig, gain=1.0):
    """buf 의 start(샘플)부터 sig 를 더한다 — 넘치는 부분은 버린다"""
    if start >= len(buf) or len(sig) == 0:
        return
    k = min(len(sig), len(buf) - start)
    buf[start:start + k] += sig[:k] * gain


# ── 악기(모노 한 음) ──────────────────────────────────────────────────

def ks_pluck(freq, dur, bright=0.6, decay=0.996, os_=4, seed=0):
    """카플러스-스트롱 현 — 4배 오버샘플로 높은 음도 음정이 맞게"""
    sr = SR * os_
    N = sr / freq - 0.5
    Ni = int(N)
    frac = N - Ni
    n = int(sr * dur)
    r = np.random.default_rng(seed)
    exc = r.uniform(-1, 1, Ni + 1)
    exc = signal.lfilter([bright], [1, -(1 - bright)], exc)  # 밝기 — 작을수록 부드러운 손끝
    x = np.zeros(n)
    x[:len(exc)] = exc
    # y[n] = x[n] + decay * ((1-frac)*avg(y[n-Ni], y[n-Ni-1]) + frac*avg(y[n-Ni-1], y[n-Ni-2]))
    a = np.zeros(Ni + 3)
    a[0] = 1
    a[Ni] -= decay * 0.5 * (1 - frac)
    a[Ni + 1] -= decay * 0.5
    a[Ni + 2] -= decay * 0.5 * frac
    y = signal.lfilter([1.0], a, x)
    y = signal.resample_poly(y, 1, os_)
    return y / (np.max(np.abs(y)) + 1e-9)


def modal(freq, dur, partials, mallet=0.0, mallet_f=3000.0):
    """막대·종 타악기 — partials = [(배수, 크기, 감쇠 τ초), ...]"""
    n = ns(dur)
    out = np.zeros(n)
    for mult, amp, tau in partials:
        f = freq * mult
        if f >= SR * 0.45:
            continue
        out += amp * np.sin(2 * np.pi * f * np.arange(n) / SR) * expdec(n, tau)
    if mallet:
        k = min(n, ns(0.012))
        out[:k] += mallet * lp(noise(k), mallet_f) * expdec(k, 0.0025)
    return fade(out, 0.0015, 0.01)


def fm(freq, dur, ratio=2.0, index=2.0, index_tau=0.15, amp_tau=0.4, attack=0.002):
    """2연산자 FM — 종·벨·건반 소리"""
    n = ns(dur)
    k = np.arange(n) / SR
    idx = index * np.exp(-k / index_tau)
    mod = np.sin(2 * np.pi * freq * ratio * k)
    car = np.sin(2 * np.pi * freq * k + idx * mod)
    env = np.minimum(1, k / max(attack, 1e-4)) * np.exp(-k / amp_tau)
    return fade(car * env, 0.0, 0.01)


def supersaw(freq, dur, voices=5, spread=0.12, seed=0):
    """여러 톱니를 조금씩 어긋나게 겹친 두꺼운 패드 — 스테레오로 퍼진다"""
    n = ns(dur)
    r = np.random.default_rng(seed)
    out = np.zeros((n, 2))
    for v in range(voices):
        det = (v - (voices - 1) / 2) / max(1, (voices - 1) / 2) * spread  # 반음 단위
        s = saw(freq * 2 ** (det / 12), n, ph0=r.random())
        out += pan(s, (v / max(1, voices - 1)) * 1.6 - 0.8)
    return out / voices


# ── 저장 ──────────────────────────────────────────────────────────────

def write_wav(path, x, peak=None):
    x = np.asarray(x, float)
    if peak:
        x = x / (np.max(np.abs(x)) + 1e-9) * peak
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1 if x.ndim == 1 else x.shape[1])
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def ffmpeg_exe():
    for c in [os.environ.get('FFMPEG'), shutil.which('ffmpeg')]:
        if c:
            return c
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        sys.exit('ffmpeg 이 없다 — FFMPEG 환경변수로 경로를 주거나 pip install imageio-ffmpeg')


def write_mp3(path, x, bitrate='128k'):
    with tempfile.TemporaryDirectory() as d:
        tmp = os.path.join(d, 'a.wav')
        write_wav(tmp, x)
        subprocess.run([ffmpeg_exe(), '-y', '-v', 'error', '-i', tmp, '-c:a', 'libmp3lame', '-b:a', bitrate, path], check=True)
