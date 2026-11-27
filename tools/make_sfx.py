# -*- coding: utf-8 -*-
"""程序化机械/环境音效：与 Main.gd 的作业事件对齐，输出 audio/sfx.wav。"""
import json
import os

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, chirp, sawtooth, sosfilt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 48000
rng = np.random.default_rng(20261117)


def _noise(n):
    return rng.normal(0, 1, n)


def _band_noise(n, lo, hi):
    x = _noise(n)
    sos = butter(3, [lo, hi], btype="bandpass", fs=SR, output="sos")
    x = sosfilt(sos, x)
    return x / (np.abs(x).max() + 1e-9)


def _env(n, attack=0.01, release=0.1):
    e = np.ones(n)
    a = min(int(attack * SR), n // 2)
    r = min(int(release * SR), n // 2)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r:
        e[-r:] = np.linspace(1, 0, r)
    return e


def _add_stereo(buf, sig, at, gain=1.0, pan=0.0):
    i = int(at * SR)
    if i >= len(buf):
        return
    n = min(len(sig), len(buf) - i)
    pan = float(np.clip(pan, -1, 1))
    lg = np.sqrt((1 - pan) * 0.5)
    rg = np.sqrt((1 + pan) * 0.5)
    buf[i:i+n, 0] += sig[:n] * gain * lg
    buf[i:i+n, 1] += sig[:n] * gain * rg


def servo(dur, seed=0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f0 = 150 + (seed % 5) * 18
    f1 = 390 + (seed % 7) * 16
    phase = 2 * np.pi * (f0 * t + (f1 - f0) * t * t / (2 * dur))
    body = 0.55 * sawtooth(phase, width=0.35) + 0.25 * np.sin(phase * 2) + 0.12 * np.sin(phase * 3)
    ratchet = 0.75 + 0.25 * np.sin(2 * np.pi * (24 + seed % 4) * t)
    grit = _band_noise(n, 500, 2400) * 0.10
    e = _env(n, 0.035, 0.18) * (0.7 + 0.3 * np.sin(np.pi * t / dur))
    return (body * ratchet + grit) * e


def hydraulic(dur, seed=0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    hiss = _band_noise(n, 250, 1900)
    hum = np.sin(2 * np.pi * (72 + seed % 3 * 6) * t) * 0.25
    pulse = 0.7 + 0.3 * np.sin(2 * np.pi * 7.5 * t)
    return (hiss * 0.55 + hum) * pulse * _env(n, 0.05, 0.25)


def suction(dur, seed=0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    noise = _band_noise(n, 900, 5200)
    thump = np.sin(2 * np.pi * (95 - 35 * t / dur) * t) * np.exp(-t * 9)
    rise = chirp(t, f0=260, f1=720, t1=dur, method="quadratic") * 0.18
    e = _env(n, 0.008, 0.22)
    return (noise * 0.55 + thump * 0.8 + rise) * e


def release(dur, seed=0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    hiss = _band_noise(n, 1200, 6500) * np.exp(-t * 10)
    click = _band_noise(n, 1800, 8000) * np.exp(-t * 45) * 0.8
    return (hiss * 0.55 + click) * _env(n, 0.003, 0.08)


def clunk(dur, seed=0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    low = np.sin(2 * np.pi * (78 - 22 * t / dur) * t) * np.exp(-t * 13)
    body = _band_noise(n, 90, 900) * np.exp(-t * 18) * 0.55
    return (low * 0.9 + body) * _env(n, 0.002, 0.12)


def beep(dur, seed=0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 880 if seed % 2 == 0 else 1174.66
    sig = np.sin(2 * np.pi * f * t) + 0.22 * np.sin(2 * np.pi * f * 2 * t)
    return sig * _env(n, 0.008, min(0.12, dur * 0.4))


def tick(dur, seed=0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    return _band_noise(n, 2200, 9000) * np.exp(-t * 70) * _env(n, 0.001, 0.02)


def motor(dur, seed=0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 46 + (seed % 4) * 3
    sig = (np.sin(2 * np.pi * f * t) * 0.65
           + np.sin(2 * np.pi * f * 2 * t) * 0.22
           + np.sin(2 * np.pi * f * 3 * t) * 0.10)
    sig += _band_noise(n, 120, 1400) * 0.12
    mod = 0.8 + 0.2 * np.sin(2 * np.pi * 3.2 * t)
    return sig * mod * _env(n, 0.12, 0.35)


def whoosh(dur, seed=0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = _noise(n)
    # 分段带通模拟频率扫过
    out = np.zeros(n)
    for k in range(6):
        a = int(k * n / 6)
        b = int((k + 1) * n / 6)
        lo = 180 + k * 180
        hi = min(lo + 900, 7000)
        out[a:b] = _band_noise(b - a, lo, hi)
    e = np.sin(np.pi * t / dur) ** 1.5
    return out * e


def ratchet(dur, seed=0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for at in np.arange(0.05, dur - 0.05, 0.11):
        i = int(at * SR)
        m = min(int(0.045 * SR), n - i)
        tt = np.arange(m) / SR
        sig[i:i+m] += _band_noise(m, 700, 4200) * np.exp(-tt * 75)
    return sig * _env(n, 0.02, 0.12)


SYNTH = {
    "servo": servo, "hydraulic": hydraulic, "suction": suction,
    "release": release, "clunk": clunk, "beep": beep,
    "tick": tick, "motor": motor, "whoosh": whoosh, "ratchet": ratchet,
}


def ambient(duration):
    n = int(duration * SR)
    t = np.arange(n) / SR
    bed = np.zeros((n, 2))
    for ch in range(2):
        x = _noise(n)
        low = sosfilt(butter(3, 900, btype="lowpass", fs=SR, output="sos"), x)
        high = sosfilt(butter(2, 70, btype="highpass", fs=SR, output="sos"), low)
        high /= np.abs(high).max() + 1e-9
        mod = 0.55 + 0.25 * np.sin(2 * np.pi * (0.035 + ch * 0.007) * t + ch)
        mod *= 0.85 + 0.15 * np.sin(2 * np.pi * 0.11 * t + ch * 1.7)
        bed[:, ch] = high * mod
    return bed


def main():
    with open(os.path.join(ROOT, "godot", "data", "timeline.json"), encoding="utf-8") as f:
        duration = float(json.load(f)["duration"])
    with open(os.path.join(ROOT, "tools", "sfx_cues.json"), encoding="utf-8") as f:
        cues = json.load(f)
    total = duration + 1.5
    buf = ambient(total) * 0.10
    for idx, cue in enumerate(cues):
        typ = cue["type"]
        if typ not in SYNTH:
            raise ValueError(f"unknown sfx type: {typ}")
        sig = SYNTH[typ](float(cue.get("dur", 0.6)), int(cue.get("seed", idx)))
        _add_stereo(buf, sig, float(cue["t"]), float(cue.get("gain", 0.5)), float(cue.get("pan", 0.0)))
    # 保守峰值，给混音留余量
    peak = np.abs(buf).max()
    if peak > 0.82:
        buf *= 0.82 / peak
    pcm = (np.clip(buf, -1, 1) * 32767).astype(np.int16)
    path = os.path.join(ROOT, "audio", "sfx.wav")
    wavfile.write(path, SR, pcm)
    print(f"SFX {total:.2f}s, {len(cues)} cues -> {path}")


if __name__ == "__main__":
    main()
