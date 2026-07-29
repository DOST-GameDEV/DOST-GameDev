extends Node
## The CHARACTER screen, rendered and checked.
##
## ⚠️ A SCENE, NOT A `-s` SCRIPT. `godot -s some_script.gd` does not load
## autoloads, so every screen in this project fails to compile under it with
## "Identifier not found: GameLaunch / AudioManager / NetworkManager". That is
## not a fault in the screen — MatchSetup.tscn fails identically — it is `-s`
## being the wrong harness for anything that touches an autoload. Run as a scene
## and they are all there.
##
## ⚠️ AND NOT `--headless` FOR THE SHOTS. Headless has no rendering device and
## every capture comes back blank; this is the same note render_probe.gd carries.
##
## USAGE
##
##   godot --path . --resolution 1280x720 tools/character_select_probe.tscn -- <out-dir>
##
## `<out-dir>` must already exist and end in a slash. Writes one PNG per roster
## entry so every character can actually be LOOKED AT, which is the only way to
## catch a palette that renders a faceless silhouette — the exact failure
## `generate_person_palettes.py`'s slot-8 guard exists to prevent and the reason
## a numeric check alone is not enough.
##
## Exit code is 1 if any roster asset failed to load, so this doubles as a gate.

const SCREEN := "res://scenes/ui/CharacterSelect.tscn"

var _out := ""
var _screen: Control = null
var _index := 0
var _settle := 0
var _fails := 0
## [tab, index] pairs, one per shot — every entry of every tab.
var _shots: Array = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else ""

	# Every Person entry's two assets, checked before anything is rendered — a
	# missing palette shows up as a stock-coloured character rather than as an
	# error, which is precisely the kind of fault a screenshot pass can miss.
	# The lata and tsinelas tabs carry a tint rather than assets of their own, so
	# there is nothing to load-check there; their failure mode is visual and the
	# shots below are the check.
	for tab in range(CharacterRoster.CATEGORIES.size()):
		var category := CharacterRoster.category(tab)
		var entries: Array = category["entries"]
		print("tab '%s' (%s): %d entries" % [
			String(category["label"]), String(category["id"]), entries.size()])
		for i in range(entries.size()):
			var entry: Dictionary = entries[i]
			_shots.append([tab, i])
			if not entry.has("model"):
				continue
			var model := load(String(entry["model"]))
			var palette := load(String(entry["material"]))
			if model == null or palette == null:
				_fails += 1
			print("  [%2d] %-12s %-14s model=%-7s palette=%s" % [
				i, String(entry["name"]), String(entry["id"]),
				"OK" if model != null else "MISSING",
				"OK" if palette != null else "MISSING"])

	var packed := load(SCREEN) as PackedScene
	if packed == null:
		print("FAILED to load ", SCREEN)
		get_tree().quit(1)
		return
	_screen = packed.instantiate() as Control
	add_child(_screen)
	_settle = 30

func _process(_delta: float) -> void:
	if _screen == null:
		return
	if _settle > 0:
		_settle -= 1
		return
	if _index >= _shots.size():
		print("\n=== %s (%d entries across %d tabs, %d asset failures) ===" % [
			"ALL ENTRIES RENDERED" if _fails == 0 else "ASSET FAILURES",
			_shots.size(), CharacterRoster.CATEGORIES.size(), _fails])
		set_process(false)
		get_tree().quit(1 if _fails > 0 else 0)
		return

	# ⚠️ DRIVEN THROUGH THE SCREEN'S OWN STATE AND ITS OWN _apply(), not by
	# reaching into the preview. That is what makes this a test of the code a
	# player's arrow press runs rather than of a reimplementation of it — and it
	# is why the first version of this probe silently rendered the same character
	# twelve times: it set an `_index` field that the tabbed rewrite had replaced
	# with `_tab` + `_indices`, and setting a property that no longer exists is
	# not an error in GDScript.
	var tab: int = _shots[_index][0]
	var slot: int = _shots[_index][1]
	_screen.set("_tab", tab)
	var indices: Array = _screen.get("_indices")
	indices[tab] = slot
	_screen.set("_indices", indices)
	_screen.call("_refresh_tab_buttons")
	_screen.call("_apply")
	await RenderingServer.frame_post_draw
	var entry: Dictionary = CharacterRoster.entries_for(tab)[slot]
	var label := "%s_%s" % [String(CharacterRoster.category(tab)["id"]), String(entry["id"])]
	get_viewport().get_texture().get_image().save_png(
		"%schar_%02d_%s.png" % [_out, _index, label])
	print("wrote char_%02d_%s.png" % [_index, label])
	_index += 1
	# A few frames between characters: the preview instances a .glb on first
	# sight of it and the turn tween restarts, and capturing on the same frame
	# catches the model mid-arrival.
	_settle = 8
