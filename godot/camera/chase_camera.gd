extends Camera3D

@export var target_path: NodePath
@export var follow_distance := 9.5
@export var follow_height := 5.2
@export var look_ahead := 4.5
@export var position_smoothing := 7.0

@export_group("Camera Obstruction")
@export var obstruction_enabled := true
@export_flags_3d_physics var obstruction_mask := 1
@export var obstruction_clearance := 0.42
@export var obstructed_smoothing := 16.0
@export var recovery_smoothing := 6.5
@export var target_anchor_height := 1.15
@export var emergency_snap_when_occluded := true
@export var emergency_close_distance := 3.4
@export var emergency_close_height := 4.1

@export_group("Forward Visibility")
@export var forward_visibility_enabled := true
@export var forward_visibility_near_ratio := 0.72
@export var forward_visibility_high_ratio := 0.54
@export var forward_visibility_near_lift := 2.4
@export var forward_visibility_high_lift := 4.8
@export var forward_visibility_endpoint_tolerance := 1.25

@export_group("Game Feel Camera")
@export var impulse_max_offset := 0.24
@export var impulse_decay := 13.0
@export var finish_pullback_max := 3.8
@export var focus_blend_max := 0.34

var _target: Node3D
var _camera_obstructed := false
var _forward_visibility_adjusted := false
var _last_desired_position := Vector3.ZERO
var _last_resolved_position := Vector3.ZERO
var _emergency_snap_count := 0
var _game_feel_impulse := Vector3.ZERO
var _finish_pullback_remaining := 0.0
var _finish_pullback_duration := 0.0
var _finish_pullback_amount := 0.0
var _focus_point := Vector3.ZERO
var _focus_remaining := 0.0
var _focus_duration := 0.0

func _ready() -> void:
	if not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node3D
		_apply_target_profile()

func set_target(target: Node3D) -> void:
	_target = target
	_apply_target_profile()
	if _target != null:
		var forward := -_target.global_transform.basis.z.normalized()
		var desired_position := _target.global_position - forward * follow_distance + Vector3.UP * follow_height
		var anchor := _get_camera_anchor()
		var look_target := _build_look_target(forward, false)
		var resolved_position := _resolve_obstructed_position(anchor, desired_position)
		resolved_position = _resolve_forward_visibility(anchor, forward, look_target, resolved_position)
		global_position = resolved_position
		_last_desired_position = desired_position
		_last_resolved_position = resolved_position

func _process(delta: float) -> void:
	if _target == null:
		return
	_update_game_feel(delta)
	var forward := -_target.global_transform.basis.z.normalized()
	var pullback := _get_finish_pullback()
	var desired_position := _target.global_position - forward * (follow_distance + pullback) + Vector3.UP * follow_height
	desired_position += _game_feel_impulse
	var anchor := _get_camera_anchor()
	var base_look_target := _build_look_target(forward, false)
	var current_view_blocked: bool = not _has_clear_forward_view(global_position, base_look_target)
	var resolved_position := _resolve_obstructed_position(anchor, desired_position)
	var previous_forward_adjusted: bool = _forward_visibility_adjusted
	_forward_visibility_adjusted = false
	resolved_position = _resolve_forward_visibility(anchor, forward, base_look_target, resolved_position)
	var was_obstructed := _camera_obstructed
	_camera_obstructed = resolved_position.distance_squared_to(desired_position) > 0.01
	_last_desired_position = desired_position
	_last_resolved_position = resolved_position

	# If the camera is already inside an upper road, mountain mass or building,
	# smoothing keeps the screen buried in geometry. Escape immediately to the
	# already validated safe candidate. Recovery after the view clears is still
	# smoothed so this only snaps when player visibility is actually lost.
	if emergency_snap_when_occluded and current_view_blocked:
		global_position = resolved_position
		_emergency_snap_count += 1
	else:
		var smoothing := position_smoothing
		if _camera_obstructed or _forward_visibility_adjusted:
			smoothing = obstructed_smoothing
		elif was_obstructed or previous_forward_adjusted:
			smoothing = recovery_smoothing
		var weight := 1.0 - exp(-smoothing * delta)
		global_position = global_position.lerp(resolved_position, weight)

	var look_target := _build_look_target(forward, _forward_visibility_adjusted)
	look_at(look_target, Vector3.UP)

func add_game_feel_impulse(direction: Vector3, strength: float) -> void:
	if direction.length_squared() <= 0.0001 or strength <= 0.0:
		return
	var amount := minf(impulse_max_offset, strength)
	var world_direction := direction.normalized()
	# Tiny positional impulse only. No rotational shake is used so readability and
	# motion comfort remain stable during repeated body checks and landings.
	_game_feel_impulse += world_direction * amount
	if _game_feel_impulse.length() > impulse_max_offset:
		_game_feel_impulse = _game_feel_impulse.normalized() * impulse_max_offset

func request_finish_pullback(duration: float = 1.6, amount: float = 3.2) -> void:
	_finish_pullback_duration = maxf(0.05, duration)
	_finish_pullback_remaining = _finish_pullback_duration
	_finish_pullback_amount = clampf(amount, 0.0, finish_pullback_max)

func request_target_focus(world_position: Vector3, duration: float = 0.75) -> void:
	_focus_point = world_position
	_focus_duration = maxf(0.05, duration)
	_focus_remaining = _focus_duration

func is_camera_obstructed() -> bool:
	return _camera_obstructed or _forward_visibility_adjusted

func get_last_desired_position() -> Vector3:
	return _last_desired_position

func get_last_resolved_position() -> Vector3:
	return _last_resolved_position

func get_emergency_snap_count() -> int:
	return _emergency_snap_count

