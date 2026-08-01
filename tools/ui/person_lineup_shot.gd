extends Control
## Renders all twelve Persons side by side, through the REAL material path.
## Written 2026-08-01, branch `HARRYDAKS`.
##
## ⚠️ WHY. 🧑 2026-08-01: *"why is there one thats a completely diff texture and no
## outline"* — a single character in a live match rendering unlike the other eleven.
## Reading the roster proved every entry has a `material` key and every referenced
## `person_*.tres` exists and carries `next_pass = person_outline.tres`, so the defect
## is not visible in the data and has to be LOOKED at. One character wrong out of twelve
## is a comparison, and a comparison needs all twelve in one frame.
##
## ⚠️ IT GOES THROUGH `CharacterPreview.show_character()`, not through a hand-built
## MeshInstance. That is the same call the CHARACTER screen makes, which applies the
## roster palette exactly the way a match does — a lineup rendered by a bespoke loader
## would prove something about the loader.
##
## ⚠️ RUN IT WITH THE PLAIN EXE. `--headless` has no rendering device and every capture
## comes back blank.
##
##     Godot_v4.7.1-stable_win64_console.exe --path <repo> \
##         tools/ui/person_lineup_shot.tscn -- <out_dir>/

const PREVIEW_SCENE: String = "res://scenes/ui/PremiseIcon.tscn"
## Six across, two down — twelve entries at a size where an ink outline is actually
## resolvable. At 12-across each tile is too narrow to judge a border by eye, which is
## the entire question being asked.
const COLUMNS: int = 6
const TILE: Vector2 = Vector2(300, 330)

var _out := "res://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(grid)

	var scene := load(PREVIEW_SCENE) as PackedScene
	var tiles: Array = []
	for i in range(CharacterRoster.size()):
		var column := VBoxContainer.new()
		var icon := scene.instantiate() as CharacterPreview
		icon.custom_minimum_size = TILE
		column.add_child(icon)
		var label := Label.new()
		label.text = "%d %s" % [i, CharacterRoster.name_at(i)]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
		grid.add_child(column)
		tiles.append(icon)

	# ⚠️ POPULATE ONLY ONCE THE TILE IS IN THE TREE. `CharacterPreview` reaches its
	# SubViewport, Camera3D and Pivot through `@onready`, which do not resolve until
	# then — `tutorial.gd` documents the same build/add/populate order for the same
	# reason, and populating early gets "Cannot call method on a null value".
	await get_tree().process_frame
	for i in range(tiles.size()):
		var icon := tiles[i] as CharacterPreview
		icon.show_character(CharacterRoster.at(i))
		_report(i)

	# The rigs settle, the SubViewports each render at least once, and the idle clip
	# gets past its first frame before anything is captured.
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _out + "person_lineup.png"
	var err := image.save_png(path)
	print("[lineup] -> %s (%dx%d)" % [path if err == OK else "FAILED",
		image.get_width(), image.get_height()])
	get_tree().quit()


## ⚠️ THE MATERIAL IS PRINTED AS WELL AS DRAWN. "No outline" is a claim about
## `next_pass`, and a shipped `.tres` that merely FAILED TO LOAD leaves the rig on its
## imported glTF `ORMMaterial3D` — which is both a different surface and borderless,
## and looks in a screenshot exactly like a palette that loaded and is simply ugly.
## These two lines tell those apart without guessing.
func _report(index: int) -> void:
	var entry := CharacterRoster.at(index)
	var declared := String(entry["material"]) if entry.has("material") else "(none)"
	var loaded := ResourceLoader.exists(declared) if declared != "(none)" else false
	var chained := "n/a"
	if loaded:
		var mat := load(declared) as Material
		chained = "MISSING" if (mat == null or mat.next_pass == null) \
			else String(mat.next_pass.resource_path).get_file()
	print("[person] %2d %-12s material=%s exists=%s next_pass=%s"
		% [index, CharacterRoster.name_at(index), declared.get_file(), str(loaded),
			chained])
