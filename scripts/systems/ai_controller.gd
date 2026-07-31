extends Node
class_name AIController
## Fills a seat nobody is sitting in — Single Player, and any empty slot in a
## networked lobby. Rewritten 2026-07-31 on branch `HARRYDAKS`.

## ---------------------------------------------------------------------------
## ⚠️⚠️ THIS REPLACES A 3 172-LINE BEHAVIOUR TREE AND IS SMALLER ON PURPOSE.
## 🧑 2026-07-31: *"we will fix the ai as well but put that in the end of agent
## prompts lane"*, and then *"develop the singleplayer too but the ai doesn't have
## to be that developed yet, maybe you could use old attacker defender ai for it"*.
##
## ⚠️ THE OLD ATTACKER/DEFENDER SHAPE IS CARRIED OVER; THE OLD CODE COULD NOT BE.
## That distinction is the whole story of this file. The predecessor's *structure*
## — one branch for the side that throws, one for the side that guards, both
## driving the same intent dictionary — is exactly what is below. Its *leaves*
## were unportable: every one of them acted on a lata that could dash, a tsinelas
## that could launch itself and dive, a `Carriable` component, or an `AbilityBase`
## resource. All four of those classes are deleted. Keeping the file would have
## meant rewriting every leaf anyway, at ten times the size, inside a lane the
## human has explicitly deferred.
##
## ⚠️ WHAT IT DOES NOT HAVE, so nobody mistakes this for a tuned baseline: no
## lookahead, no lane reasoning, no dodging, no shove, no body-blocking intent, no
## anticipation. The difficulty tiers scale two things — reaction time and aim
## scatter — and nothing else. **`build ai` is the last lane on the board and this
## file is its whole job.** It is a placeholder that films, not a baseline worth
## tuning.
##
## ⚠️ IT PRESSES BUTTONS, IT DOES NOT MOVE BODIES, and a rewrite must keep that.
## Every decision goes out through `CharacterBase.ai_set_intent()`, the same
## indirection a human's keyboard feeds, so `_physics_process` never branches on
## who is driving — the confinement clamp, the stun states, the throw gate and the
## netcode all apply to a bot for free. An AI that writes `velocity` directly
## desyncs the moment it is not the authority for the body it is writing to.
## ---------------------------------------------------------------------------

enum Difficulty { BATA, NORMAL, ASTIG }

## ⚠️ THE KEYS ARE A SUBSET OF WHAT THIS TABLE USED TO CARRY. `pursue`, `lead`,
## `gait` and `mistake` described verbs that no longer exist. What survives is the
## two things a simple bot can honestly vary: how long it takes to notice
## something, and how badly it aims.
const DIFFICULTY_TIERS: Dictionary = {
	Difficulty.BATA:   {"think": 0.50, "aim_error": 1.60, "charge": 0.40},
	Difficulty.NORMAL: {"think": 0.35, "aim_error": 0.80, "charge": 0.65},
	Difficulty.ASTIG:  {"think": 0.22, "aim_error": 0.25, "charge": 0.85},
}

static var difficulty: Difficulty = Difficulty.NORMAL
## Seconds between re-decisions. A bot that re-plans every frame reads as a
## twitching machine rather than as a player.
static var tier_think: float = 0.35
## Metres of scatter added to the aim point.
static var tier_aim_error: float = 0.80
## How full a charge it releases at.
static var tier_charge: float = 0.65

## Read by `settings_manager.gd` off the saved difficulty index.
static func apply_difficulty(tier: Difficulty) -> void:
	difficulty = tier
	var values: Dictionary = DIFFICULTY_TIERS[tier]
	tier_think = float(values["think"])
	tier_aim_error = float(values["aim_error"])
	tier_charge = float(values["charge"])

