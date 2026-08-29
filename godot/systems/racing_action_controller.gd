class_name WildDashRacingActionController
extends Node

## RC9 arcade race actions layered on top of CharacterController.
## W/Up is an energy-limited tactical boost, not a permanent throttle advantage.
## F / Gamepad Y is a weight-aware race contact action.
## Elephant replaces the single-target shoulder check with a multi-target trunk sweep.

const BASE_RACE_SPEED_RATIO: float = 0.91
const OVERDRIVE_SPEED_MULTIPLIER: float = 1.14
const OVERDRIVE_ACCELERATION_MULTIPLIER: float = 2.10
const BOOST_ENERGY_MAX: float = 100.0
const BOOST_ENERGY_COST: float = 100.0
const BOOST_RECHARGE_PER_SECOND: float = 22.0
const BOOST_DURATION: float = 1.05
const BOOST_READY_EPSILON: float = 0.05

const BODY_CHECK_COOLDOWN: float = 2.80
const BODY_CHECK_RANGE: float = 3.35
const BODY_CHECK_FORWARD_DOT: float = -0.20
const BODY_CHECK_MAX_VERTICAL_DELTA: float = 1.80
const BODY_CHECK_FEEDBACK_SECONDS: float = 0.80
const BODY_CHECK_POWER_SCALE: float = 0.84
const ATTACKER_SPEED_RETENTION: float = 0.97

const ELEPHANT_OPENING_SECONDS: float = 6.0
const ELEPHANT_TRUNK_RANGE: float = 5.80
const ELEPHANT_TRUNK_FORWARD_DOT: float = -0.32
const ELEPHANT_TRUNK_MAX_TARGETS: int = 2
const ELEPHANT_TRUNK_POWER_MULTIPLIER: float = 1.25
const ELEPHANT_TRUNK_COOLDOWN: float = 3.05
const ELEPHANT_OPENING_TRUNK_RANGE: float = 11.50
const ELEPHANT_OPENING_TRUNK_FORWARD_DOT: float = -0.80
const ELEPHANT_OPENING_TRUNK_MAX_TARGETS: int = 5
const ELEPHANT_OPENING_POWER_MULTIPLIER: float = 1.65
const ELEPHANT_OPENING_COOLDOWN: float = 1.45
const ELEPHANT_OPENING_SPEED_ASSIST_RATIO: float = 0.98

var _racer: WildDashCharacterController
var _body_check_cooldown: float = 0.0
var _body_check_feedback_remaining: float = 0.0
var _body_check_feedback_text: String = ""
var _boost_energy: float = BOOST_ENERGY_MAX
var _boost_remaining: float = 0.0
var _boost_reported: bool = false
var _boost_hold_locked: bool = false
var _race_elapsed: float = 0.0

func _ready() -> void:
	process_priority = 80

func _physics_process(delta: float) -> void:
	_resolve_player()
	_body_check_cooldown = maxf(0.0, _body_check_cooldown - delta)
	_body_check_feedback_remaining = maxf(0.0, _body_check_feedback_remaining - delta)
	if _body_check_feedback_remaining <= 0.0:
		_body_check_feedback_text = ""
	if _racer == null:
		return
	if not RaceManager.active or _racer.finished:
		_race_elapsed = 0.0
		_reset_boost_runtime(false)
		return

	_race_elapsed += delta
	_update_boost(delta)
	if InputManager.consume_race_bump():
		_try_race_contact_action()

func get_body_check_cooldown_remaining() -> float:
	return _body_check_cooldown

func get_contact_action_name() -> String:
	if _racer != null and _racer.animal_id == &"elephant":
		return "TRUNK SWEEP"
	return "BODY CHECK"

func get_body_check_status_text() -> String:
	if not _body_check_feedback_text.is_empty() and _body_check_feedback_remaining > 0.0:
		return _body_check_feedback_text
	if _body_check_cooldown > 0.01:
		return "COOLDOWN %.1fs" % _body_check_cooldown
	if _racer != null and _racer.animal_id == &"elephant":
		if _is_elephant_opening():
			var opening_left: float = maxf(0.0, ELEPHANT_OPENING_SECONDS - _race_elapsed)
			return "OPENING TRUNK %.1fs · F / Y" % opening_left
		return "SWEEP READY · F / Y"
	if _find_body_check_target() != null:
		return "TARGET IN RANGE · F / Y"
	return "READY · F / Y"

func get_current_body_check_power() -> float:
	if _racer == null:
		return 0.0
	var power: float = get_body_check_power(_racer.animal_id)
	if _racer.animal_id == &"elephant":
		power *= ELEPHANT_TRUNK_POWER_MULTIPLIER
		if _is_elephant_opening():
			power *= ELEPHANT_OPENING_POWER_MULTIPLIER
	return power

