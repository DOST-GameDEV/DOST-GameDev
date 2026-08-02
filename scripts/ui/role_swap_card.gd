extends Control
class_name RoleSwapCard

## THE INTERMISSION CARD — the four seconds between one round and the next.
##
## Timeline (Dev_Plan.md §4.6, unchanged by the 2026-08-02 rebuild):
##   0.0s  round_intermission_started fires → headline, swap and standings show
##   1.2s  the two panels rise and fade in
##   3.5s  "ROUND N — FIGHT!" wipe label briefly shown
##   ~4.0s round_started fires → card hides, panels reset for next time
##
## The world reset at 3.0s already happens in main.gd::_on_round_intermission_started
## (which fires on the same signal) — this card does not touch it.
##
## ⚠️⚠️ WHAT THIS CARD IS FOR, WRITTEN DOWN BECAUSE THE LAST VERSION HAD LOST IT. 🧑
## 2026-08-02, with a screenshot: *"i dont get this shit at all, like what is it supposed
## to tell me? pls revamp the boxes here and whats supposed to go to them"*.
##
## It had two boxes saying the same swap twice — "LOLA PACING · TAYA / was ATTACKER →"
## on the left and "MALLOWS INDAY TIKBOY · ATTACKERS / P3 was TAYA →" on the right. Every
## word of that is true and none of it is useful: a player already knows what they were
## last round, the arrows point at nothing, and the two boxes are the same sentence read
## forwards and backwards.
##
## A player has exactly two questions at a round boundary and this card now answers both,
## in the order they are asked:
##
##   1. **WHO DEFENDS NEXT** — the one fact that changes how the next 90 s is played, and
##      the one thing a player cannot work out for themselves (the rotation is clockwise
##      by slot, which nothing on the HUD spells out).
##   2. **WHERE DO I STAND** — the match is cumulative and has no per-round winner
##      (`Design.md` §1), so the standings ARE the story. The old card named one leader
##      and a number, which tells the leader something and everybody else nothing.
##
## The headline stat above them is what the round just produced. It stays because it is
## the only place the passive-defence payout is ever visible, and that number being
## enormous is a known balance risk `build fair` §2.1 exists to measure.
##
## ⚠️ THE LAYOUT IS THE SCENE'S JOB NOW, NOT THIS FILE'S. Every element sits in a
## `CenterContainer > VBoxContainer` and is sized by its content — see `RoleSwapCard.tscn`
## for why the old offset-positioned panels could not be made to stop overlapping. The
## only geometry left in this script is the reveal tween, which animates `modulate` and a
## pivot scale rather than positions, precisely so it cannot fight the container that
## owns the layout.

@onready var title_label: Label = %TitleLabel
@onready var headline_label: Label = %HeadlineLabel
@onready var swap_panel: PanelContainer = %SwapPanel
@onready var taya_caption: Label = %TayaCaption
@onready var taya_name: Label = %TayaName
@onready var attack_caption: Label = %AttackCaption
@onready var attacker_names: Label = %AttackerNames
@onready var standings_panel: PanelContainer = %StandingsPanel
@onready var standings: VBoxContainer = %Standings
@onready var fight_label: Label = %FightLabel

## The standings rows: made once at `_ready()` and refilled, like `hud.gd`'s score rows,
## so an intermission allocates nothing.
var _rows: Array[HBoxContainer] = []

func _ready() -> void:
	MatchManager.round_intermission_started.connect(_on_intermission_started)
	MatchManager.round_started.connect(_on_round_started)
	_build_standings_rows()
	_apply_wood_skin()

## The card's share of the 2026-07-30 restyle (B-143): the same face and the same
## `UiTheme.wood_style()` source as `hud.gd::_apply_wood_skin()`, because this is the
## screen the HUD hands over to between rounds.
##
## ⚠️ DISPLAY TYPE GETS AN INK OUTLINE AND NOT A PLATE. The card dims the 3D scene behind
## it rather than covering it, so every line of loose text has to survive being drawn
## over a lit street — the same rule HUD.tscn's floating text follows.
func _apply_wood_skin() -> void:
	for label in [title_label, headline_label, fight_label]:
		label.add_theme_constant_override("outline_size", 10)
		label.add_theme_color_override("font_outline_color", UiTheme.INK)
	title_label.add_theme_color_override("font_color", UiTheme.CREAM_MUTED)
	headline_label.add_theme_color_override("font_color", UiTheme.DEFENSE)
	fight_label.add_theme_color_override("font_color", UiTheme.AMBER)

	# ⚠️ THE ROLE COLOURS ARE ON THE ROWS, NOT ON TWO SEPARATE PANELS. §4.2's rule is
	# orange = OFFENSE, blue = DEFENSE, and it used to be carried by which of two boxes a
	# name sat in — which meant the rule needed two boxes to exist. A row of a shared
	# panel says it just as clearly and cannot drift out of alignment with its neighbour.
	for caption in [taya_caption, attack_caption]:
		caption.add_theme_color_override("font_color", UiTheme.CREAM_MUTED)
	taya_name.add_theme_color_override("font_color", UiTheme.DEFENSE)
	attacker_names.add_theme_color_override("font_color", UiTheme.OFFENSE)

	for panel in [swap_panel, standings_panel]:
		var sb := UiTheme.wood_style(UiTheme.WOOD_DEEP)
		sb.content_margin_left = 22.0
		sb.content_margin_right = 22.0
		sb.content_margin_top = 14.0
		sb.content_margin_bottom = 14.0
		panel.add_theme_stylebox_override("panel", sb)

