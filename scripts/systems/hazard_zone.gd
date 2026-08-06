extends Area3D
class_name HazardZone


@export var speed_multiplier: float = 0.5
@export var lifetime: float = 4.0

const FLOOR_TOP_Y: float = 0.5

static func spawn(parent: Node, at_position: Vector3, radius: float, duration: float, multiplier: float = 0.5) -> HazardZone:
	var zone := HazardZone.new()
	zone.speed_multiplier = multiplier
	zone.lifetime = duration
	zone.collision_layer = 0
	zone.collision_mask = 1
	if duration > 0.0:
		zone.add_to_group("hazard_zone")

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	zone.add_child(shape)

	zone.position = at_position
	parent.add_child(zone)
	return zone

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if lifetime > 0.0:
		get_tree().create_timer(lifetime).timeout.connect(_expire)
	_build_visual()

func _build_visual() -> void:
	var shape_node := _find_collision_shape()
	if shape_node == null or not (shape_node.shape is SphereShape3D):
		return
	var radius: float = (shape_node.shape as SphereShape3D).radius

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(UiTheme.IMPACT.r, UiTheme.IMPACT.g, UiTheme.IMPACT.b, 0.35)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.05
	cylinder.material = material

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	mesh_instance.mesh = cylinder
	mesh_instance.position.y = FLOOR_TOP_Y - global_position.y + 0.01
	add_child(mesh_instance)

func _find_collision_shape() -> CollisionShape3D:
	for child in get_children():
		if child is CollisionShape3D:
			return child
	return null

func _on_body_entered(body: Node3D) -> void:
	var who := body as CharacterBase
	if who != null:
		who.enter_speed_zone(speed_multiplier)

func _on_body_exited(body: Node3D) -> void:
	var who := body as CharacterBase
	if who != null:
		who.exit_speed_zone(speed_multiplier)

func _expire() -> void:
	if is_instance_valid(self):
		for body in get_overlapping_bodies():
			var who := body as CharacterBase
			if who != null:
				who.exit_speed_zone(speed_multiplier)
		queue_free()

