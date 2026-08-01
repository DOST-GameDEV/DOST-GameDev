extends Node

## Photographs THE PLAY AREA — the chalk box, the throwing lines and the court —
## from above, on both maps.
##
##     Godot_v4.7.1-stable_win64.exe --path <repo> tools/maps/court_shot.tscn -- <out_dir>
##
## ⚠️ RUN IT WITH THE PLAIN EXE. `--headless` has no rendering device and every
## capture comes back blank — the same rule `harrydaks_shot.gd` states.
##
## WHY THIS EXISTS RATHER THAN REUSING `harrydaks_shot.tscn`. That one films a
## LIVE MATCH from a player's own camera, which is the right tool for judging the
## HUD and the props in play and the wrong one for judging a floor plan: from eye
## height the far end of the court is twenty pixels tall and the chalk box's shape
## is pure guesswork. `build model` § 5.1 widened the Defender's Box from 5.0 to
## 6.5 and had to redraw the chalk on both maps to match, and "did the box and the
## throwing line actually move, and do they still line up" is a question only a
## plan view answers.
##
## It drives `Main.tscn` exactly as the match does — the maps are emitted wholesale
## by `tools/maps/build_*.py` and the chalk is derived from
## `CharacterBase.CONFINEMENT_RADIUS`, so photographing the real scene is the only
## capture that proves the whole chain rather than the builder's intent.

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

## How high the camera sits and how much of the world it takes in. Orthogonal
## rather than perspective on purpose: a perspective plan view foreshortens the
## far end of the court, so the two throwing lines measure differently on screen
## even when they are symmetric, which is exactly the error being checked for.
const CAMERA_HEIGHT: float = 34.0
const ORTHO_SIZE: float = 30.0
## A slight tilt off straight-down. Dead vertical renders every upright object as
## its own footprint and the arena reads as a flat diagram — enough tilt to keep
## the lata, the players and the sari-sari store legible as objects, not enough to
## hide a court edge behind a roofline.
const TILT_DEG: float = 68.0

var _out := "res://"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	# ⚠️ SECOND ARGUMENT PICKS THE MAP, and it is additive — omit it and this
	# behaves exactly as before, photographing whatever `GameLaunch` defaults to.
	# Added 2026-08-01 because "show me the other map" had no answer: this harness
	# could only ever photograph one of the two, which is half a floor-plan review.
	# ⚠️ It sets `GameLaunch.selected_map` BEFORE instancing, because `main.gd`
	# resolves the scene through `selected_map_scene()` at `_ready()`.
	if args.size() > 1:
		GameLaunch.selected_map = StringName(String(args[1]).to_lower())
	print("[court] map=%s" % GameLaunch.selected_map)
	add_child(MAIN_SCENE.instantiate())
	_run.call_deferred()

func _run() -> void:
	# The map is instanced and the four seats settle over the first few frames;
	# `SPAWN_SETTLE_FRAMES` alone is three physics frames.
	await get_tree().create_timer(2.0).timeout
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = ORTHO_SIZE
	camera.far = 200.0
	add_child(camera)
	var tilt := deg_to_rad(TILT_DEG)
	camera.global_position = Vector3(0.0, CAMERA_HEIGHT, CAMERA_HEIGHT / tan(tilt))
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true
	# Report the numbers the picture is meant to prove, so a reader does not have
	# to measure pixels to check the chalk agrees with the code.
	print("[court] CONFINEMENT_RADIUS=%.2f  spawn_ring=%.2f  throwing_line=%.2f"
		% [CharacterBase.CONFINEMENT_RADIUS,
			CharacterBase.CONFINEMENT_RADIUS + 2.0,
			CharacterBase.CONFINEMENT_RADIUS + 1.0])
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(_out + "court.png")
	print("[court] wrote %s (%dx%d)" % [
		_out + "court.png" if err == OK else "FAILED",
		image.get_width(), image.get_height()])
	get_tree().quit()
