"""火拼炸弹堂 — 程序化音效 / 8-bit 配乐合成器（NumPy）。

输出 16-bit 单声道 WAV 到 game/assets/audio/，全部原创合成，无第三方音频。
用法: python tools/gen_audio.py
"""

from __future__ import annotations

import math
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "assets", "audio")
SR = 22050
rng = np.random.default_rng(4242)


# ------------------------------------------------------------------ 基础工具
def t_axis(dur: float) -> np.ndarray:
    return np.arange(int(dur * SR)) / SR


def midi_hz(n: float) -> float:
    return 440.0 * 2.0 ** ((n - 69.0) / 12.0)


def env(n: int, attack=0.005, decay=0.0, sustain=1.0, release=0.05) -> np.ndarray:
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    d = max(1, int(decay * SR))
    e = np.ones(n)
    a = min(a, n)
    e[:a] = np.linspace(0, 1, a)
    if decay > 0:
        d = min(d, n)
        e[:d] *= np.linspace(1, sustain, d)
        e[d:] *= sustain
    e[-r:] *= np.linspace(1, 0, min(r, n))
    return e


def pulse(freq: float, dur: float, duty=0.5, vib=0.0, vib_hz=5.5) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = freq * (1.0 + vib * np.sin(2 * math.pi * vib_hz * t))
    phase = np.cumsum(f) / SR
    ph = np.mod(phase, 1.0)
    return np.where(ph < duty, 1.0, -1.0)


def triangle(freq: float, dur: float, vib=0.0) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = freq * (1.0 + vib * np.sin(2 * math.pi * 5.0 * t))
    phase = np.cumsum(f) / SR
    ph = np.mod(phase, 1.0)
    return 2.0 * np.abs(2.0 * ph - 1.0) - 1.0


