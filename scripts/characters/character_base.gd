extends CharacterBody3D
class_name CharacterBase


const SPEED: float = 4.6
const ATTACKER_SPEED_SCALE: float = 0.75
const FRICTION: float = 30.0
const GRAVITY: float = 20.0
const MAX_FALL_SPEED: float = 26.0
const JUMP_VELOCITY: float = 5.8
const LAND_SFX_MIN_SPEED: float = 2.0

const STAMINA_MAX: float = 60.0
const STAMINA_DRAIN_RATE: float = 40.0
const STAMINA_REGEN_RATE: float = 20.0
const STAMINA_REGEN_DELAY: float = 1.0
const SPRINT_SCALE: float = 1.50
const STAMINA_SPRINT_FLOOR: float = 7.5
const FATIGUE_TIME: float = 2.0
const FATIGUE_SPEED_SCALE: float = 0.75

const CONFINEMENT_RADIUS: float = 7.0
static var confinement_radius: float = CONFINEMENT_RADIUS

static var playable_half_x: float = 1000.0
static var playable_half_z: float = 1000.0

static func clamp_to_playable(where: Vector3, margin: float = 0.45) -> Vector3:
	var limit_x := maxf(playable_half_x - margin, 0.5)
	var limit_z := maxf(playable_half_z - margin, 0.5)
	return Vector3(clampf(where.x, -limit_x, limit_x), where.y,
		clampf(where.z, -limit_z, limit_z))

const SHOVE_CHARGE_TIME: float = 0.0
const SHOVE_SPEED: float = 12.247
const SHOVE_LIFT: float = 2.2
const SHOVE_STUN: float = 1.25
const SHOVE_STAMINA_COST: float = 25.0
const SHOVE_COOLDOWN: float = 7.5
const SHOVE_MISS_COOLDOWN: float = 2.0
const SHOVE_RANGE: float = 1.6
const SHOVE_ARC_DEG: float = 70.0

const LUNGE_CHARGE_TIME: float = 0.5
const LUNGE_SPEED: float = 7.746
const LUNGE_TAG_RADIUS: float = 1.3
const LUNGE_ACTIVE_TIME: float = 0.45
const LUNGE_COOLDOWN: float = 1.5
const LUNGE_MIN_POWER: float = 0.35

const PUNCH_RANGE: float = 1.7
const PUNCH_ARC_DEG: float = 75.0
const PUNCH_COOLDOWN: float = 0.9

const MAX_KNOCKBACK_SPEED: float = 16.0
const MAX_KNOCKBACK_LIFT: float = 7.0
const BASE_STAGGER_TIME: float = 0.25

const HITSTOP_DURATION: float = 0.06
const HITSTOP_TIME_SCALE: float = 0.05
static var _hitstop_active: bool = false
static var _hitstop_restore_scale: float = 1.0

enum State { NORMAL, STAGGERED, DOWNED }

@export var is_person: bool = true
@export var is_can: bool = false

@export var is_defender: bool = false
@export var player_slot: int = 0
@export_range(1, 4, 1) var player_id: int = 1

@export var player_name: String = ""

@export var is_bot: bool = false

func display_name() -> String:
	if is_bot or is_ai_driven():
		return _character_name().to_upper()
	if player_name != "":
		return player_name.to_upper()
	return "P%d" % [player_slot + 1]

func _character_name() -> String:
	if character_index < 0 or character_index >= CharacterRoster.size():
		return "P%d" % [player_slot + 1]
	return CharacterRoster.name_at(character_index)

var character_index: int = -1:
	set(value):
		if character_index == value:
			return
		character_index = value
		_repaint_for_pick()

var _pick_repaint_pending: bool = false

func _repaint_for_pick() -> void:
	if _visual == null or not is_instance_valid(_visual):
		return
	var carrier := get_node_or_null("Carrier") as Carrier
	if carrier != null and carrier.held() != null:
		_pick_repaint_pending = true
		return
	_pick_repaint_pending = false
	_visual.apply(is_person, is_can, player_slot)

signal state_changed(new_state: State)

var spawn_position: Vector3 = Vector3.ZERO

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
var _observed_shove_charge: float = -1.0

var _lunge_charge: float = 0.0
var _lunge_charging: bool = false
var _lunge_cooldown_left: float = 0.0
var _punch_cooldown_left: float = 0.0
var _lunge_active_left: float = 0.0
var _observed_lunge_charge: float = -1.0

var _was_airborne: bool = false
var _fall_speed: float = 0.0
var _audio_prev_state: State = State.NORMAL

var _held_slipper: Slipper = null

