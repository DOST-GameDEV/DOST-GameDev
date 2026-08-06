extends Control

const PREVIEW_SCENE: String = "res://scenes/ui/PremiseIcon.tscn"
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

	await get_tree().process_frame
	for i in range(tiles.size()):
		var icon := tiles[i] as CharacterPreview
		icon.show_character(CharacterRoster.at(i))
		_report(i)

	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _out + "person_lineup.png"
	var err := image.save_png(path)
	print("[lineup] -> %s (%dx%d)" % [path if err == OK else "FAILED",
		image.get_width(), image.get_height()])
	get_tree().quit()


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

