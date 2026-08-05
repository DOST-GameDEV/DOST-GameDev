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
## simpler basically, there were so many skills and stuff earlier, it was too
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
## channel already costs `RESET_CHANNEL_TIME` of standing still, which is the real
## price, and a ring you keep sliding out of turns one commitment into a
## positioning minigame.
const INTERACTION_RADIUS: float = 1.6
## How long the Defender must hold E in the ring to stand it back up.
## `Design.md` §Defender.
## ⚠️ 1.5 s SINCE 2026-08-01, DOWN FROM 2.5. 🧑: *"Hold E over a fallen Lata for 1.5
## seconds (reduced from 2.5s) to restore it upright and re-enable tagging."*
##
## It moves with the lunge, and the two are one decision. The taya's job got an
## active verb that costs them a charge and a cooldown; leaving the reset at 2.5 s
## would have meant a taya who spends the round standing still doing the one thing
## they cannot be interrupted out of. A shorter channel puts them back on their feet
## and into lunge range sooner, which is where the round is now decided.
const RESET_CHANNEL_TIME: float = 1.5
## Degrees the visual tips over by when it goes down. Not a ragdoll — a rotation,
## which is what the predecessor settled on too after measuring that a simulated
## one was unreadable at spectator distance.
const DOWNED_TILT_DEG: float = 88.0
## How long the topple animation takes. Long enough to read from across the
## arena, short enough that the +100 toast and the fall are the same beat.
const TOPPLE_TIME: float = 0.22

## ---------------------------------------------------------------------------
## ⚠️⚠️ THE HIT WINDOW — THE NUMBER THAT DECIDES EVERY KNOCKDOWN IN THE GAME, AND
## UNTIL 2026-08-01 IT WAS AN UNNAMED LITERAL IN ANOTHER FILE.
##
## A thrown slipper connects when its flat distance to the can is inside
## `Slipper.HIT_RADIUS + this`, tested per physics frame, host-side
## (`slipper.gd::_step_flying`). `Design.md` §7 has always listed a "hurtbox
## 0.30 r / 0.70 h" and `Lata.tscn` has always carried an `Area3D` authored to
## exactly that — and **grep found no reader for either**. The rule ran off a bare
## `0.30` typed into `slipper.gd`, so the balance source of truth was describing a
## shape the game did not consult and the scene shipped a node that did nothing.
## Three numbers that were supposed to be one.
##
## ⚠️ 0.30 IS UNCHANGED. This is a renaming, not a retune: the window every
## measurement on the board was taken against is exactly the window that is still
## here at neutral. `_fit_collision_to_mesh()` writes the `Area3D` from this value
## so the editor gizmo finally shows the real rule, and `hit_margin()` is what
## `slipper.gd` asks.
##
## ⚠️ AND IT IS THE ONE PLACE A LATA SKIN'S GRIT LANDS (§2.8). It is DIVIDED by
## the grit scale, so a tough can presents a smaller window: DECADES (tatag 5)
## shrinks it 12.3% to 0.263 and PASIP (tatag 1) opens it 16.3% to 0.349. Total
## window against `HIT_RADIUS` 0.23: 0.493 m to 0.579 m, either side of 0.53.
##
## ⚠️⚠️ AND IT IS DELIBERATELY *NOT* DERIVED FROM THE MESH, WHICH IS THE WHOLE
## FAIRNESS RULING HERE. The four cans measure 0.108 to 0.143 in radius — a 32%
## spread — and deriving the scoring window from geometry would have made the
## CHARACTER screen's prettiest can quietly the hardest to hit, with nothing on
## screen saying so. A competitive difference between cosmetic picks has to be
## DECLARED, and the meters declare it. The mesh drives the physical collider
## (see `_fit_collision_to_mesh`) and nothing else.
const HIT_MARGIN: float = 0.30

