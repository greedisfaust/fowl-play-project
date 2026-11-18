param(
	[Parameter(Mandatory = $true)][string]$GodotExecutable,
	[string[]]$Targets = @("host", "client", "late", "late_settled", "rate15", "rate60")
)
$ErrorActionPreference = "Stop"
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$port = Get-Random -Minimum 20000 -Maximum 50000
$jobs = @()

function Start-M4Process([string]$Role, [string]$Target) {
	$out = [System.IO.Path]::GetTempFileName()
	$err = [System.IO.Path]::GetTempFileName()
	$testRole = if ($Target -like "late*" -and $Role -eq "client") { "late" } else { $Role }
	$testTarget = if ($Target -like "late*" -or $Target -like "rate*" -or $Target -eq "auto") { "host" } else { $Target }
	$testRate = if ($Target -like "rate*") { [int]($Target -replace '^rate', '') } else { 30 }
	$arguments = @("--headless", "--path", ('"{0}"' -f $projectPath), "--script", "res://tests/m4_ragdoll_network_test.gd", "--", "--test-role=$testRole", "--test-target=$testTarget", "--port=$port")
	$arguments += "--test-rate=$testRate"
	if ($Target -eq "auto") { $arguments += "--test-auto-recovery" }
	if ($Target -like "late*") { $arguments += "--test-late" }
	if ($Target -eq "late_settled") { $arguments += "--test-join-after-settled" }
	if ($Role -eq "host") { $arguments += "--host" } else { $arguments += "--join=127.0.0.1" }
	$process = Start-Process -FilePath $GodotExecutable -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
	$null = $process.Handle
	return @{ Process = $process; Out = $out; Err = $err }
}

try {
	foreach ($target in $Targets) {
		$port = Get-Random -Minimum 20000 -Maximum 50000
		$hostJob = Start-M4Process "host" $target
		$jobs += $hostJob
		$deadline = [DateTime]::UtcNow.AddSeconds(8)
		do {
			Start-Sleep -Milliseconds 100
			$hostOutput = Get-Content -LiteralPath $hostJob.Out -Raw
			if ($hostJob.Process.HasExited) { throw "M4 host exited early: $hostOutput $(Get-Content -LiteralPath $hostJob.Err -Raw)" }
		} until ($hostOutput -match "Host started on port" -or [DateTime]::UtcNow -gt $deadline)
		if ($hostOutput -notmatch "Host started on port") { throw "M4 host did not start" }
		if ($target -like "late*") {
			$deadline = [DateTime]::UtcNow.AddSeconds(8)
			do {
				Start-Sleep -Milliseconds 100
				$hostOutput = Get-Content -LiteralPath $hostJob.Out -Raw
				if ($hostJob.Process.HasExited) { throw "M4 host exited before late join: $hostOutput" }
			} until ($hostOutput -match "Ragdoll spike started" -or [DateTime]::UtcNow -gt $deadline)
			if ($hostOutput -notmatch "Ragdoll spike started") { throw "M4 host did not start ragdoll before late join" }
			if ($target -eq "late_settled") {
				$deadline = [DateTime]::UtcNow.AddSeconds(8)
				do {
					Start-Sleep -Milliseconds 100
					$hostOutput = Get-Content -LiteralPath $hostJob.Out -Raw
					if ($hostJob.Process.HasExited) { throw "M4 host exited before settled late join: $hostOutput" }
				} until ($hostOutput -match "Ragdoll settled for peer" -or [DateTime]::UtcNow -gt $deadline)
				if ($hostOutput -notmatch "Ragdoll settled for peer") { throw "M4 host did not settle before late join" }
			}
		}
		$clientJob = Start-M4Process "client" $target
		$jobs += $clientJob
		foreach ($job in @($hostJob, $clientJob)) {
			if (-not $job.Process.WaitForExit(20000)) { throw "M4 process timed out" }
			$job.Process.WaitForExit()
			$output = (Get-Content -LiteralPath $job.Out, $job.Err) -join "`n"
			Write-Output $output
			if ($job.Process.ExitCode -ne 0 -or $output -match "ERROR:|SCRIPT ERROR:" -or $output -notmatch "M4 PASS") {
				throw "M4 verification failed (exit code: $($job.Process.ExitCode))"
			}
		}
	}
} finally {
	foreach ($job in $jobs) {
		if (-not $job.Process.HasExited) { $job.Process.Kill(); $job.Process.WaitForExit() }
		Remove-Item -LiteralPath $job.Out, $job.Err -Force
	}
}
