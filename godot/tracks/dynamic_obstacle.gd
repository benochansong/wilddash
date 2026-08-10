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
var _difficulty_scale := 1.0

func _ready() -> void:
	_origin = position
	var profile := WildDashDifficultySystem.get_profile(GameManager.difficulty)
	_difficulty_scale = float(profile.get("obstacle_speed_scale", 1.0))
	print("OBSTACLE DIFFICULTY name=%s mode=%s speed_scale=%.2f" % [
		name,
		WildDashDifficultySystem.get_display_name(GameManager.difficulty),
		_difficulty_scale,
	])

func _physics_process(delta: float) -> void:
	_elapsed += delta
	var effective_speed := motion_speed * _difficulty_scale
	match motion_type:
		MotionType.ROTATE:
			rotation.y += effective_speed * delta
		MotionType.SWEEP:
			position = _origin + global_transform.basis.x.normalized() * sin(_elapsed * effective_speed) * amplitude

func get_effective_motion_speed() -> float:
	return motion_speed * _difficulty_scale