@onready var _visual: CharacterVisual = $Visual
@onready var _camera_rig: CameraRig = get_node_or_null("CameraRig")
@onready var _carrier: Carrier = get_node_or_null("Carrier")

var ai_controller: AIController = null

const TRAIT_SPEED_PER_POINT: float = 0.05
const TRAIT_POWER_PER_POINT: float = 0.07
const TRAIT_GRIT_PER_POINT: float = 0.07

func trait_points(key: StringName) -> int:
	return CharacterRoster.person_trait(character_index, key)

func trait_speed_scale() -> float:
	return CharacterRoster.trait_scale(trait_points(&"bilis"), TRAIT_SPEED_PER_POINT)

func trait_power_scale() -> float:
	return CharacterRoster.trait_scale(trait_points(&"lakas"), TRAIT_POWER_PER_POINT)

func trait_grit_scale() -> float:
	return maxf(0.1, CharacterRoster.trait_scale(trait_points(&"tatag"), TRAIT_GRIT_PER_POINT))

func _is_mouse_aimed() -> bool:
	return _camera_rig != null and _camera_rig.aim_source == CameraRig.AimSource.MOUSE


func can_act() -> bool:
	return RoundManager.round_active and state == State.NORMAL

func is_attacker() -> bool:
	return not is_defender

func holding_slipper() -> bool:
	return _held_slipper != null and is_instance_valid(_held_slipper)

func held_slipper() -> Slipper:
	return _held_slipper if holding_slipper() else null

func notify_holding(what: Slipper) -> void:
	_held_slipper = what
	if _carrier != null:
		_carrier.notify_holding(what)

func is_inside_box() -> bool:
	return maxf(absf(global_position.x), absf(global_position.z)) < confinement_radius

func is_taggable() -> bool:
	if is_defender or not RoundManager.round_active:
		return false
	if not holding_slipper():
		return false
	return is_inside_box()

func can_be_hit_by_slipper() -> bool:
	return state != State.DOWNED

func _is_confined_to_base() -> bool:
	return RoundManager.round_active and is_defender

const SPAWN_SETTLE_FRAMES: int = 3
var _spawn_settle: int = 0
var _spawn_settle_at: Transform3D = Transform3D.IDENTITY

func begin_spawn_settle() -> void:
	_spawn_settle = SPAWN_SETTLE_FRAMES
	_spawn_settle_at = global_transform
	velocity = Vector3.ZERO

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
			continue
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
	_visual.emote_finished.connect(_restore_emote_camera)
	state_changed.connect(_on_state_changed_emote)

func _on_state_changed_emote(new_state: State) -> void:
	if new_state != State.NORMAL:
		stop_emote()


func _physics_process(delta: float) -> void:
	_step_hitstop()
	if _spawn_settle > 0:
		_spawn_settle -= 1
		global_transform = _spawn_settle_at
		velocity = Vector3.ZERO
		return
	if ai_controller != null:
		ai_controller.decide(delta)

	_cancel_emote_on_input()

	if _shove_cooldown_left > 0.0:
		_shove_cooldown_left = maxf(0.0, _shove_cooldown_left - delta)
	if _observed_shove_charge >= 0.0:
		_observed_shove_charge = minf(_observed_shove_charge + delta, SHOVE_CHARGE_TIME)
	if _lunge_cooldown_left > 0.0:
		_lunge_cooldown_left = maxf(0.0, _lunge_cooldown_left - delta)
	if _punch_cooldown_left > 0.0:
		_punch_cooldown_left = maxf(0.0, _punch_cooldown_left - delta)
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
		_step_punch(delta)
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


func _role_speed_scale() -> float:
	return 1.0 if is_defender else ATTACKER_SPEED_SCALE

func _step_stamina(delta: float, moving: bool) -> float:
	if _fatigue_left > 0.0:
		_is_sprinting = false
		_stamina_idle += delta
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

func _step_shove(_delta: float) -> void:
	if is_defender:
		return
	if _carrier != null and _carrier.is_busy():
		_cancel_shove()
		return
	if _shove_cooldown_left > 0.0 or not input_just_pressed("grab"):
		return
	if _stamina < SHOVE_STAMINA_COST or _fatigue_left > 0.0:
		return
	_broadcast_shove_charge(true)
	_release_shove()
	_broadcast_shove_charge(false)