def saw(freq: float, dur: float) -> np.ndarray:
    n = int(dur * SR)
    ph = np.mod(np.cumsum(np.full(n, freq) / SR), 1.0)
    return 2.0 * ph - 1.0


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    a = math.exp(-2 * math.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def lp_fast(x: np.ndarray, cutoff: float) -> np.ndarray:
    """一阶低通（向量化近似，用于长信号）。"""
    a = math.exp(-2 * math.pi * cutoff / SR)
    # 用卷积核近似一阶 IIR
    k = int(min(len(x), max(4, 4 * SR / max(cutoff, 40))))
    kernel = (1 - a) * a ** np.arange(k)
    kernel /= kernel.sum()
    return np.convolve(x, kernel, mode="same")


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - lp_fast(x, cutoff)


def soft_clip(x: np.ndarray, drive: float = 1.4) -> np.ndarray:
    return np.tanh(x * drive) / math.tanh(drive)


def noise(dur: float) -> np.ndarray:
    return rng.uniform(-1, 1, int(dur * SR))


def mix(*parts: np.ndarray) -> np.ndarray:
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def pad(x: np.ndarray, dur: float) -> np.ndarray:
    n = int(dur * SR)
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def fade(x: np.ndarray, ms: float = 8.0) -> np.ndarray:
    n = max(1, int(ms / 1000 * SR))
    n = min(n, len(x) // 2)
    y = x.copy()
    y[:n] *= np.linspace(0, 1, n)
    y[-n:] *= np.linspace(1, 0, n)
    return y


def normalize(x: np.ndarray, peak: float = 0.9) -> np.ndarray:
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def write_wav(name: str, x: np.ndarray, peak=0.9):
    x = normalize(x, peak)
    data = np.clip(x, -1.0, 1.0)
    pcm = (data * 32767.0).astype("<i2")
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"wrote {os.path.relpath(path, ROOT)}  {len(pcm)/SR:6.2f}s  peak={np.max(np.abs(data)):.2f} rms={np.sqrt(np.mean(data**2)):.3f}")


# ------------------------------------------------------------------ 打击乐
def kick(dur=0.22, f0=130.0, f1=48.0, punch=1.0) -> np.ndarray:
    t = t_axis(dur)
    f = f1 + (f0 - f1) * np.exp(-t * 28)
    ph = np.cumsum(f) / SR
    body = np.sin(2 * math.pi * ph) * np.exp(-t * 9)
    click = noise(0.012) * np.exp(-np.arange(int(0.012 * SR)) / (0.004 * SR)) * 0.4
    return mix(body * punch, click) * 0.9


def snare(dur=0.18) -> np.ndarray:
    t = t_axis(dur)
    n = noise(dur) * np.exp(-t * 26)
    tone = np.sin(2 * math.pi * 190 * t) * np.exp(-t * 34) * 0.5
    return mix(lp_fast(n, 5200), tone)


def hat(dur=0.06, open_=False) -> np.ndarray:
    d = 0.16 if open_ else dur
    t = t_axis(d)
    n = noise(d) * np.exp(-t * (18 if open_ else 55))
    return highpass(n, 6000) * 0.5


def crash(dur=0.9) -> np.ndarray:
    t = t_axis(dur)
    n = noise(dur) * np.exp(-t * 5)
    return highpass(n, 3500) * 0.55


# ------------------------------------------------------------------ 音效
def sfx_ui_move():
    x = pulse(880, 0.05, duty=0.25) * env(int(0.05 * SR), 0.002, 0.03, 0.2, 0.01) * 0.35
    return x


def sfx_ui_click():
    a = pulse(660, 0.05, duty=0.5) * env(int(0.05 * SR), 0.001, 0.02, 0.3, 0.01)
    b = pulse(990, 0.07, duty=0.5) * env(int(0.07 * SR), 0.001, 0.03, 0.25, 0.02)
    return mix(a, np.concatenate([np.zeros(int(0.035 * SR)), b])) * 0.5


def sfx_bomb_place():
    t = t_axis(0.2)
    thud = np.sin(2 * math.pi * (90 + 60 * np.exp(-t * 40)) * t) * np.exp(-t * 22) * 0.9
    clik = noise(0.03) * np.exp(-np.arange(int(0.03 * SR)) / (0.006 * SR)) * 0.5
    return mix(thud, clik)


def sfx_explosion():
    dur = 0.95
    t = t_axis(dur)
    n = noise(dur)
    body = lp_fast(n, 1200) * np.exp(-t * 7.5) * 1.6
    rumble = np.sin(2 * math.pi * (58 + 30 * np.exp(-t * 9)) * t) * np.exp(-t * 6) * 0.9
    crackle_t = rng.uniform(0, 0.6, 40)
    crackle = np.zeros(int(dur * SR))
    for ct in crackle_t:
        i = int(ct * SR)
        seg = int(0.012 * SR)
        if i + seg < len(crackle):
            crackle[i : i + seg] += noise(0.012) * 0.35
    # 高频冲击
    impact = highpass(noise(0.12), 2400) * np.exp(-np.arange(int(0.12 * SR)) / (0.02 * SR)) * 0.8
    return mix(body, rumble, crackle, np.concatenate([impact, np.zeros(int(dur * SR) - len(impact))]))


def sfx_brick():
    dur = 0.3
    t = t_axis(dur)
    n = lp_fast(noise(dur), 2600) * np.exp(-t * 15) * 0.9
    crunches = np.zeros(int(dur * SR))
    for k, off in enumerate((0.0, 0.05, 0.11)):
        i = int(off * SR)
        seg = int(0.06 * SR)
        if i + seg < len(crunches):
            crunches[i : i + seg] += noise(0.06) * np.exp(-np.arange(seg) / (0.012 * SR)) * (0.5 - k * 0.12)
    thud = np.sin(2 * math.pi * 120 * t) * np.exp(-t * 24) * 0.4
    return mix(n, crunches, thud)


def sfx_powerup():
    seq = [72, 76, 79, 84]
    parts = []
    for i, n in enumerate(seq):
        d = 0.09
        x = pulse(midi_hz(n), d, duty=0.5) * env(int(d * SR), 0.002, 0.06, 0.5, 0.02) * 0.4
        parts.append(np.concatenate([np.zeros(int(i * 0.055 * SR)), x]))
    return mix(*parts)


def sfx_shield():
    dur = 0.7
    t = t_axis(dur)
    sweep = np.sin(2 * math.pi * np.cumsum(300 + 900 * t) / SR) * np.exp(-t * 3.2) * 0.4
    shimmer = highpass(noise(dur), 5000) * np.exp(-t * 2.4) * 0.35
    return mix(sweep, shimmer)


def sfx_hurt():
    dur = 0.34
    t = t_axis(dur)
    f = 420 - 260 * (t / dur)
    x = saw(1, dur) * 0  # placeholder
    ph = np.cumsum(f) / SR
    sq = np.where(np.mod(ph, 1.0) < 0.5, 1.0, -1.0) * np.exp(-t * 6)
    return soft_clip(sq, 2.0) * 0.6


def sfx_death():
    dur = 1.1
    t = t_axis(dur)
    f = 520 * np.exp(-t * 2.2) + 70
    ph = np.cumsum(f) / SR
    tone = np.where(np.mod(ph, 1.0) < 0.35, 1.0, -1.0) * np.exp(-t * 2.6)
    hiss = lp_fast(noise(dur), 1800) * np.exp(-t * 4) * 0.4
    return mix(tone, hiss) * 0.8


def sfx_countdown():
    dur = 0.16
    x = pulse(1046, dur, duty=0.4) * env(int(dur * SR), 0.003, 0.1, 0.4, 0.03) * 0.5
    return x


def sfx_round_start():
    notes = [(69, 0.0), (72, 0.1), (76, 0.2), (81, 0.32)]
    parts = []
    for n, off in notes:
        d = 0.28
        x = pulse(midi_hz(n), d, duty=0.5) * env(int(d * SR), 0.004, 0.12, 0.5, 0.08) * 0.4
        parts.append(np.concatenate([np.zeros(int(off * SR)), x]))
    return mix(*parts)


def sfx_win():
    notes = [(72, 0.0), (76, 0.12), (79, 0.24), (84, 0.36), (88, 0.52)]
    parts = []
    for n, off in notes:
        d = 0.5
        x = pulse(midi_hz(n), d, duty=0.5) * env(int(d * SR), 0.004, 0.2, 0.45, 0.15) * 0.45
        parts.append(np.concatenate([np.zeros(int(off * SR)), x]))
    return mix(*parts)


def sfx_lose():
    notes = [(69, 0.0), (65, 0.18), (62, 0.36), (57, 0.56)]
    parts = []
    for n, off in notes:
        d = 0.6
        x = pulse(midi_hz(n), d, duty=0.35) * env(int(d * SR), 0.006, 0.25, 0.4, 0.18) * 0.45
        parts.append(np.concatenate([np.zeros(int(off * SR)), x]))
    return mix(*parts)


# ------------------------------------------------------------------ 配乐
class Track:
    """极简 16 分音符步进音序器。"""

    def __init__(self, bpm: float, bars: int):
        self.step = 60.0 / bpm / 4.0
        self.steps = bars * 16
        self.total = self.steps * self.step
        self.buf = np.zeros(int(self.total * SR) + SR)

    def add(self, at_step: int, audio: np.ndarray, gain: float = 1.0, track=None):
        i = int(at_step * self.step * SR)
        seg = min(len(audio), len(self.buf) - i)
        if seg > 0:
            self.buf[i : i + seg] += audio[:seg] * gain

    def note(self, at_step: int, midi: float, length_steps: float, gain=0.3, kind="pulse", duty=0.5, vib=0.0):
        dur = length_steps * self.step
        n = int(dur * SR)
        if kind == "pulse":
            a = pulse(midi_hz(midi), dur, duty=duty, vib=vib)
        elif kind == "tri":
            a = triangle(midi_hz(midi), dur, vib=vib)
        else:
            a = saw(midi_hz(midi), dur)
        e = env(n, 0.006, dur * 0.5, 0.55, 0.05)
        self.add(at_step, a * e, gain)

    def drum(self, at_step: int, kind: str, gain=0.5):
        if kind == "k":
            self.add(at_step, kick(), gain)
        elif kind == "s":
            self.add(at_step, snare(), gain)
        elif kind == "h":
            self.add(at_step, hat(), gain)
        elif kind == "H":
            self.add(at_step, hat(open_=True), gain)
        elif kind == "c":
            self.add(at_step, crash(), gain)

    def echo(self, delay_steps: float, gain: float = 0.22):
        d = int(delay_steps * self.step * SR)
        out = self.buf.copy()
        out[d:] += self.buf[:-d] * gain
        out[d * 2 :] += self.buf[:- d * 2] * gain * 0.5
        self.buf = out


CHORDS = {
    "Am": (57, [69, 72, 76]),
    "F": (53, [65, 69, 72]),
    "C": (48, [64, 67, 72]),
    "G": (55, [67, 71, 74]),
    "Em": (52, [64, 67, 71]),
    "Dm": (50, [62, 65, 69]),
}

MENU_MELODY = [
    # (bar, step, note, len)
    (0, 0, 76, 4), (0, 4, 72, 2), (0, 6, 74, 2), (0, 8, 76, 4), (0, 12, 79, 4),
    (1, 0, 77, 6), (1, 6, 76, 2), (1, 8, 72, 4), (1, 12, 69, 4),
    (2, 0, 72, 4), (2, 4, 76, 4), (2, 8, 79, 4), (2, 12, 81, 4),
    (3, 0, 79, 6), (3, 6, 76, 2), (3, 8, 74, 4), (3, 12, 71, 4),
    (4, 0, 76, 4), (4, 4, 79, 2), (4, 6, 81, 2), (4, 8, 84, 4), (4, 12, 81, 4),
    (5, 0, 77, 4), (5, 4, 76, 2), (5, 6, 74, 2), (5, 8, 72, 8),
    (6, 0, 69, 4), (6, 4, 72, 4), (6, 8, 76, 4), (6, 12, 79, 4),
    (7, 0, 81, 8), (7, 8, 79, 4), (7, 12, 76, 4),
]

BATTLE_MELODY = [
    (0, 0, 69, 2), (0, 2, 72, 2), (0, 4, 76, 2), (0, 6, 72, 2), (0, 8, 81, 4), (0, 12, 79, 2), (0, 14, 76, 2),
    (1, 0, 69, 2), (1, 2, 72, 2), (1, 4, 76, 2), (1, 6, 79, 2), (1, 8, 84, 4), (1, 12, 81, 4),
    (2, 0, 77, 2), (2, 2, 81, 2), (2, 4, 84, 2), (2, 6, 81, 2), (2, 8, 89, 4), (2, 12, 86, 4),
    (3, 0, 79, 2), (3, 2, 83, 2), (3, 4, 86, 2), (3, 6, 83, 2), (3, 8, 91, 4), (3, 12, 88, 4),
    (4, 0, 76, 2), (4, 2, 79, 2), (4, 4, 84, 2), (4, 6, 79, 2), (4, 8, 88, 4), (4, 12, 84, 4),
    (5, 0, 74, 2), (5, 2, 77, 2), (5, 4, 81, 2), (5, 6, 77, 2), (5, 8, 86, 4), (5, 12, 81, 4),
    (6, 0, 72, 2), (6, 2, 76, 2), (6, 4, 79, 2), (6, 6, 76, 2), (6, 8, 84, 4), (6, 12, 79, 4),
    (7, 0, 71, 2), (7, 2, 74, 2), (7, 4, 79, 2), (7, 6, 74, 2), (7, 8, 83, 6), (7, 14, 79, 2),
]

PROGRESSIONS = [
    ["Am", "F", "C", "G"],
    ["Am", "Am", "F", "G"],
    ["F", "G", "Em", "Am"],
    ["F", "G", "Am", "Am"],
]


def music_menu() -> np.ndarray:
    bars = 8
    bpm = 96
    tr = Track(bpm, bars)
    prog = PROGRESSIONS[0] + PROGRESSIONS[2]
    for bar in range(bars):
        chord = prog[bar % len(prog)]
        root, tones = CHORDS[chord]
        # 低音：每小节 1 拍一次，八度下行
        for b, off in enumerate((0, 8)):
            tr.note(bar * 16 + off, root - 12 if b == 0 else root - 5, 6, 0.30, "tri")
        # 和声琶音（16 分）
        for i in range(8):
            n = tones[i % 3] + 12
            tr.note(bar * 16 + i * 2, n, 1.4, 0.10, "pulse", duty=0.125)
        # 鼓：轻
        tr.drum(bar * 16, "k", 0.22)
        tr.drum(bar * 16 + 8, "k", 0.16)
        tr.drum(bar * 16 + 4, "s", 0.10)
        tr.drum(bar * 16 + 12, "s", 0.10)
        for i in (2, 6, 10, 14):
            tr.drum(bar * 16 + i, "h", 0.07)
    for (bar, st, n, ln) in MENU_MELODY:
        tr.note(bar * 16 + st, n, ln, 0.26, "pulse", duty=0.5, vib=0.004)
    tr.echo(3, 0.18)
    out = tr.buf[: int(tr.total * SR)]
    return fade(out, 10)


def music_battle() -> np.ndarray:
    bars = 16
    bpm = 138
    tr = Track(bpm, bars)
    prog = PROGRESSIONS[1] + PROGRESSIONS[3] + PROGRESSIONS[0] + PROGRESSIONS[2]
    for bar in range(bars):
        chord = prog[bar % len(prog)]
        root, tones = CHORDS[chord]
        # 驱动低音（8 分）
        for i in range(8):
            n = root - 12 + (12 if i % 4 == 3 else 0)
            tr.note(bar * 16 + i * 2, n, 1.8, 0.32, "tri")
        # 16 分和声
        for i in range(16):
            n = tones[i % 3] + 12
            tr.note(bar * 16 + i, n, 0.9, 0.075, "pulse", duty=0.25)
        # 鼓
        tr.drum(bar * 16, "k", 0.55)
        tr.drum(bar * 16 + 6, "k", 0.4)
        tr.drum(bar * 16 + 10, "k", 0.3)
        tr.drum(bar * 16 + 4, "s", 0.4)
        tr.drum(bar * 16 + 12, "s", 0.4)
        for i in range(0, 16, 2):
            tr.drum(bar * 16 + i, "h", 0.12)
        if bar % 4 == 0:
            tr.drum(bar * 16, "c", 0.16)
    for (bar, st, n, ln) in BATTLE_MELODY:
        tr.note(bar * 16 + st, n, ln, 0.22, "pulse", duty=0.5, vib=0.003)
    tr.echo(3, 0.2)
    out = tr.buf[: int(tr.total * SR)]
    return fade(out, 10)


# ------------------------------------------------------------------ 主流程
def main():
    os.makedirs(OUT, exist_ok=True)
    write_wav("ui_move.wav", sfx_ui_move(), 0.45)
    write_wav("ui_click.wav", sfx_ui_click(), 0.55)
    write_wav("bomb_place.wav", sfx_bomb_place(), 0.8)
    write_wav("explosion.wav", sfx_explosion(), 0.95)
    write_wav("brick.wav", sfx_brick(), 0.8)
    write_wav("powerup.wav", sfx_powerup(), 0.7)
    write_wav("shield.wav", sfx_shield(), 0.6)
    write_wav("hurt.wav", sfx_hurt(), 0.7)
    write_wav("death.wav", sfx_death(), 0.85)
    write_wav("countdown.wav", sfx_countdown(), 0.5)
    write_wav("round_start.wav", sfx_round_start(), 0.7)
    write_wav("win.wav", sfx_win(), 0.85)
    write_wav("lose.wav", sfx_lose(), 0.8)
    write_wav("music_menu.wav", music_menu(), 0.55)
    write_wav("music_battle.wav", music_battle(), 0.55)


if __name__ == "__main__":
    main()
