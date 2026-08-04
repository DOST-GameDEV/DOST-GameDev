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
    # 'latecomer' somebody who was NEVER in this match knocking while it runs. ⚠️⚠️ THIS
    #             SCENARIO ASSERTS THE OPPOSITE OF WHAT IT USED TO. It proved a first-time
    #             mid-match joiner got a body straight away; under the 2026-08-04 rule that
    #             IS the defect. It now proves the newcomer is admitted as a SPECTATOR with
    #             no body, and is seated at the next ROLE ROTATION. See rejoin_run.gd's
    #             § THE WAITING ROOM INSIDE A RUNNING MATCH.
    # 'capacity'  the other half of that rule: with every free seat already claimed by
    #             people ahead of it in the queue, the next newcomer is REFUSED and bounced
    #             with a legible message. Six processes -- see § THE CAPACITY CASE.
    [ValidateSet('rejoin', 'latecomer', 'capacity')]
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

# ⚠️ THE PER-SCENARIO FIXTURE, IN ONE PLACE.
#
#   $ClientRole  which role the process this script WAITS on plays. It is the one under test.
#   $WaitFor     how many other humans the anchor waits for before it presses START MATCH.
#                1 for a rejoin (the dropper must be seated before it can drop out of
#                anything); 0 wherever the premise is that the match is already running when
#                the client first arrives.
#   $JoinAfter   how long that client sits before it knocks. It must be AFTER the round is
#                genuinely under way, and for 'capacity' also after every filler is queued.
#   $Fillers     extra headless newcomers that occupy the waiting queue -- see § THE CAPACITY
#                CASE in rejoin_run.gd.
#   $RefereeArgs '--nudge-round' cuts the running round's clock short once somebody is
#                actually waiting, so the ROTATION happens inside a run somebody will sit
#                through. It is a fixture over WHEN the clock reaches zero and nothing else;
#                the rotation itself is still the real `_on_time_up` chain.
$Fillers     = 0
$RefereeArgs = @()
if ($Scenario -eq 'latecomer') {
    $ClientRole = 'latecomer'; $WaitFor = 0; $JoinAfter = 30
    $RefereeArgs = @('--nudge-round')
} elseif ($Scenario -eq 'capacity') {
    # ⚠️ THREE FILLERS, AND THE NUMBER IS THE SEAT ARITHMETIC, NOT A GUESS. Four seats; the
    # anchor holds one; the referee is a seatless dedicated server. So `free_seat_count()` is
    # 3 and the queue is full at 3 -- the fourth newcomer is the one that must be refused.
    $ClientRole = 'refused'; $WaitFor = 0; $JoinAfter = 55
    $Fillers = 3
} else {
    $ClientRole = 'dropper'; $WaitFor = 1; $JoinAfter = 30
}

