extends Node
class_name GameLaunchScript



const MAPS: Array[Dictionary] = [
	{
		"id": &"eskinita",
		"name": "ESKINITA",
		"tagline": "Urban side street. Sari-sari, sampay, kanal.",
		"scene": "res://scenes/maps/Eskinita.tscn",
		"preview": {"yaw": 0.0, "distance": 22.0, "height": 16.0},
	},
	{
		"id": &"bayan_plaza",
		"name": "BAYAN PLAZA",
		"tagline": "Barangay plaza. Church, basketball ring, acacia.",
		"scene": "res://scenes/maps/BayanPlaza.tscn",
		"preview": {"yaw": 0.0, "distance": 22.0, "height": 16.0},
	},
]

var selected_map: StringName = &"eskinita"

func selected_map_scene() -> String:
	for entry in MAPS:
		if entry["id"] == selected_map:
			return String(entry["scene"])
	push_warning("GameLaunch: unknown map '%s', falling back to '%s'" % [
		selected_map, MAPS[0]["id"]])
	return String(MAPS[0]["scene"])

func map_index() -> int:
	for i in range(MAPS.size()):
		if MAPS[i]["id"] == selected_map:
			return i
	return 0

var selected_character: StringName = &"berto"

func player_name() -> String:
	return SettingsManager.player_name

func character_index() -> int:
	var index := CharacterRoster.index_of(selected_character)
	return index if index >= 0 else 0

var selected_can: StringName = &"sarsi"
var selected_slipper: StringName = &"goma"

func can_index() -> int:
	var index := CharacterRoster.index_in(CharacterRoster.CANS, selected_can)
	return index if index >= 0 else 0

func slipper_index() -> int:
	var index := CharacterRoster.index_in(CharacterRoster.SLIPPERS, selected_slipper)
	return index if index >= 0 else 0

var pending_action: String = ""
var pending_join_address: String = ""
var pending_status_message: String = ""

func reset() -> void:
	pending_action = ""
	pending_join_address = ""
	pending_status_message = ""


var seat_tokens: Dictionary = {}

var solo_seat: int = 1

var spectator: bool = false

func clear_seating() -> void:
	seat_tokens.clear()



func _ready() -> void:
	if "--resolution" in OS.get_cmdline_args():
		return
	fit_window_to_usable_screen()

func fit_window_to_usable_screen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var win := get_window()
	if win == null:
		return
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
	if usable.size.x <= 0 or usable.size.y <= 0:
		return
	var extra: Vector2i = win.get_size_with_decorations() - win.size
	var inset: Vector2i = win.position - win.get_position_with_decorations()
	var room: Vector2i = usable.size - extra
	if room.x <= 0 or room.y <= 0:
		return
	var scale := minf(
		minf(float(room.x) / float(win.size.x), float(room.y) / float(win.size.y)), 1.0)
	if scale < 1.0:
		win.size = Vector2i(
			maxi(int(floor(win.size.x * scale)), 1), maxi(int(floor(win.size.y * scale)), 1))
		extra = win.get_size_with_decorations() - win.size
	var decorated: Vector2i = win.size + extra
	win.position = usable.position + inset + Vector2i(
		maxi((usable.size.x - decorated.x) / 2, 0), maxi((usable.size.y - decorated.y) / 2, 0))

