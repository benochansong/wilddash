extends "res://camera/chase_camera.gd"

## Round 3-only recovery and readability camera adapter.
## Water recovery keeps independent yaw. Normal racing may supply a modest
## world-space focus so moving logs, Titan branches and the Crown Nest remain
## readable without stealing player control or changing the shared camera.

const RECOVERY_MOUSE_YAW_SENSITIVITY: float = 0.0035
const RECOVERY_GAMEPAD_YAW_SPEED: float = 1.9
const RECOVERY_POSITION_SMOOTHING: float = 9.5
const RECOVERY_FOCUS_BLEND: float = 0.28
const RECOVERY_FOCUS_MAX_DISTANCE: float = 38.0
const RECOVERY_DISTANCE_SCALE: float = 0.86
const RECOVERY_HEIGHT_SCALE: float = 0.86
const RACE_FOCUS_MAX_DISTANCE: float = 58.0
const RACE_FOCUS_MIN_BLEND: float = 0.08
const RACE_FOCUS_MAX_BLEND: float = 0.34

var _recovery_mode: bool = false
var _recovery_focus := Vector3.ZERO
var _recovery_yaw: float = 0.0
var _race_focus_active: bool = false
var _race_focus := Vector3.ZERO
var _race_focus_blend: float = 0.16

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

func set_race_focus(world_point: Vector3, blend_strength: float = 0.16) -> void:
	_race_focus_active = true
	_race_focus = world_point
	_race_focus_blend = clampf(blend_strength, RACE_FOCUS_MIN_BLEND, RACE_FOCUS_MAX_BLEND)

func clear_race_focus() -> void:
	_race_focus_active = false

func is_race_focus_active() -> bool:
	return _race_focus_active and not _recovery_mode

func _unhandled_input(event: InputEvent) -> void:
	if not _recovery_mode:
		return
	var mouse_motion := event as InputEventMouseMotion
	if mouse_motion != null:
		_recovery_yaw -= mouse_motion.relative.x * RECOVERY_MOUSE_YAW_SENSITIVITY

func _process(delta: float) -> void:
	super(delta)
	if _target == null:
		return
	if not _recovery_mode:
		_apply_race_focus()
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

func _apply_race_focus() -> void:
	if not _race_focus_active or _target == null:
		return
	var racer_forward := -_target.global_transform.basis.z
	racer_forward.y = 0.0
	if racer_forward.length_squared() <= 0.001:
		racer_forward = Vector3.FORWARD
	else:
		racer_forward = racer_forward.normalized()
	var look_origin := _target.global_position + Vector3.UP * 1.0
	var to_focus := _race_focus - look_origin
	var distance: float = to_focus.length()
	if distance <= 0.35 or distance > RACE_FOCUS_MAX_DISTANCE:
		return
	var direction := to_focus / distance
	if direction.dot(racer_forward) < -0.18:
		return
	var base_look := _build_look_target(racer_forward, false)
	var framed := base_look.lerp(_race_focus, _race_focus_blend)
	look_at(framed, Vector3.UP)
