class_name WildWhirlpoolVolume
extends Area3D

## Soft, recoverable whirlpool force. No reset/death authority lives here.
## The swimmer can counter this with steering, Swim Burst, or Dive Burst.

var radius: float = 7.0
var pull_strength: float = 4.0

func configure(world_position: Vector3, whirlpool_radius: float, strength: float) -> void:
	global_position = world_position
	radius = maxf(1.0, whirlpool_radius)
	pull_strength = maxf(0.0, strength)
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false

	var shape_node := CollisionShape3D.new()
	shape_node.name = "WhirlpoolBounds"
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 5.0
	shape_node.shape = shape
	add_child(shape_node)

func contains_world_point(world_position: Vector3) -> bool:
	var delta := world_position - global_position
	delta.y = 0.0
	return delta.length() <= radius and absf(world_position.y - global_position.y) <= 3.0

func sample_force(world_position: Vector3) -> Vector3:
	var delta := global_position - world_position
	delta.y = 0.0
	var distance := delta.length()
	if distance <= 0.001 or distance > radius:
		return Vector3.ZERO
	var inward := delta / distance
	var tangent := Vector3(-inward.z, 0.0, inward.x)
	var center_factor := 1.0 - clampf(distance / radius, 0.0, 1.0)
	var pull := pull_strength * lerpf(0.32, 1.0, center_factor)
	var orbit := pull_strength * lerpf(0.34, 0.16, center_factor)
	return inward * pull + tangent * orbit
