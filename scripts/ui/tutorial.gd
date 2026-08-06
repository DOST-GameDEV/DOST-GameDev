extends Control
class_name TutorialPanel


signal back_pressed

const PAGES: Array[Dictionary] = [
	{
		"title": "TUMBANG PRESO",
		"lede": "1v1v1v1. One taya.",
		"tiles": [
			{"kind": "can", "fil": "LATA", "eng": "the can", "role": "defense"},
			{"kind": "person", "index": 0, "fil": "TAYA", "eng": "guards it, alone", "role": "defense"},
			{"kind": "slipper", "fil": "TSINELAS", "eng": "the slipper", "role": "offense"},
			{"kind": "person", "index": 1, "fil": "ATTACKER", "eng": "throws, then runs", "role": "offense"},
		],
	},
	{
		"title": "THE GAME",
		"lede": "Blue is the taya, orange is the attack. The colours follow the ROLE, so yours changes.",
		"rows": [
			["1v1v1v1", "Four players, four separate scores. No teams, no allies — empty seats are bots."],
			["90s × 4 ROUNDS", "The taya moves one seat clockwise each round, so everybody is taya exactly once."],
			["POINTS, NOT WINS", "You carry your own score across all four rounds. Highest total takes the match."],
			["TAYA", "Guard the lata and never leave the box. Block throws, stand it back up, tag attackers."],
			["ATTACKERS", "Throw from outside the box, then walk in and get your slipper back."],
		],
	},
	{
		"title": "HOW A ROUND GOES",
		"lede": "Four beats, and the third one is the whole game.",
		"rows": [
			["1.  THROW", "You start holding your slipper. From outside the box, hold LEFT CLICK to charge and release."],
			["2.  IT LANDS", "Hit the lata and it goes over. If the taya blocks it, it drops right beside them."],
			["3.  RETRIEVE", "Walk in and pick it up. This is the risk, and the entire point of the game."],
			["4.  RESET", "The taya holds E by the lata for 1.5 seconds to stand it up. No throws for a moment after."],
		],
	},
	{
		"title": "THE RISK",
		"lede": "Three rules decide every round, and they are all about the moment you hold a slipper.",
		"rows": [
			["SAFE UNTIL YOU GRAB", "Empty-handed you cannot be tagged at all, even inside the box. The danger is self-inflicted."],
			["TAGGED", "Thrown back to the safe zone and stunned for 5 seconds. Nobody is ever out of the round."],
			["NO THROWING FROM INSIDE", "A throw needs you outside the box, the lata standing, and your pickup cooldown expired."],
			["CROSSHAIR", "It only appears when a throw would be allowed. No crosshair means the throw is refused."],
		],
	},
	{
		"title": "CONTROLS  ·  MOVING",
		"lede": "Keyboard and mouse. Rebind any of it under SETTINGS.",
		"rows": [
			["W A S D", "Move."],
			["MOUSE", "Look, and aim your throw at the point your crosshair is actually on."],
			["SHIFT", "Sprint, about 1.5 seconds' worth. Empty it completely and you are winded for 2 seconds."],
			["SPACE", "Jump."],
			["ESC", "Pause."],
		],
	},
	{
		"title": "CONTROLS  ·  ATTACKER",
		"lede": "Your two buttons. Any slipper on the ground is fair game.",
		"rows": [
			["LEFT CLICK", "Hold to charge, release to throw. 2.5 seconds to full power; a tap still throws, weakly."],
			["E  ·  tap", "Pick up any loose slipper you are standing near, yours or not. You can carry one."],
			["E  ·  tap (nothing to grab)", "SHOVE a rival 2.5 metres back. If they are tagged after it, you are paid +50."],
		],
	},
	{
		"title": "CONTROLS  ·  TAYA",
		"lede": "You are faster than every attacker. Closing them down is your whole job.",
		"rows": [
			["LEFT CLICK", "PUNCH. An instant jab ahead, tagging any attacker in front of you holding a slipper."],
			["E  ·  hold", "LUNGE. Hold half a second, release to dash a metre and tag anyone in the path."],
			["E  ·  in the ring", "With the lata down, hold E to set it back up. Letting go loses all of it."],
			["⚠  NO TAGS WHILE IT IS DOWN", "Neither verb can tag until the lata is standing. Reset first, then hunt."],
			["YOU ARE FASTER", "Both verbs aim where you FACE, and you only turn while walking — keep moving into them."],
		],
	},
	{
		"title": "SCORING",
		"lede": "Every point in the game comes from one of these four, and your total carries across all four rounds.",
		"rows": [
			["+100  KNOCKDOWN", "To the attacker whose slipper hit the lata. Only the thrower is paid."],
			["+100  TAG", "To the taya, for catching an attacker who is holding a slipper inside the box."],
			["+10 / s  DEFENCE", "To the taya, for every second the lata is left standing."],
			["+50  SABOTAGE", "To an attacker who shoves a rival who is then tagged."],
		],
	},
]

