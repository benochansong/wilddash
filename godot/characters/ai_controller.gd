class_name WildDashAIController
extends Node

@export var racer_path: NodePath
@export var target_speed := 10.4
@export var preferred_lane := 0.0
@export var lane_wander := 0.7
@export var steering_strength := 4.2
@export var acceleration := 12.0
@export var avoidance_distance := 5.5

var _racer: WildDashCharacterController
var _phase := 0.0
var _avoidance_sign := 1.0

func _ready() -> void:
	_racer = get_node_or_null(racer_path) as WildDashCharacterController
	_phase = randf_range(0.0, TAU)
	_avoidance_sign = -1.0 if randf() < 0.5 else 1.0
	if _racer != null:
		_racer.is_player = false

func _physics_process(delta: float) -> void:
	if _racer == null or _racer.finished or not RaceManager.active:
		return

	var desired_x := preferred_lane + sin(Time.get_ticks_msec() * 0.0016 + _phase) * lane_wander
	if _has_obstacle_ahead():
		desired_x += _avoidance_sign * 3.2
	else:
		_avoidance_sign = 1.0 if preferred_lane >= _racer.global_position.x else -1.0
	desired_x = clampf(desired_x, -7.2, 7.2)

	var error_x := desired_x - _racer.global_position.x
	var desired_direction := Vector3(clampf(error_x * 0.18, -0.72, 0.72), 0.0, -1.0).normalized()
	var target_yaw := atan2(-desired_direction.x, -desired_direction.z)
	_racer.rotation.y = lerp_angle(_racer.rotation.y, target_yaw, clampf(steering_strength * delta, 0.0, 1.0))

	var speed_goal := target_speed
	if _racer.get_slide_collision_count() > 0:
		speed_goal *= 0.72
	_racer.current_speed = move_toward(_racer.current_speed, speed_goal, acceleration * delta)

	var forward := -_racer.global_transform.basis.z.normalized()
	_racer.velocity.x = forward.x * _racer.current_speed
	_racer.velocity.z = forward.z * _racer.current_speed
	if not _racer.is_on_floor():
		_racer.velocity.y -= _racer.gravity * delta
	elif _racer.velocity.y < 0.0:
		_racer.velocity.y = 0.0
	_racer.move_and_slide()

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
