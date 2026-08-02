extends Node3D
class_name Slipper
## The tsinelas. **A prop, not a player.** Written 2026-07-31 on branch `HARRYDAKS`.

## ---------------------------------------------------------------------------
## ⚠️⚠️ THIS REPLACES A 1 635-LINE `Carriable` ON A 2 868-LINE `CharacterBase`.
##
## The slipper used to be a player unit that could charge a jump, launch ITSELF
## over the defender, dive at 22 m/s, steer mid-flight, dash on a cooldown, scuff
## enemy slippers by walking on them, bounce, and win a round outright without its
## thrower ever touching it. All of that is deleted. 🧑 2026-07-31: *"there were so
## many skills and stuff earlier ... too complicated and far from tumbang preso"*.
##
## WHAT SURVIVED, AND IT IS THE ONE THING WORTH KEEPING: **`_solve_arc()`**. That
## quadratic is lifted verbatim from `carriable.gd`, it is measured, and
## `trajectory_preview.gd` draws the dotted arc from the same function — so the
## line the player aims along and the line the slipper flies are the same line by
## construction rather than by two implementations agreeing. Everything around it
## (the lob's second root, the long-throw speed bonus, mid-flight steering,
## bouncing, the self-launch) is gone.
##
## ⚠️ CONTACT IS RESOLVED BY DISTANCE ON THE HOST, NOT BY AN `Area3D`. Same call as
## `RoundManager._step_tag()` and for the same recorded reason: an overlap signal
## fires on whichever peer owns the body, so a hit could resolve on a client or on
## nobody. `hit_probe` measured that directly — 16 of 36 overlaps did not land, and
## the misses were split by TARGET. A flying slipper checks one lata and up to four
## capsules per frame, on the machine that owns the score.
## ---------------------------------------------------------------------------

enum CarryState { LOOSE, CARRIED, FLYING }

signal carry_state_changed(new_state: CarryState)

## Metres/second at a full-charge throw. One number for every slipper — the four
## per-class `ThrowProfile` resources are deleted along with the classes that
## justified them.
##
## ⚠️⚠️ 17.0 -> 20.0 ON 2026-08-01, ON HUMAN INSTRUCTION: *"can u make the throws a
## bit more powerful (stronger and faster and reaches a bit farther)"*. One number
## buys all three, because they are the same number: the 45-degree range is
## `v² / GRAVITY`, so **14.45 m -> 17.11 m** (+18%), the flight is 9% faster, and
## every impulse derived from this scales with it — the body-block deflection
## (`DEFLECT_SPEED_SCALE`) and the lata recoil (`LATA_RECOIL_SCALE`) both get harder
## without a second edit.
##
## ⚠️ IT DOES NOT BREAK CONTACT SAMPLING, WHICH IS THE ONE THING THAT COULD HAVE
## GONE WRONG QUIETLY. The lata's hit window is `HIT_RADIUS + Lata.HIT_MARGIN` =
## **0.53 m** and it is tested once per physics frame, so a slipper must advance
## less than that per step or it can pass straight through. At 60 Hz: 17.0 gave
## 0.28 m/step and 18.5 gives **0.31 m/step**, still comfortably inside the window.
## `ai_probe`'s § TIME SCALE note is about exactly this failure and it is the
## reason the tick rate is raised with `Engine.time_scale` rather than instead of.
##
## ⚠️ AND NOTHING HAD TO BE RE-TUNED AROUND IT. `ai_controller::_min_power_for()`
## inverts the range equation against this constant rather than storing a table, and
## `trajectory_preview.gd` draws from `launch_velocity_for()`, so the bots' charge
## solve and the player's dotted arc both followed it on their own. *Verified after
## the change: `mech_probe`'s §2.16 check still reports the preview and the flight
## landing in the same place on every skin.*
const LAUNCH_SPEED: float = 18.5
## A tap still throws, at this fraction of full speed, so an accidental click is a
## weak throw and not a dropped input. Mirrors `Carrier.CHARGE_MIN_POWER`.
const MIN_POWER_SCALE: float = 0.35
## Effective radius of the slipper for contact. Generous over the mesh, the same
## margin the Person's Hurtbox keeps over its body capsule.
const HIT_RADIUS: float = 0.23
## Ceiling on a flight, so a slipper thrown at the sky cannot hang forever and
## strand its owner without a slipper to retrieve.
const MAX_FLIGHT_TIME: float = 6.0
## The thrower cannot block their own throw for this long after release.
const THROWER_IGNORE_TIME: float = 0.25
## Where a LOOSE slipper sits relative to the floor it landed on — i.e. the height
## of the mesh ORIGIN above the ground when the slipper is lying still.
##
## ⚠️ 0.08 -> 0.045 ON 2026-08-01, BECAUSE THE MESH ORIGIN MOVED (§ 5.2/5.4).
## The four new slippers are centred on their VOLUME CENTROID rather than on the
## sole's underside, which `Agent_Prompts.md` § 5.2 requires: the `Visual` node is
## spun about the mesh origin on two axes at once (SPIN_SPEED_DEG 900,
## TUMBLE_SPEED_DEG 520), so an origin at the underside made a thrown slipper
## orbit its own sole instead of spinning in place. With the origin at the middle
## of the slipper, "resting on the floor" is half a slipper up, not zero.
##
## ⚠️ THIS IS ONLY THE FALLBACK NOW — the live value is `_rest_height`, MEASURED
## off whichever mesh the skin swapped in. One constant could not serve four
## slippers: in world units they need tsinelas 0.034 · sike 0.043 ·
## pantulog 0.056 · **crocs 0.161**, because a crocs is a tall hollow shell whose
## centroid sits at 53% of its height rather than near the sole. Any constant that
## suits the three flat ones buries the crocs to the laces. See
## `_measure_rest_height()`.
##
## 0.045 is kept as the value a slipper uses before any skin is applied, which is
## the three-flat-slipper average and cannot look wrong on the default.
const REST_HEIGHT: float = 0.045
## Visual spin about the long axis while airborne, degrees/second.
const SPIN_SPEED_DEG: float = 900.0
## End-over-end tumble, degrees/second. A real thrown slipper does both at once;
## doing only the spin is what made the predecessor read as "flying perfectly flat".
const TUMBLE_SPEED_DEG: float = 520.0
## How far below the arena a slipper has to fall before it is considered lost and
## returned to its spawn rather than falling forever.
const VOID_Y: float = -12.0

@onready var _visual: Node3D = $Visual

## This slipper's own position in `main.gd`'s `slippers` array (0/1/2 for
## Slipper1/2/3 — set directly on each instance in Main.tscn). A plain int
## rather than looked up at call time on purpose: it is the stable identifier
## every mutation RPC is now addressed by (see `_main_rpc`'s own doc), and
## "a value that must always hold, write it directly" is the exact rule
## `owner_slot` already learned the hard way.
@export var slipper_index: int = -1

## 0..3, whoever last held it. -1 when nobody has. The score for knocking the lata
## down is credited to this slot.
var owner_slot: int = -1
var state: CarryState = CarryState.LOOSE
## Set while CARRIED. The unit whose hand this is in.
var carrier: CharacterBase = null

## Where this slipper starts a round, so a lost one has somewhere to come back to.
var spawn_position: Vector3 = Vector3.ZERO

var _velocity: Vector3 = Vector3.ZERO
var _flight_time: float = 0.0
var _thrower_ignore_left: float = 0.0
var _thrower: CharacterBase = null

func _ready() -> void:
	spawn_position = global_position
	set_multiplayer_authority(1) # host-owned; there is no player to hand it to
	# `carrier.gd::_find_grabbable()` scans this group rather than the scene tree,
	# so a slipper spawned anywhere is pickable without anybody registering it.
	add_to_group("slippers")
	# ⚠️ RUNS LAST IN `_process`, AND THAT IS WHAT PUTS THE SLIPPER IN THE HAND.
	# A carried slipper copies its carrier's hand transform, and that hand is a
	# `BoneAttachment3D` driven by the SKELETON, which the AnimationPlayer moves
	# during idle processing. Copying it from `_physics_process` therefore reads
	# the hand's position from BEFORE this frame's animation ran, so the slipper
	# trails the palm permanently — measured at 98 mm with the carrier standing
	# perfectly still, which is the reported "the shoe would float". A high
	# priority makes this node process after the characters, so `_step_carried()`
	# re-syncs against the hand's FINAL position for the frame.
	process_priority = 100
	_sample_floor.call_deferred()
	_set_state(CarryState.LOOSE)

## ⚠️ THE CARRY POSE IS UPDATED HERE, NOT ONLY IN `_physics_process`, for the
## frame-ordering reason in `_ready()`. Flight and contact stay in the physics
## step where they belong — this is a visual re-sync of a transform that is
## already being driven, so doing it twice in a frame costs two vector copies and
## cannot desync anything: it is derived entirely from the carrier's own
## replicated transform, on every peer, exactly as `_step_carried()` documents.
func _process(_delta: float) -> void:
	# ⚠️ ONLY FOR A CARRIER WITH NO HAND BONE. When `_attach_to_hand()` succeeded
	# the slipper IS a child of the hand and inherits its transform exactly, so
	# touching it here would fight the scene tree for no gain. This is the belt for
	# the one case reparenting cannot cover.
	if state == CarryState.CARRIED and carrier != null \
			and get_parent() != carrier.get_hand_attachment():
		_step_carried()

## ---------------------------------------------------------------------------
## QUERIES — the gates `carrier.gd` and the HUD ask.
## ---------------------------------------------------------------------------

func is_loose() -> bool:
	return state == CarryState.LOOSE

func is_flying() -> bool:
	return state == CarryState.FLYING

