class_name WildDashTerrainZone
extends Node3D

## Lightweight route-aligned terrain volume.
## This deliberately avoids adding physics collision. Gameplay systems query the
## oriented bounds directly so terrain tuning cannot destabilize road collision.

var zone_id: StringName = &"terrain"
var terrain_type: StringName = &"rough"
var center: Vector3 = Vector3.ZERO
var forward: Vector3 = Vector3.FORWARD
var right: Vector3 = Vector3.RIGHT
var half_length: float = 5.0
var half_width: float = 3.0
var half_height: float = 3.0
var current_direction: Vector3 = Vector3.ZERO
var current_strength: float = 0.0

func _ready() -> void:
	add_to_group("wilddash_terrain_zone")

func configure_route_box(
	id: StringName,
	type: StringName,
	from_point: Vector3,
	to_point: Vector3,
	width: float,
	height: float,
	start_t: float = 0.0,
	end_t: float = 1.0
) -> void:
	zone_id = id
	terrain_type = type
	var start: Vector3 = from_point.lerp(to_point, clampf(start_t, 0.0, 1.0))
	var finish: Vector3 = from_point.lerp(to_point, clampf(end_t, 0.0, 1.0))
	center = (start + finish) * 0.5
	var planar: Vector3 = finish - start
	planar.y = 0.0
	if planar.length_squared() <= 0.001:
		planar = Vector3.FORWARD
	forward = planar.normalized()
	right = Vector3(-forward.z, 0.0, forward.x).normalized()
	half_length = maxf(0.25, start.distance_to(finish) * 0.5)
	half_width = maxf(0.25, width * 0.5)
	half_height = maxf(0.5, height * 0.5)
	position = center

func configure_current(direction: Vector3, strength: float) -> void:
	var planar: Vector3 = Vector3(direction.x, 0.0, direction.z)
	current_direction = Vector3.ZERO if planar.length_squared() <= 0.001 else planar.normalized()
	current_strength = maxf(0.0, strength)

func contains_global_point(point: Vector3) -> bool:
	var offset: Vector3 = point - center
	var vertical: float = absf(offset.y)
	if vertical > half_height:
		return false
	var planar: Vector3 = Vector3(offset.x, 0.0, offset.z)
	var along: float = absf(planar.dot(forward))
	if along > half_length:
		return false
	var lateral: float = absf(planar.dot(right))
	return lateral <= half_width

func get_terrain_type() -> StringName:
	return terrain_type

func get_zone_id() -> StringName:
	return zone_id

func get_current_direction() -> Vector3:
	return current_direction

func get_current_strength() -> float:
	return current_strength
