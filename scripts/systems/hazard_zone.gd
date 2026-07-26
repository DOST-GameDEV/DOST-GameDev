extends Area3D
class_name HazardZone

## Generic slow-zone hazard. Used right now by Palayok's Shatter Trap; reusable as-is
## for map hazards later (GDD Section 5 — Bayan Plaza mud patches, Palengke wet floor).
## First-pass / untested in-editor.

@export var speed_multiplier: float = 0.5
@export var lifetime: float = 4.0 ## <= 0 means permanent (for map hazards, not specials)

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

	parent.add_child(zone)
	zone.global_position = at_position
	return zone

func _ready() -> void:
	monitoring = true
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	if lifetime > 0.0:
		get_tree().create_timer(lifetime).timeout.connect(_expire)

func _on_area_entered(area: Area3D) -> void:
	if area is Hurtbox:
		(area as Hurtbox).owner_character.set_speed_multiplier(speed_multiplier)

func _on_area_exited(area: Area3D) -> void:
	if area is Hurtbox:
		(area as Hurtbox).owner_character.set_speed_multiplier(1.0)

func _expire() -> void:
	if is_instance_valid(self):
		queue_free()
