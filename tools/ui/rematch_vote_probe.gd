extends Node

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

	if not _is_host:
		btn.pressed.emit()
		_emit("client voted")
	await get_tree().create_timer(2.5).timeout
	_emit("after client-only vote: visible=%s button_text=%s" % [_result.visible, btn.text])

	if _is_host:
		btn.pressed.emit()
		_emit("host voted")
	await get_tree().create_timer(3.0).timeout
	_emit("final: visible=%s round=%d" % [_result.visible, MatchManager.round_number])
	if _is_host:
		await get_tree().create_timer(8.0).timeout
	get_tree().quit(0)

