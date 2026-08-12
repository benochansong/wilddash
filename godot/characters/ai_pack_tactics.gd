class_name WildDashAIPackTactics
extends Node

enum Personality {
	AGGRESSIVE,
	SAFE,
	SHORTCUT,
	ITEM_FIGHTER,
	BALANCED,
}

const NORMAL_THINK_INTERVAL := 0.18
const HARD_THINK_INTERVAL := 0.14
const DETECTION_FORWARD := 12.5
const DETECTION_REAR := 7.5
const DETECTION_SIDE := 4.4
const FRONT_CORRIDOR := 1.55
const MAX_LANE_SHIFT := 2.45
const HARD_MAX_LANE_SHIFT := 2.85
const NORMAL_LANE_COMMIT_SECONDS := 0.85
const HARD_LANE_COMMIT_SECONDS := 0.62
const NORMAL_FRONT_HEADWAY := 4.4
const HARD_FRONT_HEADWAY := 4.0
const SIDE_FRONT_CLEARANCE := 5.2
const SIDE_REAR_CLEARANCE := 4.4
const ESCAPE_FRONT_CLEARANCE := 4.25
const ESCAPE_REAR_CLEARANCE := 3.55
const LARGE_BODY_HEADWAY_BONUS := 0.9
const LARGE_BODY_ESCAPE_BONUS := 0.35
const LARGE_BODY_LANE_SCALE := 0.74
const CROWD_DENSITY_LIMIT := 4
const CROWD_LANE_SCALE := 0.72
const NORMAL_BLOCKED_ESCAPE_SECONDS := 1.05
const HARD_BLOCKED_ESCAPE_SECONDS := 0.78
const TRAILING_ESCAPE_TIME_SCALE := 0.82
const BLOCKED_SPEED_RATIO := 0.91
const ESCAPE_COOLDOWN_SECONDS := 1.25
const NORMAL_ESCAPE_COMMIT_SECONDS := 1.05
const HARD_ESCAPE_COMMIT_SECONDS := 0.86
const POST_BLOCK_RECOVERY_SECONDS := 1.25
const PRODUCTION_PACE_SCALE := 1.35
const HARD_RISK_BONUS := 0.12
const HARD_OVERTAKE_BONUS := 0.10
const HARD_SHORTCUT_BONUS := 0.10
const HARD_SPEED_SCALE := 1.02
const LARGE_BODY_ANIMALS := [&"bear", &"elephant", &"panda", &"boar"]

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
var _lane_commit_remaining := 0.0
var _committed_side := 0.0
var _escape_cooldown_remaining := 0.0
var _post_block_recovery_remaining := 0.0
var _blocked_elapsed := 0.0
var _blocked_target_id := 0
var _blocked_active := false
var _last_action := &"pace"
var _overtake_actions := 0
var _yield_actions := 0
var _line_change_actions := 0
var _traffic_holds := 0
var _lane_commit_actions := 0
var _crowd_avoid_actions := 0
var _blocked_breakout_actions := 0
var _commit_break_actions := 0
var _blocked_seconds_total := 0.0

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
		"lane_commits": _lane_commit_actions,
		"crowd_avoids": _crowd_avoid_actions,
		"blocked_breakouts": _blocked_breakout_actions,
		"commit_breaks": _commit_break_actions,
		"blocked_seconds": _blocked_seconds_total,
	}

func _process(delta: float) -> void:
	if _racer == null or _driver == null or not is_instance_valid(_racer) or _racer.finished or not RaceManager.active:
		return
	_lane_commit_remaining = maxf(0.0, _lane_commit_remaining - delta)
	_escape_cooldown_remaining = maxf(0.0, _escape_cooldown_remaining - delta)
	_post_block_recovery_remaining = maxf(0.0, _post_block_recovery_remaining - delta)
	if _blocked_active:
		_blocked_seconds_total += delta
	_think_elapsed += delta
	if _think_elapsed < _think_interval:
		return
	var decision_elapsed := _think_elapsed
	_think_elapsed = 0.0
	_update_pack_decision(decision_elapsed)

