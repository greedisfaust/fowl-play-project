@echo off
setlocal EnableExtensions
title Fowl Play - Lobby Host Join Checks

echo ==========================================
echo   FOWL PLAY - LOBBY HOST / JOIN CHECKS
echo ==========================================
echo.

set "PROJECT=%~dp0.."
set "GODOT=%FOWL_PLAY_GODOT%"
if defined GODOT goto check_godot

rem Try the usual Steam installation location from the Windows registry.
for /f "tokens=2,*" %%A in ('reg query "HKCU\Software\Valve\Steam" /v SteamPath 2^>nul ^| findstr /i "SteamPath"') do set "STEAM_PATH=%%B"
if defined STEAM_PATH (
    set "GODOT=%STEAM_PATH%\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
    if exist "%GODOT%" goto check_godot
    set "GODOT=%STEAM_PATH%\steamapps\common\Godot Engine\godot.windows.opt.tools.64.console.exe"
    if exist "%GODOT%" goto check_godot
)

set "GODOT=%ProgramFiles(x86)%\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
if exist "%GODOT%" goto check_godot
set "GODOT=%ProgramFiles(x86)%\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.console.exe"
if exist "%GODOT%" goto check_godot

echo Could not automatically locate your Steam copy of Godot.
echo.
set /p "GODOT=Godot executable path: "
if not defined GODOT goto no_godot

:check_godot
if not exist "%GODOT%" goto invalid_godot

echo Using Godot: "%GODOT%"
echo Project: "%PROJECT%"
echo.

echo [1/3] Importing project resources...
"%GODOT%" --headless --editor --path "%PROJECT%" --import
if errorlevel 1 goto failed

echo.
echo [2/3] Running Lobby Host / Join terminal checks...
"%GODOT%" --headless --path "%PROJECT%" --script res://tests/m3_lobby_host_join_terminal_test.gd
if errorlevel 1 goto failed

echo.
echo [3/3] Running MainController disconnect / respawn checks...
"%GODOT%" --headless --path "%PROJECT%" --script res://tests/main_controller_test.gd
if errorlevel 1 goto failed

echo.
echo ==========================================
echo   LOBBY HOST / JOIN CHECKS PASSED
echo ==========================================
pause
exit /b 0

:no_godot
echo No Godot executable was provided.
goto failed

:invalid_godot
echo.
echo ERROR: The Godot executable was not found:
echo "%GODOT%"
goto failed

:failed
echo.
echo ==========================================
echo   CHECKS FAILED
echo ==========================================
pause
exit /b 1
