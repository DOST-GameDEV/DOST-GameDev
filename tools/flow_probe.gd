extends Node3D

const HEATMAP_PX := 320
const HEATMAP_HALF := 20.0
const SAMPLE_INTERVAL := 1.0

var _mode := "heatmap"
var _map_id := &"eskinita"
var _out := ""
var _target_rounds := 10
var _scale := 8.0

var _main: Node
var _rounds_done := 0
var _accum := 0.0
var _samples := 0
var _finishing := false
var _grid := PackedFloat32Array()
var _grid_can := PackedFloat32Array()

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



func _physics_process(delta: float) -> void:
	if _mode != "heatmap" or _main == null or _finishing:
		return
	Engine.time_scale = _scale
	_accum += delta
	if _accum < SAMPLE_INTERVAL:
		return
	_accum -= SAMPLE_INTERVAL
	_sample()


func _sample() -> void:
	for c in _main.find_children("*", "CharacterBase", true, false):
		var body := c as Node3D
		if body == null:
			continue
		var idx := _cell(body.global_position)
		if idx < 0:
			continue
		if _is_defender(c):
			_grid_can[idx] += 1.0
		else:
			_grid[idx] += 1.0
	_samples += 1


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


func _write_heatmap() -> void:
	var atk := _blur(_blur(_grid))
	var def := _blur(_blur(_grid_can))
	var img := Image.create(HEATMAP_PX, HEATMAP_PX, false, Image.FORMAT_RGB8)
	var pa := _peak(atk)
	var pd := _peak(def)
	for y in range(HEATMAP_PX):
		for x in range(HEATMAP_PX):
			var i := y * HEATMAP_PX + x
			var a: float = pow(atk[i] / pa, 0.45)
			var d: float = pow(def[i] / pd, 0.45)
			img.set_pixel(x, y, Color(0.04 + a * 0.96, 0.04 + d * 0.45 + a * 0.35,
				0.08 + d * 0.92))
	_draw_reference(img)
	_save(img, "flow_heatmap_" + String(_map_id))
	_save(_single(atk, pa, true), "flow_attack_" + String(_map_id))
	_save(_single(def, pd, false), "flow_defend_" + String(_map_id))


func _single(g: PackedFloat32Array, peak: float, warm: bool) -> Image:
	var img := Image.create(HEATMAP_PX, HEATMAP_PX, false, Image.FORMAT_RGB8)
	for y in range(HEATMAP_PX):
		for x in range(HEATMAP_PX):
			var v: float = pow(g[y * HEATMAP_PX + x] / peak, 0.45)
			if warm:
				img.set_pixel(x, y, Color(0.04 + v, 0.04 + v * 0.45, 0.08))
			else:
				img.set_pixel(x, y, Color(0.04, 0.04 + v * 0.5, 0.08 + v))
	_draw_reference(img)
	return img


func _save(img: Image, stem: String) -> void:
	var path := _out + stem + ".png"
	if img.save_png(path) != OK:
		push_error("flow_probe: could not write " + path)
	else:
		print("wrote ", path)


func _blur(src: PackedFloat32Array) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(src.size())
	var out := PackedFloat32Array()
	out.resize(src.size())
	for y in range(HEATMAP_PX):
		for x in range(HEATMAP_PX):
			var acc := 0.0
			for k in range(-2, 3):
				var xx := x + k
				if xx >= 0 and xx < HEATMAP_PX:
					acc += src[y * HEATMAP_PX + xx]
			tmp[y * HEATMAP_PX + x] = acc
	for y in range(HEATMAP_PX):
		for x in range(HEATMAP_PX):
			var acc := 0.0
			for k in range(-2, 3):
				var yy := y + k
				if yy >= 0 and yy < HEATMAP_PX:
					acc += tmp[yy * HEATMAP_PX + x]
			out[y * HEATMAP_PX + x] = acc
	return out


func _peak(g: PackedFloat32Array) -> float:
	var p := 0.0
	for v in g:
		p = maxf(p, v)
	return maxf(p, 1.0)


func _draw_reference(img: Image) -> void:
	var r: float = CharacterBase.CONFINEMENT_RADIUS
	var white := Color(1, 1, 1)
	for t in range(-int(r * 10.0), int(r * 10.0) + 1):
		var f := float(t) * 0.1
		_plot(img, f, -r, white)
		_plot(img, f, r, white)
		_plot(img, -r, f, white)
		_plot(img, r, f, white)
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

