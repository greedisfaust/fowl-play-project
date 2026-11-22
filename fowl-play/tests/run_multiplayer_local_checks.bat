@echo off
setlocal EnableExtensions
title Fowl Play - Local Multiplayer Test

echo ==========================================
echo   FOWL PLAY - LOCAL MULTIPLAYER TEST
echo ==========================================
echo.
set "PROJECT=%~dp0.."
set "GODOT=%FOWL_PLAY_GODOT%"
if defined GODOT goto check_godot

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
set /p "GODOT=Godot executable path: "
if not defined GODOT goto failed

:check_godot
if not exist "%GODOT%" goto invalid_godot
echo Using Godot: "%GODOT%"
echo Project: "%PROJECT%"
echo.
set /p "INSTANCE_COUNT=How many game windows? Enter 2 for host/client, up to 5 for capacity testing [2]: "
if not defined INSTANCE_COUNT set "INSTANCE_COUNT=2"
echo %INSTANCE_COUNT%| findstr /r "^[2-5]$" >nul
if errorlevel 1 (
    echo Please enter a number from 2 to 5.
    goto failed
)
echo.
echo Opening %INSTANCE_COUNT% independent game instances...
for /L %%I in (1,1,%INSTANCE_COUNT%) do (
    start "Fowl Play Instance %%I" "%GODOT%" --path "%PROJECT%"
    timeout /t 3 /nobreak >nul
)
echo.
echo First window: choose HOST at the Lobby Host / Join terminal.
echo Other windows: choose JOIN and enter 127.0.0.1.
echo Follow docs/NETWORK_MULTIPLAYER_VERIFICATION.md.
echo.
echo All game windows are independent. Close them individually after testing.
exit /b 0

:invalid_godot
echo Godot executable was not found: "%GODOT%"
goto failed

:failed
echo.
echo Multiplayer test launcher could not start.
pause
exit /b 1
