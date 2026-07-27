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
## Ring height: the ring sits at CharacterBase-local `y = -0.78`, not `0.03`.
## The parent's origin is the CENTRE of a 1.6-unit capsule, so `0.03` drew the
## "ground" ring at chest height, hovering around the character's torso and, on
## a carried tsinelas, in mid-air beside its carrier's head. `-0.78` is just
## above the capsule floor at `-0.8`, which is also where
## `CharacterVisual._align_to_capsule_floor` puts every model's feet.

## §4.5: "Fades out past ~15m." Without this every tag in the match renders at
## full opacity forever, and in a 40x40 arena that means four billboarded labels
## permanently stacked across the middle of a first-person view. Fully opaque
## in close, gone by FADE_END.
const FADE_START: float = 12.0
const FADE_END: float = 18.0

@onready var _ring: MeshInstance3D = $NameplateRing
@onready var _label: Label3D = $NameplateLabel

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
	# Roles swap every round, so this cannot be a one-shot. MatchManager is an
	# autoload and this node reads it directly, the same way hud.gd does — no
	# per-scene wiring, and it survives being instanced anywhere.
	MatchManager.round_started.connect(_on_round_started)
	refresh()

func _on_round_started(_round_number: int, _team_a_is_can: bool) -> void:
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
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var distance := camera.global_position.distance_to(_label.global_position)
	var alpha := clampf(inverse_lerp(FADE_END, FADE_START, distance), 0.0, 1.0)
	_label.modulate = Color(_role_color.r, _role_color.g, _role_color.b, alpha)