func _update_pack_decision(decision_elapsed: float) -> void:
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
	var nearby_count := 0

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
		if absf(ahead) <= DETECTION_FORWARD:
			nearby_count += 1

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
		if _blocked_elapsed >= 0.35:
			_post_block_recovery_remaining = maxf(_post_block_recovery_remaining, POST_BLOCK_RECOVERY_SECONDS)
		_reset_blocked_state()
		var decay := 0.28 if _lane_commit_remaining > 0.0 else 0.62
		_lane_shift = move_toward(_lane_shift, 0.0, decay)
		if _lane_commit_remaining <= 0.0:
			_committed_side = 0.0
		_driver.preferred_lane = lerpf(_driver.preferred_lane, _base_lane + _lane_shift, 0.26)
		var pace_scale := 0.985 + _risk * 0.025
		var pace_response := 0.28
		if _post_block_recovery_remaining > 0.0:
			pace_scale = maxf(pace_scale, 1.0)
			pace_response = 0.56 if GameManager.difficulty == &"nightmare" else 0.50
		_driver.target_speed = lerpf(_driver.target_speed, _base_speed * pace_scale, pace_response)
		_record_action(&"pace", null, 0.0)
		return

	var large_body := _is_large_body()
	var safe_front_gap := HARD_FRONT_HEADWAY if GameManager.difficulty == &"nightmare" else NORMAL_FRONT_HEADWAY
	if large_body:
		safe_front_gap += LARGE_BODY_HEADWAY_BONUS

	var left_clear := front_left > SIDE_FRONT_CLEARANCE and rear_left > SIDE_REAR_CLEARANCE
	var right_clear := front_right > SIDE_FRONT_CLEARANCE and rear_right > SIDE_REAR_CLEARANCE
	var preferred_side := -1.0 if front_side >= 0.0 else 1.0
	var committed_clear := (_committed_side < 0.0 and left_clear) or (_committed_side > 0.0 and right_clear)
	if _lane_commit_remaining > 0.0 and _committed_side != 0.0 and committed_clear:
		preferred_side = _committed_side
	elif left_clear and right_clear:
		if absf(front_left - front_right) > 0.75:
			preferred_side = -1.0 if front_left > front_right else 1.0
		else:
			preferred_side = -1.0 if int(_racer.get_instance_id()) % 2 == 0 else 1.0
	elif left_clear:
		preferred_side = -1.0
	elif right_clear:
		preferred_side = 1.0

	var rank: int = RaceManager.get_rank(_racer)
	var field_size: int = RaceManager.racers.size()
	var trailing_half: bool = rank > ceili(float(field_size) * 0.5)
	var front_id: int = int(front.get_instance_id())
	var slow_in_traffic: bool = _racer.current_speed < _base_speed * BLOCKED_SPEED_RATIO
	var blocked_range: bool = front_distance < safe_front_gap * 1.55
	if blocked_range and slow_in_traffic:
		if _blocked_target_id == front_id:
			_blocked_elapsed += decision_elapsed
		else:
			_blocked_target_id = front_id
			_blocked_elapsed = decision_elapsed
		_blocked_active = true
	else:
		_blocked_elapsed = maxf(0.0, _blocked_elapsed - decision_elapsed * 1.6)
		if _blocked_elapsed <= 0.01:
			_blocked_target_id = 0
			_blocked_active = false

	var escape_threshold := HARD_BLOCKED_ESCAPE_SECONDS if GameManager.difficulty == &"nightmare" else NORMAL_BLOCKED_ESCAPE_SECONDS
	if trailing_half:
		escape_threshold *= TRAILING_ESCAPE_TIME_SCALE
	var escape_front_clearance := ESCAPE_FRONT_CLEARANCE + (LARGE_BODY_ESCAPE_BONUS if large_body else 0.0)
	var escape_rear_clearance := ESCAPE_REAR_CLEARANCE + (LARGE_BODY_ESCAPE_BONUS if large_body else 0.0)
	var left_escape_clear := front_left > escape_front_clearance and rear_left > escape_rear_clearance
	var right_escape_clear := front_right > escape_front_clearance and rear_right > escape_rear_clearance
	var breakout_ready := _blocked_elapsed >= escape_threshold and _escape_cooldown_remaining <= 0.0 and (left_escape_clear or right_escape_clear)

	var can_change_lane := (preferred_side < 0.0 and left_clear) or (preferred_side > 0.0 and right_clear)
	if breakout_ready:
		var escape_side := preferred_side
		if left_escape_clear and right_escape_clear:
			var left_score := _side_clearance_score(front_left, rear_left)
			var right_score := _side_clearance_score(front_right, rear_right)
			escape_side = -1.0 if left_score >= right_score else 1.0
		elif left_escape_clear:
			escape_side = -1.0
		else:
			escape_side = 1.0
		if _lane_commit_remaining > 0.0 and _committed_side != 0.0 and escape_side != _committed_side:
			_commit_break_actions += 1
		preferred_side = escape_side
		can_change_lane = true
		_committed_side = escape_side
		_lane_commit_remaining = HARD_ESCAPE_COMMIT_SECONDS if GameManager.difficulty == &"nightmare" else NORMAL_ESCAPE_COMMIT_SECONDS
		_escape_cooldown_remaining = ESCAPE_COOLDOWN_SECONDS
		_post_block_recovery_remaining = POST_BLOCK_RECOVERY_SECONDS
		_blocked_breakout_actions += 1
		_blocked_elapsed = 0.0
		_blocked_target_id = 0
		_blocked_active = false
	elif can_change_lane and (_committed_side == 0.0 or preferred_side != _committed_side or _lane_commit_remaining <= 0.0):
		_committed_side = preferred_side
		_lane_commit_remaining = HARD_LANE_COMMIT_SECONDS if GameManager.difficulty == &"nightmare" else NORMAL_LANE_COMMIT_SECONDS
		_lane_commit_actions += 1
	elif not can_change_lane and _lane_commit_remaining <= 0.0:
		_committed_side = 0.0

	var lane_cap := HARD_MAX_LANE_SHIFT if GameManager.difficulty == &"nightmare" else MAX_LANE_SHIFT
	var overtake_strength := lerpf(1.20, lane_cap, _overtake)
	var desired_shift := preferred_side * overtake_strength
	if large_body:
		desired_shift *= LARGE_BODY_LANE_SCALE
	var desired_speed_scale := 0.965
	var action: StringName = &"traffic_hold"

	match _personality:
		Personality.AGGRESSIVE:
			if can_change_lane:
				desired_speed_scale = 1.02
				action = &"overtake"
			else:
				desired_speed_scale = 0.965
				desired_shift *= 0.30
		Personality.SAFE:
			desired_speed_scale = 0.955 if not can_change_lane else 0.98
			desired_shift *= 0.55
			action = &"yield" if not can_change_lane or front_distance < safe_front_gap else &"line_change"
		Personality.SHORTCUT:
			desired_speed_scale = 0.995 if can_change_lane else 0.965
			desired_shift *= 0.72
			action = &"line_change" if can_change_lane else &"traffic_hold"
		Personality.ITEM_FIGHTER:
			if _racer.get_held_item() != &"":
				desired_speed_scale = 0.98 if can_change_lane else 0.96
				desired_shift *= 0.64
				action = &"attack_setup"
			elif can_change_lane:
				desired_speed_scale = 1.01
				desired_shift *= 0.78
				action = &"overtake"
			else:
				desired_speed_scale = 0.965
		_:
			if can_change_lane:
				desired_speed_scale = 1.005
				action = &"overtake"
			else:
				desired_speed_scale = 0.965
				desired_shift *= 0.30

	# Follow the pace of the car ahead without stacking an excessive slowdown.
	# Phase 2 could cap a blocked racer at 0.93x even when the front racer was
	# moving at nearly the same pace, which widened the tail of dense fields.
	if front_distance < safe_front_gap:
		var pressure := clampf((safe_front_gap - front_distance) / safe_front_gap, 0.0, 1.0)
		var close_speed_cap := lerpf(0.99, 0.96, pressure)
		var front_speed_ratio := clampf(front.current_speed / maxf(_base_speed, 0.1), 0.90, 1.02)
		close_speed_cap = maxf(close_speed_cap, minf(0.995, front_speed_ratio + 0.012))
		if large_body:
			close_speed_cap = minf(close_speed_cap, 0.985)
		if GameManager.difficulty == &"nightmare":
			close_speed_cap = minf(0.998, close_speed_cap + 0.006)
		desired_speed_scale = minf(desired_speed_scale, close_speed_cap)
		if not can_change_lane:
			desired_shift *= 0.55
			action = &"yield" if _personality == Personality.SAFE else &"traffic_hold"

	if breakout_ready:
		desired_speed_scale = maxf(desired_speed_scale, 0.995 if GameManager.difficulty == &"nightmare" else 0.985)
		action = &"blocked_escape"

	# Do not cut across a racer approaching from behind. During an explicit
	# blocked escape, use a still-safe but slightly tighter rear gap so the tail
	# can actually leave a traffic queue instead of waiting indefinitely.
	var rear_guard := escape_rear_clearance if breakout_ready else SIDE_REAR_CLEARANCE
	if preferred_side < 0.0 and rear_left < rear_guard:
		desired_shift = maxf(0.0, desired_shift)
		desired_speed_scale = minf(desired_speed_scale, 0.97)
		action = &"yield"
	elif preferred_side > 0.0 and rear_right < rear_guard:
		desired_shift = minf(0.0, desired_shift)
		desired_speed_scale = minf(desired_speed_scale, 0.97)
		action = &"yield"

	# Dense groups still prefer stable lines, except when the racer has been
	# measurably blocked long enough to justify a committed escape.
	if nearby_count >= CROWD_DENSITY_LIMIT and front_distance < safe_front_gap * 1.35 and not breakout_ready:
		desired_shift *= CROWD_LANE_SCALE
		desired_speed_scale = minf(desired_speed_scale, 0.985 if GameManager.difficulty == &"nightmare" else 0.98)
		_crowd_avoid_actions += 1
		if action == &"overtake":
			action = &"line_change"

	var response := 0.50 if GameManager.difficulty == &"nightmare" else 0.40
	if breakout_ready:
		response = 0.66 if GameManager.difficulty == &"nightmare" else 0.58
	_lane_shift = clampf(lerpf(_lane_shift, desired_shift, response), -lane_cap, lane_cap)
	_driver.preferred_lane = clampf(_base_lane + _lane_shift, -4.0, 4.0)
	var speed_response := 0.46 if GameManager.difficulty == &"nightmare" else 0.38
	if breakout_ready or _post_block_recovery_remaining > 0.0:
		speed_response = 0.58 if GameManager.difficulty == &"nightmare" else 0.52
	_driver.target_speed = lerpf(_driver.target_speed, _base_speed * desired_speed_scale, speed_response)
	_record_action(action, front, front_distance)

func _side_clearance_score(front_gap: float, rear_gap: float) -> float:
	return minf(front_gap, 18.0) * 0.58 + minf(rear_gap, 14.0) * 0.42

func _reset_blocked_state() -> void:
	_blocked_elapsed = 0.0
	_blocked_target_id = 0
	_blocked_active = false

func _is_large_body() -> bool:
	return _racer != null and _racer.animal_id in LARGE_BODY_ANIMALS

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
	var target_name: String = "none" if target == null else String(target.name)
	print("AI PACK TACTIC racer=%s personality=%s action=%s target=%s gap=%.1f lane=%.1f blocked=%.2f" % [
		_racer.name, get_personality_name(), String(action), target_name, gap, _driver.preferred_lane, _blocked_elapsed,
	])
	_last_action = action
