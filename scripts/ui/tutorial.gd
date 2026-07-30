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
## THE CONTENT IS THE POINT, so a note on where it comes from. Every number and
## every rule below was read out of the code that implements it, not out of the
## design doc, because the two have disagreed before:
##
##   * 90s rounds, best-of-5, the 5-fall cap and the 3 ring-outs are
##     `RoundManager.ROUND_TIME` / `MatchManager.WINS_NEEDED` /
##     `RoundManager.FALL_LIMIT` / `RoundManager.RING_OUT_LIMIT`.
##   * The 0.9s charge and the 1.5s reset channel are `Carrier.CHARGE_FULL_TIME`
##     and `Carrier.RESET_CHANNEL_TIME`.
##   * The key names are the `[input]` block of `project.godot`, p1's bindings.
##
## ⚠️ THE CONFINEMENT RADIUS IS DELIBERATELY NOT GIVEN A NUMBER. The GDD says 3
## units and `CharacterBase.CONFINEMENT_RADIUS` says 5.0. Rather than print
## whichever one happens to be right this week, page 2 describes the rule — the
## defender cannot leave its post — which is the part a player needs and the part
## both sources agree on. Put a number here once they agree.

signal back_pressed

## One entry per page. `rows` are rendered as a fixed-width amber chip beside a
## wrapping body line — see `_build_row`. `tiles` is the PREMISE card's own shape and
## only page 1 has it — see `_build_premise_tile`.
##
## ⚠️ PAGE 1 IS FOUR PICTURES AND TWELVE WORDS, and the eight reference pages behind
## it are unchanged. The reference pages answer "what does SHIFT do"; they cannot
## answer "what am I looking at", because a player who does not yet know what a lata
## is has no hook to hang `["90 SECONDS", ...]` on. So the premise goes IN FRONT and
## stays wordless enough to be read in one glance:
##
##   LATA / can · DEFENDER / holds the post   are the DEFENCE pair, and their words are blue
##   TSINELAS / slipper · ATTACKER / throws, then runs   are the OFFENCE pair, and their words are orange
##
## which teaches the colour rule by using it rather than by stating it — the same way
## the vocabulary itself is taught. Word count is the whole budget, lede included:
## four glosses, four headwords, and a four-word lede is twelve. ⚠️ Only LATA and
## TSINELAS are still Filipino — 🧑 2026-07-30 kept exactly those two plus
## "person"; TAYA and TAKBO became DEFENDER and ATTACKER.
const PAGES: Array[Dictionary] = [
	{
		"title": "TUMBANG PRESO",
		"lede": "One can. Two sides.",
		"tiles": [
			# ⚠️ Two DIFFERENT roster entries for the two person tiles. Both concepts are
			# "a person", and rendering the same rig twice would read as a duplicated
			# picture rather than as two jobs — the role colour alone cannot carry that
			# when the silhouette is identical.
			{"kind": "can", "fil": "LATA", "eng": "can", "role": "defense"},
			{"kind": "person", "index": 0, "fil": "DEFENDER", "eng": "holds the post", "role": "defense"},
			{"kind": "slipper", "fil": "TSINELAS", "eng": "slipper", "role": "offense"},
			{"kind": "person", "index": 1, "fil": "ATTACKER", "eng": "throws, then runs", "role": "offense"},
		],
	},
	{
		"title": "THE GAME",
		"lede": "Tumbang preso, played as a sport. One side guards the lata. The other side throws a tsinelas at it.",
		"rows": [
			["2 v 2", "Each team is one PERSON and one OBJECT. The object is a lata when you defend and a tsinelas when you attack. Every unit is driven by somebody: a player, or a bot filling an empty seat."],
			["90 SECONDS", "How long a round lasts. If nothing else has decided it by then, the defending side keeps the round."],
			["BEST OF 5", "First team to 3 round wins takes the match."],
			["SWAP EVERY ROUND", "You attack one round and defend the next. Both teams play both jobs, so the match is never decided by which side you drew."],
		],
	},
	{
		"title": "THE TWO SIDES",
		"lede": "Orange is offense and blue is defense. The colours track the ROLE, not the team, so they swap when you do.",
		"rows": [
			["LATA SIDE\nDEFENSE", "Your person is the defender. You and your lata are pinned inside a chalk square around the base circle for the whole round, so you cannot chase the attacker back to the throwing line. Holding the post IS the job."],
			["TSINELAS SIDE\nOFFENSE", "Your person carries the tsinelas, throws it at the lata, and then has to go out into the open and get it back."],
			["NOBODY IS OUT", "Contact stuns and knocks back. Nobody is ever eliminated, so one bad tag never puts a round out of reach."],
		],
	},
	{
		"title": "HOW A ROUND GOES",
		"lede": "Five beats, and the third one is where the whole game lives.",
		"rows": [
			["1.  CARRY", "The attacking person picks the tsinelas up and walks it out to the throwing line."],
			["2.  THROW", "Hold the ability button to charge, release to let it go. It leaves the hand on a real ballistic arc, aimed with the camera."],
			["3.  SCRAMBLE", "The tsinelas lands loose on the ground. Either the attacker sprints out and grabs it, or the slipper's own player crawls it home, slowly and completely exposed. Both routes can be tagged."],
			["4.  DEFEND", "The defender body-blocks the throw, tags the attacker, and stands the lata back up when it goes over. Standing it up takes 2.2 seconds of holding still, so it is a commitment, not a reflex."],
			["5.  END", "On a win condition below, or on the 90-second timer."],
		],
	},
	{
		"title": "CONTROLS  ·  MOVING",
		"lede": "Keyboard and mouse. Rebind any of it under SETTINGS.",
		"rows": [
			["W A S D", "Move."],
			["MOUSE", "Look, and aim your throw. The slipper flies to the point your crosshair is actually on, not just along the line it points down."],
			["SPACE", "Jump, and Bump: a light melee with a small stagger and no cooldown."],
			["SHIFT", "Guard if you are a Can, dash-evade if you are a Tsinelas."],
		],
	},
	{
		"title": "CONTROLS  ·  HANDS",
		"lede": "The two buttons that decide rounds.",
		"rows": [
			["E", "Grab the tsinelas. As the defender, HOLD it beside your knocked-over lata to stand it back up. That takes 2.2 seconds and being tagged out of it cancels the whole thing, with no partial credit."],
			["Q  /  LEFT CLICK", "Special. With a tsinelas in hand, holding it charges the throw: 0.9 seconds to full power, and a tap still throws. Empty-handed it is your person's Tag."],
			["R", "Ready up, in the match itself, before the first round. Everybody walks around freely until every player has pressed it, then the 3, 2, 1 runs and the round starts."],
			["ESC", "Pause."],
		],
	},
	{
		"title": "HOW YOU WIN",
		"lede": "Two round-win modes. Pick one on the setup screen before you start. In multiplayer only the host picks, and it applies to everyone.",
		"rows": [
			["CAPTURE\nlata side", "Tag the attacking person, with the always-on Bump or with the Tag ability, and the round ends in your favour immediately. Or simply survive to the 90-second timer."],
			["CAPTURE\ntsinelas side", "Knock the lata down and stop it getting back up. A fall nobody recovers inside its self-right window ends the round, and knocking it down 4 times wins outright whether or not the defender saved every one. Now and then it lands on its head and rights itself for free, which costs you the throw and nothing else."],
			["DENTS", "The lata carries a health bar instead. The tsinelas side wins by fully denting it. The lata side wins on the timer, by beating dents back out with the reset channel, or by knocking the tsinelas out of bounds 3 times."],
		],
	},
	{
		"title": "THE LATA",
		"lede": "Three kits on the defending side. These are BUTTONS: press the special while you are the lata.",
		"rows": [
			["QUICK STAND\nSarsilya · Sardinas", "Stand straight back up out of a knockdown, instantly. Once per round, so spend it on the fall that actually decides something."],
			["SPIN GUARD\nGatas · Kape", "A knockback pulse that shoves whoever is crowding you off the mark."],
			["SHATTER TRAP\nPintura · Biskwit", "Arm it, and the next time you go over you leave a patch behind that slows anyone coming through it."],
		],
	},
	{
		"title": "THE TSINELAS",
		"lede": "Three kits on the attacking side. A tsinelas special is NOT a button. It is HOW that slipper flies when your Tao throws it, so you choose it before the match and then you live with it.",
		"rows": [
			["BAGSAK BOMB\nPula · Dilaw", "The lob. High arc and heavy gravity, so it comes down onto the lata from above and bursts wide where it lands. The throw to pick when a defender is standing in your lane."],
			["BAKYA BASH\nBakya · Asul", "The heavy. Flattest arc, barely steerable once it leaves your hand, and a direct hit knocks the lata flat outright."],
			["FLICK DASH\nGoma · Luma", "The line drive. Fastest launch and the most steering in mid-air, but it is the one throw that will not knock the lata down on its own. It sets up the next one."],
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
