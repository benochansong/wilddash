class_name WildDashAIController
extends Node

@export var racer_path: NodePath
@export var target_speed := 10.0
@export var lane_wander := 2.5
@export var steering_strength := 1.2

var _racer: WildDashCharacterController
var _phase := 0.0

func _ready() -> void:
	_racer = get_node_or_null(racer_path) as WildDashCharacterController
	_phase = randf_range(0.0, TAU)
	if _racer != null:
		_racer.is_player = false

func _physics_process(delta: float) -> void:
	if _racer == null or not RaceManager.active:
		return

	# First-stage AI is deliberately simple: move forward and gently seek a
	# changing lane offset. Production AI will use track checkpoints/splines,
	# obstacle avoidance, overtaking and difficulty aggression.
	var desired_x := sin(Time.get_ticks_msec() * 0.001 + _phase) * lane_wander
	var error_x := desired_x - _racer.global_position.x
	_racer.rotate_y(-clampf(error_x * 0.05, -1.0, 1.0) * steering_strength * delta)

	var forward := -_racer.global_transform.basis.z.normalized()
	_racer.velocity.x = forward.x * target_speed
	_racer.velocity.z = forward.z * target_speed
	if not _racer.is_on_floor():
		_racer.velocity.y -= 22.0 * delta
	_racer.move_and_slide()