## ⚠️⚠️ REVERSED 2026-08-01: A SLIPPER BELONGS TO ONE ATTACKER AND NOBODY ELSE CAN
## TOUCH IT. This used to be "any attacker may pick up any loose slipper, and doing
## so reassigns ownership", on the reasoning that hunting for your specific one
## *"reads as a bug"*. 🧑 replaced it: *"Personal Ownership: Each slipper is uniquely
## color-coded and tied strictly to its owner. Opponents cannot pick up or tamper
## with another player's slipper."*
##
## The old rule quietly deleted the three-way rivalry. If any slipper serves any
## attacker, the nearest one is always the right one and there is nothing to
## contest — whereas ownership means the pile inside the box is three separate
## problems, and the shove exists to make somebody else's problem worse. It is also
## what makes the floor glow and the foot arrow legible: an indicator can only point
## at YOUR slipper if the word "yours" means something.
##
## ⚠️⚠️ `owner_slot` IS ASSIGNED AT EVERY ROUND RESET — AND UNTIL 2026-08-01 THIS
## COMMENT CLAIMED THAT AND IT WAS NOT TRUE. Nothing wrote the field at spawn:
## the only writers were `_apply_grabbed()` and `_apply_thrown()`, so a slipper
## nobody had yet touched carried `-1`, and "yours" was undefined precisely when
## the player most needs to be told which one is theirs.
##
## `main.gd::_reset_slippers()` appeared to cover it — it hands each attacker
## their slipper with `host_grab()` at the top of a round — but that is a courtesy
## pickup, not an assignment, and it can silently refuse. `can_be_grabbed_by()`
## requires `who.can_act()`, which is `round_active and state == NORMAL`, and a
## character that is still settling at a reset is neither. **Measured**
## (`fpp_carry_probe`, solo, seat 1): `Slipper1 owner_slot=-1 state=0
## carrier=false d=0.02` — sitting at its own player's feet, unowned — while the
## two the grab did reach read 2 and 3.
##
## Three shipped things read this field and every one of them fails OPEN or
## SILENT on `-1`:
##   · the foot arrow (`offscreen_indicators.gd`) never points at anything;
##   · the owner glow (`_update_owner_glow`) never lights;
##   · **the ownership RULE itself is unenforced** — the gate below opens with
##     `owner_slot >= 0`, so an unowned slipper is grabbable by ANY attacker,
##     which is exactly the rule `Design.md` §5.2 exists to impose.
##
## It is `host_assign_owner()` now, called from the reset before the grab is
## attempted, so ownership is a property of the SEAT and no longer a side effect
## of a pickup that may or may not land. `_apply_grabbed()`/`_apply_thrown()` still
## write the field and are now genuinely harmless: the gate below has already
## refused anybody but the owner, so they can only ever rewrite the same slot.
## ⚠️⚠️ ANY ATTACKER MAY PICK UP ANY SLIPPER, 2026-08-01, ON DIRECT HUMAN
## INSTRUCTION: *"allow bots and humans to pick up the slippers of others, make
## sure this works in multiplayer"*.
##
## The owner gate that used to sit here (`owner_slot >= 0 and who.player_slot !=
## owner_slot`) is GONE. Everything above it — loose, an attacker, able to act,
## not already carrying — is untouched, because each of those is a different rule
## and only the ownership one was asked about.
##
## ⚠️ `owner_slot` ITSELF STAYS AND IS STILL ASSIGNED. Ownership and permission
## were the same field and are now two things: the slipper that spawns with you is
## still YOURS for as long as the round lasts, which is what the foot arrow
## (`offscreen_indicators.gd::_find_own_slipper`) and the owner glow read. It just
## no longer stops anybody else picking it up. Deleting the field would have taken
## both of those with it for a change that was only ever about the gate.
##
## ⚠️ MULTIPLAYER-SAFE BY CONSTRUCTION, NOT BY LUCK. Every grab funnels through
## `host_grab()`, which runs ONLY on the host (clients `rpc_id(1, ...)` and return),
## re-checks this function there, and broadcasts `_rpc_slipper_grabbed` (via
## `main.gd` — see `_main_rpc`'s own doc). Two attackers
## reaching for one slipper on the same frame therefore resolve in host order: the
## first `_apply_grabbed` moves it out of `CarryState.LOOSE`, and the second call
## fails the very first line below. There is no window in which both succeed,
## because there is only one machine deciding.
func can_be_grabbed_by(who: CharacterBase) -> bool:
	if who == null or state != CarryState.LOOSE:
		return false
	if who.is_defender or not who.can_act():
		return false
	return not who.holding_slipper()

## ⚠️⚠️ EVERY MUTATION RPC GOES THROUGH `main.gd`, NOT THROUGH `self`. THIS IS
## THE FIX FOR "non-host players and spectators cannot see thrown slippers."
##
## `_attach_to_hand()`/`_detach_from_hand()` reparent this node onto a
## per-peer, runtime-built path under its carrier's hand and back again on
## every pickup and throw (see `_attach_to_hand()`'s own §2.24 doc). That doc
## already fixed the identical "packets naming a node the receiver may not
## have finished constructing" problem for the automatic
## `MultiplayerSynchronizer` — silenced via `_set_sync_enabled` while carried —
## but an `@rpc` method called directly on THIS node uses the same underlying
## node-path-based targeting, and nothing ever covered that half.
##
## Measured live: a host + join test, the host AI cycling through 20+
## throw/catch loops over 46 seconds — the join client received the very
## first round-start equip (sent while every slipper was still at its
## original, since-scene-load path) and NOTHING else for the rest of the
## match. Once reparented even once, every subsequent RPC aimed directly at
## this node silently stopped arriving on non-host peers.
##
## Main.tscn's own root never reparents, so every call below routes through
## it instead, re-dispatched by `slipper_index` — a plain int, immune to path
## instability by construction, unlike a `NodePath`.
func _main_rpc(method: StringName, args: Array) -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	var full_args: Array = [method, slipper_index]
	full_args.append_array(args)
	main.callv("rpc", full_args)

## ---------------------------------------------------------------------------
## STATE TRANSITIONS. Host decides; every peer is told.
## ---------------------------------------------------------------------------

## Host-side. Says which seat this slipper belongs to for the round, or -1 for
## "nobody" (the spare slipper in a match with fewer than three attackers).
##
## ⚠️ REPLICATED, LIKE EVERY OTHER STATE CHANGE ON THIS OBJECT, and for the reason
## `Design.md` §7 gives about the lata's `is_upright`: a `MultiplayerSynchronizer`
## writes a property directly, so the setter's side effects never run on the peer
## that RECEIVED it. The owner glow is driven off this value on every peer
## independently, so it has to arrive as a call, not as a silent property write.
##
## ⚠️ IT DOES NOT TOUCH `carrier` OR `state`. Ownership and possession are
## different questions — a loose slipper lying in the box still belongs to
## somebody, and that is the whole point of the field.
func host_assign_owner(slot: int) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if NetworkManager.is_networked():
		_main_rpc("_rpc_slipper_owner", [slot])
	else:
		_apply_owner(slot)

func _apply_owner(slot: int) -> void:
	if owner_slot == slot:
		return
	owner_slot = slot
	# The glow is per-peer and polls, but ownership also changes when the ROLE
	# rotates and no state change on this slipper fires for that — so nudge it
	# here rather than waiting for a poll that may be gated on state.
	_update_owner_glow()

## ⚠️⚠️ THE ROUND-START EQUIP. New 2026-08-01, on human instruction: *"At the
## beginning of each round, automatically equip each player's personal slipper in
## their hand. This should eliminate the need for players to manually pick it up at
## the start of the round."*
##
## ⚠️ IT IS A SEPARATE ENTRY POINT FROM `host_grab()` ON PURPOSE, AND THE REASON IS
## §6 TRAP 12 ALMOST EXACTLY. `main.gd::_reset_slippers()` has always ended with a
## courtesy `host_grab()`, and that call **can silently refuse**:
## `can_be_grabbed_by()` requires `who.can_act()`, which is `round_active and state
## == NORMAL`, and a character being reset at a round boundary is neither. So
## whether you started the round holding your slipper depended on frame timing.
## That is the same shape as the `owner_slot` bug — a value that must always hold,
## inferred from an action that has its own preconditions.
##
## So the equip WRITES, and it keeps only the two gates that are about the RULES
## rather than about the moment: a defender never holds a slipper, and nobody ever
## holds somebody else's (`Design.md` §5.2). It deliberately does not ask
## `can_act()`, because "the round has not started yet" is precisely when this runs.
func host_force_equip(who: CharacterBase) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if who == null or who.is_defender:
		return
	if state == CarryState.CARRIED and carrier == who:
		return
	if owner_slot >= 0 and who.player_slot != owner_slot:
		return
	# ⚠⚠ THE CARRIER MUST ALREADY BE REGISTERED, OR THIS CREATES A SLIPPER
	# NOBODY HOLDS AND NOBODY CAN FETCH. `_apply_grabbed()` resolves the carrier
	# through `RoundManager.player_at()`; if that comes back null the prop still
	# enters CARRIED, so it is no longer LOOSE (fetch refuses it) and no character
	# knows it is held (throw refuses it). Measured, when this was called during
	# the round reset: 0 throws in a whole match and three bots stuck in FETCH.
	if RoundManager.player_at(who.player_slot) != who:
		return
	if NetworkManager.is_networked():
		_main_rpc("_rpc_slipper_grabbed", [who.player_slot])
	else:
		_apply_grabbed(who.player_slot)

