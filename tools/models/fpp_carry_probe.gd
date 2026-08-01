extends Node
## CAN THE LOCAL PLAYER SEE THE SLIPPER IN THEIR OWN HANDS?
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/models/fpp_carry_probe.tscn -- out=C:/tmp/
##
## ⚠️ RUN IT WITH THE PLAIN EXE — it renders, and `--headless` has no rendering
## device.
##
## 🧑 2026-08-01, from play: *"slipper model can be seen but it doesnt get seen
## in first person"*.
##
## ⚠️ `carry_shot.tscn` CANNOT ANSWER THIS AND ITS OWN HEADER SAYS SO. It kills
## every camera in the tree and photographs the hand from OUTSIDE, precisely to
## avoid the viewmodel — so it measures the world slipper, which is the half that
## already works. First person is a different object entirely: `camera_rig.gd`
## HIDES the world slipper for the local peer (`_apply_carried_self_hide`) and
## shows `RightPivot/Arm/HeldSlipper` inside `ViewmodelArms.tscn` instead. If that
## one node is wrong, the player's own hands are empty while everybody else sees
## the slipper — exactly what was reported.
##
## So this reports the five things that can each independently produce an empty
## hand, rather than one pass/fail:
##
##   1. is the viewmodel there and visible at all;
##   2. is `HeldSlipper` visible;
##   3. does it carry a mesh, and WHICH — it is hardcoded in the .tscn and does
##      not follow the roster pick;
##   4. how big is it on screen after the viewmodel's two nested scales;
##   5. is it actually inside the camera frustum.
##
## 5 is the one no screenshot explains: a node can be visible, meshed and
## correctly sized while sitting behind the near plane or off the bottom of the
## frame, and that reads as "it isn't rendering".

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

var _out: String = ""
var _main: Node = null
var _log: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("out="):
			_out = text.substr(4)
		elif text.begins_with("slipper="):
			# The whole point of `slipper=` is checking that the hands hold what
			# the CHARACTER screen picked, so it is set the same way that screen
			# sets it — `GameLaunch.selected_slipper`, before the match loads.
			GameLaunch.selected_slipper = StringName(text.substr(8))
	if _out == "":
		_out = ProjectSettings.globalize_path("user://")
	# ⚠️ SEAT 1, NOT 0, AND THAT IS FORCED BY THE RULES. Round 1's taya is always
	# slot 0 (`MatchManager.defender_slot_for(1)`), the taya owns no slipper, and
	# a slipper belongs to exactly one attacker (`Design.md` §5.2) — so a probe
	# seated at 0 can never get a slipper into its own hand and the first run of
	# this file failed with exactly that. Set BEFORE `Main.tscn` is instantiated:
	# `_start_local_test()` reads it during `_ready()`.
	GameLaunch.solo_seat = 1
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("seat="):
			GameLaunch.solo_seat = int(text.substr(5))
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_run.call_deferred()


func _emit(text: String) -> void:
	print(text)
	_log.append(text)


func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	if _main.has_method("_run_ready_countdown"):
		_main._run_ready_countdown()
	await get_tree().create_timer(4.5).timeout

	var local := _local_character()
	if local == null:
		_emit("[fpp] NO LOCAL CHARACTER — cannot test first person")
		_finish(1)
		return
	var rig := local.get_node_or_null("CameraRig") as CameraRig
	if rig == null:
		_emit("[fpp] local character has no CameraRig")
		_finish(1)
		return
	_emit("[fpp] local = %s  (defender: %s)" % [local.display_name(), local.is_defender])

	# ⚠️ THE LOCAL SEAT IS THE TAYA IN ROUND 1 AND THE TAYA NEVER HOLDS A SLIPPER.
	# `harrydaks_shot` has the same problem and it is why the slipper glow was
	# never seen either (§ CHECKLIST 2.20). So the slipper is PUT in the hand
	# here rather than waited for.
	var slipper := _give_slipper(local)
	if slipper == null:
		_emit("[fpp] could not put a slipper in the local player's hand")
		# The reason matters — ownership, state and distance are three different
		# refusals and they need telling apart.
		for node in _main.find_children("*", "Node3D", true, false):
			var each := node as Slipper
			if each == null:
				continue
			_emit("[fpp]   %s owner_slot=%d state=%d carrier=%s grabbable=%s d=%.2f"
				% [each.name, each.owner_slot, each.state,
					each.carrier != null, each.can_be_grabbed_by(local),
					local.global_position.distance_to(each.global_position)])
		_finish(1)
		return
	# Let the carry pose settle — `_update_viewmodel_carry` interpolates towards
	# it at VIEWMODEL_REACH_SPEED rather than snapping.
	await get_tree().create_timer(1.5).timeout

	_report(local, rig, slipper)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _out + "fpp_carry.png"
	_emit("[fpp] frame -> %s" % (path if image.save_png(path) == OK else "FAILED"))
	_finish(0)


