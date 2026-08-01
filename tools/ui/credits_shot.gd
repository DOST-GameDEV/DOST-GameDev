extends Node
## Screenshots the CREDITS panel reached the way a player reaches it — through
## MainMenu.tscn's own CreditsButton, not by loading CreditsPanel.tscn in
## isolation — so this is evidence for § CHECKLIST 1.11 rather than a claim
## that the control is merely in the tree (THE REACHABILITY RULE).
##
##   godot --path . tools/ui/credits_shot.tscn --resolution 1920x1080 -- /out/ [scroll_px]
##
## Writes `credits_from_menu.png`, or `credits_from_menu_scrolled.png` when a
## scroll offset is given.
##
## ⚠️ THE SECOND ARGUMENT WAS ADDED 2026-08-01 BY 🤖 `build ai`, OUT OF ROW
## (`tools/ui/**` is 🖥️ `build ui`'s), and it is additive — omit it and this
## behaves exactly as before. The reason: the panel is a fixed-size scrolling
## control, so **the courtesy credits have never been photographed**. Every
## capture this tool has ever produced stops at the "EVERYTHING ELSE" heading,
## and a taller `--resolution` does not help because the panel does not grow.
## A credit that is only provably in an `Array[Dictionary]` is exactly the
## "the control is added to the tree is not the claim" this file's own header
## warns about — so when a licence line was added below the fold, there was no
## way to see it.

var _out: String = ""
var _scroll: int = 0
var _menu: Control = null
var _settle: int = 0
var _stage: int = 0

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else ""
	_scroll = int(a[1]) if a.size() > 1 else 0
	_menu = load("res://scenes/ui/MainMenu.tscn").instantiate()
	add_child(_menu)
	_settle = 40

func _process(_d: float) -> void:
	if _settle > 0:
		_settle -= 1
		return
	if _stage == 0:
		(_menu.get_node("%CreditsButton") as BaseButton).pressed.emit()
		_stage = 1
		_settle = 20
		return
	var name := "credits_from_menu"
	if _scroll > 0 and _stage == 1:
		# Scroll the panel's own ScrollContainer rather than faking a viewport
		# offset, so what is captured is what the player's mouse wheel reaches.
		var panel := _menu.find_child("CreditsPanel", true, false)
		var box := panel.find_child("Scroll", true, false) as ScrollContainer \
			if panel != null else null
		if box != null:
			box.scroll_vertical = _scroll
		_stage = 2
		_settle = 6
		return
	if _scroll > 0:
		name = "credits_from_menu_scrolled"
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + name + ".png")
	print("wrote " + name)
	get_tree().quit(0)
