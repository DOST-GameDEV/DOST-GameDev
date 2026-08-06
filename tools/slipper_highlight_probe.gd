extends Node

const LANDING := Vector3(2.0, 0.0, -3.0)

var _fails: int = 0

func _ready() -> void:
	print("=== § LANDED-SLIPPER HIGHLIGHT PROBE ===")
	_check_palette()
	_check_material_types()
	_check_slipper()
	_check_panel()
	_check_persistence()
	print("=== RESULT: %s ===" % ("ALL CHECKS PASSED" if _fails == 0
		else "*** %d CHECK(S) FAILED ***" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)

func _expect(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s%s" % ["ok" if ok else "FAIL", label,
		"" if detail == "" else "  (%s)" % detail])


func _check_palette() -> void:
	print("§1 palette + setting")
	var palette := SettingsManagerScript.SLIPPER_HIGHLIGHTS
	_expect("Off is index 0", String(palette[0]["label"]) == "Off",
		String(palette[0]["label"]))
	var labels: Array[String] = []
	for choice in palette:
		labels.append(String(choice["label"]))
	_expect("palette is Off + purple/red/yellow/blue",
		labels == ["Off", "Blue", "Purple", "Red", "Yellow"], ", ".join(labels))

	SettingsManager.set_slipper_highlight(SettingsManagerScript.DEFAULT_SLIPPER_HIGHLIGHT, false)
	_expect("default is on", SettingsManager.slipper_highlight_enabled())
	_expect("default is Blue",
		String(palette[SettingsManager.slipper_highlight]["label"]) == "Blue")

	SettingsManager.set_slipper_highlight(SettingsManagerScript.HIGHLIGHT_OFF, false)
	_expect("Off disables", not SettingsManager.slipper_highlight_enabled())

	SettingsManager.set_slipper_highlight(99, false)
	_expect("out-of-range clamps into the palette",
		SettingsManager.slipper_highlight == palette.size() - 1,
		"got %d" % SettingsManager.slipper_highlight)
	SettingsManager.set_slipper_highlight(-4, false)
	_expect("negative clamps to Off", SettingsManager.slipper_highlight == 0,
		"got %d" % SettingsManager.slipper_highlight)


func _check_material_types() -> void:
	print("§2 what the roster is actually made of")
	var scene := load("res://scenes/objects/Slipper.tscn") as PackedScene
	var slipper := scene.instantiate() as Slipper
	add_child(slipper)
	var kinds: Array[String] = []
	for mesh in _meshes(slipper):
		for surface in range(mesh.get_surface_override_material_count()):
			var active := mesh.get_active_material(surface)
			kinds.append(active.get_class() if active != null else "nil")
	_expect("the stock prop has surfaces to rim", kinds.size() > 0, "%d" % kinds.size())
	var all_standard := true
	for kind in kinds:
		if kind != "StandardMaterial3D":
			all_standard = false
	_expect("every surface is StandardMaterial3D, i.e. no toon pass, i.e. emission is the lever",
		all_standard, ", ".join(kinds))
	var whites := 0
	for index in range(CharacterRoster.SLIPPERS.size()):
		if Color(CharacterRoster.slipper_at(index).get("tint", Color.WHITE)) == Color.WHITE:
			whites += 1
	_expect("every roster slipper is white-tint, i.e. never gets an override on its own",
		whites == CharacterRoster.SLIPPERS.size(),
		"%d of %d" % [whites, CharacterRoster.SLIPPERS.size()])
	slipper.queue_free()


