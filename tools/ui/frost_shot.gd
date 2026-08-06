extends Node
## § THE STUN FROST, on a real body in a real match, photographed at both ends.
##
##     godot --path <repo> tools/ui/frost_shot.tscn -- out=/tmp/
##
## ⚠️ PLAIN EXE, NOT --headless. The whole thing is two shaders; a run with no
## rendering device proves nothing about either.
##
## ⚠️ IT STUNS THE **LOCAL** ATTACKER ON PURPOSE. The two halves go to different
## audiences — the body ices for everybody, the screen frosts only for the victim —
## so the only camera that sees both at once is the stunned player's own.
var _out: String = ""
var _fails: int = 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("out="):
			_out = String(a).substr(4)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout

	var me: CharacterBase = null
	for node in main.find_children("*", "CharacterBase", true, false):
		var c := node as CharacterBase
		if c != null and c.is_person and not c.is_defender and not c.is_ai_driven():
			me = c
			break
	_check(me != null, "found the local human attacker")
	if me == null:
		_finish()
		return
	var visual: CharacterVisual = null
	for n in me.find_children("*", "CharacterVisual", true, false):
		visual = n
		break
	_check(visual != null, "it has a CharacterVisual")

	# ⚠️ THE GAP THIS PROBE EXISTS FOR. A Person wears `person_palette.gdshader`, which
	# `_collect_meshes()` used to skip outright — so nothing was duplicated for a body and
	# there was no per-unit material to write frost into. An empty list here means the
	# feature is silently dead, which looks exactly like "nobody got stunned".
	_check(not visual._frost_materials.is_empty(),
		"per-unit frost materials were collected (%d)" % visual._frost_materials.size())

	var hud := main.find_child("HUD", true, false)
	var frost_rect := hud.get_node_or_null("%FrostVignette") as ColorRect if hud != null else null
	_check(frost_rect != null, "the HUD frost vignette exists")

	await _shot("frost_before", "before the tag")
	_check(is_zero_approx(visual._frost_level), "body is unfrosted at rest (%.2f)" % visual._frost_level)
	_check(frost_rect == null or not frost_rect.visible, "screen is clear at rest")

	# The real thing: the tag penalty, through the same call the tag makes.
	me.apply_stagger(RoundManagerScript.TAG_STUN_TIME)
	_check(me.state == CharacterBase.State.STAGGERED, "the attacker is STAGGERED")
	await get_tree().create_timer(0.9).timeout
	await _shot("frost_peak", "0.9s in — frost at full")
	_check(visual._frost_level > 0.85, "body is iced (%.2f)" % visual._frost_level)
	_check(frost_rect != null and frost_rect.visible, "screen frost is up")
	var peak: float = frost_rect.material.get_shader_parameter("coverage") if frost_rect else 0.0
	_check(peak > 0.85, "screen coverage is at full (%.2f)" % peak)

	# ⚠️ AND IT MUST RECEDE. Holding full for five seconds then snapping off is the thing
	# the accessible-status guidance says not to do: the player is never told it is ending.
	await get_tree().create_timer(3.6).timeout   # ~4.5s in, inside the thaw window
	var thaw: float = frost_rect.material.get_shader_parameter("coverage") if frost_rect else 0.0
	await _shot("frost_thaw", "4.5s in — receding")
	_check(thaw < peak, "screen frost is receding (%.2f -> %.2f)" % [peak, thaw])
	_check(visual._frost_level < 0.99, "body is thawing too (%.2f)" % visual._frost_level)

	await get_tree().create_timer(2.0).timeout
	await _shot("frost_after", "after the stun")
	_check(me.state == CharacterBase.State.NORMAL, "the stun ended")
	_check(is_zero_approx(visual._frost_level), "body cleared (%.2f)" % visual._frost_level)
	_check(not frost_rect.visible, "screen cleared")

	# ⚠️ THE BODY HALF NEEDS A DIFFERENT CAMERA. Everything above is the victim's own
	# screen, and in first person a player cannot see their own frozen body — which is
	# precisely why the body half exists at all: it is for the taya who landed the tag.
	# So this stuns SOMEBODY ELSE and looks at them from outside.
	await _shoot_a_bystander(main)
	_finish()

func _shoot_a_bystander(main: Node) -> void:
	var victim: CharacterBase = null
	for node in main.find_children("*", "CharacterBase", true, false):
		var c := node as CharacterBase
		if c != null and c.is_person and not c.is_defender and c.is_ai_driven():
			victim = c
			break
	_check(victim != null, "found another attacker to freeze")
	if victim == null:
		return
	var vis: CharacterVisual = null
	for n in victim.find_children("*", "CharacterVisual", true, false):
		vis = n
		break
	# A camera of our own, close in on the body — the match cameras are wherever the
	# players left them and would photograph the back of somebody's head.
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.global_position = victim.global_position + Vector3(2.9, 2.1, 3.4)
	cam.look_at(victim.global_position + Vector3(0, 1.25, 0))
	cam.fov = 40
	cam.make_current()
	await get_tree().create_timer(0.3).timeout
	await _shot("frost_body_before", "bystander, unfrozen")
	victim.apply_stagger(RoundManagerScript.TAG_STUN_TIME)
	await get_tree().create_timer(1.0).timeout
	await _shot("frost_body_iced", "bystander, tagged and iced")
	_check(vis != null and vis._frost_level > 0.85,
		"the bystander body is iced (%.2f)" % (vis._frost_level if vis else -1.0))

func _shot(name: String, note: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if _out != "":
		get_viewport().get_texture().get_image().save_png("%s%s.png" % [_out, name])
	print("  [shot] %s — %s" % [name, note])

func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])

func _finish() -> void:
	print("[frost probe] %s" % ("ALL CHECKS PASSED" if _fails == 0
		else "*** %d FAILED ***" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)