func host_grab(by: CharacterBase) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if not can_be_grabbed_by(by):
		return
	if NetworkManager.is_networked():
		_main_rpc("_rpc_slipper_grabbed", [by.player_slot])
	else:
		_apply_grabbed(by.player_slot)

func _apply_grabbed(slot: int) -> void:
	owner_slot = slot
	carrier = RoundManager.player_at(slot)
	_velocity = Vector3.ZERO
	_set_state(CarryState.CARRIED)
	if carrier != null:
		carrier.notify_holding(self)
		AudioManager.play_at("pickup", global_position)

## `origin` and `target_point` come from the thrower's own aim solve, so the arc
## passes through the crosshair rather than through the character's centre.
func host_throw(from: CharacterBase, origin: Vector3, target_point: Vector3,
		power: float) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if state != CarryState.CARRIED or from == null:
		return
	# ⚠️ THE SKIN'S SPEED SCALE IS APPLIED HERE AND IN `launch_velocity_for()`, AND
	# IT HAS TO BE BOTH. `trajectory_preview.gd` draws the dotted arc from that
	# static, and `Design.md` §12 keeps it shared precisely so the aim line and the
	# flight line are one line by construction. Scaling only one of them would have
	# reintroduced the drift that sharing it exists to prevent (§2.16).
	var speed: float = LAUNCH_SPEED * lerpf(MIN_POWER_SCALE, 1.0, clampf(power, 0.0, 1.0)) \
		* speed_scale()
	var direction := _solve_arc(origin, target_point, speed)
	if NetworkManager.is_networked():
		_main_rpc("_rpc_slipper_thrown", [from.player_slot, origin, direction * speed])
	else:
		_apply_thrown(from.player_slot, origin, direction * speed)

func _apply_thrown(slot: int, origin: Vector3, launch_velocity: Vector3) -> void:
	owner_slot = slot
	_thrower = RoundManager.player_at(slot)
	if _thrower != null:
		_thrower.notify_holding(null)
	carrier = null
	global_position = origin
	_velocity = launch_velocity
	_flight_time = 0.0
	_thrower_ignore_left = THROWER_IGNORE_TIME
	_set_state(CarryState.FLYING)
	AudioManager.play_at("throw_release", origin)

## Dropped where it stands — used when a carrier is stunned, tagged, or the round
## ends with a slipper in hand.
func host_drop() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if state != CarryState.CARRIED:
		return
	if NetworkManager.is_networked():
		_main_rpc("_rpc_slipper_landed", [global_position])
	else:
		_apply_landed(global_position)

## How fast a blocked slipper leaves the blocker, and how steeply. The speed is a
## fraction of `LAUNCH_SPEED` rather than a fresh constant so a deflection can never
## out-travel the throw that produced it.
## ⚠️⚠️ 0.24, DOWN FROM 0.62, AND THIS IS THE FIX FOR §2.30 — THE TAYA'S SCORING
## VERB. 🧑 2026-08-01: *"taya cant tag while can is down, to make it playable for
## defender, make the rebound/recoil of slippers weaker so that the attackers have
## to pick up the slippers inside the box and risk getting tagged"*.
##
## ⚠️ IT REVERSES AN EARLIER INSTRUCTION AND THE REASON IT CAN IS THAT THE GAME
## MOVED UNDER IT. 0.62 was set for *"it bounces off a far distance into the open
## field rather than dropping dead at their feet. This prevents slipper
## clustering"*, and that was the right call for the game as it stood: the block
## used to drop the slipper on the taya's own mark, so every block left another
## slipper on the pile the attackers then had to wade into.
##
## What it also did, unnoticed, was **delete the taya's only way to score**. An
## attacker is taggable exactly while holding a slipper INSIDE the box
## (`is_taggable()`), so a block that lands the slipper OUTSIDE the box means the
## retrieval never enters the box, and the tag never gets a chance to happen. That
## is most of the 22.5% → 1.8% collapse recorded in §2.30.
##
## Measured, at `LAUNCH_SPEED` 18.5 and `GRAVITY` 20.0: `DEFLECT_LIFT` 5.0 keeps
## the slipper airborne 0.50 s either way, so the travel is the speed.
##   0.62 → 11.5 m/s → **5.7 m**, i.e. from a taya near the mark to the chalk or
##          past it. Retrieval is safe; nobody is ever taggable.
##   0.27 →  5.0 m/s → **2.5 m**, which is where it sits. 🧑 settled on it directly:
##          *"im talking abt the slippers btw for 2.5 m"*. The attacker has to walk
##          well inside the chalk for it and is taggable from the moment they pick
##          it up, which is the whole point.
## The clustering the old value fixed does not come back: the direction is still
## "away from the blocker, outward from the box" (see `_host_deflect_from`), so a
## block still moves the slipper off the taya's feet — it just no longer clears
## the court with it.
const DEFLECT_SPEED_SCALE: float = 0.27
const DEFLECT_LIFT: float = 5.0

## Bounces a blocked slipper back out into the open. Host-side, like every other
## state change on this object.
##
## ⚠️ THE DIRECTION IS "AWAY FROM THE BLOCKER, OUTWARD FROM THE BOX", NOT A MIRROR
## REFLECTION. A true reflection off a capsule sends the slipper wherever the
## incoming angle happens to point, which as often as not is deeper into the box —
## the exact clustering this change exists to remove. Taking the horizontal vector
## from the blocker to the slipper and pushing along it guarantees the slipper ends
## up further from the taya than it started, whatever the throw was doing.
## How hard a slipper comes off the LATA, as a fraction of `DEFLECT_SPEED_SCALE`.
## Small on purpose: this is meant to look like a collision, not like a second
## throw.
##
## ⚠️⚠️ NOW A FRACTION OF `LAUNCH_SPEED` IN ITS OWN RIGHT, AND THAT IS THE POINT.
## 🧑 2026-08-01, having asked for the BLOCK to be weakened: *"yo let the lata recoil
## a bit tho maybe around 1-1.5 m, js wanted to reduce recoil of slippers"*, then
## *"actually pull it back, put the recoil above a bit around 2.5m"*.
##
## Two different events that happened to share one constant. The block is about
## making the retrieval dangerous, so it wants to be SHORT; the can knock is about
## the hit reading as a collision, so it wants to be VISIBLE. Nesting this inside
## `DEFLECT_SPEED_SCALE` meant the second silently collapsed to 0.3 m the moment the
## first was cut for the tag fix — a number moving for a reason that had nothing to
## do with it, which is the whole hazard of a derived constant.
##
## ⚠️ THE TWO NUMBERS ARE NOT THE SAME AND WERE ASKED FOR SEPARATELY. 🧑:
## *"NO LATA RECOIL STAYS AT 1-1.5 m"* — the 2.5 m figure is the BLOCK
## (`DEFLECT_SPEED_SCALE`), this one is the slipper coming off the CAN and is meant
## to be the smaller of the two.
##
## 0.25 of `LAUNCH_SPEED` 18.5 is 4.6 m/s; with `LATA_RECOIL_LIFT_SCALE` 0.55 of
## `DEFLECT_LIFT` 5.0 the slipper is airborne 0.275 s, so it travels **≈ 1.3 m** —
## off the can and onto the mark's own doorstep, which still has to be walked to.
const LATA_RECOIL_SCALE: float = 0.25
## Upward kick on that recoil, as a fraction of the block's lift. Enough to get it
## off the floor so the arc is visible; not enough to send it over the taya.
const LATA_RECOIL_LIFT_SCALE: float = 0.55

## Bounces the slipper away from a point it just struck. Shared shape with
## `_host_deflect_from()` — see that function's notes on staying in `FLYING`,
## which is what makes the rebound arc, fall and land through the normal path
## rather than needing a landing of its own.
func _host_recoil_from(point: Vector3, scale: float) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	var away := global_position - point
	away.y = 0.0
	if away.length() < 0.05:
		away = Vector3(-_velocity.x, 0.0, -_velocity.z)
	if away.length() < 0.05:
		away = Vector3.FORWARD
	away = away.normalized()
	# ⚠️ A FRACTION OF `LAUNCH_SPEED`, NOT OF `DEFLECT_SPEED_SCALE`. It used to be
	# nested inside the block's scale, which meant the two could never be tuned
	# apart — and on 2026-08-01 they had to be, in opposite directions. Dropping the
	# block from 0.62 to 0.16 dragged the can's own knock down with it to a third of
	# a metre, purely because it was expressed relative to a number that was moving
	# for an unrelated reason. Two events, two constants.
	var speed := LAUNCH_SPEED * scale
	var recoiled := Vector3(
		away.x * speed, DEFLECT_LIFT * LATA_RECOIL_LIFT_SCALE, away.z * speed)
	if NetworkManager.is_networked():
		_main_rpc("_rpc_slipper_deflected", [global_position, recoiled])
	else:
		_apply_deflected(global_position, recoiled)

func _host_deflect_from(blocker: CharacterBase) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	var away := global_position - blocker.global_position
	away.y = 0.0
	if away.length() < 0.05:
		# Dead-centre hit: no usable bearing, so send it back the way it came.
		away = Vector3(-_velocity.x, 0.0, -_velocity.z)
	if away.length() < 0.05:
		away = Vector3.FORWARD
	away = away.normalized()
	var speed := LAUNCH_SPEED * DEFLECT_SPEED_SCALE
	var deflected := Vector3(away.x * speed, DEFLECT_LIFT, away.z * speed)
	if NetworkManager.is_networked():
		_main_rpc("_rpc_slipper_deflected", [global_position, deflected])
	else:
		_apply_deflected(global_position, deflected)

