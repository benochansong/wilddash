class_name WildDashBearCombatV2Controller
extends Node

## Bear race-combat identity for Race Combat Core V2.
## Bear is slower than speed racers, so a successful F attack must create a real
## passing opportunity instead of only a cosmetic bump.
##
## Tap  F      : SHOULDER BASH — frequent single-target heavy hit.
## Hold F      : BEAR SLAM — slower, much stronger hit with launch/ring-out threat.
## A/D + F     : biases target acquisition and knockback to that side.
## Out of range: a short Bear Lunge can close a small gap before the hit.
## Successful hits grant FURY MOMENTUM so Bear can re-enter the racing pack.

const BEAR_IMPACT_PER_ATTACK_POINT: float = 2.20
const BEAR_DIRECTIONAL_POWER_MULTIPLIER: float = 1.08
const BEAR_TAP_LAUNCH_MULTIPLIER: float = 0.58
const BEAR_HOLD_LAUNCH_MULTIPLIER: float = 1.05
const BEAR_MAX_VERTICAL_DELTA: float = 2.10
const BEAR_LUNGE_BONUS_RANGE: float = 3.00
const BEAR_LUNGE_DURATION: float = 0.48
const BEAR_LUNGE_PENDING_DELAY: float = 0.14
const BEAR_LUNGE_SPEED_RATIO: float = 1.18
const BEAR_LUNGE_ACCEL_MULTIPLIER: float = 3.60
const FURY_MOMENTUM_DURATION: float = 1.25
const FURY_MOMENTUM_SPEED_RATIO: float = 1.17
const FURY_MOMENTUM_ACCEL_MULTIPLIER: float = 2.15
const TAP_RETENTION_MIN: float = 0.46
const TAP_RETENTION_MAX: float = 0.72
const HOLD_RETENTION_MIN: float = 0.28
const HOLD_RETENTION_MAX: float = 0.56

var _racer: WildDashCharacterController
var _combat_core: WildDashRaceCombatCoreV2
var _cooldown_remaining: float = 0.0
var _lunge_remaining: float = 0.0
var _pending_delay: float = -1.0
var _pending_command: Dictionary = {}
var _fury_remaining: float = 0.0
var _feedback_text: String = ""
var _feedback_remaining: float = 0.0

func _ready() -> void:
	process_priority = 85
	call_deferred("_connect_combat_core")

func _exit_tree() -> void:
	if _combat_core != null and is_instance_valid(_combat_core):
		if _combat_core.combat_command_ready.is_connected(_on_combat_command_ready):
			_combat_core.combat_command_ready.disconnect(_on_combat_command_ready)

func _physics_process(delta: float) -> void:
	_resolve_player()
	if _racer == null:
		return
	if not RaceManager.active or _racer.finished:
		_reset_runtime()
		return

	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	_feedback_remaining = maxf(0.0, _feedback_remaining - delta)
	if _feedback_remaining <= 0.0:
		_feedback_text = ""
	_update_lunge(delta)
	_update_pending_attack(delta)
	_update_fury_momentum(delta)

func get_action_name() -> String:
	return "BEAR BASH / SLAM"

func get_cooldown_remaining() -> float:
	return _cooldown_remaining

func get_status_text() -> String:
	if not _feedback_text.is_empty() and _feedback_remaining > 0.0:
		return _feedback_text
	if _cooldown_remaining > 0.01:
		return "COOLDOWN %.1fs" % _cooldown_remaining
	return "TAP BASH · HOLD SLAM · F / Y"

func _connect_combat_core() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	_combat_core = parent.get_node_or_null("RaceCombatCoreV2") as WildDashRaceCombatCoreV2
	if _combat_core == null:
		push_warning("BearCombatV2Controller could not find RaceCombatCoreV2")
		return
	if not _combat_core.combat_command_ready.is_connected(_on_combat_command_ready):
		_combat_core.combat_command_ready.connect(_on_combat_command_ready)

