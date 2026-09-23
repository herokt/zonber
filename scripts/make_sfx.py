"""효과음 합성 — assets/audio/*.wav (44.1kHz · 16bit · 모노). 녹음·외부 음원 없이 코드로 만든다.
   python scripts/make_sfx.py
소리를 바꾸려면 여기 수치를 고치고 다시 돌린다. 이벤트 연결은 lib/audio_manager.dart(Sfx) 참고.
"""
import os
import wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
rng = np.random.default_rng(7)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def sine(freq, sec, phase=0.0):
    tt = t(sec)
    if callable(freq):
        f = freq(tt)
        return np.sin(2 * np.pi * np.cumsum(f) / SR + phase)
    return np.sin(2 * np.pi * freq * tt + phase)


def noise(sec):
    return rng.uniform(-1, 1, int(SR * sec))


def decay(sec, tau):
    return np.exp(-t(sec) / tau)


def attack(sig, sec=0.004):
    n = min(len(sig), int(SR * sec))
    sig = sig.copy()
    sig[:n] *= np.linspace(0, 1, n)
    return sig


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bell(freq, sec, tau):
    s = sine(freq, sec) + 0.45 * sine(freq * 2.01, sec) + 0.2 * sine(freq * 3.02, sec)
    return attack(s * decay(sec, tau))


def at(total, parts):
    """(시작 초, 신호) 목록을 한 트랙으로 섞는다"""
    out = np.zeros(int(SR * total))
    for start, sig in parts:
        i = int(SR * start)
        n = min(len(sig), len(out) - i)
        out[i:i + n] += sig[:n]
    return out


def save(name, sig, gain=0.85):
    sig = sig / (np.max(np.abs(sig)) + 1e-9) * gain
    fade = int(SR * 0.006)
    sig[-fade:] *= np.linspace(1, 0, fade)
    data = (sig * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f'{name:14s} {len(sig) / SR:.2f}s')


def main():
    os.makedirs(OUT, exist_ok=True)

    # 피구 — 던지는 바람 소리(대역 노이즈가 올라갔다 내려감)
    d = 0.28
    n = noise(d)
    env = np.sin(np.pi * np.clip(t(d) / d, 0, 1)) ** 1.5
    whoosh = highpass(lowpass(n, 2200), 500) * env
    save('throw.wav', whoosh, 0.6)

    # 골키퍼 — 킥(낮은 쿵 + 짧은 딱)
    d = 0.22
    thump = sine(lambda x: 110 * np.exp(-x * 9) + 40, d) * decay(d, 0.06)
    click = lowpass(noise(0.02), 3000) * decay(0.02, 0.004)
    save('kick.wav', at(d, [(0, attack(thump)), (0, click * 0.6)]), 0.9)

    # 선방 — 장갑 "탁"(짧은 노이즈 + 몸통 울림)
    d = 0.16
    slap = lowpass(noise(0.05), 2500) * decay(0.05, 0.012)
    body = sine(210, d) * decay(d, 0.035)
    save('save.wav', at(d, [(0, slap), (0.002, attack(body) * 0.7)]), 0.85)

    # 실점 — 골망 흔들림 + 짧은 호루라기
    d = 0.75
    net = highpass(lowpass(noise(0.4), 5000), 900) * decay(0.4, 0.12)
    vib = lambda x: 2900 + 60 * np.sin(2 * np.pi * 28 * x)
    whistle = sine(vib, 0.42) * np.clip(t(0.42) / 0.02, 0, 1) * np.clip((0.42 - t(0.42)) / 0.05, 0, 1)
    save('goal.wav', at(d, [(0, net), (0.22, whistle * 0.55)]), 0.8)

    # 추가 기록 — 작고 맑은 "팅"
    d = 0.14
    save('graze.wav', bell(1760, d, 0.04) + 0.3 * bell(2640, d, 0.03), 0.45)

    # 코인 — 두 음 "띠링"(B5 → E6)
    d = 0.42
    save('coin.wav', at(d, [(0, bell(988, 0.12, 0.05)), (0.07, bell(1319, 0.35, 0.12))]), 0.7)

    # 뱃지 — 올라가는 차임(C6 E6 G6 C7)
    d = 0.9
    notes = [1047, 1319, 1568, 2093]
    save('badge.wav', at(d, [(i * 0.07, bell(f, 0.7 - i * 0.05, 0.22)) for i, f in enumerate(notes)]), 0.75)

    # 구매 — "촤르륵" + 코인 두 번 + 반짝
    d = 0.7
    rattle = highpass(noise(0.12), 2500) * decay(0.12, 0.04)
    sparkle = sum(bell(f, 0.3, 0.08) * 0.35 for f in (2349, 2794))
    save('purchase.wav', at(d, [(0, rattle * 0.6), (0.05, bell(1175, 0.2, 0.06)), (0.13, bell(1568, 0.5, 0.15)), (0.22, sparkle)]), 0.75)

    # 장착 — 부드러운 "뽁"
    d = 0.1
    pop = sine(lambda x: 520 + 5200 * x, d) * decay(d, 0.025)
    save('equip.wav', attack(pop), 0.6)

    # 레벨업 — 위로 쓸어 올리는 음 + 반짝
    d = 0.5
    sweep = np.sign(sine(lambda x: 380 + 2200 * x, 0.36)) * 0.25 + sine(lambda x: 380 + 2200 * x, 0.36)
    sweep = lowpass(sweep, 4000) * np.clip((0.36 - t(0.36)) / 0.08, 0, 1)
    save('levelup.wav', at(d, [(0, attack(sweep) * 0.5), (0.3, bell(2093, 0.2, 0.06) * 0.5)]), 0.6)

    # 신기록 — 짧은 팡파르(G5 C6 E6 G6)
    d = 1.0
    fan = [(0, 784, 0.1), (0.09, 1047, 0.1), (0.18, 1319, 0.1), (0.27, 1568, 0.7)]
    parts = []
    for st, f, ln in fan:
        tone = sine(f, ln) + 0.35 * np.sign(sine(f, ln)) * 0.3 + 0.25 * sine(f * 2, ln)
        parts.append((st, attack(lowpass(tone, 5000) * decay(ln, ln * 0.6 + 0.03))))
    save('newbest.wav', at(d, parts), 0.7)

    # 위기 — 심장박동(쿵-쿵, 0.8초 반복용)
    d = 0.8
    beat = lambda: attack(sine(lambda x: 70 * np.exp(-x * 6) + 38, 0.16) * decay(0.16, 0.05))
    save('heartbeat.wav', at(d, [(0, beat()), (0.18, beat() * 0.7)]), 0.8)

    # 버튼 — 짧은 "틱"
    d = 0.04
    save('click.wav', sine(1300, d) * decay(d, 0.008), 0.4)


if __name__ == '__main__':
    main()
