extends Node3D
class_name Lata
## The can. **A prop, not a player.** Written 2026-07-31 on branch `HARRYDAKS`.

## ---------------------------------------------------------------------------
## ⚠️⚠️ THIS REPLACES A 2 868-LINE `CharacterBase`. That is the point of the file.
##
## The lata used to be a full player unit: it had a seat in the lobby, a camera
## rig, a roster entry, stamina, a dash, a shockwave, an evade, a self-right
## window, a knockback solver and an AI controller. It was the "objects are
## players" thesis, and it is deleted — 🧑 2026-07-31: *"we're making the game way
## simpler basically, there were so many skills and shit earlier, it was too
## complicated and far from tumbang preso"*, and *"drop ... slipper being a
## character and can being a character"*.
##
## WHAT A LATA ACTUALLY HAS TO DO, and therefore all this file does:
##   1. stand up or lie down, and say which;
##   2. be hittable by a thrown slipper;
##   3. hold an interaction ring the Defender stands in to reset it.
##
## ⚠️ `is_upright` IS THE MOST-READ FLAG IN THE GAME and it gates four separate
## rules — the throw (`RoundManager.can_throw`), the tag (`_step_tag`), passive
## defence scoring, and the reset channel. It is therefore host-authoritative and
## **replicated through an explicit RPC rather than a `MultiplayerSynchronizer`
## property**. That is not a style preference: a synchronizer writes a property
## DIRECTLY, so a setter's `signal` never fires on the peer that RECEIVED the
## value. That exact defect cost this project a whole session once already — one
## setter, three symptoms (see § LOG, `CharacterBase.state`, 2026-07-30) — and
## every listener here is a HUD row or an audio cue that has to fire on all four
## machines, not just the host's.
## ---------------------------------------------------------------------------

signal upright_changed(now_upright: bool)

## How close the Defender must be to channel a reset. Generous on purpose: the
## channel already costs 2.5 s of standing still, which is the real price, and a
## ring you keep sliding out of turns one commitment into a positioning minigame.
const INTERACTION_RADIUS: float = 1.6
## How long the Defender must hold E in the ring to stand it back up.
## `Design.md` §Defender.
const RESET_CHANNEL_TIME: float = 2.5
## Degrees the visual tips over by when it goes down. Not a ragdoll — a rotation,
## which is what the predecessor settled on too after measuring that a simulated
## one was unreadable at spectator distance.
const DOWNED_TILT_DEG: float = 88.0
## How long the topple animation takes. Long enough to read from across the
## arena, short enough that the +100 toast and the fall are the same beat.
const TOPPLE_TIME: float = 0.22

@onready var _visual: Node3D = $Visual
@onready var _hurtbox: Area3D = $Hurtbox

## Host-authoritative. Never written directly on a client — see the header.
var is_upright: bool = true
## Where the lata belongs. Captured at `_ready()` from wherever the map put it, so
## a map that moves the base circle moves the lata's home with it and no constant
## here has to agree with a `.tscn`.
var home_position: Vector3 = Vector3.ZERO

var _topple_tween: Tween = null

func _ready() -> void:
	home_position = global_position
	# The host owns the lata outright. There is no owning player to hand it to —
	# that is the whole difference between this and what it replaced.
	set_multiplayer_authority(1)
	_apply_upright_visual(true, false)

## Radius test rather than an `Area3D`, for the same reason `RoundManager._step_tag`
## is: this is asked on the host, about the host's own view of a position, on the
## frame the answer is used. An overlap signal would answer about whichever peer
## owns the body and one frame late.
func is_in_ring(world_position: Vector3) -> bool:
	var flat := Vector3(world_position.x - global_position.x, 0.0,
		world_position.z - global_position.z)
	return flat.length() <= INTERACTION_RADIUS

## True when a Defender standing here could start a reset channel: the lata is
## down, and they are in the ring.
func can_be_reset_by(who: CharacterBase) -> bool:
	if who == null or is_upright:
		return false
	if not who.is_defender:
		return false
	if not who.can_act():
		return false
	return is_in_ring(who.global_position)

## ---------------------------------------------------------------------------
## THE TWO STATE CHANGES. Both host-only, both routed through `RoundManager` so
## the score and the state change cannot disagree about whether they happened.
## ---------------------------------------------------------------------------

## Called by `slipper.gd` when a thrown slipper connects. `by_slot` is the
## slipper's owner. Returns true if this hit actually put it over, so the caller
## can decide whether to play an impact or a knockdown.
func host_knock_down(by_slot: int) -> bool:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return false
	if not is_upright:
		return false
	_broadcast_upright(false)
	RoundManager.host_note_lata_knocked(by_slot)
	return true

## Called by `carrier.gd` when the Defender's 2.5 s channel completes.
func host_restore() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	if is_upright:
		return
	# Back on the mark AND upright, in that order. A lata that stands up where it
	# was knocked to is a lata the next throw cannot miss.
	_broadcast_home()
	_broadcast_upright(true)
	RoundManager.host_note_lata_restored()

func host_reset_for_new_round() -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	_broadcast_home()
	_broadcast_upright(true)

func _broadcast_upright(now_upright: bool) -> void:
	if NetworkManager.is_networked():
		_rpc_set_upright.rpc(now_upright)
	else:
		_apply_upright(now_upright)

func _broadcast_home() -> void:
	if NetworkManager.is_networked():
		_rpc_place.rpc(home_position)
	else:
		_apply_place(home_position)

@rpc("authority", "call_local", "reliable")
func _rpc_set_upright(now_upright: bool) -> void:
	_apply_upright(now_upright)

@rpc("authority", "call_local", "reliable")
func _rpc_place(where: Vector3) -> void:
	_apply_place(where)

func _apply_upright(now_upright: bool) -> void:
	if is_upright == now_upright:
		return
	is_upright = now_upright
	_apply_upright_visual(now_upright, true)
	AudioManager.play_at("can_knockdown" if not now_upright else "reset_complete",
		global_position)
	upright_changed.emit(now_upright)

func _apply_place(where: Vector3) -> void:
	global_position = where

## The whole visual state machine. Upright is identity; down is a tip about the
## X axis plus a drop to the floor, so the silhouette from a spectator camera is
## unambiguous at any distance — that readability is the reason it is 88° and not
## a subtle lean.
func _apply_upright_visual(now_upright: bool, animate: bool) -> void:
	if _visual == null:
		return
	var target := Vector3.ZERO if now_upright else Vector3(deg_to_rad(DOWNED_TILT_DEG), 0.0, 0.0)
	if _topple_tween != null and _topple_tween.is_valid():
		_topple_tween.kill()
	if not animate:
		_visual.rotation = target
		return
	_topple_tween = create_tween()
	_topple_tween.set_trans(Tween.TRANS_BACK if now_upright else Tween.TRANS_BOUNCE)
	_topple_tween.set_ease(Tween.EASE_OUT)
	_topple_tween.tween_property(_visual, "rotation", target, TOPPLE_TIME)

## Late joiners get the current state pushed by `main.gd`'s sync path; this is the
## receiving half, kept separate from `_rpc_set_upright` so a correction never
## replays the audio and the topple animation.
func adopt_state(now_upright: bool, where: Vector3) -> void:
	global_position = where
	if is_upright != now_upright:
		is_upright = now_upright
		_apply_upright_visual(now_upright, false)
		upright_changed.emit(now_upright)
