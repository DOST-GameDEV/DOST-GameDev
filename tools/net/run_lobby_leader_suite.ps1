<#
  Real-network acceptance for § DEDICATED HOSTING and § THE LOBBY LEADER
  (scripts/systems/network_manager.gd). Launches several REAL Godot processes on
  loopback, drives them through a lobby's whole life, and diffs what each one
  reported against what the two headers promise.

      powershell -ExecutionPolicy Bypass -File tools/net/run_lobby_leader_suite.ps1

  Three scenarios, three ports (8990-8992):

    1. DEDICATED   a referee, then one peer, then three, then they leave oldest
                   first. Three is the minimum that can tell "the longest-waiting
                   peer" apart from "the only peer left" -- see the scenario's
                   own note.
    2. LISTEN      the unchanged case. A listen host must still seat itself in
                   all three dictionaries and must still lead its own lobby --
                   the dedicated work is only allowed to have added a branch.
    3. DOCUMENTED  the literal launch line from the handoff, verbatim, with no
                   probe wrapped around the server. Scenario 1 reaches Main.tscn
                   through `change_scene_to_file` so the probe can outlive the
                   scene load; this one proves the positional-scene form people
                   will actually type still boots and still hands out the role.

  DESIGN NOTES, so the next person does not re-derive them:

  * ⚠️ PEER IDS ARE NOT 2 AND 3. Godot 4's ENet server mints a random 32-bit id
    per client (measured: 1524618684). Nothing here may hardcode a client id --
    every id is read back out of the process that owns it and then used
    symbolically.
  * ⚠️ NO BLIND SLEEPS BETWEEN CAUSAL STEPS. Each step waits for the LINE that
    proves the previous one landed. A fixed sleep is what makes a network test
    fail on a loaded machine and pass on a quiet one, which is worse than not
    having the test.
  * ⚠️ PEERS LEAVE BY SENTINEL FILE, NOT BY Stop-Process. `announce_host_leaving`'s
    header measured the difference: a killed process is only noticed when ENet's
    timeout expires, so killing would test ENET_TIMEOUT_MIN instead of
    `_reassign_leader`. The probe watches for a file and calls
    `disconnect_network()`, which flushes a real ENet disconnect.
  * Logs go to %TEMP%, never into the repo -- this tree is shared.
#>

param(
    [string]$Godot   = 'C:\Users\StarX\Desktop\Godot_v4.7.1-stable_win64.exe',
    [string]$Project = 'C:\Users\StarX\Desktop\SCHOOL\dostgame\DOST-GameDev',
    # Ports 8990-8992. The 899x band is reserved for this harness.
    [int]$BasePort   = 8990,
    [string]$LogDir  = ''
)

$ErrorActionPreference = 'Stop'

