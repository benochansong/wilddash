class_name WildDashElephantTrunkLungeController
extends Node

## Mid-race Elephant identity pass.
## After the opening six seconds, F/Y becomes a 7.8m multi-target trunk sweep.
## If opponents are a little farther ahead, Elephant lunges forward before sweeping.
## Low-defense racers can be visibly launched while heavy racers remain difficult to move.

const OPENING_SECONDS: float = 6.0
const MIDRACE_SWEEP_RANGE: float = 7.80
const MIDRACE_LUNGE_ACQUIRE_RANGE: float = 10.50
const MIDRACE_MAX_TARGETS: int = 3
const MIDRACE_FORWARD_DOT: float = -0.42
const MIDRACE_MAX_VERTICAL_DELTA: float = 1.90
const MIDRACE_COOLDOWN: float = 2.15
const CLOSE_RANGE_THRESHOLD: float = 5.80
const CLOSE_SUPPLEMENTAL_POWER: float = 10.00
const FAR_SWEEP_POWER: float = 18.00
const TARGET_SPEED_RETENTION_MIN: float = 0.52
const TARGET_SPEED_RETENTION_MAX: float = 0.78
const LUNGE_DURATION: float = 0.48
const LUNGE_PENDING_SWEEP_DELAY: float = 0.14
const LUNGE_SPEED_RATIO: float = 1.16
const LUNGE_ACCELERATION_MULTIPLIER: float = 4.00
const HIT_MOMENTUM_SPEED_RATIO: float = 1.10

var _racer: WildDashCharacterController
var _race_elapsed: float = 0.0
var _cooldown_remaining: float = 0.0
var _lunge_remaining: float = 0.0
var _pending_sweep_delay: float = -1.0
var _f_was_down: bool = false

func _ready() -> void:
	process_priority = 90

func _physics_process(delta: float) -> void:
	_resolve_player()
	if _racer == null:
		return
	if not RaceManager.active or _racer.finished:
		_reset_runtime()
		return
	_race_elapsed += delta
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	_update_lunge(delta)
	_update_pending_sweep(delta)
	var pressed: bool = _consume_local_bump_press()
	if not pressed or _race_elapsed <= OPENING_SECONDS or _cooldown_remaining > 0.0:
		return
	if _racer.animal_id != &"elephant":
		return

	var immediate_targets: Array[WildDashCharacterController] = _find_targets(MIDRACE_SWEEP_RANGE)
	if not immediate_targets.is_empty():
		_start_lunge()
		_apply_midrace_sweep(immediate_targets, false)
		return

	var acquire_targets: Array[WildDashCharacterController] = _find_targets(MIDRACE_LUNGE_ACQUIRE_RANGE)
	if not acquire_targets.is_empty():
		_start_lunge()
		_pending_sweep_delay = LUNGE_PENDING_SWEEP_DELAY
		_cooldown_remaining = MIDRACE_COOLDOWN
		print("RC9 ELEPHANT TRUNK LUNGE acquire distance=%.2f pending=%.2fs" % [
			_racer.global_position.distance_to(acquire_targets[0].global_position),
			LUNGE_PENDING_SWEEP_DELAY,
		])

func _update_lunge(delta: float) -> void:
	if _lunge_remaining <= 0.0:
		return
	_lunge_remaining = maxf(0.0, _lunge_remaining - delta)
	var target_speed: float = _racer.max_speed * LUNGE_SPEED_RATIO
	var lunge_accel: float = _racer.acceleration * _racer.get_active_acceleration_scale() * LUNGE_ACCELERATION_MULTIPLIER
	_racer.current_speed = move_toward(_racer.current_speed, target_speed, lunge_accel * delta)

func _update_pending_sweep(delta: float) -> void:
	if _pending_sweep_delay < 0.0:
		return
	_pending_sweep_delay -= delta
	if _pending_sweep_delay > 0.0:
		return
	_pending_sweep_delay = -1.0
	var targets: Array[WildDashCharacterController] = _find_targets(MIDRACE_SWEEP_RANGE)
	if not targets.is_empty():
		_apply_midrace_sweep(targets, true)

func _start_lunge() -> void:
	_lunge_remaining = LUNGE_DURATION
	_racer.current_speed = maxf(_racer.current_speed, _racer.max_speed * 0.98)

