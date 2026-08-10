class_name WildDashDynamicObstacle
extends AnimatableBody3D

enum MotionType {
	ROTATE,
	SWEEP,
}

@export var motion_type: MotionType = MotionType.ROTATE
@export var motion_speed := 1.6
@export var amplitude := 4.0

var _origin := Vector3.ZERO
var _elapsed := 0.0
var _base_motion_speed := 1.6

func _ready() -> void:
	_origin = position
	_base_motion_speed = motion_speed

func set_difficulty_speed_scale(scale: float) -> void:
	if _base_motion_speed <= 0.0:
		_base_motion_speed = motion_speed
	motion_speed = _base_motion_speed * clampf(scale, 0.5, 1.6)

func get_base_motion_speed() -> float:
	return _base_motion_speed

func _physics_process(delta: float) -> void:
	_elapsed += delta
	match motion_type:
		MotionType.ROTATE:
			rotation.y += motion_speed * delta
		MotionType.SWEEP:
			position = _origin + global_transform.basis.x.normalized() * sin(_elapsed * motion_speed) * amplitude
