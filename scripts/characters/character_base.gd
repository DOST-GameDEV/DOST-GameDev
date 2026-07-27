extends CharacterBody3D
class_name CharacterBase

## Shared controller for every unit — both the human Person and the Can/Slipper
## Prop (see `is_person`/`is_can` below). A team is 2 players: 1 Person + 1 Prop,
## not two Props. Each of the 6 roster Props = this scene + a different
## AbilityBase resource plugged into `ability`; every Person shares one
## Tag/Throw ability (see person_action.gd).
## Stock/Downed round-win logic is NOT here on purpose (see Section 3 of the GDD) —
## it lives in its own decoupled system so Option A vs Option B can be swapped freely.

const SPEED: float = 6.0
## B-12: deceleration when there's no movement input, in units/sec² — separate
## from SPEED because the old code reused SPEED itself as a per-tick
## move_toward() step with no `delta`, which was an effectively-instant stop
## every physics tick regardless of framerate (no momentum), and made a
## velocity boost like Flick Dash's decay away in about 3 frames instead of
## actually covering distance.
const FRICTION: float = 30.0
const GRAVITY: float = 20.0
const BUMP_STAGGER_TIME: float = 0.25
## GDD Section 3, Option B: ~2s window to self-right before a Tsinelas can seal a
## Downed Can. Kept here (not in RoundManager) because it's shared by both Option A
## and Option B, and by abilities like Quick Stand / Shatter Trap that reference
## "Downed" directly — see docs/Tumbang_Preso_2v2_GDD.md Section 4.
const DOWNED_SELF_RIGHT_WINDOW: float = 2.0
## Bump is "no cooldown" per the GDD but still needs an active window so standing
## next to an opponent doesn't stagger them every physics tick — press-to-bump,
## briefly live, matches "light melee" better than always-on contact damage.
const BUMP_ACTIVE_TIME: float = 0.15
## Option A (GDD Section 3, "Stock/Life"): a Can's health bar. Slippers win the
## round once a tracked Can reaches this many dents — see RoundManager
## _on_tracked_can_dents_changed. Only ever meaningful for a Can (is_can true);
## Persons and Slippers never accumulate dents. 3 per user decision (Session 7).
const MAX_DENTS: int = 3

## B-16: GDD Section 4 shared basic — "Guard/Dash (Cans block, Tsinelas
## dash-evade)" — for Props only; Persons don't get this (their assist/support
## slot is Tag/Throw, see person_action.gd). Which half a Prop gets depends on
## `is_can` this round, same as every other Can/Tsinelas-side split.
## Guard: hold to block. A stamina meter (not an unlimited hold) so it can't be
## held forever — drains while held, regenerates while released.
const GUARD_MAX_STAMINA: float = 3.0
const GUARD_DRAIN_RATE: float = 1.0
const GUARD_REGEN_RATE: float = 0.6
## Dash: a quick evasive burst in the current facing direction, on a short
## cooldown rather than a stamina meter — it's one instant action, not a hold.
const DASH_SPEED: float = 14.0
const DASH_DURATION: float = 0.15
const DASH_COOLDOWN: float = 2.5

## NORMAL — moving/acting freely.
## STAGGERED — brief no-control flinch from a bump (BUMP_STAGGER_TIME), auto-recovers.
## DOWNED — knocked down; can self-right (bump input) within DOWNED_SELF_RIGHT_WINDOW;
##          after the window expires it becomes sealable by an opponent Hitbox.
## SEALED — round-relevant "out" state for this character. What SEALED actually does to
##          round outcome is intentionally NOT decided here — RoundManager/MatchManager
##          own that, this just reports the state change via `state_changed`.
enum State { NORMAL, STAGGERED, DOWNED, SEALED }

