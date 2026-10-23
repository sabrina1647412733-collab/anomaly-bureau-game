@echo off
setlocal
chcp 65001 >nul
title 得利洗衣店 · 当前工程
cd /d "%~dp0"

REM Optional GODOT_EXE override; otherwise locate the installed matching engine.
if defined GODOT_EXE if exist "%GODOT_EXE%" goto engine_ready
set "GODOT_EXE="
for /f "delims=" %%G in ('where Godot_v4.7.2-stable_win64.exe 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%G"
if not defined GODOT_EXE (
  echo 未找到 Godot 4.7.2。请在 Godot 中导入本目录的 project.godot。
  echo 也可以将 GODOT_EXE 环境变量设为你的 Godot 4.7.2 程序路径。
  pause
  exit /b 1
)

:engine_ready
if not exist "%~dp0project.godot" (
  echo 本目录缺少 project.godot，请保留完整工程。
  pause
  exit /b 1
)
if not exist "%~dp0_预览" mkdir "%~dp0_预览"
echo 正在打开当前工程：%~dp0
"%GODOT_EXE%" --path "%~dp0." --log-file "%~dp0_预览\启动日志.log" %*
set "GAME_EXIT=%ERRORLEVEL%"
if not "%GAME_EXIT%"=="0" (
  echo 启动失败，日志在本工程的 _预览\启动日志.log。
  pause
)
exit /b %GAME_EXIT%
