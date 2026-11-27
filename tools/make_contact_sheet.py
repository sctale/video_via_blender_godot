# -*- coding: utf-8 -*-
"""把指定时间点的静帧拼成带时间标签的 contact sheet。"""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    ap.add_argument("--times", required=True, help="逗号分隔，如 0.5,14,29.7")
    ap.add_argument("--out", required=True)
    ap.add_argument("--cols", type=int, default=4)
    args = ap.parse_args()
    times = [x.strip() for x in args.times.split(",") if x.strip()]
    if not times:
        raise SystemExit("no times")
    root = Path(args.dir)
    w, h = 480, 270
    rows = (len(times) + args.cols - 1) // args.cols
    sheet = Image.new("RGB", (w * args.cols, h * rows), (18, 20, 22))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 18)
    except OSError:
        font = ImageFont.load_default()
    for i, t in enumerate(times):
        candidates = [root / f"frame_{t}.png", root / f"still_{t}.png", root / f"{t}.png"]
        src = next((p for p in candidates if p.exists()), None)
        if src is None:
            raise FileNotFoundError(f"missing still for t={t} in {root}")
        im = Image.open(src).convert("RGB").resize((w, h), Image.Resampling.LANCZOS)
        x, y = (i % args.cols) * w, (i // args.cols) * h
        sheet.paste(im, (x, y))
        draw.rectangle((x + 8, y + 8, x + 104, y + 38), fill=(0, 0, 0))
        draw.text((x + 14, y + 11), f"{t}s", font=font, fill=(255, 255, 255))
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.out)
    print(f"contact sheet -> {args.out}")


if __name__ == "__main__":
    main()
