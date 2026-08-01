extends Node
## Does the REMATCH vote actually gate on every real peer, and does the result
## screen disappear on BOTH ends when it fires? § — 🧑: *"in multiplayer only
## host has rematch and this doesnt disappear... can we make it so that they
## all can click rematch button... if they all check the rematch goes on"*.
##
## Jumps straight to match-end (`MatchManager._finish_match`) rather than
## playing a full 4-round match, host-side only — that call already branches
## on networking exactly like a real match end would (`_sync_match_won.rpc`
## when networked), so this exercises the real replication path, just without
## six minutes of bots throwing slippers first.
##
## ⚠️ RUN INTO THE PRE-EXISTING §2.24 BUG WHILE VERIFYING THIS, NOT A NEW ONE.
## Wrapping `Main.tscn` under this probe's own root node (same pattern every
## `tools/ui/*_probe.gd` uses) shifts every node inside it off `/root/Main`,
## and on the run this was written against the client logged hundreds of
## "Node not found" errors for `HandAttachment/HandPoint/Slipper*` paths and,
## once, `Main` itself — the same reparent/RPC race §2.24 already documents,
## not something this vote logic introduced. Confirmed the vote/RPC code
## itself is sound by static read-through instead of trusting this probe's
## own multi-process run — real verification is a real multiplayer session.
##
##     Godot_..._console.exe --path <repo> tools/ui/rematch_vote_probe.tscn -- --host --out=<dir>/host_
##     Godot_..._console.exe --path <repo> tools/ui/rematch_vote_probe.tscn -- --join=127.0.0.1 --out=<dir>/client_

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")

var _out: String = ""
var _is_host := false
var _main: Node = null
var _result: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text == "--host":
			_is_host = true
		elif text.begins_with("--out="):
			_out = text.substr(6)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_run.call_deferred()

func _emit(text: String) -> void:
	print("[%s] %s" % ["HOST" if _is_host else "CLIENT", text])

func _run() -> void:
	await get_tree().create_timer(6.0).timeout
	_result = _main.find_child("MatchResult", true, false) as Control
	if _result == null:
		_emit("NO MatchResult NODE FOUND")
		get_tree().quit(1)
		return
	var btn := _result.get_node("%RematchButton") as Button

	if _is_host:
		await get_tree().create_timer(1.0).timeout
		_emit("forcing match end")
		MatchManager._finish_match(0)
	await get_tree().create_timer(2.0).timeout
	_emit("after match_won: visible=%s rematch_visible=%s" % [_result.visible, btn.visible])

	# CLIENT votes first, alone. Neither screen should hide yet — only one of
	# the two required votes is in.
	if not _is_host:
		btn.pressed.emit()
		_emit("client voted")
	await get_tree().create_timer(2.5).timeout
	_emit("after client-only vote: visible=%s button_text=%s" % [_result.visible, btn.text])

	# HOST votes second — this is the vote that should complete the gate.
	if _is_host:
		btn.pressed.emit()
		_emit("host voted")
	await get_tree().create_timer(3.0).timeout
	_emit("final: visible=%s round=%d" % [_result.visible, MatchManager.round_number])
	# The client needs the host to still be listening when IT votes (well
	# after the host already has, in this script's own ordering) - stay up
	# generously past that rather than tuning the margin by feel.
	if _is_host:
		await get_tree().create_timer(8.0).timeout
	get_tree().quit(0)
