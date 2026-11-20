param(
	[string]$OnlyStage = "all"
)

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
$stages = @("import", "d0", "m1", "m1-cursor", "m2", "m2-arm-ik", "m7-jab", "m3", "m3-interaction", "m4-handoff", "m6", "procedural-legs", "movement-presentation", "m9-lifecycle", "identity", "identity-presentation", "physical-button", "screen-text", "world-screen", "slim-world-screen", "fat-world-screen", "screen-menu", "registration-terminal", "interactive-terminal")
if ($OnlyStage -ne "all") {
	if ($stages -notcontains $OnlyStage) {
		throw "Unknown test stage '$OnlyStage'. Available stages: $($stages -join ', ')"
	}
	$stages = @($OnlyStage)
}
foreach ($stage in $stages) {
	$checkStdout = [System.IO.Path]::GetTempFileName()
	$checkStderr = [System.IO.Path]::GetTempFileName()
	$arguments = @("--headless", "--path", ('"{0}"' -f $project))
	if ($stage -eq "import") { $arguments += @("--editor", "--import") }
	elseif ($stage -eq "d0") { $arguments += @("--script", "res://tests/d0_debug_hub_test.gd") }
	elseif ($stage -eq "m1") { $arguments += @("--script", "res://tests/m1_interaction_test.gd") }
	elseif ($stage -eq "m1-cursor") { $arguments += @("--script", "res://tests/m1_cursor_test.gd") }
	elseif ($stage -eq "m2") { $arguments += @("--script", "res://tests/m2_hands_test.gd") }
	elseif ($stage -eq "m2-arm-ik") { $arguments += @("--script", "res://tests/m2_procedural_arm_test.gd") }
	elseif ($stage -eq "m7-jab") { $arguments += @("--script", "res://tests/m7_jab_test.gd") }
	elseif ($stage -eq "m3-interaction") { $arguments += @("--script", "res://tests/m3_interaction_test.gd") }
	elseif ($stage -eq "m4-handoff") { $arguments += @("--script", "res://tests/m4_limp_handoff_test.gd") }
	elseif ($stage -eq "m6") { $arguments += @("--script", "res://tests/m6_carry_test.gd") }
	elseif ($stage -eq "procedural-legs") { $arguments += @("--script", "res://tests/m8_procedural_legs_test.gd") }
	elseif ($stage -eq "movement-presentation") { $arguments += @("--script", "res://tests/m8_movement_presentation_test.gd") }
	elseif ($stage -eq "m9-lifecycle") { $arguments += @("--script", "res://tests/m9_lifecycle_test.gd") }
	elseif ($stage -eq "identity") { $arguments += @("--script", "res://tests/m3_identity_test.gd") }
	elseif ($stage -eq "identity-presentation") { $arguments += @("--script", "res://tests/m3_player_identity_presentation_test.gd") }
	elseif ($stage -eq "physical-button") { $arguments += @("--script", "res://tests/m3_physical_use_button_test.gd") }
	elseif ($stage -eq "screen-text") { $arguments += @("--script", "res://tests/m3_screen_text_test.gd") }
	elseif ($stage -eq "world-screen") { $arguments += @("--script", "res://tests/m3_world_screen_test.gd") }
	elseif ($stage -eq "slim-world-screen") { $arguments += @("--script", "res://tests/m3_slim_world_screen_test.gd") }
	elseif ($stage -eq "fat-world-screen") { $arguments += @("--script", "res://tests/m3_fat_world_screen_test.gd") }
	elseif ($stage -eq "screen-menu") { $arguments += @("--script", "res://tests/m3_screen_menu_test.gd") }
	elseif ($stage -eq "registration-terminal") { $arguments += @("--script", "res://tests/m3_registration_terminal_test.gd") }
	elseif ($stage -eq "interactive-terminal") { $arguments += @("--script", "res://tests/m3_interactive_terminal_test.gd") }
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
& (Join-Path $PSScriptRoot "run_m9_late_join_checks.ps1") -GodotExecutable $godot
