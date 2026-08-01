extends Control
class_name OffscreenIndicators

## Checklist 3.4 (U-6b) — screen-edge arrows for your teammate and the
## currently tracked Can. `Dev_Plan.md` §3.3 calls these **mandatory** for
## FPP: a Person's camera has a much narrower awareness cone than a Prop's
## TPP, and U-6 deferred exactly this mitigation.
##
## Driven from hud.gd, which already resolves the local character once a
## frame for the crosshair (`you_card.get_local_character()`) — `update()`
## takes that as a parameter instead of this file scanning for it a second
## time, same rule `you_card.gd`'s own doc already states for the local-
## character scan itself.
##
## Structure only, plain styling — the design lane restyles the arrow glyphs
## once this is merged, same sequencing as 0.1's meters.

## Keeps the arrow's own size inside the true screen edge rather than
## clipping half of it off-frame.
const EDGE_MARGIN: float = 40.0
## Roughly chest height, so the arrow points at "the unit" rather than at
## whatever happens to be at its feet — same reasoning IMPACT_PARTICLE_HEIGHT
## already uses in character_visual.gd.
const TARGET_HEIGHT_OFFSET: Vector3 = Vector3(0, 0.5, 0)
## INK outline on the arrow glyphs — see `_ready`. Heavy enough to survive against a
## bright sky, which is the worst case for a HIGHLIGHT-yellow arrow.
const GLYPH_OUTLINE: int = 6

@onready var teammate_arrow: Control = %TeammateArrow
@onready var teammate_label: Label = %TeammateLabel
@onready var can_arrow: Control = %CanArrow
@onready var can_label: Label = %CanLabel

func _ready() -> void:
	teammate_label.text = "▲"
	can_label.text = "▲"
	teammate_label.modulate = UiTheme.INK
	can_label.modulate = UiTheme.HIGHLIGHT
	# R-28 — AN OUTLINE, because these arrows live on the screen EDGE, which is where
	# this game's backgrounds are least predictable: sky one frame, asphalt the next, a
	# lit facade the one after. A flat glyph is legible against roughly half of that. An
	# INK outline makes it legible against all of it, and costs one theme constant.
	for label in [teammate_label, can_label]:
		label.add_theme_constant_override("outline_size", GLYPH_OUTLINE)
		label.add_theme_color_override("font_outline_color", UiTheme.INK)
	teammate_arrow.visible = false
	can_arrow.visible = false

## R-28 — the objective arrow takes the LOCAL PLAYER'S ROLE COLOUR. The can is the thing
## the whole round is about for both sides, so the arrow pointing at it should read as
## "this is your job", in the colour the rest of the HUD is already using for that.
## Called from `hud.gd::_refresh_role_accents()` on the same hooks the team cards use, so
## it can never disagree with them.
##
## ⚠️ The TEAMMATE arrow deliberately does NOT take it. Both arrows in one colour would
## make them indistinguishable at a glance, which is the opposite of the point.
func set_can_arrow_colour(colour: Color) -> void:
	can_label.modulate = colour

## Called once a frame by hud.gd. `local_character` may be null before it
## resolves, or on a peer with no match loaded — both just hide everything.
func update(local_character: CharacterBase) -> void:
	if local_character == null or not is_instance_valid(local_character):
		teammate_arrow.visible = false
		can_arrow.visible = false
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		teammate_arrow.visible = false
		can_arrow.visible = false
		return
	_update_one(teammate_arrow, camera, _find_own_slipper(local_character))
	# ⚠️ THE LATA IS READ STRAIGHT OFF `RoundManager`, NOT FOUND BY A TREE SCAN. There
	# is exactly one of it and the manager already holds the reference, so a recursive
	# `_find_character` walk every frame would be a search for something never lost.
	_update_one(can_arrow, camera, RoundManager.lata)