## How close the bot tries to get to a thing before it acts on it.
const REACH: float = 1.0
## How far outside the box an Attacker retreats before throwing. A metre of margin
## past the line, so a bot that drifts does not lose its own throw to the gate.
const THROW_STANDOFF: float = 1.2
## How far from the lata a Defender parks while nothing is happening.
const GUARD_RADIUS: float = 2.2
## Above this distance the bot sprints. Short legs are walked, so a bot does not
## spend the round fatigued and then get tagged standing still — which is what
## "the AI just gives up" looks like from the outside.
const SPRINT_DISTANCE: float = 6.0

## ⚠️ PUBLIC AND NAMED `character`, because `main.gd::_attach_ai` constructs this
## with a bare `.new()` and assigns afterwards. Resolved from the parent in
## `_ready()` as well, so either order works.
var character: CharacterBase = null

var _enabled: bool = true
var _think_left: float = 0.0
var _aim_jitter: Vector3 = Vector3.ZERO
## Held across think ticks so the bot commits to a charge instead of stuttering.
var _charging: bool = false

func _ready() -> void:
	if character == null:
		character = get_parent() as CharacterBase

## Debug-switcher hand-off: a human taking manual control of an AI-driven unit
## must not fight the AI for the same buttons. Disabling releases everything this
## controller might be mid-press on, so nothing sticks "held" once a human is
## driving instead.
func set_enabled(enabled: bool) -> void:
	if _enabled == enabled:
		return
	_enabled = enabled
	if not enabled and character != null:
		_release_all()
		# Wipe the intent too, or CharacterBase keeps answering `input_pressed()`
		# from a stale dictionary while a human is trying to drive — the unit would
		# walk into a wall on its own.
		character.ai_clear_intent()

## `CharacterBase` asks this before deciding whether to read intent or hardware.
func is_enabled() -> bool:
	return _enabled

## Called from `CharacterBase._physics_process` before it reads input.
func decide(delta: float) -> void:
	if not _enabled or character == null or not is_instance_valid(character):
		return
	if not RoundManager.round_active or not character.can_act():
		_release_all()
		return
	_think_left -= delta
	if _think_left <= 0.0:
		_think_left = tier_think
		# ⚠️ SCATTER IS RE-ROLLED PER THINK TICK, NOT PER FRAME. Per frame it
		# averages out to a perfect shot over the length of a charge, which is the
		# opposite of what an aim error is for.
		_aim_jitter = Vector3(randf_range(-tier_aim_error, tier_aim_error), 0.0,
			randf_range(-tier_aim_error, tier_aim_error))
	if character.is_defender:
		_act_defender()
	else:
		_act_attacker()

## ---------------------------------------------------------------------------
## THE ATTACKER: retrieve → leave the box → throw.
## ---------------------------------------------------------------------------
func _act_attacker() -> void:
	var lata := RoundManager.lata
	if not character.holding_slipper():
		_press("special_ability", false)
		_charging = false
		var slipper := _nearest_loose_slipper()
		if slipper == null:
			_walk_to(character.spawn_position)
			return
		_walk_to(slipper.global_position)
		# ⚠️ THE PICKUP IS A TAP AND HOLDING `grab` WOULD CHARGE A SHOVE INSTEAD, so
		# it is pressed only on the frames the bot is genuinely in range.
		_press("grab", character.global_position.distance_to(slipper.global_position) <= REACH)
		return
	_press("grab", false)
	# Holding a slipper inside the box is the one state that can be tagged, and a
	# bot that lingers there is a bot that hands the Defender 100 points.
	if character.is_inside_box() or lata == null or not lata.is_upright \
			or not RoundManager.can_throw(character):
		_charging = false
		_press("special_ability", false)
		_walk_to(_safe_spot())
		return
	# In position, armed, and the lata is up: aim and commit.
	character.ai_aim_point = lata.global_position + _aim_jitter + Vector3.UP * 0.3
	_stop()
	var carrier := character.get_node_or_null("Carrier") as Carrier
	var power: float = carrier.charge_power() if carrier != null else 0.0
	if _charging and power >= tier_charge:
		_press("special_ability", false) # release IS the throw
		_charging = false
		return
	_charging = true
	_press("special_ability", true)

