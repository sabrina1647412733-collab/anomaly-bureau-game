@echo off
chcp 65001 >nul
title 得利洗衣店 · 第一案
cd /d "%~dp0"

REM ===================================================================
REM  得利洗衣店 · 第一案 · 启动器
REM
REM  需要 Godot 4.7.2（必须 4.7，4.3 以下不兼容）
REM  如果你的 Godot 不在下面这个路径，改这一行：
REM ===================================================================
set GODOT="C:\Users\Sabrina\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"

if not exist %GODOT% (
  echo.
  echo  [!] 找不到 Godot： %GODOT%
  echo.
  echo  请改本文件里的 GODOT 变量为你的 Godot 4.7.2 路径。
  echo  或者直接用 Godot 启动器：导入 -^> 选 project.godot -^> 按 F5
  echo.
  pause
  exit /b 1
)

echo 启动 得利洗衣店 · 第一案 ...
%GODOT% --path "%~dp0" res://scenes/main.tscn