## ⚠️ IT STAYS IN `FLYING`, WHICH IS WHAT MAKES THE BOUNCE REAL. The slipper keeps
## being integrated by `_step_flying()`, so it arcs, falls and lands through the same
## path a throw does — including the plain-miss landing branch. A deflection that
## teleported it would have needed its own landing, its own sound and its own
## ownership handling, all of which already exist here.
func _apply_deflected(from: Vector3, new_velocity: Vector3) -> void:
	global_position = from
	_velocity = new_velocity
	# The thrower can block their own deflected slipper a moment later otherwise.
	_flight_time = 0.0

func _apply_landed(where: Vector3, audible: bool = false) -> void:
	if carrier != null:
		carrier.notify_holding(null)
	carrier = null
	_thrower = null
	_velocity = Vector3.ZERO
	global_position = Vector3(where.x, maxf(where.y, _rest_height), where.z)
	rotation = Vector3.ZERO
	if _visual != null:
		_visual.rotation = Vector3.ZERO
	_set_state(CarryState.LOOSE)
	# Every peer runs this handler, so the thud is heard on all four machines at
	# the position it happened — which is what `play_at` is for.
	if audible:
		AudioManager.play_at("slipper_land", global_position)

func host_reset_for_new_round() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if NetworkManager.is_networked():
		_main_rpc("_rpc_slipper_landed", [spawn_position])
	else:
		_apply_landed(spawn_position)

## ⚠️⚠️ A CARRIED SLIPPER IS RE-PARENTED ONTO THE HAND. THIS IS THE FIX FOR THE
## BUG THAT KEPT COMING BACK. 🧑, repeatedly: *"the shoe would float"*, *"the
## slippers are inside the head of the attackers"*, *"its a reoccuring problem
## that keeps coming back"*.
##
## Every previous attempt COPIED the hand's transform once a frame, and a copy has
## three separate ways to be wrong, all of which were observed:
##   · it is read before the animation moves the bone, so it trails the palm —
##     measured at 98 mm with the carrier standing perfectly still;
##   · it needs a fallback for a rig with no hand bone, and that fallback put the
##     slipper inside the carrier's skull;
##   · it runs on a schedule, so it is wrong on every frame the schedule misses.
##
## A CHILD has none of them. The slipper inherits the bone's transform through the
## scene tree, so it is exact on every frame, on every peer, at any framerate,
## during any animation, with no ordering to get right and nothing to tune.
##
## ⚠️ IT MUST BE PUT BACK on release, or a thrown slipper flies around inside its
## thrower's arm. `_home_parent` is captured once and everything that leaves
## CARRIED restores it, preserving the world transform across the move.
var _home_parent: Node = null

func _set_state(new_state: CarryState) -> void:
	if state == new_state:
		return
	if new_state == CarryState.CARRIED:
		_attach_to_hand()
	elif state == CarryState.CARRIED:
		_detach_from_hand()
	state = new_state
	# ⚠️⚠️ THE SYNCHRONIZER IS DRIVEN FROM THE STATE, NOT FROM THE REPARENT, AND
	# THAT IS THE FIX FOR "SLIPPERS DISAPPEAR SOMETIMES POST THROW".
	#
	# 🧑 2026-08-01, with a screenshot: *"slippers disappear sometimes post throw"*.
	# Both halves of the quiet period used to be side effects of the two functions
	# above — and BOTH of those can return early. `_attach_to_hand()` silences the
	# sync only after it has found a carrier and a hand attachment; `_detach_from_
	# hand()` re-enables it only after `_home_parent` checks out AND the node is not
	# already parented there. So any path that put the slipper back by some other
	# route — `main.gd::_reset_slippers`, or the reparent-vs-RPC race in §2.24 —
	# hit `if get_parent() == _home_parent: return` and **never re-opened the
	# synchronizer**. From then on that slipper never sent another position packet:
	# on every remote peer it froze wherever it was last seen, which is exactly what
	# "it disappeared after I threw it" looks like from the other machine. It is
	# intermittent because it needs the race, which is why it read as random.
	#
	# ⚠️ §6 TRAP 12, THE SAME SHAPE A THIRD TIME. `owner_slot` was assigned by a
	# courtesy `host_grab()` that could refuse; the hand attachment was a copied
	# transform that could miss; this was a network flag set by a reparent that could
	# decline. **If a value must always hold, write it directly.** Carried means
	# silent, anything else means talking — that is a property of the STATE, and it
	# is now set from the state on every transition, whatever the reparent did.
	_set_sync_enabled(new_state != CarryState.CARRIED)
	if new_state != CarryState.CARRIED:
		_restore_shadow_casting()
	carry_state_changed.emit(new_state)


## ⚠️⚠️ THE FIX FOR "SLIPPERS RANDOMLY DISAPPEAR AND ARE JUST A SHADOW".
##
## 🧑 2026-08-01: *"sometimes the slippers randomly disappear and are just a
## shadow"*. That is not a network bug and it is not a `visible` flag — it is
## literally `SHADOW_CASTING_SETTING_SHADOWS_ONLY`, and the mechanism is a
## collision between two features that never knew about each other:
##
##   1. `camera_rig.gd::_apply_fpp_self_hide()` blanks the local player's own body
##      in first person with SHADOWS_ONLY rather than `hide()`, deliberately —
##      its own comment: *"losing your own shadow in FPP destroys the ground
##      read, so the body still casts, it just isn't drawn."* Correct, and it
##      applies that to every `GeometryInstance3D` it finds under `Visual`.
##   2. A CARRIED slipper is re-parented onto a `HandAttachment`, which lives
##      UNDER that same `Visual`. So the held slipper is swept into that sweep and
##      set to SHADOWS_ONLY along with the arms and the torso.
##
## The restore loop only walks what is under `Visual` NOW. Throw the slipper and it
## leaves that subtree while still flagged — so nothing ever puts it back, and it
## spends the rest of the match invisible with a shadow, on the thrower's machine
## only. `_detach_from_hand()` could not be trusted with this either: it has two
## early returns, which is the same thing that stranded the synchronizer above.
##
## So it is driven from the STATE, like the sync flag, and it is unconditional:
## anything not in a hand draws normally. Cheap, and it cannot be stranded.
func _restore_shadow_casting() -> void:
	var visual := get_node_or_null("Visual")
	if visual == null:
		return
	for node in visual.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = \
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if visual is GeometryInstance3D:
		(visual as GeometryInstance3D).cast_shadow = \
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# The self-hide sets `visible` on the slipper's own Visual too (see
	# `_apply_carried_self_hide`), and that restore has the same shape of hole.
	(visual as Node3D).visible = true

## ⚠⚠ THE SYNCHRONIZER IS SILENCED FOR AS LONG AS THIS PROP IS IN A HAND, AND
## THAT IS THE FIX FOR §2.24. A `MultiplayerSynchronizer` identifies its node to
## every peer BY NODE PATH. Re-parenting the slipper onto the carrier's hand moves
## it to `Main/Players/-4/Visual/<rig>/Skeleton3D/HandAttachment/HandPoint/Slipper3`
## — a path `character_visual.gd` BUILDS AT RUNTIME, independently, on each peer —
## so every position packet sent while carried names a node the receiver may not
## have finished constructing. Measured on two real peers before this fix:
## **123 `Node not found` / "Invalid packet received" errors on the client in one
## round**, and it got worse the moment every attacker started each round holding
## a slipper.
##
## Silencing costs nothing, which is why this is the right lever rather than a
## workaround: `_step_carried()`'s own note already says a carried slipper "never
## needs its own position packets while it is held", because every peer derives it
## from the CARRIER's replicated transform. The synchronizer was sending packets
## that were redundant when they arrived and errors when they did not.
##
## ⚠️ `owner_slot` IS NOT LOST WITH IT. That field is replicated by an explicit
## RPC (`_rpc_slipper_owner`, routed through `main.gd`), for the reason
## `host_assign_owner()` documents — a
## synchronizer writes a property directly and the glow's side effect never runs on
## the peer that received it. So ownership survives the quiet period intact.
func _set_sync_enabled(enabled: bool) -> void:
	var sync := get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync != null:
		sync.public_visibility = enabled

func _attach_to_hand() -> void:
	if carrier == null or not is_instance_valid(carrier):
		return
	var hand := carrier.get_hand_attachment()
	if hand == null:
		return
	if _home_parent == null:
		_home_parent = get_parent()
	if get_parent() == hand:
		return
	_set_sync_enabled(false)
	var keep := global_transform
	get_parent().remove_child(self)
	hand.add_child(self)
	global_transform = keep
	# Sit ON the hand point, not merely near it. Rotation follows the hand so the
	# slipper turns with the wrist through every clip.
	transform = Transform3D.IDENTITY
	# ⚠️⚠️ UNDO THE RIG'S SCALE OR THE SLIPPER COMES OUT 2.38x. The hand point
	# hangs off a `BoneAttachment3D` under the `Skeleton3D`, which inherits the
	# model's `PERSON_SCALE` — so a child of it is silently multiplied by it, and
	# a picked-up slipper suddenly filled the screen. 🧑: *"what the heck the
	# slippers are massive man"*. Dividing the local scale back out makes the
	# slipper's WORLD size identical held, loose and in flight, which is what
	# `HIT_RADIUS` and `REST_HEIGHT` are both quoted against.
	#
	# Read off the parent's real basis rather than hard-coded to 2.38, so a rig
	# saved at a different scale cannot reintroduce this.
	var inherited := hand.global_transform.basis.get_scale()
	scale = Vector3(
		1.0 / maxf(inherited.x, 0.0001),
		1.0 / maxf(inherited.y, 0.0001),
		1.0 / maxf(inherited.z, 0.0001))
	# ⚠️⚠️ THE **MESH** GOES ON THE PALM, NOT THE ORIGIN — 🧑 2026-08-02, checking the
	# hand fix by hand: *"its clipped on arm but phasing below it"*. Exactly right, and it
	# is the last piece of this bug rather than a new one: `character_visual.gd`'s carry
	# point is now measured to the palm, so the slipper's ORIGIN lands on the palm — and
	# the tsinelas mesh does not sit on its own origin. It is authored around the sole and
	# drawn at 1.6x (`TsinelasVisual.tscn`), so what a player sees hangs below the point
	# the code so carefully placed, and it reads as the shoe sinking through the hand.
	#
	# ⚠️ MEASURED FROM THE MESH, NOT A CONSTANT, AND THAT IS THE WHOLE LESSON OF THIS BUG.
	# `HAND_CARRY_OFFSET` was hand-tuned three times and was wrong three times. The centre
	# of the visible geometry is a fact this node can read at runtime, it is right for
	# every tsinelas in the roster without enumerating them, and a new skin with a
	# different footbed height cannot reintroduce this.
	#
	# The old code DID have this correction — in `carriable.gd::_step_carried()`, reading
	# `visual_centre_offset()`. `carriable.gd` was deleted in the pivot and the
	# compensation went with it, which is why a bug that had been fixed came back.
	var centre := _visual_centre_local()
	if centre != Vector3.ZERO:
		position -= transform.basis * centre

