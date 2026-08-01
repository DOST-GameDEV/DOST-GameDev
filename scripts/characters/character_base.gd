extends CharacterBody3D
class_name CharacterBase
## One human player. **Every unit in the match is one of these and there are
## exactly four.** Rewritten 2026-07-31 on branch `HARRYDAKS`.

## ---------------------------------------------------------------------------
## ⚠️⚠️ WHAT THIS FILE STOPPED BEING. It used to be the base class for FOUR kinds
## of thing — a Person, a lata, a tsinelas, and whatever a roster ability made of
## them — carrying every verb any of them had: a charged bump meter with a punt, a
## Can-Dash, a Ground Smash, a self-launch, a guard, a seal, a scuff, a dent
## counter and an `AbilityBase` slot. 🧑 2026-07-31: *"drop the irrelevant
## mechanics now like bump and shit and slipper being a character and can being a
## character"*.
##
## The lata is now `scripts/objects/lata.gd` and the tsinelas is
## `scripts/objects/slipper.gd`, both props. This file is one role — a person who
## runs, sprints, throws, retrieves, shoves and tags — and `is_defender` is the
## only thing that varies between the four of them.
##
## ⚠️ WHAT WAS KEPT, AND WHY EACH ONE IS NOT DEAD WEIGHT:
##   · `SPAWN_SETTLE_FRAMES` — a real, expensively-diagnosed physics fix (B-100).
##     Roles rotate every round, so players trade marks, and for one physics frame
##     each stands on the other's stale collider. Still true with four of them.
##   · `_shed_character_perch()` — you cannot stand on somebody's head. Also real,
##     also from live play, and MORE likely now that three attackers converge on
##     one box.
##   · The AI intent block and `input_*` indirection — the AI presses the same
##     buttons a human does, which is the only reason a single `_physics_process`
##     serves both. 🧑 deferred the AI rewrite to the last lane; this keeps the
##     harness it will need.
##   · The confinement clamp — see `CONFINEMENT_RADIUS`. It IS the Defender's Box.
## ---------------------------------------------------------------------------

## Base walk speed, metres/second. **The taya's speed** — see `ATTACKER_SPEED_SCALE`.
const SPEED: float = 4.6
## ⚠️⚠️ THE ATTACKER IS PERMANENTLY SLOWER THAN THE TAYA, AND THAT ASYMMETRY IS THE
## POINT. 🧑 2026-08-01: *"Attacker Speed: 75% Base Speed (Permanently 25% slower than
## the Defender to give the Defender a reliable closing advantage during chases)."*
##
## Before this the two moved identically, which made the tag a coin-flip on reaction
## time: a taya who read the retrieval perfectly still could not close, because the
## attacker they were chasing was exactly as fast and had a head start by
## construction. One taya against three attackers needs a structural edge somewhere,
## and speed is the one the player can actually feel.
##
## ⚠️ IT IS A ROLE SCALE, NOT A UNIT STAT — read through `_role_speed_scale()` off
## `is_defender`, which rotates every round. Baking it into a character would make
## the seat rotation change how fast you are for reasons unrelated to your role.
const ATTACKER_SPEED_SCALE: float = 0.75
const FRICTION: float = 30.0
const GRAVITY: float = 20.0
const MAX_FALL_SPEED: float = 26.0
const JUMP_VELOCITY: float = 5.8
const LAND_SFX_MIN_SPEED: float = 2.0

## ---------------------------------------------------------------------------
## STAMINA. `Design.md` §Shared — and the units changed with this rewrite.
##
## ⚠️ THIS BAR IS NOW IN POINTS, NOT SECONDS. It used to be `STAMINA_MAX = 4.0`
## meaning "four seconds of sprint", drained at 1.0/s. The GDD specifies a
## 100-point bar draining at 20/s, which is the same idea at 25× the resolution —
## but the numbers are NOT a straight rescale of the old ones and must not be read
## as one: 100/20 is **5.0 s** of sprint, not 4.0, and regen is 20/s against the
## old 0.7/s-equivalent of 17.5/s. The HUD reads `get_stamina_ratio()` and is
## unaffected either way.
## ---------------------------------------------------------------------------
## ⚠️⚠️ REVISED 2026-08-01 ON HUMAN INSTRUCTION — A 50-POINT POOL DRAINING AT 40/s.
## 🧑: *"Max Stamina Pool: 50 Points. Sprint Drain: Consumes 10 Stamina Points every
## 0.25 seconds (40 Stamina/second)."* That is **1.25 s of sprint**, down from 5.0 s.
##
## ⚠️ THE DRAIN IS EXPRESSED PER SECOND, NOT AS A 0.25 s TICK, and the two are the
## same rule. A quarter-second tick would make sprint free for the first 249 ms and
## then cost 10 in one frame — a player tapping Shift on a 0.2 s rhythm would sprint
## for nothing, which is exactly the feathering `STAMINA_SPRINT_FLOOR` exists to
## stop. 40/s continuous spends the identical 10 points per 0.25 s held.
const STAMINA_MAX: float = 50.0
const STAMINA_DRAIN_RATE: float = 40.0
const STAMINA_REGEN_RATE: float = 20.0
const STAMINA_REGEN_DELAY: float = 2.5
## Sprint is +50% speed.
const SPRINT_SCALE: float = 1.50
## You cannot *start* a sprint below this, so the bar cannot be feathered a frame
## at a time to dodge the fatigue state. Kept from the predecessor, rescaled.
## ⚠️ RESCALED WITH THE POOL: 7.5 on a 50-point bar is the same 15% of full that
## 15.0 was on 100. Not rescaling it would have left the floor at 30% of the new bar
## and made short sprints impossible to start.
const STAMINA_SPRINT_FLOOR: float = 7.5
## Hitting zero costs this long at reduced speed with sprint locked out. This is
## the whole reason the bar is interesting: running out is a punishment, not just
## an absence.
##
## ⚠️⚠️ 2.0 s, AND IT IS NOW A REGEN LOCKOUT AS WELL AS A SPEED PENALTY. 🧑
## 2026-08-01: *"Reaching 0 Stamina triggers the Fatigued State. While fatigued,
## stamina regeneration is completely locked until a 2-second recovery delay
## expires."* Previously the bar started refilling `STAMINA_REGEN_DELAY` after the
## last sprint frame REGARDLESS of fatigue, so a fatigued player was slower but was
## already rebuilding — the penalty was cosmetic on the resource it was supposedly
## punishing. `_step_stamina()` now refuses to regen at all while `_fatigue_left`
## is running.
const FATIGUE_TIME: float = 2.0
const FATIGUE_SPEED_SCALE: float = 0.75

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE DEFENDER'S BOX. THE `const` BELOW MUST STAY, AND MUST STAY IN THAT
## EXACT SYNTAX. `tools/maps/floorcheck.py` reads the box size by regexing
## `^const CONFINEMENT_RADIUS: float = ...` out of this file, and BOTH map builders
## draw the chalk from it. Delete or reshape the const and every map build aborts.
##
## The boundary is a chalk SQUARE at |x| = |z| = this value, and `_move_and_confine()`
## clamps X and Z independently to match — a square and a circle of the same
## "radius" only agree at the four edge midpoints, and on the diagonals they
## disagree by 2.07 units, which is exactly where a Defender moves when covering a
## corner. The square is the real one; that was a human call on 2026-07-29 and it
## survives this rewrite unchanged.
##
## ⚠️ IT NOW MEANS SOMETHING SLIGHTLY DIFFERENT AND THE NUMBER HAS NOT BEEN
## RE-TUNED FOR IT. It used to confine the defending Person and the lata in a 2v2.
## It now confines ONE Defender while THREE Attackers converge on the same box.
## 5.0 is inherited, not measured against the new shape — filed to the backlog.
##
## ⚠️ CHANGING THIS AT RUNTIME MOVES THE PHYSICS BOX AND NOT THE PAINTED ONE.
const CONFINEMENT_RADIUS: float = 5.0
## The live value every gameplay read goes through, promoted so a probe can sweep
## the box size without editing this file.
static var confinement_radius: float = CONFINEMENT_RADIUS

