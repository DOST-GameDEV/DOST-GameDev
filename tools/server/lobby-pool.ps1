<#
-----------------------------------------------------------------------------
Dedicated lobby pool — Windows. The dev-machine twin of lobby-pool.sh, so the
pool can be exercised locally before anything is put on a VM.

Same shape as the Linux script: one process per port, one match per process,
because RoundManager/MatchManager are autoloads holding a single match's state.

⚠️ THIS IS THE TEST HARNESS, NOT THE DEPLOYMENT. Two deliberate differences
from lobby-pool.sh:
  * Stop is a hard kill. There is no SIGTERM on Windows and Godot headless has
    no console window to close, so shutdown does not get the graceful ENet
    close the Linux path gives it. Fine for a local pool, not for players.
  * A crashed lobby is noticed at `status` or `stop` time, not at the moment it
    dies — there is no supervising subshell here. The exit is still written to
    that port's log when it is noticed.

  .\lobby-pool.ps1 start [-Count 4]
  .\lobby-pool.ps1 stop
  .\lobby-pool.ps1 restart [-Count 4]
  .\lobby-pool.ps1 status

Defaults target the dev machine; override with -GodotBin / -GamePath /
-BasePort as needed.
-----------------------------------------------------------------------------
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('start', 'stop', 'restart', 'status')]
    [string]$Command = 'status',

    [int]$Count = 4,
    [int]$BasePort = 8910,
    [string]$GodotBin = "C:\Users\StarX\Desktop\Godot_v4.7.1-stable_win64.exe",
    [string]$GamePath = "",
    [string]$StateDir = (Join-Path $env:LOCALAPPDATA "tumbang-preso-pool")
)

