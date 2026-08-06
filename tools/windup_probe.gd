extends Node3D


const ARMS_SCENE: String = "res://scenes/characters/visuals/ViewmodelArms.tscn"
const WINDUP_RAD: float = CameraRig.VIEWMODEL_WINDUP_RAD

func _ready() -> void:
	var scene := load(ARMS_SCENE) as PackedScene
	if scene == null:
		print("WINDUP: could not load %s" % ARMS_SCENE)
		get_tree().quit(1)
		return
	var arms := scene.instantiate() as Node3D
	add_child(arms)

	var player := arms.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player != null:
		player.stop()
	var arm := arms.get_node_or_null("RightPivot/Arm") as Node3D
	var fist := arms.get_node_or_null("RightPivot/Arm/HeldSlipper") as Node3D
	if arm == null or fist == null:
		print("WINDUP: RightPivot/Arm or HeldSlipper missing")
		get_tree().quit(1)
		return

	print("\n=== WIND-UP DIRECTION ===")
	print("  VIEWMODEL_WINDUP_RAD = %.3f rad (%.1f deg)" % [WINDUP_RAD, rad_to_deg(WINDUP_RAD)])
	print("  convention: +Y is UP, -Z is FORWARD (the way the player looks)\n")

	var rest := await _fist_at(arm, fist, 0.0)
	var wound := await _fist_at(arm, fist, WINDUP_RAD)
	var negated := await _fist_at(arm, fist, -WINDUP_RAD)

	print("  rest              (rotation.x = %+.3f): fist at (%+.3f, %+.3f, %+.3f)" % [0.0, rest.x, rest.y, rest.z])
	print("  positive rotation (rotation.x = %+.3f): fist at (%+.3f, %+.3f, %+.3f)" % [WINDUP_RAD, wound.x, wound.y, wound.z])
	print("  NEGATIVE rotation (rotation.x = %+.3f): fist at (%+.3f, %+.3f, %+.3f)" % [-WINDUP_RAD, negated.x, negated.y, negated.z])
	print("\n  positive moves the fist  dY = %+.3f  dZ = %+.3f" % [wound.y - rest.y, wound.z - rest.z])
	print("  NEGATIVE moves the fist  dY = %+.3f  dZ = %+.3f" % [negated.y - rest.y, negated.z - rest.z])

	var shipping_dy := negated.y - rest.y
	var ok := shipping_dy > 0.0
	print("\n  shipping code uses the NEGATIVE sign (camera_rig.gd::set_viewmodel_charge)")
	print("  VERDICT: %s" % ("PASS — that sign raises the fist by %.3f: the wind-up cocks UP and BACK" % shipping_dy
		if ok else
		"*** FAIL — the shipping sign LOWERS the fist by %.3f. The arm drops instead of cocking back. ***" % -shipping_dy))
	if not ok:
		print("  FIX: flip the sign in camera_rig.gd::set_viewmodel_charge()")
	get_tree().quit(0 if ok else 1)

func _fist_at(arm: Node3D, fist: Node3D, rot_x: float) -> Vector3:
	arm.rotation = Vector3(rot_x, 0.0, 0.0)
	await get_tree().process_frame
	return (self.global_transform.affine_inverse() * fist.global_transform).origin

