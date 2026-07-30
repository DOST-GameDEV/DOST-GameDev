extends Node3D
## R-27(b) ACCEPTANCE: renders of BOTH ready-phase objective states.
##
##   godot --path . tools/ui/ready_objective_shot.tscn -- /out/
##
## Writes `ready_objective_offense.png` / `ready_objective_defense.png`, and prints the
## label text and colour it resolved so the claim is a measurement and not only a look.
##
## ⚠️ DRIVES THE REAL PATH. `hud.gd::show_ready_prompt()` DERIVES the objective from the
## local character's team and `MatchManager.team_a_is_can` rather than being handed a
## string — that is the whole design, because `main.gd` owns the call sites and is not
## the UX lane's file. So a probe that set the label directly would prove nothing. This
## loads `Main.tscn`, reads which team the local unit actually landed on, and flips
## `team_a_is_can` to put that unit on each side in turn.
##
## Same shape as `tools/hud_probe.gd`, including the 1.0s wait — the local character does
## not exist until Main has spawned everyone, and `_refresh_ready_objective()` correctly
## shows NOTHING when it cannot find one.

var _main: Node
var _hud: Node
var _out := ""

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else ""
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	_hud = _main.find_child("HUD", true, false)

	var local_char = _hud.you_card.get_local_character()
	if local_char == null:
		print("FAIL: no local character after 1.0s — nothing to derive a role from")
		get_tree().quit(1)
		return
	print("local unit is on team %d" % local_char.team)

	# `team_a_is_can` means "team A holds the can", i.e. team A defends. To put OUR unit
	# on defence, the can must be held by OUR team.
	await _shoot("defense", local_char.team == 0)
	await _shoot("offense", local_char.team != 0)
	get_tree().quit(0)

## ⚠️ HONEST LIMITS OF THIS PROBE, so nobody reads more into the PNGs than is there.
## Flipping `team_a_is_can` is enough to exercise the objective — that plus the local
## unit's team is exactly what `_refresh_ready_objective()` reads. It is NOT enough to
## make the whole HUD agree with itself: `set_round_display()` is called below so the two
## team cards along the top follow the flip, but the YOU card bottom-left reads its role
## off the CHARACTER, which only `main.gd` reassigns on a real round swap. So in the
## offence shot the YOU card still says DEFENSE. That is this harness, not the feature.
func _shoot(tag: String, team_a_is_can: bool) -> void:
	MatchManager.team_a_is_can = team_a_is_can
	_hud.set_round_display(MatchManager.round_number, team_a_is_can)
	# Through the same public call main.gd makes, with no `text` argument — which is the
	# branch that has to derive the objective for itself.
	_hud.show_ready_prompt(true)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var label: Label = _hud.ready_objective
	print("[%s] visible=%s  colour=%s  text=%s" % [tag, label.visible,
		label.get_theme_color("font_color").to_html(false), label.text])
	get_viewport().get_texture().get_image().save_png(
		"%sready_objective_%s.png" % [_out, tag])