if ($LogDir -eq '') {
    $LogDir = Join-Path $env:TEMP ('dostgame-net-lobby\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

$script:Procs  = @()
$script:Checks = @()

# --------------------------------------------------------------------------
# Process control
# --------------------------------------------------------------------------

function Start-Probe {
    param([string]$Tag, [string[]]$UserArgs, [string]$Log)
    $argv = @('--headless', '--path', ('"' + $Project + '"'), '-s', 'tools/net/net_lobby_probe.gd', '--')
    foreach ($a in $UserArgs) { $argv += ('"' + $a + '"') }
    $p = Start-Process -FilePath $Godot -ArgumentList $argv -PassThru `
        -RedirectStandardOutput $Log -RedirectStandardError ($Log + '.err')
    $script:Procs += $p
    Write-Host ("  launched {0} (pid {1}) -> {2}" -f $Tag, $p.Id, (Split-Path $Log -Leaf))
    return $p
}

# The handoff's own command line, unwrapped. No probe, no -s: this exists to
# prove the documented invocation is the one that works.
function Start-DocumentedServer {
    param([int]$Port, [string]$Log)
    $argv = @('--headless', '--path', ('"' + $Project + '"'),
              'res://scenes/main/Main.tscn', '--', '--dedicated', ('--port=' + $Port))
    $p = Start-Process -FilePath $Godot -ArgumentList $argv -PassThru `
        -RedirectStandardOutput $Log -RedirectStandardError ($Log + '.err')
    $script:Procs += $p
    Write-Host ("  launched DOC-SERVER (pid {0}) -> {1}" -f $p.Id, (Split-Path $Log -Leaf))
    return $p
}

function Stop-AllProbes {
    foreach ($p in $script:Procs) {
        try {
            if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction Stop }
        } catch {
            # Already gone, or gone between the test and the kill. Either is fine
            # -- the only failure that matters here is a survivor holding a port.
        }
    }
}

# --------------------------------------------------------------------------
# Log reading
# --------------------------------------------------------------------------

# ⚠️ FileShare::ReadWrite, NOT Get-Content. The file is open for writing by a
# live Godot process; the ordinary read path takes a share mode that collides
# with it and throws intermittently -- which reads as a flaky network test.
function Read-Log {
    param([string]$Log)
    if (-not (Test-Path $Log)) { return @() }
    $fs = New-Object System.IO.FileStream(
        $Log, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $sr = New-Object System.IO.StreamReader($fs)
        $text = $sr.ReadToEnd()
    } finally { $fs.Dispose() }
    return ($text -split "`r?`n")
}

function Get-ProbeLines {
    param([string]$Log, [string]$Tag, [string]$Kind)
    return @(Read-Log $Log | Where-Object { $_ -match ("^NETPROBE " + $Tag + " " + $Kind + " ") })
}

function Get-Field {
    param([string]$Line, [string]$Name)
    if ($Line -match ('(?:^|\s)' + $Name + '=([^\s]+)')) { return $Matches[1] }
    return '<missing>'
}

# Order-independent comparison of an id list. `connected_peer_ids` is an append
# order and `.keys()` an insertion order; neither is part of the contract.
function Get-IdSet {
    param([string]$Value)
    if ($Value -eq '-' -or $Value -eq '<missing>') { return $Value }
    return (($Value -split ',' | Sort-Object) -join ',')
}

# ⚠️ A SEAT LIST HAS TO BE MATCHED AS A WHOLE FIELD, space to space. Matching
# `peers=<id>` loosely also matches `peers=<id>,<other>`, and matching `peers=-`
# loosely also matches the PRISTINE state from before the first client ever
# connected -- which is how "the lobby emptied" once passed instantly at t=0 and
# then read a stale sample that still had everybody in it.
function Get-SeatPattern {
    param([string]$Tag, [string]$Peers)
    return ('^NETPROBE ' + $Tag + ' STATE .* peers=' + [regex]::Escape($Peers) + ' ')
}

function Wait-ForPattern {
    param([string]$Log, [string]$Pattern, [int]$TimeoutSec = 60, [string]$What = '')
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $hit = @(Read-Log $Log | Where-Object { $_ -match $Pattern })
        if ($hit.Count -gt 0) { return $hit[$hit.Count - 1] }
        Start-Sleep -Milliseconds 150
    }
    throw ("TIMEOUT after {0}s waiting for /{1}/ in {2}{3}" -f $TimeoutSec, $Pattern, (Split-Path $Log -Leaf),
        $(if ($What -ne '') { " -- $What" } else { '' }))
}

# --------------------------------------------------------------------------
# Assertions
# --------------------------------------------------------------------------

function Add-Check {
    param([string]$Name, $Expected, $Actual)
    $ok = ([string]$Expected -eq [string]$Actual)
    $script:Checks += [pscustomobject]@{
        Name = $Name; Ok = $ok; Expected = [string]$Expected; Actual = [string]$Actual
    }
    if ($ok) {
        Write-Host ("    PASS  {0}" -f $Name) -ForegroundColor Green
    } else {
        Write-Host ("    FAIL  {0}" -f $Name) -ForegroundColor Red
        Write-Host ("          expected: {0}" -f $Expected) -ForegroundColor Red
        Write-Host ("          actual:   {0}" -f $Actual) -ForegroundColor Red
    }
}

