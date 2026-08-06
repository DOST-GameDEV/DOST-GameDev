extends Node
class_name RoundManagerScript


signal round_ended(round_number: int)
signal lata_knocked(by_slot: int)
signal lata_restored()
signal attacker_tagged(defender_slot: int, victim_slot: int)

const ROUND_TIME: float = 90.0

const SYNC_INTERVAL: float = 0.25

const SCORE_LATA_KNOCKED: int = 100
const SCORE_SABOTAGE: int = 50
const SCORE_TAG: int = 100
const SCORE_DEFENSE_PER_TICK: int = 10
const DEFENSE_TICK_INTERVAL: float = 1.0

const TAG_STUN_TIME: float = 5.0
const SABOTAGE_WINDOW: float = 2.5
const THROW_RESTORE_COOLDOWN: float = 1.25

var time_left: float = ROUND_TIME
var round_active: bool = false
var _sync_accum: float = 0.0
var _defense_accum: float = 0.0
var _throw_cooldown_left: float = 0.0

var lata: Lata = null
var _players: Array = [null, null, null, null]
var _shove_credit: Dictionary = {}
var _clock: float = 0.0

func register_player(who: CharacterBase) -> void:
	if who == null:
		return
	var slot := who.player_slot
	if slot < 0 or slot >= _players.size():
		return
	_players[slot] = who

func clear_players() -> void:
	_players = [null, null, null, null]
	_shove_credit.clear()

func player_at(slot: int) -> CharacterBase:
	if slot < 0 or slot >= _players.size():
		return null
	var who = _players[slot]
	return who if is_instance_valid(who) else null

func players() -> Array:
	var live: Array = []
	for who in _players:
		if is_instance_valid(who):
			live.append(who)
	return live

func defender() -> CharacterBase:
	return player_at(MatchManager.defender_slot)

func throw_cooldown_left() -> float:
	return _throw_cooldown_left

func can_throw(who: CharacterBase) -> bool:
	if who == null or not round_active:
		return false
	if who.is_defender:
		return false
	if not who.holding_slipper():
		return false
	if lata == null or not lata.is_upright:
		return false
	if _throw_cooldown_left > 0.0:
		return false
	return not who.is_inside_box()


func note_shove(victim_slot: int, shover_slot: int) -> void:
	if victim_slot < 0 or shover_slot < 0 or victim_slot == shover_slot:
		return
	_shove_credit[victim_slot] = {"by": shover_slot, "at": _clock}

func _consume_shove_credit(victim_slot: int) -> int:
	if not _shove_credit.has(victim_slot):
		return -1
	var record: Dictionary = _shove_credit[victim_slot]
	_shove_credit.erase(victim_slot)
	if _clock - float(record.get("at", -999.0)) > SABOTAGE_WINDOW:
		return -1
	return int(record.get("by", -1))


func host_note_lata_knocked(by_slot: int) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if not round_active:
		return
	if by_slot >= 0 and by_slot != MatchManager.defender_slot:
		MatchManager.add_score(by_slot, SCORE_LATA_KNOCKED, "LATA DOWN")
	if NetworkManager.is_networked():
		_sync_lata_event.rpc(true, by_slot)
	else:
		lata_knocked.emit(by_slot)

func host_note_lata_restored() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	_throw_cooldown_left = THROW_RESTORE_COOLDOWN
	if NetworkManager.is_networked():
		_sync_lata_event.rpc(false, -1)
	else:
		lata_restored.emit()

@rpc("authority", "call_local", "reliable")
func _sync_lata_event(knocked: bool, by_slot: int) -> void:
	if knocked:
		lata_knocked.emit(by_slot)
	else:
		_throw_cooldown_left = THROW_RESTORE_COOLDOWN
		lata_restored.emit()

func _step_tag() -> void:
	pass

func host_resolve_lunge_tag(taya: CharacterBase, victim: CharacterBase) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if not round_active or taya == null or victim == null:
		return
	_resolve_tag(taya, victim)

func _resolve_tag(taya: CharacterBase, victim: CharacterBase) -> void:
	MatchManager.add_score(taya.player_slot, SCORE_TAG, "TAG")
	var saboteur := _consume_shove_credit(victim.player_slot)
	if saboteur >= 0 and saboteur != victim.player_slot:
		MatchManager.add_score(saboteur, SCORE_SABOTAGE, "SABOTAGE")
	victim.host_apply_tag_penalty(TAG_STUN_TIME)
	if NetworkManager.is_networked():
		_sync_tag.rpc(taya.player_slot, victim.player_slot)
	else:
		attacker_tagged.emit(taya.player_slot, victim.player_slot)

@rpc("authority", "call_local", "reliable")
func _sync_tag(defender_slot: int, victim_slot: int) -> void:
	attacker_tagged.emit(defender_slot, victim_slot)