func _step_punch(_delta: float) -> void:
	if not is_defender:
		return
	if _punch_cooldown_left > 0.0:
		return
	if _carrier != null and _carrier.is_busy():
		return
	if not input_just_pressed("special_ability"):
		return
	_punch_cooldown_left = PUNCH_COOLDOWN
	broadcast_visual_action("punch")
	AudioManager.play_at("bump_swing", global_position)
	if not NetworkManager.is_networked() or NetworkManager.is_host():
		host_resolve_punch(player_slot, global_position, -global_transform.basis.z)
	else:
		_rpc_request_punch.rpc_id(1, global_position, -global_transform.basis.z)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_punch(from: Vector3, facing: Vector3) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	host_resolve_punch(player_slot, from, facing)

func host_resolve_punch(puncher_slot: int, from: Vector3, facing: Vector3) -> void:
	if not RoundManager.round_active:
		return
	var lata := RoundManager.lata
	if lata == null or not lata.is_upright:
		return
	var flat_facing := Vector3(facing.x, 0.0, facing.z)
	if flat_facing.length() < 0.01:
		return
	flat_facing = flat_facing.normalized()
	var taya := RoundManager.player_at(puncher_slot)
	if taya == null:
		return
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null or who.player_slot == puncher_slot or who.is_defender:
			continue
		if not who.is_taggable():
			continue
		var to_them := who.global_position - from
		to_them.y = 0.0
		var distance := to_them.length()
		if distance > PUNCH_RANGE or distance < 0.01:
			continue
		if rad_to_deg(flat_facing.angle_to(to_them.normalized())) > PUNCH_ARC_DEG:
			continue
		RoundManager.host_resolve_lunge_tag(taya, who)
		return

func punch_cooldown_left() -> float:
	return _punch_cooldown_left

func _step_lunge(delta: float) -> void:
	if not is_defender:
		_cancel_lunge()
		return
	if _lunge_active_left > 0.0:
		_lunge_active_left = maxf(0.0, _lunge_active_left - delta)
		if not NetworkManager.is_networked() or NetworkManager.is_host():
			_sweep_lunge_tag()
	if _carrier != null and _carrier.is_busy():
		_cancel_lunge()
		return
	if _lunge_charging:
		if _lunge_held_now():
			_lunge_charge = minf(_lunge_charge + delta, LUNGE_CHARGE_TIME)
			return
		var power := clampf(_lunge_charge / LUNGE_CHARGE_TIME, LUNGE_MIN_POWER, 1.0)
		_cancel_lunge()
		_release_lunge(power)
		return
	if _lunge_cooldown_left > 0.0 or not _lunge_pressed_now():
		return
	if state != State.NORMAL:
		return
	_lunge_charging = true
	_lunge_charge = 0.0
	_broadcast_lunge_charge(true)

func _lunge_pressed_now() -> bool:
	return input_just_pressed("lunge")


func _lunge_held_now() -> bool:
	return input_pressed("lunge")


func _cancel_lunge() -> void:
	if not _lunge_charging:
		return
	_lunge_charging = false
	_lunge_charge = 0.0
	_broadcast_lunge_charge(false)

func _release_lunge(power: float) -> void:
	_lunge_cooldown_left = LUNGE_COOLDOWN
	_lunge_active_left = LUNGE_ACTIVE_TIME
	broadcast_visual_action("lunge")
	AudioManager.play_at("bump_swing", global_position)
	var forward := -global_transform.basis.z
	velocity.x = forward.x * LUNGE_SPEED * power
	velocity.z = forward.z * LUNGE_SPEED * power
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		_rpc_request_lunge.rpc_id(1, global_position, forward, power)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_lunge(from: Vector3, facing: Vector3, power: float) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	host_resolve_lunge(player_slot, from, facing, power)

func host_resolve_lunge(taya_slot: int, from: Vector3, facing: Vector3, power: float) -> void:
	if not RoundManager.round_active:
		return
	var lata := RoundManager.lata
	if lata == null or not lata.is_upright:
		return
	var taya := RoundManager.player_at(taya_slot)
	if taya == null or not taya.is_defender:
		return
	var flat_facing := Vector3(facing.x, 0.0, facing.z)
	if flat_facing.length() < 0.01:
		return
	flat_facing = flat_facing.normalized()
	var speed := LUNGE_SPEED * clampf(power, LUNGE_MIN_POWER, 1.0)
	var dash := (speed * speed) / (2.0 * FRICTION)
	var start := Vector3(from.x, 0.0, from.z)
	var end := start + flat_facing * dash
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null or who.player_slot == taya_slot or who.is_defender:
			continue
		if not who.is_taggable():
			continue
		var them := Vector3(who.global_position.x, 0.0, who.global_position.z)
		if Geometry3D.get_closest_point_to_segment(them, start, end).distance_to(them) \
			> LUNGE_TAG_RADIUS:
			continue
		RoundManager.host_resolve_lunge_tag(taya, who)
		return