## ---------------------------------------------------------------------------
## THE SHOVE. `Design.md` §Attacker.
##
## ⚠️⚠️ REVISED 2026-08-01: SINGLE TAP, NO CHARGE, 2.5 m, 7.5 s COOLDOWN. 🧑:
## *"Input: Single tap of E (No charge time). Cooldown: 7.5 Seconds. Effect:
## Triggers a Hand Shove Animation and blasts neighboring players in front backward
## 2.5 meters and stun them for 1.25 seconds."*
##
## `SHOVE_CHARGE_TIME` is now **0.0** rather than deleted, and that is deliberate:
## `character_visual.gd::_drive_charge_pose()` and `camera_rig.gd`'s viewmodel both
## read `observed_shove_charge()` as a 0..1 ratio, and `hud.gd` draws it. Zeroing the
## time makes the ratio jump 0 → 1 in one frame, which every one of those readers
## already handles (it is the same shape a tap-throw produces); deleting the const
## would have broken three files for a mechanic that still fires.
##
## ⚠️ THE IMPULSE IS RE-DERIVED, AND IT IS THE ONE NUMBER HERE THAT CANNOT BE COPIED.
## The old 7.75 m/s was salvaged precisely because `distance = v² / FRICTION_2` gave
## exactly 1.00 m on this friction model. The spec now asks for **2.5 m**, so the
## same solve runs again rather than the old constant being nudged:
## `v = sqrt(2.5 × 60) = 12.247`. Move `FRICTION` and this number is wrong — it is
## derived from it, not independent of it.
## ---------------------------------------------------------------------------
const SHOVE_CHARGE_TIME: float = 0.0
const SHOVE_SPEED: float = 12.247
const SHOVE_LIFT: float = 2.2
const SHOVE_STUN: float = 1.25
const SHOVE_STAMINA_COST: float = 25.0
const SHOVE_COOLDOWN: float = 7.5
## How far in front of the shover the push reaches. Two capsule radii (0.40 each)
## plus a small band — you have to actually be next to them.
const SHOVE_RANGE: float = 1.6
## Half-angle of the forward arc, degrees. A shove is aimed; it is not a pulse.
const SHOVE_ARC_DEG: float = 70.0

## ---------------------------------------------------------------------------
## THE LUNGE — the taya's tag, made an ACTIVE verb. New 2026-08-01. `Design.md` §6.
##
## 🧑: *"Input: Hold Right-Click to charge, release to fire. Charge Time: 0.5 Seconds
## to reach maximum lunge power. Execution: Triggers a Hand Lunge Animation while
## launching the Defender forward in a rapid 2.5-meter dash. Tag Trigger: Any
## vulnerable Attacker caught in the lunge path is instantly tagged."*
##
## ⚠️⚠️ THIS REPLACES A PROXIMITY TAG THAT THE PLAYER NEVER PRESSED. `RoundManager.
## _step_tag()` awarded 100 points for standing close enough, every physics frame,
## with no input and no animation — the taya was *"simply teleported"* into a score
## (the old §2.14). Making it a charged, aimed commitment does three things at once:
## it gives the tag a wind-up an attacker can read and dodge, it gives the taya
## something to be good at, and it makes the 100 points an earned event rather than
## a proximity accident.
##
## ⚠️ THE DASH DISTANCE IS DERIVED FROM `FRICTION`, exactly like `SHOVE_SPEED`:
## `v = sqrt(2.5 × 60) = 12.247`. The lunge is a velocity impulse the existing
## friction integrates down, NOT a teleport — a teleport would skip the intervening
## space, and "caught in the lunge path" requires there to be a path.
const LUNGE_CHARGE_TIME: float = 0.5
const LUNGE_SPEED: float = 12.247
## Radius around the taya, swept every frame the lunge is live, inside which a
## vulnerable attacker is tagged. Wider than `TAG_RADIUS` was, because a moving body
## sampled at 60 Hz covering 2.5 m can otherwise step clean over a narrow band
## between two frames — the classic tunnelling failure, and the reason this is a
## swept check rather than a single test at the end of the dash.
const LUNGE_TAG_RADIUS: float = 1.3
## How long the lunge stays "live" for tagging after release. Slightly longer than
## the dash itself takes to decay, so the tail of the movement still counts.
const LUNGE_ACTIVE_TIME: float = 0.45
const LUNGE_COOLDOWN: float = 1.5
## A minimum commitment, so a tapped right-click is not a free full-power tag. Below
## this the lunge still fires but travels proportionally less far.
const LUNGE_MIN_POWER: float = 0.35

const MAX_KNOCKBACK_SPEED: float = 16.0
const MAX_KNOCKBACK_LIFT: float = 7.0
## Default stagger applied by an unqualified hit.
const BASE_STAGGER_TIME: float = 0.25

const HITSTOP_DURATION: float = 0.06
const HITSTOP_TIME_SCALE: float = 0.05
static var _hitstop_active: bool = false
static var _hitstop_restore_scale: float = 1.0

## ⚠️ `SEALED` IS GONE with the seal, and so is every branch that tested for it.
## `DOWNED` survives because a shove that lands on someone mid-air still has to put
## them on the floor, and because the visual has a pose for it.
enum State { NORMAL, STAGGERED, DOWNED }