func _on_combat_command_ready(racer: WildDashCharacterController, command: Dictionary) -> void:
	_resolve_player()
	if _racer == null or racer != _racer or _racer.animal_id != &"bear":
		return
	if _cooldown_remaining > 0.0:
		_feedback_text = "BEAR ATTACK · COOLDOWN %.1fs" % _cooldown_remaining
		_feedback_remaining = 0.45
		return

	var range_limit: float = float(command.get("range", WildDashRaceCombatProfile.get_range(&"bear")))
	var direction: int = int(command.get("direction", 0))
	var target: WildDashCharacterController = _find_target(range_limit, direction)
	if target != null:
		_apply_bear_attack(target, command, false)
		return

	var lunge_target: WildDashCharacterController = _find_target(range_limit + BEAR_LUNGE_BONUS_RANGE, direction)
	if lunge_target != null:
		_start_lunge(command)
		_feedback_text = "BEAR LUNGE"
		_feedback_remaining = 0.50
		print("RC9 BEAR LUNGE acquire=%.2fm kind=%s direction=%s" % [
			_racer.global_position.distance_to(lunge_target.global_position),
			String(command.get("kind", &"tap")),
			String(command.get("direction_name", &"neutral")),
		])
		return

	_feedback_text = "BEAR ATTACK · NO TARGET"
	_feedback_remaining = 0.45

func _start_lunge(command: Dictionary) -> void:
	_lunge_remaining = BEAR_LUNGE_DURATION
	_pending_delay = BEAR_LUNGE_PENDING_DELAY
	_pending_command = command.duplicate(true)
	_cooldown_remaining = maxf(_cooldown_remaining, float(command.get("cooldown", 1.75)) * 0.85)
	_racer.current_speed = maxf(_racer.current_speed, _racer.max_speed * 0.98)

func _update_lunge(delta: float) -> void:
	if _lunge_remaining <= 0.0 or _racer == null:
		return
	_lunge_remaining = maxf(0.0, _lunge_remaining - delta)
	var target_speed: float = _racer.max_speed * BEAR_LUNGE_SPEED_RATIO
	var accel: float = _racer.acceleration * _racer.get_active_acceleration_scale() * BEAR_LUNGE_ACCEL_MULTIPLIER
	_racer.current_speed = move_toward(_racer.current_speed, target_speed, accel * delta)

func _update_pending_attack(delta: float) -> void:
	if _pending_delay < 0.0 or _pending_command.is_empty():
		return
	_pending_delay -= delta
	if _pending_delay > 0.0:
		return
	_pending_delay = -1.0
	var command: Dictionary = _pending_command.duplicate(true)
	_pending_command.clear()
	var direction: int = int(command.get("direction", 0))
	var range_limit: float = float(command.get("range", 5.2)) + 0.75
	var target: WildDashCharacterController = _find_target(range_limit, direction)
	if target != null:
		_apply_bear_attack(target, command, true)
	else:
		_feedback_text = "BEAR LUNGE · MISSED"
		_feedback_remaining = 0.45

