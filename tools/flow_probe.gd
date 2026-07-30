extends Node3D
## R-21 — turns "does this map flow" into a picture instead of an opinion.
##
##   godot --path . tools/flow_probe.tscn -- heatmap map=eskinita rounds=40 scale=8 out=C:/tmp/
##   godot --path . tools/flow_probe.tscn -- sightlines map=bayan_plaza out=C:/tmp/
##
## ⚠️ NEVER WITH `--headless`. Both modes render — the heatmap mode because a
## headless run has no rendering device and the match scene it drives would miss
## the whole B-77..B-80 class of bug, and the sightline mode obviously.
##
## TWO MODES, ONE TOOL, for the reason Checklist §9 gives about ai_probe: a second
## tool measuring the same scene is a second thing to keep in step.
##
## HEATMAP — where do the four units actually spend their time? Samples every
## unit's XZ once per second of GAME time (accumulated delta, never wall clock, so
## `scale=` does not distort the sample rate) across N AI-vs-AI rounds, then
## rasterises the density top-down. That answers the three questions R-21 asks and
## a still frame cannot: whether the retrieval walk is dead time (a bright corridor
## with nothing else in it), whether anyone uses the map's width (density hugging
## the centre line means the width is decoration), and whether the confinement
## square is the right size (the Taya's cloud either fills it or rattles inside it).
##
## ⚠️ I DO NOT OWN `tools/ai_probe.gd` — it is the BALANCE lane's file, and R-21
## says to use its heatmap hook if one exists and to build only the rendering half
## if it does. It has no heatmap mode, so the capture is here. THE HOOK BALANCE
## NEEDS IS `_sample()` BELOW: it is four lines and reads nothing but
## `CharacterBase.global_position`, so it can be lifted into ai_probe's own
## `_physics_process` verbatim and this file can then keep only `_write_heatmap()`.
##
## ⚠️ THE AI TAKEOVER IS COPIED FROM ai_probe.gd ON PURPOSE AND IS TEST-ONLY.
## Single Player leaves one seat for the human, and a flow map with one of four
## units standing still is a flow map of three units and a statue. Same reasoning,
## same flag, same one-function removal as ai_probe's own `_take_over_human_slot`.
## It is duplicated rather than shared because that file is another lane's and
## reaching into it to export a helper is a merge conflict for no gain.

const HEATMAP_PX := 320
## Half-extent of the sampled window, in world units. ONE VALUE FOR BOTH MAPS so
## the two images are directly comparable — Eskinita is 8.6 x 18 of playable space
## and the plaza is 12.5 square, and rescaling per map would make the brighter
## picture look busier rather than denser.
const HEATMAP_HALF := 20.0
const SAMPLE_INTERVAL := 1.0

var _mode := "heatmap"
var _map_id := &"eskinita"
var _out := ""
var _target_rounds := 40
var _scale := 8.0

var _main: Node
var _rounds_done := 0
var _accum := 0.0
var _samples := 0
var _finishing := false
## Flat count grid, HEATMAP_PX * HEATMAP_PX. A PackedInt32Array rather than a
## 2D structure so the write loop below is a single pass.
var _grid := PackedInt32Array()
## Sampled separately, because "where does the Taya go" and "where does an
## attacker go" are different questions and one blended cloud answers neither.
var _grid_can := PackedInt32Array()

## Sightline mode. (label, eye, look_at) — all at an FPP Person's real eye height
## of 1.25 above the ground, never a flattering angle.
##
## ⚠️ THE THREE POSITIONS ARE THE THREE QUESTIONS R-21 NAMES, not a tour:
##   attacker  — standing ON the 6.0 throwing line. Can you see the can at all?
##   taya      — the defender's blocking post beside the can, looking back up the
##               lane. Can the Taya see the attacker coming?
##   retrieval — the midpoint of the walk back, looking toward the throwing line.
##               Is that walk interesting, or is it dead time?
const SIGHTLINES := [
	["attacker_6m", Vector3(0.0, 1.35, 6.0), Vector3(0.0, 0.30, 0.0)],
	["taya_post", Vector3(2.2, 1.35, -1.5), Vector3(0.0, 1.25, 6.0)],
	["retrieval_mid", Vector3(2.5, 1.35, -3.5), Vector3(0.5, 1.25, 6.0)],
]
var _shot := 0
var _settle := 0
var _cam: Camera3D