@export var ability: AbilityBase
## true = this is the team's Can/Slipper Prop this round (defense = Can, offense =
## Slipper); false = this is the team's Person. See `is_person` below — a team is
## 1 Person + 1 Prop, NOT two Props. `is_can` only ever describes the Prop; a
## Person's `is_can` is always false regardless of which side its team is on this
## round (see main.gd `_spawn_player` / `_on_match_round_started`).
@export var is_can: bool = true
## true = this unit is the team's human Person (tags opponents on defense, throws
## the Slipper at the Can on offense — GDD Section 3/4). false = this unit is the
## team's Can/Slipper Prop, which carries the roster's class abilities (Quick
## Stand, Bakya Bash, etc.) via `ability`. Fixed for the whole match — unlike
## Can/Slipper (which flips with the team's Attacker/Defender role each round),
## a player stays Person or stays Prop all match. See main.gd for assignment.
@export var is_person: bool = false
## Session 8 (throw/tag mechanic): mirrors the Prop's `is_can` for a Person, who
## doesn't have an `is_can` of its own (a Person's `is_can` is always false — see
## above) but still needs to know which side its team is on this round to pick
## Tag (defense) vs Throw (offense) — see person_action.gd. true = team is on the
## Can/defense side, false = team is on the Slipper/offense side. Meaningless for
## a Prop (which already has `is_can` for this). Kept in sync by main.gd, same
## lifetime/pattern as `is_can` — see _spawn_player / _on_match_round_started.
@export var team_is_can_side: bool = true
## B-09: which team (0 = Team A, 1 = Team B) this character belongs to.
## Previously there was no team identity on CharacterBase at all — only
## main.gd's own `_peer_teams` dict knew it — so Hitbox had no way to skip a
## same-team hit, letting a defending Person dent/seal its own team's Can.
## Fixed for the whole match, same lifetime as `is_person`. Set by main.gd at
## spawn (both the networked flow and the local-test flow).
@export var team: int = 0
## Which local input set this character reads from (1-4). Lets multiple
## characters share one keyboard without both moving on the same WASD press —
## see project.godot [input]: every action is suffixed "_p1".."_p4". p1/p2 are
## bound to real keys (WASD+Space / Arrows+Enter); p3/p4 are registered but
## deliberately left unbound (see project.godot [input]) — they exist so the
## local single-PC test flow can spawn the real 4-unit Person+Prop structure
## without needing 4 human players, and a character with an unbound player_id
## simply never receives input, standing in as a local-test dummy. See
## main.gd's local _ready() branch for how p3/p4 are assigned.
@export_range(1, 4, 1) var player_id: int = 1

signal state_changed(new_state: State)
## Option A only (see MAX_DENTS above). Fires whenever `dents` changes so
## RoundManager can watch for a tracked Can reaching MAX_DENTS without polling.
signal dents_changed(new_dents: int)
## Q-6: fires whenever a Guard blocks an incoming stagger/dent — the mechanic
## had no feedback of any kind, on the player being hit OR the one landing a
## now-nullified hit. CharacterVisual answers with a distinct (DEFENSE-tinted,
## never IMPACT-tinted) flash — see _flash_blocked below.
signal hit_blocked

## B-15/B-35: where this character respawns after falling into the KillPlane
## (scripts/systems/kill_plane.gd). Captured from wherever this character
## actually was when it first entered the tree (correct as-is for the local
## test flow's hand-placed transforms); main.gd updates it explicitly whenever
## it assigns a fresh position afterward (networked spawn, round reset), so a
## fall during round 2 respawns to round 2's spawn point, not round 1's stale
## one — see _build_networked_character / _on_match_round_started.
## (Two independent PRs added this same field for the same bug; merging them
## left it declared twice, which is a GDScript parse error — this is the
## surviving single declaration.)
var spawn_position: Vector3 = Vector3.ZERO
var state: State = State.NORMAL
## Option A only. Always 0 for Persons and Slippers — only a Can (is_can true)
## ever takes dents. Synced like `state` (see CharacterBase.tscn) so RoundManager
## can watch it identically on every peer; only the host's report actually counts
## (same pattern as _on_tracked_can_state_changed).
var dents: int = 0
var _staggered_time_left: float = 0.0
var _downed_time_left: float = 0.0
var _downed_self_rightable: bool = false ## true only within the self-right window
var _bump_active_time_left: float = 0.0
var _speed_multiplier: float = 1.0 ## set by hazard zones (mud, Shatter Trap patch, etc.)
## B-16: Guard/Dash state — see the constants above for the doc on each.
var _guard_stamina: float = GUARD_MAX_STAMINA
var _is_guarding: bool = false
var _dash_cooldown_left: float = 0.0
var _dash_active_time_left: float = 0.0
## The character's own always-present melee Hitbox (requires_bump_window = true)
## — cached so opening the bump window can sweep already-overlapping targets
## (see _open_bump_window, B-08) without a scene-tree lookup every press.
var _melee_hitbox: Hitbox = null
## Everything about how this unit LOOKS lives on the `Visual` node's own script
## (see character_visual.gd) — including the B-44 hit flash, which used to be a
## hardcoded `get_node_or_null("Visual/MeshInstance3D")` here. That path broke
## silently once already (commit 6f97e76) when the mesh moved under the `Visual`
## wrapper: a wrong node path returns null with no error, so the flash simply
## stopped firing and nothing said so. This script no longer knows or cares what
## the mesh tree looks like.
@onready var _visual: CharacterVisual = $Visual
## B-60: this unit's own rig, consulted for who owns yaw this frame. Queried
## live rather than cached as a bool because `aim_source` changes at runtime —
## the debug switcher hands the mouse between units mid-match.
@onready var _camera_rig: CameraRig = get_node_or_null("CameraRig")
## Task 0 — this unit's own carry state, when it is a throwable tsinelas. Present
## on every character; reports is_throwable() false and stays LOOSE on a Person
## or a Can. See carriable.gd.
@onready var _carriable: Carriable = get_node_or_null("Carriable")
## Task 0/1 — this unit's hands, when it is a Person. See carrier.gd.
@onready var _carrier: Carrier = get_node_or_null("Carrier")