## ⚠️ KEPT AS EXPORTS ONLY SO `character_visual.gd` AND `character_nameplate.gd`
## KEEP THEIR SIGNATURES. Every unit is a Person now; nothing sets these to
## anything else. They are the last two lines of the objects-are-players thesis
## and a later lane may fold them away entirely.
@export var is_person: bool = true
@export var is_can: bool = false

## ⚠️ RENAMED FROM `team_is_can_side`, and it is the same bit doing a clearer job.
## It meant "this Person is on the defending side"; there are no sides now, so it
## means "this Person is THE Defender this round". Exactly one of the four has it
## true, `MatchManager.defender_slot` decides which, and `main.gd` writes it at
## every round start.
@export var is_defender: bool = false
## ⚠️ RENAMED FROM `team`. 0..3. There are no teams — this is the player's seat,
## the index into `MatchManager.scores`, and the rotation position that decides
## when they defend.
@export var player_slot: int = 0
@export_range(1, 4, 1) var player_id: int = 1

## ⚠️ REPLICATED, AND EMPTY IS A REAL VALUE. What this player calls themselves, from
## the Settings screen. Empty means "never set one", and every reader falls back to
## `display_name()` rather than printing a blank row — which is why nothing that
## draws a name has to know whether one exists.
@export var player_name: String = ""

## The name to actually draw. One function, so the scoreboard, the 3D nameplate, the
## YOU card and every toast cannot disagree about what an unnamed player is called.
func display_name() -> String:
	return player_name if player_name != "" else "P%d" % [player_slot + 1]

## Roster pick, for the model and the traits. -1 until a pick arrives.
var character_index: int = -1

signal state_changed(new_state: State)

## Where this player starts the round, and where a tag sends them back to. Always
## in the Safe Zone; `main.gd` owns choosing it.
var spawn_position: Vector3 = Vector3.ZERO

## ⚠️ THE SETTER IS LOAD-BEARING AND WAS ADDED TO FIX A REAL BUG. `state` is
## replicated, and a `MultiplayerSynchronizer` writes a property DIRECTLY — so
## without this, `state_changed` never fired on a peer that RECEIVED a state, and
## every listener downstream (audio, nameplate, HUD) was silently host-only.
var state: State = State.NORMAL:
	set(value):
		if value == state:
			return
		state = value
		state_changed.emit(state)

var _staggered_time_left: float = 0.0
var _downed_time_left: float = 0.0
var _speed_multiplier: float = 1.0
var _active_speed_multipliers: Array[float] = []

var _stamina: float = STAMINA_MAX
var _stamina_idle: float = 0.0
var _is_sprinting: bool = false
var _fatigue_left: float = 0.0

var _shove_charge: float = 0.0
var _shove_charging: bool = false
var _shove_cooldown_left: float = 0.0
## Mirror of another peer's shove wind-up, so the tell is visible to the person
## about to be shoved and not only to the shover. Same defect the predecessor
## found with its charge wind-up: an action animated only on the presser's own
## machine is an action with no counterplay.
var _observed_shove_charge: float = -1.0

## The lunge. `_lunge_active_left` is what makes the tag land — see `_step_lunge`.
var _lunge_charge: float = 0.0
var _lunge_charging: bool = false
var _lunge_cooldown_left: float = 0.0
var _lunge_active_left: float = 0.0
## Mirrored to every peer so the wind-up is visible to the attacker about to be
## lunged at, for the same reason `_observed_shove_charge` exists: a commitment
## nobody else can see is a commitment nobody can dodge.
var _observed_lunge_charge: float = -1.0

var _was_airborne: bool = false
var _fall_speed: float = 0.0
var _audio_prev_state: State = State.NORMAL

## The slipper in this player's hand, or null. Written only by `slipper.gd`
## through `notify_holding()`, so there is one owner of the relationship.
var _held_slipper: Slipper = null

@onready var _visual: CharacterVisual = $Visual
@onready var _camera_rig: CameraRig = get_node_or_null("CameraRig")
@onready var _carrier: Carrier = get_node_or_null("Carrier")

var ai_controller: AIController = null

## ---------------------------------------------------------------------------
## TRAITS. Kept: they are the character-select screen's whole payload, they are
## ±5–7% each, and removing them would have broken a screen that works.
## ---------------------------------------------------------------------------
const TRAIT_SPEED_PER_POINT: float = 0.05
const TRAIT_POWER_PER_POINT: float = 0.07
const TRAIT_GRIT_PER_POINT: float = 0.07

func trait_points(key: StringName) -> int:
	return CharacterRoster.person_trait(character_index, key)

func trait_speed_scale() -> float:
	return 1.0 + float(trait_points(&"bilis") - CharacterRoster.TRAIT_NEUTRAL) * TRAIT_SPEED_PER_POINT

func trait_power_scale() -> float:
	return 1.0 + float(trait_points(&"lakas") - CharacterRoster.TRAIT_NEUTRAL) * TRAIT_POWER_PER_POINT

func trait_grit_scale() -> float:
	return maxf(0.1,
		1.0 + float(trait_points(&"tatag") - CharacterRoster.TRAIT_NEUTRAL) * TRAIT_GRIT_PER_POINT)

func _is_mouse_aimed() -> bool:
	return _camera_rig != null and _camera_rig.aim_source == CameraRig.AimSource.MOUSE

## ---------------------------------------------------------------------------
## ROLE QUERIES — the vocabulary every other file asks in.
## ---------------------------------------------------------------------------

## True while this player can take an action at all: round live, not stunned.
func can_act() -> bool:
	return RoundManager.round_active and state == State.NORMAL

func is_attacker() -> bool:
	return not is_defender

func holding_slipper() -> bool:
	return _held_slipper != null and is_instance_valid(_held_slipper)

func held_slipper() -> Slipper:
	return _held_slipper if holding_slipper() else null

## Called by `slipper.gd` on both halves of the relationship. Pass null to clear.
## ⚠️ FORWARDS TO THE `Carrier` COMPONENT rather than letting the slipper tell both
## of them. Two writers of the same relationship is how it ends up half-cleared:
## a hand that still thinks it is full while the slipper is already in the air.
func notify_holding(what: Slipper) -> void:
	_held_slipper = what
	if _carrier != null:
		_carrier.notify_holding(what)

## ⚠️ THE BOX TEST IS A SQUARE AND IT HAS TO MATCH `_move_and_confine()`. Both are
## `max(|x|, |z|)` against the same number; if one of them ever becomes a radial
## test the throw line and the chalk stop agreeing and nobody will be able to see
## why. That is not hypothetical — it happened on 2026-07-29 and cost a session.
func is_inside_box() -> bool:
	return maxf(absf(global_position.x), absf(global_position.z)) < confinement_radius

