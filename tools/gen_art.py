"""火拼炸弹堂 — 像素素材生成器。

所有美术资源均由本脚本程序化绘制（Pillow），无第三方素材。
输出到 game/assets/，逻辑分辨率 24x24，引擎内按 2 倍最近邻放大 = 48px/格。

用法: python tools/gen_art.py
"""

from __future__ import annotations

import math
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "assets")

T = 24  # 逻辑格尺寸
rng = random.Random(20261110)

# ---------------------------------------------------------------- 调色板
C = {
    "ink": (20, 18, 30, 255),
    "ink_soft": (40, 38, 54, 255),
    "floor_a": (62, 68, 94, 255),
    "floor_b": (70, 76, 104, 255),
    "floor_line": (48, 52, 74, 255),
    "wall": (96, 106, 148, 255),
    "wall_top": (136, 148, 196, 255),
    "wall_dark": (44, 50, 78, 255),
    "wood": (176, 108, 58, 255),
    "wood_light": (208, 138, 78, 255),
    "wood_dark": (112, 64, 32, 255),
    "bomb": (44, 44, 58, 255),
    "bomb_light": (96, 100, 128, 255),
    "fuse": (196, 160, 96, 255),
    "white": (255, 255, 255, 255),
    "flame_white": (255, 252, 220, 255),
    "flame_yellow": (255, 214, 84, 255),
    "flame_orange": (255, 138, 48, 255),
    "flame_red": (222, 68, 44, 255),
    "flame_deep": (150, 36, 32, 255),
}

PLAYERS = [
    # name, 主色, 暗色, 亮色, 帽子风格
    ("赤焰", (226, 74, 66, 255), (150, 40, 38, 255), (255, 132, 118, 255), "cap"),
    ("苍蓝", (66, 138, 232, 255), (36, 76, 148, 255), (132, 190, 255, 255), "helm"),
    ("翠风", (78, 196, 98, 255), (40, 110, 56, 255), (146, 232, 158, 255), "hood"),
    ("金雷", (240, 196, 62, 255), (152, 116, 26, 255), (255, 226, 132, 255), "crown"),
]

SKIN = (255, 214, 178, 255)
SKIN_DARK = (214, 160, 124, 255)


def new(w: int = T, h: int = T) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def bl(d: ImageDraw.ImageDraw, box, fill, outline=None, width: int = 1):
    """带描边的矩形。box = (x0, y0, x1, y1) inclusive."""
    if outline:
        d.rectangle([box[0] - width, box[1] - width, box[2] + width, box[3] + width], fill=outline)
    d.rectangle(box, fill=fill)


def blob(d: ImageDraw.ImageDraw, cx, cy, rx, ry, fill, outline, outline_w: int = 1):
    d.ellipse([cx - rx - outline_w, cy - ry - outline_w, cx + rx + outline_w, cy + ry + outline_w], fill=outline)
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=fill)


def rrect(d: ImageDraw.ImageDraw, box, radius, fill, outline, width: int = 1):
    d.rounded_rectangle(
        [box[0] - width, box[1] - width, box[2] + width, box[3] + width],
        radius=radius + width,
        fill=outline,
    )
    d.rounded_rectangle(box, radius=radius, fill=fill)


# ---------------------------------------------------------------- 地形
def floor_tile(variant: int) -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)
    base = (36, 40, 56) if variant % 2 == 0 else (41, 45, 62)
    d.rectangle([0, 0, T - 1, T - 1], fill=base)
    # 细砖缝
    d.line([(0, T - 1), (T - 1, T - 1)], fill=(28, 31, 44, 255))
    d.line([(T - 1, 0), (T - 1, T - 1)], fill=(28, 31, 44, 255))
    d.line([(0, 0), (T - 1, 0)], fill=(46, 51, 71, 255))
    d.line([(0, 0), (0, T - 1)], fill=(46, 51, 71, 255))
    # 斑点纹理，避免大面积死板
    for _ in range(5 if variant else 3):
        x = rng.randint(3, T - 4)
        y = rng.randint(3, T - 4)
        d.point((x, y), fill=(base[0] + 8, base[1] + 9, base[2] + 12, 255))
    return img


