class_name WildDashDynamicObstacle
extends AnimatableBody3D

enum MotionType {
	ROTATE,
	SWEEP,
	OPEN_CLOSE,
	CROSS,
}

@export var motion_type: MotionType = MotionType.ROTATE
@export var motion_speed := 1.6
@export var amplitude := 4.0
@export var phase_offset := 0.0

var _origin := Vector3.ZERO
var _elapsed := 0.0

func _ready() -> void:
	_origin = position

func _physics_process(delta: float) -> void:
	_elapsed += delta
	var phase := _elapsed * motion_speed + phase_offset
	match motion_type:
		MotionType.ROTATE:
			rotation.y += motion_speed * delta
		MotionType.SWEEP:
			position = _origin + global_transform.basis.x.normalized() * sin(phase) * amplitude
		MotionType.OPEN_CLOSE:
			# Starts low, rises to leave a readable opening, then returns. This is
			# useful for warehouse shutters and dock gates without new physics code.
			position = _origin + Vector3.UP * ((sin(phase) + 1.0) * 0.5) * amplitude
		MotionType.CROSS:
			# Same lightweight sinusoidal motion as SWEEP, but named explicitly for
			# vehicles/cargo that cross the racing line so tests/design data can
			# distinguish them from generic sweepers.
			position = _origin + global_transform.basis.x.normalized() * sin(phase) * amplitude
