# -*- coding: utf-8 -*-
"""原创分层氛围 BGM（numpy/scipy 合成），时长随 timeline.json。"""
import json
import os

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 48000
rng = np.random.default_rng(20261117)


def env_adsr(n, a, d, s, r, sustain=0.65):
    a_n, d_n, r_n = max(int(a * SR), 1), max(int(d * SR), 1), max(int(r * SR), 1)
    s_n = max(n - a_n - d_n - r_n, 0)
    e = np.concatenate([
        np.linspace(0, 1, a_n),
        np.linspace(1, sustain, d_n),
        np.full(s_n, sustain),
        np.linspace(sustain, 0, r_n),
    ])
    if len(e) < n:
        e = np.pad(e, (0, n - len(e)))
    return e[:n]


def tone(freq, dur, kind="sine", detune=0.0, a=0.01, d=0.1, s=0.2, r=0.2, sustain=0.7):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = freq * (1 + detune)
    if kind == "sine":
        w = np.sin(2 * np.pi * f * t)
    elif kind == "tri":
        w = 2 / np.pi * np.arcsin(np.sin(2 * np.pi * f * t))
    else:
        w = np.sin(2 * np.pi * f * t) + 0.28 * np.sin(2 * np.pi * f * 2 * t)
    return w * env_adsr(n, a, d, s, r, sustain)


def note(name):
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6,
             "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + names[pitch]
    return 440.0 * 2 ** ((midi - 69) / 12)


def add(buf, sig, at, gain=1.0, pan=0.5):
    i = int(at * SR)
    if i >= len(buf):
        return
    n = min(len(sig), len(buf) - i)
    buf[i:i+n, 0] += sig[:n] * gain * (1.2 - pan)
    buf[i:i+n, 1] += sig[:n] * gain * pan


def lowpass(x, cutoff):
    return sosfilt(butter(2, cutoff, btype="lowpass", fs=SR, output="sos"), x)


def main():
    with open(os.path.join(ROOT, "godot", "data", "timeline.json"), encoding="utf-8") as f:
        duration = float(json.load(f)["duration"])
    total = duration + 2.0
    n = int(total * SR)
    buf = np.zeros((n, 2))

    bpm = 72
    beat = 60.0 / bpm
    chords = [
        ["C3", "E3", "G3", "B3"],
        ["A2", "C3", "E3", "G3"],
        ["F2", "A2", "C3", "E3"],
        ["G2", "B2", "D3", "E3"],
    ]
    roots = ["C2", "A1", "F1", "G1"]

    # 和声铺底：每 4 拍换和弦，轻微失谐 + 低通，避免数字味
    t = 0.0
    ci = 0
    while t < total - 1:
        chord = chords[ci % len(chords)]
        dur = beat * 4
        for k, nm in enumerate(chord):
            f = note(nm)
            sig = tone(f, dur + 1.0, "sine", detune=0.0018 * (1 if k % 2 else -1),
                       a=0.9, d=0.5, s=0.22, r=1.3, sustain=0.55)
            sig += tone(f * 2, dur + 1.0, "tri", a=1.2, d=0.6, s=0.08, r=1.4, sustain=0.25) * 0.18
            add(buf, sig, t, 0.050, 0.32 + 0.12 * k)
        # 低音根部，长音
        bass = tone(note(roots[ci % len(roots)]), dur + 0.6, "sine",
                    a=0.25, d=0.4, s=0.35, r=0.8, sustain=0.6)
        add(buf, bass, t, 0.085, 0.5)
        ci += 1
        t += dur

    # 琶音：半拍一次，段落 6 暂时收薄，片尾回到主和弦
    penta = ["C5", "D5", "E5", "G5", "A5", "E4", "G4", "A4", "C5"]
    t = beat
    i = 0
    while t < total - 1:
        if not (55.5 < t < 64.0):
            nm = penta[i % len(penta)] if rng.random() < 0.72 else penta[int(rng.integers(0, len(penta)))]
            f = note(nm)
            sig = tone(f, 0.75, "tri", a=0.004, d=0.35, s=0.08, r=0.35, sustain=0.20)
            add(buf, sig, t, 0.040, 0.28 + 0.44 * ((i % 5) / 4.0))
            i += 1
        t += beat * 0.5

    # 轻脉冲：8s 后进入，落板后短暂留白
    t = 8.0
    while t < 82.0:
        if not (55.5 < t < 64.0):
            kick = tone(58, 0.28, "sine", a=0.002, d=0.08, s=0.05, r=0.15, sustain=0.15)
            add(buf, kick, t, 0.050, 0.5)
            sh = rng.normal(0, 1, int(0.09 * SR))
            sh = sosfilt(butter(2, 5500, btype="highpass", fs=SR, output="sos"), sh)
            sh *= np.exp(-np.arange(len(sh)) / SR * 45)
            add(buf, sh, t + beat * 0.5, 0.010, 0.62)
        t += beat

    # 两次动作前的上升音
    for start, end in ((22.4, 23.66), (63.4, 64.68), (76.4, 77.2)):
        dur = end - start
        m = int(dur * SR)
        x = rng.normal(0, 1, m)
        x = sosfilt(butter(2, [500, 5200], btype="bandpass", fs=SR, output="sos"), x)
        x /= np.abs(x).max() + 1e-9
        x *= np.linspace(0, 1, m) ** 1.8
        add(buf, x, start, 0.055, 0.5)

    # 片尾主和弦长音
    for k, nm in enumerate(["C3", "E3", "G3", "B3", "C4"]):
        sig = tone(note(nm), 6.0, "sine", a=0.7, d=0.8, s=0.25, r=2.2, sustain=0.5)
        add(buf, sig, 81.8, 0.045, 0.30 + 0.10 * k)

    # 整体低通、淡入淡出、峰值归一
    for ch in range(2):
        buf[:, ch] = lowpass(buf[:, ch], 5200)
    fade_in = int(1.5 * SR)
    fade_out = int(2.5 * SR)
    buf[:fade_in] *= np.linspace(0, 1, fade_in)[:, None]
    buf[-fade_out:] *= np.linspace(1, 0, fade_out)[:, None]
    peak = np.abs(buf).max()
    buf *= 0.72 / (peak + 1e-9)
    pcm = (np.clip(buf, -1, 1) * 32767).astype(np.int16)
    path = os.path.join(ROOT, "audio", "bgm.wav")
    wavfile.write(path, SR, pcm)
    print(f"BGM {total:.2f}s -> {path}")


if __name__ == "__main__":
    main()
