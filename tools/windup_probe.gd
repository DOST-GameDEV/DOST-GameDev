extends Node3D

## WHICH WAY DOES THE WIND-UP ARM ACTUALLY GO? — 2026-07-29 user report:
## "i think the wind up is opposite direction? the arm goes down, not up."
##
## `camera_rig.gd::set_viewmodel_charge()` writes
## `arm.rotation.x = VIEWMODEL_WINDUP_RAD * power`, and whether a POSITIVE
## rotation about the arm's local X cocks the fist up-and-back or drops it
## down-and-forward is not readable from that line. It depends entirely on
## `RightPivot`'s basis in ViewmodelArms.tscn, which is a fully general rotation:
##
##   X (-0.90016, -0.43556,  0.00000)
##   Y (-0.30109,  0.62224, -0.72261)
##   Z ( 0.31474, -0.65046, -0.69126)
##
## ⚠️ SO THIS IS MEASURED, NOT REASONED ABOUT. B-127 is the cautionary case: the
## throw's arc tilt was sign-inverted for months behind a comment that said it
## tilted "upward", because nobody put a number on it. Reading a rotation sign off
## a basis by eye is exactly that mistake.
##
## `RightPivot/Arm/HeldSlipper` sits at arm-local (0, 0.86, 0) — it is where the
## thrown tsinelas rides, i.e. the fist. Its position in ViewmodelArms space is
## therefore the honest answer to "where did the hand go", and its Y is the
## answer to "up or down".
##
## Camera-space convention, for reading the numbers below: +Y is up, and -Z is
## FORWARD (the direction the player is looking). So a correct wind-up should
## raise Y and move Z toward zero or positive — up and BACK. Dropping Y while
## driving Z more negative is the arm falling forward, which is the report.
##
## USAGE:  godot --path . tools/windup_probe.tscn

const ARMS_SCENE: String = "res://scenes/characters/visuals/ViewmodelArms.tscn"
## Mirrors camera_rig.gd's own constant. Read from there rather than restated, so
## this cannot silently disagree with the thing it is testing.
const WINDUP_RAD: float = CameraRig.VIEWMODEL_WINDUP_RAD

func _ready() -> void:
	var scene := load(ARMS_SCENE) as PackedScene
	if scene == null:
		print("WINDUP: could not load %s" % ARMS_SCENE)
		get_tree().quit(1)
		return
	var arms := scene.instantiate() as Node3D
	add_child(arms)

	# The idle clip animates the SAME rotation the wind-up writes, so it has to be
	# stopped or it overwrites the pose between the write and the read — the same
	# trap camera_rig.gd::set_viewmodel_charge() documents and works around.
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

	# ⚠️ ASSERTS ON THE SIGN THE SHIPPING CODE USES, not merely on the geometry.
	# `camera_rig.gd::set_viewmodel_charge()` writes
	#     arm.rotation.x = -VIEWMODEL_WINDUP_RAD * power
	# so this probe passes only while the NEGATIVE rotation is the one that raises
	# the fist. If ViewmodelArms.tscn's RightPivot basis is ever re-authored, or
	# the arm mesh's axis changes, that can silently flip — and this fails and says
	# which way to go, rather than passing forever because it only measured a mesh.
	var shipping_dy := negated.y - rest.y
	var ok := shipping_dy > 0.0
	print("\n  shipping code uses the NEGATIVE sign (camera_rig.gd::set_viewmodel_charge)")
	print("  VERDICT: %s" % ("PASS — that sign raises the fist by %.3f: the wind-up cocks UP and BACK" % shipping_dy
		if ok else
		"*** FAIL — the shipping sign LOWERS the fist by %.3f. The arm drops instead of cocking back. ***" % -shipping_dy))
	if not ok:
		print("  FIX: flip the sign in camera_rig.gd::set_viewmodel_charge()")
	get_tree().quit(0 if ok else 1)

## Fist position in ViewmodelArms space at a given arm rotation. Read after a
## frame so the transform notification has actually propagated to the child.
func _fist_at(arm: Node3D, fist: Node3D, rot_x: float) -> Vector3:
	arm.rotation = Vector3(rot_x, 0.0, 0.0)
	await get_tree().process_frame
	# Relative to the ViewmodelArms root, which is what the FPP pivot parents —
	# so these are camera-space offsets, not world coordinates.
	return (self.global_transform.affine_inverse() * fist.global_transform).origin
