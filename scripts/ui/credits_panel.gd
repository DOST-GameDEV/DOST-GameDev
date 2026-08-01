extends Control
class_name CreditsPanel

## The CREDITS screen — § CHECKLIST 1.11, licence compliance rather than
## polish. Three CC-BY-4.0 models ship (CROCS, PANTULOG, IKE — see
## `Art_Direction.md` §4b) and their one requirement is that the author be
## reachable from somewhere the game actually ships, not just a line in a
## design doc nobody plays. This is that somewhere.
##
## ⚠️ CHIP READS "IKE", NOT "SIKE" — matches `CharacterRoster.SLIPPERS`'
## in-game display name (renamed 2026-08-01, on direct human instruction: the
## model's Nike wordmark only reads "IKE" legibly in play). The `LICENSE.txt`
## credit line below is untouched — it quotes the model's real Sketchfab
## title, which the licence itself fixes, not this game's roster name for it.
##
## An overlay instanced into MainMenu.tscn and shown in place, exactly like
## SettingsPanel and TutorialPanel: it emits `back_pressed` and the menu
## re-unfurls its pennants. Not a `change_scene_to_file` target, for the same
## reason those two are not — a scene change would tear down and rebuild the
## title screen behind a panel the player is about to close.

signal back_pressed

## ⚠️ EVERY CC-BY LINE BELOW IS THE MODEL'S OWN LICENSE.TXT, COPIED VERBATIM,
## NOT PARAPHRASED. Each `*_LICENSE.txt` beside the `.glb` in
## `assets/models/kits/footwear/` spells out the exact credit string the
## author asked redistributors to use ("copy paste this credit wherever you
## share it") — reusing their words instead of writing a summary is what
## makes this the actual requirement being met, not a good-faith paraphrase
## of it.
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

## Courtesy credits — none of these require attribution (CC0 / in-house), but
## they sit on the same screen as the CC-BY table rather than in a docs file,
## per `Art_Direction.md` §4b: "alongside the existing Kenney CC0 ... credits".
##
## ⚠️ THE FONT WAS THE ONE THIRD-PARTY ASSET MISSING FROM THIS SCREEN, and it
## is the only entry here that carries a real obligation. `Darumadrop One` is
## SIL Open Font License 1.1, not CC0: the OFL is satisfied by shipping the
## licence text (`assets/ui/fonts/DarumadropOne_LICENSE.txt`, which does ship)
## rather than by an on-screen line — but a credits screen that lists every
## CC0 kit and omits the one licensed asset it does not own reads as an
## oversight, because it was one. Added 2026-08-01 on direct human instruction
## (🧑: *"add ccby i missed"*, *"add it to credits too in the game lowkey"*).
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
		# ⚠️ REWORDED 2026-08-01. It read "all music and sound effects are
		# original, synthesised in-house by this project's own tools", which
		# stopped being true when the OST landed: the two tracks that ship were
		# WRITTEN by the team (🧑: *"we made the OST tracks btw"*), not emitted
		# by `generate_sfx.py`. Still all ours; no longer all synthesised.
		"chip": "AUDIO",
		"body": "All music and sound effects are original. The OST is written by the team; the SFX and ambience beds are synthesised in-house by this project's own tools. No third-party audio ships in this build.",
	},
	{
		"chip": "TSINELAS",
		"body": "This project's own mesh, generated procedurally — not a sourced asset.",
	},
]

## Matches Tutorial's CHIP_WIDTH so a player who has already seen that screen
## reads this one as the same design language, not a second UI.
const CHIP_WIDTH: float = 330.0

@onready var rows: VBoxContainer = %Rows
@onready var scroll: ScrollContainer = %Scroll
@onready var back_button: Button = %BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_build()

## Only while actually on screen — the same visibility guard SettingsPanel and
## TutorialPanel both carry. A hidden Control still receives
## `_unhandled_input` in Godot, so without this an offscreen CreditsPanel
## would swallow every Esc press meant for the menu underneath it.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()

func _build() -> void:
	for child in rows.get_children():
		child.queue_free()
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

## One row: a fixed-width recessed chip carrying the asset name, and the
## credit line wrapping beside it. Same shape as `TutorialPanel._build_row` —
## built in code rather than as an instanced scene because it is four nodes
## with no behaviour, and kept in step with the tutorial's row so the two
## screens do not visually drift apart.
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