# ⚠️ RESOLVED HERE AND NOT AS A PARAMETER DEFAULT. Windows PowerShell 5.1 has
# not populated $PSScriptRoot yet when it binds the param block under
# `powershell -File`, so `-Parent $PSScriptRoot` there fails with "cannot bind
# argument ... because it is an empty string" before a single line runs.
# tools/server -> tools -> the project root.
if ([string]::IsNullOrEmpty($GamePath)) {
    $GamePath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

# ⚠️⚠️ THE SCENE PATH IS NOT OPTIONAL AND ITS ABSENCE IS SILENT.
#
# project.godot's run/main_scene is res://scenes/ui/SplashScreen.tscn. The
# --dedicated / --port= parsing is in scripts/main.gd::_ready and only runs when
# Main.tscn is what booted. Measured on this machine 2026-08-02: launched
# without this argument, the process lived 18 s, logged nothing but the engine
# banner, and never bound its UDP port. It looks completely healthy.
$MainScene = "res://scenes/main/Main.tscn"

$RunDir = Join-Path $StateDir "run"
$LogDir = Join-Path $StateDir "log"

function Write-Pool([string]$Message) {
    Write-Host "[pool] $Message"
}

function Get-PidFile([int]$Port) {
    Join-Path $RunDir ("lobby-{0}.pid" -f $Port)
}

function Get-LogFile([int]$Port) {
    Join-Path $LogDir ("lobby-{0}.log" -f $Port)
}

# ⚠️ SEPARATE FILE FROM THE GAME'S OWN LOG, ON PURPOSE. Start-Process's
# -RedirectStandardOutput TRUNCATES its target and then holds the handle open
# for the life of the process, so anything the pool writes to that same path is
# either erased at launch or interleaved into a stream Godot is still writing.
# The pool's bookkeeping (started / stopped / died) gets its own file.
function Get-PoolLogFile([int]$Port) {
    Join-Path $LogDir ("lobby-{0}.pool.log" -f $Port)
}

function Add-PoolLog([int]$Port, [string]$Message) {
    Add-Content -Path (Get-PoolLogFile $Port) -Value ("[pool] {0} port {1} {2}" -f (Get-Date -Format 's'), $Port, $Message)
}

# Returns the live Process for this port, or $null.
#
# ⚠️ THE START TIME IS PART OF THE IDENTITY, NOT DECORATION. Windows recycles
# PIDs quickly, so a bare `Get-Process -Id` after a crash can cheerfully return
# somebody else's process and the pool would report a dead lobby as healthy —
# and worse, `stop` would kill whatever inherited the number.
function Get-LobbyProcess([int]$Port) {
    $pf = Get-PidFile $Port
    if (-not (Test-Path $pf)) { return $null }
    $parts = (Get-Content $pf -ErrorAction SilentlyContinue) -split '\|'
    if ($parts.Count -lt 2) { Remove-Item $pf -Force -ErrorAction SilentlyContinue; return $null }
    $procId = 0
    if (-not [int]::TryParse($parts[0], [ref]$procId)) {
        Remove-Item $pf -Force -ErrorAction SilentlyContinue
        return $null
    }
    $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
    if ($null -eq $proc) {
        Add-PoolLog $Port "pid $procId is gone (noticed at inspection)."
        Remove-Item $pf -Force -ErrorAction SilentlyContinue
        return $null
    }
    if ($proc.StartTime.Ticks.ToString() -ne $parts[1]) {
        Add-PoolLog $Port "pid $procId was reused by another process; lobby is gone."
        Remove-Item $pf -Force -ErrorAction SilentlyContinue
        return $null
    }
    return $proc
}

# ⚠️ UDP, NOT TCP. ENet is UDP end to end. Get-NetTCPConnection will show
# nothing here no matter how well the pool is running.
function Test-PortBound([int]$Port) {
    $ep = Get-NetUDPEndpoint -LocalPort $Port -ErrorAction SilentlyContinue
    return ($null -ne $ep)
}

function Start-Lobby([int]$Port) {
    $existing = Get-LobbyProcess $Port
    if ($null -ne $existing) {
        Write-Pool "port $Port already served by pid $($existing.Id) — left alone."
        return $true
    }
    if (Test-PortBound $Port) {
        Write-Pool "port $Port is already bound by a process this pool does not own — skipped."
        return $false
    }

    $log = Get-LogFile $Port
    $errLog = "$log.err"
    Add-PoolLog $Port "starting on udp/$Port"

    # ⚠️ `--` separates ENGINE arguments from GAME arguments. scripts/main.gd
    # reads OS.get_cmdline_user_args(), which is only what follows `--`. Move
    # --dedicated in front of it and the engine rejects it as unknown.
    $argv = @(
        '--headless'
        '--path'; $GamePath
        $MainScene
        '--'
        '--dedicated'
        "--port=$Port"
    )

    $proc = Start-Process -FilePath $GodotBin -ArgumentList $argv `
        -RedirectStandardOutput $log -RedirectStandardError $errLog `
        -PassThru -WindowStyle Hidden
    if ($null -eq $proc) {
        Write-Pool "port $Port failed to launch."
        return $false
    }
    Set-Content -Path (Get-PidFile $Port) -Value ("{0}|{1}" -f $proc.Id, $proc.StartTime.Ticks) -Encoding utf8

    # Bind is not instant — the engine has to boot, load Main.tscn and the map
    # before _ready() reaches host_game(). Poll rather than sleep a guessed
    # amount, and report what actually happened.
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline) {
        if ($proc.HasExited) {
            Add-PoolLog $Port "exited during startup with code $($proc.ExitCode)."
            Write-Pool "port $Port exited during startup with code $($proc.ExitCode) — see $log"
            Remove-Item (Get-PidFile $Port) -Force -ErrorAction SilentlyContinue
            return $false
        }
        if (Test-PortBound $Port) {
            Write-Pool "started port $Port (pid $($proc.Id), log $log)"
            return $true
        }
        Start-Sleep -Milliseconds 500
    }
    # ⚠️ `${Port}` and not `$Port`. A `$name:` sequence is PowerShell's
    # drive-qualified variable syntax (`$env:PATH`), so `"port $Port: ..."` is a
    # PARSE ERROR, not a formatting quirk — and it takes the whole file with it.
    Write-Pool "port ${Port}: process is up but never bound the port — check that $MainScene is on its command line. See $log"
    return $false
}