func host_broadcast_tag_penalty(victim_slot: int, stun: float, safe_spot: Vector3) -> void:
	if NetworkManager.is_networked():
		_sync_tag_penalty.rpc(victim_slot, stun, safe_spot)
	else:
		_apply_tag_penalty_to(victim_slot, stun, safe_spot)

@rpc("authority", "call_local", "reliable")
func _sync_tag_penalty(victim_slot: int, stun: float, safe_spot: Vector3) -> void:
	_apply_tag_penalty_to(victim_slot, stun, safe_spot)

func _apply_tag_penalty_to(victim_slot: int, stun: float, safe_spot: Vector3) -> void:
	var who := player_at(victim_slot)
	if who != null:
		who.apply_tag_penalty_local(stun, safe_spot)

func host_broadcast_shove(victim_slot: int, impulse: Vector3, stun: float) -> void:
	if NetworkManager.is_networked():
		_sync_shove.rpc(victim_slot, impulse, stun)
	else:
		_apply_shove_to(victim_slot, impulse, stun)

@rpc("authority", "call_local", "reliable")
func _sync_shove(victim_slot: int, impulse: Vector3, stun: float) -> void:
	_apply_shove_to(victim_slot, impulse, stun)

func _apply_shove_to(victim_slot: int, impulse: Vector3, stun: float) -> void:
	var who := player_at(victim_slot)
	if who != null:
		who.apply_shove_local(impulse, stun)

func host_broadcast_block(blocker_slot: int, impulse: Vector3) -> void:
	if NetworkManager.is_networked():
		_sync_block.rpc(blocker_slot, impulse)
	else:
		_apply_block_to(blocker_slot, impulse)

@rpc("authority", "call_local", "reliable")
func _sync_block(blocker_slot: int, impulse: Vector3) -> void:
	_apply_block_to(blocker_slot, impulse)

func _apply_block_to(blocker_slot: int, impulse: Vector3) -> void:
	var who := player_at(blocker_slot)
	if who != null:
		who.apply_block_local(impulse)

func host_broadcast_shove_cooldown(shover_slot: int) -> void:
	if NetworkManager.is_networked():
		_sync_shove_cooldown.rpc(shover_slot)
	else:
		_apply_shove_cooldown_to(shover_slot)

@rpc("authority", "call_local", "reliable")
func _sync_shove_cooldown(shover_slot: int) -> void:
	_apply_shove_cooldown_to(shover_slot)

func _apply_shove_cooldown_to(shover_slot: int) -> void:
	var who := player_at(shover_slot)
	if who != null:
		who.apply_shove_cooldown_local()


func start_round() -> void:
	time_left = ROUND_TIME
	_clock = 0.0
	_defense_accum = 0.0
	_throw_cooldown_left = 0.0
	_shove_credit.clear()
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	round_active = true
	_sync_accum = 0.0
	for who in players():
		who.reset_for_new_round()
	if lata != null:
		lata.host_reset_for_new_round()
	if NetworkManager.is_networked():
		_sync_state.rpc(time_left, round_active)

func _physics_process(_delta: float) -> void:
	_step_tag()

func _process(delta: float) -> void:
	if not round_active:
		return
	_clock += delta
	if _throw_cooldown_left > 0.0:
		_throw_cooldown_left = maxf(0.0, _throw_cooldown_left - delta)
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	time_left = maxf(0.0, time_left - delta)
	_step_passive_defense(delta)
	if NetworkManager.is_networked():
		_sync_accum += delta
		if _sync_accum >= SYNC_INTERVAL:
			_sync_accum = 0.0
			_sync_state.rpc(time_left, round_active, _throw_cooldown_left)
	if time_left <= 0.0:
		_on_time_up()

func _step_passive_defense(delta: float) -> void:
	if lata == null or not lata.is_upright:
		_defense_accum = 0.0
		return
	_defense_accum += delta
	while _defense_accum >= DEFENSE_TICK_INTERVAL:
		_defense_accum -= DEFENSE_TICK_INTERVAL
		MatchManager.add_score(MatchManager.defender_slot, SCORE_DEFENSE_PER_TICK, "DEFENSE")

func _on_time_up() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if not round_active:
		return
	round_active = false
	if NetworkManager.is_networked():
		_sync_state.rpc(time_left, round_active)
		_sync_round_ended.rpc(MatchManager.round_number)
	else:
		round_ended.emit(MatchManager.round_number)
	MatchManager.report_round_result()

@rpc("authority", "call_local", "reliable")
func _sync_round_ended(which_round: int) -> void:
	round_active = false
	round_ended.emit(which_round)

func reset() -> void:
	clear_players()
	lata = null
	time_left = ROUND_TIME
	round_active = false
	_sync_accum = 0.0
	_defense_accum = 0.0
	_throw_cooldown_left = 0.0
	_clock = 0.0

@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_state(new_time_left: float, new_round_active: bool,
		new_throw_cooldown: float = 0.0) -> void:
	time_left = new_time_left
	round_active = new_round_active
	_throw_cooldown_left = new_throw_cooldown

