class_name WildDashCanopyVineRoute
extends RefCounted

## Stable fake-swing route between two elevated anchors. The traversal system
## samples this curve instead of simulating a free rope, keeping CharacterBody3D
## movement deterministic and easy to extend to multiplayer later.

var vine_id: StringName = &""
var start_position: Vector3 = Vector3.ZERO
var end_position: Vector3 = Vector3.ZERO
var arc_drop: float = 2.0
var max_swing_speed: float = 9.0
var release_boost: float = 4.0
var enabled: bool = true

func configure(
	id: StringName,
	start: Vector3,
	finish: Vector3,
	drop: float,
	max_speed: float,
	release_velocity_boost: float
) -> WildDashCanopyVineRoute:
	vine_id = id
	start_position = start
	end_position = finish
	arc_drop = maxf(0.25, drop)
	max_swing_speed = maxf(2.0, max_speed)
	release_boost = maxf(0.0, release_velocity_boost)
	return self

func sample(progress: float) -> Vector3:
	var t: float = clampf(progress, 0.0, 1.0)
	var base: Vector3 = start_position.lerp(end_position, t)
	var sag: float = sin(t * PI) * arc_drop
	return base - Vector3.UP * sag

func tangent(progress: float) -> Vector3:
	var t: float = clampf(progress, 0.0, 1.0)
	var epsilon: float = 0.015
	var t0: float = maxf(0.0, t - epsilon)
	var t1: float = minf(1.0, t + epsilon)
	var delta: Vector3 = sample(t1) - sample(t0)
	if delta.length_squared() <= 0.0001:
		delta = end_position - start_position
	if delta.length_squared() <= 0.0001:
		return Vector3.FORWARD
	return delta.normalized()

func approximate_length() -> float:
	var total: float = 0.0
	var previous: Vector3 = sample(0.0)
	for i: int in range(1, 13):
		var point: Vector3 = sample(float(i) / 12.0)
		total += previous.distance_to(point)
		previous = point
	return maxf(1.0, total)