const CHIP_WIDTH: float = 330.0

@onready var page_title: Label = %PageTitle
@onready var page_lede: Label = %PageLede
@onready var rows: VBoxContainer = %Rows
@onready var scroll: ScrollContainer = %Scroll
@onready var page_label: Label = %PageLabel
@onready var prev_button: TextureButton = %PrevButton
@onready var next_button: TextureButton = %NextButton
@onready var back_button: Button = %BackButton

var _page: int = 0

func _ready() -> void:
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_apply_page()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
	elif event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_on_prev_pressed()
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_on_next_pressed()

func reset_to_first_page() -> void:
	_page = 0
	_apply_page()


func _on_prev_pressed() -> void:
	AudioManager.play("ui_click")
	_page = (_page - 1 + PAGES.size()) % PAGES.size()
	_apply_page()

func _on_next_pressed() -> void:
	AudioManager.play("ui_click")
	_page = (_page + 1) % PAGES.size()
	_apply_page()

func _apply_page() -> void:
	var page: Dictionary = PAGES[_page]
	page_title.text = String(page["title"])
	page_lede.text = String(page["lede"])
	page_label.text = "%d / %d" % [_page + 1, PAGES.size()]

	for child in rows.get_children():
		child.queue_free()
	if page.has("tiles"):
		var strip := _build_premise_strip(page["tiles"])
		rows.add_child(strip)
		_populate_premise(strip, page["tiles"])
	for row in page.get("rows", []):
		rows.add_child(_build_row(String(row[0]), String(row[1])))

	scroll.set_deferred("scroll_vertical", 0)

func _build_row(chip_text: String, body_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)

	var slot := PanelContainer.new()
	slot.theme_type_variation = &"WoodSlot"
	slot.custom_minimum_size = Vector2(CHIP_WIDTH, 0)
	slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var chip := Label.new()
	chip.theme_type_variation = &"MenuValue"
	chip.text = chip_text
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot.add_child(chip)

	var body := Label.new()
	body.theme_type_variation = &"MenuBody"
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	row.add_child(slot)
	row.add_child(body)
	return row


const PREMISE_ICON: String = "res://scenes/ui/PremiseIcon.tscn"
const TILE_WIDTH: float = 250.0
const TILE_ICON_MIN_HEIGHT: float = 190.0
const TILE_ZOOM: float = 0.80
const TILE_FIL_SIZE: int = 46
const TILE_ENG_SIZE: int = 24

func _build_premise_strip(tiles: Array) -> HBoxContainer:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 18)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for tile in tiles:
		strip.add_child(_build_premise_tile(tile as Dictionary))
	return strip

func _build_premise_tile(tile: Dictionary) -> VBoxContainer:
	var is_offense := String(tile.get("role", "defense")) == "offense"
	var role_colour := UiTheme.OFFENSE if is_offense else UiTheme.DEFENSE

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.custom_minimum_size = Vector2(TILE_WIDTH, 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var icon := (load(PREMISE_ICON) as PackedScene).instantiate() as CharacterPreview
	icon.custom_minimum_size = Vector2(TILE_WIDTH, TILE_ICON_MIN_HEIGHT)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(icon)

	var fil := Label.new()
	fil.text = String(tile["fil"])
	fil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fil.add_theme_font_size_override("font_size", TILE_FIL_SIZE)
	fil.add_theme_color_override("font_color", role_colour)
	fil.clip_text = true
	fil.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(fil)

	var eng := Label.new()
	eng.text = String(tile["eng"])
	eng.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eng.add_theme_font_size_override("font_size", TILE_ENG_SIZE)
	eng.add_theme_color_override("font_color", UiTheme.CREAM_MUTED)
	eng.clip_text = true
	eng.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(eng)

	return column

func _populate_premise(strip: HBoxContainer, tiles: Array) -> void:
	for i in range(min(strip.get_child_count(), tiles.size())):
		var icon := strip.get_child(i).get_child(0) as CharacterPreview
		if icon == null:
			continue
		icon.enable_tile_interaction()
		_show_subject(icon, tiles[i] as Dictionary)
		icon.set_tile_framing(TILE_ZOOM, true)

func _show_subject(icon: CharacterPreview, tile: Dictionary) -> void:
	match String(tile["kind"]):
		"can":
			icon.show_prop(CharacterRoster.can_at(0), true)
		"slipper":
			icon.show_prop(CharacterRoster.slipper_at(
				CharacterRoster.index_in(CharacterRoster.SLIPPERS, &"crocs")), false)
		_:
			icon.show_character(CharacterRoster.at(int(tile.get("index", 0))))

func _on_back_pressed() -> void:
	AudioManager.play("ui_back")
	back_pressed.emit()

