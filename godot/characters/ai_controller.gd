class_name WildDashAIController
extends Node

enum AIMode {
	RACE,
	ARENA,
}

@export var racer_path: NodePath
@export var ai_mode: AIMode = AIMode.RACE
@export var target_speed := 10.4
@export var preferred_lane := 0.0
@export var lane_wander := 0.2
@export var steering_strength := 4.2
@export var acceleration := 12.0
@export var avoidance_distance := 6.5
@export var preserve_player_identity := false

var _racer: WildDashCharacterController
var _phase := 0.0
var _avoidance_sign := 1.0
var _stuck_seconds := 0.0
var _last_progress := 0.0
var _arena_target := Vector3.ZERO
var _arena_enabled := true
var _lod_anchor: Node3D
var _lod_level := 0
var _applied_lod_level := -1
var _brain_elapsed := 999.0
var _cached_target_yaw := 0.0
var _last_brain_updated := false
var _last_raycast_used := false
var _race_route: Array[Vector3] = []
var _route_index := 1

func _ready() -> void:
	_racer = get_node_or_null(racer_path) as WildDashCharacterController
	if _racer == null:
		return
	if not preserve_player_identity:
		_racer.is_player = false
	_configure_deterministic_personality(_racer.animal_id)
	_cached_target_yaw = _racer.rotation.y
	if ai_mode == AIMode.RACE:
		_last_progress = RaceManager.get_track_progress(_racer)

func _physics_process(delta: float) -> void:
	var started_usec := Time.get_ticks_usec()
	_last_brain_updated = false
	_last_raycast_used = false
	if _racer == null or _racer.finished:
		_record_perf(started_usec)
		return
	if ai_mode == AIMode.ARENA:
		_process_arena_ai(delta)
		_record_perf(started_usec)
		return
	if _racer.global_position.y < -28.0:
		_recover_to_track()
	if PerformanceManager.optimization_enabled:
		_process_race_ai_optimized(delta)
	else:
		_lod_level = 0
		_process_race_ai_baseline(delta)
	_record_perf(started_usec)

func set_race_route(points: Array[Vector3]) -> void:
	_race_route.clear()
	for point in points:
		_race_route.append(point)
	_route_index = 1 if _race_route.size() > 1 else 0
	if _racer != null and not _race_route.is_empty():
		_route_index = maxi(1, _find_nearest_route_index(_racer.global_position) + 1)
		_route_index = mini(_route_index, _race_route.size() - 1)

func set_arena_target(target: Vector3) -> void:
	_arena_target = target

func set_arena_enabled(value: bool) -> void:
	_arena_enabled = value
	if not value and _racer != null:
		_racer.velocity = Vector3.ZERO
		_racer.current_speed = 0.0

func set_lod_anchor(anchor: Node3D) -> void:
	_lod_anchor = anchor

func get_racer() -> WildDashCharacterController:
	return _racer

func get_route_index() -> int:
	return _route_index

func _process_race_ai_baseline(delta: float) -> void:
	if not RaceManager.active:
		return
	if _race_route.size() >= 2:
		_update_route_brain(delta, true)
		_racer.rotation.y = lerp_angle(_racer.rotation.y, _cached_target_yaw, clampf(steering_strength * delta, 0.0, 1.0))
		_move_racer(delta, true)
		return

	_last_brain_updated = true
	_last_raycast_used = true
	var obstacle_ahead := _has_obstacle_ahead()
	var desired_x := preferred_lane + sin(Time.get_ticks_msec() * 0.0016 + _phase) * lane_wander
	if obstacle_ahead:
		desired_x += _avoidance_sign * 3.8
		if _racer.is_on_floor():
			_racer.velocity.y = _racer.jump_velocity * 0.88
	else:
		_avoidance_sign = 1.0 if preferred_lane >= _racer.global_position.x else -1.0

	var progress := RaceManager.get_track_progress(_racer)
	_update_stuck_state(delta, progress)
	if _stuck_seconds > 1.0:
		_avoidance_sign *= -1.0
		desired_x += _avoidance_sign * 4.8
		_stuck_seconds = 0.0

	desired_x = clampf(desired_x, -8.0, 8.0)
	var error_x := desired_x - _racer.global_position.x
	var desired_direction := Vector3(clampf(error_x * 0.2, -0.8, 0.8), 0.0, -1.0).normalized()
	var target_yaw := atan2(-desired_direction.x, -desired_direction.z)
	_racer.rotation.y = lerp_angle(_racer.rotation.y, target_yaw, clampf(steering_strength * delta, 0.0, 1.0))
	_move_racer(delta, true)

