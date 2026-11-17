# -*- coding: utf-8 -*-
"""生成中文旁白（edge-tts）并输出 Godot 时间轴 timeline.json"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NAR_DIR = os.path.join(ROOT, "audio", "narration")
DATA_DIR = os.path.join(ROOT, "godot", "data")
os.makedirs(NAR_DIR, exist_ok=True)
os.makedirs(DATA_DIR, exist_ok=True)

VOICE = "zh-CN-YunxiNeural"
RATE = "-2%"

SEGMENTS = [
    dict(id=0, name="片头", nominal=8.0,
         narration="在大型光伏电站的建设现场，组件安装正在变得不一样。",
         caption="大型光伏电站 · 组件安装新方式"),
    dict(id=1, name="设备概览", nominal=14.0,
         narration="丽天智能 MMR 自动导航组件安装机器人。履带底盘适应沙地与砾石地形，机械臂与真空吸盘负责抓取，三维视觉系统完成毫米级对位。",
         caption="丽天智能 MMR 自动导航组件安装机器人"),
    dict(id=2, name="上料抓取", nominal=12.0,
         narration="作业开始。机器人停靠安装排一侧，机械臂转向承载平台，吸盘贴合组件，建立负压。",
         caption="上料抓取 · 吸盘建立负压"),
    dict(id=3, name="转运", nominal=9.0,
         narration="组件被稳稳抓起。转台旋转九十度，把组件送到支架轨道上方。",
         caption="转运 · 转台旋转 90°"),
    dict(id=4, name="视觉对位", nominal=11.0,
         narration="视觉系统实时识别轨道位置，自动修正位置与角度偏差，完成精准对位。",
         caption="视觉对位 · 实时修正位置与角度"),
    dict(id=5, name="落板", nominal=9.0,
         narration="组件平稳落位，吸盘释放，一次安装完成。",
         caption="精准落板 · 吸盘释放"),
    dict(id=6, name="换位循环", nominal=15.0,
         narration="机器人自主换位，循环作业。已经铺好的组件，在阵列中不断延伸。",
         caption="自动换位 · 循环安装"),
    dict(id=7, name="片尾", nominal=8.0,
         narration="丽天智能，让光伏电站建设更高效，更安全。",
         caption="丽天智能 · 让光伏电站建设更高效"),
]


def tts(text, path):
    cmd = [sys.executable, "-m", "edge_tts", "--voice", VOICE, "--rate=" + RATE,
           "--text", text, "--write-media", path]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        raise RuntimeError(f"edge-tts failed: {r.stderr[-800:]}")


def duration(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=noprint_wrappers=1:nokey=1", path],
        check=True, capture_output=True, text=True).stdout.strip()
    return float(out)


def main():
    cursor = 0.0
    total = 0.0
    audio_events = []
    out_segments = []
    for seg in SEGMENTS:
        path = os.path.join(NAR_DIR, f"seg{seg['id']}.mp3")
        if not os.path.exists(path) or os.environ.get("REGEN"):
            tts(seg["narration"], path)
        dur = duration(path)
        lead = 1.0 if seg["id"] == 0 else 0.9
        seg_len = max(seg["nominal"], dur + lead + 0.7)
        out_segments.append(dict(
            id=seg["id"], name=seg["name"], start=round(cursor, 2),
            end=round(cursor + seg_len, 2), length=round(seg_len, 2),
            narration=seg["narration"], narration_dur=round(dur, 2),
            narration_start=round(cursor + lead, 2),
            caption=seg["caption"],
        ))
        audio_events.append(dict(file=path.replace("\\", "/"), at=round(cursor + lead, 2)))
        cursor += seg_len
        total = cursor
        print(f"seg{seg['id']} {seg['name']:6s} tts={dur:5.2f}s  seg={seg_len:5.2f}s  start={cursor - seg_len:6.2f}")
    timeline = dict(fps=30, duration=round(total, 2), segments=out_segments)
    with open(os.path.join(DATA_DIR, "timeline.json"), "w", encoding="utf-8") as f:
        json.dump(timeline, f, ensure_ascii=False, indent=1)
    with open(os.path.join(ROOT, "audio", "narration_events.json"), "w", encoding="utf-8") as f:
        json.dump(audio_events, f, ensure_ascii=False, indent=1)
    print(f"TOTAL {total:.2f}s  -> godot/data/timeline.json")


if __name__ == "__main__":
    main()