# ⚠️⚠️ THE NAME IS PART OF THE FIXTURE TOO, AND IT IS HANDED TO ALL THREE PROCESSES.
# 🧑: a player who joins (or rejoins) a match ALREADY IN PROGRESS has a blank name on every
# peer, and their 3D nameplate and scoreboard row fall back to the bare seat label "P2".
#
# `rejoin_run.gd::_ready()` already gave each process a distinguishable name
# (`SettingsManager.player_name = _role.to_upper()`) so bodies could be told apart in a log --
# but nothing ever ASSERTED it, which is why the defect survived every run of this file.
# Measured 2026-08-04 on the latecomer scenario, the same body on all three processes:
#
#     latecomer  PICK 1927296562 slot=1 player_name='' is_bot=false auth=1927296562
#     referee    PICK 1927296562 slot=1 player_name=''
#     anchor     PICK 1927296562 slot=1 player_name=''
#
# ...and the run said PASS.
#
# ⚠️ PASSED IN RATHER THAN LEFT TO EACH PROCESS TO DERIVE. On the client, `--expect-name` and
# `SettingsManager.player_name` come from the same `--role` by two different routes, so the
# comparison is against an EXTERNAL expectation rather than against the harness agreeing with
# itself. On the referee and the anchor it is the only way to know it at all: neither owns that
# seat, and a non-host peer cannot ask `picks_for()` about anybody.
$ExpectName = $ClientRole.ToUpper()

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
$refereeArgList = @(
    '--headless', '--path', $Project, 'tools/net/rejoin_run.tscn',
    '--', '--role=referee', '--dedicated', ('--port=' + $Port),
    ('--expect-character=' + $DropperCharacter),
    ('--expect-can=' + $DropperCan), ('--expect-slipper=' + $DropperSlipper),
    ('--expect-name=' + $ExpectName)
) + $RefereeArgs
$referee = Start-Process -FilePath $Godot -WindowStyle Hidden -PassThru -ArgumentList $refereeArgList `
  -RedirectStandardOutput (Join-Path $OutDir 'referee.log') `
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
    ('--expect-can=' + $DropperCan), ('--expect-slipper=' + $DropperSlipper),
    ('--expect-name=' + $ExpectName)
) -RedirectStandardOutput (Join-Path $OutDir 'anchor.log') `
  -RedirectStandardError  (Join-Path $OutDir 'anchor.err')

# =============================================================================
# ⚠️⚠️ § THE CAPACITY CASE. The fillers exist to make the queue FULL, and nothing else.
#
# ⚠️ HEADLESS, UNLIKE THE ANCHOR AND THE CLIENT UNDER TEST. This file's header explains why
# the clients render: the run asks whether a CAMERA is current, which has no honest answer on
# a process with no rendering device. A filler is never asked that -- it asserts that it was
# ADMITTED to the queue and that it holds NO body -- so three more windows would buy nothing
# and cost a machine already running six Godot processes.
#
# ⚠️ THEY ALL KNOCK AT THE SAME MOMENT, ON PURPOSE. `_rule_on_mid_match_arrival` is driven by
# `_rpc_identify`, which the host processes one packet at a time, so three simultaneous
# arrivals see a queue of 0, 1 and 2 against three free seats and all three are admitted.
# Staggering them would test the same thing more slowly and hide any ordering fault.
# =============================================================================
$fillerProcs = @()
for ($i = 1; $i -le $Fillers; $i++) {
    $fillerProcs += Start-Process -FilePath $Godot -WindowStyle Hidden -PassThru -ArgumentList @(
        '--headless', '--path', $Project, 'tools/net/rejoin_run.tscn',
        # ⚠️ 30, NOT `$JoinAfter`. The fillers have to be QUEUED before the peer under test
        # knocks, or the queue it finds is not full and the refusal it is measuring is a
        # different event. `$JoinAfter` is 55 for this scenario, 25 s later.
        '--', '--role=filler', ('--port=' + $Port), '--host=127.0.0.1', '--join-after=30'
    ) -RedirectStandardOutput (Join-Path $OutDir ('filler' + $i + '.log')) `
      -RedirectStandardError  (Join-Path $OutDir ('filler' + $i + '.err'))
}

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
        ('--expect-can=' + $DropperCan), ('--expect-slipper=' + $DropperSlipper),
        ('--expect-name=' + $ExpectName), ('--join-after=' + $JoinAfter)
    ) -RedirectStandardOutput (Join-Path $OutDir 'client.log') `
      -RedirectStandardError  (Join-Path $OutDir 'client.err')
    $exit = $client.ExitCode
} finally {
    foreach ($f in $fillerProcs) { Stop-Process -Id $f.Id -Force -ErrorAction SilentlyContinue }
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
# ⚠️⚠️ THE FILLERS COUNT TOWARDS THE RESULT TOO, AND IF THEY DID NOT THIS SCENARIO WOULD
# PASS FOR THE WRONG REASON. `capacity` asserts that the fourth newcomer is refused BECAUSE
# the queue is full -- so a run in which a filler was itself refused (or seated) has an empty
# queue and is measuring a completely different event with the same green tick.
#
# ⚠️ PRESENCE, NOT MERELY THE ABSENCE OF "FAIL", the rule every block in this file follows.
# A filler that never printed FILL-CHECK never reached the host at all.
# =============================================================================
$fillFail = 0
if ($Fillers -gt 0) {
    Write-Host "`nqueue verdict (the fillers that make the queue full):"
    for ($i = 1; $i -le $Fillers; $i++) {
        $lines = @(Get-Content (Join-Path $OutDir ('filler' + $i + '.log')) -ErrorAction SilentlyContinue)
        $checks = @($lines | Select-String -Pattern 'FILL-CHECK')
        if ($checks.Count -eq 0) {
            Write-Host ("  filler{0}: (none) - this process never reached the host" -f $i)
            $fillFail += 1
        } else {
            $checks | ForEach-Object { Write-Host ("  " + $_.Line) }
        }
        $failed = @($lines | Select-String -Pattern '^\[filler\] FAIL')
        if ($failed.Count -gt 0) {
            $failed | ForEach-Object { Write-Host ("  " + $_.Line) }
            $fillFail += $failed.Count
        }
    }
}
$exit += $fillFail

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