## The centre of what this slipper actually DRAWS, in its own local space.
##
## ⚠️ THAT SPACE INCLUDES `Visual`'s 1.6 SCALE, because the box is transformed by every
## node between here and the mesh. Which is the point: the answer is where the shoe
## appears, not where its source geometry was authored.
##
## Zero when nothing has been instanced yet, which callers must read as "not ready" rather
## than "no offset" — the same contract `character_visual.gd::visual_centre_offset()`
## keeps. `_physics_process` retries the attach every frame while carried, so a mesh that
## arrives a frame late is corrected on the next one.
func _visual_centre_local() -> Vector3:
	var visual := get_node_or_null("Visual") as Node3D
	if visual == null:
		return Vector3.ZERO
	var bounds := AABB()
	var first := true
	var to_self := global_transform.affine_inverse()
	for node in visual.find_children("*", "VisualInstance3D", true, false):
		var instance := node as VisualInstance3D
		var box: AABB = (to_self * instance.global_transform) * instance.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if visual is VisualInstance3D:
		var own_box: AABB = (to_self * visual.global_transform) \
			* (visual as VisualInstance3D).get_aabb()
		bounds = own_box if first else bounds.merge(own_box)
		first = false
	return Vector3.ZERO if first else bounds.get_center()

func _detach_from_hand() -> void:
	if _home_parent == null or not is_instance_valid(_home_parent):
		return
	if get_parent() == _home_parent:
		return
	var keep := global_transform
	get_parent().remove_child(self)
	_home_parent.add_child(self)
	global_transform = keep
	# Back at a path every peer has had since the scene loaded, so it may talk again.
	_set_sync_enabled(true)
	# The hand's inherited scale was divided out on the way in; a slipper back in
	# the world owns its own scale again. Set explicitly rather than left to the
	# restored basis, so a rounding drift cannot accumulate over a match's worth
	# of pick-ups and throws.
	scale = Vector3.ONE

## ---------------------------------------------------------------------------
## § SOFT STATS — §2.8, closed 2026-08-01. The TSINELAS tab decides three things.
##
## ⚠️ THE SCALES ARE READ OFF `skin_index`, WHICH IS THIS SLIPPER'S OWNER'S PICK.
## Every seat owns one slipper (`Design.md` §5.2/§9) and `main.gd` pushes that
## seat's tsinelas skin onto it, so the prop already knows whose it is and no
## seat lookup is needed. -1 (never picked, an AI seat before the deal, a peer on
## an older build) resolves to neutral and therefore to 1.0 — see
## `CharacterRoster.trait_scale()`.
##
## ⚠️ SPEED IS DELIBERATELY THE NARROWEST OF THE THREE. The table only spans
## `bilis` 2..4 on slippers, i.e. **±5% of `LAUNCH_SPEED`**, and that ceiling is
## not taste. `ai_controller.gd::_min_power_for()` inverts the range equation
## against `Slipper.LAUNCH_SPEED` to decide how long to charge; a per-skin launch
## speed is therefore an error term in somebody else's solve, and that file is
## 🤖 `build ai`'s. 5% sits inside the margin it already charges to (measured: hit
## rate unmoved), where 20% would have quietly made every bot holding a slow
## slipper fall short — a balance change masquerading as an AI regression, which
## is exactly what this lane's prompt warns against.
## ---------------------------------------------------------------------------

## Metres/second the blocker is pushed back at neutral POWER. Solved off the same
## `distance = v² / FRICTION_2` model `SHOVE_SPEED` and `LUNGE_SPEED` use, so all
## three impulses in the game are derived from `CharacterBase.FRICTION` rather
## than being three independently-tuned magic numbers:
## `v = sqrt(0.35 × 60) = 4.583` → **0.35 m** at neutral, 0.26–0.46 m across the
## table's `lakas` range.
##
## ⚠️ A PUSH AND NOT A STUN, AND THAT WAS A DELIBERATE REVERSAL. `apply_stagger()`
## was the obvious way to make a block cost the taya something, and it is wrong
## here: three attackers throwing at one box would chain 0.3 s stuns onto the
## defender, and `apply_stagger()`'s `max()` bounds the DURATION of one stun
## without bounding how often the next one starts. Knockback costs the taya
## POSITION, which is the resource the body block is actually about, and it cannot
## lock anybody out of the game.
##
## ⚠️ AND IT COMPOSES WITH THE PERSON TABLE FOR FREE. `apply_knockback()` divides
## by the RECEIVER's `trait_grit_scale()`, so a CROCS thrown at BEBANG (grit 5)
## barely moves her and the same throw rocks JUN-JUN (grit 2). Neither table knows
## about the other; the interaction falls out of both being real.
const BLOCK_KNOCKBACK_SPEED: float = 4.583

func speed_scale() -> float:
	return CharacterRoster.trait_scale(
		CharacterRoster.slipper_trait(skin_index, &"bilis"),
		CharacterBase.TRAIT_SPEED_PER_POINT)

func power_scale() -> float:
	return CharacterRoster.trait_scale(
		CharacterRoster.slipper_trait(skin_index, &"lakas"),
		CharacterBase.TRAIT_POWER_PER_POINT)

## ⚠️ FLOORED AT 0.1 like `CharacterBase.trait_grit_scale()`, because every caller
## DIVIDES by it and a zero would be a division by zero on the spawn path.
func grit_scale() -> float:
	return maxf(0.1, CharacterRoster.trait_scale(
		CharacterRoster.slipper_trait(skin_index, &"tatag"),
		CharacterBase.TRAIT_GRIT_PER_POINT))

## ---------------------------------------------------------------------------
## SIMULATION.
## ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	# ⚠️ POLLED, NOT DRIVEN OFF `carry_state_changed`. "Yours" also changes when the
	# ROLE rotates — the taya owns no slipper, and next round they will — and no state
	# change on this object fires for that. `_update_owner_glow()` early-outs on every
	# frame the answer has not changed, so the poll costs one comparison.
	_update_owner_glow()
	match state:
		CarryState.CARRIED:
			# ⚠⚠ RETRY THE ATTACH BEFORE FALLING BACK, AND THAT IS THE FIX FOR
			# "THE SLIPPER IS IN HER BODY". 🧑 2026-08-01, with a screenshot: *"why is
			# the slipper inside her body, make it go to her hand"*.
			#
			# `_attach_to_hand()` returns silently when `get_hand_attachment()` is
			# null, and `character_visual.gd` BUILDS that attachment at runtime — so
			# a slipper handed over before the rig finishes never becomes a child of
			# the hand, and `_step_carried()`'s last-resort branch parks it at
			# chest height relative to the BODY. That fallback exists for a rig with
			# no skeleton at all; it was catching a rig that simply was not ready yet.
			#
			# The round-start auto-equip made it the common case rather than a rare
			# one: it fires the moment a round begins, which is exactly when every
			# visual is being rebuilt. Retrying each frame costs one comparison and
			# snaps the slipper into the hand as soon as the bone exists.
			if carrier != null and is_instance_valid(carrier) 					and get_parent() != carrier.get_hand_attachment():
				_attach_to_hand()
			if carrier == null or get_parent() != carrier.get_hand_attachment():
				_step_carried()
		CarryState.FLYING:
			_step_flying(delta)
		CarryState.LOOSE:
			pass

## Rides the carrier's hand. Every peer does this locally off the carrier's own
## replicated transform, so the slipper never needs its own position packets while
## it is held — which is most of the time.
func _step_carried() -> void:
	if carrier == null or not is_instance_valid(carrier):
		return
	var hand := carrier.get_hand_attachment()
	if hand != null:
		global_position = hand.global_position
		global_rotation = hand.global_rotation
		return
	# ⚠️ THE OLD FALLBACK PUT IT INSIDE THE CARRIER'S HEAD. A CharacterBase's
	# origin is the CENTRE of its 1.6-unit capsule, so `+ UP * 1.0` is a metre
	# above the middle of the body — which is the skull, not a hand. 🧑: *"the
	# slippers are inside the head of the attackers when they charge it"*.
	#
	# `character_visual.gd::_build_hand_attachment()` now falls back to any
	# arm-ish bone, so this should be unreachable — but it is the LAST resort for
	# a rig with no skeleton at all, and "unreachable" is exactly the kind of
	# claim that turns out to be wrong on the twelfth character. Chest height,
	# forward and to the carrier's right, is where a held object belongs.
	global_position = carrier.global_position \
		+ Vector3.UP * 0.15 \
		+ carrier.global_transform.basis.x * 0.28 \
		- carrier.global_transform.basis.z * 0.20