# ⚠️ WAITS FOR A SAMPLE RATHER THAN ACCEPTING "none yet". A client prints its
# JOINED line the frame the handshake lands and its first STATE up to
# STATE_INTERVAL later, so reading "the last STATE" the instant after JOINED
# legitimately finds nothing -- and an empty line parses as `<missing>` on every
# field, which reads as a code failure and is only a fast machine.
function Get-LastState {
    param([string]$Log, [string]$Tag, [int]$TimeoutSec = 30)
    Wait-ForPattern $Log ('^NETPROBE ' + $Tag + ' STATE ') $TimeoutSec ('no STATE sample from ' + $Tag) | Out-Null
    $lines = @(Get-ProbeLines $Log $Tag 'STATE')
    return $lines[$lines.Count - 1]
}

# ⚠️ @() AT EVERY CALL SITE OF A LINE-RETURNING FUNCTION. PowerShell unrolls a
# one-element array on return, so a log with exactly one matching line comes back
# as a STRING -- and `$lines[0]` then yields the letter "N" of "NETPROBE" rather
# than the line. Measured: it turned 23 good checks into `<missing>` and reported
# a leader id of "4" for peer 474299023.
#
# ⚠️ AND `return ,$ids` IS NOT THE FIX, IT IS THE NEXT BUG. Wrapping the array to
# protect it from unrolling makes the caller's own `@()` see one element that
# happens to be an array, so a three-event transcript counted as 1 and every
# index past [0] came back empty -- i.e. it reported a working handover as
# missing. The array is returned bare; the `@()` belongs to the caller.
function Get-LeaderEvents {
    param([string]$Log, [string]$Tag)
    $ids = @(Get-ProbeLines $Log $Tag 'EVENT' | ForEach-Object { Get-Field $_ 'leader' })
    return $ids
}

# --------------------------------------------------------------------------

$P_DEDICATED = $BasePort
$P_LISTEN    = $BasePort + 1
$P_DOCUMENTED = $BasePort + 2

