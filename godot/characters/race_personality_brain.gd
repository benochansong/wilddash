class_name WildDashRacePersonalityBrain
extends Node

const PERSONALITY_IDS: Array[StringName] = [
	&"balanced",
	&"aggressive",
	&"safe",
	&"shortcut",
	&"item_fighter",
]
const DEFAULT_DECISION_HZ := 6.0

var risk_level := 0.50
var shortcut_preference := 0.45
var overtake_preference := 0.60
var item_threshold_bias := 0.0

var _racer: WildDashCharacterController
var _driver: WildDashAIController
var _personality_id: StringName = &"balanced"
var _base_lane := 0.0
var _base_speed := 0.0
var _decision_hz := DEFAULT_DECISION_HZ
var _elapsed := 999.0
var _side_sign := 1.0

static func get_profile_ids() -> Array[StringName]:
	return [&"balanced", &"aggressive", &"safe", &"shortcut", &"item_fighter"]

static func get_default_decision_hz() -> float:
	return DEFAULT_DECISION_HZ

func configure(
	racer: WildDashCharacterController,
	driver: WildDashAIController,
	personality_id: StringName,
	seed_index := 0,
) -> void:
	_racer = racer
	_driver = driver
	_personality_id = personality_id if PERSONALITY_IDS.has(personality_id) else &"balanced"
	_side_sign = -1.0 if seed_index % 2 == 0 else 1.0
	if _driver != null:
		_base_lane = _driver.preferred_lane
		_base_speed = _driver.target_speed
	_apply_profile()
	print("AI PERSONALITY racer=%s profile=%s risk=%.2f shortcut=%.2f overtake=%.2f decision_hz=%.1f" % [
		RaceManager.get_racer_label(_racer) if _racer != null else "Unknown",
		String(_personality_id).to_upper(),
		risk_level,
		shortcut_preference,
		overtake_preference,
		_decision_hz,
	])

func sync_base_speed_from_driver() -> void:
	if _driver != null:
		_base_speed = _driver.target_speed

func get_personality_id() -> StringName:
	return _personality_id

func get_shortcut_preference() -> float:
	return shortcut_preference

func get_item_threshold_bias() -> float:
	return item_threshold_bias

func _process(delta: float) -> void:
	if _racer == null or _driver == null or not is_instance_valid(_racer) or _racer.finished or not RaceManager.active:
		return
	_elapsed += delta
	var interval := 1.0 / clampf(_decision_hz, 4.0, 8.0)
	if _elapsed < interval:
		return
	_elapsed = 0.0
	_update_tactical_choice()

func _update_tactical_choice() -> void:
	_driver.preferred_lane = lerpf(_driver.preferred_lane, _base_lane, 0.34)
	_driver.target_speed = _base_speed

	var nearby := _find_close_racer_ahead(14.0 + risk_level * 4.0)
	var target := nearby.get("racer") as Node3D
	if target == null:
		return
	var distance := float(nearby.get("distance", INF))
	var lateral := float(nearby.get("lateral", 0.0))
	if distance > 11.5:
		return

	if _personality_id == &"safe":
		_driver.target_speed = _base_speed * (0.88 if distance < 6.0 else 0.94)
		if distance < 5.2:
			_driver.preferred_lane = clampf(_base_lane + _side_sign * 1.15, -3.1, 3.1)
		return

	var side := _side_sign
	if absf(lateral) > 0.35:
		side = -1.0 if lateral > 0.0 else 1.0
	var lane_shift := lerpf(1.15, 2.35, overtake_preference)
	if _personality_id == &"item_fighter":
		lane_shift *= 0.78
		_driver.target_speed = _base_speed * 0.98
	else:
		_driver.target_speed = _base_speed * (1.0 + risk_level * 0.035)
	_driver.preferred_lane = clampf(_base_lane + side * lane_shift, -3.1, 3.1)
	_side_sign = side

func _find_close_racer_ahead(max_distance: float) -> Dictionary:
	var result := {"racer": null, "distance": INF, "lateral": 0.0}
	if _racer == null:
		return result
	var forward := -_racer.global_transform.basis.z.normalized()
	var right := _racer.global_transform.basis.x.normalized()
	var own_progress := RaceManager.get_track_progress(_racer)
	var best_distance := max_distance
	for rival in RaceManager.racers:
		if rival == _racer or not is_instance_valid(rival) or RaceManager.finish_order.has(rival):
			continue
		var progress_delta := RaceManager.get_track_progress(rival) - own_progress
		if progress_delta < -2.0 or progress_delta > 32.0:
			continue
		var offset := rival.global_position - _racer.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance <= 0.05 or distance > best_distance:
			continue
		if forward.dot(offset.normalized()) < 0.18:
			continue
		best_distance = distance
		result.racer = rival
		result.distance = distance
		result.lateral = offset.dot(right)
	return result

func _apply_profile() -> void:
	match _personality_id:
		&"aggressive":
			risk_level = 0.90
			shortcut_preference = 0.35
			overtake_preference = 0.95
			item_threshold_bias = -0.03
			if _driver != null:
				_driver.lane_wander = 0.22
		&"safe":
			risk_level = 0.20
			shortcut_preference = 0.10
			overtake_preference = 0.25
			item_threshold_bias = 0.04
			if _driver != null:
				_driver.lane_wander = 0.08
		&"shortcut":
			risk_level = 0.72
			shortcut_preference = 1.0
			overtake_preference = 0.68
			item_threshold_bias = 0.0
			if _driver != null:
				_driver.lane_wander = 0.12
		&"item_fighter":
			risk_level = 0.64
			shortcut_preference = 0.42
			overtake_preference = 0.52
			item_threshold_bias = -0.08
			if _driver != null:
				_driver.lane_wander = 0.16
		_:
			risk_level = 0.50
			shortcut_preference = 0.45
			overtake_preference = 0.60
			item_threshold_bias = 0.0
			if _driver != null:
				_driver.lane_wander = 0.13
