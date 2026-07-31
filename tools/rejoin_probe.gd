extends Node3D
## REJOIN ACCEPTANCE — the blank screen a reconnecting player used to get.
##
## 🧑 2026-07-31: *"blank screen when rejoining sa ongoing na match."*
##
## ⚠️⚠️ WHAT THIS PROBE IS ACTUALLY TESTING IS AN ORDERING, NOT A NETWORK.
##
## A rejoining peer loads a fresh `Main.tscn`, so its own `_index_to_character` starts
## EMPTY and the four characters reach it as `MultiplayerSpawner` deliveries — while the
## host's `_rpc_reclaim_character(index, peer_id)` is a reliable RPC racing them. When the
## RPC lost that race it hit `if character == null: return` and **nothing ever retried**:
## authority never migrated on that peer, so `_refresh_rig_ownership()` never ran, so no
## `CameraRig` ever became current and the player looked at whatever the engine fell back
## to. The seat bookkeeping (B-65's token key) had already succeeded, which is exactly why
## it read as "the match is gone" rather than as a seating bug.
##
## So the defect is reproducible in ONE process: deliver the reclaim FIRST, deliver the
## character SECOND, and ask whether the peer ends up owning it and looking through it.
## That is what the three checks below do, through `main.gd`'s real functions —
## `_rpc_reclaim_character`, `_build_spawn_data` and `_build_networked_character` — rather
## than through a copy of their logic.
##
## ⚠️ WHAT IT DOES NOT COVER, said plainly: this is a single process. It does not exercise
## ENet, real packet ordering, or a genuine disconnect/reconnect. The two-peer test — join,
## drop, rejoin mid-match, confirm the camera comes back — is still owed and is filed as
## § CHECKLIST 4.24. This probe proves the ordering contract; it does not prove the wire.

var _main: Node
var _pass: int = 0
var _fail: int = 0

## ⚠️ TOLERATES `_pending_reclaims` NOT EXISTING, ON PURPOSE — that is what makes this a
## regression test rather than an assertion about the build it was written on. Against the
## pre-fix `main.gd` the field is absent, `get()` returns Nil, and a typed assignment would
## CRASH the probe. A crash is not a measurement: it says "this code is different", not
## "this code is broken". Falling back to `{}` lets the same probe run on both versions and
## report the actual defect — the reclaim silently dropped, and no camera at the end of it.
func _pending() -> Dictionary:
	var value: Variant = _main.get("_pending_reclaims")
	return value if value is Dictionary else {}

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  %s  %s%s" % ["PASS" if ok else "FAIL", label, ("   " + detail) if detail != "" else ""])

func _ready() -> void:
	print("=== REJOIN ACCEPTANCE (the reclaim/spawn race) ===")
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout

	var peer_id := multiplayer.get_unique_id()
	var index_to_character: Dictionary = _main.get("_index_to_character")
	# Any seat this process has not built through the networked spawn path. Locally the
	# four units are authored in the scene and never pass through
	# `_build_networked_character`, so this dictionary is empty and seat 3 is free —
	# which is precisely the state a freshly-loaded rejoining peer is in.
	var index := 3
	while index_to_character.has(index) and index < 4:
		index += 1
	if index >= 4:
		print("  HARNESS: every seat already built; cannot stage the race.")
		get_tree().quit(1)
		return

	# ---- 1. THE RECLAIM ARRIVES FIRST, for a character this peer does not have yet.
	# Before the fix this returned silently and the rejoin was lost with no error.
	_main.call("_rpc_reclaim_character", index, peer_id)
	var pending := _pending()
	_check("a reclaim for an unknown seat is REMEMBERED, not dropped",
		pending.has(index) and int(pending[index]) == peer_id,
		"_pending_reclaims=%s" % str(pending))

	# ---- 2. THE CHARACTER ARRIVES SECOND, through the real spawn function.
	var data: Dictionary = _main.call("_build_spawn_data", peer_id, index)
	var character: CharacterBase = _main.call("_build_networked_character", data)
	if character == null:
		print("  HARNESS: spawn function returned null.")
		get_tree().quit(1)
		return
	# The spawner would normally parent it; do the same so the rig can become current.
	var players := _main.get_node_or_null("Players")
	(players if players != null else _main).add_child(character)
	pending = _pending()
	_check("the remembered reclaim is CONSUMED when that seat turns up",
		not pending.has(index), "_pending_reclaims=%s" % str(pending))

	# The replay is deferred on purpose — a spawn_function runs before the node is in the
	# tree, and `Camera3D.current` on an out-of-tree camera does nothing at all.
	await get_tree().process_frame
	await get_tree().process_frame

	# ---- 3. THE OUTCOME THE PLAYER ACTUALLY SEES.
	_check("the rejoining peer OWNS the character",
		character.get_multiplayer_authority() == peer_id,
		"authority=%d want=%d" % [character.get_multiplayer_authority(), peer_id])

	var rig := character.get_node_or_null("CameraRig")
	var rig_active: bool = rig != null and bool(rig.get("_active"))
	var looking_through := false
	if rig != null:
		var fpp := rig.get("fpp_camera") as Camera3D
		var tpp := rig.get("tpp_camera") as Camera3D
		looking_through = (fpp != null and fpp.current) or (tpp != null and tpp.current)
	_check("and is LOOKING THROUGH it — this is the blank screen",
		rig_active and looking_through,
		"rig_active=%s camera_current=%s" % [str(rig_active), str(looking_through)])

	print("=== REJOIN PROBE: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