## True when the local player is aiming this unit with the mouse, i.e. the rig
## is writing `rotation.y` and this script must not fight it.
func _is_mouse_aimed() -> bool:
	return _camera_rig != null and _camera_rig.aim_source == CameraRig.AimSource.MOUSE

func _ready() -> void:
	spawn_position = global_position
	for child in find_children("*", "Hurtbox", true, false):
		(child as Hurtbox).owner_character = self
	for child in find_children("*", "Hitbox", true, false):
		var hitbox := child as Hitbox
		hitbox.owner_character = self
		if hitbox.requires_bump_window:
			_melee_hitbox = hitbox
	# Person / Can / Tsinelas each get their own model. Reapplied every round in
	# reset_for_new_round(), because `is_can` flips with the role swap.
	_visual.apply(is_person, is_can, team)

func _physics_process(delta: float) -> void:
	# Session 6: the bump-active window has to decay on every peer, not just
	# the owning one — the host needs its own copy of this timer to resolve
	# hits authoritatively (see hitbox.gd), and it never runs the input half
	# of this function for a character it doesn't own. Cheap and harmless for
	# the non-networked local flow too.
	if _bump_active_time_left > 0.0:
		_bump_active_time_left -= delta
	if _dash_active_time_left > 0.0:
		_dash_active_time_left -= delta

	# Task 0: a tsinelas that is in someone's hand or in the air is not walking
	# anywhere under its own power — the carry component owns its transform for
	# the duration. Deliberately placed BEFORE the authority gate below so every
	# peer runs it: both branches are deterministic from state the host has
	# already broadcast (who is carrying / the launch origin and velocity), so
	# computing them locally is cheaper and smoother than streaming a transform,
	# and a carried slipper costs literally no bandwidth.
	if _carriable != null and _carriable.drives_movement():
		_carriable.physics_step(delta)
		return

	# Rough networking pass (Session 5): once a network peer exists, only the
	# owning peer simulates movement/input for its own character — everyone
	## else's copy is driven purely by MultiplayerSynchronizer (see
	## CharacterBase.tscn). Local single-PC/split-keyboard testing is
	# unaffected since NetworkManager.is_networked() is false there.
	if NetworkManager.is_networked() and not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Item 10 / B-37: freeze input during the round intermission (the gap
	# between a round ending and the next one's timer starting — see
	# MatchManager.round_intermission_started / main.gd::_reset_world) and
	# before the very first round begins. round_active is already false in
	# both cases; still apply gravity/friction above/below so nobody floats
	# or skids, just can't act.
	if not RoundManager.round_active:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)
		move_and_slide()
		return

	if ability:
		ability.tick(delta)

	# Task 0/1: grab and charge-throw. Runs before the rest of the input block so
	# a throw released this frame is not also read as an ability press below.
	if _carrier != null and state == State.NORMAL:
		_carrier.input_step(delta)

	if state == State.NORMAL and Input.is_action_just_pressed(_action("bump")):
		_open_bump_window()
		# Cosmetic only. CharacterVisual decides what a bump LOOKS like and picks
		# a clip the model actually has; this file just says what happened.
		_visual.play_action("bump")
		# Tell the host our bump window just opened, since the host is the one
		# resolving Hitbox/Hurtbox overlaps now (see hitbox.gd) and it can't
		# see this peer's local-only timer any other way. No-op if we ARE the
		# host, or if we're not networked at all.
		if NetworkManager.is_networked() and not NetworkManager.is_host():
			_rpc_notify_bump.rpc_id(1)

	if state == State.NORMAL:
		_process_guard_dash(delta)

	match state:
		State.STAGGERED:
			_staggered_time_left -= delta
			if _staggered_time_left <= 0.0:
				_set_state(State.NORMAL)
		State.DOWNED:
			if _downed_self_rightable:
				_downed_time_left -= delta
				if _downed_time_left <= 0.0:
					_downed_self_rightable = false # window expired, now sealable
			if Input.is_action_just_pressed(_action("bump")) and _downed_self_rightable:
				self_right()
			# B-06: special_ability is normally only read further down, past the
			# STAGGERED/DOWNED/SEALED early return below — unreachable for an
			# "escape" ability like Quick Stand, whose only effect is self-
			# righting from exactly this state. is_ready()/once_per_round on the
			# ability itself already gates whether it actually does anything.
			if Input.is_action_just_pressed(_action("special_ability")) and ability:
				ability.activate(self)
				if NetworkManager.is_networked() and not NetworkManager.is_host():
					_rpc_notify_ability_activate.rpc_id(1)
		State.SEALED:
			pass # awaiting round reset / respawn logic

	if state in [State.STAGGERED, State.DOWNED, State.SEALED]:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)
		move_and_slide()
		return

	if _dash_active_time_left > 0.0:
		# B-16: a Tsinelas-side Dash burst (see _process_dash) is a brief
		# committed action, not just a velocity nudge — without this guard,
		# holding a movement key during the dash would overwrite the burst
		# with normal walk speed on the very same physics frame it fired.
		move_and_slide()
		return

	var input_dir := Input.get_vector(_action("move_left"), _action("move_right"), _action("move_up"), _action("move_down"))
	# B-60: which frame WASD is read in depends on who owns this unit's yaw.
	#
	# Mouse-aimed (the unit you are personally driving): the CameraRig owns yaw
	# and writes `rotation.y` from mouse motion, so input is read in the BODY's
	# frame — W is "where I am looking". Reading it in world space instead, and
	# then calling look_at() below to face the movement vector, snapped the body
	# to the WASD direction on every keypress; since the rig is a CHILD of the
	# body, that dragged the camera round with it. Measured: aim 90 deg left,
	# then hold D, and the camera flipped a full 180.
	#
	# Everything else (remote peers, local-test dummies — aim_source MOVEMENT)
	# keeps the original world-space scheme with look_at(), which is right for a
	# unit nobody is aiming with a mouse.
	#
	# B-05's original note said world-space was deliberate, "NOT
	# `transform.basis * input_dir`". That was correct when the only camera was
	# the fixed-angle ArenaCamera (removed A-2, v4.8); it stopped being correct the moment the
	# per-character FPP/TPP rigs (item 13) made the camera turn with the player.
	var mouse_aimed := _is_mouse_aimed()
	var direction: Vector3
	if mouse_aimed:
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y))
		direction.y = 0.0
		direction = direction.normalized()
	else:
		direction = Vector3(input_dir.x, 0, input_dir.y).normalized()

	# Task 0: a LOOSE tsinelas crawls rather than walks (CRAWL_SPEED_SCALE) — the
	# retrieval scramble is only tense if getting home under your own power is
	# genuinely slow. 1.0 for every other unit and every other carry state.
	var carry_scale: float = _carriable.movement_speed_scale() if _carriable != null else 1.0
	if direction:
		velocity.x = direction.x * SPEED * _speed_multiplier * carry_scale
		velocity.z = direction.z * SPEED * _speed_multiplier * carry_scale
		# Face the direction we're moving — nothing wrote `rotation` before this,
		# so every directional attack (melee Hitbox offset, PersonAction,
		# BakyaBash, FlickDash, all built on `-transform.basis.z`/local offsets)
		# fired toward world -Z regardless of which way the player was moving.
		# Skipped when mouse-aimed: the rig already wrote yaw this frame, and
		# overwriting it here is exactly the bug above. Attacks still fire where
		# you are looking, which is what B-05 actually wanted.
		if not mouse_aimed:
			look_at(global_position + direction, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)

	# Task 0: `and not _carrier_is_holding()` — with a slipper in hand this button
	# is the charge-throw (carrier.gd owns it, above) and must not ALSO fire the
	# ordinary ability. person_action.gd is now Tag-only for exactly this reason.
	if Input.is_action_just_pressed(_action("special_ability")) and ability and not _carrier_is_holding():
		# B-12: this used to run AFTER move_and_slide(), so an ability that sets
		# velocity directly (Flick Dash's dash burst) applied a full physics
		# frame late. Moved above move_and_slide() so a velocity change this
		# tick actually takes effect this tick.
		#
		# Same pattern as the bump RPC above: activate locally (so a client sees
		# its own cosmetic hitbox/movement effect immediately, e.g. Flick Dash's
		# velocity kick), and — since hitbox resolution only ever runs on the
		# host (see hitbox.gd) — also tell the host to activate ITS OWN copy of
		# this character so the actual resolving hitbox exists where it can be
		# resolved (B-02: previously the activating peer's hitbox never reached
		# the host at all, so every special/Tag/Throw was a no-op for clients).
		ability.activate(self)
		# The grab/throw arm swing. Cosmetic, same contract as the bump above.
		_visual.play_action("throw")
		if NetworkManager.is_networked() and not NetworkManager.is_host():
			_rpc_notify_ability_activate.rpc_id(1)

	move_and_slide()

