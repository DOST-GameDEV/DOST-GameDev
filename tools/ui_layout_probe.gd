extends Node

## LOOK AT THE FRONT END, at the real 1920x1080 base resolution.
##
## Every UI item in this pass is a LAYOUT claim — the BACK button not running off
## the bottom, three explanation lines fitting in the left column, the trait
## meters fitting inside the wood panel — and a layout claim is the one kind that
## a parse check, a probe and a code review all pass while the screen is still
## wrong. `Dev_Plan.md` §1 is explicit that this project has shipped code that
## was written, reviewed and never run.
##
## Renders both setup screens and reports whether anything landed outside the
## viewport, which is the specific failure being fixed.
##
##     godot --path . tools/ui_layout_probe.tscn --resolution 1920x1080 -- C:\tmp\

## `tab` is which CHARACTER tab to open before rendering, or -1 for "leave it".
## The tsinelas tab is listed separately because it is the one the report was
## about ("the weird viewing angle for the slippers") and it is also the hardest
## subject to frame — 0.432 long by 0.078 tall against a 4-unit standing figure.
const SCREENS := [
	["match_setup", "res://scenes/ui/MatchSetup.tscn", -1],
	["character_select", "res://scenes/ui/CharacterSelect.tscn", 0],
	["character_select_lata", "res://scenes/ui/CharacterSelect.tscn", 1],
	["character_select_tsinelas", "res://scenes/ui/CharacterSelect.tscn", 2],
]

var _out := ""
var _i := 0
var _settle := 0
var _screen: Node = null
var _fails := 0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else ""
	# Solo, so MatchSetup takes the branch that needs no ENet session at all.
	GameLaunch.pending_action = "local"
	_load()

func _load() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
	_screen = (load(String(SCREENS[_i][1])) as PackedScene).instantiate()
	add_child(_screen)
	var tab: int = int(SCREENS[_i][2])
	if tab >= 0 and _screen is CharacterSelect:
		# Through the screen's own handler rather than by poking its state, so
		# what is rendered is what a player clicking that tab would actually get.
		(_screen as CharacterSelect)._on_tab_pressed(tab)
	_settle = 20

func _process(_delta: float) -> void:
	if _settle > 0:
		_settle -= 1
		return
	set_process(false)
	_report(String(SCREENS[_i][0]))
	await RenderingServer.frame_post_draw
	if _out != "":
		get_viewport().get_texture().get_image().save_png(
			_out + "ui_" + String(SCREENS[_i][0]) + ".png")
	_i += 1
	if _i >= SCREENS.size():
		print("RESULT: ", "FAIL — %d control(s) outside the viewport" % _fails
			if _fails > 0 else "PASS — every checked control is on screen")
		get_tree().quit(1 if _fails > 0 else 0)
		return
	_load()
	set_process(true)

## Every named control that has ever been reported as off-screen, plus the ones
## this pass moved. Checked against the VIEWPORT rect rather than against a
## parent, because "off the bottom of the screen" is what was reported and a
## control can be perfectly placed inside a container that is itself too tall.
const WATCHED := ["BackButton", "PrimaryButton", "StartButton", "ConfirmButton",
	"DetailLabel", "TraitRows", "StatusLabel"]

func _report(tag: String) -> void:
	var screen_size := Vector2(get_viewport().get_visible_rect().size)
	print("[%s] viewport %.0fx%.0f" % [tag, screen_size.x, screen_size.y])
	# The 3D framing, not just the 2D rects — "the subject is cropped" is a camera
	# fact and none of the Control rects below can see it.
	var preview := _screen.find_child("CharacterPreview", true, false) as CharacterPreview
	if preview != null:
		var sub := preview.get_node_or_null("SubViewport") as SubViewport
		var cam := preview.get_node_or_null("SubViewport/Camera3D") as Camera3D
		if sub != null and cam != null:
			print("  preview  container=%s subviewport=%s cam_pos=%s fov=%.1f h_offset=%.3f" % [
				str(preview.size), str(sub.size), str(cam.position), cam.fov, cam.h_offset])
	for name in WATCHED:
		var node := _screen.find_child(name, true, false) as Control
		if node == null:
			continue
		var rect := node.get_global_rect()
		var inside := rect.position.y >= -1.0 and rect.end.y <= screen_size.y + 1.0 \
			and rect.position.x >= -1.0 and rect.end.x <= screen_size.x + 1.0
		if not inside:
			_fails += 1
		print("  %-14s x %6.0f..%-6.0f  y %6.0f..%-6.0f  %s" % [
			name, rect.position.x, rect.end.x, rect.position.y, rect.end.y,
			"ok" if inside else "** OFF SCREEN **"])
