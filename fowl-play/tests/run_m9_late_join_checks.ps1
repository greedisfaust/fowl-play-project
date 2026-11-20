param([Parameter(Mandatory = $true)][string]$GodotExecutable)
$ErrorActionPreference = "Stop"
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$port = Get-Random -Minimum 20000 -Maximum 50000
$hostOut = [System.IO.Path]::GetTempFileName()
$hostErr = [System.IO.Path]::GetTempFileName()
$clientOut = [System.IO.Path]::GetTempFileName()
$clientErr = [System.IO.Path]::GetTempFileName()
$hostProcess = $null
$clientProcess = $null
try {
	$hostArgs = @("--headless", "--path", ('"{0}"' -f $projectPath), "--script", "res://tests/m9_late_join_test.gd", "--", "--test-role=host", "--host", "--port=$port")
	$hostProcess = Start-Process -FilePath $GodotExecutable -ArgumentList $hostArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $hostOut -RedirectStandardError $hostErr
	$deadline = [DateTime]::UtcNow.AddSeconds(12)
	do {
		Start-Sleep -Milliseconds 100
		$hostText = (Get-Content -LiteralPath $hostOut, $hostErr) -join "`n"
		if ($hostProcess.HasExited -and $hostText -notmatch "M9_RECOVERY_STARTED") { throw "M9 host exited before recovery: $hostText" }
	} until ($hostText -match "M9_RECOVERY_STARTED x=([-0-9.]+) y=([-0-9.]+) z=([-0-9.]+)" -or [DateTime]::UtcNow -gt $deadline)
	$match = [regex]::Match($hostText, "M9_RECOVERY_STARTED x=([-0-9.]+) y=([-0-9.]+) z=([-0-9.]+)")
	if (-not $match.Success) { throw "M9 host did not reach recovery before timeout: $hostText" }
	$x = $match.Groups[1].Value; $y = $match.Groups[2].Value; $z = $match.Groups[3].Value
	$clientArgs = @("--headless", "--path", ('"{0}"' -f $projectPath), "--script", "res://tests/m9_late_join_test.gd", "--", "--test-role=client", "--join=127.0.0.1", "--port=$port", "--expected-x=$x", "--expected-y=$y", "--expected-z=$z")
	$clientProcess = Start-Process -FilePath $GodotExecutable -ArgumentList $clientArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $clientOut -RedirectStandardError $clientErr
	if (-not $clientProcess.WaitForExit(15000)) { throw "M9 client process timed out" }
	$clientText = (Get-Content -LiteralPath $clientOut, $clientErr) -join "`n"
	Write-Output $clientText
	if ($clientProcess.ExitCode -ne 0 -or $clientText -match "ERROR:|SCRIPT ERROR:" -or $clientText -notmatch "M9 PASS client") { throw "M9 client verification failed (exit code $($clientProcess.ExitCode))" }
	if (-not $hostProcess.WaitForExit(10000)) { throw "M9 host process timed out" }
	$hostText = (Get-Content -LiteralPath $hostOut, $hostErr) -join "`n"
	Write-Output $hostText
	if ($hostProcess.ExitCode -ne 0 -or $hostText -match "ERROR:|SCRIPT ERROR:" -or $hostText -notmatch "M9 PASS host") { throw "M9 host verification failed (exit code $($hostProcess.ExitCode))" }
} finally {
	foreach ($process in @($clientProcess, $hostProcess)) {
		if ($null -ne $process -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
	}
	Remove-Item -LiteralPath $hostOut, $hostErr, $clientOut, $clientErr -Force
}
