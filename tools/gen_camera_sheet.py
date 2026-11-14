"""把 5 个游玩视角的截图拼成一张对比图。

输入 game3d/shots/cam_0..4.png，输出 docs/camera_sheet.png。
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
    ("0", "全场 正交 45°", "全图可见、格子等距，4 人混战最好判读", "角色略小，缺少纵深", True),
    ("1", "跟随 65° 正交", "人物大、身边 8 格清楚", "看不到远处，容易被偷", False),
    ("2", "跟随 78° 近俯视", "遮挡最少，最像 2D", "只见头顶，3D 感最弱", False),
    ("3", "跟随 55° 透视", "纵深强，像动作游戏", "透视让远近格子不等大", False),
    ("4", "全场 透视 55°", "画面最好看", "远处人物小、判读最差", False),
]

IMG_W, IMG_H = 560, 315
CARD_W = IMG_W + 20
CARD_H = IMG_H + 116
GAP_X, GAP_Y = 26, 26
PAD = 36
W = PAD * 2 + CARD_W * 2 + GAP_X
H = 116 + 3 * (CARD_H + GAP_Y) + 40


def main() -> None:
    canvas = Image.new("RGB", (W, H), (12, 14, 21))
    d = ImageDraw.Draw(canvas)
    try:
        title = ImageFont.truetype(FONT, 36)
        name = ImageFont.truetype(FONT, 23)
        note = ImageFont.truetype(FONT, 15)
        small = ImageFont.truetype(FONT, 14)
    except OSError:
        title = name = note = small = ImageFont.load_default()

    d.text((PAD, 26), "游玩视角对比 · 游戏内按 C 切换", font=title, fill=(238, 241, 250))
    d.text((PAD + 2, 74), "同一局、同一时刻，只换镜头；红/橙色地面格是炸弹爆炸范围预演", font=small, fill=(140, 150, 180))

    for i, (key, title_txt, pro, con, rec) in enumerate(ITEMS):
        col = i % 2
        row = i // 2
        x = PAD + col * (CARD_W + GAP_X)
        y = 112 + row * (CARD_H + GAP_Y)

        d.rounded_rectangle([x, y, x + CARD_W, y + CARD_H], radius=10, fill=(20, 23, 34))

        path = os.path.join(SRC, "cam_%s.png" % key)
        if os.path.exists(path):
            shot = Image.open(path).convert("RGB").resize((IMG_W, IMG_H), Image.LANCZOS)
            canvas.paste(shot, (x + 10, y + 10))
        else:
            d.text((x + 20, y + 20), "missing %s" % key, font=note, fill=(255, 120, 120))

        if rec:
            d.rounded_rectangle([x, y, x + CARD_W, y + CARD_H], radius=10, outline=(255, 179, 71), width=3)
            d.rounded_rectangle([x + CARD_W - 92, y + 18, x + CARD_W - 16, y + 48], radius=6, fill=(255, 179, 71))
            d.text((x + CARD_W - 80, y + 21), "推荐", font=note, fill=(24, 20, 10))

        ty = y + IMG_H + 20
        d.text((x + 14, ty), "%d  %s" % (int(key) + 1, title_txt), font=name, fill=(240, 243, 250))
        d.text((x + 14, ty + 34), "+ " + pro, font=note, fill=(120, 210, 150))
        d.text((x + 14, ty + 56), "− " + con, font=note, fill=(225, 130, 130))

    # 最后一格：怎么选
    col = 0
    row = 2
    x = PAD + col * (CARD_W + GAP_X)
    y = 112 + row * (CARD_H + GAP_Y)
    x = PAD + (CARD_W + GAP_X)
    d.rounded_rectangle([x, y, x + CARD_W, y + CARD_H], radius=10, fill=(18, 21, 31), outline=(70, 80, 110), width=1)
    d.text((x + 18, y + 18), "怎么选", font=name, fill=(255, 179, 71))
    lines = [
        "想赢 → 1（全场正交）：4 人混战要看得全。",
        "想有代入感 → 2 或 4：人物大，但只能看到身边。",
        "想拍图/宣传 → 5（全场透视）：最好看。",
        "",
        "另外两处已按“能玩”改过：",
        "· 石柱/木箱压矮，减少遮挡；",
        "· 放弹时地面亮出爆炸范围，不再靠脑补。",
    ]
    ly = y + 58
    for line in lines:
        d.text((x + 18, ly), line, font=note, fill=(180, 190, 215))
        ly += 30

    canvas.save(OUT)
    print("wrote", os.path.relpath(OUT, ROOT), canvas.size)


if __name__ == "__main__":
    main()
