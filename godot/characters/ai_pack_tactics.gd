class_name WildDashAIPackTactics
extends Node

enum Personality {
	AGGRESSIVE,
	SAFE,
	SHORTCUT,
	ITEM_FIGHTER,
	BALANCED,
}

const NORMAL_THINK_INTERVAL := 0.16
const HARD_THINK_INTERVAL := 0.12
const DETECTION_FORWARD := 10.5
const DETECTION_REAR := 6.5
const DETECTION_SIDE := 3.6
const FRONT_CORRIDOR := 1.35
const MAX_LANE_SHIFT := 2.8
const HARD_MAX_LANE_SHIFT := 3.15
const PRODUCTION_PACE_SCALE := 1.35
const HARD_RISK_BONUS := 0.12
const HARD_OVERTAKE_BONUS := 0.10
const HARD_SHORTCUT_BONUS := 0.10
const HARD_SPEED_SCALE := 1.02

var _racer: WildDashCharacterController
var _driver: WildDashAIController
var _personality: Personality = Personality.BALANCED
var _base_lane := 0.0
var _base_speed := 0.0
var _risk := 0.5
var _overtake := 0.5
var _shortcut_preference := 0.5
var _think_elapsed := 0.0
var _think_interval := NORMAL_THINK_INTERVAL
var _lane_shift := 0.0
var _last_action := &"pace"
var _overtake_actions := 0
var _yield_actions := 0
var _line_change_actions := 0
var _traffic_holds := 0

func _ready() -> void:
	add_to_group("wilddash_ai_tactics")

func configure(
	racer: WildDashCharacterController,
	driver: WildDashAIController,
	personality: Personality,
	risk: float,
	overtake: float,
	shortcut_preference: float,
) -> void:
	_racer = racer
	_driver = driver
	_personality = personality
	_risk = clampf(risk, 0.0, 1.0)
	_overtake = clampf(overtake, 0.0, 1.0)
	_shortcut_preference = clampf(shortcut_preference, 0.0, 1.0)
	_base_lane = driver.preferred_lane
	_base_speed = driver.target_speed

	var production_pace := DisplayServer.get_name() != "headless" or OS.has_environment("WILDDASH_REALTIME_BALANCE") or OS.has_environment("WILDDASH_BALANCE_RUN")
	if production_pace:
		_base_speed *= PRODUCTION_PACE_SCALE
		_driver.target_speed = _base_speed

	if GameManager.difficulty == &"nightmare":
		_risk = clampf(_risk + HARD_RISK_BONUS, 0.0, 1.0)
		_overtake = clampf(_overtake + HARD_OVERTAKE_BONUS, 0.0, 1.0)
		_shortcut_preference = clampf(_shortcut_preference + HARD_SHORTCUT_BONUS, 0.0, 1.0)
		_think_interval = HARD_THINK_INTERVAL
		if production_pace:
			_base_speed *= HARD_SPEED_SCALE
			_driver.target_speed = _base_speed
		print("AI HARD PROFILE racer=%s risk=%.2f overtake=%.2f shortcut=%.2f think=%.2fs speed_scale=%.2f" % [
			racer.name, _risk, _overtake, _shortcut_preference, _think_interval,
			HARD_SPEED_SCALE if production_pace else 1.0,
		])
	_think_elapsed = float(racer.get_instance_id() % 13) * 0.009

func get_shortcut_preference() -> float:
	return _shortcut_preference

func get_risk() -> float:
	return _risk

func get_overtake_preference() -> float:
	return _overtake

func get_racer() -> WildDashCharacterController:
	return _racer

func get_personality_name() -> String:
	match _personality:
		Personality.AGGRESSIVE:
			return "Aggressive"
		Personality.SAFE:
			return "Safe"
		Personality.SHORTCUT:
			return "Shortcut"
		Personality.ITEM_FIGHTER:
			return "Item Fighter"
		_:
			return "Balanced"

func get_balance_telemetry() -> Dictionary:
	return {
		"personality": get_personality_name(),
		"last_action": String(_last_action),
		"overtake_actions": _overtake_actions,
		"yield_actions": _yield_actions,
		"line_change_actions": _line_change_actions,
		"traffic_holds": _traffic_holds,
	}

func _process(delta: float) -> void:
	if _racer == null or _driver == null or not is_instance_valid(_racer) or _racer.finished or not RaceManager.active:
		return
	_think_elapsed += delta
	if _think_elapsed < _think_interval:
		return
	_think_elapsed = 0.0
	_update_pack_decision()

