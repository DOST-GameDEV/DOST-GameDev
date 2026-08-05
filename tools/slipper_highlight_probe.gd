extends Node
## § THE LANDED-SLIPPER HIGHLIGHT — the measurement behind the feature.
##
## Checks the three things that can be wrong without anybody noticing in a
## playtest, because each of them fails SILENTLY (a rim that never lights looks
## exactly like a rim nobody threw):
##
##   1. the rim actually reaches the material — on BOTH material types the roster
##      ships (`ShaderMaterial` from the toon pass, `StandardMaterial3D` straight
##      off an .obj import) and on a white-tint skin, which carries no surface
##      override at all until `_set_rim()` makes one;
##   2. it turns on for a landing that ENDED A FLIGHT and for nothing else — not
##      for a drop, not for a round reset;
##   3. the Settings picker is populated from the palette and honours "Off".
##
## ⚠️ RUN AS A SCENE, NOT WITH `-s`. A `SceneTree` script REPLACES the main loop, and
## the autoloads (`SettingsManager`, `AudioManager`, `RoundManager`) are registered by
## the one it replaces — so every probe in this directory that needs one is a scene, and
## this needs three.
##
##     godot --headless --path <repo> tools/slipper_highlight_probe.tscn

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

## ---------------------------------------------------------------------------

func _check_palette() -> void:
	print("§1 palette + setting")
	var palette := SettingsManagerScript.SLIPPER_HIGHLIGHTS
	_expect("Off is index 0", String(palette[0]["label"]) == "Off",
		String(palette[0]["label"]))
	var labels: Array[String] = []
	for choice in palette:
		labels.append(String(choice["label"]))
	# The four the human named, plus Off.
	_expect("palette is Off + purple/red/yellow/blue",
		labels == ["Off", "Blue", "Purple", "Red", "Yellow"], ", ".join(labels))

	SettingsManager.set_slipper_highlight(SettingsManagerScript.DEFAULT_SLIPPER_HIGHLIGHT, false)
	_expect("default is on", SettingsManager.slipper_highlight_enabled())
	_expect("default is Blue",
		String(palette[SettingsManager.slipper_highlight]["label"]) == "Blue")

	SettingsManager.set_slipper_highlight(SettingsManagerScript.HIGHLIGHT_OFF, false)
	_expect("Off disables", not SettingsManager.slipper_highlight_enabled())

	# ⚠️ THE CLAMP IS THE POINT, not the value: a settings.cfg written by a build with a
	# longer palette must not index off the end of this one.
	SettingsManager.set_slipper_highlight(99, false)
	_expect("out-of-range clamps into the palette",
		SettingsManager.slipper_highlight == palette.size() - 1,
		"got %d" % SettingsManager.slipper_highlight)
	SettingsManager.set_slipper_highlight(-4, false)
	_expect("negative clamps to Off", SettingsManager.slipper_highlight == 0,
		"got %d" % SettingsManager.slipper_highlight)

## ---------------------------------------------------------------------------

## ⚠️⚠️ THE ASSUMPTION UNDER THE WHOLE FEATURE, ASSERTED RATHER THAN BELIEVED. The
## highlight reaches the roster through `StandardMaterial3D.emission` and not through
## `toon.gdshader`'s `rim_strength`, because measurement says no slipper carries that
## shader. If somebody later puts the toon pass on this prop, `_set_rim()` keeps working
## (it handles both) but THIS check goes red — which is the point: it is the notice that
## the comment block explaining why the shader arm is dead has stopped being true.
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
	# White tint on every entry is the other half of why no override exists until
	# `_set_rim()` makes one — `apply_skin()` skips `_tint_meshes()` outright on white.
	var whites := 0
	for index in range(CharacterRoster.SLIPPERS.size()):
		if Color(CharacterRoster.slipper_at(index).get("tint", Color.WHITE)) == Color.WHITE:
			whites += 1
	_expect("every roster slipper is white-tint, i.e. never gets an override on its own",
		whites == CharacterRoster.SLIPPERS.size(),
		"%d of %d" % [whites, CharacterRoster.SLIPPERS.size()])
	slipper.queue_free()

## ---------------------------------------------------------------------------

