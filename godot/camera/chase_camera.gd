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

func set_target(target: Node3D) -> void:
	_target = target
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
