extends Node3D

const DEFAULT_OUT := "res://"

var _frames := 0
var _mode := "viewmodel"
var _out := DEFAULT_OUT
var _side_cam: Camera3D = null

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_mode = args[0]
	if args.size() > 1:
		_out = args[1]
	if _mode == "match":
		_build_match()
	elif _mode == "round2":
		_build_match()
	elif _mode == "canwatch":
		_build_match()
	elif _mode == "setup":
		_build_setup()
	else:
		_build_viewmodel()

var _setup: Control = null

func _build_setup() -> void:
	GameLaunch.pending_action = "local"
	_setup = (load("res://scenes/ui/MatchSetup.tscn") as PackedScene).instantiate()
	add_child(_setup)

func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(_out + name + ".png")
	print("[render_probe] ", _out, name, ".png -> ", err)


func _build_match() -> void:
	GameLaunch.pending_action = "local"
	add_child((load("res://scenes/main/Main.tscn") as PackedScene).instantiate())


func _build_viewmodel() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.53, 0.73, 0.9)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.75
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	add_child(sun)

	var ground := StaticBody3D.new()
	var body_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	body_shape.shape = box
	ground.add_child(body_shape)
	var ground_mesh := MeshInstance3D.new()
	var ground_box := BoxMesh.new()
	ground_box.size = Vector3(40, 1, 40)
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.72, 0.70, 0.66)
	ground_box.material = ground_mat
	ground_mesh.mesh = ground_box
	ground.add_child(ground_mesh)
	add_child(ground)
	ground.position = Vector3(0, -0.5, 0)

	var scene := load("res://scenes/characters/CharacterBase.tscn") as PackedScene
	add_child(_unit(scene, "P", true, false, 0, 1, Vector3(0, 0.8, 0)))
	var slipper := (load("res://scenes/objects/Slipper.tscn") as PackedScene).instantiate() as Slipper
	slipper.name = "S"
	slipper.position = Vector3(1.5, 0.8, 0)
	add_child(slipper)
	var can := (load("res://scenes/objects/Lata.tscn") as PackedScene).instantiate() as Lata
	can.name = "C"
	can.position = Vector3(0, 0.8, -4.0)
	add_child(can)

	_side_cam = Camera3D.new()
	_side_cam.fov = 45.0
	add_child(_side_cam)

func _unit(scene: PackedScene, id: String, is_person: bool, is_can: bool,
		team: int, player_id: int, where: Vector3) -> CharacterBase:
	var unit := scene.instantiate() as CharacterBase
	unit.name = id
	unit.is_person = is_person
	unit.is_can = is_can
	unit.team = team
	unit.player_id = player_id
	unit.position = where
	return unit


func _process(_delta: float) -> void:
	_frames += 1
	if _mode == "canwatch":
		_canwatch()
		return
	if _mode == "match":
		if _frames == 120:
			_shot("match_fpp")
			get_tree().quit()
		return

	if _mode == "round2":
		if _frames == 5:
			MatchManager.begin_next_round()
		if _frames == 20:
			_dump_positions("ROUND 1 (frame 20)")
		if _frames == 30:
			RoundManager.report_round_win(true)
		if _frames == 50:
			_dump_positions("ROUND 2, after report_round_result (frame 50)")
		if _frames == 70:
			MatchManager.begin_next_round()
		if _frames == 90:
			_dump_positions("ROUND 2, after begin_next_round (frame 90)")
			_shot("round2_fpp")
			get_tree().quit()
		return

	if _mode == "setup":
		if _frames == 30:
			var primary := _setup.get_node("%PrimaryButton") as Button
			print("[render_probe] setup: solo START disabled on arrival = ",
				primary.disabled)
			print("[render_probe] setup: solo seat on arrival = ", GameLaunch.solo_seat)
			_shot("setup_solo_seat0")
		if _frames == 45:
			(_setup.get_node("%SeatButton3") as BaseButton).pressed.emit()
		if _frames == 60:
			print("[render_probe] setup: solo seat after clicking Team B Prop = ",
				GameLaunch.solo_seat)
			_shot("setup_solo_seat3")
			get_tree().quit()
		return

	if _frames == 20:
		(get_node("S") as Slipper).host_grab(get_node("P") as CharacterBase)
	if _frames == 50:
		(get_node("P/CameraRig") as CameraRig).set_active(true)
	if _frames == 70:
		_report()
		_shot("viewmodel_fpp")
	if _frames == 75:
		(get_node("P/CameraRig") as CameraRig).set_active(false)
		(get_node("S/CameraRig") as CameraRig).set_active(true)
	if _frames == 90:
		_shot("viewmodel_slipper_tpp")
		(get_node("S/CameraRig") as CameraRig).set_active(false)
	if _frames == 95:
		(get_node("C/CameraRig") as CameraRig).set_active(true)
	if _frames == 105:
		_shot("viewmodel_can_tpp")
		(get_node("C/CameraRig") as CameraRig).set_active(false)
	if _frames == 110:
		var person := get_node("P") as CharacterBase
		_side_cam.global_position = person.global_position + Vector3(2.6, 0.55, 2.0)
		_side_cam.look_at(person.global_position + Vector3(0, -0.15, 0))
		_side_cam.current = true
	if _frames == 125:
		_shot("viewmodel_tpp")
		get_tree().quit()

