extends Node3D
class_name CharacterNameplate

## U-6 — the in-world half of "who is everyone else?" (docs/Dev_Plan.md §4.5).
## A flat ground ring in the unit's CURRENT ROLE colour plus a billboarded tag.
##
## ⚠️ THE RING IS ROLE-COLOURED, NEVER CLASS-COLOURED. `Dev_Plan.md` §4.2's hard
## rule: orange means the unit is on OFFENSE this round, blue means DEFENCE, for
## the whole project — HUD, nameplates, rings, scoreboard, role-swap card. The
## first version of this file keyed the colour off `is_person`, so every Person
## was orange and every Prop blue on both teams at once: the ring then carried
## no information a player could not already read off the model, and it
## contradicted the HUD panel sitting directly above it. The canonical
## derivation is `team_is_can_side` — the same one `you_card.gd::refresh()` and
## `hud.gd::set_round_display()` use. Do not add a third copy of it.
##
## ⚠️ AND IT HAS TO REFRESH. `team_is_can_side` FLIPS EVERY ROUND. A colour
## resolved once in `_ready()` is correct for round 1 and wrong for every round
## after it — the same trap B-42, `debug_refresh_readout()` and the YOU card
## each hit independently.
##
## Ring height and radius, and the label height, all track THIS unit's OWN
## current capsule (`CharacterBase.capsule_height()`/`capsule_radius()`)
## instead of a number baked for the Person alone — see `_apply_sizing()`.
##
## ⚠️ B-89, same lineage as B-88. The ring used to sit at a hardcoded
## CharacterBase-local `y = -0.78`, just above the capsule floor at `-0.8` —
## correct back when every unit (Person, Can, Tsinelas) shared that same
## 1.6-tall capsule. `Art_Direction.md` §1 gave Can/Tsinelas their own much
## shorter capsule (0.34/0.32 tall), and this ring never followed: on a Can it
## kept drawing a 0.55-radius ring nearly a full metre below the model's actual
## feet, and on a CARRIED tsinelas the whole nameplate (ring, label, all of it)
## rides along, so the disconnected ring appeared to float around/near the
## held object — "the slippers still have a circle around it when holding".
## Found by the human immediately after B-88's own fix landed.

## §4.5: "Fades out past ~15m." Without this every tag in the match renders at
## full opacity forever, and in a 40x40 arena that means four billboarded labels
## permanently stacked across the middle of a first-person view. Fully opaque
## in close, gone by FADE_END.
const FADE_START: float = 12.0
const FADE_END: float = 18.0

## Ring radius as a multiple of the unit's own capsule radius. 0.55 / 0.4 = 1.375
## for the Person, which is the only pair this was ever tuned against — kept as
## the ratio for every role rather than a flat number so a Can's ring reads as
## "a ring around a can", not "a ring sized for a person, around a can".
const RING_RADIUS_RATIO: float = 1.375
## Ring sits this far above the capsule floor — small and absolute (not
## proportional) on purpose: it only has to clear the floor mesh, not scale
## with the unit.
const RING_FLOOR_MARGIN: float = 0.02
## Label sits this far above the capsule top, scaled by the unit's own capsule
## height relative to the Person's (1.6) — 0.25 at Person scale is where this
## was originally tuned; a can with a 0.34-tall capsule wants a proportionally
## smaller gap, not the same 0.25 floating disconnected above a tiny object.
const LABEL_MARGIN_AT_PERSON_SCALE: float = 0.25
const PERSON_CAPSULE_HEIGHT: float = 1.6

@onready var _ring: MeshInstance3D = $NameplateRing
@onready var _ring_mesh: CylinderMesh = _ring.mesh as CylinderMesh
@onready var _label: Label3D = $NameplateLabel
## 2026-07-28 — B-89's sizing fix (see the class doc above) corrected the
## ring's SIZE/position relative to whatever capsule it currently has, but
## never addressed the actual complaint it quotes: a carried unit's ring
## still shows, now correctly sized but still riding along near the hand —
## "the circle is still attached to slipper even when it's held". A ground
## ring makes no sense for an object that is not standing on the ground.
## Hidden outright below, in _process(), rather than sized to nothing.
@onready var _carriable: Carriable = get_node_or_null("../Carriable") as Carriable