func _process_race_ai_optimized(delta: float) -> void:
	if not RaceManager.active:
		return
	_lod_level = _resolve_lod_level()
	_apply_lod_if_needed()
	_brain_elapsed += delta
	var interval := 1.0 / 60.0
	if _lod_level == 1:
		interval = 1.0 / 30.0
	elif _lod_level >= 2:
		interval = 1.0 / 15.0

	if _brain_elapsed >= interval:
		if _race_route.size() >= 2:
			_update_route_brain(_brain_elapsed, _lod_level < 2)
		else:
			_update_straight_race_brain(_brain_elapsed, _lod_level < 2)
		_brain_elapsed = 0.0

	_racer.rotation.y = lerp_angle(_racer.rotation.y, _cached_target_yaw, clampf(steering_strength * delta, 0.0, 1.0))
	_move_racer(delta, _lod_level <= 1)

func _update_straight_race_brain(elapsed: float, allow_raycast: bool) -> void:
	_last_brain_updated = true
	var obstacle_ahead := false
	if allow_raycast:
		_last_raycast_used = true
		obstacle_ahead = _has_obstacle_ahead()
	var desired_x := preferred_lane + sin(Time.get_ticks_msec() * 0.0016 + _phase) * lane_wander
	if obstacle_ahead:
		desired_x += _avoidance_sign * 3.8
		if _racer.is_on_floor():
			_racer.velocity.y = _racer.jump_velocity * 0.88
	else:
		_avoidance_sign = 1.0 if preferred_lane >= _racer.global_position.x else -1.0

	var progress := RaceManager.get_track_progress(_racer)
	_update_stuck_state(elapsed, progress)
	if _stuck_seconds > 1.0:
		_avoidance_sign *= -1.0
		desired_x += _avoidance_sign * 4.8
		_stuck_seconds = 0.0

	desired_x = clampf(desired_x, -8.0, 8.0)
	var error_x := desired_x - _racer.global_position.x
	var desired_direction := Vector3(clampf(error_x * 0.2, -0.8, 0.8), 0.0, -1.0).normalized()
	_cached_target_yaw = atan2(-desired_direction.x, -desired_direction.z)

func _update_route_brain(elapsed: float, allow_raycast: bool) -> void:
	_last_brain_updated = true
	_advance_route_index()
	if _race_route.is_empty():
		return

	var current_target := _race_route[_route_index]
	var previous_index := maxi(0, _route_index - 1)
	var tangent := current_target - _race_route[previous_index]
	tangent.y = 0.0
	if tangent.length_squared() <= 0.001:
		tangent = -_racer.global_transform.basis.z
	else:
		tangent = tangent.normalized()
	var right := Vector3(-tangent.z, 0.0, tangent.x)
	var wander := sin(Time.get_ticks_msec() * 0.0013 + _phase) * lane_wander
	var desired_point := current_target + right * (preferred_lane + wander)

	var obstacle_ahead := false
	if allow_raycast:
		_last_raycast_used = true
		obstacle_ahead = _has_obstacle_ahead()
	if obstacle_ahead:
		desired_point += right * _avoidance_sign * 2.6
		if _racer.is_on_floor():
			_racer.velocity.y = _racer.jump_velocity * 0.82
	else:
		var lateral_error := (_racer.global_position - current_target).dot(right)
		_avoidance_sign = -1.0 if lateral_error > 0.0 else 1.0

	var offset := desired_point - _racer.global_position
	offset.y = 0.0
	if offset.length_squared() > 0.04:
		var desired_direction := offset.normalized()
		_cached_target_yaw = atan2(-desired_direction.x, -desired_direction.z)

	var progress := RaceManager.get_track_progress(_racer)
	_update_stuck_state(elapsed, progress)
	if _stuck_seconds > 1.35:
		_avoidance_sign *= -1.0
		_racer.current_speed = maxf(_racer.current_speed, target_speed * 0.7)
		if _racer.is_on_floor():
			_racer.velocity.y = _racer.jump_velocity * 0.9
		_stuck_seconds = 0.0