## ⚠️⚠️ THE INVISIBLE BACK WALL — 🧑 2026-08-02, with a screenshot of a slipper sitting
## in the road well outside the court: *"pls put an invisible barrier that makes it bounce
## back and not go out of bounds as it's unreachable"*.
##
## The arena has real wall colliders (`Bounds`, measured into `CharacterBase.playable_half_x/z`
## by `main.gd::_publish_playable_extent`) and they stop PEOPLE, because a CharacterBase
## moves with `move_and_slide()`. A slipper does not: `_step_flying()` integrates a
## position by hand, so it passes through every collider in the map and lands wherever the
## arc ends. Every seat owns exactly one slipper (`Design.md` §5.2), so one that leaves the
## court does not merely look untidy — it takes a quarter of the round's offence with it
## until the round resets.
##
## ⚠️ A REFLECTION, NOT A CLAMP, AND THE DIFFERENCE IS PLAYABLE. Clamping to the wall
## would stop the slipper dead ON the boundary, which piles them along the edge — the same
## clustering the body-block deflection below was added to prevent. Reflecting sends it
## back into the court, where somebody can reach it.
##
## ⚠️ IT RUNS BEFORE THE `host_side` GATE, so it runs on EVERY peer. That is required, not
## incidental: the whole flight is simulated everywhere from one launch velocity (see
## below), and a bounce applied only on the host would put the slipper somewhere else on
## every other screen. The rule is a pure function of position and velocity, so every peer
## computes the same reflection on the same frame.
##
## ⚠️ ENERGY IS LOST ON THE BOUNCE. A perfectly elastic wall would return a slipper at
## throw speed, which is a projectile nobody threw and which can still knock the lata
## down — a point scored by the wall. 0.45 is enough to carry it clear of the boundary and
## not enough to be a shot.
const BOUNCE_RESTITUTION: float = 0.45

## How far inside the wall face the slipper turns around. Its own contact radius, so the
## visible shoe never buries itself in a facade before reversing.
const BOUNCE_INSET: float = HIT_RADIUS

func _bounce_off_bounds() -> void:
	var limit_x: float = CharacterBase.playable_half_x - BOUNCE_INSET
	var limit_z: float = CharacterBase.playable_half_z - BOUNCE_INSET
	if limit_x > 0.0 and absf(global_position.x) > limit_x:
		global_position.x = signf(global_position.x) * limit_x
		# ⚠️ `-absf`, NOT `-=` OR A FLIP. A plain sign flip would send a slipper that is
		# somehow already outside and travelling inward back out again — and being outside
		# is exactly the state this function exists to recover from, so it must not have a
		# way to make it worse. This form always ends up pointing at the court.
		_velocity.x = -signf(global_position.x) * absf(_velocity.x) * BOUNCE_RESTITUTION
	if limit_z > 0.0 and absf(global_position.z) > limit_z:
		global_position.z = signf(global_position.z) * limit_z
		_velocity.z = -signf(global_position.z) * absf(_velocity.z) * BOUNCE_RESTITUTION

## ⚠️ FLIGHT IS SIMULATED ON EVERY PEER FROM THE SAME LAUNCH VELOCITY, and only
## the HOST resolves contact. Both halves matter. Simulating everywhere means the
## arc is smooth on a client instead of being 4 Hz of interpolated packets, which
## is what a spectator actually watches. Resolving only on the host means the
## knockdown and its +100 cannot happen twice or on the wrong machine.
func _step_flying(delta: float) -> void:
	_flight_time += delta
	if _thrower_ignore_left > 0.0:
		_thrower_ignore_left = maxf(0.0, _thrower_ignore_left - delta)
	_velocity.y -= CharacterBase.GRAVITY * delta
	global_position += _velocity * delta
	_bounce_off_bounds()
	_spin(delta)

	var host_side := not NetworkManager.is_networked() or NetworkManager.is_host()
	if not host_side:
		return

	if global_position.y < VOID_Y or _flight_time >= MAX_FLIGHT_TIME:
		host_reset_for_new_round()
		return

	var blocker := _first_body_hit()
	if blocker != null:
		# ⚠️⚠️ THE BODY BLOCK NOW DEFLECTS INSTEAD OF DROPPING DEAD. 🧑 2026-08-01:
		# *"When a thrown slipper hits the Defender's body-block, it bounces off a
		# far distance into the open field rather than dropping dead at their feet.
		# This prevents slipper clustering and gives Attackers room to maneuver for
		# retrieval."*
		#
		# The old comment argued the drop-at-contact WAS the trade — "they stopped
		# the throw, and now the slipper is deep inside their box". In practice that
		# compounded with itself: every block left another slipper on the taya's
		# mark, so a taya who blocked well ended up standing on a heap of them, and
		# the attackers' only route back was through the one square metre the taya
		# never leaves. Deflecting keeps the block (the throw is still stopped, the
		# lata still stands) and removes the clustering.
		AudioManager.play_at("hit_body", global_position)
		# ⚠️⚠️ §2.11 — THE BLOCK NOW DOES SOMETHING TO THE BLOCKER, AND UNTIL
		# 2026-08-01 IT DID NOT. Body-blocking is the taya's entire passive verb and
		# the only thing it produced was a sound at a world position: no flash on the
		# body that made the block, no recoil, nothing at all on the blocker's own
		# screen. A verb with no feedback is a verb the player cannot tell they
		# performed, which is most of why §2.11 and §2.22 are the same complaint
		# written from two sides.
		#
		# The push is scaled by the THROWER's slipper POWER and divided by the
		# BLOCKER's own GRIT inside `apply_knockback()`, so both stat tables are live
		# in a single contact. See § SOFT STATS.
		var push := Vector3(_velocity.x, 0.0, _velocity.z)
		if push.length() > 0.01:
			blocker.host_apply_block(
				push.normalized() * BLOCK_KNOCKBACK_SPEED * power_scale())
		_host_deflect_from(blocker)
		return

	# ⚠️ NOT NAMED `lata` — a local of that name SHADOWS the `Lata` class, and every
	# member access on it then resolves against nothing.
	# ⚠️ THE `0.30` LITERAL THAT USED TO BE HERE IS NOW `Lata.hit_margin()`, AND
	# THAT WAS A REAL DEFECT AND NOT A TIDY-UP. `Design.md` §7 lists the lata's
	# hurtbox as 0.30 r / 0.70 h, `Lata.tscn` carries an `Area3D` authored to
	# exactly that — and NOTHING READ EITHER OF THEM. The number that actually
	# decided every knockdown in the game was this bare literal, so the balance
	# source of truth documented a shape the rules ignored and the scene shipped a
	# node with no reader. The margin has a name and an owner now, and it is where
	# the lata's GRIT stat lands.
	var target: Lata = RoundManager.lata
	if target != null and target.is_upright \
			and _flat_distance(global_position, target.global_position) \
				<= HIT_RADIUS + target.hit_margin() \
			and absf(global_position.y - target.global_position.y) < 1.0:
		target.host_knock_down(owner_slot)
		# ⚠️⚠️ IT RECOILS OFF THE LATA NOW INSTEAD OF STOPPING DEAD. 🧑 2026-08-01:
		# *"the slippers should bounce back a bit when it hits stuff, it doesn tlook
		# like real physics"* and *"make it as well so that they recoil a bit when
		# it hits something"*. Landing the instant it touched was the single most
		# unphysical moment in the game: the slipper went from 17 m/s to lying flat
		# in one frame, on the exact beat a spectator is watching hardest.
		#
		# MUCH SOFTER THAN THE BODY BLOCK, and deliberately so. A block is meant to
		# fling the slipper clear of the box (see `_host_deflect_from`); this is a
		# tin can taking the hit, so it is a short knock-back that keeps the slipper
		# roughly where it landed. The can is what flies here, not the slipper.
		#
		# ⚠️ SCALED BY THE CAN'S OWN POWER STAT SINCE 2026-08-01 (§2.8). This is
		# where a heavy can pays off defensively: it throws the tsinelas further
		# from the mark, so the retrieval that follows is longer — which is the
		# taya buying time in the one currency `Design.md` §0 says the game is
		# about. BOYBEN (lakas 5) sends it 14% further than PASIP (lakas 1) sends
		# it 14% less.
		_host_recoil_from(target.global_position,
			LATA_RECOIL_SCALE * target.power_scale())
		return

	# ⚠️ THE GROUND IS FOUND, NOT ASSUMED TO BE AT y = 0. Both maps put their road
	# and paving at y = 0.1, so testing `y <= _rest_height` let every throw sink
	# 100 mm through the road before it registered as landed — visibly phasing
	# into the floor. `_ground_under()` raycasts, so this is also correct on a
	# kerb, a plaza step, or anything a later map puts underfoot.
	if global_position.y <= _floor_y + _rest_height:
		# ⚠️⚠️ §2.17 — `audible` IS TRUE HERE AND NOWHERE ELSE, AND THAT IS THE FIX.
		# `slipper_land` has been registered in `audio_manager.gd` with a mix level
		# of its own since the sound pass and had **never had a caller**: a throw
		# that hit a body played `hit_body`, a throw that hit the can played
		# `can_knockdown`, and a throw that simply missed — by far the most common
		# outcome, 38 of 71 flights in the 2026-08-01 baseline — landed in total
		# silence. The one shot the attacker most needs to hear the result of was
		# the one shot the game said nothing about.
		#
		# It is a parameter rather than a line inside `_apply_landed()` because that
		# function is shared with `host_drop()` and `host_reset_for_new_round()`, and
		# a round reset teleports three slippers home on one frame — putting the
		# sound in there would have played a triple thud at the start of every round.
		var rest := _ground_under(global_position)
		if NetworkManager.is_networked():
			_main_rpc("_rpc_slipper_landed", [rest, true])
		else:
			_apply_landed(rest, true)

