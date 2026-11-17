# -*- coding: utf-8 -*-
"""旁白铺到时间轴 + BGM 侧链压缩混音，输出 audio/mix.m4a"""
import json
import os
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    with open(os.path.join(ROOT, "audio", "narration_events.json"), encoding="utf-8") as f:
        events = json.load(f)
    with open(os.path.join(ROOT, "godot", "data", "timeline.json"), encoding="utf-8") as f:
        duration = json.load(f)["duration"]

    cmd = ["ffmpeg", "-y", "-i", os.path.join(ROOT, "audio", "bgm.wav")]
    for ev in events:
        cmd += ["-i", ev["file"]]
    parts = []
    for i, ev in enumerate(events, start=1):
        ms = int(ev["at"] * 1000)
        parts.append(f"[{i}:a]aresample=44100,aformat=channel_layouts=stereo,adelay={ms}:all=1[n{i}]")
    mix_inputs = "".join(f"[n{i}]" for i in range(1, len(events) + 1))
    parts.append(f"{mix_inputs}amix=inputs={len(events)}:normalize=0,volume=1.0[voice]")
    parts.append("[0:a]volume=0.32,highpass=f=60[bed]")
    parts.append("[bed][voice]sidechaincompress=threshold=0.04:ratio=6:attack=180:release=650:makeup=1[bedduck]")
    parts.append("[bedduck][voice]amix=inputs=2:normalize=0,"
                 f"loudnorm=I=-16:TP=-1.5:LRA=11,atrim=0:{duration},asetpts=N/SR/TB[aout]")
    cmd += ["-filter_complex", ";".join(parts), "-map", "[aout]",
            "-c:a", "aac", "-b:a", "192k",
            os.path.join(ROOT, "audio", "mix.m4a")]
    print(" ".join(cmd)[:400], "...")
    subprocess.run(cmd, check=True)
    print("audio mix -> audio/mix.m4a")


if __name__ == "__main__":
    main()
