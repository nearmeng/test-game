"""草 + 箱子混搭模式的场地示意（俯视战术图）。

与 concept3d/render.gd 使用同一套 hash 规则，所以图和 3D 渲染对得上。
用法: python tools/gen_tactical_map.py
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "concept3d", "c3d_10_map.png")
FONT = "C:/Windows/Fonts/msyh.ttc"

COLS, ROWS = 15, 11
CELL = 62
PAD_X, PAD_Y = 90, 150

STONE = (43, 48, 72, 255)
CRATE = (176, 112, 56, 255)
GRASS = (47, 122, 58, 255)
FLOOR = (24, 28, 42, 255)
SPAWN = [(226, 74, 66), (66, 138, 232), (78, 196, 98), (240, 196, 62)]


def is_wall(x: int, z: int) -> bool:
    edge = x in (0, COLS - 1) or z in (0, ROWS - 1)
    pillar = x % 2 == 0 and z % 2 == 0
    return edge or pillar


def hash_cell(x: int, z: int) -> int:
    v = (x * 73856093) ^ (z * 19349663)
    v &= 0xFFFFFFFF
    v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
    v = v ^ (v >> 16)
    return v % 100


def role(x: int, z: int) -> str:
    if is_wall(x, z):
        return "stone"
    if absi_spawn(x, z):
        return "empty"
    h = hash_cell(x, z)
    if h < 22:
        return "crate"
    if h < 48:
        return "grass"
    return "empty"


def absi_spawn(x: int, z: int) -> bool:
    for sx, sz in ((1, 1), (13, 1), (1, 9), (13, 9)):
        if abs(x - sx) + abs(z - sz) <= 2:
            return True
    return False


def main() -> None:
    w = PAD_X * 2 + COLS * CELL
    h = PAD_Y + ROWS * CELL + 190
    img = Image.new("RGBA", (w, h), (14, 16, 24, 255))
    d = ImageDraw.Draw(img)
    try:
        title_font = ImageFont.truetype(FONT, 34)
        font = ImageFont.truetype(FONT, 19)
        small = ImageFont.truetype(FONT, 15)
    except OSError:
        title_font = font = small = ImageFont.load_default()

    d.text((PAD_X, 42), "草 + 箱子混搭 · 场地规则示意", font=title_font, fill=(238, 241, 250, 255))
    d.text((PAD_X, 88), "箱子管道具与开路，草丛管视野；石柱提供结构。箱子越炸越少，草的价值越打越高。",
           font=small, fill=(150, 160, 190, 255))

    counts = {"stone": 0, "crate": 0, "grass": 0, "empty": 0}
    for z in range(ROWS):
        for x in range(COLS):
            r = role(x, z)
            counts[r] += 1
            px = PAD_X + x * CELL
            py = PAD_Y + z * CELL
            box = [px + 2, py + 2, px + CELL - 2, py + CELL - 2]
            if r == "stone":
                d.rounded_rectangle(box, radius=6, fill=STONE, outline=(70, 78, 112, 255), width=2)
                d.rectangle([box[0] + 8, box[1] + 8, box[2] - 8, box[1] + 16], fill=(72, 80, 116, 255))
            elif r == "crate":
                d.rounded_rectangle(box, radius=4, fill=CRATE, outline=(96, 58, 26, 255), width=2)
                d.line([box[0] + 6, box[1] + 6, box[2] - 6, box[3] - 6], fill=(126, 76, 36, 255), width=2)
                d.line([box[2] - 6, box[1] + 6, box[0] + 6, box[3] - 6], fill=(126, 76, 36, 255), width=2)
            elif r == "grass":
                d.rounded_rectangle(box, radius=22, fill=GRASS, outline=(24, 70, 32, 255), width=2)
                for i in range(5):
                    bx = box[0] + 10 + i * 9
                    d.line([bx, box[3] - 8, bx + 3, box[1] + 10], fill=(88, 176, 96, 255), width=2)
            else:
                d.rounded_rectangle(box, radius=3, fill=FLOOR, outline=(38, 44, 64, 255), width=1)

    # 出生点
    for i, (sx, sz) in enumerate(((1, 1), (13, 1), (1, 9), (13, 9))):
        cx = PAD_X + sx * CELL + CELL // 2
        cy = PAD_Y + sz * CELL + CELL // 2
        c = SPAWN[i]
        d.ellipse([cx - 15, cy - 15, cx + 15, cy + 15], fill=(c[0], c[1], c[2], 235), outline=(255, 255, 255, 200), width=2)
        d.text((cx - 5, cy - 11), str(i + 1), font=font, fill=(20, 20, 26, 255))

    # 图例
    ly = PAD_Y + ROWS * CELL + 26
    items = [
        ("石柱", STONE, "不可破坏，挡爆炸挡视线"),
        ("木箱", CRATE, "可炸开，掉道具，挡爆炸挡视线"),
        ("草丛", GRASS, "可穿行，不挡爆炸，只挡视线"),
        ("空地", FLOOR, "完全可见"),
    ]
    x = PAD_X
    for name, color, desc in items:
        d.rounded_rectangle([x, ly, x + 30, ly + 30], radius=6, fill=color, outline=(90, 96, 130, 255), width=1)
        d.text((x + 42, ly - 1), name, font=font, fill=(230, 234, 245, 255))
        d.text((x + 42, ly + 24), desc, font=small, fill=(146, 154, 182, 255))
        x += 300

    # 比例
    total = COLS * ROWS
    stat = "石柱 %d · 木箱 %d · 草丛 %d · 空地 %d（共 %d 格）" % (
        counts["stone"], counts["crate"], counts["grass"], counts["empty"], total
    )
    d.text((PAD_X, ly + 62), stat, font=small, fill=(146, 154, 182, 255))
    d.text((PAD_X, ly + 88), "建议区间：木箱 18–25%，草丛 18–25%，石柱约 1/3；箱子偏多则节奏快，草偏多则容易互相蹲。",
           font=small, fill=(120, 128, 156, 255))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.convert("RGB").save(OUT)
    print("wrote", os.path.relpath(OUT, ROOT), img.size, stat)


if __name__ == "__main__":
    main()