function Stop-Lobby([int]$Port) {
    $proc = Get-LobbyProcess $Port
    if ($null -eq $proc) {
        Write-Pool "port $Port was not running."
        return
    }
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    $deadline = (Get-Date).AddSeconds(10)
    while ((Get-Date) -lt $deadline) {
        if ($null -eq (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)) { break }
        Start-Sleep -Milliseconds 250
    }
    Add-PoolLog $Port "stopped."
    Remove-Item (Get-PidFile $Port) -Force -ErrorAction SilentlyContinue
    Write-Pool "stopped port $Port."
}

function Invoke-Preflight {
    $ok = $true
    if (-not (Test-Path $GodotBin)) {
        Write-Pool "GodotBin '$GodotBin' does not exist."
        $ok = $false
    }
    if (-not (Test-Path (Join-Path $GamePath "project.godot"))) {
        Write-Pool "GamePath '$GamePath' has no project.godot in it."
        $ok = $false
    }
    return $ok
}

function Invoke-Start {
    if (-not (Invoke-Preflight)) { return 1 }
    New-Item -ItemType Directory -Force $RunDir | Out-Null
    New-Item -ItemType Directory -Force $LogDir | Out-Null
    $failures = 0
    for ($i = 0; $i -lt $Count; $i++) {
        if (-not (Start-Lobby ($BasePort + $i))) { $failures++ }
    }
    if ($failures -gt 0) {
        Write-Pool "$failures of $Count lobbies did not start."
        return 1
    }
    Write-Pool ("pool of {0} up on udp/{1}-{2}." -f $Count, $BasePort, ($BasePort + $Count - 1))
    return 0
}

# Stops every lobby with a pidfile, not just the currently configured -Count. A
# pool started at 8 and stopped at 4 must not leave four orphans holding ports.
function Invoke-Stop {
    if (-not (Test-Path $RunDir)) {
        Write-Pool "no state directory at $RunDir — nothing to stop."
        return 0
    }
    $files = Get-ChildItem -Path $RunDir -Filter "lobby-*.pid" -ErrorAction SilentlyContinue
    if ($null -eq $files -or $files.Count -eq 0) {
        Write-Pool "no lobbies were running."
        return 0
    }
    foreach ($f in $files) {
        $port = 0
        if ([int]::TryParse(($f.BaseName -replace '^lobby-', ''), [ref]$port)) {
            Stop-Lobby $port
        }
    }
    return 0
}

# ⚠️ Write-Host, not bare strings. A function's uncaptured output IS its return
# value in PowerShell, so a table emitted to the pipeline would come back to
# `exit` as a string array instead of an exit code.
function Invoke-Status {
    Write-Host ("{0,-7} {1,-10} {2,-8} {3}" -f 'PORT', 'PID', 'BOUND', 'LOG')
    for ($i = 0; $i -lt $Count; $i++) {
        $port = $BasePort + $i
        $proc = Get-LobbyProcess $port
        $shown = '-'
        if ($null -ne $proc) { $shown = $proc.Id }
        $bound = 'NO'
        if (Test-PortBound $port) { $bound = 'yes' }
        Write-Host ("{0,-7} {1,-10} {2,-8} {3}" -f $port, $shown, $bound, (Get-LogFile $port))
    }
    Write-Host ""
    Write-Pool "a pid with BOUND=NO means the process is up but is not listening —"
    Write-Pool "check that $MainScene is on its command line."
    return 0
}

switch ($Command) {
    'start'   { exit (Invoke-Start) }
    'stop'    { exit (Invoke-Stop) }
    'restart' { Invoke-Stop | Out-Null; exit (Invoke-Start) }
    'status'  { exit (Invoke-Status) }
}
