<#
  A MATCH PLAYED TO ITS NATURAL END ON A DEDICATED SERVER, WATCHED FROM INSIDE
  THE REFEREE. Says PASS or FAIL.

      powershell -ExecutionPolicy Bypass -File tools/net/run_dedicated_matchend.ps1

  `run_dedicated_recycle.ps1` covers the ABANDONMENT trigger: the player walks out
  mid-round and the referee finds an empty room. This covers the other one -- the
  player does NOT walk out, four rounds are played, `match_won` fires with a client
  still connected, and the referee has to close the room itself once its post-match
  grace expires.

  ⚠️ THE REFEREE IS THE HARNESS HERE, and that is the point. Only from inside the
  server process can the run assert the thing that makes this a RETURN rather than
  a restart: that the ENet listener and the ServerQuery status socket are still
  open on the other side of the recycle. A client on the far side of the wire
  cannot see either. See `dedicated_recycle_run.gd`'s own § for the rest, including
  why winding the round clock down is not the same as faking the match end.

  ⚠️ PORT 8973, inside the 8970-8979 band this work owns.

  ⚠️ IT DELIBERATELY DOES NOT `Get-Process Godot* | Stop-Process` FIRST, unlike
  every other harness in this tree. Other work on this machine runs its own Godot
  processes, and a global kill here would take those down mid-run just as theirs
  takes these down -- measured, repeatedly, on 2026-08-02. Both processes this
  script starts are tracked by PID and killed by PID.
#>

param(
    [string]$Godot   = 'C:\Users\StarX\Desktop\Godot_v4.7.1-stable_win64.exe',
    [string]$Project = 'C:\Users\StarX\Desktop\SCHOOL\dostgame\DOST-GameDev',
    [int]$Port       = 8973,
    [string]$OutDir  = ''
)

$ErrorActionPreference = 'Stop'

if ($OutDir -eq '') {
    $OutDir = Join-Path $env:TEMP ('dostgame-matchend\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
Write-Host ("referee on {0}, logs -> {1}" -f $Port, $OutDir)

# The referee IS the harness -- same scene, same arguments, same `--dedicated` path a
# pool process boots with. Headless: it renders nothing and prints numbers.
$ref = Start-Process -FilePath $Godot -WindowStyle Hidden -PassThru -ArgumentList @(
    '--headless', '--path', $Project, 'tools/net/dedicated_recycle_run.tscn',
    '--', '--dedicated', ('--port=' + $Port), '--role=referee', '--pool=127.0.0.1'
) -RedirectStandardOutput (Join-Path $OutDir 'referee.log') `
  -RedirectStandardError  (Join-Path $OutDir 'referee.err')
Start-Sleep -Seconds 7

try {
    # ⚠️ WINDOWED, NOT HIDDEN. A windowed Godot started `-WindowStyle Hidden` on this
    # machine dies partway through with an empty stderr -- measured.
    $client = Start-Process -FilePath $Godot -Wait -PassThru -ArgumentList @(
        '--path', $Project, 'tools/net/dedicated_recycle_run.tscn',
        '--', '--pool=127.0.0.1', '--role=stay', ('--port=' + $Port)
    ) -RedirectStandardOutput (Join-Path $OutDir 'stay.log') `
      -RedirectStandardError  (Join-Path $OutDir 'stay.err')
} finally {
    # Give the referee its own tail: the client exits when it is sent home, which is
    # BEFORE the referee has finished asserting on what it kept open.
    $waited = 0
    while ((-not $ref.HasExited) -and $waited -lt 60) { Start-Sleep -Seconds 2; $waited += 2 }
    Stop-Process -Id $ref.Id -Force -ErrorAction SilentlyContinue
}

Write-Host "`n--- the client ---"
Get-Content (Join-Path $OutDir 'stay.log') -ErrorAction SilentlyContinue |
    Select-String -Pattern '\[stay\]|SCRIPT ERROR' | ForEach-Object { Write-Host $_.Line }
Write-Host "`n--- the referee ---"
Get-Content (Join-Path $OutDir 'referee.log') -ErrorAction SilentlyContinue |
    Select-String -Pattern '\[referee\]|main:|SCRIPT ERROR' | ForEach-Object { Write-Host $_.Line }

# ⚠️ THE VERDICT IS READ OUT OF THE LOG, NOT OFF `$ref.ExitCode`. The referee is stopped
# by PID above (it has no reason to quit on its own once it has reported), so its exit code
# is whatever a forced termination leaves behind -- measured: a run in which every single
# check printed PASS still reported "referee exit 99".
$exit = 1
$verdict = Get-Content (Join-Path $OutDir 'referee.log') -ErrorAction SilentlyContinue |
    Select-String -Pattern '\[referee\] RESULT (PASS|FAIL)' | Select-Object -Last 1
if ($verdict -and $verdict.Line -match 'RESULT PASS') { $exit = 0 }
if ($exit -eq 0) {
    Write-Host "`nPASS - a finished match put the lobby back in its waiting room, sockets intact."
} else {
    Write-Host ("`nFAIL - referee exit {0}. Full output: {1}" -f $exit, $OutDir)
}
exit $exit