## Anyone but the thrower, during the ignore window. A slipper that clipped its
## own thrower on release was the single most common "my throw did nothing"
## report against the predecessor.
func _first_body_hit() -> CharacterBase:
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null:
			continue
		if who == _thrower and _thrower_ignore_left > 0.0:
			continue
		if not who.can_be_hit_by_slipper():
			continue
		# Capsule, not sphere: a slipper passing over a crouched head and one
		# passing through a chest are different events and a sphere conflates them.
		if _flat_distance(global_position, who.global_position) > HIT_RADIUS + who.capsule_radius():
			continue
		var dy := global_position.y - who.global_position.y
		if dy < -who.capsule_height() * 0.5 or dy > who.capsule_height() * 0.5:
			continue
		return who
	return null

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## ⚠️ THE FLOOR IS NOT AT y = 0 AND THIS USED TO ASSUME IT WAS.
## Both maps sit their road and paving at **y = 0.1** (`build_*.py` reports
## "floor+paving both at y=0.1"), so returning a flat `_rest_height` dropped every
## landed slipper 100 mm INTO the road — 🧑: *"make sure too none of the slipper
## models phase thru ground when thrown"*. Raycasting finds the surface actually
## under the slipper, which also means it lands correctly on the kerb, the plaza
## step and anything a future map puts there instead of only on flat ground.
##
## Falls back to the old flat answer if the ray finds nothing, so a slipper over a
## hole still resolves somewhere rather than returning a null position.
func _ground_under(where: Vector3) -> Vector3:
	return Vector3(where.x, _floor_y + _rest_height, where.z)

## The court's floor height, sampled ONCE.
##
## ⚠️ SAMPLED ONCE, NOT RAYCAST PER FRAME, AND BOTH HALVES OF THAT ARE SCARS.
##
## Per-frame raycasting hung the game outright: the landing test runs for every
## flying slipper every frame, and a query built and thrown away that often — with
## an exclusion list rebuilt from `RoundManager.players()` each time — was enough
## to stall a match to a standstill.
##
## And the ray had to exclude the players anyway, which is the subtler half. A
## `CharacterBase` is a `CharacterBody3D`, and a slipper leaves the hand at chest
## height INSIDE its thrower's own capsule — so a ray dropped from above it hit
## that capsule first and reported "the ground is at head height". The very next
## frame's `y <= rest` test passed and the throw landed on the frame it was
## released: zero flights in a 50-second match, no knockdowns, and three bots that
## looked frozen mid-wind-up. Nothing about that reads as a raycast bug.
##
## One sample is correct here because the court IS flat — both builders assert it
## (`surfaces.verify()` aborts on a marking that spans a step) and every marking,
## the base circle and the lata all sit on the same plane. `0.1` is the value both
## maps actually use; the sample just avoids hard-coding it.
var _floor_y: float = 0.0

func _sample_floor() -> void:
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(spawn_position.x, spawn_position.y + 3.0, spawn_position.z),
		Vector3(spawn_position.x, spawn_position.y - 6.0, spawn_position.z))
	query.collide_with_areas = false
	var blocked: Array[RID] = []
	for node in RoundManager.players():
		var who := node as CollisionObject3D
		if who != null:
			blocked.append(who.get_rid())
	query.exclude = blocked
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		_floor_y = (hit["position"] as Vector3).y

func _spin(delta: float) -> void:
	if _visual == null:
		return
	_visual.rotate_z(deg_to_rad(SPIN_SPEED_DEG) * delta)
	_visual.rotate_x(deg_to_rad(TUMBLE_SPEED_DEG) * delta)

## ---------------------------------------------------------------------------
## ⚠️ LIFTED VERBATIM FROM `carriable.gd::_solve_arc`, MINUS THE LOB'S HIGH ROOT.
##
## Solves the launch DIRECTION that puts a projectile of the given speed through
## `target` from `origin` under `CharacterBase.GRAVITY`. `trajectory_preview.gd`
## calls this same function to draw the dotted arc, which is why the preview
## cannot drift from the throw.
## ---------------------------------------------------------------------------
static func _solve_arc(origin: Vector3, target: Vector3, speed: float) -> Vector3:
	var to_target := target - origin
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	var distance := flat.length()
	# Straight up, straight down, or on top of us: no arc to solve, just throw
	# along the line. Also guards the division below.
	if distance < 0.05 or speed < 0.01:
		return to_target.normalized() if to_target.length() > 0.01 else Vector3.FORWARD
	var gravity: float = CharacterBase.GRAVITY
	var v2 := speed * speed
	var discriminant := v2 * v2 - gravity * (gravity * distance * distance + 2.0 * to_target.y * v2)
	if discriminant < 0.0:
		# ⚠️ OUT OF RANGE — no launch angle at this speed reaches that point, so
		# there is nothing to solve and the honest thing is to throw along the
		# player's own line and let it fall short. Deliberately NOT the
		# maximum-range 45 degrees: aiming at a distant wall would then fire a
		# lob straight up, which is a far stranger thing to have happen than a
		# throw that visibly does not get there.
		return to_target.normalized()
	var root := sqrt(discriminant)
	var tangent := (v2 - root) / (gravity * distance)
	return (flat.normalized() + Vector3.UP * tangent).normalized()

## Used by `trajectory_preview.gd` so the dotted line is sampled from the same
## launch velocity the throw will actually use.
##
## ⚠️ `skin_speed_scale` DEFAULTS TO 1.0 rather than being required, so every
## existing caller still resolves and an aim line drawn before a skin is pushed is
## the neutral one — which is exactly what an unpicked slipper throws. `carrier.gd`
## passes the held slipper's own `speed_scale()`.
static func launch_velocity_for(origin: Vector3, target: Vector3, power: float,
		skin_speed_scale: float = 1.0) -> Vector3:
	var speed: float = LAUNCH_SPEED * lerpf(MIN_POWER_SCALE, 1.0, clampf(power, 0.0, 1.0)) \
		* skin_speed_scale
	return _solve_arc(origin, target, speed) * speed

## ---------------------------------------------------------------------------
## SKINS. The character screen's TSINELAS tab picks one of these, and this is what
## makes that pick a real choice rather than a dead control.
##
## ⚠️ THE HOST'S PICK WINS AND IS BROADCAST. There is one set of slippers in the world and
## all four players look at it, so it cannot wear four different skins. `main.gd`
## pushes the host's index at every round start; in Single Player that is your own.
##
## ⚠️ THE MATERIAL IS DUPLICATED PER MESH BEFORE IT IS WRITTEN. An imported `.glb`
## or `.obj` shares one `Material` resource across every instance of that mesh in
## the project — writing the tint straight onto it would recolour the preview on the
## character screen, and every other copy in the scene, at the same time.
## ---------------------------------------------------------------------------

## Which roster entry this prop is wearing. -1 is "stock, never picked".
var skin_index: int = -1

## ⚠️ A SKIN IS A MESH **AND** A TINT SINCE 2026-08-01 — see the twin note in
## `lata.gd::apply_skin()` for the full reasoning. It matters more here than it
## does on the can: a Tsinelas, a Crocs, a Bakya and a Sike are four different
## silhouettes, and the slipper is the object the player tracks through the air.
func apply_skin(index: int) -> void:
	if index < 0 or index == skin_index:
		return
	skin_index = index
	var entry: Dictionary = CharacterRoster.slipper_at(index)
	_apply_model(entry)
	if not entry.has("tint"):
		return
	# ⚠️ WHITE MEANS "DO NOT TINT", AND THAT IS NOT A MICRO-OPTIMISATION.
	# `_tint_meshes()` writes the tint into `albedo_color` on EVERY surface. On a
	# TEXTURED prop that multiplies the art, so white is already a no-op. On an
	# UNTEXTURED one `albedo_color` IS the colour, so white repaints the whole
	# model white — which is exactly what happened to the classic tsinelas the
	# moment it was restored: a brown foam sole with a tan strap rendered as a
	# blank white slipper. 🧑: *"what happened to my orig sliupper bruh? it has
	# just white for its bottom"*.
	#
	# Every prop now carries its own colour, either in its texture or in its
	# materials, so white is the honest way to say "this skin brings its own
	# look". Skipping the walk makes that true for textured and untextured props
	# alike instead of only for textured ones.
	var tint: Color = entry["tint"]
	if tint == Color.WHITE:
		return
	_tint_meshes(tint)

## How long a slipper is in world units, toe to heel. Every skin is normalised to
## this regardless of what scale its author saved it at.
##
## ⚠️ IT IS THE NUMBER `HIT_RADIUS` AND `REST_HEIGHT` ARE QUOTED AGAINST, so it
## is a gameplay constant wearing a cosmetic hat. 0.691 is what the generated
## meshes already measured (0.432 mesh x the 1.6 visual scale in
## `TsinelasVisual.tscn`), kept exactly so those two constants did not have to
## move again when downloaded models arrived.
const MODEL_LENGTH: float = 0.691