## Called on this character when it's hit by an opponent's Hitbox (see hitbox.gd).
func apply_stagger(duration: float = BUMP_STAGGER_TIME) -> void:
	# B-07: also skip DOWNED, not just SEALED — a hit landing on a Can that's
	# still inside its self-right window used to overwrite DOWNED with
	# STAGGERED, which auto-recovers to NORMAL, letting ANY bump (including a
	# teammate's) rescue a Downed Can for free. A hit during that window
	# should do nothing; hitbox.gd already routes a hit AFTER the window
	# expires to "seal" instead of "stagger", so this only ever blocks the
	# free-rescue case.
	if state == State.SEALED or state == State.DOWNED:
		return
	# B-16: a Can actively Guarding blocks the incoming hit outright — no
	# stagger, same as apply_dent() below no-ops the dent for the same reason.
	if _is_guarding:
		hit_blocked.emit()
		_flash_blocked()
		return
	_staggered_time_left = max(_staggered_time_left, duration)
	_set_state(State.STAGGERED)

## B-17: HazardZone used to call a single set_speed_multiplier(1.0) on exit,
## which reset speed to normal even while still standing in a second overlapping
## zone. Track every zone this character is currently inside instead, and apply
## whichever is most restrictive — normal speed only once none are left.
var _active_speed_multipliers: Array[float] = []