## `Design.md` §Attacker: an Attacker is 100% safe inside the box *until* they pick
## their slipper up. This one function is the entire vulnerability rule, and
## `RoundManager._step_tag()` and the HUD's `VULNERABLE` row both read it — so the
## warning the player sees cannot disagree with the rule that tags them.
func is_taggable() -> bool:
	if is_defender or not can_act():
		return false
	if not holding_slipper():
		return false
	return is_inside_box()

## A slipper in flight stops on any standing body. Deliberately includes the
## Attackers: three of them crowding the box means friendly fire is part of the
## traffic, and a slipper that passes through teammates would make the Defender's
## body block the only block in the game.
func can_be_hit_by_slipper() -> bool:
	return state != State.DOWNED

## ⚠️ CONFINEMENT IS THE DEFENDER'S BOX, AND IT IS THIS ONE LINE. The Defender
## cannot leave; everyone else moves freely and the box is merely dangerous to
## them. The predecessor confined "the lata, and the Person on the can side",
## which is the same expression with the lata deleted.
func _is_confined_to_base() -> bool:
	return RoundManager.round_active and is_defender

## ---------------------------------------------------------------------------
## ⚠️ SPAWN SETTLE — DO NOT REMOVE. This is the real fix for B-100, and role
## rotation is exactly what triggers it.
##
## Writing `position` on a PhysicsBody3D updates the SCENE TREE at once and the
## physics BROADPHASE only at the next server step. Roles rotate every round, so
## players trade marks — and for one physics frame each is standing on the OTHER
## one's stale collider. Measured: the incoming player is placed correctly, then
## `move_and_slide()` reports three contacts with the outgoing one (normal 0,1,0 —
## stacked on its head), shoves it 1.60 up, and the next frame slides it 9.89
## units into a wall.
##
## Neither `force_update_transform()` nor `PhysicsServer3D.body_set_state()` fixes
## it, and "park everyone at y=500 first" could not either — all three are writes
## the broadphase does not see until it steps. So nobody MOVES until it has.
## Three frames is 50 ms and is invisible.
## ---------------------------------------------------------------------------
const SPAWN_SETTLE_FRAMES: int = 3
var _spawn_settle: int = 0
var _spawn_settle_at: Transform3D = Transform3D.IDENTITY

func begin_spawn_settle() -> void:
	_spawn_settle = SPAWN_SETTLE_FRAMES
	_spawn_settle_at = global_transform
	velocity = Vector3.ZERO

## ⚠️⚠️ YOU CANNOT STAND ON SOMEBODY'S HEAD. Every unit is on collision layer 1
## with the world and with each other, so one capsule resting on another is a
## perfectly legal floor as far as `CharacterBody3D` is concerned — `is_on_floor()`
## goes true in mid-air, gravity is never applied, and the player hovers with full
## walking control.
##
## ⚠️ THE FIX IS A NUDGE, NOT A COLLISION-LAYER CHANGE. Turning
## character-vs-character collision off would take the BODY BLOCK with it, and the
## Defender standing in the throwing lane is a real mechanic. So only a contact
## steep enough to be a *perch* is answered.
const PERCH_NORMAL_MIN: float = 0.7
const PERCH_SHED_SPEED: float = 2.5
var _perched_on_character: bool = false

func _move_and_confine() -> void:
	move_and_slide()
	_shed_character_perch()
	if not _is_confined_to_base():
		return
	global_position.x = clampf(global_position.x, -confinement_radius, confinement_radius)
	global_position.z = clampf(global_position.z, -confinement_radius, confinement_radius)

func _shed_character_perch() -> void:
	_perched_on_character = false
	if not is_on_floor():
		return
	for i in get_slide_collision_count():
		var contact := get_slide_collision(i)
		var other := contact.get_collider() as CharacterBase
		if other == null or other == self:
			continue
		if contact.get_normal().y <= PERCH_NORMAL_MIN:
			continue # a side contact — that is the body block, and it stays
		_perched_on_character = true
		var away := global_position - other.global_position
		away.y = 0.0
		if away.length() < 0.01:
			away = other.global_transform.basis.x
		away = away.normalized()
		velocity.x += away.x * PERCH_SHED_SPEED
		velocity.z += away.z * PERCH_SHED_SPEED
		return

func _ready() -> void:
	spawn_position = global_position
	_visual.apply(is_person, is_can, player_slot)
	state_changed.connect(_on_state_changed_audio)

## ---------------------------------------------------------------------------
## THE FRAME.
## ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _spawn_settle > 0:
		_spawn_settle -= 1
		global_transform = _spawn_settle_at
		velocity = Vector3.ZERO
		return
	if ai_controller != null:
		ai_controller.decide(delta)

	# Cooldowns tick on every peer so the HUD row is honest on a client too.
	if _shove_cooldown_left > 0.0:
		_shove_cooldown_left = maxf(0.0, _shove_cooldown_left - delta)
	if _observed_shove_charge >= 0.0:
		_observed_shove_charge = minf(_observed_shove_charge + delta, SHOVE_CHARGE_TIME)
	if _lunge_cooldown_left > 0.0:
		_lunge_cooldown_left = maxf(0.0, _lunge_cooldown_left - delta)
	if _observed_lunge_charge >= 0.0:
		_observed_lunge_charge = minf(_observed_lunge_charge + delta, LUNGE_CHARGE_TIME)
	if _fatigue_left > 0.0:
		_fatigue_left = maxf(0.0, _fatigue_left - delta)
		if _fatigue_left == 0.0:
			exit_speed_zone(FATIGUE_SPEED_SCALE)

	if NetworkManager.is_networked() and not is_multiplayer_authority():
		return

	var grounded := is_on_floor() and not _perched_on_character
	if grounded and _was_airborne and _fall_speed > LAND_SFX_MIN_SPEED:
		AudioManager.play_at("land", global_position)
	_was_airborne = not grounded
	if not grounded:
		velocity.y -= GRAVITY * delta
		velocity.y = maxf(velocity.y, -MAX_FALL_SPEED)
	_fall_speed = -velocity.y

	# Between rounds: gravity still applies (so nobody is left hovering after an
	# intermission), but nothing else does.
	if not RoundManager.round_active and MatchManager.round_number > 0:
		velocity.x = 0.0
		velocity.z = 0.0
		if is_on_floor():
			velocity.y = 0.0
			return
		_move_and_confine()
		return

	if state == State.NORMAL and is_on_floor() and input_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		AudioManager.play_at("jump", global_position)

	if _carrier != null and state == State.NORMAL:
		_carrier.input_step(delta)
	if state == State.NORMAL:
		_step_shove(delta)
		_step_lunge(delta)

	match state:
		State.STAGGERED:
			_staggered_time_left -= delta
			if _staggered_time_left <= 0.0:
				state = State.NORMAL
		State.DOWNED:
			_downed_time_left -= delta
			if _downed_time_left <= 0.0:
				state = State.NORMAL
		State.NORMAL:
			pass

	if state != State.NORMAL:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)
		_move_and_confine()
		return

	var input_dir := input_vector("move_left", "move_right", "move_up", "move_down")
	var mouse_aimed := _is_mouse_aimed()
	var direction: Vector3
	if mouse_aimed:
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y))
		direction.y = 0.0
		direction = direction.normalized()
	else:
		direction = Vector3(input_dir.x, 0, input_dir.y).normalized()

	var sprint_scale := _step_stamina(delta, direction != Vector3.ZERO)
	if direction:
		var speed_now := SPEED * _role_speed_scale() * _speed_multiplier \
			* trait_speed_scale() * sprint_scale
		velocity.x = direction.x * speed_now
		velocity.z = direction.z * speed_now
		if not mouse_aimed:
			look_at(global_position + direction, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)

	_move_and_confine()
	if ai_controller != null:
		ai_commit_intent_frame()