func is_overdrive_active() -> bool:
	return _boost_remaining > 0.0

func get_boost_energy() -> float:
	return _boost_energy

func get_boost_energy_ratio() -> float:
	return clampf(_boost_energy / BOOST_ENERGY_MAX, 0.0, 1.0)

func is_boost_ready() -> bool:
	return _boost_remaining <= 0.0 and _boost_energy >= BOOST_ENERGY_COST - BOOST_READY_EPSILON

func get_boost_status_text() -> String:
	if _boost_remaining > 0.0:
		return "BOOSTING %.1fs" % _boost_remaining
	if is_boost_ready():
		return "READY · W / ↑"
	return "CHARGING %d%%" % int(round(get_boost_energy_ratio() * 100.0))

static func get_overdrive_target(max_speed: float, throttle: float = 1.0) -> float:
	var amount: float = clampf(throttle, 0.0, 1.0)
	return max_speed * lerpf(1.0, OVERDRIVE_SPEED_MULTIPLIER, amount)

static func get_normal_race_target(max_speed: float, cruise_speed: float) -> float:
	return maxf(cruise_speed, max_speed * BASE_RACE_SPEED_RATIO)

static func get_body_check_power(animal_id: StringName) -> float:
	# Keep the historical Elephant baseline (10.0 ability -> 8.4 body-check)
	# while making the player-facing Power stat the authoritative ordering.
	return WildDashRaceCombatProfile.get_attack_power(animal_id) * BODY_CHECK_POWER_SCALE

static func get_body_check_resistance(animal_id: StringName) -> float:
	match animal_id:
		&"elephant": return 0.62
		&"bear": return 0.70
		&"boar": return 0.76
		&"panda": return 0.80
		&"wolf": return 0.90
		&"dog": return 0.93
		&"deer": return 0.98
		&"monkey": return 1.05
		&"rabbit": return 1.08
		&"fox": return 1.10
		&"cat": return 1.12
		&"raccoon": return 1.15
		_: return 1.00

static func calculate_body_check_impulse(attacker_id: StringName, target_id: StringName) -> float:
	return get_body_check_power(attacker_id) * get_body_check_resistance(target_id)

static func get_body_check_strength(animal_id: StringName) -> float:
	return get_body_check_power(animal_id)

func _update_boost(delta: float) -> void:
	var throttle: float = InputManager.get_throttle_axis()
	var boost_held: bool = throttle > 0.05
	if not boost_held:
		_boost_hold_locked = false

	if _boost_remaining > 0.0:
		_boost_remaining = maxf(0.0, _boost_remaining - delta)
		var boost_target: float = get_overdrive_target(_racer.max_speed)
		var boost_accel: float = _racer.acceleration * _racer.get_active_acceleration_scale() * OVERDRIVE_ACCELERATION_MULTIPLIER
		_racer.current_speed = move_toward(_racer.current_speed, boost_target, boost_accel * delta)
		if _boost_remaining <= 0.0:
			_boost_reported = false
		return

	_boost_energy = minf(BOOST_ENERGY_MAX, _boost_energy + BOOST_RECHARGE_PER_SECOND * delta)
	var normal_target: float = get_normal_race_target(_racer.max_speed, _racer.cruise_speed)
	if throttle >= -0.05 and _racer.get_active_speed_scale() <= 1.02:
		if _racer.current_speed > normal_target:
			_racer.current_speed = normal_target
		else:
			var recovery_accel: float = _racer.acceleration * _racer.get_active_acceleration_scale() * 1.20
			_racer.current_speed = move_toward(_racer.current_speed, normal_target, recovery_accel * delta)

	if boost_held and not _boost_hold_locked:
		_boost_hold_locked = true
		if _boost_energy >= BOOST_ENERGY_COST - BOOST_READY_EPSILON:
			_activate_boost()

func _activate_boost() -> void:
	_boost_energy = maxf(0.0, _boost_energy - BOOST_ENERGY_COST)
	_boost_remaining = BOOST_DURATION
	if not _boost_reported:
		_boost_reported = true
		print("RC9 BOOST BURST racer=%s duration=%.2f energy=%.0f recharge=%.1fs target=%.2f" % [
			_racer.name,
			BOOST_DURATION,
			_boost_energy,
			BOOST_ENERGY_MAX / BOOST_RECHARGE_PER_SECOND,
			get_overdrive_target(_racer.max_speed),
		])

func _reset_boost_runtime(refill: bool) -> void:
	_boost_remaining = 0.0
	_boost_reported = false
	_boost_hold_locked = false
	if refill:
		_boost_energy = BOOST_ENERGY_MAX

