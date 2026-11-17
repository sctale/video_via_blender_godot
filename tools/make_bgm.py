# -*- coding: utf-8 -*-
"""原创轻氛围/芯片音乐 BGM（numpy 合成），时长随 timeline.json"""
import json
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 44100


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


def tone(freq, dur, kind="sine", detune=0.0, a=0.01, d=0.1, s=0.5, r=0.2, sustain=0.7):
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
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + names[pitch]
    return 440.0 * 2 ** ((midi - 69) / 12)


def add(buf, sig, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    n = min(len(sig), len(buf) - i)
    buf[i:i + n] += sig[:n]


def main():
    with open(os.path.join(ROOT, "godot", "data", "timeline.json"), encoding="utf-8") as f:
        duration = json.load(f)["duration"]
    total = duration + 2.0
    n = int(total * SR)
    left = np.zeros(n)
    right = np.zeros(n)

    bpm = 72
    beat = 60.0 / bpm
    chords = [
        ["C4", "E4", "G4", "B4"],
        ["A3", "C4", "E4", "G4"],
        ["F3", "A3", "C4", "E4"],
        ["G3", "B3", "D4", "E4"],
    ]
    # 铺底 pad：每 4 拍换和弦
    t = 0.0
    ci = 0
    while t < total - 1:
        chord = chords[ci % len(chords)]
        dur = beat * 4
        for k, nm in enumerate(chord):
            f = note(nm)
            sig = tone(f, dur + 0.8, "sine", detune=0.0015 * (1 if k % 2 else -1),
                       a=1.1, d=0.4, s=0.25, r=1.4, sustain=0.5)
            pan = 0.5 + 0.12 * (k - 1.5) / 3
            add(left, sig * 0.09 * (1 - pan + 0.3), t)
            add(right, sig * 0.09 * (pan + 0.3), t)
        ci += 1
        t += dur

    # 轻盈琶音
    rng = np.random.default_rng(2026)
    penta = ["C5", "D5", "E5", "G5", "A5", "E4", "G4", "A4", "C5"]
    t = beat
    i = 0
    while t < total - 1:
        if rng.random() < 0.62:
            nm = penta[i % len(penta)] if rng.random() < 0.7 else penta[int(rng.integers(0, len(penta)))]
            f = note(nm)
            sig = tone(f, 0.9, "tri", a=0.004, d=0.5, s=0.12, r=0.5, sustain=0.25)
            pan = rng.uniform(0.25, 0.75)
            add(left, sig * 0.055 * (1.3 - pan), t)
            add(right, sig * 0.055 * pan, t)
            i += 1
        t += beat * 2

    # 低频沙地风声
    w = rng.normal(0, 1, n)
    kernel = np.ones(600) / 600
    w = np.convolve(w, kernel, mode="same")
    w = w / (np.abs(w).max() + 1e-9) * 0.035
    left += w
    right += np.roll(w, 400) * 0.9

    # 淡入淡出
    fade = int(2.0 * SR)
    for buf in (left, right):
        buf[:fade] *= np.linspace(0, 1, fade)
        buf[-fade:] *= np.linspace(1, 0, fade)
    peak = max(np.abs(left).max(), np.abs(right).max())
    gain = 0.85 / peak
    left *= gain
    right *= gain
    stereo = np.stack([left, right], axis=1)
    pcm = (np.clip(stereo, -1, 1) * 32767).astype(np.int16)
    path = os.path.join(ROOT, "audio", "bgm.wav")
    with wave.open(path, "wb") as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())
    print(f"BGM {total:.2f}s -> {path}")


if __name__ == "__main__":
    main()