## ---------------------------------------------------------------------------
## STAMINA AND FATIGUE.
## ---------------------------------------------------------------------------

## 1.0 for the taya, `ATTACKER_SPEED_SCALE` for everyone else. Read off `is_defender`
## every frame rather than cached, because the role rotates at a round boundary and a
## cached copy is one more thing that can be stale on a client.
func _role_speed_scale() -> float:
	return 1.0 if is_defender else ATTACKER_SPEED_SCALE

func _step_stamina(delta: float, moving: bool) -> float:
	if _fatigue_left > 0.0:
		# Sprint is locked out for the whole fatigue window. The speed penalty
		# itself rides the speed-zone stack rather than being multiplied in here,
		# so it composes with a hazard zone instead of one silently winning.
		_is_sprinting = false
		_stamina_idle += delta
		# ⚠️⚠️ NO REGEN WHILE FATIGUED — 🧑 2026-08-01: *"While fatigued, stamina
		# regeneration is completely locked until a 2-second recovery delay
		# expires."* This line used to refill the bar at full rate DURING the
		# penalty, which meant a player who ran themselves to zero was already
		# recovering while "being punished" and walked out of fatigue with a usable
		# bar. The penalty is now the thing it was described as: 2.0 s at reduced
		# speed with the bar genuinely empty, and regen begins after it expires.
		return 1.0
	var wants := moving and input_pressed("sprint")
	var may_start := _is_sprinting or _stamina >= STAMINA_SPRINT_FLOOR
	_is_sprinting = wants and may_start and _stamina > 0.0
	if _is_sprinting:
		_stamina = maxf(0.0, _stamina - STAMINA_DRAIN_RATE * delta)
		_stamina_idle = 0.0
		if _stamina <= 0.0:
			_enter_fatigue()
			return 1.0
		return SPRINT_SCALE
	_stamina_idle += delta
	if _stamina_idle >= STAMINA_REGEN_DELAY:
		_stamina = minf(STAMINA_MAX, _stamina + STAMINA_REGEN_RATE * delta)
	return 1.0

func _enter_fatigue() -> void:
	if _fatigue_left > 0.0:
		return
	_fatigue_left = FATIGUE_TIME
	_is_sprinting = false
	enter_speed_zone(FATIGUE_SPEED_SCALE)
	AudioManager.play_at("stamina_empty", global_position)

func is_fatigued() -> bool:
	return _fatigue_left > 0.0

func get_stamina_ratio() -> float:
	return _stamina / STAMINA_MAX

func spend_stamina(amount: float) -> bool:
	if _fatigue_left > 0.0 or _stamina < amount:
		return false
	_stamina -= amount
	_stamina_idle = 0.0
	if _stamina <= 0.0:
		_stamina = 0.0
		_enter_fatigue()
	return true

## ---------------------------------------------------------------------------
## THE SHOVE. `Design.md` §Attacker — hold E, release, push a neighbour.
##
## ⚠️ E IS CONTEXTUAL AND THAT IS DELIBERATE. The GDD gives E three jobs: tap to
## pick a slipper up, hold 1.25 s to shove, hold 2.5 s (as Defender) to reset the
## lata. Rather than inventing two more keybinds for a game whose whole brief is
## "simpler", the press resolves against what is actually in front of you.
## `carrier.gd` gets first refusal — if there is a slipper at your feet or a lata
## to channel, the press is that. Only a press with nothing to act on charges a
## shove, which is why this runs AFTER `_carrier.input_step()`.
## ---------------------------------------------------------------------------
func _step_shove(_delta: float) -> void:
	if is_defender:
		# The Defender has the tag; giving them the shove as well would make the
		# box unenterable.
		return
	if _carrier != null and _carrier.is_busy():
		_cancel_shove()
		return
	# ⚠️⚠️ SINGLE TAP SINCE 2026-08-01 — `input_just_pressed`, NOT a hold-and-release.
	# 🧑: *"Input: Single tap of E (No charge time)."* The charge loop this replaces
	# is gone rather than parameterised to zero, because a zero-length hold still
	# needed a release frame to fire and would have made the shove cost one extra
	# frame of input latency for no design reason.
	#
	# ⚠️ `_broadcast_shove_charge(true)` STILL FIRES, and it is not vestigial. It is
	# what puts the wind-up pose on every OTHER peer (`character_visual.gd`), and the
	# spec asks for a *"Hand Shove Animation"* — the animation has to exist on the
	# machines watching it, not just on the one that pressed E. It is immediately
	# followed by the release, so the pose reads as a snap rather than a hold.
	if _shove_cooldown_left > 0.0 or not input_just_pressed("grab"):
		return
	if _stamina < SHOVE_STAMINA_COST or _fatigue_left > 0.0:
		return
	_broadcast_shove_charge(true)
	_release_shove()
	_broadcast_shove_charge(false)