func _advance_route_index() -> void:
	if _race_route.size() < 2:
		return
	while _route_index < _race_route.size() - 1:
		var target := _race_route[_route_index]
		var planar := target - _racer.global_position
		planar.y = 0.0
		if planar.length() > 3.5:
			break
		_route_index += 1

func _update_stuck_state(elapsed: float, progress: float) -> void:
	if progress - _last_progress < 0.05:
		_stuck_seconds += elapsed
	else:
		_stuck_seconds = maxf(0.0, _stuck_seconds - elapsed * 2.0)
	_last_progress = progress

func _recover_to_track() -> void:
	if _racer == null:
		return
	var respawn := RaceManager.get_respawn_position(_racer)
	_racer.reset_motion(respawn)
	if not _race_route.is_empty():
		_route_index = mini(_find_nearest_route_index(respawn) + 1, _race_route.size() - 1)
	print("AI TRACK RECOVERY racer=%s checkpoint=%d" % [RaceManager.get_racer_label(_racer), RaceManager.get_checkpoint_progress(_racer)])

func _find_nearest_route_index(position: Vector3) -> int:
	if _race_route.is_empty():
		return 0
	var best_index := 0
	var best_distance := INF
	for i in range(_race_route.size()):
		var distance := position.distance_squared_to(_race_route[i])
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index

func _move_racer(delta: float, inspect_blocking_collision: bool) -> void:
	_racer.current_speed = move_toward(_racer.current_speed, target_speed, acceleration * delta)
	var forward := -_racer.global_transform.basis.z.normalized()
	_racer.velocity.x = forward.x * _racer.current_speed
	_racer.velocity.z = forward.z * _racer.current_speed
	_apply_gravity(delta)
	_racer.move_and_slide()
	if inspect_blocking_collision and _racer.has_blocking_collision():
		_racer.current_speed *= 0.9

func _process_arena_ai(delta: float) -> void:
	if not GameManager.round_active or not _arena_enabled:
		return
	var offset := _arena_target - _racer.global_position
	offset.y = 0.0
	var direction := Vector3.ZERO
	if offset.length_squared() > 0.04:
		direction = offset.normalized()
	var desired := direction * target_speed + _racer.get_knockback_velocity()
	_racer.velocity.x = move_toward(_racer.velocity.x, desired.x, acceleration * delta)
	_racer.velocity.z = move_toward(_racer.velocity.z, desired.z, acceleration * delta)
	_apply_gravity(delta)
	_racer.move_and_slide()
	_racer.current_speed = Vector2(_racer.velocity.x, _racer.velocity.z).length()
	_racer.decay_knockback(delta)

func _resolve_lod_level() -> int:
	if _lod_anchor == null or _racer == null:
		return 0
	var distance_sq := _racer.global_position.distance_squared_to(_lod_anchor.global_position)
	if distance_sq <= 28.0 * 28.0:
		return 0
	if distance_sq <= 65.0 * 65.0:
		return 1
	return 2

func _apply_lod_if_needed() -> void:
	if _racer == null or _applied_lod_level == _lod_level:
		return
	_applied_lod_level = _lod_level
	_racer.set_performance_lod(_lod_level)

func _record_perf(started_usec: int) -> void:
	PerformanceManager.record_ai_update(Time.get_ticks_usec() - started_usec, _lod_level, _last_brain_updated, _last_raycast_used)

func _apply_gravity(delta: float) -> void:
	if not _racer.is_on_floor():
		_racer.velocity.y -= _racer.gravity * delta
	elif _racer.velocity.y < 0.0:
		_racer.velocity.y = 0.0

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
	var hit: Dictionary = _racer.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty()
