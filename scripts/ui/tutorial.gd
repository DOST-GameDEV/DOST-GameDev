extends Control
class_name TutorialPanel

## The TUTORIAL screen — how the game is actually played, paginated.
##
## An overlay instanced into MainMenu.tscn and shown in place, exactly like
## SettingsPanel: it emits `back_pressed` and the menu re-unfurls its pennants.
## Not a `change_scene_to_file` target, because a scene change would tear down
## and rebuild the title screen behind it for a panel the player is going to
## close in twenty seconds.
##
## ⚠️⚠️ REWRITTEN 2026-08-01 FOR THE HARRYDAKS PIVOT (§ CHECKLIST 1.2). The nine pages
## this replaces taught a game that no longer exists, and not at the margins: 2v2 and
## paired sets, best-of-5, the lata and the tsinelas as PLAYABLE units with eight
## abilities between them, dents, ring-outs, two selectable win modes, and a control
## list in which every single key was wrong — Bump on F, Guard/dash on Shift, Tag on
## Q. `Design.md` §12 is the list of what went; every one of those pages described
## something on it. A tutorial that teaches deleted mechanics is worse than no
## tutorial, because the player trusts it.
##
## THE CONTENT IS THE POINT, so a note on where it comes from. Every number and every
## rule below was read out of the code that implements it, and cross-checked against
## `Design.md`, which is the balance source of truth:
##
##   * 4 players, 4 rounds, the clockwise rotation — `MatchManager.PLAYER_COUNT` /
##     `ROUNDS` / `defender_slot_for()`. §0 and §1.
##   * 90 s rounds — `RoundManager.ROUND_TIME`. §1.
##   * The 2.5 s charge, the 1.25 s throw lock, the 1.5 s reset channel —
##     `Carrier.CHARGE_FULL_TIME` / `THROW_LOCK_TIME` / `Lata.RESET_CHANNEL_TIME`.
##   * The lunge, the shove and the speed split — `CharacterBase.LUNGE_*` / `SHOVE_*` /
##     `ATTACKER_SPEED_SCALE`. All revised 2026-08-01 on human instruction.
##   * The scores — `RoundManager.SCORE_*` and `Design.md` §8.
##   * The keys are the `[input]` block of `project.godot`.
##
## ⚠️ THE BOX IS STILL DELIBERATELY NOT GIVEN A NUMBER, for a NEW reason. It is a
## SQUARE at |x| = |z| = 5.0 (`Design.md` §2), not a radius, and "5 units square" means
## nothing to a player who has never seen the chalk. The pages describe the rule — the
## taya cannot leave the box, and outside it you cannot be tagged — which is what the
## player acts on. ⚠️ It is also the one number on this screen most likely to move:
## `build fair` §2.2 owns retuning it for 1-vs-3 and `build model` §5.1 redraws the
## chalk with it, so a printed figure here would go stale in someone else's commit.

signal back_pressed

