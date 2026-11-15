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
$checkStdout = [System.IO.Path]::GetTempFileName()
$checkStderr = [System.IO.Path]::GetTempFileName()
try {
	$checkProcess = Start-Process -FilePath $godot -ArgumentList @(
		"--headless", "--path", ('"{0}"' -f $project),
		"--script", "res://tests/d0_debug_hub_test.gd"
	) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $checkStdout -RedirectStandardError $checkStderr
	$exitCode = $checkProcess.ExitCode
	$output = @(Get-Content -LiteralPath $checkStdout, $checkStderr)
} finally {
	Remove-Item -LiteralPath $checkStdout, $checkStderr -Force
}
$output | ForEach-Object { Write-Output $_ }

if ($exitCode -ne 0) {
	throw "Godot checks failed with exit code $exitCode."
}

$outputText = $output -join "`n"
if ($outputText -match "ERROR:|SCRIPT ERROR:") {
	throw "Godot checks emitted an error."
}
