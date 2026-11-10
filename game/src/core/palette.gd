class_name Pal
extends RefCounted
## 全局配色与尺寸常量。

# 场景
const BG := Color("12131c")
const BG_DEEP := Color("0c0c13")
const PANEL := Color("1b1d2b")
const PANEL_SOFT := Color("232637")
const LINE := Color("3b4160")
const LINE_SOFT := Color("2a2e44")

# 文字
const TEXT := Color("eef1fa")
const TEXT_DIM := Color("9aa3c0")
const TEXT_WARN := Color("ffb347")

# 强调
const AMBER := Color("ffb347")
const CYAN := Color("55d6ff")
const MAGENTA := Color("ff5c8a")
const LIME := Color("8be04e")

# 玩家
const P_COLORS: Array[Color] = [
	Color("e24a42"), Color("428ae8"), Color("4ec462"), Color("f0c43e"),
]
const P_LIGHT: Array[Color] = [
	Color("ff8a80"), Color("8ec4ff"), Color("9ae8a6"), Color("ffe08a"),
]

# 场地
const TILE := 48
const COLS := 15
const ROWS := 11
const ARENA_POS := Vector2(280, 112)
const ARENA_SIZE := Vector2(COLS * TILE, ROWS * TILE)

# 布局
const VIEW := Vector2(1280, 720)