## One entry per page. `rows` are rendered as a fixed-width amber chip beside a
## wrapping body line — see `_build_row`. `tiles` is the PREMISE card's own shape and
## only page 1 has it — see `_build_premise_tile`.
##
## ⚠️ PAGE 1 IS FOUR PICTURES AND TWELVE WORDS, and the reference pages sit behind it. The reference pages answer "what does SHIFT do"; they cannot
## answer "what am I looking at", because a player who does not yet know what a lata
## is has no hook to hang `["90 SECONDS", ...]` on. So the premise goes IN FRONT and
## stays wordless enough to be read in one glance:
##
##   LATA / the can · TAYA / guards it, alone   are the DEFENCE pair, and their words are blue
##   TSINELAS / the slipper · ATTACKER / throws, then runs   are the OFFENCE pair, in orange
##
## which teaches the colour rule by using it rather than by stating it — the same way
## the vocabulary itself is taught. Word count is the whole budget, lede included:
## four glosses, four headwords, and a four-word lede is twelve. ⚠️ LATA, TSINELAS and
## TAYA are Filipino; ATTACKER is not. TAYA was DEFENDER until 2026-08-01 — see the
## tile's own note, which is about matching the HUD rather than about vocabulary.
## ⚠️⚠️ EVERY BODY LINE IS ONE SENTENCE, AND THAT IS A HARD RULE RATHER THAN A STYLE.
## 🧑 2026-08-02, relaying playtest feedback: *"make tutorial shorter or easier to
## understand, comments was it was too long"*. It was ten pages of forty-to-sixty-word
## paragraphs — about 1 400 words of reading standing between a player and a game they
## wanted to play, which is not a tutorial anyone finishes.
##
## What was cut, and why it was safe:
##
##   · THE TWO JOBS folded into THE GAME. It restated the premise card in prose; only
##     the two role definitions were new, and they fit as two more rows.
##   · READING THE HUD dropped whole. The scoreboard, the lata panel and the status rows
##     are all legible ON SCREEN, in front of the player, labelled — a page describing
##     them teaches nothing the first ten seconds of a round does not. CROSSHAIR was the
##     one line carrying a RULE rather than a description, so it moved to THE RISK, which
##     is where the rule it enforces already lives.
##   · Every remaining body was cut to the fact and its consequence. The reasoning that
##     went with them ("that is the taya's reward for blocking", "selling out the person
##     beside you is a real strategy") is good writing and it is why the page was long;
##     a player discovers all of it in one round anyway.
##
## Nothing MECHANICAL was dropped. Every number a player cannot discover by looking —
## 2.5 s charge, 1.5 s reset, 5 s stun, 2.5 m shove, the four scoring values — is still
## on a page. Ten pages became eight and the word count roughly halved.
##
## ⚠️ AND THE ROW COUNT IS THE REAL CEILING, NOT THE WORD COUNT. `_build_row` gives every
## row a fixed-height amber chip, so a page's height is driven by how MANY rows it has far
## more than by how long they are — HANDS overflowed at six rows and clipped its own last
## line at 1920×1080. Five is the most any page here carries, and a merge that would have
## made seven is why THE GAME lost two rows on the way in rather than gaining three.
const PAGES: Array[Dictionary] = [
	{
		"title": "TUMBANG PRESO",
		"lede": "1v1v1v1. One taya.",
		"tiles": [
			# ⚠️ Two DIFFERENT roster entries for the two person tiles. Both concepts are
			# "a person", and rendering the same rig twice would read as a duplicated
			# picture rather than as two jobs — the role colour alone cannot carry that
			# when the silhouette is identical.
			# ⚠️ "TAYA", NOT "DEFENDER", AND THE HUD IS WHY. Every readout in the match
			# says taya — the round label ("TAYA: P2"), the YOU card ("TAYA (DEFENDER)")
			# and the scoreboard's own marker. The premise card is where a player learns
			# the word, so teaching them a different one and then showing this one on
			# screen for six minutes is the one thing this page must not do. The gloss
			# carries the English, which is the same trick LATA and TSINELAS already use.
			{"kind": "can", "fil": "LATA", "eng": "the can", "role": "defense"},
			{"kind": "person", "index": 0, "fil": "TAYA", "eng": "guards it, alone", "role": "defense"},
			{"kind": "slipper", "fil": "TSINELAS", "eng": "the slipper", "role": "offense"},
			{"kind": "person", "index": 1, "fil": "ATTACKER", "eng": "throws, then runs", "role": "offense"},
		],
	},
	{
		"title": "THE GAME",
		# The colour rule was THE TWO JOBS' lede and it survives the merge, because it is
		# the one thing on this screen a player must carry into the match: the colours
		# track the ROLE, so a player's own colour changes when their turn as taya comes.
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
			# ⚠️ MOVED HERE FROM THE DELETED HUD PAGE, because it is a RULE and not a
			# description: the crosshair is the only feedback the game gives for the row
			# above it, and on its own page a player met it before the rule it answers.
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
			# ⚠️ THE MENU KEY LIVES ON THIS PAGE, NOT ON THE NEXT ONE, AND IT IS A LAYOUT
			# FIX RATHER THAN A CATEGORY JUDGEMENT. HANDS with six rows raised a scrollbar
			# and clipped its own last row at 1920×1080 — rendered and looked at. A
			# reference page the player has to scroll is the failure the premise card's
			# own note already calls out.
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
			# ⚠️ ONE-LINE CHIPS ON THIS PAGE, DELIBERATELY. Every other page's chip is a
			# key name and fits on a line; these were "+100\nknock it down" style
			# two-liners, and with four rows that alone overflowed the panel by 37 px —
			# `tutorial_shot.gd` measured it. Three passes of trimming the BODIES moved
			# the number by exactly zero, because each row's height was set by its chip,
			# not by its text. The chip carries the number and the verb.
			["+100  KNOCKDOWN", "To the attacker whose slipper hit the lata. Only the thrower is paid."],
			["+100  TAG", "To the taya, for catching an attacker who is holding a slipper inside the box."],
			["+10 / s  DEFENCE", "To the taya, for every second the lata is left standing."],
			["+50  SABOTAGE", "To an attacker who shoves a rival who is then tagged."],
		],
	},
]

