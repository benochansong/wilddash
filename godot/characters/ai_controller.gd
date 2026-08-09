class_name WildDashAIController
extends Node

@export var racer_path: NodePath
@export var target_speed := 10.4
@export var preferred_lane := 0.0
@export var lane_wander := 0.2
@export var steering_strength := 4.2
@export var acceleration := 12.0
@export var avoidance_distance := 6.5

var _racer: WildDashCharacterController
var _phase := 0.0
var _avoidance_sign := 1.0
var _stuck_seconds := 0.0
var _last_progress := 0.0

func _ready() -> void:
	_racer = get_node_or_null(racer_path) as WildDashCharacterController
	if _racer == null:
		return
	_racer.is_player = false
	_last_progress = RaceManager.get_test_track_progress(_racer)
	_configure_deterministic_personality(_racer.animal_id)

func _physics_process(delta: float) -> void:
	if _racer == null or _racer.finished or not RaceManager.active:
		return

	var obstacle_ahead := _has_obstacle_ahead()
	var desired_x := preferred_lane + sin(Time.get_ticks_msec() * 0.0016 + _phase) * lane_wander
	if obstacle_ahead:
		desired_x += _avoidance_sign * 3.8
		if _racer.is_on_floor():
			_racer.velocity.y = _racer.jump_velocity * 0.88
	else:
		_avoidance_sign = 1.0 if preferred_lane >= _racer.global_position.x else -1.0

	var progress := RaceManager.get_test_track_progress(_racer)
	if progress - _last_progress < 0.04:
		_stuck_seconds += delta
	else:
		_stuck_seconds = maxf(0.0, _stuck_seconds - delta * 2.0)
	_last_progress = progress

	if _stuck_seconds > 1.0:
		_avoidance_sign *= -1.0
		desired_x += _avoidance_sign * 4.8
		_stuck_seconds = 0.0

	desired_x = clampf(desired_x, -8.0, 8.0)
	var error_x := desired_x - _racer.global_position.x
	var desired_direction := Vector3(clampf(error_x * 0.2, -0.8, 0.8), 0.0, -1.0).normalized()
	var target_yaw := atan2(-desired_direction.x, -desired_direction.z)
	_racer.rotation.y = lerp_angle(_racer.rotation.y, target_yaw, clampf(steering_strength * delta, 0.0, 1.0))

	_racer.current_speed = move_toward(_racer.current_speed, target_speed, acceleration * delta)
	var forward := -_racer.global_transform.basis.z.normalized()
	_racer.velocity.x = forward.x * _racer.current_speed
	_racer.velocity.z = forward.z * _racer.current_speed
	if not _racer.is_on_floor():
		_racer.velocity.y -= _racer.gravity * delta
	elif _racer.velocity.y < 0.0:
		_racer.velocity.y = 0.0
	_racer.move_and_slide()

	if _racer.has_blocking_collision():
		_racer.current_speed *= 0.9

func _configure_deterministic_personality(id: StringName) -> void:
	match id:
		&"rabbit":
			_phase = 0.6
			_avoidance_sign = -1.0
		&"elephant":
			_phase = 2.2
			_avoidance_sign = 1.0
		&"cat":
			_phase = 4.4
			_avoidance_sign = -1.0
		_:
			_phase = 0.0
			_avoidance_sign = 1.0

func _has_obstacle_ahead() -> bool:
	if _racer == null or _racer.get_world_3d() == null:
		return false
	var from := _racer.global_position + Vector3.UP * 0.85
	var forward := -_racer.global_transform.basis.z.normalized()
	var query := PhysicsRayQueryParameters3D.create(from, from + forward * avoidance_distance)
	query.exclude = [_racer.get_rid()]
	query.collision_mask = 1
	var hit := _racer.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty()