func enter_speed_zone(multiplier: float) -> void:
	_active_speed_multipliers.append(multiplier)
	_recompute_speed_multiplier()

## `multiplier` identifies which zone is leaving (a zone could in principle change
## multiplier mid-life, but none do today) — removes one matching entry, not all.
func exit_speed_zone(multiplier: float) -> void:
	var idx := _active_speed_multipliers.find(multiplier)
	if idx != -1:
		_active_speed_multipliers.remove_at(idx)
	_recompute_speed_multiplier()

func _recompute_speed_multiplier() -> void:
	var lowest := 1.0
	for m in _active_speed_multipliers:
		lowest = min(lowest, m)
	_speed_multiplier = lowest

## Knocks this character into the Downed state (out-of-base hit, or a heavy special
## like Bakya Bash's instant-down). Starts the self-right window.
func go_downed() -> void:
	if state == State.SEALED:
		return
	_downed_time_left = DOWNED_SELF_RIGHT_WINDOW
	_downed_self_rightable = true
	_set_state(State.DOWNED)
	if ability and ability.has_method("_on_owner_downed"):
		ability._on_owner_downed(self)

## Player (or an ability, e.g. Sardinas' Quick Stand) recovers from Downed early.
func self_right() -> void:
	if state != State.DOWNED:
		return
	_downed_self_rightable = false
	_set_state(State.NORMAL)