## Width of the amber chip beside each body line. Wide enough for the longest
## key in CONTROLS ("Q / LEFT CLICK") without wrapping it.
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

## Only while actually on screen: this is an overlay that sits hidden inside
## MainMenu.tscn, and an invisible panel eating ui_cancel would stop Esc ever
## reaching the menu underneath it.
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

## Called by main_menu.gd when the panel is shown, so re-opening it starts at
## page one rather than wherever the last visit left off.
func reset_to_first_page() -> void:
	_page = 0
	_apply_page()

# --- Pages --------------------------------------------------------------------

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
		# ⚠️ TWO STEPS, AND THE ORDER IS LOAD-BEARING. `CharacterPreview` reaches its
		# SubViewport and Pivot through `@onready`, which do not resolve until the node
		# enters the tree — and `_ready()` is also where it sets its own mouse_filter.
		# Populating a tile before the strip is added gives "Cannot call method
		# 'add_child' on a null value" from `show_prop`, and an mouse_filter set there
		# is overwritten a moment later. So: build, ADD, then populate.
		var strip := _build_premise_strip(page["tiles"])
		rows.add_child(strip)
		_populate_premise(strip, page["tiles"])
	for row in page.get("rows", []):
		rows.add_child(_build_row(String(row[0]), String(row[1])))

	# A page the player has already scrolled, then paged away from and back to,
	# would otherwise open halfway down. Deferred because the new rows have not
	# been laid out yet on this frame, so the scroll maximum is still the old
	# page's.
	scroll.set_deferred("scroll_vertical", 0)

## One row: a fixed-width recessed chip carrying the key or the name, and the
## body line wrapping beside it. Built in code rather than as an instanced scene
## because it is four nodes with no behaviour — a .tscn for it would be a file to
## keep in sync for nothing.
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

# --- The premise card ---------------------------------------------------------

const PREMISE_ICON: String = "res://scenes/ui/PremiseIcon.tscn"
## Floor under one tile. Four of these plus separation has to fit the panel width,
## and the picture has to stay big enough to recognise a slipper in.
const TILE_WIDTH: float = 250.0
## ⚠️ A FLOOR, NOT A HEIGHT. The icon expands to whatever the panel has left after the
## two words — see the `Rows` comment in `Tutorial.tscn`. Both fixed heights that were
## tried are visible in the renders: 210 stranded the strip at the top of a mostly
## empty panel, and 330 clipped the English gloss and raised a scrollbar, which for a
## card whose whole job is to be read at a glance is the worse of the two failures.
const TILE_ICON_MIN_HEIGHT: float = 190.0
## Pulls the camera in on `CharacterPreview`'s measured shot — see `set_tile_framing()`,
## which also centres the subject. `FRAME_MARGIN` leaves 62% air, sized for a T-pose
## sharing the frame with a wood panel; in a tile that is the "big negative space" that was
## reported. ⚠️ 0.62 was too tight even centred — it cropped the lata top and bottom and
## the running figure through the feet — because it cancels the margin exactly. 0.80 fills
## the tile with a little air left, which is what a picture wants.
const TILE_ZOOM: float = 0.80
const TILE_FIL_SIZE: int = 46
const TILE_ENG_SIZE: int = 24

## The four tiles across one row. `EXPAND_FILL` at equal ratio rather than four
## absolute x positions, for the reason the whole front end is now container-driven:
## a Control's size is clamped UP to its minimum, so an absolute offset is a guess.
## The worst a long word can do here is push its own tile to the shared floor.
func _build_premise_strip(tiles: Array) -> HBoxContainer:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 18)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for tile in tiles:
		strip.add_child(_build_premise_tile(tile as Dictionary))
	return strip

