class_name WildDashRacingActionController
extends Node

## RC9 arcade race actions layered on top of the CharacterController.
## W/Up is now an energy-limited boost burst instead of an always-on speed
## advantage. F / Gamepad Y performs a short-range body check.

const BASE_RACE_SPEED_RATIO: float = 0.90
const OVERDRIVE_SPEED_MULTIPLIER: float = 1.12
const OVERDRIVE_ACCELERATION_MULTIPLIER: float = 2.05
const BOOST_ENERGY_MAX: float = 100.0
const BOOST_ENERGY_COST: float = 100.0
const BOOST_RECHARGE_PER_SECOND: float = 22.0
const BOOST_DURATION: float = 1.10
const BOOST_READY_EPSILON: float = 0.05

const BODY_CHECK_COOLDOWN: float = 2.45
const BODY_CHECK_RANGE: float = 2.65
const BODY_CHECK_FORWARD_DOT: float = -0.08
const ATTACKER_SPEED_RETENTION: float = 0.98
const TARGET_SPEED_RETENTION: float = 0.93

const META_BOOST_ACTIVE: StringName = &"wilddash_boost_active"
const META_BOOST_SPEED: StringName = &"wilddash_boost_speed_multiplier"
const META_BOOST_ACCEL: StringName = &"wilddash_boost_acceleration_multiplier"

var _racer: WildDashCharacterController
var _body_check_cooldown: float = 0.0
var _boost_energy: float = BOOST_ENERGY_MAX
var _boost_remaining: float = 0.0
var _boost_rearmed: bool = true
var _boost_reported: bool = false

func _ready() -> void:
	# Lower priorities run first. Publish boost state before CharacterController
	# performs its movement pass, then RacingFeelController (100) samples it.
	process_priority = -20

func _exit_tree() -> void:
	_clear_racer_boost_meta()

func _physics_process(delta: float) -> void:
	_resolve_player()
	_body_check_cooldown = maxf(0.0, _body_check_cooldown - delta)
	if _racer == null:
		return
	if not RaceManager.active or _racer.finished:
		_reset_boost_runtime(false)
		return

	_update_boost(delta)
	if InputManager.consume_race_bump():
		_try_body_check()

func get_body_check_cooldown_remaining() -> float:
	return _body_check_cooldown

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

func _update_boost(delta: float) -> void:
	var throttle: float = InputManager.get_throttle_axis()
	if throttle <= 0.05:
		_boost_rearmed = true

	if _boost_remaining > 0.0:
		_boost_remaining = maxf(0.0, _boost_remaining - delta)
		_publish_racer_boost_meta(true)
		if _boost_remaining <= 0.0:
			_publish_racer_boost_meta(false)
			_boost_reported = false
		return

	_publish_racer_boost_meta(false)
	_boost_energy = minf(BOOST_ENERGY_MAX, _boost_energy + BOOST_RECHARGE_PER_SECOND * delta)

	# A held key never auto-fires when the meter eventually fills. Every boost
	# needs a deliberate press after release, which prevents permanent W holding.
	if throttle > 0.05 and _boost_rearmed:
		_boost_rearmed = false
		if _boost_energy >= BOOST_ENERGY_COST - BOOST_READY_EPSILON:
			_activate_boost()

func _activate_boost() -> void:
	_boost_energy = maxf(0.0, _boost_energy - BOOST_ENERGY_COST)
	_boost_remaining = BOOST_DURATION
	_publish_racer_boost_meta(true)
	if not _boost_reported:
		_boost_reported = true
		print("RC9 BOOST BURST racer=%s duration=%.2f energy=%.0f recharge=%.1fs target=%.2f" % [
			_racer.name,
			BOOST_DURATION,
			_boost_energy,
			BOOST_ENERGY_MAX / BOOST_RECHARGE_PER_SECOND,
			get_overdrive_target(_racer.max_speed),
		])

func _publish_racer_boost_meta(active: bool) -> void:
	if _racer == null:
		return
	_racer.set_meta(META_BOOST_ACTIVE, active)
	_racer.set_meta(META_BOOST_SPEED, OVERDRIVE_SPEED_MULTIPLIER)
	_racer.set_meta(META_BOOST_ACCEL, OVERDRIVE_ACCELERATION_MULTIPLIER)

func _clear_racer_boost_meta() -> void:
	if _racer == null or not is_instance_valid(_racer):
		return
	_racer.remove_meta(META_BOOST_ACTIVE)
	_racer.remove_meta(META_BOOST_SPEED)
	_racer.remove_meta(META_BOOST_ACCEL)

func _reset_boost_runtime(refill: bool) -> void:
	_boost_remaining = 0.0
	_boost_rearmed = true
	_boost_reported = false
	if refill:
		_boost_energy = BOOST_ENERGY_MAX
	_publish_racer_boost_meta(false)

func _try_body_check() -> void:
	if _body_check_cooldown > 0.0:
		return
	var target: WildDashCharacterController = _find_body_check_target()
	if target == null:
		return
	var offset: Vector3 = target.global_position - _racer.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return
	var strength: float = get_body_check_strength(_racer.animal_id)
	var direction: Vector3 = offset.normalized()
	var forward: Vector3 = -_racer.global_transform.basis.z.normalized()
	var push_direction: Vector3 = (direction * 0.78 + forward * 0.22).normalized()
	target.apply_knockback(push_direction, strength)
	target.current_speed *= TARGET_SPEED_RETENTION
	_racer.current_speed *= ATTACKER_SPEED_RETENTION
	_body_check_cooldown = BODY_CHECK_COOLDOWN
	AudioManager.play_sfx_id("hit", 0.82)
	var attacker_visual: WildDashCharacterVisual = _racer.get_visual()
	if attacker_visual != null:
		attacker_visual.play_action(&"Skill", 0.22)
	var target_visual: WildDashCharacterVisual = target.get_visual()
	if target_visual != null:
		target_visual.play_action(&"Hit", 0.20)
	print("RC9 BODY CHECK attacker=%s animal=%s target=%s strength=%.2f cooldown=%.2f" % [
		_racer.name, String(_racer.animal_id), target.name, strength, BODY_CHECK_COOLDOWN,
	])

func _find_body_check_target() -> WildDashCharacterController:
	var best: WildDashCharacterController = null
	var best_distance: float = INF
	var forward: Vector3 = -_racer.global_transform.basis.z.normalized()
	for candidate: Node3D in RaceManager.racers:
		if candidate == _racer or not candidate is WildDashCharacterController:
			continue
		var controller: WildDashCharacterController = candidate as WildDashCharacterController
		if controller.finished:
			continue
		var offset: Vector3 = controller.global_position - _racer.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= 0.01 or distance > BODY_CHECK_RANGE:
			continue
		var alignment: float = forward.dot(offset / distance)
		if alignment < BODY_CHECK_FORWARD_DOT:
			continue
		if distance < best_distance:
			best_distance = distance
			best = controller
	return best

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
		_boost_rearmed = true
		_publish_racer_boost_meta(false)