## How high THIS skin's origin sits when the slipper is lying on the ground,
## measured off the mesh rather than assumed. Falls back to `REST_HEIGHT`.
##
## ⚠️ ONE CONSTANT COULD NOT SERVE FOUR SLIPPERS, AND THE CROCS IS WHY.
## Every mesh is centred on its volume centroid, so "resting on the floor" means
## "origin one half-slipper up" — and that half differs per skin. Measured, in
## world units: tsinelas 0.034 · sike 0.043 · pantulog 0.056 · **crocs 0.161**.
## A crocs is a tall hollow shell, so its centroid sits at 53% of its height
## rather than near the sole, and any constant that suits the three flat ones
## buries it to the laces. Measuring it per skin retires the whole class of bug —
## and it means a model dropped in later cannot float or sink either.
var _rest_height: float = REST_HEIGHT

## How high this skin's own origin sits when it is lying on the ground.
##
## ⚠️ PUBLIC BECAUSE THE AIM ARC HAS TO STOP WHERE THE SLIPPER ACTUALLY STOPS.
## `TrajectoryPreview` used a fixed 0.03 floor, and a CROCS rests at **0.161 m**
## (tall hollow shell, centroid at 53% of its height) against 0.034-0.056 for the
## other three — so the preview kept integrating for another 0.13 m of fall and
## drew its landing point 0.31 m long, on that skin only. Measured by `mech_probe`
## as an arc-vs-throw mismatch, which read as a preview bug; it was a per-skin
## constant being treated as a global one.
func rest_height() -> float:
	return _rest_height

## ⚠️ BUILT FROM LOCAL TRANSFORMS, NOT GLOBAL ONES. This used to compose
## `global_transform.affine_inverse() * mesh_node.global_transform`, which is
## only correct once every ancestor's global transform is up to date — and
## `apply_skin()` is called from `main.gd`'s round-reset path, while props are
## still being repositioned. Read a frame early it returned garbage, and a
## `_rest_height` of about a metre is a slipper hanging in mid-air over the road:
## 🧑, pointing at one, *"what the heck is that floating thing?"*. Walking the
## local chain instead depends on nothing outside this node.
func _measure_rest_height(visual: Node3D) -> void:
	var lowest := INF
	for node in visual.find_children("*", "VisualInstance3D", true, false):
		var mesh_node := node as VisualInstance3D
		var box: AABB = mesh_node.get_aabb()
		# Compose Slipper <- Visual <- ... <- mesh by walking up, so `Visual`'s
		# 1.6 drama scale is included and nothing global is consulted.
		var chain := Transform3D.IDENTITY
		var walk: Node = mesh_node
		while walk != null and walk != self:
			if walk is Node3D:
				chain = (walk as Node3D).transform * chain
			walk = walk.get_parent()
		for i in range(8):
			lowest = minf(lowest, (chain * box.get_endpoint(i)).y)
	# A slipper is 0.69 long, so anything past a quarter of a metre below its own
	# origin is a bad read rather than a tall shoe. Falling back to the constant
	# keeps a wrong measurement from parking the prop in the sky.
	if lowest < INF and lowest > -0.25:
		_rest_height = -lowest
	else:
		_rest_height = REST_HEIGHT

## Swaps the model under `Visual` to the one this skin names.
##
## ⚠️ IT TAKES A BARE MESH **OR** A WHOLE SCENE, and the second case is why this
## is more than one line. The four generated props are `.obj` files that load as
## a `Mesh`; the models the human sourced from Sketchfab and Poly Pizza are
## `.glb` files that load as a `PackedScene` carrying their own node hierarchy,
## materials and embedded textures. Instancing those wholesale is the ONLY way
## they keep the look they were downloaded for.
##
## ⚠️ AND IT NORMALISES THEM AT RUNTIME RATHER THAN FROM HAND-TUNED CONSTANTS.
## Downloaded models arrive at whatever scale and origin their author used — the
## Pantulog's bounding box is 41 units across and starts 18 units off its own
## origin, the Sike's is 22. Rather than storing a bespoke scale and offset per
## entry (four more numbers to get wrong, and wrong again for the next model
## somebody drops in), the AABB is measured after instancing and the wrapper is
## scaled and re-centred from it. Any model dropped into the roster comes out the
## right size, centred, with no per-model tuning at all.
func _apply_model(entry: Dictionary) -> void:
	if not entry.has("model"):
		return
	var visual := get_node_or_null("Visual")
	if visual == null:
		return
	var resource := load(String(entry["model"]))
	if resource == null:
		push_warning("Slipper.apply_skin: cannot load %s" % entry["model"])
		return

	if resource is Mesh:
		var target := visual.find_children("*", "MeshInstance3D", true, false)
		if target.is_empty():
			return
		var instance := target[0] as MeshInstance3D
		# Overrides do NOT clear themselves when the mesh beneath them changes,
		# and the surface counts need not even match — see the twin note in lata.gd.
		for surface in range(instance.get_surface_override_material_count()):
			instance.set_surface_override_material(surface, null)
		instance.mesh = resource
		_measure_rest_height(visual)
		return

	if resource is PackedScene:
		_swap_scene_model(visual, resource as PackedScene)

## Replaces `Visual`'s contents with a normalised instance of `scene`.
func _swap_scene_model(visual: Node3D, scene: PackedScene) -> void:
	for child in visual.get_children():
		child.queue_free()
		visual.remove_child(child)
	var holder := Node3D.new()
	visual.add_child(holder)
	var model := scene.instantiate()
	holder.add_child(model)

	var bounds := _merged_bounds(holder)
	if bounds.size.z <= 0.0001:
		return
	# `Visual` already carries Art_Direction §2's 1.6 drama scale, so the target
	# here is expressed in the mesh's own space and that multiply still applies.
	var factor: float = (MODEL_LENGTH / 1.6) / bounds.size.z
	holder.scale = Vector3.ONE * factor
	# Re-centre on the bounding box, in the PARENT's space (hence the factor).
	holder.position = -bounds.get_center() * factor

## Union of every visual's bounds under `root`, in `root`'s own space.
func _merged_bounds(root: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for node in root.find_children("*", "VisualInstance3D", true, false):
		var visual_node := node as VisualInstance3D
		var box: AABB = visual_node.get_aabb()
		var relative: Transform3D = root.global_transform.affine_inverse() \
			* visual_node.global_transform
		box = relative * box
		if first:
			bounds = box
			first = false
		else:
			bounds = bounds.merge(box)
	return bounds

## ⚠️⚠️ THE FLOOR GLOW THAT SAYS WHICH SLIPPER IS YOURS. 🧑 2026-08-01: *"Your
## personal slipper glows with an outline on the arena floor."* It pairs with the foot
## arrow (§1.6): the arrow points across the map, the glow confirms it once you are
## close enough to see the thing itself.
##
## ⚠️ IT USES `rim_strength`, A UNIFORM `toon.gdshader` HAS CARRIED SINCE 7.1 AND THAT
## EVERY PROP SHIPPED AT 0.0 — built and never switched on. A rim is a single dot
## product, it survives the flat two-band toon ramp (a specular lobe would either
## vanish into the lit band or sit on it as a white blob), and it does not touch
## `albedo_color`, so the OWNER'S CHOSEN SKIN TINT IS UNAFFECTED. That last part is the
## constraint that decided the whole approach: recolouring the slipper by owner slot
## would have overridden the tsinelas pick from the CHARACTER screen, which is exactly
## the "a control that is reachable and does nothing" failure the board's own
## REACHABILITY RULE was extended to forbid.
##
## ⚠️ AND IT IS PER-PEER, DELIBERATELY NOT REPLICATED. "Yours" is a different slipper
## on every machine, so this is computed locally each time it changes and never sent —
## a networked glow would light one slipper for everybody.
const OWNER_RIM_STRENGTH: float = 0.85
const OWNER_RIM_COLOR: Color = Color(1.0, 0.86, 0.35)

var _glow_on: bool = false

func _update_owner_glow() -> void:
	# Only a LOOSE slipper is worth pointing at. Carried, it is already in your hand;
	# in flight, it is the thing everybody is watching anyway.
	var mine := state == CarryState.LOOSE and owner_slot >= 0 		and owner_slot == _local_owner_slot()
	if mine == _glow_on:
		return
	_glow_on = mine
	_set_rim(OWNER_RIM_STRENGTH if mine else 0.0)

## The seat this machine is playing, or -1 for a spectator or a peer with no character.
func _local_owner_slot() -> int:
	var main := get_tree().current_scene
	if main == null or not main.has_method("get_local_character"):
		return -1
	var who := main.get_local_character() as CharacterBase
	return who.player_slot if who != null and is_instance_valid(who) else -1

func _set_rim(strength: float) -> void:
	var visual := get_node_or_null("Visual")
	if visual == null:
		return
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in range(mesh.get_surface_override_material_count()):
			# ⚠️ THE OVERRIDE, NOT `get_active_material()`. The outline pass is chained
			# as `next_pass` and carries none of these uniforms — writing the rim
			# through the active material would land on whichever of the two answered.
			var material := mesh.get_surface_override_material(surface)
			if material is ShaderMaterial:
				var shader_mat := material as ShaderMaterial
				shader_mat.set_shader_parameter("rim_strength", strength)
				shader_mat.set_shader_parameter("rim_color", OWNER_RIM_COLOR)

func _tint_meshes(tint: Color) -> void:
	var visual := get_node_or_null("Visual")
	if visual == null:
		return
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in range(mesh.get_surface_override_material_count()):
			var material := mesh.get_active_material(surface)
			if material == null:
				continue
			var copy := material.duplicate()
			if copy is StandardMaterial3D:
				(copy as StandardMaterial3D).albedo_color = tint
			elif copy is ShaderMaterial:
				# The toon pass reads `albedo_color` as the actual colour, so a
				# tinted prop still flashes correctly and returns to its tint.
				(copy as ShaderMaterial).set_shader_parameter("albedo_color", tint)
			mesh.set_surface_override_material(surface, copy)