## THE TAYA'S LUNGE. Hold right-click, release to dash forward and tag.
##
## ⚠️ THE SWEEP RUNS ON EVERY FRAME THE LUNGE IS LIVE, not once on release. A 2.5 m
## dash at 60 Hz moves ~0.2 m per frame at its peak, so a single end-of-dash test
## would miss an attacker standing halfway along the path — and "caught in the lunge
## path" is the rule, not "standing where the taya stopped".
func _step_lunge(delta: float) -> void:
	if not is_defender:
		# The attackers have the shove. Giving the taya both would be the mirror of
		# the mistake the shove's own guard already prevents.
		_cancel_lunge()
		return
	if _lunge_active_left > 0.0:
		_lunge_active_left = maxf(0.0, _lunge_active_left - delta)
		# Host-only: the tag writes a score, and a score may only be created where
		# `MatchManager.add_score()` can be reached — see `Design.md` §8.
		if not NetworkManager.is_networked() or NetworkManager.is_host():
			_sweep_lunge_tag()
	if _carrier != null and _carrier.is_busy():
		_cancel_lunge()
		return
	if _lunge_charging:
		if input_pressed("lunge"):
			_lunge_charge = minf(_lunge_charge + delta, LUNGE_CHARGE_TIME)
			return
		var power := clampf(_lunge_charge / LUNGE_CHARGE_TIME, LUNGE_MIN_POWER, 1.0)
		_cancel_lunge()
		_release_lunge(power)
		return
	if _lunge_cooldown_left > 0.0 or not input_just_pressed("lunge"):
		return
	if state != State.NORMAL:
		return
	_lunge_charging = true
	_lunge_charge = 0.0
	_broadcast_lunge_charge(true)

func _cancel_lunge() -> void:
	if not _lunge_charging:
		return
	_lunge_charging = false
	_lunge_charge = 0.0
	_broadcast_lunge_charge(false)

func _release_lunge(power: float) -> void:
	_lunge_cooldown_left = LUNGE_COOLDOWN
	_lunge_active_left = LUNGE_ACTIVE_TIME
	broadcast_visual_action("shove")
	AudioManager.play_at("bump_swing", global_position)
	# ⚠️ A VELOCITY IMPULSE, NOT A TELEPORT. The friction model integrates it down to
	# ~2.5 m at full power (v²/60), and the intervening frames are what the sweep
	# below reads. It is also why the taya can be body-blocked mid-lunge rather than
	# passing through geometry.
	var forward := -global_transform.basis.z
	velocity.x = forward.x * LUNGE_SPEED * power
	velocity.z = forward.z * LUNGE_SPEED * power

## Host-side. Any vulnerable attacker within `LUNGE_TAG_RADIUS` is tagged.
##
## ⚠️ IT ASKS `is_taggable()`, THE SAME FUNCTION THE HUD'S `VULNERABLE` ROW ASKS.
## `Design.md` §5.2 makes that a rule rather than a coincidence: the warning a player
## sees and the check that catches them must be one function, or the HUD can promise
## safety the tag then ignores.
func _sweep_lunge_tag() -> void:
	if not RoundManager.round_active:
		return
	var lata := RoundManager.lata
	if lata == null or not lata.is_upright:
		return # a tag requires the lata standing, exactly as the proximity tag did
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null or who == self or who.is_defender:
			continue
		if not who.is_taggable():
			continue
		if global_position.distance_to(who.global_position) > LUNGE_TAG_RADIUS:
			continue
		RoundManager.host_resolve_lunge_tag(self, who)
		_lunge_active_left = 0.0
		return # one tag per lunge — a dash through two attackers is not a double

func _broadcast_lunge_charge(active: bool) -> void:
	if NetworkManager.is_networked():
		_rpc_lunge_charge_visual.rpc(active)
	else:
		_rpc_lunge_charge_visual(active)

@rpc("any_peer", "call_local", "reliable")
func _rpc_lunge_charge_visual(active: bool) -> void:
	_observed_lunge_charge = 0.0 if active else -1.0

## 0..1 while a lunge is being charged anywhere, -1.0 at rest. Read by the HUD and
## by `character_visual.gd`, the same contract `observed_shove_charge()` keeps.
func observed_lunge_charge() -> float:
	if _lunge_charging:
		return clampf(_lunge_charge / LUNGE_CHARGE_TIME, 0.0, 1.0)
	if _observed_lunge_charge < 0.0:
		return -1.0
	return clampf(_observed_lunge_charge / LUNGE_CHARGE_TIME, 0.0, 1.0)

func lunge_cooldown_left() -> float:
	return _lunge_cooldown_left

func _cancel_shove() -> void:
	if not _shove_charging:
		return
	_shove_charging = false
	_shove_charge = 0.0
	_broadcast_shove_charge(false)

func _release_shove() -> void:
	if not spend_stamina(SHOVE_STAMINA_COST):
		return
	_shove_cooldown_left = SHOVE_COOLDOWN
	broadcast_visual_action("shove")
	AudioManager.play_at("bump_swing", global_position)
	if not NetworkManager.is_networked() or NetworkManager.is_host():
		host_resolve_shove(player_slot, global_position, -global_transform.basis.z)
	else:
		_rpc_request_shove.rpc_id(1, global_position, -global_transform.basis.z)

## ⚠️ RESOLVED ON THE HOST BY DISTANCE, like the tag and like slipper contact. The
## client sends where it was and which way it faced; the host decides who that
## reaches. A client that lies about its position can only lie about a 1 m push.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_shove(from: Vector3, facing: Vector3) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	host_resolve_shove(player_slot, from, facing)

func host_resolve_shove(shover_slot: int, from: Vector3, facing: Vector3) -> void:
	var flat_facing := Vector3(facing.x, 0.0, facing.z)
	if flat_facing.length() < 0.01:
		return
	flat_facing = flat_facing.normalized()
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null or who.player_slot == shover_slot or who.is_defender:
			continue # Attackers shove Attackers. The Defender is not shovable.
		if who.state != State.NORMAL:
			continue
		var to_them := who.global_position - from
		to_them.y = 0.0
		var distance := to_them.length()
		if distance > SHOVE_RANGE or distance < 0.01:
			continue
		if rad_to_deg(flat_facing.angle_to(to_them.normalized())) > SHOVE_ARC_DEG:
			continue
		var impulse := to_them.normalized() * SHOVE_SPEED * trait_power_scale() \
			+ Vector3.UP * SHOVE_LIFT
		who.host_apply_shove(impulse, SHOVE_STUN, shover_slot)

func host_apply_shove(impulse: Vector3, stun: float, from_slot: int) -> void:
	# Recorded BEFORE the stun, so a shove that leads straight into a tag still
	# pays the shover even if the tag lands on the very next frame.
	RoundManager.note_shove(player_slot, from_slot)
	if NetworkManager.is_networked():
		_rpc_apply_shove.rpc(impulse, stun)
	else:
		_apply_shove(impulse, stun)

@rpc("authority", "call_local", "reliable")
func _rpc_apply_shove(impulse: Vector3, stun: float) -> void:
	_apply_shove(impulse, stun)