## ⚠️ THE ROW COUNT COMES FROM `MatchManagerScript.PLAYER_COUNT`, so a card built for four
## seats is not a card that assumes four seats. `ranking()` returns every slot and the
## table draws all of them.
func _build_standings_rows() -> void:
	for i in range(MatchManagerScript.PLAYER_COUNT):
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 18)

		var rank := Label.new()
		rank.name = "Rank"
		# A minimum, not a clip: "1".."4" are the only strings this holds, and the width
		# exists so the NAME column starts at the same x on every row.
		rank.custom_minimum_size = Vector2(44, 0)
		rank.add_theme_font_size_override("font_size", 26)
		row.add_child(rank)

		var who := Label.new()
		who.name = "Name"
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.add_theme_font_size_override("font_size", 26)
		# ⚠️ AUTOWRAP, NOT `clip_text`. A clipped name is the layout bug wearing a
		# disguise — the same call `character_base.gd::display_name()` documents when it
		# explains why the length limit is a rule on the data rather than a haircut at
		# draw time.
		who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(who)

		var score := Label.new()
		score.name = "Score"
		score.custom_minimum_size = Vector2(120, 0)
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score.add_theme_font_size_override("font_size", 26)
		row.add_child(score)

		standings.add_child(row)
		_rows.append(row)

## The player's set name, or their seat label. The same call the scoreboard, the round
## label and the lobby all make — `display_name()` falls back on an empty name
## (`Design.md` §10), so nothing here needs a null check.
func _name_of(slot: int) -> String:
	var who := RoundManager.player_at(slot)
	return who.display_name() if who != null else "P%d" % [slot + 1]

## R-29 — WHAT THE ROUND PRODUCED.
##
## ⚠️ THIS IS A STAT, NOT A WIN CONDITION, and the difference is the pivot. It used to
## classify which of four win conditions had just fired (TAGGED / LATA DOWN / DENTED /
## TIME). None of them exist: a round is 90 s of scoring and ends on the clock, every
## time. What is worth saying instead is what the defence was actually worth — which is
## also the number `build fair` §2.1 is going to be measuring, so drawing it every round
## is free instrumentation.
## ⚠️⚠️ THE ROLE WORD NEVER TOUCHES THE NAME — 🧑 2026-08-02, on the rebuilt card:
## *"TAYA BERTO? It looks like taya berto is his name, figure out how to show that he is
## taya better"*. The line read "TAYA BERTO HELD FOR 70 PTS", and this is the SECOND place
## today the same mistake was found (the scoreboard row said "INDAY TAYA" — see
## `hud.gd::_build_role_cell()`), so it is worth stating as a rule rather than patching
## twice:
##
##   **A role word placed immediately before or after a name becomes part of the name.**
##
## Every name in this game is uppercase, several are two words ("LOLA PACING"), and the
## roster contains INDAY and BERTO — so "TAYA BERTO" is typographically identical to a
## two-word name. There are only two fixes: give the role its own cell in a different
## size and colour (what the scoreboard does, where space is tight), or take the role word
## out of the sentence entirely and let a VERB carry it (what this line does, where there
## is room for a sentence).
##
## "HELD THE LATA" is the taya's job description and only the taya can do it, so the role
## is stated more precisely than the label ever did — and there is no bare noun sitting
## against the name for a reader to glue on. The SwapPanel below names the roles outright
## anyway, in a layout where they are unmistakably captions.
func _show_headline() -> void:
	var taya := MatchManager.defender_slot
	headline_label.text = "%s HELD THE LATA FOR %d PTS" % [
		_name_of(taya), MatchManager.score_for(taya)]

