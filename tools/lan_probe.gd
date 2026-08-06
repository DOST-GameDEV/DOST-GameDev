extends Node

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
	print("[lan_probe] local IPv4 interfaces:")
	for entry in IP.get_local_interfaces():
		for address in entry.get("addresses", []):
			if not (":" in String(address)):
				print("    %-16s %s" % [address, entry.get("friendly", "?")])
	print("[lan_probe] a beacon would go to: %s" % ", ".join(LanBeacon._broadcast_destinations()))
	if _role == "host" or _role == "both":
		SettingsManager.player_name = "PROBE"
		var err := NetworkManager.host_game()
		print("[lan_probe] host_game() -> %s | advertising=%s"
			% [error_string(err), NetworkManager.is_host()])
		print("[lan_probe] broadcasting to: %s" % ", ".join(LanBeacon._destinations))
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

