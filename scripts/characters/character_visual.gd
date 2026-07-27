extends Node3D
class_name CharacterVisual

## Owns everything about how a unit LOOKS, so `character_base.gd` never has to
## know the shape of the mesh tree. Sits on `CharacterBase.tscn`'s `Visual`
## node, which `camera_rig.gd` already treats as one hideable subtree for the
## FPP self-hide.
##
## Why this exists as its own script rather than a mesh wired into
## CharacterBase.tscn: `is_can` FLIPS EVERY ROUND (roles swap — see
## main.gd::_reset_world), so a Prop is a Can one round and a Tsinelas the next.
## The model has to be swappable at runtime, not baked into the scene.
##
## It also owns the B-44 hit flash. That used to be
## `get_node_or_null("Visual/MeshInstance3D")` in character_base.gd, and it has
## already broken silently once (commit 6f97e76) when the mesh moved under the
## `Visual` wrapper — a hardcoded node path returns null with no error and the
## flash just stops happening. Nothing here depends on a fixed path: the meshes
## are whatever `find_children` turns up under the model that was actually
## instanced, so restructuring a visual scene cannot break it.

## Persons are Kenney "Mini Characters" (CC0 — see KENNEY_LICENSE.txt). Indexed
## by team, so index 0 and 1 are the two Persons you actually see in a match and
## the rest are the character-select roster (B-24).
##
## Order is deliberate, not alphabetical:
##   [0] male-f   — the reference character from the art direction: dark blocky
##                  hair, heavy brow, green top over a tan body.
##   [1] female-f — Team B's default, picked to contrast [0] on the two things
##                  readable at gameplay distance: ginger hair against dark, and
##                  a black/yellow outfit against green.
## Everything after those two is roster stock. Do not reorder the first two
## without checking both still read apart from across the arena.
const PERSON_MODELS: Array[String] = [
	"res://assets/characters/persons/character-male-f.glb",
	"res://assets/characters/persons/character-female-f.glb",
	"res://assets/characters/persons/character-male-a.glb",
	"res://assets/characters/persons/character-female-a.glb",
	"res://assets/characters/persons/character-male-b.glb",
	"res://assets/characters/persons/character-female-b.glb",
	"res://assets/characters/persons/character-male-c.glb",
	"res://assets/characters/persons/character-female-c.glb",
	"res://assets/characters/persons/character-male-d.glb",
	"res://assets/characters/persons/character-female-d.glb",
	"res://assets/characters/persons/character-male-e.glb",
	"res://assets/characters/persons/character-female-e.glb",
]
const CAN_VISUAL: String = "res://scenes/characters/visuals/CanVisual.tscn"
const TSINELAS_VISUAL: String = "res://scenes/characters/visuals/TsinelasVisual.tscn"

## The Kenney rig is authored ~0.67 units tall with its origin at the feet, so
## this brings it up to the ~1.6 units of CharacterBase's CapsuleShape3D.
## Measured from the imported model's AABB, not guessed.
const PERSON_SCALE: float = 2.38
## The capsule is 1.6 tall and centred on the character's origin, so its floor
## sits here in local space. Every model is dropped to it — see
## `_align_to_capsule_floor`.
const CAPSULE_HALF_HEIGHT_DOWN: float = -0.8

const FLASH_DURATION: float = 0.15

## Q-8: impact particle burst on a landed hit — the moodboard's "IMPACT EFFECT
## (particle burst)". Built from a primitive + StandardMaterial3D in code, no
## art asset. Roughly chest height so it reads against the character instead
## of bursting at ground level.
const IMPACT_PARTICLE_COUNT: int = 16
const IMPACT_PARTICLE_LIFETIME: float = 0.4
const IMPACT_PARTICLE_HEIGHT: float = 1.0

## Emitted whenever the instanced model is replaced. `camera_rig.gd` listens so
## it can re-apply the FPP self-hide: rig `_ready()` runs BEFORE
## `character_base.gd`'s (children are ready before parents), so at the moment
## the rig first looks for meshes to hide, this node is still empty — and every
## round-swap replaces them again. Without this, a Person's own body renders
## solid in first person and you look at the inside of your own head.
signal model_changed

## Which model is currently instanced, so a `refresh()` that doesn't actually
## change anything (the idempotent double call from `_reset_world` →
## `reset_for_new_round`) doesn't rebuild the mesh tree and restart animation.
var _current_key: String = ""
## The per-surface materials this unit owns, not the MeshInstance3Ds — a model
## can have several surfaces per mesh, and keying the flash off surface 0 would
## silently miss the rest and desync from the albedo list.
var _materials: Array[BaseMaterial3D] = []
## Parallel to `_materials`: the albedo each one started at, so a flash always
## tweens back to the real colour rather than to whatever it was mid-flash.
var _base_albedos: Array[Color] = []
var _flash_tween: Tween = null

## Builds (or rebuilds) the model for this unit. Safe to call every round.
func apply(is_person: bool, is_can: bool, team: int) -> void:
	var key := _model_path(is_person, is_can, team)
	if key == _current_key:
		return
	_current_key = key

	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	for child in get_children():
		# remove_child BEFORE queue_free, not queue_free alone. queue_free only
		# schedules deletion for end of frame, so the outgoing model stays in the
		# tree and keeps being drawn while its duplicated materials are already
		# being released — which the renderer reports as "Parameter 'material' is
		# null" once per server call, on the one frame a model is swapped.
		remove_child(child)
		child.queue_free()
	_materials.clear()
	_base_albedos.clear()

	var scene := load(key) as PackedScene
	if scene == null:
		push_error("CharacterVisual: could not load model '%s'" % key)
		return
	var model := scene.instantiate() as Node3D
	if is_person:
		model.scale = Vector3.ONE * PERSON_SCALE
	add_child(model)

	_collect_meshes(model)
	_align_to_capsule_floor(model)
	_play_idle(model)
	model_changed.emit()

