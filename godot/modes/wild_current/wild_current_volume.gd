class_name WildCurrentVolume
extends Area3D

## Reusable non-blocking water-current volume for Round 5.
## The Area3D owns simple box bounds only; racers query the force from the
## swimming layer so gameplay water never becomes solid collision geometry.

var direction: Vector3 = Vector3.FORWARD
var strength: float = 1.0
var width: float = 10.0
var length: float = 20.0
var current_type: StringName = &"NORMAL"

func configure(
	world_position: Vector3,
	flow_direction: Vector3,
	flow_strength: float,
	flow_width: float,
	flow_length: float,
	flow_type: StringName,
) -> void:
	global_position = world_position
	direction = flow_direction
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	else:
		direction = direction.normalized()
	strength = maxf(0.0, flow_strength)
	width = maxf(1.0, flow_width)
	length = maxf(1.0, flow_length)
	current_type = flow_type
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false

	var shape_node := CollisionShape3D.new()
	shape_node.name = "CurrentBounds"
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 7.0, length)
	shape_node.shape = shape
	add_child(shape_node)

func contains_world_point(world_position: Vector3) -> bool:
	var local := to_local(world_position)
	return absf(local.x) <= width * 0.5 and absf(local.z) <= length * 0.5 and absf(local.y) <= 3.5

func sample_force(world_position: Vector3) -> Vector3:
	if not contains_world_point(world_position):
		return Vector3.ZERO
	return direction * strength
