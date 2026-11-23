@echo off
setlocal EnableExtensions
title Fowl Play - Game Loop Checks

echo ==========================================
echo   FOWL PLAY - GAME LOOP CHECKS
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
echo Set FOWL_PLAY_GODOT or edit the path in this file.
pause
exit /b 2

:check_godot
if not exist "%GODOT%" goto invalid_godot

echo Using Godot: "%GODOT%"
echo Project: "%PROJECT%"
echo.
echo [1/10] Importing project resources...
"%GODOT%" --headless --editor --path "%PROJECT%" --import
if errorlevel 1 goto failed

call :run_test res://tests/casino_wallet_test.gd "Shared wallet"
if errorlevel 1 goto failed
call :run_test res://tests/base_table_test.gd "BaseTable lifecycle"
if errorlevel 1 goto failed
call :run_test res://tests/chicken_cross_rules_test.gd "Chicken Cross rules"
if errorlevel 1 goto failed
call :run_test res://tests/betting_keypad_test.gd "Betting keypad and wager confirmation"
if errorlevel 1 goto failed
call :run_test res://tests/chicken_cross_table_test.gd "Chicken Cross table and multiplayer outcomes"
if errorlevel 1 goto failed
call :run_test res://tests/casino_day_manager_test.gd "Five-minute day and quota"
if errorlevel 1 goto failed
call :run_test res://tests/run_manager_test.gd "Day 1-10 outer-loop progression"
if errorlevel 1 goto failed
call :run_test res://tests/casino_table_spawner_test.gd "Six-slot spawning and Chicken Cross test fallback"
if errorlevel 1 goto failed
call :run_test res://tests/elevator_departure_test.gd "Elevator all-player departure gate"
if errorlevel 1 goto failed
call :run_test res://tests/elevator_occupancy_test.gd "Elevator occupant and carried-player tracking"
call :run_test res://tests/elevator_door_collision_test.gd "Elevator door panel collision"
if errorlevel 1 goto failed

echo.
echo ==========================================
echo   ALL GAME LOOP CHECKS PASSED
echo ==========================================
pause
exit /b 0

:run_test
echo.
echo Running %~2 checks...
"%GODOT%" --headless --path "%PROJECT%" --script "%~1"
if errorlevel 1 exit /b 1
exit /b 0

:invalid_godot
echo ERROR: Godot executable not found: "%GODOT%"
goto failed

:failed
echo.
echo ==========================================
echo   GAME LOOP CHECKS FAILED
echo ==========================================
pause
exit /b 1