# =============================================================================
# ⚠️⚠️ THE THROW IS REQUIRED TO HAVE BEEN **WITNESSED**, NOT MERELY NOT TO HAVE FAILED.
#
# 🧑 2026-08-04: *"still cant throw on rejoin.. i have the throw animation and chargup now
# but it doesnt actually throw."* That reached a player because the check this file used to
# make asserted `RoundManager.can_throw()` -- PERMISSION -- and nothing about the prop. It
# passed on a build where the host silently refused every request.
#
# So two independent facts are demanded here, and the SECOND is the one that cannot be
# faked by the process under test:
#
#   THROW-CHECK    the thrower's own machine saw the tsinelas leave the hand and travel.
#   THROW-OBSERVED the REFEREE saw the same transition on its own copy. Throwing is
#                  host-authoritative -- the client asks, the host validates, the host
#                  broadcasts -- so this line is the host agreeing it accepted the request.
#                  `rejoin_run.gd::_watch_throws` latches only NON-BOT hands, and the only
#                  human seats in this run are the client and the anchor (who is the taya
#                  and may not throw at all), so any line here is the client's throw.
#
# ⚠️ PRESENCE, NOT THE ABSENCE OF "FAIL", for the reason the reclaim block above already
# states: a check that never ran and a check that passed are the same thing to a grep.
#
# ⚠️⚠️ DEMANDED IN THE `rejoin` SCENARIO ONLY, AND THE REASON IS THE RULES OF THE GAME RATHER
# THAN A GAP IN THE COVERAGE. Under § THE WAITING ROOM the promotion happens at a ROLE
# ROTATION, and the seat arithmetic is fixed: the anchor identifies first and takes seat 0,
# the promoted newcomer takes `_first_free_seat()` = seat 1, and `defender_slot_for(2)` is
# `(2 - 1) % 4` = 1. So the newcomer is round 2's TAYA -- the one player who may not throw at
# all -- and `_check_abilities` correctly skips the throw for it. Demanding a THROW-CHECK
# here would be demanding the game break its own rule. The `capacity` scenario has no seated
# newcomer at all. Everything else `_check_abilities` asserts (the seat table, the lata, the
# live round, the shove) still runs in every scenario.
# =============================================================================
$throwFail = 0
if ($Scenario -eq 'rejoin') {
    $clientLines = @(Get-Content (Join-Path $OutDir 'client.log') -ErrorAction SilentlyContinue)
    $throwChecks = @($clientLines | Select-String -Pattern 'THROW-CHECK')
    Write-Host "`nthrow verdict (thrower's own machine):"
    if ($throwChecks.Count -eq 0) {
        Write-Host "  (none) - the run never drove a throw at all"
        $throwFail += 1
    } else {
        $throwChecks | ForEach-Object { Write-Host ("  " + $_.Line) }
    }

    $refLines = @(Get-Content (Join-Path $OutDir 'referee.log') -ErrorAction SilentlyContinue)
    $observed = @($refLines | Select-String -Pattern 'THROW-OBSERVED')
    Write-Host "throw verdict (referee, host side):"
    if ($observed.Count -eq 0) {
        Write-Host "  (none) - the HOST never saw a slipper leave a human hand"
        $throwFail += 1
    } else {
        $observed | ForEach-Object { Write-Host ("  " + $_.Line) }
    }
}
if ($throwFail -gt 0) { $exit += $throwFail }

