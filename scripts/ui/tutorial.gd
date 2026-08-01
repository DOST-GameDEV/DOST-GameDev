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
const PAGES: Array[Dictionary] = [
	{
		"title": "TUMBANG PRESO",
		"lede": "Four players. One taya.",
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
		"lede": "Tumbang preso, played as a sport. One player guards the lata. The other three throw slippers at it.",
		"rows": [
			["4 PLAYERS", "One taya and three attackers. Empty seats are filled by bots, so a match always runs four."],
			["90 SECONDS", "How long one round lasts. The clock is the only thing that ends it — there is no sudden win."],
			["4 ROUNDS", "The taya role moves one seat clockwise after every round, so everybody is taya exactly once. Nobody can be handed the easy job twice."],
			["POINTS, NOT WINS", "Rounds are scored, not won. Your score carries across all four rounds and the highest total at the end takes the match. Level scores at the top is an honest draw."],
		],
	},
	{
		"title": "THE TWO JOBS",
		"lede": "Blue is the taya and orange is the attack. The colours track the ROLE, so yours changes when your turn comes.",
		"rows": [
			["TAYA\none player", "You guard the lata and you cannot leave the chalk box around it, all round. You stop throws with your body, stand the lata back up when it goes down, and tag attackers who come in. Holding the post IS the job."],
			["ATTACKERS\nthree players", "You throw a tsinelas at the lata from outside the box — and then you have to walk in and get it back. You are also each other's rivals: only one of you gets paid for knocking it down."],
			["NOBODY IS OUT", "Being tagged costs you position and time, never the round. There is no elimination, so a bad start is always recoverable."],
		],
	},
	{
		"title": "HOW A ROUND GOES",
		"lede": "Four beats, and the third one is the whole game.",
		"rows": [
			["1.  THROW", "You start every round with your slipper already in hand. From outside the box, hold LEFT CLICK to charge and release. 2.5 seconds to full power, so the taya can see it coming. Throwing is free — nothing can happen to you while you do it."],
			["2.  IT LANDS", "Hit the lata and it goes over. Miss and your slipper is lying on the ground. If the taya blocks it with their body it bounces away into the open field, which is a reprieve — it is not landing at their feet."],
			["3.  RETRIEVE", "This is the risk, and it is the entire point of the game. Only YOUR slipper answers to you — an arrow at your feet points to it. Walking in is safe; the instant it is in your hand you can be tagged, until you carry it back out."],
			["4.  RESET", "The taya stands the lata back up by holding E in its ring. It takes 1.5 seconds of standing still, and nobody may throw for a moment afterwards."],
		],
	},
	{
		"title": "THE RISK",
		"lede": "Three rules decide every round. They are all about the moment you are holding a slipper.",
		"rows": [
			["SAFE UNTIL YOU GRAB", "An attacker inside the box cannot be tagged at all until they pick a slipper up. Empty-handed you can stand on the taya's toes. The danger is entirely self-inflicted."],
			["TAGGED", "The taya LUNGES and catches you holding your slipper: you are thrown back to the safe zone and stunned for 5 seconds. Your slipper comes with you, so there is nothing to camp over — but the whole trip has to be made again."],
			["YOU CANNOT THROW FROM INSIDE", "A throw only leaves your hand if you are outside the box, the lata is standing, and your pickup cooldown has expired. The crosshair asks the same question the rules do, so if it is greyed out, the throw would have been refused."],
		],
	},
	{
		"title": "CONTROLS  ·  MOVING",
		"lede": "Keyboard and mouse. Rebind any of it under SETTINGS.",
		"rows": [
			["W A S D", "Move."],
			["MOUSE", "Look, and aim your throw. The slipper flies to the point your crosshair is actually on, not just along the line it points down."],
			["SHIFT", "Sprint. The bar is short — about 1.5 seconds flat out, roughly one crossing of the box — and it starts refilling a second after you let go. Empty it completely and you are winded for 2 seconds: slower, no sprint, and the bar will not refill at all until it passes."],
			["SPACE", "Jump."],
			# ⚠️ THE TWO MENU KEYS LIVE ON THIS PAGE, NOT ON THE NEXT ONE, AND IT IS A
			# LAYOUT FIX RATHER THAN A CATEGORY JUDGEMENT. HANDS with six rows raised a
			# scrollbar and clipped its own last row at 1920×1080 — rendered and looked
			# at. This page had a third of its panel empty. A reference page the player
			# has to scroll is the failure the premise card's own note already calls out.
			["ESC", "Pause."],
		],
	},
	{
		"title": "CONTROLS  ·  ATTACKER",
		"lede": "Your two buttons. Any slipper on the ground is fair game.",
		"rows": [
			["LEFT CLICK", "Hold to charge a throw, release to throw. 2.5 seconds to full power — a long, visible commitment the taya can react to. A tap still throws, weakly."],
			["E  ·  tap", "Pick up ANY loose slipper you are standing near — yours or somebody else's. You start the round with your own, and an arrow points to it, but if a rival leaves theirs lying in the open you can take it and throw it. You can only carry one."],
			["E  ·  tap (nothing to grab)", "SHOVE. No wind-up — it fires instantly, blasting a rival back 2.5 metres and stunning them. Costs a quarter of your stamina either way; 7.5-second cooldown if it lands, only 2 seconds if you whiff. Shove someone who is then tagged and you are paid +50 for it."],
		],
	},
	{
		"title": "CONTROLS  ·  TAYA",
		"lede": "You are faster than every attacker. Closing them down is your whole job.",
		"rows": [
			["LEFT CLICK", "PUNCH. A quick jab straight ahead, no wind-up. Any attacker holding their slipper within arm's reach in front of you is tagged instantly. Short cooldown — this is your answer to somebody standing next to you. ⚠ It only works while the lata is STANDING (see below)."],
			["E  ·  hold", "LUNGE. Hold half a second to charge, release to dash a metre forward. Anyone holding their slipper caught in the path is tagged — this is your answer to somebody running PAST you. (Right click does the same thing.)"],
			["E  ·  in the ring", "Standing in the lata's ring with it knocked over: hold E to set it back up. Letting go loses all of it — and while you are doing that, E is the reset and not the lunge."],
			["⚠  NO TAGS WHILE IT IS DOWN", "Neither the punch nor the lunge can tag anybody while the lata is lying over. Standing it back up is not just tidying — it is what re-arms both of your tagging verbs. Reset first, then hunt."],
			["YOU ARE FASTER", "Attackers move at 75% of your speed, permanently. Any chase in the open is one you win if you commit to it."],
			["TAGGING IS A PRESS", "Neither verb fires by standing close. Both are aimed along the way you are FACING, and you only turn on a frame you are walking — so keep moving into them."],
		],
	},
	{
		"title": "SCORING",
		"lede": "Every point in the game comes from one of these four. Your total carries across all four rounds.",
		"rows": [
			# ⚠️ ONE-LINE CHIPS ON THIS PAGE, DELIBERATELY. Every other page's chip is a
			# key name and fits on a line; these were "+100\nknock it down" style
			# two-liners, and with four rows that alone overflowed the panel by 37 px —
			# `tutorial_shot.gd` measures it. Three passes of trimming the BODIES moved
			# the number by exactly zero, because each row's height was set by its chip,
			# not by its text. The chip carries the number and the verb; the body carries
			# the reasoning.
			["+100  KNOCKDOWN", "To the attacker whose slipper hit the lata. Only the thrower is paid, so the other two attackers are your rivals as much as the taya is."],
			["+100  TAG", "To the taya, for lunging and catching an attacker who is holding a slipper inside the box."],
			["+10 / s  DEFENCE", "To the taya, every second the lata is standing. A taya nobody troubles is quietly winning the whole round."],
			["+50  SABOTAGE", "To an attacker who shoves a rival who is then tagged. Selling out the person beside you is a real strategy."],
		],
	},
	{
		"title": "READING THE HUD",
		"lede": "Everything the game will not say out loud is on screen somewhere.",
		"rows": [
			["SCOREBOARD\ntop left", "All four players, ranked, with the taya marked. The arrow is you."],
			["THE LATA\nbottom right", "Whether it is up or down, and what YOU can do about it right now — which differs depending on whether you are the taya or an attacker."],
			["STATUS ROWS", "Stuns, knockdowns and cooldowns each draw a row with its own countdown, so you can time playing around them. VULNERABLE has no timer on purpose: it lasts exactly as long as you choose to stand in the box holding a slipper."],
			["CROSSHAIR", "Only shown when a throw would actually be allowed. If it is not there, check the three rules on THE RISK."],
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
		# These four sit INSIDE the page's ScrollContainer, and `CharacterPreview`
		# takes the mouse for drag-to-turn and wheel-to-zoom. Left alone, the wheel
		# over a tile would zoom a slipper instead of scrolling the page. The tiles are
		# pictures; the CHARACTER screen is where inspecting the model belongs.
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_show_subject(icon, tiles[i] as Dictionary)
		# ⚠️ AFTER the subject, because `set_frame_zoom` multiplies the MEASURED framing and
		# `show_prop`/`show_character` are what measure it. Called the other way round it
		# would be overwritten by the frame that follows.
		icon.set_tile_framing(TILE_ZOOM)

## Puts the right rig in the tile. Through `CharacterPreview`'s own public calls, so
## the framing, the material and the prop tint are all the ones the CHARACTER screen
## would give the same subject.
func _show_subject(icon: CharacterPreview, tile: Dictionary) -> void:
	match String(tile["kind"]):
		"can":
			icon.show_prop(CharacterRoster.can_at(0), true)
		"slipper":
			icon.show_prop(CharacterRoster.slipper_at(0), false)
		_:
			icon.show_character(CharacterRoster.at(int(tile.get("index", 0))))

func _on_back_pressed() -> void:
	AudioManager.play("ui_back")
	back_pressed.emit()
