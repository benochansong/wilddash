class_name WildDashAIItemBrain
extends Node

var _racer: WildDashCharacterController
var _driver: WildDashAIController
var _think_elapsed := 0.0
var _held_age := 0.0
var _last_item: StringName = &""
var _decision_interval := 0.30
var _utility_threshold := 0.59
var _difficulty_id: StringName = WildDashDifficultySystem.NORMAL

func configure(racer: WildDashCharacterController, driver: WildDashAIController, difficulty_id: StringName = &"") -> void:
	_racer = racer
	_driver = driver
	configure_difficulty(GameManager.difficulty if difficulty_id == &"" else difficulty_id)

func configure_difficulty(id: StringName) -> void:
	_difficulty_id = WildDashDifficultySystem.normalize(id)
	var profile := WildDashDifficultySystem.get_profile(_difficulty_id)
	_decision_interval = float(profile.item_decision_interval)
	_utility_threshold = float(profile.item_utility_threshold)

func get_decision_interval() -> float:
	return _decision_interval

func get_utility_threshold() -> float:
	return _utility_threshold

func _process(delta: float) -> void:
	if _racer == null or not is_instance_valid(_racer) or _racer.finished or not RaceManager.active:
		return
	var item_id := _racer.get_held_item()
	if item_id == &"":
		_last_item = &""
		_held_age = 0.0
		return
	if item_id != _last_item:
		_last_item = item_id
		_held_age = 0.0
	_held_age += delta
	_think_elapsed += delta
	if _think_elapsed < _decision_interval:
		return
	_think_elapsed = 0.0
	evaluate_and_use_now()

func evaluate_and_use_now() -> bool:
	if _racer == null or not is_instance_valid(_racer):
		return false
	var item_id := _racer.get_held_item()
	if item_id == &"":
		return false
	var utility := _utility_for_item(item_id)
	var threshold := _utility_threshold
	if _held_age >= 4.0:
		threshold = maxf(0.30, _utility_threshold - 0.22)
	if utility < threshold:
		return false
	var used := ItemSystem.use_held_item(_racer)
	if used:
		print("AI ITEM USE racer=%s item=%s utility=%.2f rank=%d difficulty=%s" % [
			RaceManager.get_racer_label(_racer),
			ItemSystem.get_display_name(item_id),
			utility,
			RaceManager.get_rank(_racer),
			_difficulty_id,
		])
		_last_item = &""
		_held_age = 0.0
	return used

func _utility_for_item(item_id: StringName) -> float:
	var rank := RaceManager.get_rank(_racer)
	var total := maxi(1, RaceManager.racers.size())
	var back_ratio := float(rank - 1) / float(maxi(1, total - 1))
	var progress_ratio := RaceManager.get_progress_percent(_racer) / 100.0
	var late_race_bonus := 0.10 if progress_ratio >= 0.78 and rank > 1 else 0.0
	match item_id:
		ItemSystem.DASH_BERRY:
			var straight_bonus := 0.42 if _is_long_straight() else 0.08
			return 0.38 + straight_bonus + back_ratio * 0.18 + late_race_bonus
		ItemSystem.BUBBLE_SHIELD:
			var nearby := ItemSystem.count_racers_near(_racer, 6.0)
			return 0.38 + minf(0.34, float(nearby) * 0.13) + (0.12 if rank <= 3 else 0.0)
		ItemSystem.STICKY_FRUIT:
			return 0.82 if ItemSystem.has_racer_behind(_racer, 10.0) else 0.24 + (0.16 if rank <= 3 else 0.0)
		ItemSystem.SHOCKWAVE:
			var crowded := ItemSystem.count_racers_near(_racer, 7.0)
			return 0.25 + minf(0.62, float(crowded) * 0.24) + back_ratio * 0.12
		ItemSystem.ROCKET_NUT:
			return (0.88 + late_race_bonus) if ItemSystem.has_target_ahead(_racer, 48.0) else 0.18
		ItemSystem.RECOVERY_FEATHER:
			var target_speed := _driver.target_speed if _driver != null else _racer.max_speed
			var struggling := _racer.current_speed < target_speed * 0.72
			var progress := RaceManager.get_progress_percent(_racer)
			var shortcut_window := progress >= 65.0 and progress <= 82.0
			return 0.42 + (0.38 if struggling else 0.0) + (0.22 if shortcut_window else 0.0) + back_ratio * 0.14
	return 0.0

func _is_long_straight() -> bool:
	var route := RaceManager.get_route_points()
	if route.size() < 4:
		return true
	var index := 1
	if _driver != null:
		index = clampi(_driver.get_route_index(), 1, route.size() - 2)
	else:
		var best_distance := INF
		for i in range(1, route.size() - 1):
			var distance := _racer.global_position.distance_squared_to(route[i])
			if distance < best_distance:
				best_distance = distance
				index = i
	var a := route[index] - route[index - 1]
	var b := route[index + 1] - route[index]
	a.y = 0.0
	b.y = 0.0
	if a.length_squared() < 0.01 or b.length_squared() < 0.01:
		return true
	return a.normalized().dot(b.normalized()) >= 0.90
