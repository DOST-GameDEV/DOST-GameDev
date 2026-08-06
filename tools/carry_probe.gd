extends Node3D

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

const PALM_Y_MIN: float = -0.45
const PALM_Y_MAX: float = 0.25
const PALM_SIDE_MIN: float = 0.0

var _out := "res://"
var _main: Node = null
var _failures: Array[String] = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	GameLaunch.spectator = true
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	if _main.has_method("_run_ready_countdown"):
		_main._run_ready_countdown()
	await get_tree().create_timer(5.5).timeout

	print("\n========== CARRY PROBE — is the slipper in the hand? ==========")
	var carriers: Array = []
	for node in get_tree().current_scene.find_children("*", "Slipper", true, false):
		var slipper := node as Slipper
		if slipper.state != Slipper.CarryState.CARRIED:
			continue
		var who := slipper.carrier
		if who == null or not is_instance_valid(who):
			continue
		carriers.append(who)
		_check(slipper, who)
	if carriers.is_empty():
		_failures.append("HARNESS: nobody was carrying a slipper — nothing was measured.")
	else:
		for i in carriers.size():
			_frame(carriers[i])
			await get_tree().process_frame
			await get_tree().process_frame
			await _capture("carry_%d" % [(carriers[i] as CharacterBase).player_slot])
	_report()
	get_tree().quit()

func _check(slipper: Slipper, who: CharacterBase) -> void:
	var hand := who.get_hand_attachment()
	var label := "%s seat %d" % [who.display_name(), who.player_slot]
	if hand == null:
		_failures.append("%s: no hand attachment at all — the slipper is riding the body."
			% label)
		print("%-28s NO HAND ATTACHMENT" % label)
		return
	var parented := slipper.get_parent() == hand
	if not parented:
		_failures.append("%s: slipper is not parented to the hand (it is on '%s')."
			% [label, slipper.get_parent().name if slipper.get_parent() != null else "<none>"])

	var b := hand.global_transform.basis.orthonormalized()
	var to_char := who.global_transform.affine_inverse()
	var shoulder: Vector3 = to_char * hand.get_parent().global_position
	var point: Vector3 = to_char * hand.global_position
	print("%-28s up-axis y %+.2f · shoulder (%+.2f,%+.2f,%+.2f) · carry point (%+.2f,%+.2f,%+.2f) · reach %.3f m"
		% [label, b.y.dot(Vector3.UP), shoulder.x, shoulder.y, shoulder.z,
			point.x, point.y, point.z, (point - shoulder).length()])
	var local: Vector3 = who.global_transform.affine_inverse() * slipper.global_position
	var side := absf(local.x)
	var ok := local.y >= PALM_Y_MIN and local.y <= PALM_Y_MAX and side >= PALM_SIDE_MIN
	print("%-28s slipper at character-local (%+.3f, %+.3f, %+.3f)  side %.3f  %s"
		% [label, local.x, local.y, local.z, side, "OK" if ok and parented else "FAIL"])
	if not ok:
		_failures.append(("%s: palm at local y %+.3f, side %.3f — outside the band "
			+ "(y %.2f..%.2f, side >= %.2f). y above the band is the chest/head; "
			+ "side below it is the body's centre line.")
			% [label, local.y, side, PALM_Y_MIN, PALM_Y_MAX, PALM_SIDE_MIN])

func _frame(who: CharacterBase) -> void:
	for node in get_tree().root.find_children("*", "Camera3D", true, false):
		(node as Camera3D).current = false
	for node in get_tree().root.find_children("*", "SpectatorCamera", true, false):
		(node as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	var basis := who.global_transform.basis
	camera.global_position = who.global_position + basis.x * 3.4 + Vector3.UP * 0.5 \
		- basis.z * 1.1
	camera.look_at(who.global_position, Vector3.UP)
	camera.fov = 55.0

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out, name]
	image.save_png(path)
	print("saved %s" % path)

func _report() -> void:
	print("---------------------------------------------------------------")
	if _failures.is_empty():
		print("RESULT: PASS — every carried slipper is parented to a hand and sits in it.")
	else:
		print("RESULT: FAIL")
		for line in _failures:
			print("  · %s" % line)
	print("===============================================================\n")

