param([Parameter(Mandatory = $true)][string]$GodotExecutable)
$ErrorActionPreference = "Stop"
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$port = Get-Random -Minimum 20000 -Maximum 50000
$out = [System.IO.Path]::GetTempFileName()
$err = [System.IO.Path]::GetTempFileName()
try {
	$arguments = @("--headless", "--path", ('"{0}"' -f $projectPath), "--script", "res://tests/m5_recovery_test.gd", "--", "--host", "--port=$port")
	$process = Start-Process -FilePath $GodotExecutable -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
	$output = (Get-Content -LiteralPath $out, $err) -join "`n"
	Write-Output $output
	if ($process.ExitCode -ne 0 -or $output -match "ERROR:|SCRIPT ERROR:" -or $output -notmatch "M5 recovery checks passed") {
		throw "M5 recovery check failed (exit code: $($process.ExitCode))"
	}
} finally {
	Remove-Item -LiteralPath $out, $err -Force
}
& (Join-Path $PSScriptRoot "run_m4_ragdoll_checks.ps1") -GodotExecutable $GodotExecutable -Targets @("auto")
