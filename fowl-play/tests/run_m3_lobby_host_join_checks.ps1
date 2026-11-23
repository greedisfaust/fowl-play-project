param([Parameter(Mandatory = $true)][string]$GodotExecutable)
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
& $GodotExecutable --headless --path $projectPath --script 'res://tests/m3_lobby_host_join_terminal_test.gd'
if ($LASTEXITCODE -ne 0) { throw 'Lobby Host / Join terminal verification failed.' }
