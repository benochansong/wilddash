class_name WildDashRacingActionController
extends Node

## RC9 arcade race actions layered on top of CharacterController.
## W/Up is an energy-limited tactical boost, not a permanent throttle advantage.
## F / Gamepad Y is a weight-aware shoulder check with readable lateral knockback.

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
const ATTACKER_SPEED_RETENTION: float = 0.97

# Elephant identity: it is deliberately slow, so its opening strength must be
# available before the light racers can simply escape the contact game.
const ELEPHANT_OPENING_SECONDS: float = 6.0
const ELEPHANT_OPENING_RANGE: float = 5.20
const ELEPHANT_OPENING_FORWARD_DOT: float = -0.55
const ELEPHANT_OPENING_POWER_MULTIPLIER: float = 1.35
const ELEPHANT_OPENING_COOLDOWN: float = 1.55
const ELEPHANT_OPENING_SPEED_ASSIST_RATIO: float = 0.97

var _racer: WildDashCharacterController
var _body_check_cooldown: float = 0.0
var _body_check_feedback_remaining: float = 0.0
var _body_check_feedback_text: String = ""
var _boost_energy: float = BOOST_ENERGY_MAX
var _boost_remaining: float = 0.0
var _boost_reported: bool = false
var _race_elapsed: float = 0.0

func _ready() -> void:
	# CharacterController moves first at default priority. This controller then
	# clamps normal pace or applies the short boost. RacingFeel (priority 100)
	# samples the resulting speed for camera feedback.
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
		_try_body_check()

func get_body_check_cooldown_remaining() -> float:
	return _body_check_cooldown

func get_body_check_status_text() -> String:
	if not _body_check_feedback_text.is_empty() and _body_check_feedback_remaining > 0.0:
		return _body_check_feedback_text
	if _body_check_cooldown > 0.01:
		return "COOLDOWN %.1fs" % _body_check_cooldown
	if _is_elephant_opening():
		var opening_left: float = maxf(0.0, ELEPHANT_OPENING_SECONDS - _race_elapsed)
		if _find_body_check_target() != null:
			return "OPENING STAMPEDE %.1fs · TARGET · F / Y" % opening_left
		return "OPENING STAMPEDE %.1fs · F / Y" % opening_left
	if _find_body_check_target() != null:
		return "TARGET IN RANGE · F / Y"
	return "READY · F / Y"

func get_current_body_check_power() -> float:
	if _racer == null:
		return 0.0
	var power: float = get_body_check_power(_racer.animal_id)
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
		return "READY · PRESS W / ↑"
	return "CHARGING %d%%" % int(round(get_boost_energy_ratio() * 100.0))

static func get_overdrive_target(max_speed: float, throttle: float = 1.0) -> float:
	var amount: float = clampf(throttle, 0.0, 1.0)
	return max_speed * lerpf(1.0, OVERDRIVE_SPEED_MULTIPLIER, amount)

static func get_normal_race_target(max_speed: float, cruise_speed: float) -> float:
	return maxf(cruise_speed, max_speed * BASE_RACE_SPEED_RATIO)

## Attacker power: heavy racers own close-contact fights; light racers can still
## disrupt an opponent but cannot launch a heavy body with the same authority.
static func get_body_check_power(animal_id: StringName) -> float:
	match animal_id:
		&"elephant": return 8.40
		&"bear": return 7.50
		&"boar": return 7.05
		&"panda": return 6.55
		&"wolf": return 5.80
		&"dog": return 5.45
		&"deer": return 5.10
		&"rabbit": return 4.70
		&"monkey": return 4.65
		&"fox": return 4.55
		&"cat": return 4.35
		&"raccoon": return 4.15
		_: return 4.70

## Multiplier applied to incoming body-check power. Values below 1 are heavy
## resistance; values above 1 make light racers easier to shoulder aside.
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

# Compatibility helper used by early RC9 network code.
static func get_body_check_strength(animal_id: StringName) -> float:
	return get_body_check_power(animal_id)