func _report(local: CharacterBase, rig: CameraRig, slipper: Node3D) -> void:
	var carrier := local.get_node_or_null("Carrier") as Carrier
	_emit("[fpp] carrier.held() = %s" % ("null" if carrier == null or carrier.held() == null
		else String(carrier.held().name)))

	var arms: Node3D = rig.call("_viewmodel_arms") as Node3D
	if arms == null:
		_emit("[fpp] 1 viewmodel arms      : ABSENT — the rig built none")
		return
	_emit("[fpp] 1 viewmodel arms      : visible=%s  scale=%.3f" % [arms.visible, arms.scale.x])

	var held := arms.get_node_or_null("RightPivot/Arm/HeldSlipper") as MeshInstance3D
	if held == null:
		_emit("[fpp] 2 HeldSlipper         : NODE MISSING from ViewmodelArms.tscn")
		return
	_emit("[fpp] 2 HeldSlipper         : visible=%s  visible_in_tree=%s"
		% [held.visible, held.is_visible_in_tree()])

	if held.mesh == null:
		_emit("[fpp] 3 HeldSlipper mesh    : NONE")
		return
	_emit("[fpp] 3 HeldSlipper mesh    : %s" % held.mesh.resource_path.get_file())

	# The on-screen size after ViewmodelArms' own 0.72 and the carry pose's 0.55.
	var box := held.mesh.get_aabb()
	var world_scale := held.global_transform.basis.get_scale()
	_emit("[fpp] 4 size                : mesh L %.3f -> world L %.3f  (scale %.3f)"
		% [box.size.z, box.size.z * world_scale.z, world_scale.z])

	# 5 — the one a picture cannot explain.
	var camera: Camera3D = null
	for node in rig.find_children("*", "Camera3D", true, false):
		if (node as Camera3D).current:
			camera = node as Camera3D
			break
	if camera == null:
		_emit("[fpp] 5 frustum             : no current camera on this rig")
		return
	var centre := held.global_transform * box.get_center()
	var local_point := camera.global_transform.affine_inverse() * centre
	var on_screen := camera.is_position_in_frustum(centre)
	var behind := local_point.z > 0.0
	_emit("[fpp] 5 frustum             : in_frustum=%s  behind_camera=%s  depth=%.3f m"
		% [on_screen, behind, -local_point.z])
	_emit("[fpp]   camera %s   slipper %s   world slipper %s"
		% [camera.global_position, centre, slipper.global_position])
	if not on_screen:
		var uv := camera.unproject_position(centre)
		_emit("[fpp]   unprojects to %s in a %s viewport — OFF SCREEN"
			% [uv, get_viewport().get_visible_rect().size])


## Finds the character this machine is actually looking through.
func _local_character() -> CharacterBase:
	for node in _main.find_children("*", "CharacterBase", true, false):
		var who := node as CharacterBase
		if who == null:
			continue
		var rig := who.get_node_or_null("CameraRig") as CameraRig
		if rig == null:
			continue
		for cam in rig.find_children("*", "Camera3D", true, false):
			if (cam as Camera3D).current:
				return who
	return null


## Puts a loose slipper in `who`'s hand through the ordinary carrier path, so
## every signal the real pickup fires (`held_changed`, which is what drives the
## self-hide) fires here too. A probe that assigned the field directly would
## skip exactly the code under test.
func _give_slipper(who: CharacterBase) -> Node3D:
	var carrier := who.get_node_or_null("Carrier") as Carrier
	if carrier == null:
		return null
	if carrier.held() != null:
		return carrier.held()
	for node in _main.find_children("*", "Node3D", true, false):
		var slipper := node as Slipper
		if slipper == null or slipper.carrier != null:
			continue
		# ⚠️ ASK THE GAME'S OWN PREDICATE, do not re-derive the rule. Ownership is
		# real (`Design.md` §5.2) and the first version of this filter compared
		# `owner_slot` to `player_slot` by hand — which rejected the local
		# player's OWN slipper, because it is spawned carrying `owner_slot = -1`
		# and only `can_be_grabbed_by()` knows that is legal.
		if not slipper.can_be_grabbed_by(who):
			continue
		# Stand on top of it so the ordinary radius check accepts the grab.
		who.global_position = slipper.global_position + Vector3.UP * 0.2
		carrier.call("_request_grab", slipper)
		break
	return carrier.held()


func _finish(code: int) -> void:
	var file := FileAccess.open("user://fpp_carry_probe.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log) + "\n")
		file.close()
	get_tree().quit(code)