func _try_race_contact_action() -> void:
	if _body_check_cooldown > 0.0:
		return
	if _racer != null and _racer.animal_id == &"elephant":
		_try_elephant_trunk_sweep()
		return
	_try_body_check()

func _try_elephant_trunk_sweep() -> void:
	var opening: bool = _is_elephant_opening()
	var targets: Array[WildDashCharacterController] = _find_elephant_trunk_targets(opening)
	if targets.is_empty():
		_body_check_feedback_text = "TRUNK SWEEP · NO TARGET"
		_body_check_feedback_remaining = 0.50
		return

	var power_multiplier: float = ELEPHANT_TRUNK_POWER_MULTIPLIER
	if opening:
		power_multiplier *= ELEPHANT_OPENING_POWER_MULTIPLIER
	var strongest_impulse: float = 0.0
	var hit_count: int = 0
	var forward: Vector3 = -_racer.global_transform.basis.z.normalized()

	for target: WildDashCharacterController in targets:
		if target == null:
			continue
		var raw_offset: Vector3 = target.global_position - _racer.global_position
		var planar_offset: Vector3 = Vector3(raw_offset.x, 0.0, raw_offset.z)
		if planar_offset.length_squared() <= 0.001:
			continue
		var radial: Vector3 = planar_offset.normalized()
		var push_direction: Vector3 = (radial * 0.94 + forward * 0.06).normalized()
		var impulse: float = calculate_body_check_impulse(_racer.animal_id, target.animal_id) * power_multiplier
		strongest_impulse = maxf(strongest_impulse, impulse)
		target.apply_knockback(push_direction, impulse)
		var target_retention: float = 0.0
		if opening:
			target_retention = clampf(0.80 - maxf(0.0, impulse - 8.0) * 0.025, 0.52, 0.78)
		else:
			target_retention = clampf(0.88 - maxf(0.0, impulse - 5.0) * 0.021, 0.66, 0.86)
		target.current_speed *= target_retention
		var target_visual: WildDashCharacterVisual = target.get_visual()
		if target_visual != null:
			target_visual.play_action(&"Hit", 0.42 if opening else 0.32)
		hit_count += 1

	if hit_count <= 0:
		return

	_racer.current_speed *= ATTACKER_SPEED_RETENTION
	if opening:
		_racer.current_speed = maxf(_racer.current_speed, _racer.max_speed * ELEPHANT_OPENING_SPEED_ASSIST_RATIO)
	_body_check_cooldown = ELEPHANT_OPENING_COOLDOWN if opening else ELEPHANT_TRUNK_COOLDOWN
	_body_check_feedback_remaining = BODY_CHECK_FEEDBACK_SECONDS
	_body_check_feedback_text = "TRUNK SWEEP x%d · POWER %.1f" % [hit_count, strongest_impulse]
	AudioManager.play_sfx_id("hit", 1.0)
	var attacker_visual: WildDashCharacterVisual = _racer.get_visual()
	if attacker_visual != null:
		attacker_visual.play_action(&"Skill", 0.42 if opening else 0.32)
	print("RC9 ELEPHANT TRUNK SWEEP hits=%d opening=%s power=%.2f range=%.2f cooldown=%.2f" % [
		hit_count,
		str(opening),
		strongest_impulse,
		ELEPHANT_OPENING_TRUNK_RANGE if opening else ELEPHANT_TRUNK_RANGE,
		_body_check_cooldown,
	])

