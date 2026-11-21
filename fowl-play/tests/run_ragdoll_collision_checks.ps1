param([Parameter(Mandatory = $true)][string]$GodotExecutable)
$ErrorActionPreference = "Stop"
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$out = [System.IO.Path]::GetTempFileName()
$err = [System.IO.Path]::GetTempFileName()
try {
	$arguments = @("--headless", "--path", ('"{0}"' -f $projectPath), "--script", "res://tests/m4_limp_handoff_test.gd")
	$process = Start-Process -FilePath $GodotExecutable -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
	$output = (Get-Content -LiteralPath $out, $err) -join "`n"
	Write-Output $output
	if ($process.ExitCode -ne 0 -or $output -match "ERROR:|SCRIPT ERROR:" -or $output -notmatch "M4 limp handoff checks passed") {
		throw "Ragdoll collision check failed (exit code: $($process.ExitCode))"
	}
} finally {
	Remove-Item -LiteralPath $out, $err -Force
}
