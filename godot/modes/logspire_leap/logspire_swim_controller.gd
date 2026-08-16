extends RefCounted

## Round 3 only swim movement helper. The shared CharacterController is paused
## while a racer is in the Canopy River, so this helper owns stable buoyant
## movement without changing movement rules in the other rounds.

const SWIM_SPEED_RATIO: float = 0.50
const SWIM_ACCELERATION: float = 16.0
const SWIM_TURN_SPEED: float = 5.5
const SURFACE_BODY_OFFSET: float = 0.52

const LIGHT_RACERS: Array[StringName] = [&"rabbit", &"cat", &"fox"]
const HEAVY_RACERS: Array[StringName] = [&"boar", &"bear", &"crocodile", &"elephant"]

func get_swim_speed(racer: WildDashCharacterController) -> float:
	if racer == null:
		return 4.0
	var species_scale: float = 0.96
	if LIGHT_RACERS.has(racer.animal_id):
		species_scale = 1.0
	elif HEAVY_RACERS.has(racer.animal_id):
		species_scale = 0.92
	if racer.animal_id == &"crocodile":
		species_scale *= 1.10
	return maxf(3.8, racer.max_speed * SWIM_SPEED_RATIO * species_scale)

func get_player_direction() -> Vector3:
	var axis: Vector2 = InputManager.get_move_vector()
	var direction := Vector3(axis.x, 0.0, axis.y)
	if direction.length_squared() <= 0.001:
		return Vector3.ZERO
	return direction.normalized()

func apply_swim(
	racer: WildDashCharacterController,
	direction: Vector3,
	water_y: float,
	delta: float
) -> void:
	if racer == null:
		return
	var desired_direction := direction
	desired_direction.y = 0.0
	if desired_direction.length_squared() > 0.001:
		desired_direction = desired_direction.normalized()
		var desired_yaw: float = atan2(-desired_direction.x, -desired_direction.z)
		racer.rotation.y = lerp_angle(racer.rotation.y, desired_yaw, clampf(SWIM_TURN_SPEED * delta, 0.0, 1.0))

	var target_speed: float = get_swim_speed(racer) if desired_direction.length_squared() > 0.001 else 0.0
	var desired_velocity := desired_direction * target_speed
	racer.velocity.x = move_toward(racer.velocity.x, desired_velocity.x, SWIM_ACCELERATION * delta)
	racer.velocity.z = move_toward(racer.velocity.z, desired_velocity.z, SWIM_ACCELERATION * delta)
	racer.velocity.y = 0.0

	var target_y: float = water_y + SURFACE_BODY_OFFSET
	var position := racer.global_position
	position.y = move_toward(position.y, target_y, 7.5 * delta)
	racer.global_position = position
	racer.move_and_slide()
	racer.current_speed = Vector2(racer.velocity.x, racer.velocity.z).length()
