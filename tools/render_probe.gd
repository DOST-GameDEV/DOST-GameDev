extends Node3D
## A rendering harness, so visual work can be VERIFIED instead of reasoned about.
##
## Why this exists. `docs/Handoff.md` §0.8 and `docs/Dev_Plan.md` §1 both record
## the same recurring failure: code that "loads clean" and was never actually
## looked at. A `--quit` smoke test never executes a frame of `_process()`, and
## even `--quit-after N` headless never renders anything — so a camera pointing
## at the sky, a ground ring floating at chest height, or a held object parked a
## metre to the left of its carrier all pass every check this project had.
## Three of those were live on `main` simultaneously and were found by taking
## one screenshot.
##
## This is NOT debug-only code under `Dev_Plan.md` §0.3 — it is not in the
## gameplay tree, is not an autoload, ships no input actions, and nothing in
## `scripts/` references it. It lives in `tools/` next to `arena_camera.gd`,
## `regenerate_ui_theme.gd` and `models/preview.gd` for exactly that reason.
##
## USAGE
##
##   # A Person holding a tsinelas, with a lata at throwing distance.
##   # Writes viewmodel_fpp.png (first person) and viewmodel_tpp.png (side on).
##   godot --path . tools/render_probe.tscn --quit-after 400 \
##       --resolution 960x540 -- viewmodel <out-dir>
##
##   # The real match scene, shot through the local Person's own FPP camera,
##   # so the HUD is included. Writes match_fpp.png.
##   godot --path . tools/render_probe.tscn --quit-after 400 \
##       --resolution 1280x720 -- match <out-dir>
##
## `<out-dir>` must already exist and end in a slash. Omit it to write beside
## the project. Run WITHOUT `--headless`: headless has no rendering device, so
## every capture comes back blank.
##
## ⚠️ It renders; it does not judge. A screenshot proves geometry is where you
## think it is. It cannot tell you whether a charge time feels good, whether a
## crawl speed makes the retrieval scramble tense, or whether a throw arc is
## satisfying. Those still need a human on the keyboard, and an item verified
## only by this harness is `[~]`, never `[x]`.

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
	else:
		_build_viewmodel()

func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(_out + name + ".png")
	print("[render_probe] ", _out, name, ".png -> ", err)

## ---------------------------------------------------------------------------
## match — the real Main.tscn, HUD and all, through the local Person's camera.
## ---------------------------------------------------------------------------

func _build_match() -> void:
	# main.gd reads this on _ready() to pick the local four-unit harness over
	# the ENet host/join paths. Same handoff the main menu uses.
	GameLaunch.pending_action = "local"
	add_child((load("res://scenes/main/Main.tscn") as PackedScene).instantiate())

## ---------------------------------------------------------------------------
## viewmodel — an isolated Person + carried tsinelas + lata, no HUD, no match.
## ---------------------------------------------------------------------------

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
	add_child(_unit(scene, "S", false, false, 0, 3, Vector3(1.5, 0.8, 0)))
	add_child(_unit(scene, "C", false, true, 1, 4, Vector3(0, 0.8, -4.0)))

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

## ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	_frames += 1
	if _mode == "match":
		# Let main.gd spawn, let RoundManager start, let the HUD populate.
		if _frames == 120:
			_shot("match_fpp")
			get_tree().quit()
		return

	if _frames == 20:
		# The real host-side transition, not a hand-set state — host_grab() is
		# what disables the slipper's collision (_set_physics_enabled), and
		# without it the two capsules depenetrate and launch the pair skyward.
		var slipper := get_node("S") as CharacterBase
		(slipper.get_node("Carriable") as Carriable).host_grab(get_node("P") as CharacterBase)
	if _frames == 50:
		(get_node("P/CameraRig") as CameraRig).set_active(true)
	if _frames == 70:
		_report()
		_shot("viewmodel_fpp")
	if _frames == 75:
		# B-91 — the slipper's OWN TPP camera, while carried. This is the shot
		# that was actually broken: not the carrying Person's view (above), the
		# carried unit's own controlling player's view. set_active on S's rig
		# exercises exactly the carry-follow path _update_tpp_carry_follow() adds.
		(get_node("P/CameraRig") as CameraRig).set_active(false)
		(get_node("S/CameraRig") as CameraRig).set_active(true)
	if _frames == 90:
		_shot("viewmodel_slipper_tpp")
		(get_node("S/CameraRig") as CameraRig).set_active(false)
	if _frames == 95:
		# B-91 — the Can's own (never-carried) TPP camera, to confirm the mount
		# height fix generally, not just the carry-follow path above.
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

## Every number the FPP viewmodel depends on, in CharacterBase-LOCAL space, so a
## regression is a diff rather than an argument.
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
