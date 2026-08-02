<#
  Drops a player out of a LIVE match and drives them back in, then says PASS or FAIL.

      powershell -ExecutionPolicy Bypass -File tools/net/run_rejoin.ps1

  🧑 2026-08-02: *"When getting disconnected from a lobby, I want the ability to rejoin
  it. Currently you are able to JOIN it, but you're stuck on a grey screen."*

  Three real processes, because two cannot reproduce it:

      referee   the dedicated lobby (hosts MatchSetup.tscn with --dedicated --port=)
      anchor    a client that joins, leads the lobby, presses START MATCH and STAYS
      dropper   the player in the report: joins, plays, drops, rejoins, reports

  ⚠️ THE ANCHOR IS NOT PADDING. `main.gd::_recycle_dedicated_lobby_if_abandoned()` sends a
  dedicated referee whose last human left straight back to MatchSetup.tscn -- so with only
  one client the match ENDS when it drops and the rejoin lands in a fresh lobby, which is a
  different (working) path and not the bug. See rejoin_run.gd's header.

  ⚠️ PORTS 8940-8949 ONLY. Outside ServerQuery's pool range (8910-8917) on purpose; every
  client here joins by TYPED ADDRESS, so no pool query is involved.

  ⚠️ LEFTOVER PROCESSES ARE KILLED FIRST, and that is not tidiness. A server still holding
  the port from an earlier run makes the new clients talk to the OLD build, which Godot
  reports as "The rpc node checksum failed" -- a message that blames your code and does not
  mean what it says.

  ⚠️ THE CLIENTS RUN WITHOUT --headless. There is no rendering device under --headless on
  this machine, and this run asks whether a CAMERA is current -- a question with no honest
  answer on a process that cannot render. The referee is headless: it draws nothing either
  way and only prints host-side bookkeeping.
#>

param(
    [string]$Godot   = 'C:\Users\StarX\Desktop\Godot_v4.7.1-stable_win64.exe',
    [string]$Project = 'C:\Users\StarX\Desktop\SCHOOL\dostgame\DOST-GameDev',
    [int]$Port       = 8941,
    # 'rejoin'    the reported bug: a player who was IN the match, drops, and comes back.
    # 'latecomer' the regression beside it: somebody who was never in this match joining
    #             while it runs. Same `main.gd::_start_joining` dial-out, so the same line
    #             broke both -- see rejoin_run.gd's § THE REGRESSION HALF.
    [ValidateSet('rejoin', 'latecomer')]
    [string]$Scenario = 'rejoin',
    [string]$OutDir  = ''
)

$ErrorActionPreference = 'Stop'

if ($OutDir -eq '') {
    $OutDir = Join-Path $env:TEMP ('dostgame-rejoin\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

if ($Scenario -eq 'latecomer') { $ClientRole = 'latecomer'; $WaitFor = 0 }
else                           { $ClientRole = 'dropper';   $WaitFor = 1 }

Write-Host ("{0} run on port {1}, logs -> {2}" -f $Scenario, $Port, $OutDir)

# ⚠️ `--dedicated` IS NOT OPTIONAL HERE AND IS NOT THE HARNESS'S OWN FLAG. It is read by
# the REAL `match_setup.gd::_read_dedicated_args()`, which is what makes this process host
# at all (it also sets `pending_action = "host"`, since a pool process has no menu behind
# it). Measured: the first run of this harness omitted it, and the referee sat in
# MatchSetup with `is_host()` false and an empty join code while both clients "connected"
# to nothing -- `join_game()` returns OK the moment the socket opens, so a client cannot
# tell the difference for several seconds.
$referee = Start-Process -FilePath $Godot -WindowStyle Hidden -PassThru -ArgumentList @(
    '--headless', '--path', $Project, 'tools/net/rejoin_run.tscn',
    '--', '--role=referee', '--dedicated', ('--port=' + $Port)
) -RedirectStandardOutput (Join-Path $OutDir 'referee.log') `
  -RedirectStandardError  (Join-Path $OutDir 'referee.err')

# The ENet listener has to be up before anybody types its address at it.
Start-Sleep -Seconds 5

$anchor = Start-Process -FilePath $Godot -PassThru -ArgumentList @(
    '--path', $Project, 'tools/net/rejoin_run.tscn',
    '--', '--role=anchor', ('--port=' + $Port), '--host=127.0.0.1',
    ('--wait-for=' + $WaitFor)
) -RedirectStandardOutput (Join-Path $OutDir 'anchor.log') `
  -RedirectStandardError  (Join-Path $OutDir 'anchor.err')

# ⚠️ Start-Process WITH REDIRECTS, NOT `& godot ... 2>&1 | Tee-Object`. Windows PowerShell
# 5.1 wraps every stderr line of a NATIVE executable in a NativeCommandError record, and
# with `$ErrorActionPreference = 'Stop'` the first harmless Godot warning
# ("LanBeacon: cannot listen on 8911") aborts the whole script mid-run. Measured: the first
# run of this file died four seconds into the dropper with two checks printed and no
# RESULT line, which reads as a harness crash rather than as the warning it was.
$exit = 0
try {
    $client = Start-Process -FilePath $Godot -PassThru -Wait -ArgumentList @(
        '--path', $Project, 'tools/net/rejoin_run.tscn',
        '--', ('--role=' + $ClientRole), ('--port=' + $Port), '--host=127.0.0.1'
    ) -RedirectStandardOutput (Join-Path $OutDir 'client.log') `
      -RedirectStandardError  (Join-Path $OutDir 'client.err')
    $exit = $client.ExitCode
} finally {
    Stop-Process -Id $anchor.Id  -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $referee.Id -Force -ErrorAction SilentlyContinue
}

Write-Host ("`n--- {0} ---" -f $ClientRole)
Get-Content (Join-Path $OutDir 'client.log') -ErrorAction SilentlyContinue |
    Select-String -Pattern ('\[' + $ClientRole + '|SCRIPT ERROR')

Write-Host "`n--- referee (host side) ---"
Get-Content (Join-Path $OutDir 'referee.log') -ErrorAction SilentlyContinue |
    Select-String -Pattern '\[referee' | Select-Object -Last 30

Write-Host "`n--- anchor ---"
Get-Content (Join-Path $OutDir 'anchor.log') -ErrorAction SilentlyContinue |
    Select-String -Pattern '\[anchor|\[run\] FAIL' | Select-Object -Last 20

if ($exit -eq 0) {
    if ($Scenario -eq 'latecomer') {
        Write-Host "`nPASS - a first-time joiner landed in the running match."
    } else {
        Write-Host "`nPASS - a dropped player got back into the running match."
    }
} else {
    Write-Host ("`nFAIL - {0} check(s) failed. Full output: {1}" -f $exit, $OutDir)
}
exit $exit
