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
## taya cannot leave its post — which is the part a player needs and the part
## both sources agree on. Put a number here once they agree.

signal back_pressed

## One entry per page. `rows` are rendered as a fixed-width amber chip beside a
## wrapping body line — see `_build_row`.
const PAGES: Array[Dictionary] = [
	{
		"title": "THE GAME",
		"lede": "Tumbang preso, played as a sport. One side guards the lata. The other side throws a tsinelas at it.",
		"rows": [
			["2 v 2", "Each team is one Person plus one Prop — a Can or a Tsinelas. Every unit is player-controlled; nobody is a bot."],
			["90 SECONDS", "How long a round lasts. If nothing else has decided it by then, the defending side keeps the round."],
			["BEST OF 5", "First team to 3 round wins takes the match."],
			["SWAP EVERY ROUND", "You attack one round and defend the next. Both teams play both jobs, so the match is never decided by which side you drew."],
		],
	},
	{
		"title": "THE TWO SIDES",
		"lede": "Orange is offense and blue is defense. The colours track the ROLE, not the team — they swap when you do.",
		"rows": [
			["CAN SIDE\nDEFENSE", "Your Person is the taya. You and your lata are pinned to a radius around the base circle for the whole round — you cannot chase the attacker back to the throwing line. Holding the post IS the job."],
			["TSINELAS SIDE\nOFFENSE", "Your Person carries the tsinelas, throws it at the lata, and then has to go out into the open and get it back."],
			["NOBODY IS OUT", "Contact stuns and knocks back. There is no permanent elimination, so one bad tag never puts a round out of reach."],
		],
	},
	{
		"title": "HOW A ROUND GOES",
		"lede": "Five beats, and the third one is where the whole game lives.",
		"rows": [
			["1.  CARRY", "The attacking Person picks the tsinelas up and walks it out to a throwing line."],
			["2.  THROW", "Hold the ability button to charge, release to let it go. It leaves the hand on a real ballistic arc, aimed with the camera."],
			["3.  SCRAMBLE", "The tsinelas lands loose on the ground. Either the attacker sprints out and grabs it, or the slipper's own player crawls it home — slowly, and completely exposed. Both routes can be tagged."],
			["4.  DEFEND", "The taya body-blocks the throw, tags the attacker, and stands the lata back up when it goes over."],
			["5.  END", "On a win condition below, or on the 90-second timer."],
		],
	},
	{
		"title": "CONTROLS  ·  MOVING",
		"lede": "Keyboard and mouse. Rebind any of it under SETTINGS.",
		"rows": [
			["W A S D", "Move."],
			["MOUSE", "Look, and aim your throw."],
			["SPACE", "Jump, and Bump — a light melee with a small stagger and no cooldown."],
			["SHIFT", "Guard if you are a Can, dash-evade if you are a Tsinelas."],
		],
	},
	{
		"title": "CONTROLS  ·  HANDS",
		"lede": "The two buttons that decide rounds.",
		"rows": [
			["E", "Grab the tsinelas. As the taya, HOLD it beside your knocked-over lata to stand it back up — 1.5 seconds, and being tagged out of it cancels the whole thing with no partial credit."],
			["Q  /  LEFT CLICK", "Special. With a tsinelas in hand, holding it charges the throw — 0.9 seconds to full power, and a tap still throws. Empty-handed it is your Person's Tag."],
			["R", "Ready up. Pressed in the match itself, at the start of a round — Single Player has no ready gate before it, and a multiplayer lobby uses a button."],
			["ESC", "Pause."],
		],
	},
	{
		"title": "HOW YOU WIN",
		"lede": "Two round-win modes. Pick one on the setup screen before you start — in multiplayer only the host picks, for everyone.",
		"rows": [
			["CAPTURE\nteam can", "Tag the attacking Person — the always-on Bump or the Tag ability, either one — and the round ends in your favour immediately. Or simply survive to the 90-second timer."],
			["CAPTURE\nteam slipper", "Knock the lata down and stop it getting back up: a fall that goes unrecovered past its self-right window ends the round. Independently, knocking it down 5 times wins outright, whether or not the taya saved every one."],
			["DENTS", "Cans carry a health bar instead. Slippers win by fully denting one; Cans win on the timer, or by knocking slippers out of bounds 3 times."],
		],
	},
	{
		"title": "THE CANS",
		"lede": "Three lata, one special each. You press these.",
		"rows": [
			["SARDINAS\nquick stand", "Instantly self-rights out of Downed. Once per round, so spend it on the fall that actually matters."],
			["PALAYOK\nshatter trap", "Arm it, and the next time you go down you leave a patch behind that slows anyone attacking through it."],
			["BILAO\nspin guard", "A knockback pulse that shoves attackers off you."],
		],
	},
	{
		"title": "THE TSINELAS",
		"lede": "Three slippers. A tsinelas special is NOT a button — it is how that slipper flies when its Person throws it.",
		"rows": [
			["DYARYO\nbagsak bomb", "The lob. High arc, heavy gravity, wide burst where it lands."],
			["BAKYA\nbakya bash", "The heavy. Flattest arc, barely steerable in flight, and a direct hit knocks the lata flat outright."],
			["HAVAIANAS\nflick dash", "The line drive. Fastest launch and the most mid-air steering — but it is the one throw that will NOT knock the lata down by itself. It sets up."],
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
	for row in page["rows"]:
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

func _on_back_pressed() -> void:
	AudioManager.play("ui_back")
	back_pressed.emit()
