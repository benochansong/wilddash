extends Camera3D

@export var target_path: NodePath
@export var follow_distance := 9.5
@export var follow_height := 5.2
@export var look_ahead := 4.5
@export var position_smoothing := 7.0

var _target: Node3D

func _ready() -> void:
	if not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node3D
		_apply_target_profile()

func set_target(target: Node3D) -> void:
	_target = target
	_apply_target_profile()
	if _target != null:
		var forward := -_target.global_transform.basis.z.normalized()
		global_position = _target.global_position - forward * follow_distance + Vector3.UP * follow_height

func _process(delta: float) -> void:
	if _target == null:
		return
	var forward := -_target.global_transform.basis.z.normalized()
	var desired_position := _target.global_position - forward * follow_distance + Vector3.UP * follow_height
	var weight := 1.0 - exp(-position_smoothing * delta)
	global_position = global_position.lerp(desired_position, weight)
	var look_target := _target.global_position + forward * look_ahead + Vector3.UP * 1.0
	look_at(look_target, Vector3.UP)

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