def wall_tile() -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)
    # 外描边
    d.rectangle([0, 0, T - 1, T - 1], fill=(20, 22, 32, 255))
    # 主体
    d.rectangle([2, 2, T - 3, T - 3], fill=(96, 104, 136, 255))
    # 顶面
    d.rectangle([2, 2, T - 3, 8], fill=(138, 148, 188, 255))
    d.line([(3, 3), (T - 4, 3)], fill=(180, 190, 226, 255))
    d.line([(2, 9), (T - 3, 9)], fill=(40, 44, 62, 255))
    # 内嵌面板
    d.rectangle([5, 11, T - 6, T - 7], fill=(76, 84, 112, 255))
    d.line([(5, 11), (T - 6, 11)], fill=(118, 128, 164, 255))
    # 底部与右侧阴影
    d.rectangle([2, T - 6, T - 3, T - 3], fill=(52, 58, 82, 255))
    d.rectangle([T - 5, 2, T - 3, T - 3], fill=(66, 72, 98, 255))
    # 铆钉
    for (x, y) in ((3, 10), (T - 4, 10), (3, T - 6), (T - 4, T - 6)):
        d.point((x, y), fill=(200, 210, 238, 255))
    return img


def crate_tile(stage: int = 0) -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, T - 1, T - 1], fill=C["wood_dark"])
    bl(d, (1, 1, T - 2, T - 2), C["wood"])
    # 木板
    d.rectangle([1, 1, T - 2, 7], fill=C["wood_light"])
    d.rectangle([1, 8, T - 2, 15], fill=C["wood"])
    d.rectangle([1, 16, T - 2, T - 2], fill=(156, 94, 50, 255))
    for y in (7, 15):
        d.line([(1, y), (T - 2, y)], fill=C["wood_dark"])
    # 边框钉
    for (x, y) in ((3, 3), (T - 4, 3), (3, T - 4), (T - 4, T - 4)):
        d.point((x, y), fill=(240, 206, 150, 255))
    # 裂纹
    if stage >= 1:
        d.line([(6, 5), (10, 9), (8, 12), (12, 15)], fill=C["wood_dark"])
        d.line([(15, 4), (13, 8)], fill=C["wood_dark"])
    if stage >= 2:
        d.line([(17, 7), (14, 12), (18, 16), (16, 20)], fill=(70, 38, 20, 255))
        d.line([(5, 13), (9, 17), (7, 21)], fill=(70, 38, 20, 255))
        d.rectangle([19, 18, 21, 20], fill=(60, 32, 16, 255))
    return img


