@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
if exist "build\火拼炸弹堂.exe" (
    start "" "build\火拼炸弹堂.exe"
    exit /b 0
)
if exist "_tools\godot\Godot_v4.7.2-stable_win64.exe" (
    start "" "_tools\godot\Godot_v4.7.2-stable_win64.exe" --path "game"
    exit /b 0
)
echo 找不到可执行文件：请先运行导出，或把 Godot 引擎放到 _tools\godot\ 下。
pause