func _update_boost(delta: float) -> void:
	var throttle: float = InputManager.get_throttle_axis()
	var boost_pressed: bool = InputManager.consume_boost_press()

	if _boost_remaining > 0.0:
		_boost_remaining = maxf(0.0, _boost_remaining - delta)
		var boost_target: float = get_overdrive_target(_racer.max_speed)
		var boost_accel: float = _racer.acceleration * _racer.get_active_acceleration_scale() * OVERDRIVE_ACCELERATION_MULTIPLIER
		_racer.current_speed = move_toward(_racer.current_speed, boost_target, boost_accel * delta)
		if _boost_remaining <= 0.0:
			_boost_reported = false
		return

	_boost_energy = minf(BOOST_ENERGY_MAX, _boost_energy + BOOST_RECHARGE_PER_SECOND * delta)

	# Normal pace is automatic and the same whether W is held or released while
	# the meter is unavailable. Character skills remain allowed to exceed it.
	var normal_target: float = get_normal_race_target(_racer.max_speed, _racer.cruise_speed)
	if throttle >= -0.05 and _racer.get_active_speed_scale() <= 1.02:
		if _racer.current_speed > normal_target:
			_racer.current_speed = normal_target
		else:
			var recovery_accel: float = _racer.acceleration * _racer.get_active_acceleration_scale() * 1.20
			_racer.current_speed = move_toward(_racer.current_speed, normal_target, recovery_accel * delta)

	# Boost activation is now a dedicated press edge. A full meter + a fresh W/Up
	# press always fires; holding the key cannot auto-fire a later recharge.
	if boost_pressed and _boost_energy >= BOOST_ENERGY_COST - BOOST_READY_EPSILON:
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
	if refill:
		_boost_energy = BOOST_ENERGY_MAX

func _try_body_check() -> void:
	if _body_check_cooldown > 0.0:
		return
	var opening_stampede: bool = _is_elephant_opening()
	var target: WildDashCharacterController = _find_body_check_target()
	if target == null:
		_body_check_feedback_text = "OPENING STAMPEDE · NO TARGET" if opening_stampede else "BODY CHECK · NO TARGET"
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
	if opening_stampede:
		impulse *= ELEPHANT_OPENING_POWER_MULTIPLIER
	target.apply_knockback(push_direction, impulse)
	var target_retention: float = clampf(0.94 - maxf(0.0, impulse - 3.0) * 0.018, 0.80, 0.94)
	target.current_speed *= target_retention
	_racer.current_speed *= ATTACKER_SPEED_RETENTION
	if opening_stampede:
		# A successful opening shoulder keeps the elephant inside the pack without
		# permanently raising its top speed.
		_racer.current_speed = maxf(_racer.current_speed, _racer.max_speed * ELEPHANT_OPENING_SPEED_ASSIST_RATIO)
	_body_check_cooldown = ELEPHANT_OPENING_COOLDOWN if opening_stampede else BODY_CHECK_COOLDOWN
	_body_check_feedback_remaining = BODY_CHECK_FEEDBACK_SECONDS
	_body_check_feedback_text = "%s %s · POWER %.1f" % [
		"OPENING HIT" if opening_stampede else "HIT",
		target.get_display_name().to_upper(),
		impulse,
	]

	AudioManager.play_sfx_id("hit", 0.96 if opening_stampede else 0.90)
	var attacker_visual: WildDashCharacterVisual = _racer.get_visual()
	if attacker_visual != null:
		attacker_visual.play_action(&"Skill", 0.28 if opening_stampede else 0.24)
	var target_visual: WildDashCharacterVisual = target.get_visual()
	if target_visual != null:
		target_visual.play_action(&"Hit", 0.32 if opening_stampede else 0.28)
	print("RC9 BODY CHECK HIT attacker=%s animal=%s target=%s target_animal=%s impulse=%.2f opening=%s retention=%.2f cooldown=%.2f" % [
		_racer.name,
		String(_racer.animal_id),
		target.name,
		String(target.animal_id),
		impulse,
		str(opening_stampede),
		target_retention,
		_body_check_cooldown,
	])

func _find_body_check_target() -> WildDashCharacterController:
	if _racer == null:
		return null
	var best: WildDashCharacterController = null
	var best_score: float = INF
	var forward: Vector3 = -_racer.global_transform.basis.z.normalized()
	var range_limit: float = ELEPHANT_OPENING_RANGE if _is_elephant_opening() else BODY_CHECK_RANGE
	var forward_dot_limit: float = ELEPHANT_OPENING_FORWARD_DOT if _is_elephant_opening() else BODY_CHECK_FORWARD_DOT
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
		if distance <= 0.01 or distance > range_limit:
			continue
		var alignment: float = forward.dot(offset / distance)
		if alignment < forward_dot_limit:
			continue
		# Prefer closer targets, with a small bias toward racers in front so a
		# crowded side-by-side pack feels predictable rather than random.
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
		_race_elapsed = 0.0