# ---------------------------------------------------------------- 角色
def draw_char(direction: str, frame: int, main, dark, light, hat: str) -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)

    bob = 1 if frame == 1 else 0  # 走动时身体上下浮动
    # 影子
    d.ellipse([5, 20, 19, 23], fill=(12, 10, 18, 90))

    # 脚
    foot_y = 19
    if frame == 1:
        boots = ((5, foot_y), (13, foot_y - 1))
    elif frame == 2:
        boots = ((6, foot_y - 1), (14, foot_y))
    else:
        boots = ((6, foot_y), (13, foot_y))
    for (bx, by) in boots:
        bl(d, (bx, by, bx + 4, by + 3), dark, C["ink"])

    # 身体
    rrect(d, (5, 11 - bob, 18, 19 - bob), 4, main, C["ink"])
    d.rectangle([6, 14 - bob, 17, 15 - bob], fill=dark)  # 腰带
    d.rectangle([11, 14 - bob, 12, 17 - bob], fill=light)  # 拉链高光

    # 手
    if direction == "left":
        blob(d, 4, 14 - bob, 2, 2, SKIN, C["ink"])
    elif direction == "right":
        blob(d, 19, 14 - bob, 2, 2, SKIN, C["ink"])
    else:
        blob(d, 4, 14 - bob, 2, 2, SKIN, C["ink"])
        blob(d, 19, 14 - bob, 2, 2, SKIN, C["ink"])

    # 头
    hy = 9 - bob
    blob(d, 12, hy, 6, 6, SKIN, C["ink"])

    # 帽子
    if hat == "cap":
        d.ellipse([5, hy - 8, 19, hy + 1], fill=main, outline=C["ink"])
        d.ellipse([7, hy - 6, 17, hy - 1], fill=main)
        brim = (7, hy - 2, 17, hy - 1) if direction != "up" else (5, hy - 3, 19, hy - 2)
        bl(d, brim, dark, C["ink"])
        d.point((12, hy - 5), fill=light)
    elif hat == "helm":
        d.ellipse([5, hy - 8, 19, hy + 1], fill=main, outline=C["ink"])
        d.ellipse([7, hy - 6, 17, hy - 2], fill=main)
        d.rectangle([5, hy - 3, 19, hy - 1], fill=dark)
        d.point((12, hy - 9), fill=light)  # 天线
        d.point((12, hy - 10), fill=light)
    elif hat == "hood":
        d.ellipse([5, hy - 8, 19, hy + 2], fill=main, outline=C["ink"])
        d.ellipse([8, hy - 5, 16, hy + 1], fill=dark)
        d.point((12, hy - 7), fill=light)
    else:  # crown
        d.rectangle([6, hy - 7, 18, hy - 2], fill=main, outline=C["ink"])
        for cx in (7, 12, 17):
            d.point((cx, hy - 9), fill=main)
            d.point((cx, hy - 8), fill=main)
        d.rectangle([6, hy - 4, 18, hy - 3], fill=dark)

    # 脸
    if direction == "down":
        eyes = ((9, hy), (14, hy))
        for (ex, ey) in eyes:
            d.rectangle([ex, ey, ex + 1, ey + 2], fill=C["white"])
            d.point((ex, ey + 1), fill=C["ink"])
        d.line([(10, hy + 4), (14, hy + 4)], fill=SKIN_DARK)
    elif direction == "left":
        d.rectangle([7, hy, 9, hy + 2], fill=C["white"])
        d.point((7, hy + 1), fill=C["ink"])
        d.point((4, hy + 2), fill=SKIN_DARK)
    elif direction == "right":
        d.rectangle([15, hy, 17, hy + 2], fill=C["white"])
        d.point((16, hy + 1), fill=C["ink"])
        d.point((20, hy + 2), fill=SKIN_DARK)
    else:  # up -> 背包
        rrect(d, (7, hy + 1, 16, hy + 6), 2, dark, C["ink"])
        d.rectangle([9, hy + 2, 14, hy + 4], fill=light)
        d.line([(5, hy - 3), (8, hy + 1)], fill=dark)

    return img


def char_sheet(idx: int) -> Image.Image:
    name, main, dark, light, hat = PLAYERS[idx]
    sheet = Image.new("RGBA", (T * 3, T * 4), (0, 0, 0, 0))
    dirs = ["down", "left", "right", "up"]
    for row, direction in enumerate(dirs):
        for frame in range(3):
            img = draw_char(direction, frame, main, dark, light, hat)
            sheet.paste(img, (frame * T, row * T))
    return sheet