func _ready() -> void:
	_parse_args()
	# Same reason ai_probe needs it: match_result.gd pauses the tree when a match
	# is won, and a probe at PROCESS_MODE_INHERIT then stops getting the very
	# callback that would dismiss the screen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _mode == "sightlines":
		_run_sightlines()
		return
	_grid.resize(HEATMAP_PX * HEATMAP_PX)
	_grid_can.resize(HEATMAP_PX * HEATMAP_PX)
	GameLaunch.selected_map = _map_id
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	_take_over_human_slots()
	RoundManager.round_won.connect(_on_round_won)
	MatchManager.match_won.connect(_on_match_won)
	Engine.time_scale = _scale
	MatchManager.begin_next_round()
	print("FLOW heatmap — map: %s, target rounds: %d, time_scale: %.1f"
		% [_map_id, _target_rounds, _scale])


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var t := String(arg)
		if t == "heatmap" or t == "sightlines":
			_mode = t
		elif t.begins_with("map="):
			_map_id = StringName(t.substr(4))
		elif t.begins_with("rounds="):
			_target_rounds = maxi(1, int(t.substr(7)))
		elif t.begins_with("scale="):
			_scale = maxf(1.0, float(t.substr(6)))
		elif t.begins_with("out="):
			_out = t.substr(4)
		elif not t.begins_with("-") and _out == "":
			_out = t


# =============================================================================
# HEATMAP
# =============================================================================

func _physics_process(delta: float) -> void:
	if _mode != "heatmap" or _main == null or _finishing:
		return
	# ⚠️ GAME TIME, NOT WALL CLOCK. `delta` is already scaled by time_scale, so
	# one sample per accumulated second means the sample RATE is identical at
	# scale 1 and scale 8 and the two runs are comparable. Sampling per frame
	# instead would make a fast machine look like a busier map.
	_accum += delta
	if _accum < SAMPLE_INTERVAL:
		return
	_accum -= SAMPLE_INTERVAL
	_sample()


## THE HOOK ai_probe.gd NEEDS. Four lines, reads nothing but a position and a
## role flag, no state of its own beyond the two grids.
func _sample() -> void:
	for c in _main.find_children("*", "CharacterBase", true, false):
		var body := c as Node3D
		if body == null:
			continue
		var idx := _cell(body.global_position)
		if idx < 0:
			continue
		# The Can/Taya pair is confined and everyone else is not, so they are
		# counted apart — see the _grid_can note.
		if _is_defender(c):
			_grid_can[idx] += 1
		else:
			_grid[idx] += 1
	_samples += 1


## True for the confined side. Read defensively: this probe must not fall over if
## another lane renames a role field, because a flow map that silently stops
## distinguishing the Taya is worse than no flow map.
func _is_defender(c: Node) -> bool:
	if c.has_method("is_defending"):
		return bool(c.call("is_defending"))
	for prop in ["is_can", "is_taya", "is_defence", "is_defender"]:
		if prop in c and bool(c.get(prop)):
			return true
	return false


func _cell(p: Vector3) -> int:
	var u := (p.x + HEATMAP_HALF) / (HEATMAP_HALF * 2.0)
	var v := (p.z + HEATMAP_HALF) / (HEATMAP_HALF * 2.0)
	if u < 0.0 or u >= 1.0 or v < 0.0 or v >= 1.0:
		return -1
	var px := int(u * float(HEATMAP_PX))
	var py := int(v * float(HEATMAP_PX))
	return py * HEATMAP_PX + px


func _on_round_won(_winning_team: int) -> void:
	_rounds_done += 1
	if _rounds_done >= _target_rounds:
		_finish()
		return
	await get_tree().create_timer(0.6).timeout
	if not _finishing:
		MatchManager.begin_next_round()


func _on_match_won(_team: int) -> void:
	await get_tree().create_timer(0.6).timeout
	if _finishing:
		return
	var result := _main.get_node_or_null("HUDLayer/MatchResult") as Control
	if result != null:
		result.visible = false
	get_tree().paused = false
	MatchManager.reset()
	RoundManager.reset()
	MatchManager.begin_next_round()


func _finish() -> void:
	_finishing = true
	Engine.time_scale = 1.0
	_write_heatmap()
	print("FLOW heatmap done — %s: %d rounds, %d samples"
		% [_map_id, _rounds_done, _samples])
	get_tree().quit(0)