func _apply_shove(impulse: Vector3, stun: float) -> void:
	apply_knockback(impulse)
	apply_stagger(stun)
	_flash_hit("hit_body")

func _broadcast_shove_charge(active: bool) -> void:
	if NetworkManager.is_networked():
		_rpc_shove_charge_visual.rpc(active)
	else:
		_rpc_shove_charge_visual(active)

@rpc("any_peer", "call_local", "reliable")
func _rpc_shove_charge_visual(active: bool) -> void:
	_observed_shove_charge = 0.0 if active else -1.0
	play_visual_action("charge" if active else "shove")

func shove_cooldown_left() -> float:
	return _shove_cooldown_left

## -1 when not charging. Drives the local player's own meter.
func shove_charge_ratio() -> float:
	if not _shove_charging:
		return -1.0
	return clampf(_shove_charge / SHOVE_CHARGE_TIME, 0.0, 1.0)

## -1 when nobody nearby is winding up. Drives the TELL another player sees.
func observed_shove_charge() -> float:
	if _observed_shove_charge < 0.0:
		return -1.0
	return clampf(_observed_shove_charge / SHOVE_CHARGE_TIME, 0.0, 1.0)

## ---------------------------------------------------------------------------
## THE TAG PENALTY. Called host-side by `RoundManager._resolve_tag()`.
## ---------------------------------------------------------------------------

func host_apply_tag_penalty(stun: float) -> void:
	if NetworkManager.is_networked():
		_rpc_tag_penalty.rpc(stun, spawn_position)
	else:
		_apply_tag_penalty(stun, spawn_position)

@rpc("authority", "call_local", "reliable")
func _rpc_tag_penalty(stun: float, safe_spot: Vector3) -> void:
	_apply_tag_penalty(stun, safe_spot)

## ⚠️⚠️ REVERSED 2026-08-01: THE SLIPPER NOW COMES WITH THEM, AND IT IS AN
## ANTI-CAMPING RULE. This function used to drop the slipper where the tag landed,
## on the reasoning that "the retrieval run has to be made again". 🧑 replaced it:
## *"The Attacker spawns with their slipper already back in hand (eliminates Danger
## Zone slipper camping)."*
##
## The old rule had a failure mode that got worse the better the taya was: every tag
## left one more slipper lying inside the box, so a taya who tagged well accumulated
## a pile of them on their own mark and could simply stand over it. The attackers
## then had to enter a box carpeted with their own equipment, which is the opposite
## of the tension the retrieval is supposed to create. Sending the slipper home with
## its owner keeps the penalty (5 s stunned, and the whole trip to make again) and
## deletes the camping.
##
## ⚠️ THE PENALTY IS STILL REAL, and it is worth being explicit about what remains:
## the attacker loses their position, 5 seconds, and the throw they were about to
## make. What they no longer lose is the ability to try again without first solving
## a pile of slippers under the taya's feet.
func _apply_tag_penalty(stun: float, safe_spot: Vector3) -> void:
	global_position = safe_spot
	velocity = Vector3.ZERO
	begin_spawn_settle()
	snap_visual_interpolation()
	apply_stagger(stun)
	AudioManager.play_at("tag", global_position)

## ---------------------------------------------------------------------------
## DAMAGE AND STATE.
## ---------------------------------------------------------------------------

func apply_stagger(duration: float = BASE_STAGGER_TIME) -> void:
	if state == State.DOWNED:
		return
	# ⚠️ `max`, NOT `+`. Two stuns overlap, they do not stack — there is no
	# additive path anywhere in the game and that is what bounds a stun chain.
	# ⚠️ ITS KNOWN COST: a short stun landing inside a longer one is INVISIBLE, so
	# a 1.25 s shove inside the 5 s tag penalty reads as nothing happening. Filed
	# to the backlog rather than fixed here, because fixing it means a status
	# stack that can show two rows for the same effect.
	_staggered_time_left = maxf(_staggered_time_left, duration / trait_grit_scale())
	state = State.STAGGERED

func go_downed(duration: float = 1.0) -> void:
	_downed_time_left = duration
	_cancel_shove()
	state = State.DOWNED

func enter_speed_zone(multiplier: float) -> void:
	_active_speed_multipliers.append(multiplier)
	_recompute_speed_multiplier()

func exit_speed_zone(multiplier: float) -> void:
	var idx := _active_speed_multipliers.find(multiplier)
	if idx != -1:
		_active_speed_multipliers.remove_at(idx)
	_recompute_speed_multiplier()

func _recompute_speed_multiplier() -> void:
	var lowest := 1.0
	for m in _active_speed_multipliers:
		lowest = minf(lowest, m)
	_speed_multiplier = lowest

func apply_knockback(impulse: Vector3) -> void:
	if impulse.is_zero_approx() or not RoundManager.round_active:
		return
	impulse /= trait_grit_scale()
	var flat := Vector2(impulse.x, impulse.z)
	if flat.length() > MAX_KNOCKBACK_SPEED:
		flat = flat.normalized() * MAX_KNOCKBACK_SPEED
	velocity.x += flat.x
	velocity.z += flat.y
	velocity.y = maxf(velocity.y, minf(impulse.y, MAX_KNOCKBACK_LIFT))

## ---------------------------------------------------------------------------
## THE HUD'S STATUS STACK. `Design.md` §Status readability — a stun the player
## cannot time is a stun they cannot play around, which is most of what "the
## defender feels overpowered" was.
##
## ⚠️ THE PRODUCER CHANGED AND THE CONSUMER DID NOT. `hud.gd::_refresh_status_stack`
## reads `[{label, seconds, total}]` and draws a labelled bar per row; every row
## below is new but the contract is the one it already had.
## ---------------------------------------------------------------------------
func status_effects() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match state:
		State.STAGGERED:
			out.append({"label": "STUNNED", "seconds": _staggered_time_left,
				"total": maxf(_staggered_time_left, BASE_STAGGER_TIME)})
		State.DOWNED:
			out.append({"label": "DOWNED", "seconds": _downed_time_left,
				"total": maxf(_downed_time_left, 1.0)})
		State.NORMAL:
			pass
	if _fatigue_left > 0.0:
		out.append({"label": "FATIGUED", "seconds": _fatigue_left, "total": FATIGUE_TIME})
	# ⚠️ VULNERABLE IS THE MOST IMPORTANT ROW ON THE HUD and it has no countdown —
	# it lasts exactly as long as you choose to stay in the box holding a slipper.
	# `seconds` 0 with a non-zero `total` is the contract hud.gd reads as "solid
	# bar, no timer", which is the honest drawing of a state you control.
	if is_taggable():
		out.append({"label": "VULNERABLE", "seconds": 0.0, "total": 1.0})
	if _shove_cooldown_left > 0.0:
		out.append({"label": "SHOVE CD", "seconds": _shove_cooldown_left,
			"total": SHOVE_COOLDOWN})
	# The taya's lunge. Same contract as SHOVE CD — a cooldown the player cannot see
	# is a cooldown they mash into, and the lunge is now the only way to score a tag.
	if _lunge_cooldown_left > 0.0:
		out.append({"label": "LUNGE CD", "seconds": _lunge_cooldown_left,
			"total": LUNGE_COOLDOWN})
	if RoundManager.throw_cooldown_left() > 0.0 and not is_defender:
		out.append({"label": "THROW CD", "seconds": RoundManager.throw_cooldown_left(),
			"total": RoundManagerScript.THROW_RESTORE_COOLDOWN})
	return out