var _character: CharacterBase = null
var _ring_material: StandardMaterial3D = null
var _role_color: Color = UiTheme.DEFENSE

func _ready() -> void:
	_character = get_parent() as CharacterBase
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = _ring_material
	# ⚠️ apply_sizing() is DELIBERATELY NOT called here. Children ready before
	# their parent, so this runs BEFORE CharacterBase's own _ready() — which is
	# where _apply_role_collision() actually resizes the capsule this reads.
	# Calling it here would read the .tscn's default (Person) capsule on every
	# single unit's first frame. character_base.gd calls apply_sizing()
	# explicitly, in the same place and the same order it already calls
	# _visual.apply() — after the capsule is sized, never before.
	#
	# Roles swap every round, so refresh() cannot be a one-shot either.
	# MatchManager is an autoload and this node reads it directly, the same way
	# hud.gd does — no per-scene wiring, and it survives being instanced
	# anywhere.
	MatchManager.round_started.connect(_on_round_started)
	refresh()

## B-89 — sizes and positions the ring and label from THIS unit's own current
## capsule rather than the old shared constant. Public: character_base.gd calls
## this explicitly, right after _apply_role_collision(), from both _ready() and
## reset_for_new_round() — see the warning on _ready() above for why it cannot
## safely run on its own.
func apply_sizing() -> void:
	if _character == null:
		return
	var height := _character.capsule_height()
	var radius := _character.capsule_radius()
	_ring.position.y = -height / 2.0 + RING_FLOOR_MARGIN
	if _ring_mesh != null:
		var ring_radius := radius * RING_RADIUS_RATIO
		_ring_mesh.top_radius = ring_radius
		_ring_mesh.bottom_radius = ring_radius
	var label_margin := LABEL_MARGIN_AT_PERSON_SCALE * (height / PERSON_CAPSULE_HEIGHT)
	_label.position.y = height / 2.0 + label_margin

## Harmless if this fires before a round reset's explicit apply_sizing() call
## happens to land first — idempotent, same numbers either way, this is just a
## safety net for the (already-correct) round-2-onward case.
func _on_round_started(_round_number: int, _team_a_is_can: bool) -> void:
	apply_sizing()
	refresh()

## Public so main.gd's late-joiner sync (B-29) can force it, matching
## `Hud.refresh_you_card()`.
func refresh() -> void:
	if _character == null or not is_instance_valid(_character):
		return
	# §4.2: the ACCENT tracks role. Team identity is carried by the letter mark
	# in the tag below, never by hue.
	var is_defense: bool = _character.team_is_can_side
	_role_color = UiTheme.DEFENSE if is_defense else UiTheme.OFFENSE
	_ring_material.albedo_color = Color(_role_color.r, _role_color.g, _role_color.b, 0.8)

	# A1 / A2 / B1 / B2 per §4.5 — the letter is the team, the digit separates
	# the two units on it. The Person is always 1 and the Prop always 2, which
	# is stable across a role swap (is_person is fixed for the match; is_can is
	# not), so a player's own tag never changes mid-match.
	var team_letter := "A" if _character.team == 0 else "B"
	var unit_digit := "1" if _character.is_person else "2"
	var role_glyph := "DEF" if is_defense else "OFF"
	_label.text = "%s%s · %s" % [team_letter, unit_digit, role_glyph]
	_label.modulate = _role_color

## The tag fade (§4.5). Polled rather than signalled because distance to the
## viewer is a continuously-varying value, not an event — the same reasoning
## `character_visual.gd::_play_locomotion` already documents for velocity.
## Reads the viewport's current Camera3D, so it is automatically correct for
## whichever unit this peer is looking through, in either FPP or TPP, with no
## reference back to CameraRig.
func _process(_delta: float) -> void:
	var carried := _carriable != null and _carriable.state == Carriable.CarryState.CARRIED
	_ring.visible = not carried
	_label.visible = not carried
	if carried:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var distance := camera.global_position.distance_to(_label.global_position)
	var alpha := clampf(inverse_lerp(FADE_END, FADE_START, distance), 0.0, 1.0)
	_label.modulate = Color(_role_color.r, _role_color.g, _role_color.b, alpha)