## One tile: the real game object in 3D, the Filipino word under it in the ROLE
## colour, the English gloss under that.
##
## ⚠️ THE PICTURE IS THE ACTUAL ASSET, not an icon drawn for this screen. There is no
## icon art in `assets/ui/` and inventing four pieces of it is the ART lane's call,
## not this one's — but `CharacterPreview` already loads the real can, slipper and
## person rigs and frames them from their MEASURED bounds, so the premise card can
## show the player exactly the object they will see in the match. That also means it
## cannot go stale: reskin the lata and this page reskins with it.
##
## ⚠️ ONLY THE WORDS TAKE THE ROLE COLOUR, never the model. `show_character()` applies
## the roster's own material (skin, clothes) and flat-tinting a person orange would
## both fight ART's palette and stop the person reading as a person. The colour rule is
## about what the UI says, and the words are the UI.
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
	# The picture absorbs the slack; the two words keep their line height. `_frame()`
	# re-fits the camera on every resize, so growing the box reframes the subject
	# rather than cropping it.
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(icon)
	# The subject is NOT set here — see `_apply_page`. Nothing on `icon` that
	# `_ready()` owns can be touched until the strip is in the tree.

	var fil := Label.new()
	fil.text = String(tile["fil"])
	fil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fil.add_theme_font_size_override("font_size", TILE_FIL_SIZE)
	fil.add_theme_color_override("font_color", role_colour)
	# The Filipino word is the one thing on this card that must never be cut in half
	# to fit — it is what the page is teaching. Shrink to the floor, ellipsise rather
	# than reflow, and let the tile keep its shape.
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

## Second half of building the card, run only once the strip is IN THE TREE — see the
## call site. Walks the columns in the order `_build_premise_strip` made them.
func _populate_premise(strip: HBoxContainer, tiles: Array) -> void:
	for i in range(min(strip.get_child_count(), tiles.size())):
		var icon := strip.get_child(i).get_child(0) as CharacterPreview
		if icon == null:
			continue
		# ⚠️ TURNABLE, BUT THE WHEEL STILL SCROLLS THE PAGE. 🧑: *"in tutorial allow
		# us to play around with the models like in char select"*. These four sit
		# INSIDE this page's ScrollContainer, which is why they used to take no mouse
		# at all — a preview that ate the wheel would zoom a slipper while the player
		# was trying to scroll, and the tiles are big enough that the cursor is over
		# one most of the time. `enable_tile_interaction()` takes the two gestures the
		# scroller has no use for (drag to turn, right-click to reset) and leaves the
		# wheel to fall through. See that function for the full reasoning.
		icon.enable_tile_interaction()
		_show_subject(icon, tiles[i] as Dictionary)
		# ⚠️ AFTER the subject, because `set_frame_zoom` multiplies the MEASURED framing and
		# `show_prop`/`show_character` are what measure it. Called the other way round it
		# would be overwritten by the frame that follows.
		icon.set_tile_framing(TILE_ZOOM, true)

## Puts the right rig in the tile. Through `CharacterPreview`'s own public calls, so
## the framing, the material and the prop tint are all the ones the CHARACTER screen
## would give the same subject.
func _show_subject(icon: CharacterPreview, tile: Dictionary) -> void:
	match String(tile["kind"]):
		"can":
			icon.show_prop(CharacterRoster.can_at(0), true)
		"slipper":
			# ⚠️ CROCS, NOT SLIPPER 0. 🧑 2026-08-01, looking at this card: *"use ike
			# tsinelas here the tsinelas model here looks ugly"*, then, shown the
			# result, *"js do crocs"*. Index 0 is `tsinelas` — this project's own
			# procedural mesh, 276 triangles — and at icon size it reads as a brown
			# smear rather than as footwear.
			#
			# ⚠️ IKE WAS TRIED FIRST AND RENDERED AS A BLACK BLOB. Its texture is
			# nearly black and this tile's lighting is flat and head-on, so the model
			# that looks best on the CHARACTER screen (which orbits it under a key
			# light) loses all its shape at 120 px. **A prop that previews well in one
			# frame is not a prop that reads as an icon** — check the tile, not the
			# model. Crocs is mid-tone and holds its silhouette at this size.
			#
			# ⚠️ LOOKED UP BY ID, NOT HARDCODED TO 3. `SLIPPERS` is `build model`'s
			# table and has been re-ordered before; an index here would silently
			# become a different shoe the next time somebody inserts an entry.
			icon.show_prop(CharacterRoster.slipper_at(
				CharacterRoster.index_in(CharacterRoster.SLIPPERS, &"crocs")), false)
		_:
			icon.show_character(CharacterRoster.at(int(tile.get("index", 0))))

func _on_back_pressed() -> void:
	AudioManager.play("ui_back")
	back_pressed.emit()