# ---------------------------------------------------------------- 炸弹
def bomb_frame(phase: int) -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)
    r = 7 + (phase % 2)
    cx, cy = 12, 14
    blob(d, cx, cy, r, r, C["bomb"], C["ink"])
    # 高光
    d.ellipse([cx - 4, cy - 5, cx - 1, cy - 2], fill=C["bomb_light"])
    d.ellipse([cx - 3, cy - 4, cx - 2, cy - 3], fill=(210, 220, 240, 255))
    # 引信口
    d.rectangle([cx - 2, cy - r - 1, cx + 1, cy - r + 1], fill=C["ink_soft"])
    # 引信
    fx = cx + 2
    fy = cy - r - 1
    d.line([(fx, fy), (fx + 2, fy - 3), (fx + 1, fy - 5)], fill=C["fuse"], width=1)
    # 火花
    sx, sy = fx + 1 + (phase % 2), fy - 6
    d.point((sx, sy), fill=C["white"])
    d.point((sx - 1, sy + 1), fill=C["flame_yellow"])
    d.point((sx + 1, sy + 1), fill=C["flame_orange"])
    if phase >= 2:
        d.point((sx, sy - 1), fill=C["flame_white"])
    return img


def bomb_sheet() -> Image.Image:
    sheet = Image.new("RGBA", (T * 4, T), (0, 0, 0, 0))
    for i in range(4):
        sheet.paste(bomb_frame(i), (i * T, 0))
    return sheet


# ---------------------------------------------------------------- 火焰
def _flame_shape(d: ImageDraw.ImageDraw, cx, cy, rx, ry, seed: int, jag: float = 1.0):
    rr = random.Random(seed)
    pts = []
    steps = 12
    for i in range(steps):
        a = i / steps * math.tau
        j = 1.0 + (rr.random() - 0.5) * 0.22 * jag
        pts.append((cx + math.cos(a) * rx * j, cy + math.sin(a) * ry * j))
    d.polygon(pts, fill=C["flame_deep"])
    inner = [(cx + (x - cx) * 0.82, cy + (y - cy) * 0.82) for (x, y) in pts]
    d.polygon(inner, fill=C["flame_red"])
    inner2 = [(cx + (x - cx) * 0.62, cy + (y - cy) * 0.62) for (x, y) in pts]
    d.polygon(inner2, fill=C["flame_orange"])
    inner3 = [(cx + (x - cx) * 0.40, cy + (y - cy) * 0.40) for (x, y) in pts]
    d.polygon(inner3, fill=C["flame_yellow"])
    inner4 = [(cx + (x - cx) * 0.20, cy + (y - cy) * 0.20) for (x, y) in pts]
    d.polygon(inner4, fill=C["flame_white"])


def flame_dir_sheet(kind: str) -> Image.Image:
    sheet = Image.new("RGBA", (T * 4, T), (0, 0, 0, 0))
    for i in range(4):
        img = new()
        d = ImageDraw.Draw(img)
        if kind == "center":
            grow = 1.0 + 0.10 * [0, 1, 0.4, -0.2][i]
            _flame_shape(d, 12, 12, 10.5 * grow, 10.5 * grow, seed=100 + i)
        elif kind == "arm_h":
            _flame_shape(d, 3.5, 12, 5.0, 9.0, seed=200 + i)
            _flame_shape(d, 12, 12, 8.0, 10.0, seed=300 + i)
            _flame_shape(d, 20.5, 12, 5.0, 9.0, seed=400 + i)
        elif kind == "arm_v":
            _flame_shape(d, 12, 3.5, 9.0, 5.0, seed=200 + i)
            _flame_shape(d, 12, 12, 10.0, 8.0, seed=300 + i)
            _flame_shape(d, 12, 20.5, 9.0, 5.0, seed=400 + i)
        elif kind == "tip_h":
            _flame_shape(d, 14, 12, 9.0, 8.0, seed=500 + i)
            _flame_shape(d, 5, 12, 5.0, 5.5, seed=600 + i)
        elif kind == "tip_v":
            _flame_shape(d, 12, 14, 8.0, 9.0, seed=500 + i)
            _flame_shape(d, 12, 5, 5.5, 5.0, seed=600 + i)
        sheet.paste(img, (i * T, 0))
    return sheet


