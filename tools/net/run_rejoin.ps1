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

# ⚠️⚠️ THE PICKS ARE PART OF THE FIXTURE, NOT DECORATION. 🧑 2026-08-02: *"The player
# rejoins on a different player character and not the same character they were on."*
#
# Every peer here used to be BERTO -- `GameLaunch.selected_character`'s default, roster
# index 0 -- because nothing in this harness opened the CHARACTER screen. A rejoin that
# came back wearing somebody else's face was therefore invisible to every run this file
# has ever done.
#
# The dropper's Person is chosen against three lists at once:
#   * not index 0, the default every unpicked peer already has;
#   * not in `main.gd::AI_PERSON_SPREAD` ([0, 3, 6, 9]), which is what the bot holding
#     the seat while the human is away would be dealt -- so "the body kept the BOT's
#     index" and "the body kept the right index" cannot produce the same number;
#   * not the anchor's, so a seat table read off by one is not silently plausible.
# ALING NENA is 11, BEBANG is 7. Neither is reachable by accident.
$DropperCharacter = 'aling_nena'
$AnchorCharacter  = 'bebang'
# The other two tabs of the same CHARACTER screen. They cross the wire in the SAME
# `picks_for()` dictionary as the Person, so they are exercised by the same run rather
# than by a second one. KALAWANG is can 3, IKE is slipper 3; both defaults resolve to 0.
$DropperCan       = 'metal'
$DropperSlipper   = 'sike'
$AnchorCan        = 'boyben'
$AnchorSlipper    = 'crocs'

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
# ⚠️ THE REFEREE IS TOLD WHAT THE DROPPER PICKED, and it is NOT told to pick anything
# itself -- a dedicated lobby has no player at it. `--expect-*` is read-only: the referee
# uses it to judge a seat it does not own. It cannot short-circuit the thing under test,
# because nothing in `main.gd` ever reads a command-line pick for somebody else's peer.
$referee = Start-Process -FilePath $Godot -WindowStyle Hidden -PassThru -ArgumentList @(
    '--headless', '--path', $Project, 'tools/net/rejoin_run.tscn',
    '--', '--role=referee', '--dedicated', ('--port=' + $Port),
    ('--expect-character=' + $DropperCharacter),
    ('--expect-can=' + $DropperCan), ('--expect-slipper=' + $DropperSlipper)
) -RedirectStandardOutput (Join-Path $OutDir 'referee.log') `
  -RedirectStandardError  (Join-Path $OutDir 'referee.err')

# The ENet listener has to be up before anybody types its address at it.
Start-Sleep -Seconds 5

# The anchor makes a pick of its OWN as well as being told the dropper's. Both matter:
# its own keeps a third human's face in the match so the reclaim cannot be judged against
# a board of identical bots, and the `--expect-*` set is what lets the one peer that owns
# neither the node nor the session say whether the returning player looks right FROM
# OUTSIDE -- the peer class `main.gd`'s B-145 note measured reading -1 while the host and
# the owner both read the correct value.
$anchor = Start-Process -FilePath $Godot -PassThru -ArgumentList @(
    '--path', $Project, 'tools/net/rejoin_run.tscn',
    '--', '--role=anchor', ('--port=' + $Port), '--host=127.0.0.1',
    ('--wait-for=' + $WaitFor),
    ('--character=' + $AnchorCharacter),
    ('--can=' + $AnchorCan), ('--slipper=' + $AnchorSlipper),
    ('--expect-character=' + $DropperCharacter),
    ('--expect-can=' + $DropperCan), ('--expect-slipper=' + $DropperSlipper)
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
    # The dropper both PICKS and EXPECTS the same three: it is the player in the report,
    # so on its own screen "what I chose" and "what I must be wearing when I get back" are
    # the same sentence. The latecomer role takes the identical arguments -- it has never
    # been in this match, so its picks arrive through `_rpc_identify` for the first time
    # rather than being restored, which is the other half of the same table.
    $client = Start-Process -FilePath $Godot -PassThru -Wait -ArgumentList @(
        '--path', $Project, 'tools/net/rejoin_run.tscn',
        '--', ('--role=' + $ClientRole), ('--port=' + $Port), '--host=127.0.0.1',
        ('--character=' + $DropperCharacter),
        ('--can=' + $DropperCan), ('--slipper=' + $DropperSlipper),
        ('--expect-character=' + $DropperCharacter),
        ('--expect-can=' + $DropperCan), ('--expect-slipper=' + $DropperSlipper)
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

# =============================================================================
# ⚠️⚠️ THE OTHER TWO PROCESSES NOW COUNT TOWARDS THE RESULT, AND UNTIL NOW THEY DID NOT.
#
# `$exit` is the CLIENT's exit code and nothing else, so every check the referee and the
# anchor ever printed was decoration: this script said PASS while the host-side log said
# FAIL, and nobody would look. That is tolerable when the client is the only thing under
# test; it is not tolerable for the roster pick, which is a per-peer fact by construction
# -- the returning player has to be on their own fighter on EVERY screen, and the peer
# most likely to disagree is the one that never left.
#
# ⚠️ PRESENCE IS REQUIRED, NOT MERELY THE ABSENCE OF FAILURE. A check that never ran and a
# check that passed are the same thing to a grep for "FAIL", and the reclaim watch is
# event-driven: if the dropper never came back inside the anchor's `--live` window, the
# run measured nothing at all about the thing it exists to measure. So both logs must
# CONTAIN a `RECLAIM-CHECK ... ok=true` line, and must not contain `ok=false`.
# =============================================================================
$sideFail = 0
foreach ($side in @('referee', 'anchor')) {
    $log = Join-Path $OutDir ($side + '.log')
    $lines = @(Get-Content $log -ErrorAction SilentlyContinue)
    $failed = @($lines | Select-String -Pattern ('^\[' + $side + '\] FAIL'))
    if ($failed.Count -gt 0) {
        Write-Host ("`n{0}: {1} failed check(s)" -f $side, $failed.Count)
        $failed | ForEach-Object { Write-Host ("  " + $_.Line) }
        $sideFail += $failed.Count
    }
    if ($Scenario -ne 'rejoin') { continue }
    $verdicts = @($lines | Select-String -Pattern 'RECLAIM-CHECK')
    Write-Host ("`n{0} reclaim verdict:" -f $side)
    if ($verdicts.Count -eq 0) {
        Write-Host "  (none) - this process never witnessed the reclaim"
        $sideFail += 1
    } else {
        $verdicts | ForEach-Object { Write-Host ("  " + $_.Line) }
    }
    # The three-moment diff the investigation turns on, quoted verbatim rather than
    # summarised: what the seat wore while the bot had it, and what it wears now.
    $lines | Select-String -Pattern 'BOT-HOLDS|RECLAIM-PROPS' |
        ForEach-Object { Write-Host ("  " + $_.Line) }
}
if ($sideFail -gt 0) { $exit += $sideFail }

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
