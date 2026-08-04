<#
  DOES AN ABANDONED DEDICATED LOBBY EVER COME BACK? Says PASS or FAIL.

      powershell -ExecutionPolicy Bypass -File tools/net/run_dedicated_recycle.ps1

  Stands up ONE dedicated lobby, drives a real client through the player's actual
  path (HOST ONLINE, ready, START MATCH), then KILLS that client mid-match -- the
  abandonment measured on the live VM on 2026-08-02, which left the pool answering
  `players=0, occupied=0, in_progress=true` forever with nobody connected.

  Then it watches the status replies, and finally sends a SECOND client to claim
  the same lobby. That last step is the whole test: `_free_pool_address()` refuses
  any row whose `in_progress` is true, so a lobby that never resets is a lobby
  HOST ONLINE can never hand to anybody again.

  ⚠️ PORTS 8970-8979 ONLY. Other agents hold the 8960s and 8980s, and 8910-8917 is
  the SHIPPED pool range -- a lobby standing there would be found by anybody's
  browser on this machine. The harness overrides `ServerQuery.pool_ports` in code
  so HOST ONLINE reaches this band; see its own ⚠️.

  ⚠️ LEFTOVER PROCESSES ARE KILLED FIRST, and that is not tidiness. A dedicated
  server still holding the port from an earlier run makes the new client talk to
  the OLD build, which Godot reports as "The rpc node checksum failed. Make sure
  to have the same methods on both nodes" -- a message that blames your code.
#>

param(
    [string]$Godot   = 'C:\Users\StarX\Desktop\Godot_v4.7.1-stable_win64.exe',
    [string]$Project = 'C:\Users\StarX\Desktop\SCHOOL\dostgame\DOST-GameDev',
    [int]$Port       = 8971,
    [string]$OutDir  = '',
    # Skips the 12 s watch pass. The watch is the BEFORE evidence; once the fix is
    # in it only proves the reset already happened, so it is opt-out.
    [switch]$NoWatch
)

$ErrorActionPreference = 'Stop'

if ($OutDir -eq '') {
    $OutDir = Join-Path $env:TEMP ('dostgame-recycle\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

# ⚠️⚠️ ONLY THIS RUN'S OWN PORT BAND IS KILLED, NOT EVERY GODOT ON THE BOX. A blanket
# `Get-Process Godot* | Stop-Process` is what every other harness in this tree does, and on
# 2026-08-02 that turned out to be mutually destructive: other work on this machine runs its
# own lobbies and its own blanket kill, and five runs of THIS script died mid-match with an
# empty stderr and a server that had simply vanished -- which reads exactly like a crash in
# the game and is not. Matching on the command line kills the stale lobbies this script
# leaked and nobody else's.
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

# The server has to be answering status queries before the client asks, or HOST
# ONLINE finds an empty pool and gives up before the first reply lands.
Start-Sleep -Seconds 7

# ⚠️ EVERY CLIENT IS RUN THROUGH Start-Process, NOT THROUGH `& $Godot ... 2>&1`.
# Windows PowerShell 5.1 wraps a native exe's stderr in an ErrorRecord, and with
# $ErrorActionPreference = 'Stop' that ABORTS THE WHOLE SCRIPT the instant Godot
# prints anything to stderr. Measured on the first run of this harness: an
# unrelated "LanBeacon: cannot listen on 8911" warning (port already held by the
# lobby process) killed the watch pass at t=2s and the claim pass before it had
# asked anything, and both looked like the run had simply produced no output.
function Invoke-Client {
    param([string]$Role, [string]$Log, [switch]$Headless)
    # NOT $args -- that is an automatic variable in a PowerShell function.
    $argv = @()
    if ($Headless) { $argv += '--headless' }
    $argv += @('--path', $Project, 'tools/net/dedicated_recycle_run.tscn',
               '--', '--pool=127.0.0.1', ('--role=' + $Role), ('--port=' + $Port))
    $out = Join-Path $OutDir $Log
    # ⚠️ `-WindowStyle Hidden` IS FOR THE HEADLESS RUNS ONLY, and that is not cosmetic.
    # A WINDOWED Godot started hidden gets no usable window on this machine and dies
    # silently partway through -- measured: the play pass logged its first two lines and
    # then stopped, with an empty stderr, which reads exactly like a game bug.
    $style = 'Normal'
    if ($Headless) { $style = 'Hidden' }
    $p = Start-Process -FilePath $Godot -Wait -PassThru -WindowStyle $style `
        -ArgumentList $argv -RedirectStandardOutput $out `
        -RedirectStandardError (Join-Path $OutDir ($Role + '.err'))
    # Write-Host, not the pipeline: anything a function EMITS is its return value,
    # so echoing the log with `ForEach-Object { $_.Line }` would hand the caller
    # forty strings with the exit code buried at the end of them.
    Get-Content $out | Select-String -Pattern '\[|SCRIPT ERROR' |
        ForEach-Object { Write-Host $_.Line }
    return $p.ExitCode
}

$exit = 0
try {
    Write-Host "`n=== 1. a player claims the lobby and starts a match, then walks out ==="
    $exit += (Invoke-Client -Role 'play' -Log 'play.log')

    if (-not $NoWatch) {
        Write-Host "`n=== 2. nobody is connected. what does the lobby keep saying? ==="
        Invoke-Client -Role 'watch' -Log 'watch.log' -Headless | Out-Null
    }

    Write-Host "`n=== 3. a SECOND player presses HOST ONLINE. can they have it? ==="
    $exit += (Invoke-Client -Role 'claim' -Log 'claim.log')
} finally {
    Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
}

if ($exit -eq 0) {
    Write-Host "`nPASS - the lobby went back to the waiting room and was claimed again."
} else {
    Write-Host ("`nFAIL - {0} check(s) failed. Full output: {1}" -f $exit, $OutDir)
}
exit $exit