var _canwatch_last: Vector3 = Vector3.INF
var _canwatch_started: bool = false

func _canwatch() -> void:
	if _frames == 5 and not _canwatch_started:
		_canwatch_started = true
		MatchManager.begin_next_round()
	if _frames == 120 or _frames == 240 or _frames == 360:
		RoundManager.report_round_win(_frames == 240)
	var can: CharacterBase = null
	for node in get_tree().get_root().find_children("*", "CharacterBase", true, false):
		var unit := node as CharacterBase
		if unit != null and unit.is_can:
			can = unit
			break
	if can == null:
		return
	var pos := can.global_position
	if _canwatch_last != Vector3.INF:
		var jump := pos.distance_to(_canwatch_last)
		if jump > 0.75:
			print("[canwatch] frame %d  JUMP %.2f  %s -> %s  round=%d active=%s" % [
				_frames, jump, _canwatch_last, pos,
				MatchManager.round_number, RoundManager.round_active])
	_canwatch_last = pos
	if _frames >= 395:
		print("[canwatch] final ", pos)
		get_tree().quit()

func _dump_positions(label: String) -> void:
	print("[render_probe] === ", label, " === round_number=", MatchManager.round_number,
		" team_a_is_can=", MatchManager.team_a_is_can)
	var main := get_node_or_null("Main")
	if main == null:
		print("[render_probe] Main not found")
		return
	for path in ["TeamAProp", "TeamAPerson", "TeamBProp", "TeamBPerson"]:
		var c := main.get_node_or_null(path) as CharacterBase
		if c == null:
			print("[render_probe] ", path, ": NOT FOUND")
			continue
		print("[render_probe] %-12s is_can=%s is_person=%s team_is_can_side=%s pos=%s" % [
			path, c.is_can, c.is_person, c.team_is_can_side, c.global_position])

func _report() -> void:
	var person := get_node("P") as CharacterBase
	var origin := person.global_position
	var visual := person.get_node("Visual") as CharacterVisual
	var model := visual.get_child(0) as Node3D
	print("[render_probe] --- Person, CharacterBase-local space ---")
	print("[render_probe] capsule spans      -0.800 .. +0.800")
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_aabb: AABB = (node as MeshInstance3D).get_aabb()
		var world: Transform3D = (node as Node3D).global_transform
		var scale_y: float = world.basis.get_scale().y
		print("[render_probe] mesh %-12s %+.3f .. %+.3f" % [
			node.name,
			world.origin.y + mesh_aabb.position.y * scale_y - origin.y,
			world.origin.y + (mesh_aabb.position.y + mesh_aabb.size.y) * scale_y - origin.y])
	var rig := person.get_node("CameraRig") as CameraRig
	print("[render_probe] FppPivot           %+.3f" % [
		(rig.get_node("FppPivot") as Node3D).global_position.y - origin.y])
	var hand := visual.get_hand_attachment()
	if hand != null:
		print("[render_probe] HandPoint          ", hand.global_transform.origin - origin)
	print("[render_probe] carried slipper    ", (get_node("S") as CharacterBase).global_position - origin)