## Option A only: a landed hit on this Can adds one dent (capped at MAX_DENTS)
## and applies a brief stagger for hit feedback — deliberately does NOT use the
## Downed/Seal state machine at all, since Option A's win condition is purely
## the dent count, tracked independently by RoundManager (see
## _on_tracked_can_dents_changed). No-op for a Person or Slipper.
func apply_dent(stagger_duration: float = BUMP_STAGGER_TIME) -> void:
	if not is_can:
		return
	# B-16: Guard blocks dents too — the whole point of a Can blocking is to
	# protect its own health bar, not just avoid the cosmetic stagger.
	if _is_guarding:
		hit_blocked.emit()
		_flash_blocked()
		return
	dents = min(dents + 1, MAX_DENTS)
	dents_changed.emit(dents)
	apply_stagger(stagger_duration)

## T-3 / B-46, Option A half: the taya's reset channel beats one dent back out of
## this Can. The exact mirror of apply_dent() above and it lives here for the same
## reason — `dents` is this file's business, and nothing outside it writes the
## field directly. No stagger, because being repaired is not being hit.
##
## Deliberately NOT a round-win concern: RoundManager watches dents_changed and
## re-evaluates on its own (_on_tracked_can_dents_changed), so dropping back below
## MAX_DENTS needs no cooperation from here. Same contract apply_dent() relies on.
func clear_dent() -> void:
	if not is_can or dents <= 0:
		return
	dents -= 1
	dents_changed.emit(dents)

## Called by an opponent's Hitbox once this character is Downed and past its
## self-right window (see hitbox.gd forces_downed / seal handling).
func seal() -> bool:
	if state != State.DOWNED or _downed_self_rightable:
		return false # still in the self-right window, can't be sealed yet
	_set_state(State.SEALED)
	return true

## Opens the press-to-bump window and immediately sweeps for anyone already
## overlapping the melee Hitbox (B-08) — area_entered alone only catches
## someone who overlaps AFTER the window opens, so walking into someone and
## then pressing bump (the natural order) used to never register a hit.
func _open_bump_window() -> void:
	_bump_active_time_left = BUMP_ACTIVE_TIME
	if _melee_hitbox:
		_melee_hitbox.sweep_overlaps()

## B-16: Guard/Dash. Props only (a Person's assist slot is Tag/Throw instead —
## see person_action.gd) — which half a Prop gets depends on `is_can` this
## round, same split as everything else that differs between Can and Tsinelas.
func _process_guard_dash(delta: float) -> void:
	if is_person:
		return
	if is_can:
		_process_guard(delta)
	else:
		_process_dash(delta)

func _process_guard(delta: float) -> void:
	var held := Input.is_action_pressed(_action("guard_dash"))
	if held and _guard_stamina > 0.0:
		_is_guarding = true
		_guard_stamina = max(0.0, _guard_stamina - GUARD_DRAIN_RATE * delta)
	else:
		_is_guarding = false
		_guard_stamina = min(GUARD_MAX_STAMINA, _guard_stamina + GUARD_REGEN_RATE * delta)

func _process_dash(delta: float) -> void:
	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left -= delta
	if _dash_active_time_left <= 0.0 and _dash_cooldown_left <= 0.0 and Input.is_action_just_pressed(_action("guard_dash")):
		var forward := -transform.basis.z
		velocity.x = forward.x * DASH_SPEED
		velocity.z = forward.z * DASH_SPEED
		_dash_active_time_left = DASH_DURATION
		_dash_cooldown_left = DASH_COOLDOWN

## Whether this character is currently blocking (B-16 Guard). Gates incoming
## stagger/dents in apply_stagger()/apply_dent() below — hitbox.gd itself stays
## generic to any hit, same as the team check (B-09).
func is_guarding() -> bool:
	return _is_guarding

