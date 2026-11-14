"""把 4 个视角的截图拼成一张对比图，供人眼挑选。

输入 game3d/shots/cam_0..3.png，输出 docs/camera_sheet.png。
用法: python tools/gen_camera_sheet.py
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "game3d", "shots")
OUT = os.path.join(ROOT, "docs", "camera_sheet.png")
FONT = "C:/Windows/Fonts/msyh.ttc"

ITEMS = [
    ("0", "透视 55° · 全场", "有纵深，画面最好看", "远处人物偏小，格子远近不一致", False),
    ("1", "正交 45° · 等距", "格子等距、判读最准", "画面偏平，没有纵深", True),
    ("2", "高俯视 70° · 全场", "视野最完整，最像 2D", "角色只剩头顶，表现力弱", False),
    ("3", "跟随近景 35°", "代入感最强，像动作游戏", "看不到远处，容易被偷", False),
]

W, H = 1480, 1260
IMG_W, IMG_H = 640, 360
CARD_W = IMG_W + 20
CARD_H = IMG_H + 116
GAP_X, GAP_Y = 26, 30
PAD = 40


def main() -> None:
    canvas = Image.new("RGB", (W, H), (12, 14, 21))
    d = ImageDraw.Draw(canvas)
    try:
        title = ImageFont.truetype(FONT, 38)
        name = ImageFont.truetype(FONT, 24)
        note = ImageFont.truetype(FONT, 16)
        small = ImageFont.truetype(FONT, 15)
    except OSError:
        title = name = note = small = ImageFont.load_default()

    d.text((PAD, 26), "视角方案对比 · 游戏内按 C 循环切换", font=title, fill=(238, 241, 250))
    d.text((PAD + 2, 76), "同一局、同一时刻的四台相机，只换镜头、不动角色", font=small, fill=(140, 150, 180))

    for i, (key, title_txt, pro, con, rec) in enumerate(ITEMS):
        col = i % 2
        row = i // 2
        x = PAD + col * (CARD_W + GAP_X)
        y = 116 + row * (CARD_H + GAP_Y)

        d.rounded_rectangle([x, y, x + CARD_W, y + CARD_H], radius=10, fill=(20, 23, 34))

        path = os.path.join(SRC, "cam_%s.png" % key)
        if os.path.exists(path):
            shot = Image.open(path).convert("RGB").resize((IMG_W, IMG_H), Image.LANCZOS)
            canvas.paste(shot, (x + 10, y + 10))
        else:
            d.text((x + 20, y + 20), "missing %s" % key, font=note, fill=(255, 120, 120))

        if rec:
            d.rounded_rectangle([x, y, x + CARD_W, y + CARD_H], radius=10, outline=(255, 179, 71), width=3)
            d.rounded_rectangle([x + CARD_W - 96, y + 18, x + CARD_W - 16, y + 50], radius=6, fill=(255, 179, 71))
            d.text((x + CARD_W - 84, y + 22), "推荐", font=note, fill=(24, 20, 10))

        ty = y + IMG_H + 22
        d.text((x + 14, ty), "%d  %s" % (int(key) + 1, title_txt), font=name, fill=(240, 243, 250))
        d.text((x + 14, ty + 36), "+ " + pro, font=note, fill=(120, 210, 150))
        d.text((x + 14, ty + 58), "− " + con, font=note, fill=(225, 130, 130))

    fy = 116 + 2 * (CARD_H + GAP_Y) + 6
    d.text((PAD, fy), "怎么选：想看清全场 → 1 或 2；想要动作游戏手感 → 3；想画面最好看 → 1。",
           font=note, fill=(150, 160, 190))
    d.text((PAD, fy + 30), "默认已设为「正交 45° 等距」，游戏里按 C 随时切换，不用重开。",
           font=note, fill=(255, 179, 71))

    canvas.save(OUT)
    print("wrote", os.path.relpath(OUT, ROOT), canvas.size)


if __name__ == "__main__":
    main()
