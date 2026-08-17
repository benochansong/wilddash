extends "res://camera/chase_camera.gd"

## Round 3-only recovery camera adapter.
## Normal race camera behaviour is untouched until WaterRecovery explicitly
## supplies a recovery focus. While active, yaw is independent from racer yaw,
## so camera-relative W remains stable instead of feeding back into steering.

const RECOVERY_MOUSE_YAW_SENSITIVITY: float = 0.0035
const RECOVERY_GAMEPAD_YAW_SPEED: float = 1.9
const RECOVERY_POSITION_SMOOTHING: float = 9.5
const RECOVERY_FOCUS_BLEND: float = 0.28
const RECOVERY_FOCUS_MAX_DISTANCE: float = 38.0
const RECOVERY_DISTANCE_SCALE: float = 0.86
const RECOVERY_HEIGHT_SCALE: float = 0.86

var _recovery_mode: bool = false
var _recovery_focus := Vector3.ZERO
var _recovery_yaw: float = 0.0

func set_recovery_focus(world_point: Vector3) -> void:
	if not _recovery_mode:
		_recovery_mode = true
		var current_forward := -global_transform.basis.z
		current_forward.y = 0.0
		if current_forward.length_squared() <= 0.001:
			current_forward = Vector3.FORWARD
		else:
			current_forward = current_forward.normalized()
		_recovery_yaw = atan2(-current_forward.x, -current_forward.z)
	_recovery_focus = world_point

func clear_recovery_focus() -> void:
	_recovery_mode = false

func is_recovery_camera_active() -> bool:
	return _recovery_mode

func _unhandled_input(event: InputEvent) -> void:
	if not _recovery_mode:
		return
	var mouse_motion := event as InputEventMouseMotion
	if mouse_motion != null:
		_recovery_yaw -= mouse_motion.relative.x * RECOVERY_MOUSE_YAW_SENSITIVITY

func _process(delta: float) -> void:
	super(delta)
	if not _recovery_mode or _target == null:
		return

	var stick_x: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(stick_x) >= 0.18:
		_recovery_yaw -= stick_x * RECOVERY_GAMEPAD_YAW_SPEED * delta

	var view_forward := Vector3(-sin(_recovery_yaw), 0.0, -cos(_recovery_yaw))
	if view_forward.length_squared() <= 0.001:
		view_forward = Vector3.FORWARD
	else:
		view_forward = view_forward.normalized()

	var anchor := _get_camera_anchor()
	var desired_position := (
		_target.global_position
		- view_forward * follow_distance * RECOVERY_DISTANCE_SCALE
		+ Vector3.UP * follow_height * RECOVERY_HEIGHT_SCALE
	)
	var resolved_position := _resolve_obstructed_position(anchor, desired_position)
	var weight: float = 1.0 - exp(-RECOVERY_POSITION_SMOOTHING * delta)
	global_position = global_position.lerp(resolved_position, weight)

	var look_origin := _target.global_position + Vector3.UP * 1.0
	var look_target := look_origin + view_forward * maxf(4.0, look_ahead * 0.72)
	var to_focus := _recovery_focus - look_origin
	var focus_distance: float = to_focus.length()
	if focus_distance > 0.25 and focus_distance <= RECOVERY_FOCUS_MAX_DISTANCE:
		var focus_direction := to_focus.normalized()
		# Do not yank the camera backwards. A target roughly within the current
		# hemisphere receives a modest framing blend while mouse/right-stick yaw
		# remains authoritative.
		if focus_direction.dot(view_forward) > -0.20:
			look_target = look_target.lerp(_recovery_focus + Vector3.UP * 0.75, RECOVERY_FOCUS_BLEND)
	look_at(look_target, Vector3.UP)
