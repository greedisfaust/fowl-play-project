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
foreach ($stage in @("import", "d0", "m1", "m2", "m3", "m3-interaction", "m4-handoff")) {
	$checkStdout = [System.IO.Path]::GetTempFileName()
	$checkStderr = [System.IO.Path]::GetTempFileName()
	$arguments = @("--headless", "--path", ('"{0}"' -f $project))
	if ($stage -eq "import") { $arguments += @("--editor", "--import") }
	elseif ($stage -eq "d0") { $arguments += @("--script", "res://tests/d0_debug_hub_test.gd") }
	elseif ($stage -eq "m1") { $arguments += @("--script", "res://tests/m1_interaction_test.gd") }
	elseif ($stage -eq "m2") { $arguments += @("--script", "res://tests/m2_hands_test.gd") }
	elseif ($stage -eq "m3-interaction") { $arguments += @("--script", "res://tests/m3_interaction_test.gd") }
	elseif ($stage -eq "m4-handoff") { $arguments += @("--script", "res://tests/m4_limp_handoff_test.gd") }
	else { $arguments += @("--script", "res://tests/m3_movement_test.gd") }
	try {
		$checkProcess = Start-Process -FilePath $godot -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $checkStdout -RedirectStandardError $checkStderr
		$exitCode = $checkProcess.ExitCode
		$output = @(Get-Content -LiteralPath $checkStdout, $checkStderr)
	} finally {
		Remove-Item -LiteralPath $checkStdout, $checkStderr -Force
	}
	$output | ForEach-Object { Write-Output $_ }
	if ($exitCode -ne 0 -or ($output -join "`n") -match "ERROR:|SCRIPT ERROR:") {
		throw "Godot $stage failed (exit code: $exitCode)."
	}
}
& (Join-Path $PSScriptRoot "run_m0_checks.ps1") -GodotExecutable $godot
& (Join-Path $PSScriptRoot "run_m3_roster_checks.ps1") -GodotExecutable $godot
& (Join-Path $PSScriptRoot "run_m4_ragdoll_checks.ps1") -GodotExecutable $godot
& (Join-Path $PSScriptRoot "run_m5_recovery_checks.ps1") -GodotExecutable $godot
