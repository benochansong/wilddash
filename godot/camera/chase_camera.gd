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
@export var minimum_camera_distance := 2.6

var _target: Node3D
var _camera_obstructed := false
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
		var resolved_position := _resolve_obstructed_position(anchor, desired_position)
		global_position = resolved_position
		_last_desired_position = desired_position
		_last_resolved_position = resolved_position

func _process(delta: float) -> void:
	if _target == null:
		return
	var forward := -_target.global_transform.basis.z.normalized()
	var desired_position := _target.global_position - forward * follow_distance + Vector3.UP * follow_height
	var anchor := _get_camera_anchor()
	var resolved_position := _resolve_obstructed_position(anchor, desired_position)
	var was_obstructed := _camera_obstructed
	_camera_obstructed = resolved_position.distance_squared_to(desired_position) > 0.01
	_last_desired_position = desired_position
	_last_resolved_position = resolved_position

	# Enter enclosed spaces quickly so the camera never rides above the tunnel roof.
	# Recover more gently on exit to avoid a visible snap back to the outdoor profile.
	var smoothing := position_smoothing
	if _camera_obstructed:
		smoothing = obstructed_smoothing
	elif was_obstructed:
		smoothing = recovery_smoothing
	var weight := 1.0 - exp(-smoothing * delta)
	global_position = global_position.lerp(resolved_position, weight)

	var look_height := 0.88 if _camera_obstructed else 1.0
	var look_target := _target.global_position + forward * look_ahead + Vector3.UP * look_height
	look_at(look_target, Vector3.UP)

func is_camera_obstructed() -> bool:
	return _camera_obstructed

func get_last_desired_position() -> Vector3:
	return _last_desired_position

func get_last_resolved_position() -> Vector3:
	return _last_resolved_position

func _get_camera_anchor() -> Vector3:
	if _target == null:
		return global_position
	return _target.global_position + Vector3.UP * target_anchor_height

func _resolve_obstructed_position(anchor: Vector3, desired_position: Vector3) -> Vector3:
	if not obstruction_enabled or _target == null or get_world_3d() == null:
		return desired_position
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

	var hit_position: Vector3 = hit.get("position", desired_position)
	var hit_normal: Vector3 = hit.get("normal", Vector3.ZERO)
	var candidate := hit_position + hit_normal * obstruction_clearance

	# Keep enough separation from the racer for a readable third-person view even
	# when the tunnel roof or side wall forces the normal outdoor camera inward.
	var from_anchor := candidate - anchor
	if from_anchor.length() < minimum_camera_distance:
		var desired_direction := desired_position - anchor
		if desired_direction.length_squared() > 0.001:
			candidate = anchor + desired_direction.normalized() * minimum_camera_distance
	return candidate

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
