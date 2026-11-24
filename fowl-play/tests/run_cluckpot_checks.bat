@echo off
setlocal EnableExtensions
title Fowl Play - Cluckpot Checks

echo ==========================================
echo   FOWL PLAY - CLUCKPOT CHECKS
echo ==========================================
echo.

set "PROJECT=%~dp0.."
set "GODOT=%FOWL_PLAY_GODOT%"
if not defined GODOT (
    echo Set FOWL_PLAY_GODOT to your Godot executable before running this check.
    goto failed
)
if not exist "%GODOT%" (
    echo ERROR: Godot executable not found: "%GODOT%"
    goto failed
)

echo Using Godot: "%GODOT%"
echo Project: "%PROJECT%"
echo.

echo [1/2] Importing project resources...
"%GODOT%" --headless --editor --path "%PROJECT%" --import
if errorlevel 1 goto failed

echo.
echo [2/2] Running Cluckpot rules and table integration checks...
"%GODOT%" --headless --path "%PROJECT%" --script res://tests/cluckpot_table_test.gd
if errorlevel 1 goto failed

echo.
echo ==========================================
echo   CLUCKPOT CHECKS PASSED
echo ==========================================
pause
exit /b 0

:failed
echo.
echo ==========================================
echo   CLUCKPOT CHECKS FAILED
echo ==========================================
pause
exit /b 1