@onready var _visual: Node3D = $Visual
## ⚠️ DEAD, AND KNOWINGLY SO — FILED, NOT DELETED. This `Area3D` has no reader
## anywhere in the project: slipper contact is a distance test against
## `HIT_MARGIN` (see that constant), and reintroducing overlap-based contact is
## forbidden by the recorded `hit_probe` measurement (`Design.md` §6 — 16 of 36
## overlaps did not land). Removing the node means editing `scenes/objects/
## Lata.tscn`, which is 🎨 `build model`'s row per §3, so it is filed as §5.23
## rather than deleted from outside that lane.
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
	_snap_home_to_ground.call_deferred()
	# ⚠️ FITTED HERE TOO, NOT ONLY ON A SKIN SWAP. `CanVisual.tscn` ships PASIP as
	# the default mesh, and PASIP is the 22 mm worst case in §2.23 — so a lata that
	# nobody ever picked a skin for (an AI seat before the deal, a `--host`
	# command-line session, any peer that never reached the CHARACTER screen) was
	# precisely the one wearing the biggest disagreement.
	_fit_collision_to_mesh()
	_apply_upright_visual(true, false)

## ⚠️ THE FLOOR IS NOT AT y = 0, AND `Main.tscn` PLACES THE LATA AS IF IT WERE.
## Both maps sit their road and paving at **y = 0.1** (`build_*.py` reports
## "floor+paving both at y=0.1"), while the `Lata` node carries no transform at
## all — so the can stood 100 mm INSIDE the road, which is a quarter of its own
## base. 🧑, with a screenshot: *"can is in the floor, part of it is phasing thru
## floor"*.
##
## Snapped by RAYCAST rather than by adding 0.1 somewhere: the two maps could
## diverge, and the lata's mark is the one spot in the arena whose height a map is
## most likely to change (the plaza has a step). Deferred so the map's own
## StaticBodies are in the tree before the ray is cast — at `_ready()` they are
## not, and the ray finds nothing.
##
## `home_position` is what `_broadcast_home()` restores to, so fixing it here fixes
## the reset and the round rollover too, not just the first spawn.
func _snap_home_to_ground() -> void:
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		home_position + Vector3.UP * 2.0, home_position + Vector3.DOWN * 6.0)
	query.collide_with_areas = false
	# ⚠️ EXCLUDE THE LATA'S OWN BODY OR THE RAY LANDS ON THE CAN ITSELF. `Lata.tscn`
	# carries a `StaticBody3D` for the can, and a ray dropped from two metres up
	# hits the top of that collider first — so the "ground" came back as the can's
	# own lid and the snap lifted it by its full height. Measured: the probe
	# reported the mesh floating at +0.385, which is the can's height exactly.
	var body := get_node_or_null("Body") as CollisionObject3D
	if body != null:
		query.exclude = [body.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	home_position.y = (hit["position"] as Vector3).y
	global_position = home_position

## ---------------------------------------------------------------------------
## § SOFT STATS — §2.8, closed 2026-08-01. The LATA tab decides three things.
##
## ⚠️ THESE ARE READ OFF `skin_index`, WHICH IS WHICHEVER SEAT IS CURRENTLY THE
## TAYA. There is only one lata in the world, so it wears the defending seat's
## pick and `main.gd` re-applies it as the role rotates (`Design.md` §9). A
## player's can therefore matters on exactly the one round they defend, which is
## the round it is standing on the mark — the stat and the object are on screen
## together or not at all. -1 resolves to neutral, i.e. 1.0.
## ---------------------------------------------------------------------------

## How long the Defender's reset channel takes for THIS can. SPEED shortens it.
## ⚠️ DIVIDED, so more points is less time: PASIP (bilis 5) rights in 1.30 s and
## BOYBEN (bilis 1) takes 1.79 s, against the neutral `RESET_CHANNEL_TIME` 1.5.
## `carrier.gd` asks this rather than the const, so the progress bar and the
## completion test cannot disagree about how long the hold is.
func reset_channel_time() -> float:
	return RESET_CHANNEL_TIME / _scale(&"bilis", CharacterBase.TRAIT_SPEED_PER_POINT)

## How hard this can knocks a slipper away when it takes a hit. Scales
## `slipper.gd::LATA_RECOIL_SCALE` — the taya's way of buying time by lengthening
## somebody's retrieval.
func power_scale() -> float:
	return _scale(&"lakas", CharacterBase.TRAIT_POWER_PER_POINT)

## The live hit window — `HIT_MARGIN` divided by GRIT. See that constant.
func hit_margin() -> float:
	return HIT_MARGIN / _scale(&"tatag", CharacterBase.TRAIT_GRIT_PER_POINT)

## ⚠️ FLOORED AT 0.1, because two of the three callers DIVIDE by it and a zero on
## the spawn path would be a division by zero rather than a balance question.
func _scale(key: StringName, per_point: float) -> float:
	return maxf(0.1, CharacterRoster.trait_scale(
		CharacterRoster.can_trait(skin_index, key), per_point))

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

## Called by `carrier.gd` when the Defender's `RESET_CHANNEL_TIME` channel completes.
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
## ⚠️ A TOPPLED CAN HAS TO BE LIFTED BY ITS OWN RADIUS, OR HALF OF IT IS UNDER
## THE FLOOR. Reported directly — 🧑 2026-08-01: *"the cans are phasing thru ...
## the floor"*.
##
## The tilt is a rotation of `Visual` about ITS OWN ORIGIN, and that origin is at
## the BASE of the can (the mesh is authored standing on y = 0). Rotating a
## cylinder 88 degrees about a point on its base circle lays it down with its
## AXIS at floor level — so everything below the axis, a full radius of can, ends
## up underground. Upright it is invisible because a standing can genuinely does
## touch the floor at its base.
##
## It was always wrong; the new cans just made it obvious. The old lata was 0.102
## in radius and sank ten centimetres, which reads as "sitting low"; these are up
## to 0.143 and sink half a can.
##
## The lift is MEASURED from the mesh rather than stored as a constant, because
## the four cans have four different radii (Pasip 0.108 to Boyben 0.143) and a
## constant would be wrong for three of them the moment a skin changed.
var _downed_lift: float = 0.0

func _measure_downed_lift() -> void:
	_downed_lift = 0.0
	if _visual == null:
		return
	var bounds := _mesh_bounds()
	# Half the can's WIDTH is what it rests on when lying on its side. Taken from
	# the mesh's own bounds so it follows the skin automatically.
	_downed_lift = maxf(bounds.size.x, bounds.size.z) * 0.5

## The union of every mesh under `Visual`, in this node's own space.
##
## ⚠️ RAW `get_aabb()`, NOT A GLOBAL COMPOSE, and that is correct HERE and would
## not be in `slipper.gd`. `CanVisual.tscn` is one `MeshInstance3D` at identity
## under a root at identity, so mesh space IS Lata space; the slipper's visual
## carries a 1.6 drama scale and therefore has to walk its local chain. If a can
## visual ever grows a transform this has to grow the same walk.
func _mesh_bounds() -> AABB:
	var bounds := AABB()
	var first := true
	if _visual == null:
		return bounds
	for node in _visual.find_children("*", "VisualInstance3D", true, false):
		var box: AABB = (node as VisualInstance3D).get_aabb()
		if first:
			bounds = box
			first = false
		else:
			bounds = bounds.merge(box)
	return bounds

## ---------------------------------------------------------------------------
## ⚠️⚠️ §2.23 — THE PHYSICAL COLLIDER FOLLOWS THE MESH. It did not until
## 2026-08-01, and the disagreement was measured: `Lata.tscn` carries ONE cylinder
## at **r 0.13**, which is the MEAN of the four cans' radii (0.108 / 0.123 / 0.125
## / 0.143), so it was wrong for all four and worst on PASIP at **22 mm** — a
## player stopped about a fifth of a can early on the slimmest skin, and clipped
## into the widest.
##
## The mesh swap already happens in `_apply_model()` and already re-measures the
## topple lift, so the collider is measured in the same place off the same bounds
## and the two cannot drift apart.
##
## ⚠️ SAFE TO WRITE BECAUSE `Lata.tscn` MARKS BOTH SHAPES `resource_local_to_scene`.
## Without that flag a `Shape3D` sub-resource is shared by every instance of the
## scene in the project, and resizing one here would resize the CHARACTER screen's
## preview and any other lata in the tree at the same time.
##
## ⚠️ THIS IS THE COLLIDER, NOT THE SCORING WINDOW. What a body bumps into follows
## the art; what a slipper has to hit to score does NOT — see `HIT_MARGIN`. Keeping
## those two separate is the fairness ruling, and putting them in one function
## would be the easiest possible way to lose it.
## ---------------------------------------------------------------------------
func _fit_collision_to_mesh() -> void:
	var bounds := _mesh_bounds()
	if bounds.size.y <= 0.001:
		return
	var shape_node := get_node_or_null("Body/CollisionShape3D") as CollisionShape3D
	if shape_node == null or not (shape_node.shape is CylinderShape3D):
		return
	var cylinder := shape_node.shape as CylinderShape3D
	cylinder.radius = maxf(bounds.size.x, bounds.size.z) * 0.5
	cylinder.height = bounds.size.y
	# A `CylinderShape3D` is centred on its own origin, and the meshes are authored
	# standing on y = 0 — so the shape sits at half its height, exactly as the
	# scene's hand-authored 0.1925 did for the old 0.385.
	shape_node.position = Vector3(0.0, bounds.position.y + bounds.size.y * 0.5, 0.0)

func _apply_upright_visual(now_upright: bool, animate: bool) -> void:
	if _visual == null:
		return
	if _downed_lift <= 0.0:
		_measure_downed_lift()
	var target_angle := 0.0 if now_upright else deg_to_rad(DOWNED_TILT_DEG)
	if _topple_tween != null and _topple_tween.is_valid():
		_topple_tween.kill()
	if not animate:
		_set_tilt(target_angle)
		return
	# ⚠️ ONE TWEENED VALUE, NOT TWO PARALLEL ONES, AND THAT IS THE FIX FOR THE
	# CAN SINKING *DURING* THE TOPPLE. Tilt and lift are not independent: at angle
	# t the can's lowest point is -radius * sin(t), so the lift that keeps it on
	# the floor is radius * sin(t) — a SINE, not a straight line. Tweening
	# `rotation` and `position` as two parallel linear properties therefore agreed
	# only at the two ends and disagreed everywhere in between: measured at the
	# halfway point, the rotation needed 0.076 of lift and the linear one supplied
	# 0.054, so the can dipped 22 mm through the floor mid-animation and popped
	# back. It read as a flicker, which is why a static end-state check passed it.
	# `prop_probe.gd` samples every frame and caught it.
	_topple_tween = create_tween()
	_topple_tween.set_trans(Tween.TRANS_BACK if now_upright else Tween.TRANS_BOUNCE)
	_topple_tween.set_ease(Tween.EASE_OUT)
	_topple_tween.tween_method(_set_tilt, _visual.rotation.x, target_angle, TOPPLE_TIME)

## Applies a tilt and the lift that exactly matches it. The single place the two
## are allowed to be set, so they cannot drift apart again.
func _set_tilt(angle: float) -> void:
	if _visual == null:
		return
	_visual.rotation = Vector3(angle, 0.0, 0.0)
	# `absf` because a bouncing tween can pass slightly either side of zero, and a
	# negative lift would drive the can down rather than up.
	_visual.position = Vector3(0.0, _downed_lift * absf(sin(angle)), 0.0)

## Late joiners get the current state pushed by `main.gd`'s sync path; this is the
## receiving half, kept separate from `_rpc_set_upright` so a correction never
## replays the audio and the topple animation.
func adopt_state(now_upright: bool, where: Vector3) -> void:
	global_position = where
	if is_upright != now_upright:
		is_upright = now_upright
		_apply_upright_visual(now_upright, false)
		upright_changed.emit(now_upright)

## ---------------------------------------------------------------------------
## SKINS. The character screen's LATA tab picks one of these, and this is what
## makes that pick a real choice rather than a dead control.
##
## ⚠️ THE HOST'S PICK WINS AND IS BROADCAST. There is one lata in the world and
## all four players look at it, so it cannot wear four different skins. `main.gd`
## pushes the host's index at every round start; in Single Player that is your own.
##
## ⚠️ THE MATERIAL IS DUPLICATED PER MESH BEFORE IT IS WRITTEN. An imported `.glb`
## or `.obj` shares one `Material` resource across every instance of that mesh in
## the project — writing the tint straight onto it would recolour the preview on the
## character screen, and every other copy in the scene, at the same time.
## ---------------------------------------------------------------------------

## Which roster entry this prop is wearing. -1 is "stock, never picked".
var skin_index: int = -1

## ⚠️ A SKIN IS A MESH **AND** A TINT SINCE 2026-08-01, AND IT HAD TO BECOME ONE.
## It used to be a tint alone, which was correct while all six cans were one
## cylinder in six colours. The human's four drawings are four different objects —
## a slim soda can, a squat paint tin, a tuna can and a ribbed bare tin — and at
## arena distance under the toon pass it is the SHAPE that tells them apart, not
## the colour. A pick that changed only the tint would have been a control that
## looks like it does something and does almost nothing, which is the exact
## failure THE REACHABILITY RULE's second half was written for.
func apply_skin(index: int) -> void:
	if index < 0 or index == skin_index:
		return
	var entry: Dictionary = CharacterRoster.can_at(index)
	# ⚠️⚠️ THE INDEX IS LATCHED ONLY ONCE THE MESH HAS ACTUALLY SWAPPED, AND WRITING IT
	# FIRST WAS A TRAP THAT COULD NOT BE RECOVERED FROM. `_apply_model()` has four silent
	# early-returns (no `model` key, no `Visual`, no `MeshInstance3D` under it yet, mesh
	# fails to load) — and the third one is REACHABLE, because this can be called before
	# the prop's own tree is built. The old order set `skin_index = index` first, so a
	# single failed call left the number saying "already wearing skin 3" while the mesh was
	# still the one the scene shipped with. Every later call — including the round-reset
	# push that exists precisely to get this right — then hit the `index == skin_index`
	# guard above and returned immediately. One early miss and the skin was unrecoverable
	# for the whole process: the can silently stuck on its default and no amount of
	# re-picking or re-pushing could move it.
	#
	# Latching after the swap makes a failed apply a NO-OP rather than a poisoning, so the
	# next push simply retries and succeeds. `_push_prop_skins()` runs on every round
	# reset, so the retry is already there and always was — it just had no way through.
	if not _apply_model(entry):
		return
	skin_index = index
	if not entry.has("tint"):
		return
	# ⚠️ WHITE MEANS "DO NOT TINT" — see the twin note in `slipper.gd::apply_skin()`
	# for the full reasoning. On these textured cans white already multiplied to a
	# no-op, so this changes nothing here; it is kept identical on both props so
	# the two cannot drift, and so an untextured can added later cannot be
	# silently painted white.
	var tint: Color = entry["tint"]
	if tint == Color.WHITE:
		return
	_tint_meshes(tint)

## Swaps the mesh under `Visual` to the one this skin names.
##
## ⚠️ ORDER MATTERS: THIS RUNS BEFORE `_tint_meshes()`. The tint is written as a
## per-surface OVERRIDE material, and Godot does not clear overrides when the
## `mesh` beneath them changes — so tinting first and swapping second would leave
## the old can's override materials sitting on the new can's surfaces, with a
## surface count that need not even match.
##
## Missing or unloadable `model` leaves whatever the scene shipped with, which is
## roster entry 0. A prop that fails to find its mesh should look like the default
## can, not like nothing at all.
## Returns true only when the mesh was actually replaced — `apply_skin()` latches
## `skin_index` on that answer, so a miss here is retried rather than remembered.
func _apply_model(entry: Dictionary) -> bool:
	if not entry.has("model"):
		return false
	var visual := get_node_or_null("Visual")
	if visual == null:
		return false
	var target := visual.find_children("*", "MeshInstance3D", true, false)
	if target.is_empty():
		return false
	var mesh := load(String(entry["model"])) as Mesh
	if mesh == null:
		push_warning("Lata.apply_skin: cannot load %s" % entry["model"])
		return false
	var instance := target[0] as MeshInstance3D
	for surface in range(instance.get_surface_override_material_count()):
		instance.set_surface_override_material(surface, null)
	instance.mesh = mesh
	# The four cans have four different radii, so the topple lift AND the physical
	# collider both have to be re-measured whenever the mesh changes — see
	# `_measure_downed_lift` and `_fit_collision_to_mesh` (§2.23).
	_measure_downed_lift()
	_fit_collision_to_mesh()
	_apply_upright_visual(is_upright, false)
	return true

func _tint_meshes(tint: Color) -> void:
	var visual := get_node_or_null("Visual")
	if visual == null:
		return
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in range(mesh.get_surface_override_material_count()):
			var material := mesh.get_active_material(surface)
			if material == null:
				continue
			var copy := material.duplicate()
			if copy is StandardMaterial3D:
				(copy as StandardMaterial3D).albedo_color = tint
			elif copy is ShaderMaterial:
				# The toon pass reads `albedo_color` as the actual colour, so a
				# tinted prop still flashes correctly and returns to its tint.
				(copy as ShaderMaterial).set_shader_parameter("albedo_color", tint)
			mesh.set_surface_override_material(surface, copy)
