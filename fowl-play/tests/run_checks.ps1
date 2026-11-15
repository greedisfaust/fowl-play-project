$ErrorActionPreference = "Stop"

$godot = $env:FOWL_PLAY_GODOT
if ([string]::IsNullOrWhiteSpace($godot)) {
	$godotCommand = Get-Command godot -ErrorAction SilentlyContinue
	if ($null -ne $godotCommand) {
		$godot = $godotCommand.Source
	} else {
		$godot = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
	}
}
if (-not (Test-Path -LiteralPath $godot)) {
	throw "Godot executable not found. Set FOWL_PLAY_GODOT or add godot to PATH."
}
$project = Join-Path $PSScriptRoot ".."
$output = @(& $godot --headless --path $project --script res://tests/d0_debug_hub_test.gd 2>&1)
$exitCode = $LASTEXITCODE
$output | ForEach-Object { Write-Output $_ }

if ($exitCode -ne 0) {
	throw "Godot checks failed with exit code $exitCode."
}

$outputText = $output -join "`n"
if ($outputText -match "ERROR:|SCRIPT ERROR:") {
	throw "Godot checks emitted an error."
}
