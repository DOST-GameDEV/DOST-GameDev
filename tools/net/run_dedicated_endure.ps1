<#
  THE OTHER TRIGGER: a match played to its NATURAL END on a dedicated server.

      powershell -ExecutionPolicy Bypass -File tools/net/run_dedicated_endure.ps1

  `run_dedicated_recycle.ps1` covers the abandonment case -- the player walks out
  mid-match and the referee finds an empty room. This covers the case where the
  player does NOT walk out: four rounds are played, `match_won` fires with the
  client still connected and sitting on the result screen, and the referee has to
  close the room itself once its post-match grace expires.

  ⚠️⚠️ PREFER `run_dedicated_matchend.ps1` — IT TESTS THE SAME TRIGGER IN THREE
  MINUTES AND CHECKS MORE. This script is the full-length version, kept because it
  is the one that fakes NOTHING: a real client sits through four real 90 s rounds.
  It has NOT been run to completion on this machine -- both attempts on 2026-08-02
  were cut short by other work on the box killing every Godot process -- so treat a
  failure from it as "look at the logs" rather than as a finding. The evidence that
  the natural-end trigger works comes from `run_dedicated_matchend.ps1`, which
  additionally asserts from INSIDE the referee that its sockets survived, something
  no client-side run can see.

  ⚠️ THIS TAKES ABOUT TEN MINUTES OF WALL CLOCK AND THERE IS NO WAY AROUND IT.
  `RoundManager.ROUND_TIME` is 90 s and a round only ever ends on the clock, so
  4 rounds + 3 intermissions is 6 min 9 s before the match can be won, plus
  `main.gd::DEDICATED_POST_MATCH_SECONDS`.

  ⚠️ PORT 8972, inside the 8970-8979 band this work owns and clear of the shipped
  pool range (8910-8917). See run_dedicated_recycle.ps1's own ⚠️.
#>

param(
    [string]$Godot   = 'C:\Users\StarX\Desktop\Godot_v4.7.1-stable_win64.exe',
    [string]$Project = 'C:\Users\StarX\Desktop\SCHOOL\dostgame\DOST-GameDev',
    [int]$Port       = 8972,
    [string]$OutDir  = ''
)

$ErrorActionPreference = 'Stop'

if ($OutDir -eq '') {
    $OutDir = Join-Path $env:TEMP ('dostgame-endure\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

# Only this run's own port band -- see run_dedicated_recycle.ps1's ⚠️⚠️ for why a blanket
# `Get-Process Godot* | Stop-Process` cost five debugging cycles on 2026-08-02.
Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot%'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match '--port=897' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2

Write-Host ("dedicated lobby on {0}, logs -> {1}" -f $Port, $OutDir)
$server = Start-Process -FilePath $Godot -WindowStyle Hidden -PassThru -ArgumentList @(
    '--headless', '--path', $Project, 'res://scenes/ui/MatchSetup.tscn',
    '--', '--dedicated', ('--port=' + $Port)
) -RedirectStandardOutput (Join-Path $OutDir 'server.log') `
  -RedirectStandardError  (Join-Path $OutDir 'server.err')
Start-Sleep -Seconds 7

$exit = 0
try {
    # See run_dedicated_recycle.ps1 for why this is Start-Process and not `& $Godot 2>&1`.
    $p = Start-Process -FilePath $Godot -Wait -PassThru -ArgumentList @(
        '--path', $Project, 'tools/net/dedicated_recycle_run.tscn',
        '--', '--pool=127.0.0.1', '--role=endure', ('--port=' + $Port)
    ) -RedirectStandardOutput (Join-Path $OutDir 'endure.log') `
      -RedirectStandardError  (Join-Path $OutDir 'endure.err')
    $exit = $p.ExitCode
    Get-Content (Join-Path $OutDir 'endure.log') |
        Select-String -Pattern '\[endure\]|SCRIPT ERROR' | ForEach-Object { Write-Host $_.Line }
} finally {
    Write-Host "`n--- the referee's own log ---"
    Get-Content (Join-Path $OutDir 'server.log') -ErrorAction SilentlyContinue |
        ForEach-Object { Write-Host $_ }
    Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
}

if ($exit -eq 0) {
    Write-Host "`nPASS - a finished match put the lobby back in its waiting room."
} else {
    Write-Host ("`nFAIL - {0} check(s) failed. Full output: {1}" -f $exit, $OutDir)
}
exit $exit