func _check_slipper() -> void:
	print("§3 the rim on a live prop")
	var scene := load("res://scenes/objects/Slipper.tscn") as PackedScene
	if scene == null:
		_expect("Slipper.tscn loads", false)
		return
	var slipper := scene.instantiate() as Slipper
	add_child(slipper)

	# ⚠️ THE WHITE-TINT CASE ON PURPOSE — the prop as it comes out of the scene carries no
	# surface override, which is exactly the state `apply_skin()` leaves a white-tint skin
	# in and the state both rims were silently dead in before `_set_rim()` learned to
	# duplicate. Measuring the stock prop measures that case.
	_expect("stock prop has no surface override (the gap being covered)",
		_override_count(slipper) == 0, "%d override(s)" % _override_count(slipper))

	SettingsManager.set_slipper_highlight(3, false) # Red
	var red: Color = SettingsManagerScript.SLIPPER_HIGHLIGHTS[3]["color"]

	slipper._apply_landed(LANDING, true)
	_expect("a landing that ended a flight lights the rim", slipper._landed_highlight_on)
	_expect("rim strength reaches the material",
		is_equal_approx(_lit_strength(slipper), Slipper.LANDED_RIM_STRENGTH),
		"got %.2f" % _lit_strength(slipper))
	_expect("rim colour is the player's pick", _lit_color(slipper).is_equal_approx(red),
		"got %s want %s" % [_lit_color(slipper), red])
	# ⚠️ THE OUTLINE IS THE HIGHLIGHT. Emission alone floods the prop and reads as a
	# re-skin rather than a highlight — measured in a rendered palette comparison, which
	# is why the shape of the cue is asserted here and not only its colour.
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

	# Colour changes repaint what is already lying on the ground, not just the next landing.
	SettingsManager.set_slipper_highlight(2, false) # Purple
	var purple: Color = SettingsManagerScript.SLIPPER_HIGHLIGHTS[2]["color"]
	_expect("changing the colour repaints a slipper already at rest",
		_lit_color(slipper).is_equal_approx(purple), "got %s" % _lit_color(slipper))

	SettingsManager.set_slipper_highlight(SettingsManagerScript.HIGHLIGHT_OFF, false)
	_expect("Off extinguishes it live", is_zero_approx(_lit_strength(slipper)),
		"got %.2f" % _lit_strength(slipper))
	SettingsManager.set_slipper_highlight(1, false) # Blue, for the rest of the run

	# Picked up: the question "where did it go" is answered, so the cue goes out.
	slipper._set_state(Slipper.CarryState.CARRIED)
	_expect("leaving LOOSE clears it", not slipper._landed_highlight_on)
	_expect("and the rim goes with it", is_zero_approx(_lit_strength(slipper)),
		"got %.2f" % _lit_strength(slipper))
	_expect("the outline hull is removed too, not left on unlit", _outline(slipper) == null)

	# A drop, and a round reset, are both "put here" rather than "arrived here".
	slipper._apply_landed(LANDING, false)
	_expect("a drop does NOT light it", not slipper._landed_highlight_on)
	slipper.host_reset_for_new_round()
	_expect("a round reset does NOT light it", not slipper._landed_highlight_on)

	# ⚠️ AND THE ALBEDO IS UNTOUCHED, which is the constraint the whole approach was
	# built around: a rim that repainted the prop would override the tsinelas skin the
	# player picked on the CHARACTER screen.
	var before: Color = _albedo(slipper)
	slipper._apply_landed(LANDING, true)
	_expect("relighting leaves the skin colour alone", _albedo(slipper).is_equal_approx(before),
		"%s -> %s" % [before, _albedo(slipper)])

	slipper.queue_free()

## ---------------------------------------------------------------------------

func _check_panel() -> void:
	print("§4 the Settings row")
	var scene := load("res://scenes/ui/SettingsPanel.tscn") as PackedScene
	if scene == null:
		_expect("SettingsPanel.tscn loads", false)
		return
	SettingsManager.set_slipper_highlight(3, false) # Red, so "seeded from the value" is visible
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
	# The picker follows the manager, which is what makes BACK-with-discard honest on a
	# panel that is hidden and re-shown rather than re-instanced.
	SettingsManager.set_slipper_highlight(4, false)
	_expect("it follows a change made elsewhere", picker.selected == 4,
		"selected %d" % picker.selected)
	panel.queue_free()

## ---------------------------------------------------------------------------