func _check_slipper() -> void:
	print("§3 the rim on a live prop")
	var scene := load("res://scenes/objects/Slipper.tscn") as PackedScene
	if scene == null:
		_expect("Slipper.tscn loads", false)
		return
	var slipper := scene.instantiate() as Slipper
	add_child(slipper)

	_expect("stock prop has no surface override (the gap being covered)",
		_override_count(slipper) == 0, "%d override(s)" % _override_count(slipper))

	SettingsManager.set_slipper_highlight(3, false)
	var red: Color = SettingsManagerScript.SLIPPER_HIGHLIGHTS[3]["color"]

	slipper._apply_landed(LANDING, true)
	_expect("a landing that ended a flight lights the rim", slipper._landed_highlight_on)
	_expect("rim strength reaches the material",
		is_equal_approx(_lit_strength(slipper), Slipper.LANDED_RIM_STRENGTH),
		"got %.2f" % _lit_strength(slipper))
	_expect("rim colour is the player's pick", _lit_color(slipper).is_equal_approx(red),
		"got %s want %s" % [_lit_color(slipper), red])
	_expect("an outline hull is chained on", _outline(slipper) != null)
	_expect("the outline is scaled out of the prop\'s own 1.6, not left at world width",
		_outline(slipper) != null and float(_outline(slipper)
			.get_shader_parameter("outline_width")) < Slipper.OUTLINE_WORLD_WIDTH,
		"width %.4f" % (float(_outline(slipper).get_shader_parameter("outline_width"))
			if _outline(slipper) != null else -1.0))
	_expect("the emission behind it is a lift, not a repaint",
		_first_override(slipper) is StandardMaterial3D
			and (_first_override(slipper) as StandardMaterial3D)
				.emission_energy_multiplier < 0.25,
		"energy %.3f" % (_first_override(slipper) as StandardMaterial3D)
			.emission_energy_multiplier)

	SettingsManager.set_slipper_highlight(2, false)
	var purple: Color = SettingsManagerScript.SLIPPER_HIGHLIGHTS[2]["color"]
	_expect("changing the colour repaints a slipper already at rest",
		_lit_color(slipper).is_equal_approx(purple), "got %s" % _lit_color(slipper))

	SettingsManager.set_slipper_highlight(SettingsManagerScript.HIGHLIGHT_OFF, false)
	_expect("Off extinguishes it live", is_zero_approx(_lit_strength(slipper)),
		"got %.2f" % _lit_strength(slipper))
	SettingsManager.set_slipper_highlight(1, false)

	slipper._set_state(Slipper.CarryState.CARRIED)
	_expect("leaving LOOSE clears it", not slipper._landed_highlight_on)
	_expect("and the rim goes with it", is_zero_approx(_lit_strength(slipper)),
		"got %.2f" % _lit_strength(slipper))
	_expect("the outline hull is removed too, not left on unlit", _outline(slipper) == null)

	slipper._apply_landed(LANDING, false)
	_expect("a drop does NOT light it", not slipper._landed_highlight_on)
	slipper.host_reset_for_new_round()
	_expect("a round reset does NOT light it", not slipper._landed_highlight_on)

	var before: Color = _albedo(slipper)
	slipper._apply_landed(LANDING, true)
	_expect("relighting leaves the skin colour alone", _albedo(slipper).is_equal_approx(before),
		"%s -> %s" % [before, _albedo(slipper)])

	slipper.queue_free()


func _check_panel() -> void:
	print("§4 the Settings row")
	var scene := load("res://scenes/ui/SettingsPanel.tscn") as PackedScene
	if scene == null:
		_expect("SettingsPanel.tscn loads", false)
		return
	SettingsManager.set_slipper_highlight(3, false)
	var panel := scene.instantiate()
	add_child(panel)
	var picker := panel.get_node_or_null("%SlipperHighlightPicker") as OptionButton
	if picker == null:
		_expect("the picker exists under its unique name", false)
		panel.queue_free()
		return
	_expect("the picker exists under its unique name", true)
	_expect("one row per palette entry",
		picker.item_count == SettingsManagerScript.SLIPPER_HIGHLIGHTS.size(),
		"%d rows" % picker.item_count)
	_expect("seeded from the saved pick", picker.selected == 3,
		"selected %d" % picker.selected)
	_expect("Off carries no swatch", picker.get_item_icon(0) == null)
	_expect("every colour carries one",
		picker.get_item_icon(1) != null and picker.get_item_icon(2) != null
			and picker.get_item_icon(3) != null and picker.get_item_icon(4) != null)
	SettingsManager.set_slipper_highlight(4, false)
	_expect("it follows a change made elsewhere", picker.selected == 4,
		"selected %d" % picker.selected)
	panel.queue_free()


