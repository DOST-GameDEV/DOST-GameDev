extends Node
## DOES LAN DISCOVERY ACTUALLY FIND A HOST? **Written 2026-08-02.**
##
##     Godot_v4.7.1-stable_win64_console.exe --path <repo> tools/lan_probe.tscn -- \
##         role=host
##     Godot_v4.7.1-stable_win64_console.exe --path <repo> tools/lan_probe.tscn -- \
##         role=listen secs=8
##
## | argument | default | what it does |
## |---|---|---|
## | `role=host/listen/both` | both | advertise, listen, or do both in one process |
## | `secs=N` | 8 | seconds to run before printing and exiting |
##
## ---------------------------------------------------------------------------
## ⚠️⚠️ `role=both` IS THE WEAK TEST AND IT IS STILL WORTH RUNNING. One process that
## broadcasts and listens proves the packet is well-formed, the magic and version gates
## pass, and `servers()` shapes a row — but a loopback delivery does not prove the packet
## crossed a wire. `role=host` on one machine and `role=listen` on another is the real
## check, which is why the roles are separable at all.
##
## ⚠️ IT DOES NOT OPEN AN ENET SERVER. `LanBeacon._step_advertise` stops itself unless
## `NetworkManager.is_host()`, so a probe that only called `start_advertising()` would
## broadcast exactly zero packets and pass for the wrong reason. `role=host` therefore
## calls the real `NetworkManager.host_game()` — the same line the lobby calls — and the
## beacon starts because that function starts it, which is the wiring under test.
## ---------------------------------------------------------------------------

var _role: String = "both"
var _secs: float = 8.0
var _elapsed: float = 0.0
var _changes: int = 0
var _last: Array = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("role="):
			_role = arg.substr(5)
		elif arg.begins_with("secs="):
			_secs = float(arg.substr(5))
	print("[lan_probe] role=%s secs=%.0f port=%d" % [_role, _secs, LanBeaconScript.DISCOVERY_PORT])
	if _role == "host" or _role == "both":
		SettingsManager.player_name = "PROBE"
		var err := NetworkManager.host_game()
		print("[lan_probe] host_game() -> %s | advertising=%s"
			% [error_string(err), NetworkManager.is_host()])
	if _role == "listen" or _role == "both":
		LanBeacon.start_listening()
		print("[lan_probe] listening=%s" % LanBeacon.is_listening())
		LanBeacon.servers_changed.connect(_on_changed)

func _on_changed() -> void:
	_changes += 1
	_last = LanBeacon.servers()
	print("[lan_probe] t=%.1fs  servers_changed -> %d visible" % [_elapsed, _last.size()])
	for entry in _last:
		print("    %s:%d  %s  %d/%d  %s" % [
			entry.get("ip", ""), int(entry.get("port", 0)), entry.get("name", ""),
			int(entry.get("players", 0)), int(entry.get("max", 0)),
			"IN A MATCH" if bool(entry.get("in_match", false)) else "IN THE LOBBY"])

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < _secs:
		return
	set_process(false)
	print("=== lan_probe: role=%s, %.1f s ===" % [_role, _elapsed])
	print("  servers_changed fired   %d" % _changes)
	print("  visible at the end      %d" % _last.size())
	# ⚠️ THE SIGNAL COUNT IS PART OF THE RESULT, NOT DECORATION. A beacon lands every
	# second, and `_emit_if_changed` exists so an UNCHANGED lobby stays quiet. Over 8 s
	# that is ~8 packets and should be ONE emission; a count that tracks the packets
	# means the de-dupe is dead and the list will fight the mouse for the row under it.
	if _role != "host":
		if _last.is_empty():
			print("  >> FAIL: nothing discovered.")
		elif _changes > 3:
			print("  >> FAIL: %d emissions for a static lobby — _emit_if_changed is not de-duping." % _changes)
		else:
			print("  >> PASS: %d server(s), %d emission(s)." % [_last.size(), _changes])
	NetworkManager.disconnect_network()
	LanBeacon.stop_listening()
	get_tree().quit(0)