# ---------------------------------------------------------------- 道具
def powerup_icon(kind: str) -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)
    # 底框
    rrect(d, (2, 2, 21, 21), 4, (36, 40, 58, 255), (108, 120, 160, 255))
    d.rectangle([4, 4, 19, 5], fill=(58, 64, 92, 255))

    if kind == "bomb":
        blob(d, 12, 13, 6, 6, C["bomb"], C["ink"])
        d.ellipse([9, 9, 11, 11], fill=C["bomb_light"])
        d.line([(14, 7), (16, 5)], fill=C["fuse"])
        d.point((16, 4), fill=C["flame_yellow"])
        d.rectangle([15, 12, 19, 13], fill=C["white"])
        d.rectangle([16, 11, 17, 14], fill=C["white"])
    elif kind == "fire":
        _flame_shape(d, 12, 13, 7.5, 8.5, seed=901)
        d.rectangle([15, 4, 18, 5], fill=C["white"])
        d.rectangle([16, 3, 17, 6], fill=C["white"])
    elif kind == "speed":
        # 靴子
        bl(d, (6, 8, 12, 17), (220, 120, 70, 255), C["ink"])
        bl(d, (10, 14, 19, 18), (220, 120, 70, 255), C["ink"])
        d.rectangle([6, 15, 9, 17], fill=(160, 76, 44, 255))
        d.line([(4, 11), (7, 11)], fill=C["white"])
        d.line([(3, 14), (6, 14)], fill=C["white"])
    elif kind == "shield":
        pts = [(12, 4), (19, 7), (19, 13), (12, 20), (5, 13), (5, 7)]
        d.polygon(pts, fill=(84, 196, 232, 255), outline=C["ink"])
        d.polygon([(12, 6), (17, 8), (17, 13), (12, 18), (7, 13), (7, 8)], fill=(52, 132, 176, 255))
        d.line([(12, 8), (12, 15)], fill=C["white"])
        d.line([(9, 11), (15, 11)], fill=C["white"])
    return img


def powerup_sheet() -> Image.Image:
    kinds = ["bomb", "fire", "speed", "shield"]
    sheet = Image.new("RGBA", (T * 4, T), (0, 0, 0, 0))
    for i, k in enumerate(kinds):
        sheet.paste(powerup_icon(k), (i * T, 0))
    return sheet


def small_icon(kind: str) -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if kind == "bomb":
        blob(d, 8, 9, 5, 5, C["bomb"], C["ink"])
        d.ellipse([5, 6, 7, 8], fill=C["bomb_light"])
        d.point((12, 3), fill=C["flame_yellow"])
    elif kind == "fire":
        _flame_shape(d, 8, 9, 5.5, 6.0, seed=902)
    elif kind == "speed":
        bl(d, (4, 6, 8, 12), (240, 150, 90, 255), C["ink"])
        bl(d, (7, 10, 12, 12), (240, 150, 90, 255), C["ink"])
    elif kind == "shield":
        d.polygon([(8, 2), (13, 4), (13, 9), (8, 14), (3, 9), (3, 4)], fill=(84, 196, 232, 255), outline=C["ink"])
        d.line([(8, 5), (8, 11)], fill=C["white"])
        d.line([(5, 7), (11, 7)], fill=C["white"])
    return img


def icon_sheet() -> Image.Image:
    kinds = ["bomb", "fire", "speed", "shield"]
    sheet = Image.new("RGBA", (16 * 4, 16), (0, 0, 0, 0))
    for i, k in enumerate(kinds):
        sheet.paste(small_icon(k), (i * 16, 0))
    return sheet


# ---------------------------------------------------------------- 应用图标 / 背景
def app_icon(size: int = 128) -> Image.Image:
    img = Image.new("RGBA", (size, size), (24, 22, 36, 255))
    d = ImageDraw.Draw(img)
    # 放射背景
    for i in range(12):
        a = i / 12 * math.tau
        d.polygon(
            [
                (size / 2, size / 2),
                (size / 2 + math.cos(a) * size, size / 2 + math.sin(a) * size),
                (size / 2 + math.cos(a + 0.16) * size, size / 2 + math.sin(a + 0.16) * size),
            ],
            fill=(44, 40, 62, 255),
        )
    big = bomb_frame(1).resize((96, 96), Image.NEAREST)
    img.alpha_composite(big, (16, 20))
    return img


