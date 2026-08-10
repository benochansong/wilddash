class_name WildDashAIItemBrain
extends Node

var _racer: WildDashCharacterController
var _driver: WildDashAIController
var _think_elapsed := 0.0
var _held_age := 0.0
var _last_item: StringName = &""
var _profile: Dictionary = {}
var _uses := 0

func configure(racer: WildDashCharacterController, driver: WildDashAIController) -> void:
	_racer = racer
	_driver = driver
	_profile = WildDashDifficultySystem.get_profile(GameManager.difficulty)

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
	var interval := float(_profile.get("item_decision_interval", 0.30))
	if _think_elapsed < interval:
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
	var threshold := float(_profile.get("item_utility_threshold", 0.60))
	if _held_age >= 4.0:
		threshold = maxf(0.30, threshold - 0.24)
	if utility < threshold:
		return false
	var used := ItemSystem.use_held_item(_racer)
	if used:
		_uses += 1
		print("AI ITEM USE racer=%s item=%s utility=%.2f rank=%d difficulty=%s" % [
			RaceManager.get_racer_label(_racer),
			ItemSystem.get_display_name(item_id),
			utility,
			RaceManager.get_rank(_racer),
			WildDashDifficultySystem.get_display_name(GameManager.difficulty),
		])
		_last_item = &""
		_held_age = 0.0
	return used

func _utility_for_item(item_id: StringName) -> float:
	var rank := RaceManager.get_rank(_racer)
	var total := maxi(1, RaceManager.racers.size())
	var back_ratio := float(rank - 1) / float(maxi(1, total - 1))
	var risk := float(_profile.get("risk_taking", 0.58))
	var final_push := 0.10 * risk if RaceManager.get_progress_percent(_racer) >= 78.0 else 0.0
	match item_id:
		ItemSystem.DASH_BERRY:
			var straight_bonus := 0.42 if _is_long_straight() else 0.08
			return 0.36 + straight_bonus + back_ratio * 0.18 + final_push
		ItemSystem.BUBBLE_SHIELD:
			var nearby := ItemSystem.count_racers_near(_racer, 6.0)
			return 0.36 + minf(0.34, float(nearby) * 0.13) + (0.12 if rank <= 3 else 0.0) + risk * 0.06
		ItemSystem.STICKY_FRUIT:
			return 0.84 if ItemSystem.has_racer_behind(_racer, 10.0) else 0.22 + (0.18 if rank <= 3 else 0.0) + risk * 0.08
		ItemSystem.SHOCKWAVE:
			var crowded := ItemSystem.count_racers_near(_racer, 7.0)
			return 0.23 + minf(0.64, float(crowded) * 0.24) + back_ratio * 0.12 + risk * 0.08
		ItemSystem.ROCKET_NUT:
			return (0.88 + final_push) if ItemSystem.has_target_ahead(_racer, 48.0) else 0.16
		ItemSystem.RECOVERY_FEATHER:
			var target_speed := _driver.target_speed if _driver != null else _racer.max_speed
			var struggling := _racer.current_speed < target_speed * 0.72
			var progress := RaceManager.get_progress_percent(_racer)
			var shortcut_window := progress >= 65.0 and progress <= 82.0
			return 0.40 + (0.38 if struggling else 0.0) + (0.22 * risk if shortcut_window else 0.0) + back_ratio * 0.14
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

func get_use_count() -> int:
	return _uses

func debug_get_threshold() -> float:
	return float(_profile.get("item_utility_threshold", 0.60))
