@echo off
setlocal

set "GODOT=%ProgramFiles(x86)%\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
if not exist "%GODOT%" (
	echo Could not find Steam Godot at:
	echo %GODOT%
	echo.
	echo Edit the GODOT path near the top of this file to match your Steam installation.
	pause
	exit /b 2
)

set "PROJECT=%~dp0.."
echo Importing Fowl Play project...
"%GODOT%" --headless --editor --path "%PROJECT%" --import
if errorlevel 1 goto failed

echo.
echo Running shared wallet checks...
"%GODOT%" --headless --path "%PROJECT%" --script res://tests/casino_wallet_test.gd
if errorlevel 1 goto failed

echo.
echo Running BaseTable checks...
"%GODOT%" --headless --path "%PROJECT%" --script res://tests/base_table_test.gd
if errorlevel 1 goto failed

echo.
echo ALL CASINO CHECKS PASSED
pause
exit /b 0

:failed
echo.
echo CASINO CHECKS FAILED. Review the error output above.
pause
exit /b 1
