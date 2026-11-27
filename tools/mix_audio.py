# -*- coding: utf-8 -*-
"""旁白逐段归一 + BGM/SFX 侧链 + 两遍 loudnorm，输出 audio/mix.m4a。"""
import json
import os
import re
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def run(cmd):
    return subprocess.run(cmd, check=True, capture_output=True, text=True, encoding="utf-8", errors="replace")


def main():
    with open(os.path.join(ROOT, "audio", "narration_events.json"), encoding="utf-8") as f:
        events = json.load(f)
    with open(os.path.join(ROOT, "godot", "data", "timeline.json"), encoding="utf-8") as f:
        duration = float(json.load(f)["duration"])

    cmd = ["ffmpeg", "-y", "-i", os.path.join(ROOT, "audio", "bgm.wav")]
    for ev in events:
        cmd += ["-i", ev["file"]]
    sfx_index = len(events) + 1
    cmd += ["-i", os.path.join(ROOT, "audio", "sfx.wav")]

    parts = []
    for i, ev in enumerate(events, start=1):
        ms = int(float(ev["at"]) * 1000)
        parts.append(
            f"[{i}:a]aresample=48000,aformat=channel_layouts=stereo,"
            f"loudnorm=I=-18:TP=-2:LRA=7,aresample=48000,"
            f"adelay={ms}:all=1[n{i}]"
        )
    mix_inputs = "".join(f"[n{i}]" for i in range(1, len(events) + 1))
    parts.append(f"{mix_inputs}amix=inputs={len(events)}:normalize=0,volume=1.0[voice]")
    parts.append("[0:a]volume=0.30,highpass=f=45[bed]")
    parts.append("[bed][voice]sidechaincompress=threshold=0.025:ratio=8:attack=20:release=320:makeup=1[bedduck]")
    parts.append(f"[{sfx_index}:a]volume=0.85,highpass=f=35[sfx]")
    parts.append("[sfx][voice]sidechaincompress=threshold=0.030:ratio=3:attack=25:release=350:makeup=1[sfxduck]")
    parts.append(
        f"[bedduck][sfxduck][voice]amix=inputs=3:normalize=0,"
        f"atrim=0:{duration},asetpts=N/SR/TB[aout]"
    )
    pre = os.path.join(ROOT, "audio", "mix_pre.wav")
    cmd += ["-filter_complex", ";".join(parts), "-map", "[aout]",
            "-c:a", "pcm_s16le", "-ar", "48000", pre]
    run(cmd)

    # 两遍 loudnorm：先测，再线性归一，避免单遍动态模式改变音色
    probe = run([
        "ffmpeg", "-hide_banner", "-nostats", "-i", pre,
        "-af", "loudnorm=I=-16:TP=-1.0:LRA=7:print_format=json",
        "-f", "null", "-",
    ])
    m = re.search(r'\{\s*"input_i".*?\}', probe.stderr, re.S)
    if not m:
        raise RuntimeError("loudnorm measurement failed: " + probe.stderr[-1200:])
    stats = json.loads(m.group(0))
    filt = (
        "loudnorm=I=-16:TP=-1.0:LRA=7:"
        f"measured_I={stats['input_i']}:measured_TP={stats['input_tp']}:"
        f"measured_LRA={stats['input_lra']}:measured_thresh={stats['input_thresh']}:"
        f"offset={stats['target_offset']}:linear=true:print_format=summary"
    )
    out = os.path.join(ROOT, "audio", "mix.m4a")
    run([
        "ffmpeg", "-y", "-i", pre, "-af", filt,
        "-ar", "48000", "-c:a", "aac", "-b:a", "192k", out,
    ])
    print(f"audio mix -> {out}  (pre {stats['input_i']} LUFS, TP {stats['input_tp']} dBTP)")


if __name__ == "__main__":
    main()
