param([Parameter(Mandatory = $true)][string]$GodotExecutable)
$ErrorActionPreference = "Stop"
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

foreach ($case in @(
	@{ Hz = 30; Ragdolls = 0 },
	@{ Hz = 15; Ragdolls = 4 },
	@{ Hz = 30; Ragdolls = 4 },
	@{ Hz = 60; Ragdolls = 4 }
)) {
	$port = Get-Random -Minimum 20000 -Maximum 50000
	$out = [System.IO.Path]::GetTempFileName()
	$err = [System.IO.Path]::GetTempFileName()
	try {
		$arguments = @("--headless", "--path", ('"{0}"' -f $projectPath), "--script", "res://tests/m4_ragdoll_profile_test.gd", "--", "--host", "--port=$port", "--profile-hz=$($case.Hz)", "--ragdolls=$($case.Ragdolls)", "--seconds=7")
		$started = [DateTime]::UtcNow
		$process = Start-Process -FilePath $GodotExecutable -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
		$null = $process.Handle
		if (-not $process.WaitForExit(30000)) {
			$process.Kill()
			throw "M4 profile timed out"
		}
		$process.WaitForExit()
		$wallMs = ([DateTime]::UtcNow - $started).TotalMilliseconds
		$cpuMs = $process.TotalProcessorTime.TotalMilliseconds
		$output = (Get-Content -LiteralPath $out, $err) -join "`n"
		$profileLine = ($output -split "`n" | Where-Object { $_ -match '^M4 PROFILE' }) -join ""
		if ($process.ExitCode -ne 0 -or $output -match "ERROR:|SCRIPT ERROR:" -or -not $profileLine) {
			throw "M4 profile failed: $output"
		}
		Write-Output $profileLine
		Write-Output ("M4 CPU hz={0} ragdolls={1} process_cpu_ms={2:N0} wall_ms={3:N0} one_core_pct={4:N1}" -f $case.Hz, $case.Ragdolls, $cpuMs, $wallMs, (100.0 * $cpuMs / $wallMs))
	} finally {
		Remove-Item -LiteralPath $out, $err -Force
	}
}
