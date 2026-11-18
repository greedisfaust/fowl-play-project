param([Parameter(Mandatory = $true)][string]$GodotExecutable)
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$testPort = Get-Random -Minimum 20000 -Maximum 50000
$jobs = @()
function Start-RosterProcess([string]$Role) {
    $outPath = [System.IO.Path]::GetTempFileName()
    $errPath = [System.IO.Path]::GetTempFileName()
    $arguments = @('--headless', '--path', ('"{0}"' -f $projectPath), '--script', 'res://tests/m3_roster_test.gd', '--', "--test-role=$Role", "--port=$testPort")
    if ($Role -eq 'host') { $arguments += '--host' } else { $arguments += '--join=127.0.0.1' }
    $process = Start-Process -FilePath $GodotExecutable -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $outPath -RedirectStandardError $errPath
    $null = $process.Handle
    return @{ Process = $process; Out = $outPath; Err = $errPath }
}
function Wait-Ready($Job, [string]$Marker) {
    $deadline = [DateTime]::UtcNow.AddSeconds(12)
    do {
        $output = Get-Content -LiteralPath $Job.Out -Raw
        if ($output -match $Marker) { return }
        if ($Job.Process.HasExited) { throw "Roster process exited early: $output $(Get-Content -LiteralPath $Job.Err -Raw)" }
        Start-Sleep -Milliseconds 50
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out waiting for $Marker"
}
try {
    $hostJob = Start-RosterProcess 'host'
    $jobs += $hostJob
    Wait-Ready $hostJob 'ROSTER HOST READY'
    $clientJob = Start-RosterProcess 'client'
    $jobs += $clientJob
    Wait-Ready $clientJob 'ROSTER CLIENT READY'
    $lateJob = Start-RosterProcess 'late'
    $jobs += $lateJob
    foreach ($job in $jobs) {
        if (-not $job.Process.WaitForExit(35000)) { throw 'Roster test timed out' }
        $job.Process.WaitForExit()
        $output = (Get-Content -LiteralPath $job.Out,$job.Err) -join "`n"
        Write-Output $output
        if ($job.Process.ExitCode -ne 0 -or $output -match 'ERROR:|SCRIPT ERROR:' -or $output -notmatch 'M3 ROSTER PASS') { throw 'Roster verification failed' }
    }
} finally {
    foreach ($job in $jobs) {
        if (-not $job.Process.HasExited) { $job.Process.Kill(); $job.Process.WaitForExit() }
        Remove-Item -LiteralPath $job.Out,$job.Err -Force
    }
}