## ⚠️ THE SETTING HAS TO SURVIVE A RESTART, and nothing else in this file proves it —
## §1 exercises the setter and the clamp, both of which are pure memory. This writes
## through `SettingsManager` and reads the file back with a second `ConfigFile`, so a
## key written into the wrong section, or under a name `_load_and_apply()` does not
## look for, fails here instead of on the player's next launch.
##
## ⚠️ IT ALSO ASSERTS THE **STAGING**, which is the half that is easy to get wrong in
## the other direction. § STAGED EDITS makes every setter a no-op on disk while the
## Settings panel has a transaction open, so a value that reached the file early would
## be one that BACK could no longer discard. The first run of this check caught exactly
## that shape from the other side: §4 leaves a panel — and therefore an open edit —
## behind it, and the write correctly did not happen.
##
## ⚠️ IT TOUCHES THE REAL `user://settings.cfg`, so the value found at entry is put
## back at exit. Every other key is safe on its own: `_save()` writes the whole of
## live memory, which was loaded from that same file at boot.
func _check_persistence() -> void:
	print("§5 it survives a restart")
	# Close whatever §4's panel opened, so this starts from a known transaction state.
	if SettingsManager.is_editing():
		SettingsManager.commit_edit()
	var found := SettingsManager.slipper_highlight

	SettingsManager.set_slipper_highlight(3, true) # Red, committed
	_expect("a committed pick reaches [display] on disk", _stored_highlight() == 3,
		"got %d" % _stored_highlight())

	SettingsManager.begin_edit()
	SettingsManager.set_slipper_highlight(2, false) # Purple, staged only
	_expect("a pick made inside an open edit does NOT reach disk", _stored_highlight() == 3,
		"got %d" % _stored_highlight())
	_expect("...but APPLY is offered it", SettingsManager.has_unsaved_changes())
	SettingsManager.commit_edit()
	_expect("APPLY writes it through", _stored_highlight() == 2,
		"got %d" % _stored_highlight())

	# And the path the autoload actually takes at boot lands on the same value.
	SettingsManager.set_slipper_highlight(0, false)
	SettingsManager._load_and_apply()
	_expect("a fresh load restores it", SettingsManager.slipper_highlight == 2,
		"got %d" % SettingsManager.slipper_highlight)

	SettingsManager.set_slipper_highlight(found, true)

## The value `settings.cfg` currently holds, or -1 if the key is absent.
func _stored_highlight() -> int:
	var config := ConfigFile.new()
	if config.load(SettingsManagerScript.SETTINGS_PATH) != OK:
		return -1
	return int(config.get_value(SettingsManagerScript.SETTINGS_SECTION_DISPLAY,
		"slipper_highlight", -1))

## ---------------------------------------------------------------------------
## Readers — deliberately going through the same surface overrides `_set_rim()`
## writes, so a rim that landed on the wrong material reads as absent here too.
##
## ⚠️⚠️ THE RIM IS READ OFF `emission` + THE OUTLINE `next_pass`, NOT OFF
## `rim_strength`, AND THAT IS THE MEASUREMENT NOT A CONVENIENCE. Every surface of
## every slipper in the roster is a `StandardMaterial3D` imported from an .obj —
## see `_check_material_types()`, which asserts exactly that so this stops being
## an assumption. `toon.gdshader` is never applied to this prop, so `rim_strength`
## has nowhere to land and reading it would report a working highlight as broken
## and a broken one as working.
##
## ⚠️ AND THE COLOUR IS READ OFF THE **OUTLINE**, because that is where the signal
## actually is. The emission is only a backing lift at `Slipper.EMISSION_SCALE` of
## the rim strength; an emission-only check would have passed just as happily on
## the version that flooded the whole slipper, which is the exact thing a rendered
## comparison caught and this reader exists to stop coming back.

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

## The first override `_set_rim()` would have written to, whatever its type.
func _first_override(slipper: Slipper) -> Material:
	for mesh in _meshes(slipper):
		for surface in range(mesh.get_surface_override_material_count()):
			var material := mesh.get_surface_override_material(surface)
			if material != null:
				return material
	return null

## How brightly this slipper is rimmed right now, 0.0 for not at all, -1.0 for
## "nothing was ever written" — which is the failure the white-tint gap caused and
## so has to read differently from an honest zero.
func _lit_strength(slipper: Slipper) -> float:
	var material := _first_override(slipper)
	if material is ShaderMaterial:
		return float((material as ShaderMaterial).get_shader_parameter("rim_strength"))
	if material is StandardMaterial3D:
		var std := material as StandardMaterial3D
		# Divided back out so this reports the STRENGTH the caller asked for, not the
		# scaled-down emission it was turned into — otherwise every expectation in this
		# file would have to know about `EMISSION_SCALE`.
		return (std.emission_energy_multiplier / Slipper.EMISSION_SCALE
			if std.emission_enabled else 0.0)
	return -1.0

## The outline hull chained onto the override, or null when the slipper is unlit.
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

## The prop's own colour, so the probe can prove the rim adds rather than replaces.
func _albedo(slipper: Slipper) -> Color:
	var material := _first_override(slipper)
	if material is StandardMaterial3D:
		return (material as StandardMaterial3D).albedo_color
	if material is ShaderMaterial:
		return (material as ShaderMaterial).get_shader_parameter("albedo_color")
	return Color(0, 0, 0, 0)
