"""火拼炸弹堂 3D 概念图后期：统一调色 + 暗角 + 颗粒 + 角标。

输入 docs/concept3d/c3d_*.png（Godot 直出），输出同名成品，
原图备份到 docs/concept3d/raw/。
用法: python tools/grade_concept.py
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "docs", "concept3d")
RAW = os.path.join(SRC, "raw")
FONT_PATH = "C:/Windows/Fonts/msyh.ttc"

CAPTIONS = {
    "c3d_01_arena": "全场 3/4 视角 · 可破坏掩体与连锁爆炸",
    "c3d_02_topdown": "玩法视角 · 俯角约 50°，一眼看清全场",
    "c3d_03_hero": "角色特写 · Q 版比例 + 边缘光",
    "c3d_04_poster": "对决赛海报 · 双色阵营与引信倒计时",
    "c3d_05_blast": "爆炸瞬间 · 火柱、体积光与烘焙接触阴影",
    "c3d_06_grass": "草丛版场地 · 掩体换成齐腰深的草，只挡视线不挡路",
    "c3d_07_ambush": "草里视角 · 你看得见外面，外面看不见你",
}


def srgb_to_linear(x: np.ndarray) -> np.ndarray:
    return np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(x: np.ndarray) -> np.ndarray:
    x = np.clip(x, 0.0, 1.0)
    return np.where(x <= 0.0031308, x * 12.92, 1.055 * (x ** (1 / 2.4)) - 0.055)


def grade(img: Image.Image) -> Image.Image:
    a = np.asarray(img.convert("RGB"), dtype=np.float32) / 255.0
    lin = srgb_to_linear(a)

    # 轻微提亮 + S 曲线：压暗部、提中间调
    lin = np.clip(lin * 1.10, 0, 1)
    lin = np.clip((lin - 0.5) * 1.06 + 0.5, 0, 1)
    lin = lin ** 0.95

    # 冷暗部 / 暖高光
    lum = (lin[..., 0] * 0.2126 + lin[..., 1] * 0.7152 + lin[..., 2] * 0.0722)[..., None]
    cool = np.array([0.95, 0.98, 1.08], dtype=np.float32)
    warm = np.array([1.04, 1.0, 0.95], dtype=np.float32)
    tint = cool * (1 - lum) + warm * lum
    lin = np.clip(lin * tint, 0, 1)

    # 暗角
    h, w, _ = lin.shape
    yy, xx = np.mgrid[0:h, 0:w]
    nx = (xx - w / 2) / (w / 2)
    ny = (yy - h / 2) / (h / 2)
    r = np.sqrt(nx ** 2 + ny ** 2) / 1.414
    vig = np.clip(1.0 - 0.30 * r ** 2.2, 0.0, 1.0)[..., None]
    lin *= vig

    # 颗粒
    rng = np.random.default_rng(7)
    grain = rng.normal(0, 0.004, lin.shape).astype(np.float32)
    lin = np.clip(lin + grain, 0, 1)

    return Image.fromarray((linear_to_srgb(lin) * 255).astype(np.uint8))


def caption(img: Image.Image, text: str) -> Image.Image:
    canvas = img.convert("RGBA")
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    try:
        font = ImageFont.truetype(FONT_PATH, 24)
        small = ImageFont.truetype(FONT_PATH, 16)
    except OSError:
        font = ImageFont.load_default()
        small = font
    x, y = 44, canvas.height - 72
    # 文字底衬，保证在亮地面上也能读
    d.rounded_rectangle([x - 18, y - 18, x + 560, y + 62], radius=10, fill=(6, 8, 14, 150))
    d.rectangle([x, y, x + 4, y + 30], fill=(255, 179, 71, 230))
    d.text((x + 16, y - 2), text, font=font, fill=(238, 241, 250, 235))
    d.text((x + 16, y + 30), "火拼炸弹堂 · BOMB BLITZ ARENA · 3D CONCEPT", font=small, fill=(150, 160, 190, 210))
    return Image.alpha_composite(canvas, layer).convert("RGB")


def main() -> None:
    os.makedirs(RAW, exist_ok=True)
    for name, text in CAPTIONS.items():
        src = os.path.join(SRC, name + ".png")
        if not os.path.exists(src):
            print("skip", name)
            continue
        raw_dst = os.path.join(RAW, name + ".png")
        if not os.path.exists(raw_dst):
            Image.open(src).save(raw_dst)
            print("backup", os.path.relpath(raw_dst, ROOT))
        img = Image.open(raw_dst)
        out = caption(grade(img), text)
        out.save(src, quality=95)
        print("graded", os.path.relpath(src, ROOT), out.size)


if __name__ == "__main__":
    main()