def menu_backdrop(w: int = 320, h: int = 180) -> Image.Image:
    """菜单背景用的低分辨率纹理（引擎内放大并淡出）。"""
    img = Image.new("RGBA", (w, h), (18, 18, 28, 255))
    d = ImageDraw.Draw(img)
    rr = random.Random(3)
    for _ in range(160):
        x, y = rr.randint(0, w - 1), rr.randint(0, h - 1)
        c = 30 + rr.randint(0, 26)
        d.point((x, y), fill=(c, c + 4, c + 16, 255))
    for _ in range(10):
        x, y = rr.randint(0, w - 1), rr.randint(0, h - 1)
        d.ellipse([x, y, x + rr.randint(4, 18), y + rr.randint(3, 10)], fill=(26, 26, 40, 255))
    return img


# ---------------------------------------------------------------- 输出
def save(img: Image.Image, name: str):
    path = os.path.join(OUT, name)
    img.save(path)
    print("wrote", os.path.relpath(path, ROOT), img.size)


def contact_sheet(path: str):
    """把主要素材放大 4 倍拼成一张预览图，便于人工检查。"""
    items = [
        ("char_0.png", char_sheet(0)),
        ("char_1.png", char_sheet(1)),
        ("char_2.png", char_sheet(2)),
        ("char_3.png", char_sheet(3)),
        ("bomb.png", bomb_sheet()),
        ("flame_center.png", flame_dir_sheet("center")),
        ("flame_arm_h.png", flame_dir_sheet("arm_h")),
        ("flame_arm_v.png", flame_dir_sheet("arm_v")),
        ("flame_tip_h.png", flame_dir_sheet("tip_h")),
        ("flame_tip_v.png", flame_dir_sheet("tip_v")),
        ("powerup.png", powerup_sheet()),
        ("icons.png", icon_sheet()),
        ("tile_floor_0.png", floor_tile(0)),
        ("tile_floor_1.png", floor_tile(1)),
        ("tile_wall.png", wall_tile()),
        ("tile_crate_0.png", crate_tile(0)),
        ("tile_crate_1.png", crate_tile(1)),
        ("tile_crate_2.png", crate_tile(2)),
    ]
    scale = 4
    pad = 8
    rows = []
    for _, img in items:
        rows.append(img.resize((img.width * scale, img.height * scale), Image.NEAREST))
    width = max(r.width for r in rows) + pad * 2
    height = sum(r.height + pad for r in rows) + pad
    sheet = Image.new("RGBA", (width, height), (14, 14, 22, 255))
    y = pad
    for r in rows:
        sheet.alpha_composite(r, (pad, y))
        y += r.height + pad
    sheet.save(path)
    print("wrote", os.path.relpath(path, ROOT), sheet.size)


def main():
    os.makedirs(OUT, exist_ok=True)
    for i in range(4):
        save(char_sheet(i), f"char_{i}.png")
    save(bomb_sheet(), "bomb.png")
    for kind in ("center", "arm_h", "arm_v", "tip_h", "tip_v"):
        save(flame_dir_sheet(kind), f"flame_{kind}.png")
    save(powerup_sheet(), "powerup.png")
    save(icon_sheet(), "icons.png")
    save(floor_tile(0), "tile_floor_0.png")
    save(floor_tile(1), "tile_floor_1.png")
    save(wall_tile(), "tile_wall.png")
    for s in range(3):
        save(crate_tile(s), f"tile_crate_{s}.png")
    save(app_icon(), "icon.png")
    save(menu_backdrop(), "backdrop.png")
    contact_sheet(os.path.join(ROOT, "docs", "art_preview.png"))


if __name__ == "__main__":
    main()
