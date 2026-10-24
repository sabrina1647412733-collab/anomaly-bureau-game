@echo off
setlocal
chcp 65001 >nul
call "%~dp0启动游戏.bat" -- --developer-review
exit /b %ERRORLEVEL%
