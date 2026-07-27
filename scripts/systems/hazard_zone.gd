extends Area3D
class_name HazardZone

## Generic slow-zone hazard. Used right now by Palayok's Shatter Trap; reusable as-is
## for map hazards later (GDD Section 5 — Bayan Plaza mud patches, Palengke wet floor).
##
## Q-7: gained a visual — previously a bare Area3D + CollisionShape3D, invisible
## in game regardless of caller. Built in _ready() from the actual
## CollisionShape3D's SphereShape3D radius (not a second exported number that
## could drift from it), so both the ability-spawned path (spawn() below) and
## a scene-placed map hazard get it for free.

@export var speed_multiplier: float = 0.5
@export var lifetime: float = 4.0 ## <= 0 means permanent (for map hazards, not specials)

## Q-7: the current single test arena's floor top sits at world y = 0.5
## (Floor's BoxMesh, size (40,1,40), centered at the origin — see Main.tscn).
## Every other placement in this arena is similarly hardcoded today
## (main.gd's SPAWN_POINTS, the four boundary walls) pending real per-map
## geometry (Phase 4) — this is the same kind of placeholder, not a design
## decision, and will need to become map-relative once real maps land.
const FLOOR_TOP_Y: float = 0.5

static func spawn(parent: Node, at_position: Vector3, radius: float, duration: float, multiplier: float = 0.5) -> HazardZone:
	var zone := HazardZone.new()
	zone.speed_multiplier = multiplier
	zone.lifetime = duration
	zone.collision_layer = 0
	zone.collision_mask = 2 # matches Hurtbox layer
	# Item 10 / B-37: main.gd::_reset_world frees anything still in this group
	# between rounds — an ability-spawned hazard (Shatter Trap) shouldn't
	# outlive the round it was cast in. Only tag the timed (duration > 0)
	# case: a permanent map hazard (duration <= 0, lifetime doc above) is part
	# of the map, not the round, and must survive a world reset once maps
	# exist and place one.
	if duration > 0.0:
		zone.add_to_group("hazard_zone")

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	zone.add_child(shape)

	# Q-7: must be set BEFORE add_child(), not after — _ready() (which now
	# also builds the visual, positioned relative to global_position) fires
	# synchronously during add_child(), before this function's next line
	# would otherwise run. `position` (local), not `global_position`: the
	# latter's setter requires already being inside the tree — confirmed
	# live, assigning it pre-entry throws "!is_inside_tree()" and silently
	# leaves the zone at the origin. Every caller passes an already-in-
	# world-space `at_position` to a parent with an identity transform
	# (current_scene / Main), so local and global coincide here regardless.
	zone.position = at_position
	parent.add_child(zone)
	return zone

func _ready() -> void:
	monitoring = true
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	if lifetime > 0.0:
		get_tree().create_timer(lifetime).timeout.connect(_expire)
	_build_visual()

## No art asset — a primitive mesh + StandardMaterial3D built in code, per the
## Q-7 scope (no 3D model/art may be touched this batch).
func _build_visual() -> void:
	var shape_node := _find_collision_shape()
	if shape_node == null or not (shape_node.shape is SphereShape3D):
		return
	var radius: float = (shape_node.shape as SphereShape3D).radius

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(UiTheme.IMPACT.r, UiTheme.IMPACT.g, UiTheme.IMPACT.b, 0.35)
	# Unshaded so the patch reads the same colour under any light — a lit
	# material would go near-black in shadow and lose the "this is a hazard"
	# read exactly where the arena's own shadows fall.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.05
	cylinder.material = material

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D" # else Godot leaves it "@MeshInstance3D@N"
	mesh_instance.mesh = cylinder
	# Projects the decal onto the floor regardless of where THIS zone's own
	# origin sits — Shatter Trap spawns at character.global_position (roughly
	# capsule-center height), a scene-placed map hazard can sit anywhere its
	# author put it. 0.01 epsilon keeps it off the floor mesh's own surface.
	mesh_instance.position.y = FLOOR_TOP_Y - global_position.y + 0.01
	add_child(mesh_instance)

func _find_collision_shape() -> CollisionShape3D:
	for child in get_children():
		if child is CollisionShape3D:
			return child
	return null

## B-17: a Hurtbox whose owner_character was never wired (null) used to crash
## here. And on exit, calling set_speed_multiplier(1.0) unconditionally reset
## speed even if the character was still standing in a second overlapping
## zone — enter_speed_zone()/exit_speed_zone() track per-zone state instead
## (see character_base.gd) so this only ever adds/removes THIS zone's effect.
func _on_area_entered(area: Area3D) -> void:
	if area is Hurtbox:
		var owner_character := (area as Hurtbox).owner_character
		if owner_character:
			owner_character.enter_speed_zone(speed_multiplier)

func _on_area_exited(area: Area3D) -> void:
	if area is Hurtbox:
		var owner_character := (area as Hurtbox).owner_character
		if owner_character:
			owner_character.exit_speed_zone(speed_multiplier)

## B-17: don't rely on Godot firing area_exited for everyone still overlapping
## at the moment this zone frees itself — explicitly clear this zone's effect
## from every character still inside first, so an expiring-while-occupied
## hazard can't leave someone permanently slowed.
func _expire() -> void:
	if is_instance_valid(self):
		for area in get_overlapping_areas():
			if area is Hurtbox:
				var owner_character := (area as Hurtbox).owner_character
				if owner_character:
					owner_character.exit_speed_zone(speed_multiplier)
		queue_free()