func _check_persistence() -> void:
	print("§5 it survives a restart")
	if SettingsManager.is_editing():
		SettingsManager.commit_edit()
	var found := SettingsManager.slipper_highlight

	SettingsManager.set_slipper_highlight(3, true)
	_expect("a committed pick reaches [display] on disk", _stored_highlight() == 3,
		"got %d" % _stored_highlight())

	SettingsManager.begin_edit()
	SettingsManager.set_slipper_highlight(2, false)
	_expect("a pick made inside an open edit does NOT reach disk", _stored_highlight() == 3,
		"got %d" % _stored_highlight())
	_expect("...but APPLY is offered it", SettingsManager.has_unsaved_changes())
	SettingsManager.commit_edit()
	_expect("APPLY writes it through", _stored_highlight() == 2,
		"got %d" % _stored_highlight())

	SettingsManager.set_slipper_highlight(0, false)
	SettingsManager._load_and_apply()
	_expect("a fresh load restores it", SettingsManager.slipper_highlight == 2,
		"got %d" % SettingsManager.slipper_highlight)

	SettingsManager.set_slipper_highlight(found, true)

func _stored_highlight() -> int:
	var config := ConfigFile.new()
	if config.load(SettingsManagerScript.SETTINGS_PATH) != OK:
		return -1
	return int(config.get_value(SettingsManagerScript.SETTINGS_SECTION_DISPLAY,
		"slipper_highlight", -1))


func _meshes(slipper: Slipper) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var visual := slipper.get_node_or_null("Visual")
	if visual == null:
		return out
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		out.append(node as MeshInstance3D)
	return out

func _override_count(slipper: Slipper) -> int:
	var count := 0
	for mesh in _meshes(slipper):
		for surface in range(mesh.get_surface_override_material_count()):
			if mesh.get_surface_override_material(surface) != null:
				count += 1
	return count

func _first_override(slipper: Slipper) -> Material:
	for mesh in _meshes(slipper):
		for surface in range(mesh.get_surface_override_material_count()):
			var material := mesh.get_surface_override_material(surface)
			if material != null:
				return material
	return null

func _lit_strength(slipper: Slipper) -> float:
	var material := _first_override(slipper)
	if material is ShaderMaterial:
		return float((material as ShaderMaterial).get_shader_parameter("rim_strength"))
	if material is StandardMaterial3D:
		var std := material as StandardMaterial3D
		return (std.emission_energy_multiplier / Slipper.EMISSION_SCALE
			if std.emission_enabled else 0.0)
	return -1.0

func _outline(slipper: Slipper) -> ShaderMaterial:
	var material := _first_override(slipper)
	return material.next_pass as ShaderMaterial if material != null else null

func _lit_color(slipper: Slipper) -> Color:
	var outline := _outline(slipper)
	if outline != null:
		return outline.get_shader_parameter("outline_color")
	var material := _first_override(slipper)
	if material is ShaderMaterial:
		return (material as ShaderMaterial).get_shader_parameter("rim_color")
	if material is StandardMaterial3D:
		return (material as StandardMaterial3D).emission
	return Color(0, 0, 0, 0)

func _albedo(slipper: Slipper) -> Color:
	var material := _first_override(slipper)
	if material is StandardMaterial3D:
		return (material as StandardMaterial3D).albedo_color
	if material is ShaderMaterial:
		return (material as ShaderMaterial).get_shader_parameter("albedo_color")
	return Color(0, 0, 0, 0)