func _sweep_lunge_tag() -> void:
	if not RoundManager.round_active:
		return
	var lata := RoundManager.lata
	if lata == null or not lata.is_upright:
		return
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
		return

func _broadcast_lunge_charge(active: bool) -> void:
	if NetworkManager.is_networked():
		_rpc_lunge_charge_visual.rpc(active)
	else:
		_rpc_lunge_charge_visual(active)

@rpc("any_peer", "call_local", "reliable")
func _rpc_lunge_charge_visual(active: bool) -> void:
	_observed_lunge_charge = 0.0 if active else -1.0

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
	_shove_cooldown_left = SHOVE_MISS_COOLDOWN
	broadcast_visual_action("shove")
	AudioManager.play_at("bump_swing", global_position)
	if not NetworkManager.is_networked() or NetworkManager.is_host():
		host_resolve_shove(player_slot, global_position, -global_transform.basis.z)
	else:
		_rpc_request_shove.rpc_id(1, global_position, -global_transform.basis.z)

func host_start_shove_cooldown() -> void:
	RoundManager.host_broadcast_shove_cooldown(player_slot)

func apply_shove_cooldown_local() -> void:
	_apply_shove_cooldown()

func _apply_shove_cooldown() -> void:
	_shove_cooldown_left = maxf(_shove_cooldown_left, SHOVE_COOLDOWN)

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
	var connected := false
	for node in RoundManager.players():
		var who := node as CharacterBase
		if who == null or who.player_slot == shover_slot or who.is_defender:
			continue
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
		connected = true
	if connected:
		var shover := RoundManager.player_at(shover_slot)
		if shover != null:
			shover.host_start_shove_cooldown()

func host_apply_shove(impulse: Vector3, stun: float, from_slot: int) -> void:
	RoundManager.note_shove(player_slot, from_slot)
	RoundManager.host_broadcast_shove(player_slot, impulse, stun)

func apply_shove_local(impulse: Vector3, stun: float) -> void:
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

func shove_charge_ratio() -> float:
	if not _shove_charging:
		return -1.0
	return clampf(_shove_charge / SHOVE_CHARGE_TIME, 0.0, 1.0)

func observed_shove_charge() -> float:
	if _observed_shove_charge < 0.0:
		return -1.0
	return clampf(_observed_shove_charge / SHOVE_CHARGE_TIME, 0.0, 1.0)

func host_apply_block(impulse: Vector3) -> void:
	RoundManager.host_broadcast_block(player_slot, impulse)

func apply_block_local(impulse: Vector3) -> void:
	_apply_block(impulse)

func _apply_block(impulse: Vector3) -> void:
	apply_knockback(impulse)
	_visual.flash_hit()
	var is_mine := (is_multiplayer_authority() and ai_controller == null) \
		if NetworkManager.is_networked() else player_id == 1
	if is_mine and _camera_rig != null:
		_camera_rig.shake()


func host_apply_tag_penalty(stun: float) -> void:
	RoundManager.host_broadcast_tag_penalty(player_slot, stun, spawn_position)

func apply_tag_penalty_local(stun: float, safe_spot: Vector3) -> void:
	_apply_tag_penalty(stun, safe_spot)

func _apply_tag_penalty(stun: float, safe_spot: Vector3) -> void:
	global_position = safe_spot
	velocity = Vector3.ZERO
	begin_spawn_settle()
	snap_visual_interpolation()
	apply_stagger(stun)
	if _fatigue_left > 0.0:
		_fatigue_left = 0.0
		exit_speed_zone(FATIGUE_SPEED_SCALE)
	_stamina = STAMINA_MAX
	_stamina_idle = 0.0
	_is_sprinting = false
	AudioManager.play_at("tag", global_position)


func apply_stagger(duration: float = BASE_STAGGER_TIME) -> void:
	if state == State.DOWNED:
		return
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

func stagger_time_left() -> float:
	return _staggered_time_left

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
	if is_taggable():
		out.append({"label": "VULNERABLE", "seconds": 0.0, "total": 1.0})
	if _shove_cooldown_left > 0.0:
		out.append({"label": "SHOVE CD", "seconds": _shove_cooldown_left,
			"total": SHOVE_COOLDOWN})
	if _lunge_cooldown_left > 0.0:
		out.append({"label": "LUNGE CD", "seconds": _lunge_cooldown_left,
			"total": LUNGE_COOLDOWN})
	if RoundManager.throw_cooldown_left() > 0.0 and not is_defender:
		out.append({"label": "THROW CD", "seconds": RoundManager.throw_cooldown_left(),
			"total": RoundManagerScript.THROW_RESTORE_COOLDOWN})
	return out


