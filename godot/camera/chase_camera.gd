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

@export_group("Forward Visibility")
@export var forward_visibility_enabled := true
@export var forward_visibility_near_ratio := 0.72
@export var forward_visibility_high_ratio := 0.54
@export var forward_visibility_near_lift := 2.4
@export var forward_visibility_high_lift := 4.8
@export var forward_visibility_endpoint_tolerance := 1.25

var _target: Node3D
var _camera_obstructed := false
var _forward_visibility_adjusted := false
var _last_desired_position := Vector3.ZERO
var _last_resolved_position := Vector3.ZERO

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
	var forward := -_target.global_transform.basis.z.normalized()
	var desired_position := _target.global_position - forward * follow_distance + Vector3.UP * follow_height
	var anchor := _get_camera_anchor()
	var base_look_target := _build_look_target(forward, false)
	var resolved_position := _resolve_obstructed_position(anchor, desired_position)
	var previous_forward_adjusted: bool = _forward_visibility_adjusted
	_forward_visibility_adjusted = false
	resolved_position = _resolve_forward_visibility(anchor, forward, base_look_target, resolved_position)
	var was_obstructed := _camera_obstructed
	_camera_obstructed = resolved_position.distance_squared_to(desired_position) > 0.01
	_last_desired_position = desired_position
	_last_resolved_position = resolved_position

	# Enter enclosed/occluded spaces quickly so the animal and the road ahead stay
	# visible. Recover more gently after the sightline clears to avoid camera snap.
	var smoothing := position_smoothing
	if _camera_obstructed or _forward_visibility_adjusted:
		smoothing = obstructed_smoothing
	elif was_obstructed or previous_forward_adjusted:
		smoothing = recovery_smoothing
	var weight := 1.0 - exp(-smoothing * delta)
	global_position = global_position.lerp(resolved_position, weight)

	var look_target := _build_look_target(forward, _forward_visibility_adjusted)
	look_at(look_target, Vector3.UP)

func is_camera_obstructed() -> bool:
	return _camera_obstructed or _forward_visibility_adjusted

func get_last_desired_position() -> Vector3:
	return _last_desired_position

func get_last_resolved_position() -> Vector3:
	return _last_resolved_position

func _get_camera_anchor() -> Vector3:
	if _target == null:
		return global_position
	return _target.global_position + Vector3.UP * target_anchor_height

func _build_look_target(forward: Vector3, visibility_adjusted: bool) -> Vector3:
	if _target == null:
		return global_position + forward
	var extra_look: float = 1.0 if visibility_adjusted else 0.0
	var look_height: float = 1.30 if visibility_adjusted else (0.88 if _camera_obstructed else 1.0)
	return _target.global_position + forward * (look_ahead + extra_look) + Vector3.UP * look_height

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
	query.hit_from_inside = false
	if _target is CollisionObject3D:
		query.exclude = [(_target as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired_position

	# Stay on the racer side of the blocking roof/wall. Pulling backward along the
	# ray is more reliable than pushing along the surface normal at tunnel corners.
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

	# If both elevated candidates are still enclosed (for example inside a real
	# tunnel), keep the existing obstruction-safe position rather than forcing the
	# camera through geometry.
	return current_position

func _has_clear_forward_view(camera_position: Vector3, look_target: Vector3) -> bool:
	if get_world_3d() == null:
		return true
	var query := PhysicsRayQueryParameters3D.new()
	query.from = camera_position
	query.to = look_target
	query.collision_mask = obstruction_mask
	query.collide_with_areas = false
	query.hit_from_inside = false
	if _target is CollisionObject3D:
		query.exclude = [(_target as CollisionObject3D).get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var hit_position: Vector3 = hit.get("position", look_target)
	# A floor hit right at the look target is not a meaningful camera occluder.
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