## The standard "radar arrow" recipe: project the target, detect off-screen
## (including behind-camera, which `unproject_position` does not itself
## flag), then clamp the centre-to-target ray to the inset screen rect and
## point the arrow along it.
## ⚠️ `target` IS A `Node3D`, NOT A `CharacterBase`. The lata is a plain prop now, and
## it is the one target this still points at — everything below only ever reads
## `global_position` and `is_inside_tree()`, so widening the type costs nothing.
func _update_one(arrow: Control, camera: Camera3D, target: Node3D) -> void:
	# `is_inside_tree()`, not just `is_instance_valid()` — measured live during
	# 4.3's peer-drop testing: a character mid-`queue_free()` (main.gd's
	# `_on_player_disconnected`, fired on every peer, not just the host —
	# every surviving peer frees its own copy of a departed one) is a real,
	# non-freed Object for one or more frames after leaving the tree, so
	# `is_instance_valid()` alone still passes it through. `global_position`
	# below needs a live parent chain to resolve and throws
	# `Condition "!is_inside_tree()" is true` otherwise — this was reachable
	# on any frame a tracked teammate or Can disconnects, not a hypothetical.
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		arrow.visible = false
		return
	var world_pos := target.global_position + TARGET_HEIGHT_OFFSET
	var to_target := world_pos - camera.global_position
	# Godot's unproject_position() divides by a plane distance that hits
	# exactly zero the instant a target sits exactly perpendicular to the
	# camera's forward axis (dead level with the lens, neither ahead nor
	# behind) — logging an engine error, not throwing, but still noise on
	# every frame a teammate happens to cross that exact line. A target this
	# close to the camera itself hits the same "p.d == 0" case regardless of
	# angle. Both are edge cases with nothing meaningful to point at anyway.
	var forward_component := -camera.global_transform.basis.z.dot(to_target)
	if to_target.length() < 0.1 or absf(forward_component) < 0.05:
		arrow.visible = false
		return
	var is_behind := forward_component < 0.0
	var viewport_size := get_viewport_rect().size
	var screen_pos := camera.unproject_position(world_pos)
	if is_behind:
		# unproject_position() mirrors a behind-camera point through the
		# centre of the frame instead of flagging it — undo that so the
		# arrow points the short way around to the target, not the long way.
		screen_pos = viewport_size - screen_pos
	var center := viewport_size / 2.0
	var on_screen := not is_behind \
		and screen_pos.x >= 0.0 and screen_pos.x <= viewport_size.x \
		and screen_pos.y >= 0.0 and screen_pos.y <= viewport_size.y
	if on_screen:
		arrow.visible = false
		return
	arrow.visible = true
	var dir := screen_pos - center
	if dir.length() < 0.01:
		dir = Vector2.UP # degenerate — dead centre behind; pick an arbitrary edge
	dir = dir.normalized()
	var half := center - Vector2.ONE * EDGE_MARGIN
	var scale_x: float = (half.x / absf(dir.x)) if absf(dir.x) > 0.0001 else INF
	var scale_y: float = (half.y / absf(dir.y)) if absf(dir.y) > 0.0001 else INF
	var t: float = minf(scale_x, scale_y)
	arrow.position = center + dir * t - arrow.size / 2.0
	# The glyph points up (-Y) at rotation 0; `Vector2.angle()` is measured
	# from +X, so it needs the quarter turn to line up with `dir`.
	arrow.rotation = dir.angle() + PI / 2.0

## Same team, not yourself — a team is 1 Person + 1 Prop (never two of the
## same kind), so this is unambiguous without checking is_person at all.
## ⚠️⚠️ THIS ARROW NOW POINTS AT **YOUR OWN SLIPPER**, and that is § CHECKLIST 1.6
## answered by 🧑's own mechanics revision rather than by this lane guessing.
##
## The history: it pointed at your teammate; the pivot deleted teams and left it a
## null-returning stub, with 1.6 asking whether a "nearest threat" arrow earned the
## slot or whether the arrow should be deleted outright. Neither, as it turns out —
## 🧑 2026-08-01: *"Directional Arrow: A dynamic UI arrow floats around the Attacker's
## feet pointing directly toward their uncollected slipper."*
##
## ⚠️ IT IS ONLY MEANINGFUL BECAUSE SLIPPERS NOW HAVE OWNERS. Under the old
## any-attacker-may-take-any-slipper rule there was no such thing as "your"
## slipper, so this arrow could not have existed as specified; `slipper.gd::
## can_be_grabbed_by()` is what makes it well-defined.
##
## Nothing is drawn while you are holding it — an arrow pointing at your own hand is
## noise, and it is the retrieval this exists to guide.
func _find_own_slipper(local_character: CharacterBase) -> Node3D:
	if local_character == null or local_character.is_defender:
		return null
	if local_character.holding_slipper():
		return null
	for node in get_tree().get_nodes_in_group("slippers"):
		var slipper := node as Slipper
		if slipper == null or slipper.owner_slot != local_character.player_slot:
			continue
		if slipper.state == Slipper.CarryState.CARRIED:
			continue
		return slipper
	return null

## Reads RoundManager's own tracked-Can list rather than re-scanning for
## `is_can` — that is the one place this is already kept correct across a
## role swap (see round_manager.gd::get_tracked_cans doc). Skips yourself:
## if you ARE the tracked Can, you don't need an arrow pointing at your own
## body.
## ⚠️ WAS `RoundManager.get_tracked_cans()`. The lata is a single world object now
## rather than whichever Prop was playing the can this round, so there is nothing to
## track and nothing to pick from.
##
## ⚠️ RETURNS `null` AND THE CALLER READS THE LATA DIRECTLY. `Lata` is not a
## `CharacterBase` — that is the whole point of the rewrite — so it cannot be
## returned through this signature. `update()` handles the lata arrow itself.
func _find_can(_local_character: CharacterBase) -> CharacterBase:
	return null

func _find_character(node: Node, matches: Callable) -> CharacterBase:
	if node is CharacterBase and matches.call(node):
		return node
	for child in node.get_children():
		var found := _find_character(child, matches)
		if found:
			return found
	return null
