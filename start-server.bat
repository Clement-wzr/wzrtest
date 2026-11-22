@echo off
chcp 65001 >nul
title EVERGREEN · 手势粒子圣诞树
cd /d "%~dp0"

where python >nul 2>nul
if not errorlevel 1 goto run_python

where py >nul 2>nul
if not errorlevel 1 goto run_py

echo.
echo [EVERGREEN] 没有找到 Python。
echo 请先安装 Python 3，或使用任意本地静态服务器打开这个目录。
echo 例如在安装了 Node.js 的情况下运行:  npx serve .
echo.
pause
exit /b 1

:run_python
python serve.py
goto end

:run_py
py -3 serve.py
goto end

:end
if errorlevel 1 pause