func _apply_midrace_sweep(targets: Array[WildDashCharacterController], from_lunge: bool) -> void:
	if targets.is_empty():
		return
	var forward: Vector3 = -_racer.global_transform.basis.z.normalized()
	var right: Vector3 = _racer.global_transform.basis.x.normalized()
	var hits: int = 0
	var strongest_effective_impulse: float = 0.0

	for target: WildDashCharacterController in targets:
		if target == null:
			continue
		var raw_offset: Vector3 = target.global_position - _racer.global_position
		var planar_offset: Vector3 = Vector3(raw_offset.x, 0.0, raw_offset.z)
		var distance: float = planar_offset.length()
		if distance <= 0.01:
			continue

		var radial: Vector3 = planar_offset / distance
		var side_amount: float = planar_offset.dot(right)
		var side_sign: float = signf(side_amount)
		if absf(side_amount) < 0.20:
			side_sign = -1.0 if hits % 2 == 0 else 1.0
		var lateral: Vector3 = right * side_sign
		var push_direction: Vector3 = (lateral * 0.82 + radial * 0.15 + forward * 0.03).normalized()

		var raw_power: float = CLOSE_SUPPLEMENTAL_POWER if distance <= CLOSE_RANGE_THRESHOLD else FAR_SWEEP_POWER
		var effective_impulse: float = WildDashRaceCombatBalance.get_effective_impulse(raw_power, target.animal_id)
		var launch_strength: float = WildDashRaceCombatBalance.get_launch_strength(raw_power, target.animal_id)
		target.apply_knockback(push_direction, effective_impulse)
		if launch_strength > 0.0 and target.is_on_floor():
			target.velocity.y = maxf(target.velocity.y, launch_strength)

		var retention: float = clampf(
			0.88 - maxf(0.0, effective_impulse - 7.0) * 0.028,
			TARGET_SPEED_RETENTION_MIN,
			TARGET_SPEED_RETENTION_MAX
		)
		target.current_speed *= retention
		var visual: WildDashCharacterVisual = target.get_visual()
		if visual != null:
			visual.play_action(&"Hit", 0.42 if launch_strength > 0.0 else 0.34)

		strongest_effective_impulse = maxf(strongest_effective_impulse, effective_impulse)
		hits += 1
		print("RC9 ELEPHANT TRUNK TARGET animal=%s defense=%.1f effective=%.2f launch=%.2f retention=%.2f" % [
			String(target.animal_id),
			WildDashRaceCombatBalance.get_defense_rating(target.animal_id),
			effective_impulse,
			launch_strength,
			retention,
		])

	if hits <= 0:
		return

	_cooldown_remaining = MIDRACE_COOLDOWN
	_lunge_remaining = maxf(_lunge_remaining, LUNGE_DURATION)
	_racer.current_speed = maxf(_racer.current_speed, _racer.max_speed * HIT_MOMENTUM_SPEED_RATIO)
	AudioManager.play_sfx_id("hit", 1.0)
	var attacker_visual: WildDashCharacterVisual = _racer.get_visual()
	if attacker_visual != null:
		attacker_visual.play_action(&"Skill", 0.40)
	print("RC9 ELEPHANT MIDRACE TRUNK hits=%d range=%.1f effective_power=%.2f lunge=%s cooldown=%.2f momentum=%.2f" % [
		hits,
		MIDRACE_SWEEP_RANGE,
		strongest_effective_impulse,
		str(from_lunge),
		MIDRACE_COOLDOWN,
		_racer.current_speed,
	])

func _find_targets(range_limit: float) -> Array[WildDashCharacterController]:
	var targets: Array[WildDashCharacterController] = []
	if _racer == null:
		return targets
	var forward: Vector3 = -_racer.global_transform.basis.z.normalized()
	while targets.size() < MIDRACE_MAX_TARGETS:
		var best: WildDashCharacterController = null
		var best_score: float = INF
		for candidate: Node3D in RaceManager.racers:
			if candidate == _racer or not candidate is WildDashCharacterController:
				continue
			var controller: WildDashCharacterController = candidate as WildDashCharacterController
			if controller.finished or targets.has(controller):
				continue
			var raw_offset: Vector3 = controller.global_position - _racer.global_position
			if absf(raw_offset.y) > MIDRACE_MAX_VERTICAL_DELTA:
				continue
			var planar_offset: Vector3 = Vector3(raw_offset.x, 0.0, raw_offset.z)
			var distance: float = planar_offset.length()
			if distance <= 0.01 or distance > range_limit:
				continue
			var alignment: float = forward.dot(planar_offset / distance)
			if alignment < MIDRACE_FORWARD_DOT:
				continue
			var score: float = distance - maxf(0.0, alignment) * 0.72
			if score < best_score:
				best_score = score
				best = controller
		if best == null:
			break
		targets.append(best)
	return targets

func _consume_local_bump_press() -> bool:
	var action_edge: bool = Input.is_action_just_pressed(&"race_bump")
	var physical_down: bool = Input.is_physical_key_pressed(KEY_F)
	var physical_edge: bool = physical_down and not _f_was_down
	_f_was_down = physical_down
	return action_edge or physical_edge

func _reset_runtime() -> void:
	_race_elapsed = 0.0
	_cooldown_remaining = 0.0
	_lunge_remaining = 0.0
	_pending_sweep_delay = -1.0
	_f_was_down = Input.is_physical_key_pressed(KEY_F)

func _resolve_player() -> void:
	if _racer != null and is_instance_valid(_racer):
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	_racer = parent.get_node_or_null("Player") as WildDashCharacterController
