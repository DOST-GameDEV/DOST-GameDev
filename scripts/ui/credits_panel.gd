extends Control
class_name CreditsPanel


signal back_pressed

const CC_BY_CREDITS: Array[Dictionary] = [
	{
		"chip": "CROCS",
		"body": "This work is based on \"crocs\" (sketchfab.com/3d-models/crocs-fbede59e03394e928ed0eccf27e8fc23) by fnk (sketchfab.com/fnk), licensed under CC-BY-4.0 (creativecommons.org/licenses/by/4.0).",
	},
	{
		"chip": "PANTULOG",
		"body": "This work is based on \"Pink Slipper\" (sketchfab.com/3d-models/pink-slipper-af5b6388d4f240389591a4ac09fedf06) by The Withered Rose (sketchfab.com/TheWitheredRose), licensed under CC-BY-4.0 (creativecommons.org/licenses/by/4.0).",
	},
	{
		"chip": "IKE",
		"body": "This work is based on \"Low Poly Nike Sandals\" (sketchfab.com/3d-models/low-poly-nike-sandals-8e77c949319148afb9134ba13f64046f) by les03 (sketchfab.com/les03official), licensed under CC-BY-4.0 (creativecommons.org/licenses/by/4.0).",
	},
]

const COURTESY_CREDITS: Array[Dictionary] = [
	{
		"chip": "ENVIRONMENT & KITS",
		"body": "Kenney kits (Mini Characters, City, Suburban, Fantasy Town, Mini Forest, Food, Furniture, Car) — CC0, kenney.nl. Attribution is courtesy, not required.",
	},
	{
		"chip": "TYPEFACE",
		"body": "Darumadrop One — Copyright 2020 The Darumadrop One Project Authors (github.com/ManiackersDesign/darumadrop), licensed under the SIL Open Font License 1.1.",
	},
	{
		"chip": "AUDIO",
		"body": "All music and sound effects are original. The OST is written by the team; the SFX and ambience beds are synthesised in-house by this project's own tools. No third-party audio ships in this build.",
	},
	{
		"chip": "TSINELAS",
		"body": "This project's own mesh, generated procedurally — not a sourced asset.",
	},
	{
		"chip": "DEVELOPMENT TOOLS",
		"body": "Claude Code (Anthropic) was used as a coding assistant during development — programming, debugging, testing and documentation. It helped write the bot AI that drives the computer-controlled players, wrote the procedural code that generates the lata meshes, this project's own tsinelas mesh and the map geometry, repurposed sourced assets into this game's formats, and wrote the tools that synthesise the SFX and ambience beds. Every skin, texture and drawing is the team's own, and the team wrote the soundtrack. All game logic, mechanics and design decisions are the team's own, and the team takes full responsibility for the code submitted. No generative-AI image, music or video service was used.",
	},
]

const CHIP_WIDTH: float = 330.0

@onready var rows: VBoxContainer = %Rows
@onready var scroll: ScrollContainer = %Scroll
@onready var back_button: Button = %BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_build()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()

func _build() -> void:
	for child in rows.get_children():
		child.queue_free()
	rows.add_child(_build_made_by())
	rows.add_child(_build_heading("THIRD-PARTY MODELS  ·  CC-BY-4.0"))
	for entry in CC_BY_CREDITS:
		rows.add_child(_build_row(String(entry["chip"]), String(entry["body"])))
	rows.add_child(_build_heading("EVERYTHING ELSE"))
	for entry in COURTESY_CREDITS:
		rows.add_child(_build_row(String(entry["chip"]), String(entry["body"])))
	scroll.set_deferred("scroll_vertical", 0)

func _build_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"MenuHeading"
	return label

const LOGO_PATH: String = "res://assets/ui/brand/bh_studios_logo.png"
const LOGO_HEIGHT: float = 104.0

const TEAM_CREDITS: Array[Dictionary] = [
	{"name": "MATTHEW LABRADOR", "role": "Lead Developer  ·  UI Designer  ·  3D Asset Editor  ·  Poster Design"},
	{"name": "PAUL RECIO", "role": "Developer  ·  Video Editor"},
	{"name": "HARRY GOMEZ", "role": "Composer, Original Soundtrack  ·  Logo & UI Design  ·  Game Voice Over"},
	{"name": "CLARENCE PAGADUAN", "role": "UI Designer  ·  Game Asset Artist  ·  Audio Composer"},
	{"name": "HANS LAO", "role": "QA Tester & Validation  ·  Administration  ·  Cinematics Director"},
]

func _build_made_by() -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 14)

	var banner := VBoxContainer.new()
	banner.add_theme_constant_override("separation", 4)
	banner.alignment = BoxContainer.ALIGNMENT_CENTER
	block.add_child(banner)

	var made := Label.new()
	made.text = "MADE BY"
	made.theme_type_variation = &"MenuBody"
	made.add_theme_font_size_override("font_size", 22)
	made.add_theme_color_override("font_color", UiTheme.CREAM_MUTED)
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner.add_child(made)

	var logo := TextureRect.new()
	logo.texture = load(LOGO_PATH) as Texture2D
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, LOGO_HEIGHT)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner.add_child(logo)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	block.add_child(spacer)

	for entry in TEAM_CREDITS:
		block.add_child(_build_row(String(entry["name"]), String(entry["role"])))

	var rule := HSeparator.new()
	rule.add_theme_constant_override("separation", 18)
	block.add_child(rule)
	return block

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

func _on_back_pressed() -> void:
	AudioManager.play("ui_back")
	back_pressed.emit()

