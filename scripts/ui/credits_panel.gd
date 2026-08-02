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
## (🧑: *"add ccby i missed"*, *"add it to credits too in the game tbh"*).
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
	{
		# ⚠️ THIS ENTRY EXISTS TO SATISFY A COMPETITION RULE, NOT A LICENCE. Gear
		# Up NCR §8 permits AI for "ideation, game design, programming, debugging,
		# writing, asset creation, prototyping, balancing, testing, documentation"
		# and requires that any AI-assisted content "be disclosed during the
		# competition" — with non-disclosure listed as grounds for disqualification
		# alongside outright plagiarism. Form 03 is where that disclosure is filed;
		# this line is the same fact stated somewhere a player can reach, which is
		# the standard the CC-BY block above is already held to.
		#
		# ⚠️ THE LATA IS NAMED HERE ON PURPOSE, AND AN EARLIER VERSION OF THIS LINE
		# WAS WRONG. It used to end "No AI-generated art, audio or 3D assets ship
		# in this build", which was written before anyone checked how the lata is
		# actually built. The can's meshes are `.obj` files emitted by
		# `tools/models/generate_all.gd` — procedural code that Claude Code wrote —
		# so a flat "no AI 3D assets" claim was false in exactly the place a judge
		# would look. What is true, and what this now says, is that the MESH comes
		# from code and the SKIN does not: the can's artwork is the team's own
		# drawing, flattened and applied as a texture.
		#
		# ⚠️ "NO GENERATIVE-AI IMAGE, MUSIC OR VIDEO SERVICE" IS THE CLAIM, AND THE
		# WORDING IS DOING REAL WORK. The line cannot say "no AI-generated assets"
		# — the SFX and ambience beds come out of `tools/audio/`, which Claude Code
		# wrote, and sourced assets were repurposed into this game's formats the
		# same way. What separates that from a prompt-to-asset generator is that
		# the AI wrote CODE and the code produced the asset deterministically, so
		# the distinction the sentence draws is the honest one and the reason the
		# AUDIO entry above ("all music and sound effects are original") is still
		# true rather than contradicted.
		#
		# ⚠️ THE COMMIT HISTORY DELIBERATELY DOES NOT SAY THIS AND THAT IS NOT A
		# CONTRADICTION. Authorship of the entry is the team's — §7 requires the
		# code be the registered members' and the team takes full responsibility
		# for it, which is why no commit carries a Co-Authored-By or a tool name
		# (see the README's setup step 4). Disclosure of a tool and attribution of
		# authorship are different questions; this answers the first.
		"chip": "DEVELOPMENT TOOLS",
		"body": "Claude Code (Anthropic) was used as a coding assistant during development — programming, debugging, testing and documentation. It helped write the bot AI that drives the computer-controlled players, wrote the procedural code that generates the lata mesh and the map geometry, repurposed sourced assets into this game's formats, and wrote the tools that synthesise the SFX and ambience beds. Every skin, texture and drawing is the team's own, and the team wrote the soundtrack. All game logic, mechanics and design decisions are the team's own, and the team takes full responsibility for the code submitted. No generative-AI image, music or video service was used.",
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

## ---------------------------------------------------------------------------
## § MADE BY. 🧑: *"put the people that made it next to made by BH studios"*, and
## *"also put our logo next to made by or something"*.
##
## ⚠️ THIS SITS ABOVE THE LICENCE BLOCKS ON PURPOSE. Everything below it answers
## "what did you borrow and what does its licence demand"; this answers "who made
## it", which is the thing a player opening CREDITS is actually looking for. It is
## the only block on this screen that carries no obligation — which is precisely
## why it would have ended up last if nobody said otherwise.
##
## ⚠️ THE LOGO IS A `TextureRect` WITH `expand_mode = IGNORE_SIZE` AND A FIXED
## HEIGHT, NOT A RAW TEXTURE. The source art is 445x370 with a transparent
## ground; dropped in at its native size it is taller than the heading beside it
## and shoves the first credit row down the page. Constraining the height and
## letting `KEEP_ASPECT_CENTERED` find the width keeps it optically level with
## the wordmark whatever the art is replaced with later.
const LOGO_PATH: String = "res://assets/ui/brand/bh_studios_logo.png"
const LOGO_HEIGHT: float = 104.0

## Names as the team gave them, in the roles they gave. Order is the order they
## were listed in, which is not alphabetical and is not seniority — leave it.
const TEAM_CREDITS: Array[Dictionary] = [
	{"name": "MATTHEW LABRADOR", "role": "Lead Developer  ·  UI Designer  ·  3D Asset Editor  ·  Poster Design"},
	{"name": "PAUL RECIO", "role": "Developer  ·  Video Editor"},
	{"name": "HARRY GOMEZ", "role": "Composer, Original Soundtrack  ·  Logo & UI Design"},
	{"name": "CLARENCE PAGADUAN", "role": "UI Designer  ·  Game Asset Artist"},
	{"name": "HANS LAO", "role": "QA Tester & Validation  ·  Administration"},
]

func _build_made_by() -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 14)

	# ⚠️ THE MARK STACKS ON TOP OF THE WORDMARK, IT DOES NOT SIT BESIDE IT.
	# 🧑: *"logo placement is weird af"* — and it was. The logo is a near-square
	# badge (445x370); parked to the LEFT of two stacked lines it has no edge to
	# align to, so it read as a loose object floating next to the text rather than
	# as part of one lockup. Centred above the words it has an axis, and the whole
	# thing becomes a masthead instead of a row that lost its body copy.
	var banner := VBoxContainer.new()
	banner.add_theme_constant_override("separation", 4)
	banner.alignment = BoxContainer.ALIGNMENT_CENTER
	block.add_child(banner)

	# ⚠️ "MADE BY" GOES ABOVE THE MARK AND THERE IS NO "BH STUDIOS" LABEL, BECAUSE
	# THE LOGO ALREADY IS ONE. The artwork is a wordmark — it reads "BH studios"
	# in the image itself — so setting a big amber "BH STUDIOS" underneath it
	# printed the studio's name twice in a row, one line apart, which is what made
	# the lockup look wrong rather than the placement alone. The words above the
	# mark now complete a sentence into it: MADE BY → [BH studios].
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
	# ⚠️ THE SHIPPED PNG IS ALREADY CREAM, AND `modulate` CANNOT DO THIS JOB.
	# The team's logo is drawn black-on-transparent — correct for the poster it
	# was made for, nearly invisible on this `WOOD_DEEP` panel. `modulate`
	# MULTIPLIES, and black times any colour is still black, so tinting it in
	# code looked like a no-op. The asset is instead recoloured on disk to
	# `CREAM` with the original alpha kept as the mask; the untouched black
	# original stays the team's master copy for print.
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner.add_child(logo)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	block.add_child(spacer)

	for entry in TEAM_CREDITS:
		block.add_child(_build_row(String(entry["name"]), String(entry["role"])))

	# Closes the block off, so the licence headings below read as a new section
	# rather than as more of this one.
	var rule := HSeparator.new()
	rule.add_theme_constant_override("separation", 18)
	block.add_child(rule)
	return block

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
