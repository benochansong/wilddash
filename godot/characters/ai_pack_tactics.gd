class_name WildDashAIPackTactics
extends Node

enum Personality {
	AGGRESSIVE,
	SAFE,
	SHORTCUT,
	ITEM_FIGHTER,
	BALANCED,
}

const THINK_INTERVAL := 0.16 # 6.25 Hz high-level pack decisions.
const DETECTION_FORWARD := 10.5
const DETECTION_SIDE := 3.4
const MAX_LANE_SHIFT := 2.8
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
var _lane_shift := 0.0
var _last_action := &"pace"

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
	if GameManager.difficulty == &"nightmare":
		_risk = clampf(_risk + HARD_RISK_BONUS, 0.0, 1.0)
		_overtake = clampf(_overtake + HARD_OVERTAKE_BONUS, 0.0, 1.0)
		_shortcut_preference = clampf(_shortcut_preference + HARD_SHORTCUT_BONUS, 0.0, 1.0)
		_base_speed *= HARD_SPEED_SCALE
		_driver.target_speed = _base_speed
		print("AI HARD PROFILE racer=%s risk=%.2f overtake=%.2f shortcut=%.2f speed_scale=%.2f" % [
			racer.name, _risk, _overtake, _shortcut_preference, HARD_SPEED_SCALE,
		])
	_think_elapsed = float(racer.get_instance_id() % 13) * 0.009

func get_shortcut_preference() -> float:
	return _shortcut_preference

func get_risk() -> float:
	return _risk

func get_overtake_preference() -> float:
	return _overtake

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

func _process(delta: float) -> void:
	if _racer == null or _driver == null or not is_instance_valid(_racer) or _racer.finished or not RaceManager.active:
		return
	_think_elapsed += delta
	if _think_elapsed < THINK_INTERVAL:
		return
	_think_elapsed = 0.0
	_update_pack_decision()

func _update_pack_decision() -> void:
	# CI and future difficulty systems may deliberately scale a driver's speed
	# after this tactics node is configured. Adopt large external scale changes
	# as the new baseline instead of accidentally cancelling them on first think.
	if _base_speed > 0.0 and _driver.target_speed > _base_speed * 1.75:
		_base_speed = _driver.target_speed

	var forward := -_racer.global_transform.basis.z.normalized()
	var right := _racer.global_transform.basis.x.normalized()
	var nearest: WildDashCharacterController = null
	var nearest_forward := INF
	var nearest_side := 0.0

	# Grand Prix target is 15-18 racers. A compact scan at 6.25 Hz is cheaper
	# and more deterministic than every-AI, every-physics-frame ray fan-outs.
	for candidate in RaceManager.racers:
		if candidate == _racer or not candidate is WildDashCharacterController or RaceManager.finish_order.has(candidate):
			continue
		var other := candidate as WildDashCharacterController
		var offset := other.global_position - _racer.global_position
		offset.y = 0.0
		var ahead := offset.dot(forward)
		if ahead <= 0.3 or ahead > DETECTION_FORWARD:
			continue
		var side := offset.dot(right)
		if absf(side) > DETECTION_SIDE:
			continue
		if ahead < nearest_forward:
			nearest = other
			nearest_forward = ahead
			nearest_side = side

	if nearest == null:
		_lane_shift = move_toward(_lane_shift, 0.0, 0.9)
		_driver.preferred_lane = lerpf(_driver.preferred_lane, _base_lane + _lane_shift, 0.35)
		_driver.target_speed = lerpf(_driver.target_speed, _base_speed * (0.98 + _risk * 0.04), 0.35)
		_last_action = &"pace"
		return

	var side_sign := -1.0 if nearest_side >= 0.0 else 1.0
	if int(_racer.get_instance_id()) % 2 == 0:
		side_sign *= -1.0
	var overtake_strength := lerpf(1.25, MAX_LANE_SHIFT, _overtake)
	var desired_shift := side_sign * overtake_strength
	var desired_speed_scale := 0.94
	var action := &"pace"

	match _personality:
		Personality.AGGRESSIVE:
			desired_speed_scale = 1.04
			desired_shift *= 1.0
			action = &"overtake"
		Personality.SAFE:
			desired_speed_scale = 0.91
			desired_shift *= 0.62
			action = &"yield"
		Personality.SHORTCUT:
			desired_speed_scale = 0.99
			desired_shift *= 0.78
			action = &"line_change"
		Personality.ITEM_FIGHTER:
			desired_speed_scale = 0.96 if _racer.get_held_item() != &"" else 1.01
			desired_shift *= 0.72
			action = &"attack_setup" if _racer.get_held_item() != &"" else &"overtake"
		_:
			desired_speed_scale = 0.99
			action = &"overtake"

	_lane_shift = clampf(lerpf(_lane_shift, desired_shift, 0.55), -MAX_LANE_SHIFT, MAX_LANE_SHIFT)
	_driver.preferred_lane = clampf(_base_lane + _lane_shift, -4.2, 4.2)
	_driver.target_speed = _base_speed * desired_speed_scale
	if action != _last_action:
		print("AI PACK TACTIC racer=%s personality=%s action=%s target=%s gap=%.1f lane=%.1f" % [
			_racer.name, get_personality_name(), String(action), nearest.name, nearest_forward, _driver.preferred_lane,
		])
	_last_action = action