## The nearest point outside the box, straight out along the bearing this bot is
## already on — so a retreat is a step back rather than a lap of the arena.
func _safe_spot() -> Vector3:
	var here := character.global_position
	var bearing := Vector3(here.x, 0.0, here.z)
	if bearing.length() < 0.01:
		bearing = Vector3(0.0, 0.0, 1.0)
	var ring: float = CharacterBase.confinement_radius + THROW_STANDOFF
	return bearing.normalized() * ring

func _nearest_loose_slipper() -> Slipper:
	var best: Slipper = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper == null or not slipper.is_loose():
			continue
		var distance := character.global_position.distance_to(slipper.global_position)
		if distance < best_distance:
			best_distance = distance
			best = slipper
	return best

## ---------------------------------------------------------------------------
## THE DEFENDER: stand the lata back up → chase a vulnerable Attacker → guard.
## ---------------------------------------------------------------------------
func _act_defender() -> void:
	_press("special_ability", false)
	var lata := RoundManager.lata
	if lata == null:
		_stop()
		return
	if not lata.is_upright:
		# Standing it back up outranks everything: it restores the +10/s AND it is
		# the only thing that closes the attackers' free-throw window. Hold `grab`
		# once inside the ring — `carrier.gd` runs the 2.5 s channel.
		_walk_to(lata.global_position)
		_press("grab", lata.is_in_ring(character.global_position))
		return
	_press("grab", false)
	var target := _nearest_taggable()
	if target != null:
		# The tag needs no button — walking into them is the whole verb.
		_walk_to(target.global_position)
		return
	# Nothing to chase: stand between the lata and the nearest Attacker rather than
	# on top of the lata, so the body actually blocks a throwing lane.
	var threat := _nearest_attacker()
	if threat == null:
		_walk_to(lata.global_position)
		return
	var toward := threat.global_position - lata.global_position
	toward.y = 0.0
	if toward.length() < 0.01:
		_walk_to(lata.global_position)
		return
	_walk_to(lata.global_position + toward.normalized() * GUARD_RADIUS)

func _nearest_taggable() -> CharacterBase:
	var best: CharacterBase = null
	var best_distance := INF
	for who in RoundManager.players():
		if not who.is_taggable():
			continue
		var distance := character.global_position.distance_to(who.global_position)
		if distance < best_distance:
			best_distance = distance
			best = who
	return best

func _nearest_attacker() -> CharacterBase:
	var best: CharacterBase = null
	var best_distance := INF
	for who in RoundManager.players():
		if who.is_defender:
			continue
		var distance := character.global_position.distance_to(who.global_position)
		if distance < best_distance:
			best_distance = distance
			best = who
	return best

## ---------------------------------------------------------------------------
## INTENT. Movement is expressed as WASD presses in WORLD space, because a bot is
## never mouse-aimed and `CharacterBase.input_vector()` reads a non-mouse-aimed
## unit's stick as world-relative.
## ---------------------------------------------------------------------------
func _walk_to(target: Vector3) -> void:
	var delta := target - character.global_position
	delta.y = 0.0
	if delta.length() <= REACH * 0.5:
		_stop()
		return
	var direction := delta.normalized()
	_press("move_right", direction.x > 0.35)
	_press("move_left", direction.x < -0.35)
	_press("move_down", direction.z > 0.35)
	_press("move_up", direction.z < -0.35)
	_press("sprint", delta.length() > SPRINT_DISTANCE and character.get_stamina_ratio() > 0.4)

func _stop() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "sprint"]:
		_press(action, false)

func _release_all() -> void:
	_charging = false
	for action in ["move_left", "move_right", "move_up", "move_down", "sprint",
			"grab", "special_ability", "jump"]:
		_press(action, false)

func _press(action: String, pressed: bool) -> void:
	if character != null:
		character.ai_set_intent(action, pressed)