## Q-6: read-only HUD accessors — the mechanic itself (B-16) was fully
## implemented with no UI at all, which is almost certainly why it was
## reported missing. Exposed rather than making _guard_stamina/_dash_cooldown_left
## public outright, so nothing outside this file can write them.
func get_guard_stamina_ratio() -> float:
	return _guard_stamina / GUARD_MAX_STAMINA

## 1.0 once the cooldown has fully elapsed (ready to dash again), 0.0 the
## instant it was just used.
func get_dash_cooldown_ratio() -> float:
	return 1.0 - clamp(_dash_cooldown_left / DASH_COOLDOWN, 0.0, 1.0)

## Q-6: distinct from _flash_hit() (B-44's white "landed" flash) — DEFENSE-
## tinted, so a blocked hit never reads as a landed one.
func _flash_blocked() -> void:
	_visual.flash_blocked()

## Whether this character's press-to-bump window is currently live. The melee
## Hitbox (requires_bump_window = true) checks this before landing a stagger;
## ability-spawned hitboxes (requires_bump_window = false) ignore it.
func is_hitbox_active() -> bool:
	return _bump_active_time_left > 0.0

## Whether this character is still inside its Downed self-right window (i.e.
## NOT yet sealable). Hitbox needs this from the outside to decide seal vs.
## downed/stagger without reaching into the private var directly.
func is_self_rightable() -> bool:
	return _downed_self_rightable

## Client → host RPC (see _physics_process): lets the host keep its own copy
## of _bump_active_time_left in sync with a remote peer's bump press, since
## the host never runs this character's input logic itself.
@rpc("any_peer", "call_local", "reliable")
func _rpc_notify_bump() -> void:
	if NetworkManager.is_networked() and NetworkManager.is_host():
		_open_bump_window()

## Client → host RPC (B-02): a non-host activator's own copy of `ability` already
## ran _do_activate() locally (see the special_ability check above) for its
## cosmetic effect, but its spawned hitbox only exists in that peer's own scene
## tree, where hitbox.gd refuses to resolve anything (host-only). This tells
## the host to run activate() on ITS OWN copy of this character/ability
## instead, so the authoritative resolving hitbox actually exists on the host.
@rpc("any_peer", "call_local", "reliable")
func _rpc_notify_ability_activate() -> void:
	if NetworkManager.is_networked() and NetworkManager.is_host() and ability:
		ability.activate(self)

## Host → target-owner RPC: the host is the only peer that decides hit
## outcomes now (see hitbox.gd), but state authority for THIS character still
## lives with its own owning peer (MultiplayerSynchronizer replicates `state`
## from the authority outward). So the host tells the owning peer what
## happened, that peer applies it locally exactly like the old local-only
## flow, and the existing synchronizer replicates the resulting state to
## everyone else — no change needed there.
##
## B-66: this used to also call _flash_hit() here, but rpc_id() only ever
## targets the STRUCK character's own owning peer — every other peer watching
## the hit land saw no feedback at all. State resolution stays exactly here,
## on the authority; the cosmetic half moved to _rpc_play_hit_vfx below,
## broadcast to everyone.
@rpc("any_peer", "call_local", "reliable")
func _apply_hit_result(kind: String, duration: float) -> void:
	match kind:
		"stagger":
			apply_stagger(duration)
		"downed":
			go_downed()
		"seal":
			seal()
		"dent":
			apply_dent(duration)

## B-66: the cosmetic half of a landed hit, broadcast to every peer (unlike
## _apply_hit_result above, which only ever reaches the struck character's own
## owning peer) — see hitbox.gd for the call site. Deliberately separate from
## state resolution: gameplay outcome must stay exactly where it already was,
## on the authority.
##
## "any_peer", not "authority" — confirmed live: hit resolution always runs
## on the HOST (hitbox.gd), but a struck character's multiplayer authority is
## its OWNING peer, which for any non-host player's own unit is NOT the host.
## An "authority"-mode RPC is only accepted when sent BY that node's own
## authority, so the host calling it on a client's character was silently
## rejected — logged as "RPC '_rpc_play_hit_vfx' is not allowed ... Mode is
## authority" on the receiving client, meaning the VFX never played for any
## hit landing on a non-host player. Same reasoning _apply_hit_result already
## uses "any_peer" for, just missed here initially.
@rpc("any_peer", "call_local", "reliable")
func _rpc_play_hit_vfx() -> void:
	_flash_hit()