func _on_intermission_started(next_round: int, next_defender_slot: int) -> void:
	# ⚠️ § CHECKLIST 1.4 ASKED WHETHER THIS READS CORRECTLY AT THE ROUND-4 BOUNDARY,
	# "where there is no next round". IT CANNOT REACH IT, and that is by construction
	# rather than by luck: `MatchManager.report_round_result()` returns into
	# `_finish_match()` when `round_number >= ROUNDS` and never emits
	# `round_intermission_started`, so the last thing after round 4 is the result screen.
	# `next_round` is therefore always 2..4 here and "ROUND 5 — FIGHT!" is unreachable.
	# Verified by reading the one call site; left as a note because the next person to
	# read this card will ask the same question.
	title_label.text = "END OF ROUND %d" % [maxi(1, next_round - 1)]
	_show_headline()

	# ⚠️ THE SWAP IS STATED ONCE, FORWARDS. The left column is the QUESTION ("who defends
	# next") and the right is the ANSWER; the old card put the answer in two boxes and
	# the question in neither.
	taya_name.text = _name_of(next_defender_slot)
	var others := PackedStringArray()
	for slot in range(MatchManagerScript.PLAYER_COUNT):
		if slot != next_defender_slot:
			others.append(_name_of(slot))
	# ⚠️ SEPARATED BY " · " AND NOT BY A SPACE. Three names run together read as one long
	# name, which is exactly how "MALLOWS INDAY LOLA PACING" appeared on the reported
	# screenshot — and roster names contain spaces themselves, so a space cannot be the
	# separator here.
	attacker_names.text = " · ".join(others)

	_fill_standings(next_defender_slot)

	fight_label.visible = false
	visible = true
	modulate.a = 1.0
	swap_panel.modulate.a = 0.0
	standings_panel.modulate.a = 0.0

	# Chained tween drives the two later beats:
	#   1.2s  → the panels rise in
	#   3.5s  → the FIGHT wipe (1.2 + 2.3 = 3.5)
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_callback(_reveal_panels)
	tween.tween_interval(2.3)
	tween.tween_callback(_show_fight.bind("ROUND %d — FIGHT!" % next_round))

## ⚠️⚠️ SORTED BY SCORE AND MARKED BY ROLE — the same two facts, and the same reasoning,
## as `hud.gd::_refresh_scoreboard()`. A player reads this table to find themselves and
## to find the person they have to catch; ranking is what makes the second possible.
##
## The INCOMING taya is what is highlighted, not the outgoing one, because this card is
## about the round that is starting. It is the only colour in the table, so it cannot be
## mistaken for a comment on a score.
func _fill_standings(next_defender_slot: int) -> void:
	var order := MatchManager.ranking()
	for i in _rows.size():
		var row := _rows[i]
		if i >= order.size():
			row.visible = false
			continue
		row.visible = true
		var slot: int = order[i]
		var colour := UiTheme.DEFENSE if slot == next_defender_slot else UiTheme.CREAM
		var rank := row.get_node("Rank") as Label
		var who := row.get_node("Name") as Label
		var score := row.get_node("Score") as Label
		rank.text = "%d" % [i + 1]
		who.text = _name_of(slot)
		score.text = str(MatchManager.score_for(slot))
		for label in [rank, who, score]:
			(label as Label).add_theme_color_override("font_color", colour)

## ⚠️⚠️ A FADE AND A SMALL SCALE POP, NEVER A POSITION TWEEN. The panels are children of a
## `VBoxContainer` now, and a container rewrites its children's positions every time it
## re-sorts — so the old `offset_left`/`offset_right` slide would be fought by the layout
## and land somewhere arbitrary. `modulate` and `scale` are not touched by container
## sorting, which is what makes them the safe things to animate inside one.
func _reveal_panels() -> void:
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for panel in [swap_panel, standings_panel]:
		panel.pivot_offset = panel.size / 2.0
		panel.scale = Vector2(0.94, 0.94)
		t.tween_property(panel, "modulate:a", 1.0, 0.35)
		t.tween_property(panel, "scale", Vector2.ONE, 0.45)

## Shows the "ROUND N — FIGHT!" wipe label, then fades it out quickly.
func _show_fight(text: String) -> void:
	fight_label.text = text
	fight_label.visible = true
	fight_label.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_property(fight_label, "modulate:a", 0.0, 0.1)

func _on_round_started(_round_number: int, _defender_slot: int) -> void:
	visible = false
	# Reset what the reveal tween touched, so the next intermission starts from a known
	# state rather than from wherever a tween killed mid-flight happened to leave things.
	for panel in [swap_panel, standings_panel]:
		panel.modulate.a = 0.0
		panel.scale = Vector2.ONE
