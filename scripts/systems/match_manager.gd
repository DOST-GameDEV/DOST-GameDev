extends Node
class_name MatchManagerScript


signal match_won(winning_slot: int)
signal round_started(round_number: int, defender_slot: int)
signal round_intermission_started(next_round_number: int, next_defender_slot: int)
signal score_changed(slot: int, total: int, delta: int, reason: String)

const ROUNDS: int = 4
const PLAYER_COUNT: int = 4

const INTERMISSION_DURATION: float = 3.0

var round_number: int = 0
var defender_slot: int = 0
var scores: Array[int] = [0, 0, 0, 0]

var _intermission_time_left: float = 0.0

func defender_slot_for(which_round: int) -> int:
	return (maxi(1, which_round) - 1) % PLAYER_COUNT

func is_defender_slot(slot: int) -> bool:
	return slot == defender_slot

func score_for(slot: int) -> int:
	if slot < 0 or slot >= scores.size():
		return 0
	return scores[slot]

func add_score(slot: int, points: int, reason: String = "") -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if slot < 0 or slot >= scores.size() or points == 0:
		return
	var total := scores[slot] + points
	if NetworkManager.is_networked():
		_sync_score.rpc(slot, total, points, reason)
	else:
		_apply_score(slot, total, points, reason)

func _apply_score(slot: int, total: int, delta: int, reason: String) -> void:
	if slot < 0 or slot >= scores.size():
		return
	scores[slot] = total
	score_changed.emit(slot, total, delta, reason)

@rpc("authority", "call_local", "reliable")
func _sync_score(slot: int, total: int, delta: int, reason: String) -> void:
	_apply_score(slot, total, delta, reason)

func begin_next_round() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	round_number += 1
	defender_slot = defender_slot_for(round_number)
	if NetworkManager.is_networked():
		_sync_round_started.rpc(round_number, defender_slot, scores)
	else:
		round_started.emit(round_number, defender_slot)

func report_round_result() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if round_number >= ROUNDS:
		_finish_match(_leading_slot())
		return
	var next_round := round_number + 1
	var next_defender := defender_slot_for(next_round)
	if NetworkManager.is_networked():
		_sync_intermission_started.rpc(next_round, next_defender, scores)
	else:
		round_intermission_started.emit(next_round, next_defender)
	_intermission_time_left = INTERMISSION_DURATION

func _leading_slot() -> int:
	var best := -1
	var best_score := -1
	var tied := false
	for slot in range(scores.size()):
		if scores[slot] > best_score:
			best_score = scores[slot]
			best = slot
			tied = false
		elif scores[slot] == best_score:
			tied = true
	return -1 if tied else best

func ranking() -> Array[int]:
	var order: Array[int] = []
	for slot in range(scores.size()):
		order.append(slot)
	order.sort_custom(func(a: int, b: int) -> bool:
		if scores[a] == scores[b]:
			return a < b
		return scores[a] > scores[b])
	return order

func _process(delta: float) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if _intermission_time_left > 0.0:
		_intermission_time_left -= delta
		if _intermission_time_left <= 0.0:
			begin_next_round()

func _finish_match(winning_slot: int) -> void:
	if NetworkManager.is_networked():
		_sync_match_won.rpc(winning_slot, scores)
	else:
		match_won.emit(winning_slot)

@rpc("authority", "call_local", "reliable")
func _sync_round_started(new_round_number: int, new_defender_slot: int,
		new_scores: Array) -> void:
	round_number = new_round_number
	defender_slot = new_defender_slot
	_adopt_scores(new_scores)
	round_started.emit(round_number, defender_slot)

@rpc("authority", "call_local", "reliable")
func _sync_match_won(winning_slot: int, new_scores: Array) -> void:
	_adopt_scores(new_scores)
	match_won.emit(winning_slot)

@rpc("authority", "call_local", "reliable")
func _sync_intermission_started(next_round_number: int, next_defender_slot: int,
		new_scores: Array) -> void:
	_adopt_scores(new_scores)
	round_intermission_started.emit(next_round_number, next_defender_slot)

func _adopt_scores(new_scores: Array) -> void:
	for slot in range(mini(scores.size(), new_scores.size())):
		scores[slot] = int(new_scores[slot])

func reset() -> void:
	round_number = 0
	defender_slot = defender_slot_for(1)
	scores = [0, 0, 0, 0]
	_intermission_time_left = 0.0