try {

# ==========================================================================
Write-Host ''
Write-Host ("SCENARIO 1 - dedicated server, three peers, two handovers (port {0})" -f $P_DEDICATED) -ForegroundColor Cyan
# ==========================================================================
# ⚠️ THREE PEERS, NOT TWO, AND THE THIRD IS THE ONLY REASON THIS TESTS ANYTHING.
# `_reassign_leader` promises the LONGEST-WAITING remaining peer. With two peers
# there is exactly one candidate, so "oldest first" and "whoever is left" give
# the same answer and the loop could be picking at random and still pass. The
# third peer is what makes B-not-D a real assertion.

$sLog = Join-Path $LogDir 'dedicated-server.log'
$aLog = Join-Path $LogDir 'dedicated-client-A.log'
$bLog = Join-Path $LogDir 'dedicated-client-B.log'
$dLog = Join-Path $LogDir 'dedicated-client-D.log'
$aLeave = Join-Path $LogDir 'leave-A.flag'
$bLeave = Join-Path $LogDir 'leave-B.flag'
$dLeave = Join-Path $LogDir 'leave-D.flag'

Start-Probe 'S' @("--probe-role=server", "--probe-tag=S", "--probe-port=$P_DEDICATED",
                  "--probe-quit-at=300", "--dedicated", "--port=$P_DEDICATED") $sLog | Out-Null
Wait-ForPattern $sLog '^NETPROBE S HOSTING ' 60 'dedicated server never started hosting' | Out-Null

$init = @(Get-ProbeLines $sLog 'S' 'INIT')[0]
Add-Check 'dedicated: server is the multiplayer authority'      1   (Get-Field $init 'host')
Add-Check 'dedicated: is_dedicated is set from --dedicated'     1   (Get-Field $init 'dedicated')
Add-Check 'dedicated: takes NO seat in connected_peer_ids'      '-' (Get-Field $init 'peers')
Add-Check 'dedicated: seeds NO entry in peer_tokens'            '-' (Get-Field $init 'tokens')
Add-Check 'dedicated: seeds NO entry in peer_characters'        '-' (Get-Field $init 'chars')
Add-Check 'dedicated: lobby_leader_id starts at 0 (nobody)'     0   (Get-Field $init 'leader')
Add-Check 'dedicated: server does not consider itself leader'   0   (Get-Field $init 'isleader')

Write-Host '  -- first peer arrives'
Start-Probe 'A' @("--probe-role=client", "--probe-tag=A", "--probe-port=$P_DEDICATED",
                  "--probe-quit-at=300", "--probe-leave-file=$aLeave", "--join=127.0.0.1") $aLog | Out-Null
$aJoined = Wait-ForPattern $aLog '^NETPROBE A JOINED ' 60 'client A never completed the handshake'
$aId = Get-Field $aJoined 'self'
Write-Host ("     client A is peer {0}" -f $aId)
Wait-ForPattern $sLog ('^NETPROBE S EVENT .*leader=' + $aId + '\s*$') 60 'server never promoted the first peer' | Out-Null
Wait-ForPattern $aLog '^NETPROBE A STATE .*isleader=1 ' 30 'client A never saw itself as leader' | Out-Null
Wait-ForPattern $sLog (Get-SeatPattern 'S' $aId) 30 'server never seated the first peer alone' | Out-Null

$sEvents = @(Get-LeaderEvents $sLog 'S')
$aEvents = @(Get-LeaderEvents $aLog 'A')
$aState  = Get-LastState $aLog 'A'
$sState  = Get-LastState $sLog 'S'
Add-Check 'dedicated: first peer to IDENTIFY becomes leader'        $aId  $sEvents[0]
Add-Check 'dedicated: lobby_leader_changed fired on the client too' $aId  $aEvents[0]
Add-Check 'dedicated: the leader knows it leads (is_lobby_leader)'  1     (Get-Field $aState 'isleader')
Add-Check 'dedicated: peer_tokens holds the peer, not the server'   $aId  (Get-IdSet (Get-Field $sState 'tokens'))
Add-Check 'dedicated: peer_characters holds the peer, not the server' $aId (Get-IdSet (Get-Field $sState 'chars'))
Add-Check 'dedicated: connected_peer_ids holds the peer, not the server' $aId (Get-IdSet (Get-Field $sState 'peers'))

Write-Host '  -- second peer arrives'
Start-Probe 'B' @("--probe-role=client", "--probe-tag=B", "--probe-port=$P_DEDICATED",
                  "--probe-quit-at=300", "--probe-leave-file=$bLeave", "--join=127.0.0.1") $bLog | Out-Null
$bJoined = Wait-ForPattern $bLog '^NETPROBE B JOINED ' 60 'client B never completed the handshake'
$bId = Get-Field $bJoined 'self'
Write-Host ("     client B is peer {0}" -f $bId)
# B learning ANY leader means the host has already decided what to do about it,
# so the "did it steal the role" check below cannot be read too early.
Wait-ForPattern $bLog '^NETPROBE B EVENT ' 60 'late joiner was never told who leads' | Out-Null
Wait-ForPattern $sLog (Get-SeatPattern 'S' ($aId + ',' + $bId)) 30 'server never seated both peers' | Out-Null

$sEvents = @(Get-LeaderEvents $sLog 'S')
$bEvents = @(Get-LeaderEvents $bLog 'B')
$sState  = Get-LastState $sLog 'S'
$bState  = Get-LastState $bLog 'B'
Add-Check 'dedicated: a late joiner is TOLD the incumbent leader'  $aId ($bEvents[0])
Add-Check 'dedicated: the second peer does NOT steal the role'     1    $sEvents.Count
Add-Check 'dedicated: server still names the first peer as leader' $aId (Get-Field $sState 'leader')
Add-Check 'dedicated: the second peer does not think it leads'     0    (Get-Field $bState 'isleader')
Add-Check 'dedicated: both peers are seated, server still is not'  (Get-IdSet ($aId + ',' + $bId)) (Get-IdSet (Get-Field $sState 'peers'))

Write-Host '  -- third peer arrives'
Start-Probe 'D' @("--probe-role=client", "--probe-tag=D", "--probe-port=$P_DEDICATED",
                  "--probe-quit-at=300", "--probe-leave-file=$dLeave", "--join=127.0.0.1") $dLog | Out-Null
$dJoined = Wait-ForPattern $dLog '^NETPROBE D JOINED ' 60 'client D never completed the handshake'
$dId = Get-Field $dJoined 'self'
Write-Host ("     client D is peer {0}" -f $dId)
Wait-ForPattern $dLog '^NETPROBE D EVENT ' 60 'third peer was never told who leads' | Out-Null
Wait-ForPattern $sLog (Get-SeatPattern 'S' ($aId + ',' + $bId + ',' + $dId)) 30 'server never seated all three peers' | Out-Null

$sEvents = @(Get-LeaderEvents $sLog 'S')
$dEvents = @(Get-LeaderEvents $dLog 'D')
$sState  = Get-LastState $sLog 'S'
Add-Check 'dedicated: a third peer is also told the incumbent'    $aId $dEvents[0]
Add-Check 'dedicated: a third peer does not steal it either'      1    $sEvents.Count
Add-Check 'dedicated: all three peers seated, server still is not' (Get-IdSet ($aId + ',' + $bId + ',' + $dId)) (Get-IdSet (Get-Field $sState 'peers'))

Write-Host '  -- the leader leaves (two candidates remain)'
New-Item -ItemType File -Path $aLeave -Force | Out-Null
Wait-ForPattern $aLog '^NETPROBE A LEAVE ' 30 'client A never acted on its leave file' | Out-Null
Wait-ForPattern $sLog ('^NETPROBE S EVENT .*leader=' + $bId + '\s*$') 60 'the role was never handed over' | Out-Null
Wait-ForPattern $bLog ('^NETPROBE B STATE .*isleader=1 ') 30 'the promoted peer never learned it leads' | Out-Null
Wait-ForPattern $sLog (Get-SeatPattern 'S' ($bId + ',' + $dId)) 30 'the departed peer was never dropped from the seat list' | Out-Null

$sEvents = @(Get-LeaderEvents $sLog 'S')
$bEvents = @(Get-LeaderEvents $bLog 'B')
$dEvents = @(Get-LeaderEvents $dLog 'D')
$sState  = Get-LastState $sLog 'S'
$bState  = Get-LastState $bLog 'B'
$dState  = Get-LastState $dLog 'D'
Add-Check 'dedicated: role passes to the LONGEST-WAITING peer, not the newest' $bId $sEvents[1]
Add-Check 'dedicated: the handover reaches the promoted client by signal' $bId $bEvents[1]
Add-Check 'dedicated: the handover reaches a BYSTANDER client too'        $bId $dEvents[1]
Add-Check 'dedicated: the promoted peer knows it leads'             1    (Get-Field $bState 'isleader')
Add-Check 'dedicated: the newest peer still does not lead'          0    (Get-Field $dState 'isleader')
Add-Check 'dedicated: the departed peer is off connected_peer_ids'  (Get-IdSet ($bId + ',' + $dId)) (Get-IdSet (Get-Field $sState 'peers'))

Write-Host '  -- the replacement leader leaves too'
New-Item -ItemType File -Path $bLeave -Force | Out-Null
Wait-ForPattern $bLog '^NETPROBE B LEAVE ' 30 'client B never acted on its leave file' | Out-Null
Wait-ForPattern $sLog ('^NETPROBE S EVENT .*leader=' + $dId + '\s*$') 60 'the role was never handed over a second time' | Out-Null
Wait-ForPattern $dLog ('^NETPROBE D STATE .*isleader=1 ') 30 'the last peer never learned it leads' | Out-Null

$sEvents = @(Get-LeaderEvents $sLog 'S')
Add-Check 'dedicated: the role hands over a SECOND time'  $dId $sEvents[2]

Write-Host '  -- the last peer leaves'
New-Item -ItemType File -Path $dLeave -Force | Out-Null
Wait-ForPattern $dLog '^NETPROBE D LEAVE ' 30 'client D never acted on its leave file' | Out-Null
Wait-ForPattern $sLog '^NETPROBE S EVENT .*leader=0\s*$' 60 'the role never returned to nobody' | Out-Null
# ⚠️ `tokens=` NON-EMPTY IS WHAT MAKES THIS THE *END* AND NOT THE BEGINNING. An
# empty seat list on its own is also the state a dedicated server boots into;
# peer_tokens deliberately outlives a departure (B-65) and is the only field that
# tells the two apart.
Wait-ForPattern $sLog '^NETPROBE S STATE .* peers=- tokens=[0-9]' 30 'the lobby never emptied' | Out-Null

$sEvents = @(Get-LeaderEvents $sLog 'S')
$sState  = Get-LastState $sLog 'S'
Add-Check 'dedicated: role returns to 0 when the last peer leaves' 0 $sEvents[3]
Add-Check 'dedicated: exactly four leader changes over the run'    4 $sEvents.Count
Add-Check 'dedicated: the empty lobby seats nobody'              '-' (Get-Field $sState 'peers')
# Documented behaviour, asserted so a "tidy up on disconnect" change trips here:
# peer_tokens/peer_characters deliberately outlive a departure so a reconnecting
# peer keeps its slot (B-65). See peer_tokens' own doc.
Add-Check 'dedicated: peer_tokens survives departure (B-65 rejoin)' (Get-IdSet ($aId + ',' + $bId + ',' + $dId)) (Get-IdSet (Get-Field $sState 'tokens'))

# The header's promise is about EVERY moment, not the moments sampled above.
$selfSeated = @(Get-ProbeLines $sLog 'S' 'STATE' | Where-Object {
    ((Get-Field $_ 'peers')  -split ',') -contains '1' -or
    ((Get-Field $_ 'tokens') -split ',') -contains '1' -or
    ((Get-Field $_ 'chars')  -split ',') -contains '1'
})
Add-Check 'dedicated: server never seats itself, in ANY sample' 0 $selfSeated.Count

# ==========================================================================
Write-Host ''
Write-Host ("SCENARIO 2 - listen host, unchanged (port {0})" -f $P_LISTEN) -ForegroundColor Cyan
# ==========================================================================

$hLog = Join-Path $LogDir 'listen-host.log'
$cLog = Join-Path $LogDir 'listen-client-C.log'

Start-Probe 'H' @("--probe-role=server", "--probe-tag=H", "--probe-port=$P_LISTEN",
                  "--probe-quit-at=300", "--host", "--port=$P_LISTEN") $hLog | Out-Null
Wait-ForPattern $hLog '^NETPROBE H HOSTING ' 60 'listen host never started hosting' | Out-Null

$hInit = @(Get-ProbeLines $hLog 'H' 'INIT')[0]
Add-Check 'listen: is_dedicated stays false'              0   (Get-Field $hInit 'dedicated')
Add-Check 'listen: host seats itself (connected_peer_ids)' '1' (Get-Field $hInit 'peers')
Add-Check 'listen: host seeds its own peer_tokens entry'   '1' (Get-Field $hInit 'tokens')
Add-Check 'listen: host seeds its own peer_characters entry' '1' (Get-Field $hInit 'chars')
Add-Check 'listen: host is its own lobby leader'          1   (Get-Field $hInit 'leader')
Add-Check 'listen: is_lobby_leader() true on the host'    1   (Get-Field $hInit 'isleader')

Write-Host '  -- a peer joins the listen host'
Start-Probe 'C' @("--probe-role=client", "--probe-tag=C", "--probe-port=$P_LISTEN",
                  "--probe-quit-at=300", "--join=127.0.0.1") $cLog | Out-Null
Wait-ForPattern $cLog '^NETPROBE C JOINED ' 60 'client C never completed the handshake' | Out-Null
Wait-ForPattern $cLog '^NETPROBE C EVENT ' 60 'client C was never told who leads' | Out-Null

$cEvents = @(Get-LeaderEvents $cLog 'C')
$hEvents = @(Get-LeaderEvents $hLog 'H')
$hState  = Get-LastState $hLog 'H'
$cState  = Get-LastState $cLog 'C'
Add-Check 'listen: the client is told the host leads'       1 $cEvents[0]
Add-Check 'listen: the client does not think it leads'      0 (Get-Field $cState 'isleader')
Add-Check 'listen: the host keeps the role when a peer joins' 1 (Get-Field $hState 'leader')
# ⚠️ NOT A BUG, BUT IT IS A CONTRACT. `host_game()` assigns lobby_leader_id
# DIRECTLY rather than through `_rpc_announce_leader`, so no signal is emitted
# for a listen host's own opening claim. Any UI that only listens and never
# reads the initial value would render blank until the first real change.
Add-Check 'listen: host emits no lobby_leader_changed for its own opening claim' 0 $hEvents.Count

# ==========================================================================
Write-Host ''
Write-Host ("SCENARIO 3 - the documented launch line, verbatim (port {0})" -f $P_DOCUMENTED) -ForegroundColor Cyan
# ==========================================================================

$dLog = Join-Path $LogDir 'documented-server.log'
$eLog = Join-Path $LogDir 'documented-client-E.log'

Start-DocumentedServer $P_DOCUMENTED $dLog | Out-Null
# `_load_map()` runs inside the same `_ready()` as `_start_hosting()`, a couple
# of lines earlier -- so its print is the last observable thing before the socket
# opens, and the only progress signal a non-probe server gives.
Wait-ForPattern $dLog '\[main\] playable extent' 90 'the documented command never reached Main._ready' | Out-Null
Start-Sleep -Seconds 2

Start-Probe 'E' @("--probe-role=client", "--probe-tag=E", "--probe-port=$P_DOCUMENTED",
                  "--probe-quit-at=120", "--join=127.0.0.1") $eLog | Out-Null
$eJoined = Wait-ForPattern $eLog '^NETPROBE E JOINED ' 60 'the documented command accepted no connection'
$eId = Get-Field $eJoined 'self'
Wait-ForPattern $eLog '^NETPROBE E EVENT ' 60 'the documented server handed out no lobby leader' | Out-Null
$eEvents = @(Get-LeaderEvents $eLog 'E')
$eState  = Get-LastState $eLog 'E'
Add-Check 'documented: `Main.tscn -- --dedicated --port=` accepts a connection' 1 (Get-Field $eState 'net')
Add-Check 'documented: the first peer is made lobby leader'                 $eId $eEvents[0]
Add-Check 'documented: that peer reports is_lobby_leader()'                 1    (Get-Field $eState 'isleader')

}
catch {
    # ⚠️ A THROWN WAIT IS A RESULT, NOT A CRASH. Every `Wait-ForPattern` timeout
    # means an expectation never happened at all -- the most interesting kind of
    # failure this harness can find. Recorded as a check so it reaches the
    # summary instead of unwinding past it and printing nothing.
    Add-Check ('ABORTED: ' + $_.Exception.Message) 'no timeout' 'timed out'
}
finally {
    # Runs on the happy path, on an assertion failure, and on a timeout alike:
    # a Godot process left alive would hold its port against the next run.
    Write-Host ''
    Write-Host 'Cleaning up processes...' -ForegroundColor DarkGray
    Stop-AllProbes
}

# ==========================================================================
Write-Host ''
Write-Host '================ SUMMARY ================'
$failed = @($script:Checks | Where-Object { -not $_.Ok })
foreach ($c in $script:Checks) {
    $mark = 'PASS'
    if (-not $c.Ok) { $mark = 'FAIL' }
    Write-Host ("{0}  {1}" -f $mark, $c.Name)
}
Write-Host '-----------------------------------------'
Write-Host ("{0} checks, {1} passed, {2} failed" -f $script:Checks.Count, ($script:Checks.Count - $failed.Count), $failed.Count)
Write-Host ("logs: {0}" -f $LogDir)
if ($failed.Count -gt 0) {
    Write-Host ''
    Write-Host 'FAILURES:' -ForegroundColor Red
    foreach ($f in $failed) {
        Write-Host ("  {0}" -f $f.Name) -ForegroundColor Red
        Write-Host ("    expected: {0}" -f $f.Expected) -ForegroundColor Red
        Write-Host ("    actual:   {0}" -f $f.Actual) -ForegroundColor Red
    }
    exit 1
}
exit 0