## Drops the model so its lowest point rests on the bottom of CharacterBase's
## capsule, measured from the model that was actually instanced rather than
## carried as a per-model magic number. The Can (1.13 units) and the Tsinelas
## (1.35) are both shorter than the 1.6 capsule and would otherwise hover a
## visible 13-24cm above the ground, and the two Kenney Persons aren't even the
## same height as each other (1.60 vs 1.85 — hair), so one shared offset cannot
## be right for all four.
func _align_to_capsule_floor(model: Node3D) -> void:
	var bounds := AABB()
	var first := true
	for node in model.find_children("*", "VisualInstance3D", true, false):
		var box: AABB = (node as VisualInstance3D).get_aabb()
		box = (node as Node3D).transform * box
		if first:
			bounds = box
			first = false
		else:
			bounds = bounds.merge(box)
	if first:
		return # nothing to measure
	model.position.y += CAPSULE_HALF_HEIGHT_DOWN - bounds.position.y * model.scale.y

func _model_path(is_person: bool, is_can: bool, team: int) -> String:
	if is_person:
		return PERSON_MODELS[team % PERSON_MODELS.size()]
	return CAN_VISUAL if is_can else TSINELAS_VISUAL

## Each mesh gets its OWN StandardMaterial3D via a surface override. Without
## this, every unit sharing a model would share one material resource, and
## flashing one of them white would flash all of them — including the enemy's.
func _collect_meshes(model: Node3D) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in range(mesh_instance.get_surface_override_material_count()):
			# Typed as BaseMaterial3D, not StandardMaterial3D: a glTF surface can
			# import as ORMMaterial3D (or carry a ShaderMaterial), and casting
			# those to StandardMaterial3D yields null — which then gets installed
			# as the surface's override and makes the renderer spew "Parameter
			# 'material' is null" every frame for a mesh that no longer draws.
			# Anything that isn't a BaseMaterial3D has no albedo_color to flash,
			# so it is left alone rather than replaced.
			var source := mesh_instance.get_active_material(surface) as BaseMaterial3D
			if source == null:
				continue
			var mat := source.duplicate() as BaseMaterial3D
			mesh_instance.set_surface_override_material(surface, mat)
			_materials.append(mat)
			_base_albedos.append(mat.albedo_color)

## Kenney's rig ships 32 clips. Without one playing, the model stands in its
## bind pose — a T-pose, which reads as broken art rather than as a character.
## Only "idle" is wired for now; walk/run blending is a separate task (see the
## follow-up noted in docs/Handoff.md item 18).
func _play_idle(model: Node3D) -> void:
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		return
	for candidate in ["idle", "Idle", "static"]:
		if player.has_animation(candidate):
			player.play(candidate)
			return

## B-44: brief white flash on a landed hit, on every mesh this unit has.
## Q-8: also bursts impact particles — see _spawn_impact_particles below.
func flash_hit() -> void:
	_spawn_impact_particles()
	if _materials.is_empty():
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween().set_parallel(true)
	for i in range(_materials.size()):
		_materials[i].albedo_color = Color.WHITE
		_flash_tween.tween_property(_materials[i], "albedo_color", _base_albedos[i], FLASH_DURATION)

## Q-8: one-shot burst, no art asset — a primitive point mesh + unshaded
## StandardMaterial3D in UiTheme.IMPACT, matching the moodboard's "IMPACT
## EFFECT (particle burst)". Frees itself once spent rather than leaking one
## GPUParticles3D node per hit for the rest of the match.
func _spawn_impact_particles() -> void:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.spread = 180.0 ## spherical emission
	material.initial_velocity_min = 1.5
	material.initial_velocity_max = 3.5
	material.gravity = Vector3(0, -9.8, 0)
	material.color = UiTheme.IMPACT

	var point_mesh := SphereMesh.new()
	point_mesh.radius = 0.04
	point_mesh.height = 0.08
	var point_material := StandardMaterial3D.new()
	point_material.albedo_color = UiTheme.IMPACT
	point_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	point_mesh.material = point_material

	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0 ## a burst, not a stream
	particles.amount = IMPACT_PARTICLE_COUNT
	particles.lifetime = IMPACT_PARTICLE_LIFETIME
	particles.process_material = material
	particles.draw_pass_1 = point_mesh
	particles.position.y = IMPACT_PARTICLE_HEIGHT
	particles.finished.connect(particles.queue_free)
	add_child(particles)
	particles.emitting = true

## Q-6: a Guard blocking a hit had no feedback at all. Deliberately
## DEFENSE-tinted rather than white, so a blocked hit is never mistaken for a
## landed one (flash_hit() above) at a glance.
func flash_blocked() -> void:
	if _materials.is_empty():
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween().set_parallel(true)
	for i in range(_materials.size()):
		_materials[i].albedo_color = UiTheme.DEFENSE
		_flash_tween.tween_property(_materials[i], "albedo_color", _base_albedos[i], FLASH_DURATION)