func _try_body_check() -> void:
	var target: WildDashCharacterController = _find_body_check_target()
	if target == null:
		_body_check_feedback_text = "BODY CHECK · NO TARGET"
		_body_check_feedback_remaining = 0.45
		return
	var offset: Vector3 = target.global_position - _racer.global_position
	var planar_offset: Vector3 = Vector3(offset.x, 0.0, offset.z)
	if planar_offset.length_squared() <= 0.001:
		return
	var attacker_right: Vector3 = _racer.global_transform.basis.x.normalized()
	var side_amount: float = planar_offset.dot(attacker_right)
	var side_sign: float = signf(side_amount)
	if absf(side_amount) < 0.18:
		var steer: float = InputManager.get_steer_axis()
		side_sign = -1.0 if steer < -0.05 else 1.0
	var lateral_push: Vector3 = attacker_right * side_sign
	var contact_direction: Vector3 = planar_offset.normalized()
	var push_direction: Vector3 = (lateral_push * 0.78 + contact_direction * 0.22).normalized()
	var impulse: float = calculate_body_check_impulse(_racer.animal_id, target.animal_id)
	target.apply_knockback(push_direction, impulse)
	var target_retention: float = clampf(0.94 - maxf(0.0, impulse - 3.0) * 0.018, 0.80, 0.94)
	target.current_speed *= target_retention
	_racer.current_speed *= ATTACKER_SPEED_RETENTION
	_body_check_cooldown = BODY_CHECK_COOLDOWN
	_body_check_feedback_remaining = BODY_CHECK_FEEDBACK_SECONDS
	_body_check_feedback_text = "HIT %s · POWER %.1f" % [target.get_display_name().to_upper(), impulse]
	AudioManager.play_sfx_id("hit", 0.90)
	var attacker_visual: WildDashCharacterVisual = _racer.get_visual()
	if attacker_visual != null:
		attacker_visual.play_action(&"Skill", 0.24)
	var target_visual: WildDashCharacterVisual = target.get_visual()
	if target_visual != null:
		target_visual.play_action(&"Hit", 0.28)
	print("RC9 BODY CHECK HIT attacker=%s animal=%s target=%s target_animal=%s impulse=%.2f retention=%.2f cooldown=%.2f" % [
		_racer.name,
		String(_racer.animal_id),
		target.name,
		String(target.animal_id),
		impulse,
		target_retention,
		_body_check_cooldown,
	])

func _find_elephant_trunk_targets(opening: bool) -> Array[WildDashCharacterController]:
	var targets: Array[WildDashCharacterController] = []
	if _racer == null:
		return targets
	var max_targets: int = ELEPHANT_OPENING_TRUNK_MAX_TARGETS if opening else ELEPHANT_TRUNK_MAX_TARGETS
	var range_limit: float = ELEPHANT_OPENING_TRUNK_RANGE if opening else ELEPHANT_TRUNK_RANGE
	var dot_limit: float = ELEPHANT_OPENING_TRUNK_FORWARD_DOT if opening else ELEPHANT_TRUNK_FORWARD_DOT
	var forward: Vector3 = -_racer.global_transform.basis.z.normalized()
	while targets.size() < max_targets:
		var best: WildDashCharacterController = null
		var best_score: float = INF
		for candidate: Node3D in RaceManager.racers:
			if candidate == _racer or not candidate is WildDashCharacterController:
				continue
			var controller: WildDashCharacterController = candidate as WildDashCharacterController
			if controller.finished or targets.has(controller):
				continue
			var raw_offset: Vector3 = controller.global_position - _racer.global_position
			if absf(raw_offset.y) > BODY_CHECK_MAX_VERTICAL_DELTA:
				continue
			var planar_offset: Vector3 = Vector3(raw_offset.x, 0.0, raw_offset.z)
			var distance: float = planar_offset.length()
			if distance <= 0.01 or distance > range_limit:
				continue
			var alignment: float = forward.dot(planar_offset / distance)
			if alignment < dot_limit:
				continue
			var score: float = distance - maxf(0.0, alignment) * 0.55
			if score < best_score:
				best_score = score
				best = controller
		if best == null:
			break
		targets.append(best)
	return targets

func _find_body_check_target() -> WildDashCharacterController:
	if _racer == null:
		return null
	var best: WildDashCharacterController = null
	var best_score: float = INF
	var forward: Vector3 = -_racer.global_transform.basis.z.normalized()
	for candidate: Node3D in RaceManager.racers:
		if candidate == _racer or not candidate is WildDashCharacterController:
			continue
		var controller: WildDashCharacterController = candidate as WildDashCharacterController
		if controller.finished:
			continue
		var raw_offset: Vector3 = controller.global_position - _racer.global_position
		if absf(raw_offset.y) > BODY_CHECK_MAX_VERTICAL_DELTA:
			continue
		var offset: Vector3 = Vector3(raw_offset.x, 0.0, raw_offset.z)
		var distance: float = offset.length()
		if distance <= 0.01 or distance > BODY_CHECK_RANGE:
			continue
		var alignment: float = forward.dot(offset / distance)
		if alignment < BODY_CHECK_FORWARD_DOT:
			continue
		var score: float = distance - maxf(0.0, alignment) * 0.35
		if score < best_score:
			best_score = score
			best = controller
	return best

func _is_elephant_opening() -> bool:
	return _racer != null and _racer.animal_id == &"elephant" and _race_elapsed <= ELEPHANT_OPENING_SECONDS

func _resolve_player() -> void:
	if _racer != null and is_instance_valid(_racer):
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	_racer = parent.get_node_or_null("Player") as WildDashCharacterController
	if _racer != null:
		_boost_energy = BOOST_ENERGY_MAX
		_boost_remaining = 0.0
		_boost_hold_locked = false
		_race_elapsed = 0.0