func _update_pack_decision() -> void:
	if _base_speed > 0.0 and _driver.target_speed > _base_speed * 1.75:
		_base_speed = _driver.target_speed

	var forward := -_racer.global_transform.basis.z.normalized()
	var right := _racer.global_transform.basis.x.normalized()
	var front: WildDashCharacterController = null
	var front_distance := INF
	var front_side := 0.0
	var front_left := INF
	var front_right := INF
	var rear_left := INF
	var rear_right := INF

	for candidate in RaceManager.racers:
		if candidate == _racer or not candidate is WildDashCharacterController or RaceManager.finish_order.has(candidate):
			continue
		var other := candidate as WildDashCharacterController
		var offset := other.global_position - _racer.global_position
		offset.y = 0.0
		var ahead := offset.dot(forward)
		var side := offset.dot(right)
		if absf(side) > DETECTION_SIDE:
			continue

		if ahead > 0.3 and ahead <= DETECTION_FORWARD:
			if absf(side) <= FRONT_CORRIDOR and ahead < front_distance:
				front = other
				front_distance = ahead
				front_side = side
			elif side < -FRONT_CORRIDOR:
				front_left = minf(front_left, ahead)
			elif side > FRONT_CORRIDOR:
				front_right = minf(front_right, ahead)
		elif ahead < -0.3 and ahead >= -DETECTION_REAR:
			var rear_distance := absf(ahead)
			if side < 0.0:
				rear_left = minf(rear_left, rear_distance)
			else:
				rear_right = minf(rear_right, rear_distance)

	if front == null:
		_lane_shift = move_toward(_lane_shift, 0.0, 0.75)
		_driver.preferred_lane = lerpf(_driver.preferred_lane, _base_lane + _lane_shift, 0.32)
		_driver.target_speed = lerpf(_driver.target_speed, _base_speed * (0.98 + _risk * 0.04), 0.32)
		_record_action(&"pace", null, 0.0)
		return

	var left_clear := front_left == INF and rear_left == INF
	var right_clear := front_right == INF and rear_right == INF
	var preferred_side := -1.0 if front_side >= 0.0 else 1.0
	if left_clear and right_clear:
		preferred_side = -1.0 if int(_racer.get_instance_id()) % 2 == 0 else 1.0
	elif left_clear:
		preferred_side = -1.0
	elif right_clear:
		preferred_side = 1.0

	var lane_cap := HARD_MAX_LANE_SHIFT if GameManager.difficulty == &"nightmare" else MAX_LANE_SHIFT
	var overtake_strength := lerpf(1.25, lane_cap, _overtake)
	var desired_shift := preferred_side * overtake_strength
	var desired_speed_scale := 0.94
	var action: StringName = &"traffic_hold"
	var can_change_lane := left_clear or right_clear

	match _personality:
		Personality.AGGRESSIVE:
			if can_change_lane:
				desired_speed_scale = 1.035
				action = &"overtake"
			else:
				desired_speed_scale = 0.94
				desired_shift *= 0.35
		Personality.SAFE:
			desired_speed_scale = 0.91 if not can_change_lane else 0.96
			desired_shift *= 0.58
			action = &"yield" if not can_change_lane or front_distance < 4.0 else &"line_change"
		Personality.SHORTCUT:
			desired_speed_scale = 0.985
			desired_shift *= 0.76
			action = &"line_change" if can_change_lane else &"traffic_hold"
		Personality.ITEM_FIGHTER:
			if _racer.get_held_item() != &"":
				desired_speed_scale = 0.96
				desired_shift *= 0.68
				action = &"attack_setup"
			elif can_change_lane:
				desired_speed_scale = 1.01
				desired_shift *= 0.82
				action = &"overtake"
		_:
			if can_change_lane:
				desired_speed_scale = 0.995
				action = &"overtake"
			else:
				desired_speed_scale = 0.93
				desired_shift *= 0.35

	# Do not cut across a racer approaching from behind on the chosen side.
	if preferred_side < 0.0 and rear_left < 3.2:
		desired_shift = maxf(0.0, desired_shift)
		desired_speed_scale = minf(desired_speed_scale, 0.94)
		action = &"yield"
	elif preferred_side > 0.0 and rear_right < 3.2:
		desired_shift = minf(0.0, desired_shift)
		desired_speed_scale = minf(desired_speed_scale, 0.94)
		action = &"yield"

	var response := 0.68 if GameManager.difficulty == &"nightmare" else 0.55
	_lane_shift = clampf(lerpf(_lane_shift, desired_shift, response), -lane_cap, lane_cap)
	_driver.preferred_lane = clampf(_base_lane + _lane_shift, -4.2, 4.2)
	_driver.target_speed = _base_speed * desired_speed_scale
	_record_action(action, front, front_distance)

func _record_action(action: StringName, target: WildDashCharacterController, gap: float) -> void:
	if action == _last_action:
		return
	match action:
		&"overtake":
			_overtake_actions += 1
		&"yield":
			_yield_actions += 1
		&"line_change":
			_line_change_actions += 1
		&"traffic_hold":
			_traffic_holds += 1
	var target_name := "none" if target == null else target.name
	print("AI PACK TACTIC racer=%s personality=%s action=%s target=%s gap=%.1f lane=%.1f" % [
		_racer.name, get_personality_name(), String(action), target_name, gap, _driver.preferred_lane,
	])
	_last_action = action