func _update_game_feel(delta: float) -> void:
	_game_feel_impulse = _game_feel_impulse.lerp(Vector3.ZERO, 1.0 - exp(-impulse_decay * delta))
	_finish_pullback_remaining = maxf(0.0, _finish_pullback_remaining - delta)
	_focus_remaining = maxf(0.0, _focus_remaining - delta)

func _get_finish_pullback() -> float:
	if _finish_pullback_remaining <= 0.0 or _finish_pullback_duration <= 0.0:
		return 0.0
	var normalized := _finish_pullback_remaining / _finish_pullback_duration
	var envelope := sin((1.0 - normalized) * PI)
	return _finish_pullback_amount * maxf(0.0, envelope)

func _get_camera_anchor() -> Vector3:
	if _target == null:
		return global_position
	return _target.global_position + Vector3.UP * target_anchor_height

func _build_look_target(forward: Vector3, visibility_adjusted: bool) -> Vector3:
	if _target == null:
		return global_position + forward
	var extra_look: float = 1.0 if visibility_adjusted else 0.0
	var look_height: float = 1.30 if visibility_adjusted else (0.88 if _camera_obstructed else 1.0)
	var base_target := _target.global_position + forward * (look_ahead + extra_look) + Vector3.UP * look_height
	if _focus_remaining > 0.0 and _focus_duration > 0.0:
		var normalized := _focus_remaining / _focus_duration
		var envelope := sin((1.0 - normalized) * PI)
		return base_target.lerp(_focus_point, clampf(envelope * focus_blend_max, 0.0, focus_blend_max))
	return base_target

func _resolve_obstructed_position(anchor: Vector3, desired_position: Vector3) -> Vector3:
	if not obstruction_enabled or _target == null or get_world_3d() == null:
		return desired_position
	var ray := desired_position - anchor
	if ray.length_squared() <= 0.001:
		return desired_position
	var ray_direction := ray.normalized()
	var query := PhysicsRayQueryParameters3D.new()
	query.from = anchor
	query.to = desired_position
	query.collision_mask = obstruction_mask
	query.collide_with_areas = false
	# Critical for stacked mountain switchbacks: the desired camera point can
	# already be inside the upper road/terrain collider.
	query.hit_from_inside = true
	if _target is CollisionObject3D:
		query.exclude = [(_target as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired_position

	var hit_position: Vector3 = hit.get("position", desired_position)
	var safe_distance := maxf(0.35, anchor.distance_to(hit_position) - obstruction_clearance)
	return anchor + ray_direction * safe_distance

func _resolve_forward_visibility(
	anchor: Vector3,
	forward: Vector3,
	look_target: Vector3,
	current_position: Vector3
) -> Vector3:
	if not forward_visibility_enabled or _target == null or get_world_3d() == null:
		return current_position
	if _has_clear_forward_view(current_position, look_target):
		return current_position

	# First try a tight shoulder-camera position. This is deliberately lower than
	# the old elevated candidates and works under stacked roads / overhead masses.
	var close_candidate: Vector3 = (
		_target.global_position
		- forward * emergency_close_distance
		+ Vector3.UP * emergency_close_height
	)
	close_candidate = _resolve_obstructed_position(anchor, close_candidate)
	if _has_clear_forward_view(close_candidate, look_target):
		_forward_visibility_adjusted = true
		return close_candidate

	var near_candidate: Vector3 = (
		_target.global_position
		- forward * (follow_distance * forward_visibility_near_ratio)
		+ Vector3.UP * (follow_height + forward_visibility_near_lift)
	)
	near_candidate = _resolve_obstructed_position(anchor, near_candidate)
	if _has_clear_forward_view(near_candidate, look_target):
		_forward_visibility_adjusted = true
		return near_candidate

	var high_candidate: Vector3 = (
		_target.global_position
		- forward * (follow_distance * forward_visibility_high_ratio)
		+ Vector3.UP * (follow_height + forward_visibility_high_lift)
	)
	high_candidate = _resolve_obstructed_position(anchor, high_candidate)
	if _has_clear_forward_view(high_candidate, look_target):
		_forward_visibility_adjusted = true
		return high_candidate

	# Final fallback: stay very close to the animal rather than leaving the camera
	# buried behind a giant foreground polygon. This keeps gameplay readable in a
	# real tunnel as well, without teleporting the racer or changing collision.
	var fallback: Vector3 = _target.global_position - forward * 2.2 + Vector3.UP * 3.2
	fallback = _resolve_obstructed_position(anchor, fallback)
	_forward_visibility_adjusted = true
	return fallback

func _has_clear_forward_view(camera_position: Vector3, look_target: Vector3) -> bool:
	if get_world_3d() == null:
		return true
	var query := PhysicsRayQueryParameters3D.new()
	query.from = camera_position
	query.to = look_target
	query.collision_mask = obstruction_mask
	query.collide_with_areas = false
	# Detect the exact failure seen in mountain switchbacks: camera starts inside
	# an upper road/terrain collision volume.
	query.hit_from_inside = true
	if _target is CollisionObject3D:
		query.exclude = [(_target as CollisionObject3D).get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var hit_position: Vector3 = hit.get("position", look_target)
	return hit_position.distance_to(look_target) <= forward_visibility_endpoint_tolerance

func _apply_target_profile() -> void:
	if not _target is WildDashCharacterController:
		return
	var racer := _target as WildDashCharacterController
	var profile: Dictionary = racer.get_camera_profile()
	follow_distance = float(profile.get("follow_distance", follow_distance))
	follow_height = float(profile.get("follow_height", follow_height))
	look_ahead = float(profile.get("look_ahead", look_ahead))
	position_smoothing = float(profile.get("smoothing", position_smoothing))
	fov = float(profile.get("fov", fov))
