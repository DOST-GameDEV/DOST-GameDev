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
## many skills and shit earlier ... too complicated and far from tumbang preso"*.
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
const LAUNCH_SPEED: float = 17.0
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
## Where a LOOSE slipper sits relative to the floor it landed on.
const REST_HEIGHT: float = 0.08
## Visual spin about the long axis while airborne, degrees/second.
const SPIN_SPEED_DEG: float = 900.0
## End-over-end tumble, degrees/second. A real thrown slipper does both at once;
## doing only the spin is what made the predecessor read as "flying perfectly flat".
const TUMBLE_SPEED_DEG: float = 520.0
## How far below the arena a slipper has to fall before it is considered lost and
## returned to its spawn rather than falling forever.
const VOID_Y: float = -12.0

@onready var _visual: Node3D = $Visual

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
	_set_state(CarryState.LOOSE)

## ---------------------------------------------------------------------------
## QUERIES — the gates `carrier.gd` and the HUD ask.
## ---------------------------------------------------------------------------

func is_loose() -> bool:
	return state == CarryState.LOOSE

func is_flying() -> bool:
	return state == CarryState.FLYING

## Any Attacker who is not already holding one may pick up any loose slipper, and
## picking it up REASSIGNS ownership. Deliberately not "your own slipper only":
## with three attackers converging on one box, slippers land in a pile, and a rule
## that makes you hunt for your specific one is a rule that reads as a bug.
func can_be_grabbed_by(who: CharacterBase) -> bool:
	if who == null or state != CarryState.LOOSE:
		return false
	if who.is_defender or not who.can_act():
		return false
	return not who.holding_slipper()

## ---------------------------------------------------------------------------
## STATE TRANSITIONS. Host decides; every peer is told.
## ---------------------------------------------------------------------------

func host_grab(by: CharacterBase) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if not can_be_grabbed_by(by):
		return
	if NetworkManager.is_networked():
		_rpc_grabbed.rpc(by.player_slot)
	else:
		_apply_grabbed(by.player_slot)

@rpc("authority", "call_local", "reliable")
func _rpc_grabbed(slot: int) -> void:
	_apply_grabbed(slot)

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
	var speed: float = LAUNCH_SPEED * lerpf(MIN_POWER_SCALE, 1.0, clampf(power, 0.0, 1.0))
	var direction := _solve_arc(origin, target_point, speed)
	if NetworkManager.is_networked():
		_rpc_thrown.rpc(from.player_slot, origin, direction * speed)
	else:
		_apply_thrown(from.player_slot, origin, direction * speed)

@rpc("authority", "call_local", "reliable")
func _rpc_thrown(slot: int, origin: Vector3, launch_velocity: Vector3) -> void:
	_apply_thrown(slot, origin, launch_velocity)

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
		_rpc_landed.rpc(global_position)
	else:
		_apply_landed(global_position)

@rpc("authority", "call_local", "reliable")
func _rpc_landed(where: Vector3) -> void:
	_apply_landed(where)

func _apply_landed(where: Vector3) -> void:
	if carrier != null:
		carrier.notify_holding(null)
	carrier = null
	_thrower = null
	_velocity = Vector3.ZERO
	global_position = Vector3(where.x, maxf(where.y, REST_HEIGHT), where.z)
	rotation = Vector3.ZERO
	if _visual != null:
		_visual.rotation = Vector3.ZERO
	_set_state(CarryState.LOOSE)

func host_reset_for_new_round() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if NetworkManager.is_networked():
		_rpc_landed.rpc(spawn_position)
	else:
		_apply_landed(spawn_position)

func _set_state(new_state: CarryState) -> void:
	if state == new_state:
		return
	state = new_state
	carry_state_changed.emit(new_state)

## ---------------------------------------------------------------------------
## SIMULATION.
## ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	match state:
		CarryState.CARRIED:
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
	else:
		global_position = carrier.global_position + Vector3.UP * 1.0

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
	_spin(delta)

	var host_side := not NetworkManager.is_networked() or NetworkManager.is_host()
	if not host_side:
		return

	if global_position.y < VOID_Y or _flight_time >= MAX_FLIGHT_TIME:
		host_reset_for_new_round()
		return

	var blocker := _first_body_hit()
	if blocker != null:
		# THE BODY BLOCK. `Design.md` §Defender — a slipper stopped by a body is
		# the Defender's whole passive verb, so it drops at the point of contact
		# rather than being absorbed. That is what makes blocking a trade: they
		# stopped the throw, and now the slipper is deep inside their box.
		AudioManager.play_at("hit_body", global_position)
		if NetworkManager.is_networked():
			_rpc_landed.rpc(_ground_under(global_position))
		else:
			_apply_landed(_ground_under(global_position))
		return

	# ⚠️ NOT NAMED `lata` — a local of that name SHADOWS the `Lata` class, and every
	# member access on it then resolves against nothing.
	var target: Lata = RoundManager.lata
	if target != null and target.is_upright \
			and _flat_distance(global_position, target.global_position) <= HIT_RADIUS + 0.30 \
			and absf(global_position.y - target.global_position.y) < 1.0:
		target.host_knock_down(owner_slot)
		if NetworkManager.is_networked():
			_rpc_landed.rpc(_ground_under(global_position))
		else:
			_apply_landed(_ground_under(global_position))
		return

	if global_position.y <= REST_HEIGHT:
		if NetworkManager.is_networked():
			_rpc_landed.rpc(_ground_under(global_position))
		else:
			_apply_landed(_ground_under(global_position))

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

func _ground_under(where: Vector3) -> Vector3:
	return Vector3(where.x, REST_HEIGHT, where.z)

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
static func launch_velocity_for(origin: Vector3, target: Vector3, power: float) -> Vector3:
	var speed: float = LAUNCH_SPEED * lerpf(MIN_POWER_SCALE, 1.0, clampf(power, 0.0, 1.0))
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

func apply_skin(index: int) -> void:
	if index < 0 or index == skin_index:
		return
	skin_index = index
	var entry: Dictionary = CharacterRoster.slipper_at(index)
	if not entry.has("tint"):
		return
	_tint_meshes(entry["tint"])

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