## B-44/Q-8: brief white flash + impact particles on a landed hit, any kind,
## on every peer (see _rpc_play_hit_vfx). Camera shake is additionally gated
## to only the struck player's own screen — a shake when a stranger across
## the map gets bumped is noise, not feedback.
func _flash_hit() -> void:
	_visual.flash_hit()
	var is_mine := is_multiplayer_authority() if NetworkManager.is_networked() else player_id == 1
	if is_mine:
		var rig := get_node_or_null("CameraRig") as CameraRig
		if rig:
			rig.shake()

## Maps a base action name (e.g. "move_left") to this character's own input
## action (e.g. "move_left_p1" / "move_left_p2"), per `player_id`.
func _action(base_name: String) -> String:
	return "%s_p%d" % [base_name, player_id]

## Public form of _action(), for the Task 0 carry components (carriable.gd,
## carrier.gd) which read this character's input set from outside this file.
## Deliberately an alias rather than a rename: `_action` has ten call sites in
## here and the string `_action(` is a substring of `play_action(`, so a blanket
## rename is a silent-corruption risk for no benefit.
func action_name(base_name: String) -> String:
	return _action(base_name)

## Task 1 — where a carried tsinelas rides on this character. Forwarded straight
## to CharacterVisual, which is the only thing that knows this model has a
## skeleton, let alone where its arm bone is. Returns null for a unit with no
## hands or whose model has not been instanced yet; callers treat that as "not
## ready", not as an error.
func get_hand_attachment() -> Node3D:
	return _visual.get_hand_attachment()

## Task 1 — lets the carry components ask for an animation without reaching into
## `_visual` themselves. Same contract the bump/throw calls already use: this
## file says WHAT happened, CharacterVisual decides what it looks like and picks
## a clip the model actually has.
func play_visual_action(kind: String) -> void:
	_visual.play_action(kind)

## Task 0 — true while this unit is a Person with something in its hands, in
## which case `special_ability` is the charge-throw and must NOT also fire the
## ordinary ability (Tag). One button, and holding a slipper is what decides
## which half of it you get.
func _carrier_is_holding() -> bool:
	return _carrier != null and _carrier.held() != null

func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	state_changed.emit(state)

## Called by KillPlane (B-15/B-35) when this character falls off the arena.
## Stun-only, no elimination — same "straight back in the fight" rule as a
## bump — so this returns to spawn_position rather than sitting anyone out.
func respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO

## Called by RoundManager at the start of a new round to clear Downed/Sealed/Staggered
## carryover from the previous round. Does NOT touch position — whatever resets a
## character to its base spot (map-specific) is a separate concern.
func reset_for_new_round() -> void:
	_staggered_time_left = 0.0
	_downed_time_left = 0.0
	_downed_self_rightable = false
	# B-17: clear any hazard zones this character was standing in too — a
	# lingering slow effect (or the reverse: a stale exit dropping speed to 1.0
	# under a still-live zone) shouldn't survive a round reset either way.
	_active_speed_multipliers.clear()
	_speed_multiplier = 1.0
	# B-16: fresh guard stamina and no leftover dash cooldown each round —
	# otherwise a Can that emptied its stamina staying alive to round end
	# would start the next round already unable to block.
	_guard_stamina = GUARD_MAX_STAMINA
	_is_guarding = false
	_dash_cooldown_left = 0.0
	_dash_active_time_left = 0.0
	state = State.NORMAL
	state_changed.emit(state)
	dents = 0
	dents_changed.emit(dents)
	if ability:
		ability.reset_round_charge()
	# Task 0: a slipper still in someone's hand, or still in the air, when the
	# round ends goes back to LOOSE — otherwise round 2 starts with a tsinelas
	# welded to a Person who is no longer even on the attacking side. Runs on
	# every peer without an RPC, same as the team/role recompute in
	# main.gd::_reset_world, because every peer already has the state to do it.
	if _carriable != null:
		_carriable.reset_for_new_round()
	# Roles swap between rounds, so a Prop that was the Can is the Tsinelas now
	# (and vice versa) and needs the other model. No-op when nothing changed.
	_visual.apply(is_person, is_can, team)
