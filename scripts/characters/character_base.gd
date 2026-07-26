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

func _ready() -> void:
	for child in find_children("*", "Hurtbox", true, false):
		(child as Hurtbox).owner_character = self
	for child in find_children("*", "Hitbox", true, false):
		var hitbox := child as Hitbox
		hitbox.owner_character = self
		if hitbox.requires_bump_window:
			_melee_hitbox = hitbox

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

	# Rough networking pass (Session 5): once a network peer exists, only the
	# owning peer simulates movement/input for its own character — everyone
	## else's copy is driven purely by MultiplayerSynchronizer (see
	## CharacterBase.tscn). Local single-PC/split-keyboard testing is
	# unaffected since NetworkManager.is_networked() is false there.
	if NetworkManager.is_networked() and not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if ability:
		ability.tick(delta)

	if state == State.NORMAL and Input.is_action_just_pressed(_action("bump")):
		_open_bump_window()
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
	# B-05: world-space directly, NOT `transform.basis * input_dir` — this used
	# to make movement direction depend on the character's own current facing,
	# which would create a car-like relative-turning control scheme the moment
	# facing started rotating (see look_at below) instead of the absolute WASD
	# directions the camera's fixed pitch implies.
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()

	if direction:
		velocity.x = direction.x * SPEED * _speed_multiplier
		velocity.z = direction.z * SPEED * _speed_multiplier
		# Face the direction we're moving — nothing wrote `rotation` before this,
		# so every directional attack (melee Hitbox offset, PersonAction,
		# BakyaBash, FlickDash, all built on `-transform.basis.z`/local offsets)
		# fired toward world -Z regardless of which way the player was moving.
		look_at(global_position + direction, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)

	if Input.is_action_just_pressed(_action("special_ability")) and ability:
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
		return
	_staggered_time_left = max(_staggered_time_left, duration)
	_set_state(State.STAGGERED)

## Called by a HazardZone (mud patch, Shatter Trap, wet floor, etc.) when this
## character enters/exits it. 1.0 = normal speed.
func set_speed_multiplier(multiplier: float) -> void:
	_speed_multiplier = multiplier

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
		return
	dents = min(dents + 1, MAX_DENTS)
	dents_changed.emit(dents)
	apply_stagger(stagger_duration)

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

## Maps a base action name (e.g. "move_left") to this character's own input
## action (e.g. "move_left_p1" / "move_left_p2"), per `player_id`.
func _action(base_name: String) -> String:
	return "%s_p%d" % [base_name, player_id]

func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	state_changed.emit(state)

## Called by RoundManager at the start of a new round to clear Downed/Sealed/Staggered
## carryover from the previous round. Does NOT touch position — whatever resets a
## character to its base spot (map-specific) is a separate concern.
func reset_for_new_round() -> void:
	_staggered_time_left = 0.0
	_downed_time_left = 0.0
	_downed_self_rightable = false
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