## ---------------------------------------------------------------------------
## FEEDBACK.
## ---------------------------------------------------------------------------

func _flash_hit(sfx: String = "") -> void:
	_visual.flash_hit()
	if sfx != "":
		AudioManager.play_at(sfx, global_position)
	_hitstop()
	var is_mine := (is_multiplayer_authority() and ai_controller == null) \
		if NetworkManager.is_networked() else player_id == 1
	if is_mine and _camera_rig != null:
		_camera_rig.shake()

func _hitstop() -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	_hitstop_restore_scale = Engine.time_scale
	Engine.time_scale = HITSTOP_TIME_SCALE
	get_tree().create_timer(HITSTOP_DURATION, true, false, true).timeout.connect(_end_hitstop)

func _end_hitstop() -> void:
	Engine.time_scale = _hitstop_restore_scale
	_hitstop_active = false

func _on_state_changed_audio(new_state: State) -> void:
	match new_state:
		State.DOWNED:
			AudioManager.play_at("downed", global_position)
		State.NORMAL, State.STAGGERED:
			pass
	_audio_prev_state = new_state

## ---------------------------------------------------------------------------
## INPUT — the one indirection that lets the AI press the same buttons a human
## does, so `_physics_process` above never branches on who is driving.
## ---------------------------------------------------------------------------
var _ai_intent: Dictionary = {}      ## base action -> bool, this frame
var _ai_intent_prev: Dictionary = {} ## base action -> bool, previous frame
var ai_aim_point: Vector3 = Vector3.INF
var input_parked: bool = false

func is_ai_driven() -> bool:
	return ai_controller != null and ai_controller.is_enabled()

func _ai_driven() -> bool:
	return is_ai_driven()

func ai_set_intent(base_name: String, pressed: bool) -> void:
	_ai_intent[base_name] = pressed

func ai_commit_intent_frame() -> void:
	_ai_intent_prev = _ai_intent.duplicate()

func ai_clear_intent() -> void:
	_ai_intent.clear()
	_ai_intent_prev.clear()

func _reads_hardware() -> bool:
	return not _ai_driven() and not input_parked

func input_pressed(base_name: String) -> bool:
	if _ai_driven():
		return _ai_intent.get(base_name, false)
	return _reads_hardware() and Input.is_action_pressed(base_name)

func input_just_pressed(base_name: String) -> bool:
	if _ai_driven():
		return _ai_intent.get(base_name, false) and not _ai_intent_prev.get(base_name, false)
	return _reads_hardware() and Input.is_action_just_pressed(base_name)

func input_just_released(base_name: String) -> bool:
	if _ai_driven():
		return _ai_intent_prev.get(base_name, false) and not _ai_intent.get(base_name, false)
	return _reads_hardware() and Input.is_action_just_released(base_name)

func input_vector(neg_x: String, pos_x: String, neg_y: String, pos_y: String) -> Vector2:
	if _ai_driven():
		var v := Vector2(
			(1.0 if _ai_intent.get(pos_x, false) else 0.0) - (1.0 if _ai_intent.get(neg_x, false) else 0.0),
			(1.0 if _ai_intent.get(pos_y, false) else 0.0) - (1.0 if _ai_intent.get(neg_y, false) else 0.0))
		return v.normalized() if v.length() > 1.0 else v
	if not _reads_hardware():
		return Vector2.ZERO
	return Input.get_vector(neg_x, pos_x, neg_y, pos_y)

func action_name(base_name: String) -> String:
	return base_name

## ---------------------------------------------------------------------------
## VISUAL PASSTHROUGH.
##
## ⚠️ `broadcast_visual_action` EXISTS BECAUSE EVERY SWING AND LUNGE WAS ONCE
## ANIMATED ONLY ON THE PRESSER'S OWN MACHINE. An action nobody else can see is an
## action nobody else can answer.
## ---------------------------------------------------------------------------

func get_hand_attachment() -> Node3D:
	return _visual.get_hand_attachment()

func play_visual_action(kind: String) -> void:
	_visual.play_action(kind)

func broadcast_visual_action(kind: String) -> void:
	if NetworkManager.is_networked():
		_rpc_visual_action.rpc(kind)
	else:
		play_visual_action(kind)

@rpc("any_peer", "call_local", "reliable")
func _rpc_visual_action(kind: String) -> void:
	play_visual_action(kind)

func snap_visual_interpolation() -> void:
	_visual.snap_remote_transform()

func capsule_height() -> float:
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		return (shape_node.shape as CapsuleShape3D).height
	return 1.6

func capsule_radius() -> float:
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		return (shape_node.shape as CapsuleShape3D).radius
	return 0.4

## ---------------------------------------------------------------------------
## LIFECYCLE.
## ---------------------------------------------------------------------------

func respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	begin_spawn_settle()
	snap_visual_interpolation()
	AudioManager.play_at("respawn", global_position)
	_was_airborne = false
	_fall_speed = 0.0

func reset_for_new_round() -> void:
	velocity = Vector3.ZERO
	_staggered_time_left = 0.0
	_downed_time_left = 0.0
	_active_speed_multipliers.clear()
	_speed_multiplier = 1.0
	_stamina = STAMINA_MAX
	_stamina_idle = 0.0
	_is_sprinting = false
	_fatigue_left = 0.0
	_cancel_shove()
	_shove_cooldown_left = 0.0
	_observed_shove_charge = -1.0
	_held_slipper = null
	_audio_prev_state = State.NORMAL
	var was_state := state
	state = State.NORMAL
	# ⚠️ The setter above suppresses a same-value write, so a unit that was ALREADY
	# NORMAL would never re-emit — and the nameplate and HUD both refresh off this
	# signal at a role rotation. Emit it by hand in exactly that case.
	if was_state == State.NORMAL:
		state_changed.emit(state)
	if _carrier != null:
		_carrier.reset_for_new_round()
	_visual.apply(is_person, is_can, player_slot)
