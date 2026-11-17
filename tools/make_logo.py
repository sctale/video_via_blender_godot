# -*- coding: utf-8 -*-
"""生成 LEAPTING 品牌贴图（系统 Python + PIL），供 Blender 资产引用"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX_DIR = os.path.join(ROOT, "blender", "textures")
FONT = os.path.join(ROOT, "godot", "assets", "fonts", "fusion-pixel-12px-proportional-zh_hans.otf")


def main():
    os.makedirs(TEX_DIR, exist_ok=True)
    img = Image.new("RGB", (640, 128), (231, 233, 235))
    d = ImageDraw.Draw(img)
    blue = (20, 87, 200)
    green = (47, 160, 96)
    d.polygon([(26, 30), (52, 22), (86, 30), (60, 38)], fill=blue)
    d.polygon([(26, 54), (52, 46), (86, 54), (60, 62)], fill=green)
    d.polygon([(52, 38), (60, 38), (60, 46), (52, 46)], fill=blue)
    f = ImageFont.truetype(FONT, 58)
    d.text((104, 26), "LEAPTING", font=f, fill=blue)
    f2 = ImageFont.truetype(FONT, 26)
    d.text((430, 66), "丽天智能", font=f2, fill=(94, 104, 112))
    d.rectangle((104, 104, 600, 110), fill=green)
    path = os.path.join(TEX_DIR, "logo.png")
    img.save(path)
    print("logo ->", path)


if __name__ == "__main__":
    main()