func _apply_bear_attack(target: WildDashCharacterController, command: Dictionary, from_lunge: bool) -> void:
	if target == null or _racer == null:
		return
	var kind: StringName = StringName(command.get("kind", &"tap"))
	var direction: int = int(command.get("direction", 0))
	var attack_power: float = float(command.get("attack_power", 9.5))
	var raw_power: float = attack_power * BEAR_IMPACT_PER_ATTACK_POINT
	if direction != 0:
		raw_power *= BEAR_DIRECTIONAL_POWER_MULTIPLIER
	if from_lunge:
		raw_power *= 1.06

	var effective_impulse: float = WildDashRaceCombatBalance.get_ring_out_impulse(raw_power, target.animal_id)
	var base_launch: float = WildDashRaceCombatBalance.get_launch_strength(raw_power, target.animal_id)
	var launch_multiplier: float = BEAR_HOLD_LAUNCH_MULTIPLIER if kind == &"hold" else BEAR_TAP_LAUNCH_MULTIPLIER
	var launch_strength: float = base_launch * launch_multiplier

	var offset: Vector3 = target.global_position - _racer.global_position
	var planar: Vector3 = Vector3(offset.x, 0.0, offset.z)
	if planar.length_squared() <= 0.001:
		return
	var radial: Vector3 = planar.normalized()
	var right: Vector3 = _racer.global_transform.basis.x.normalized()
	var side_sign: float = float(direction)
	if is_zero_approx(side_sign):
		side_sign = signf(planar.dot(right))
	if is_zero_approx(side_sign):
		side_sign = 1.0
	var lateral: Vector3 = right * side_sign
	var lateral_weight: float = 0.82 if kind == &"hold" else 0.70
	var push_direction: Vector3 = (lateral * lateral_weight + radial * (1.0 - lateral_weight)).normalized()

	target.apply_knockback(push_direction, effective_impulse)
	if launch_strength > 0.0:
		target.velocity.y = maxf(target.velocity.y, launch_strength)

	var retention: float
	if kind == &"hold":
		retention = clampf(0.60 - maxf(0.0, effective_impulse - 12.0) * 0.012, HOLD_RETENTION_MIN, HOLD_RETENTION_MAX)
	else:
		retention = clampf(0.74 - maxf(0.0, effective_impulse - 10.0) * 0.010, TAP_RETENTION_MIN, TAP_RETENTION_MAX)
	target.current_speed *= retention

	var visual: WildDashCharacterVisual = target.get_visual()
	if visual != null:
		visual.play_action(&"Hit", 0.52 if kind == &"hold" else 0.36)
	var bear_visual: WildDashCharacterVisual = _racer.get_visual()
	if bear_visual != null:
		bear_visual.play_action(&"Skill", 0.48 if kind == &"hold" else 0.30)
	AudioManager.play_sfx_id("hit", 1.0)

	_cooldown_remaining = float(command.get("cooldown", WildDashRaceCombatProfile.get_cooldown(&"bear")))
	_fury_remaining = FURY_MOMENTUM_DURATION
	_racer.current_speed = maxf(_racer.current_speed, _racer.max_speed * 1.04)
	_feedback_text = "%s · HIT %s · POWER %.1f" % [
		"BEAR SLAM" if kind == &"hold" else "SHOULDER BASH",
		target.get_display_name().to_upper(),
		effective_impulse,
	]
	_feedback_remaining = 0.90
	print("RC9 BEAR COMBAT kind=%s target=%s defense=%.1f raw=%.2f effective=%.2f launch=%.2f retention=%.2f lunge=%s fury=%.2fs cooldown=%.2f" % [
		String(kind),
		String(target.animal_id),
		WildDashRaceCombatBalance.get_defense_rating(target.animal_id),
		raw_power,
		effective_impulse,
		launch_strength,
		retention,
		str(from_lunge),
		FURY_MOMENTUM_DURATION,
		_cooldown_remaining,
	])

func _update_fury_momentum(delta: float) -> void:
	if _fury_remaining <= 0.0 or _racer == null:
		return
	_fury_remaining = maxf(0.0, _fury_remaining - delta)
	var target_speed: float = _racer.max_speed * FURY_MOMENTUM_SPEED_RATIO
	var accel: float = _racer.acceleration * _racer.get_active_acceleration_scale() * FURY_MOMENTUM_ACCEL_MULTIPLIER
	_racer.current_speed = move_toward(_racer.current_speed, target_speed, accel * delta)

func _find_target(range_limit: float, direction: int) -> WildDashCharacterController:
	if _racer == null:
		return null
	var best: WildDashCharacterController = null
	var best_score: float = INF
	var forward: Vector3 = -_racer.global_transform.basis.z.normalized()
	var right: Vector3 = _racer.global_transform.basis.x.normalized()
	for candidate: Node3D in RaceManager.racers:
		if candidate == _racer or not candidate is WildDashCharacterController:
			continue
		var controller: WildDashCharacterController = candidate as WildDashCharacterController
		if controller.finished:
			continue
		var raw_offset: Vector3 = controller.global_position - _racer.global_position
		if absf(raw_offset.y) > BEAR_MAX_VERTICAL_DELTA:
			continue
		var planar: Vector3 = Vector3(raw_offset.x, 0.0, raw_offset.z)
		var distance: float = planar.length()
		if distance <= 0.01 or distance > range_limit:
			continue
		var normalized: Vector3 = planar / distance
		var alignment: float = forward.dot(normalized)
		if alignment < (-0.55 if direction != 0 else -0.18):
			continue
		var side_amount: float = right.dot(normalized)
		if direction < 0 and side_amount > 0.32:
			continue
		if direction > 0 and side_amount < -0.32:
			continue
		var side_bonus: float = absf(side_amount) * 0.30 if direction != 0 else 0.0
		var score: float = distance - maxf(0.0, alignment) * 0.65 - side_bonus
		if score < best_score:
			best_score = score
			best = controller
	return best

func _reset_runtime() -> void:
	_cooldown_remaining = 0.0
	_lunge_remaining = 0.0
	_pending_delay = -1.0
	_pending_command.clear()
	_fury_remaining = 0.0
	_feedback_text = ""
	_feedback_remaining = 0.0

func _resolve_player() -> void:
	if _racer != null and is_instance_valid(_racer):
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	_racer = parent.get_node_or_null("Player") as WildDashCharacterController