func _flash_hit(sfx: String = "") -> void:
	_visual.flash_hit()
	if sfx != "":
		AudioManager.play_at(sfx, global_position)
	_hitstop()
	var is_mine := (is_multiplayer_authority() and ai_controller == null) \
		if NetworkManager.is_networked() else player_id == 1
	if is_mine and _camera_rig != null:
		_camera_rig.shake()

static var _hitstop_until_msec: int = 0

func _hitstop() -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	_hitstop_restore_scale = Engine.time_scale
	_hitstop_until_msec = Time.get_ticks_msec() + int(HITSTOP_DURATION * 1000.0)
	Engine.time_scale = HITSTOP_TIME_SCALE

static func _step_hitstop() -> void:
	if not _hitstop_active or Time.get_ticks_msec() < _hitstop_until_msec:
		return
	_end_hitstop()

static func _end_hitstop() -> void:
	if not _hitstop_active:
		return
	Engine.time_scale = _hitstop_restore_scale
	_hitstop_active = false

func _exit_tree() -> void:
	_end_hitstop()

func _on_state_changed_audio(new_state: State) -> void:
	match new_state:
		State.DOWNED:
			AudioManager.play_at("downed", global_position)
		State.NORMAL, State.STAGGERED:
			pass
	_audio_prev_state = new_state

var _ai_intent: Dictionary = {}
var _ai_intent_prev: Dictionary = {}
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


func get_hand_attachment() -> Node3D:
	return _visual.get_hand_attachment()

func play_visual_action(kind: String) -> void:
	_visual.play_action(kind)
	var rig := get_node_or_null("CameraRig") as CameraRig
	if rig != null:
		rig.play_viewmodel_action(kind)


func can_emote() -> bool:
	return state == State.NORMAL and not _visual.is_emoting()

func is_emoting() -> bool:
	return _visual.is_emoting()

func try_emote(id: String) -> void:
	var is_mine := is_multiplayer_authority() if NetworkManager.is_networked() else player_id == 1
	if not is_mine or not can_emote():
		return
	broadcast_emote(id)

func broadcast_emote(id: String) -> void:
	if NetworkManager.is_networked():
		_rpc_emote.rpc(id)
	else:
		play_emote(id)

@rpc("any_peer", "call_local", "reliable")
func _rpc_emote(id: String) -> void:
	play_emote(id)

func play_emote(id: String) -> void:
	if not _visual.play_emote(id):
		return
	var is_mine := is_multiplayer_authority() if NetworkManager.is_networked() else player_id == 1
	if not is_mine:
		return
	var rig := get_node_or_null("CameraRig") as CameraRig
	if rig != null:
		rig.begin_emote_view()

func stop_emote() -> void:
	if not _visual.is_emoting():
		return
	if NetworkManager.is_networked():
		_rpc_stop_emote.rpc()
	else:
		_apply_stop_emote()

@rpc("any_peer", "call_local", "reliable")
func _rpc_stop_emote() -> void:
	_apply_stop_emote()

func _apply_stop_emote() -> void:
	_visual.stop_emote()
	_restore_emote_camera()

func _restore_emote_camera() -> void:
	var is_mine := is_multiplayer_authority() if NetworkManager.is_networked() else player_id == 1
	if not is_mine:
		return
	var rig := get_node_or_null("CameraRig") as CameraRig
	if rig != null:
		rig.end_emote_view()

func _cancel_emote_on_input() -> void:
	if not _visual.is_emoting():
		return
	var is_mine := is_multiplayer_authority() if NetworkManager.is_networked() else player_id == 1
	if not is_mine:
		return
	if (input_pressed("move_left") or input_pressed("move_right")
			or input_pressed("move_up") or input_pressed("move_down")
			or input_just_pressed("jump") or input_just_pressed("sprint")
			or input_just_pressed("grab") or input_just_pressed("special_ability")):
		stop_emote()

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


func respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	begin_spawn_settle()
	snap_visual_interpolation()
	AudioManager.play_at("respawn", global_position)
	_was_airborne = false
	_fall_speed = 0.0

func reset_for_new_round() -> void:
	if _pick_repaint_pending:
		_pick_repaint_pending = false
		if _visual != null and is_instance_valid(_visual):
			_visual.apply(is_person, is_can, player_slot)
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
	if was_state == State.NORMAL:
		state_changed.emit(state)
	if _carrier != null:
		_carrier.reset_for_new_round()
	_visual.apply(is_person, is_can, player_slot)

