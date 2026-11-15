param([Parameter(Mandatory = $true)][string]$GodotExecutable)
$ErrorActionPreference = "Stop"
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$jobs = @()

function Start-M0Process([string]$Role, [string]$Scenario, [int]$Port) {
	$stdoutPath = [System.IO.Path]::GetTempFileName()
	$stderrPath = [System.IO.Path]::GetTempFileName()
	$arguments = @("--headless", "--path", ('"{0}"' -f $projectPath), "--script", "res://tests/m0_network_test.gd", "--", "--test-role=$Role", "--test-case=$Scenario", "--port=$Port")
	if (-not $Scenario.StartsWith("console-")) {
		if ($Role -eq "host") { $arguments += "--host" }
		if ($Role -eq "client") { $arguments += "--join=127.0.0.1" }
	}
	$process = Start-Process -FilePath $GodotExecutable -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
	$null = $process.Handle
	return @{ Process = $process; Out = $stdoutPath; Err = $stderrPath }
}

function Complete-M0Process($Job) {
	if (-not $Job.Process.WaitForExit(20000)) { throw "M0 process timed out" }
	$Job.Process.WaitForExit()
	$output = (Get-Content -LiteralPath $Job.Out, $Job.Err) -join "`n"
	Write-Output $output
	if ($Job.Process.ExitCode -ne 0 -or $output -match "ERROR:|SCRIPT ERROR:" -or $output -notmatch "M0 PASS") {
		throw "M0 verification failed (exit code: $($Job.Process.ExitCode))"
	}
}

try {
	$offline = Start-M0Process "offline" "offline" 7777
	$jobs += $offline
	Complete-M0Process $offline
	foreach ($scenario in @("client-leaves", "host-leaves", "console-client-leaves", "console-host-leaves")) {
		$testPort = Get-Random -Minimum 20000 -Maximum 50000
		$hostJob = Start-M0Process "host" $scenario $testPort
		$jobs += $hostJob
		$deadline = [DateTime]::UtcNow.AddSeconds(8)
		do {
			Start-Sleep -Milliseconds 100
			$hostOutput = Get-Content -LiteralPath $hostJob.Out -Raw
			if ($hostJob.Process.HasExited) { throw "M0 host exited before startup: $hostOutput" }
		} until ($hostOutput -match "Host started on port" -or [DateTime]::UtcNow -gt $deadline)
		if ($hostOutput -notmatch "Host started on port") { throw "M0 host did not start" }
		$clientJob = Start-M0Process "client" $scenario $testPort
		$jobs += $clientJob
		Complete-M0Process $hostJob
		Complete-M0Process $clientJob
	}
} finally {
	foreach ($job in $jobs) {
		if (-not $job.Process.HasExited) { $job.Process.Kill(); $job.Process.WaitForExit() }
		Remove-Item -LiteralPath $job.Out, $job.Err -Force
	}
}
