class_name WildDashRacingFeelController
extends Node

const SPEED_LINES_SCRIPT: Script = preload("res://camera/speed_lines_overlay.gd")

@export_group("Speed Camera")
@export var fov_gain := 7.0
@export var boost_fov_bonus := 2.4
@export var fov_smoothing := 7.5
@export var speed_lines_enabled := true

@export_group("Arcade Corner Slip")
@export var corner_slip_enabled := true
@export var slip_start_speed_ratio := 0.56
@export var slip_strength := 0.085
@export var slip_response := 5.2
@export var slip_release := 6.8
@export var boost_slip_multiplier := 1.18
@export var max_slip_speed := 2.0
@export var body_lean_radians := 0.075

var _racer: WildDashCharacterController
var _camera: Camera3D
var _base_fov := -1.0
var _slip_speed := 0.0
var _slip_sign := 0.0
var _overlay: WildDashSpeedLinesOverlay
var _reported_ready := false

func _ready() -> void:
	# Race modes create the Player and ChaseCamera from their parent _ready().
	# Run this controller later than gameplay nodes so the tiny arcade slip is
	# applied after the normal CharacterBody3D race movement for the frame.
	process_priority = 100
	if DisplayServer.get_name() != "headless" and speed_lines_enabled:
		var canvas := CanvasLayer.new()
		canvas.name = "RacingSpeedFX"
		canvas.layer = 8
		add_child(canvas)
		_overlay = SPEED_LINES_SCRIPT.new() as WildDashSpeedLinesOverlay
		_overlay.name = "SpeedLinesOverlay"
		canvas.add_child(_overlay)
		_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	_resolve_runtime_nodes()
	if _racer == null or _camera == null:
		return
	if _base_fov < 0.0:
		_base_fov = _camera.fov
	var speed_ratio := _get_speed_ratio()
	var boosted := _is_boosted(speed_ratio)
	var fov_factor := clampf((speed_ratio - 0.48) / 0.62, 0.0, 1.0)
	var target_fov := _base_fov + fov_factor * fov_gain
	if boosted:
		target_fov += boost_fov_bonus * clampf(maxf(speed_ratio - 0.92, 0.35), 0.35, 1.0)
	var weight := 1.0 - exp(-fov_smoothing * delta)
	_camera.fov = lerpf(_camera.fov, target_fov, weight)

	if _overlay != null:
		var line_strength := clampf((speed_ratio - 0.58) / 0.52, 0.0, 1.0)
		if boosted:
			line_strength = minf(1.0, line_strength + 0.18)
		_overlay.set_effect_strength(line_strength, boosted)
	_update_visual_lean(delta, speed_ratio)

func _physics_process(delta: float) -> void:
	_resolve_runtime_nodes()
	if not corner_slip_enabled or _racer == null or not _racer.is_player:
		_release_slip(delta)
		return
	if _racer.movement_mode != WildDashCharacterController.MovementMode.RACE or not RaceManager.active or _racer.finished:
		_release_slip(delta)
		return
	if not _racer.is_on_floor():
		_release_slip(delta)
		return

	var steer := InputManager.get_steer_axis()
	var steer_amount := absf(steer)
	var speed_ratio := _get_speed_ratio()
	if steer_amount < 0.14 or speed_ratio <= slip_start_speed_ratio:
		_release_slip(delta)
		return

	var current_sign := signf(steer)
	if _slip_sign != 0.0 and current_sign != _slip_sign:
		_slip_speed *= 0.42
	_slip_sign = current_sign
	var speed_factor := clampf((speed_ratio - slip_start_speed_ratio) / maxf(0.01, 1.08 - slip_start_speed_ratio), 0.0, 1.0)
	var desired_slip := _racer.current_speed * slip_strength * speed_factor * steer_amount * _get_archetype_slip_multiplier()
	if _is_boosted(speed_ratio):
		desired_slip *= boost_slip_multiplier
	desired_slip = minf(max_slip_speed, desired_slip)
	_slip_speed = move_toward(_slip_speed, desired_slip, slip_response * delta)

	var right := _racer.global_transform.basis.x.normalized()
	var outward := -right * current_sign
	var collision := _racer.move_and_collide(outward * _slip_speed * delta)
	if collision != null:
		_slip_speed *= 0.28

func _resolve_runtime_nodes() -> void:
	if _racer == null or not is_instance_valid(_racer):
		_racer = get_parent().get_node_or_null("Player") as WildDashCharacterController
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_parent().get_node_or_null("ChaseCamera") as Camera3D
	if not _reported_ready and _racer != null and _camera != null:
		_reported_ready = true
		_base_fov = _camera.fov
		print("RACING FEEL READY fov_base=%.1f dynamic_fov=true speed_lines=%s player_slip=true ai_slip=false" % [_base_fov, str(_overlay != null)])

func _get_speed_ratio() -> float:
	if _racer == null:
		return 0.0
	return maxf(0.0, _racer.current_speed) / maxf(0.1, _racer.max_speed)

func _is_boosted(speed_ratio: float) -> bool:
	if _racer == null:
		return false
	return _racer.get_active_speed_scale() > 1.02 or speed_ratio > 1.02

func _get_archetype_slip_multiplier() -> float:
	if _racer == null:
		return 1.0
	match _racer.animal_id:
		&"elephant", &"bear", &"panda":
			return 1.18
		&"rabbit", &"deer", &"monkey":
			return 0.92
		&"cat", &"fox", &"raccoon":
			return 0.82
		&"dog", &"wolf", &"boar":
			return 1.0
		_:
			return 1.0

func _release_slip(delta: float) -> void:
	_slip_speed = move_toward(_slip_speed, 0.0, slip_release * delta)
	if _slip_speed <= 0.01:
		_slip_speed = 0.0
		_slip_sign = 0.0

func _update_visual_lean(delta: float, speed_ratio: float) -> void:
	if _racer == null:
		return
	var visual := _racer.get_visual()
	if visual == null:
		return
	var target_roll := 0.0
	if RaceManager.active and not _racer.finished and _racer.is_on_floor():
		var speed_factor := clampf((speed_ratio - 0.42) / 0.58, 0.0, 1.0)
		target_roll = -InputManager.get_steer_axis() * body_lean_radians * speed_factor
	visual.rotation.z = lerp_angle(visual.rotation.z, target_roll, 1.0 - exp(-8.0 * delta))