# =============================================================================
# ⚠️⚠️ THE NAME MUST BE RIGHT ON ALL THREE PROCESSES, AND EACH MUST HAVE SAID SO.
#
# 🧑: a player who joins (or rejoins) a match ALREADY IN PROGRESS has a blank name on every
# peer. The fix writes `player_name` on the peer that OWNS the reclaimed body -- it has to be
# written there, because that peer becomes the multiplayer authority for it and a host-side
# write would be replicated over within a frame or two (`main.gd::_apply_reclaim`'s own note,
# and the identical failure `character_index` had). That shape makes the joiner's OWN log the
# one place the value is guaranteed to look right whether or not it ever reached the wire.
#
# So a green client is explicitly NOT the verdict. The referee and the anchor each have to
# print their own NAME-CHECK, and all three lines must be present -- a check that never ran and
# a check that passed are the same thing to a grep for FAIL, the rule the two blocks above
# already state. `ok=false` is caught by the per-side FAIL sweep; this block is about SILENCE.
# =============================================================================
#
# ⚠️ SKIPPED FOR `capacity`, WHERE THERE IS NO JOINER TO NAME. Every newcomer in that
# scenario is either still in the queue or was turned away at the door, so no body anywhere
# in the match belongs to one and a NAME-CHECK would be a check about nothing. The refusal's
# own words are asserted inside `rejoin_run.gd::_refused` instead.
$nameFail = 0
if ($Scenario -ne 'capacity') {
    Write-Host "`nname verdict (a blank name here is the reported bug):"
    foreach ($side in @(@{ n = $ClientRole; f = 'client' }, @{ n = 'referee'; f = 'referee' },
                        @{ n = 'anchor'; f = 'anchor' })) {
        $lines = @(Get-Content (Join-Path $OutDir ($side.f + '.log')) -ErrorAction SilentlyContinue)
        $checks = @($lines | Select-String -Pattern 'NAME-CHECK')
        if ($checks.Count -eq 0) {
            Write-Host ("  {0}: (none) - this process never reported on the joiner's name" -f $side.n)
            $nameFail += 1
        } else {
            $checks | ForEach-Object { Write-Host ("  " + $_.Line) }
        }
    }
}
if ($nameFail -gt 0) { $exit += $nameFail }

# ⚠️ THE WAITING-ROOM EVIDENCE, QUOTED VERBATIM. These are the lines a reader needs to
# believe the three rules, so they are printed whether the run passed or failed.
Write-Host "`nmid-match arrival evidence (host side):"
Get-Content (Join-Path $OutDir 'referee.log') -ErrorAction SilentlyContinue |
    Select-String -Pattern 'waiting=\d+ free_seats=\d+|NUDGE' | Select-Object -Last 12 |
    ForEach-Object { Write-Host ("  " + $_.Line) }
Write-Host "mid-match arrival evidence (the peer under test):"
Get-Content (Join-Path $OutDir 'client.log') -ErrorAction SilentlyContinue |
    Select-String -Pattern 'WAIT-CHECK|PROMOTE-CHECK|REFUSE-CHECK' |
    ForEach-Object { Write-Host ("  " + $_.Line) }

if ($exit -eq 0) {
    if ($Scenario -eq 'latecomer') {
        Write-Host "`nPASS - a mid-match newcomer waited as a spectator and was seated at the rotation."
    } elseif ($Scenario -eq 'capacity') {
        Write-Host "`nPASS - a newcomer arriving at a full waiting queue was refused and told why."
    } else {
        Write-Host "`nPASS - a dropped player got back into the running match."
    }
} else {
    Write-Host ("`nFAIL - {0} check(s) failed. Full output: {1}" -f $exit, $OutDir)
}
exit $exit
