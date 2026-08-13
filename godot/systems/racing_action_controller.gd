class_name WildDashRacingActionController
extends Node

## RC9 arcade race actions layered on top of the proven CharacterController.
## W/Up remains normal throttle input, but while held it now has a clear
## overdrive envelope above max_speed so the player can feel the difference.
## F / Gamepad Y performs a short-range body check with species-weighted force.

const OVERDRIVE_SPEED_MULTIPLIER := 1.12
const OVERDRIVE_ACCELERATION_MULTIPLIER := 2.15
const BODY_CHECK_COOLDOWN := 2.45
const BODY_CHECK_RANGE := 2.65
const BODY_CHECK_FORWARD_DOT := -0.08
const ATTACKER_SPEED_RETENTION := 0.98
const TARGET_SPEED_RETENTION := 0.93

var _racer: WildDashCharacterController
var _body_check_cooldown := 0.0
var _overdrive_reported := false

func _ready() -> void:
	# CharacterController uses the default priority. Run after movement so this
	# controller can establish the next-frame overdrive target, but before the
	# RacingFeelController (100) samples speed for FOV/speed-line feedback.
	process_priority = 80

func _physics_process(delta: float) -> void:
	_resolve_player()
	_body_check_cooldown = maxf(0.0, _body_check_cooldown - delta)
	if _racer == null or not RaceManager.active or _racer.finished:
		_overdrive_reported = false
		return

	_apply_overdrive(delta)
	if InputManager.consume_race_bump():
		_try_body_check()

func get_body_check_cooldown_remaining() -> float:
	return _body_check_cooldown

func is_overdrive_active() -> bool:
	return _racer != null and RaceManager.active and InputManager.get_throttle_axis() > 0.05

static func get_overdrive_target(max_speed: float, throttle: float) -> float:
	var amount := clampf(throttle, 0.0, 1.0)
	return max_speed * lerpf(1.0, OVERDRIVE_SPEED_MULTIPLIER, amount)

static func get_body_check_strength(animal_id: StringName) -> float:
	match animal_id:
		&"elephant": return 4.60
		&"bear": return 4.05
		&"boar": return 3.85
		&"panda": return 3.65
		&"wolf": return 3.20
		&"dog": return 3.00
		&"deer": return 2.75
		&"rabbit": return 2.55
		&"monkey": return 2.55
		&"fox": return 2.45
		&"cat": return 2.35
		&"raccoon": return 2.25
		_: return 2.60

func _apply_overdrive(delta: float) -> void:
	var throttle := InputManager.get_throttle_axis()
	if throttle <= 0.05:
		_overdrive_reported = false
		return
	var target := get_overdrive_target(_racer.max_speed, throttle)
	var overdrive_acceleration := _racer.acceleration * _racer.get_active_acceleration_scale() * OVERDRIVE_ACCELERATION_MULTIPLIER
	_racer.current_speed = move_toward(_racer.current_speed, target, overdrive_acceleration * delta)
	if not _overdrive_reported and _racer.current_speed > _racer.max_speed * 1.015:
		_overdrive_reported = true
		print("RC9 W OVERDRIVE ACTIVE racer=%s speed=%.2f base_max=%.2f target=%.2f" % [
			_racer.name, _racer.current_speed, _racer.max_speed, target,
		])

func _try_body_check() -> void:
	if _body_check_cooldown > 0.0:
		return
	var target := _find_body_check_target()
	if target == null:
		return
	var offset := target.global_position - _racer.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return
	var strength := get_body_check_strength(_racer.animal_id)
	var direction := offset.normalized()
	# A little forward bias keeps the hit readable as a shoulder/body check
	# instead of a sideways launch. Strength remains intentionally modest.
	var forward := -_racer.global_transform.basis.z.normalized()
	var push_direction := (direction * 0.78 + forward * 0.22).normalized()
	target.apply_knockback(push_direction, strength)
	target.current_speed *= TARGET_SPEED_RETENTION
	_racer.current_speed *= ATTACKER_SPEED_RETENTION
	_body_check_cooldown = BODY_CHECK_COOLDOWN
	AudioManager.play_sfx_id("hit", 0.82)
	var attacker_visual := _racer.get_visual()
	if attacker_visual != null:
		attacker_visual.play_action(&"Skill", 0.22)
	var target_visual := target.get_visual()
	if target_visual != null:
		target_visual.play_action(&"Hit", 0.20)
	print("RC9 BODY CHECK attacker=%s animal=%s target=%s strength=%.2f cooldown=%.2f" % [
		_racer.name, String(_racer.animal_id), target.name, strength, BODY_CHECK_COOLDOWN,
	])

func _find_body_check_target() -> WildDashCharacterController:
	var best: WildDashCharacterController = null
	var best_distance := INF
	var forward := -_racer.global_transform.basis.z.normalized()
	for candidate: Node3D in RaceManager.racers:
		if candidate == _racer or not candidate is WildDashCharacterController:
			continue
		var controller := candidate as WildDashCharacterController
		if controller.finished:
			continue
		var offset := controller.global_position - _racer.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance <= 0.01 or distance > BODY_CHECK_RANGE:
			continue
		var alignment := forward.dot(offset / distance)
		if alignment < BODY_CHECK_FORWARD_DOT:
			continue
		if distance < best_distance:
			best_distance = distance
			best = controller
	return best

func _resolve_player() -> void:
	if _racer != null and is_instance_valid(_racer):
		return
	var parent := get_parent()
	if parent == null:
		return
	_racer = parent.get_node_or_null("Player") as WildDashCharacterController