## THE RENDERING HALF. Density -> image, with the court drawn over it so the
## picture can be read against the geometry rather than floating free.
func _write_heatmap() -> void:
	var img := Image.create(HEATMAP_PX, HEATMAP_PX, false, Image.FORMAT_RGB8)
	var peak := 1
	for i in range(_grid.size()):
		peak = maxi(peak, maxi(_grid[i], _grid_can[i]))
	# ⚠️ LOG SCALE, NOT LINEAR. Units stand still at spawns and at the can far
	# longer than anywhere else, so on a linear ramp two or three cells saturate
	# and the entire rest of the map — which is the part the question is about —
	# renders as black. Log is what makes the ROUTES visible.
	var denom: float = log(float(peak) + 1.0)
	for y in range(HEATMAP_PX):
		for x in range(HEATMAP_PX):
			var i := y * HEATMAP_PX + x
			var a: float = log(float(_grid[i]) + 1.0) / denom
			var d: float = log(float(_grid_can[i]) + 1.0) / denom
			# Attackers warm, defence cool, so an overlap reads as a third
			# colour instead of hiding one under the other.
			img.set_pixel(x, y, Color(0.06 + a * 0.94, 0.06 + d * 0.55,
				0.10 + d * 0.90))
	_draw_reference(img)
	var path := _out + "flow_heatmap_" + String(_map_id) + ".png"
	if img.save_png(path) != OK:
		push_error("flow_probe: could not write " + path)
	else:
		print("wrote ", path)


## The court, in white, so a bright patch can be located. Read from the same
## constants the builders use rather than typed: CharacterBase.CONFINEMENT_RADIUS
## is the confinement square and 6.0 is the throwing line.
func _draw_reference(img: Image) -> void:
	var r: float = CharacterBase.CONFINEMENT_RADIUS
	var white := Color(1, 1, 1)
	for t in range(-int(r * 10.0), int(r * 10.0) + 1):
		var f := float(t) * 0.1
		_plot(img, f, -r, white)
		_plot(img, f, r, white)
		_plot(img, -r, f, white)
		_plot(img, r, f, white)
	# The two throwing lines at |z| = 6.0, drawn dimmer.
	var grey := Color(0.65, 0.65, 0.65)
	for t in range(-80, 81):
		var f := float(t) * 0.1
		_plot(img, f, -6.0, grey)
		_plot(img, f, 6.0, grey)


func _plot(img: Image, wx: float, wz: float, c: Color) -> void:
	var idx := _cell(Vector3(wx, 0.0, wz))
	if idx < 0:
		return
	img.set_pixel(idx % HEATMAP_PX, idx / HEATMAP_PX, c)


# =============================================================================
# SIGHTLINES
# =============================================================================

func _run_sightlines() -> void:
	var path := "res://scenes/maps/Eskinita.tscn"
	if String(_map_id) == "bayan_plaza":
		path = "res://scenes/maps/BayanPlaza.tscn"
	add_child(load(path).instantiate())
	await get_tree().process_frame
	_cam = Camera3D.new()
	_cam.fov = 75.0
	_cam.far = 400.0
	add_child(_cam)
	_cam.current = true
	_place_shot()


func _place_shot() -> void:
	_cam.global_position = SIGHTLINES[_shot][1]
	_cam.look_at(SIGHTLINES[_shot][2], Vector3.UP)
	_settle = 30


func _process(_d: float) -> void:
	if _mode != "sightlines" or _cam == null:
		return
	if _settle > 0:
		_settle -= 1
		return
	await RenderingServer.frame_post_draw
	var name := "sight_%s_%s.png" % [_map_id, SIGHTLINES[_shot][0]]
	get_viewport().get_texture().get_image().save_png(_out + name)
	print("wrote ", name)
	_shot += 1
	if _shot >= SIGHTLINES.size():
		set_process(false)
		get_tree().quit(0)
		return
	_place_shot()


func _take_over_human_slots() -> void:
	var taken := 0
	for c in _main.find_children("*", "CharacterBase", true, false):
		if not c.is_person:
			continue
		if c.ai_controller != null and c.ai_controller.is_enabled():
			continue
		# MOVEMENT, not MOUSE — character_base.gd reads WASD in the body's frame
		# for a mouse-aimed unit (B-60) and the AI emits world-space directions.
		var rig := c.get_node_or_null("CameraRig") as CameraRig
		if rig != null:
			rig.set_aim_source(CameraRig.AimSource.MOVEMENT)
		c.input_parked = false
		if c.ai_controller != null:
			c.ai_controller.set_enabled(true)
		else:
			var controller := AIController.new()
			c.add_child(controller)
			c.ai_controller = controller
		taken += 1
	var driven := 0
	for c in _main.find_children("*", "CharacterBase", true, false):
		if c.ai_controller != null and c.ai_controller.is_enabled():
			driven += 1
	print("flow: human slots taken over: %d, units AI-driven: %d (must be 4)"
		% [taken, driven])
	if driven < 4:
		push_error("flow_probe: only %d of 4 units are AI-driven — this heatmap "
			% driven + "describes fewer units than the map has and is void.")
