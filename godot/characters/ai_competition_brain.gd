class_name WildDashAICompetitionBrain
extends Node

var _racer: WildDashCharacterController
var _driver: WildDashAIController
var _profile: Dictionary = {}
var _think_elapsed := 0.0
var _base_target_speed := 0.0
var _base_lane := 0.0
var _base_wander := 0.0
var _base_steering := 0.0
var _base_acceleration := 0.0
var _base_avoidance := 0.0
var _penalty_remaining := 0.0
var _last_position := Vector3.ZERO
var _last_rank := 0
var _rank_changes := 0
var _overtake_attempts := 0
var _decision_count := 0
var _mistakes := 0
var _recoveries := 0
var _temporary_lane_bias := 0.0
var _mistake_remaining := 0.0
var _rng := RandomNumberGenerator.new()

func configure(racer: WildDashCharacterController, driver: WildDashAIController) -> void:
	_racer = racer
	_driver = driver
	_profile = WildDashDifficultySystem.get_profile(GameManager.difficulty)
	_base_target_speed = driver.target_speed
	_base_lane = driver.preferred_lane
	_base_wander = driver.lane_wander
	_base_steering = driver.steering_strength
	_base_acceleration = driver.acceleration
	_base_avoidance = driver.avoidance_distance
	_last_position = racer.global_position
	_last_rank = RaceManager.get_rank(racer)
	_rng.seed = int(racer.get_instance_id() * 7919 + String(GameManager.difficulty).hash())
	_apply_profile_baseline()

func refresh_baseline_from_driver() -> void:
	if _driver == null:
		return
	_base_target_speed = _driver.target_speed / maxf(0.01, float(_profile.ai_speed_scale))
	_base_steering = _driver.steering_strength / maxf(0.01, float(_profile.steering_scale))
	_base_acceleration = _driver.acceleration / maxf(0.01, float(_profile.acceleration_scale))
	_base_avoidance = _driver.avoidance_distance / maxf(0.01, float(_profile.avoidance_scale))
	_apply_profile_baseline()

func _physics_process(delta: float) -> void:
	if _racer == null or _driver == null or not is_instance_valid(_racer) or _racer.finished:
		return
	_detect_rank_change()
	_detect_recovery_jump()
	if _penalty_remaining > 0.0:
		_penalty_remaining = maxf(0.0, _penalty_remaining - delta)
		_driver.target_speed = _base_target_speed * 0.34
		_racer.current_speed = minf(_racer.current_speed, _base_target_speed * 0.45)
		return
	_mistake_remaining = maxf(0.0, _mistake_remaining - delta)
	_think_elapsed += delta
	if _think_elapsed < float(_profile.reaction_interval):
		return
	var elapsed := _think_elapsed
	_think_elapsed = 0.0
	_decision_count += 1
	_evaluate_competition(elapsed)

func _apply_profile_baseline() -> void:
	if _driver == null:
		return
	var stable_seed := int(_racer.get_instance_id()) if _racer != null else 1
	_driver.target_speed = WildDashDifficultySystem.apply_small_ai_variance(_base_target_speed * float(_profile.ai_speed_scale), stable_seed)
	_driver.steering_strength = _base_steering * float(_profile.steering_scale)
	_driver.acceleration = _base_acceleration * float(_profile.acceleration_scale)
	_driver.avoidance_distance = _base_avoidance * float(_profile.avoidance_scale)
	_driver.lane_wander = _base_wander * (1.18 if GameManager.difficulty == WildDashDifficultySystem.CASUAL else (0.72 if GameManager.difficulty == WildDashDifficultySystem.HARD else 1.0))

func _evaluate_competition(elapsed: float) -> void:
	_apply_profile_baseline()
	var rank := RaceManager.get_rank(_racer)
	var total := maxi(1, RaceManager.racers.size())
	var progress := RaceManager.get_progress_percent(_racer)
	var risk: float = float(_profile.risk_taking)
	var ahead := _nearest_competitor(true, 13.0)
	var behind := _nearest_competitor(false, 9.0)

	# Deliberate, small mistakes keep AI human. Casual makes more; Hard still
	# retains a tiny error rate so it never becomes a perfect racing line bot.
	if _mistake_remaining <= 0.0 and _rng.randf() < float(_profile.mistake_chance) * maxf(0.25, elapsed * 2.0):
		_mistake_remaining = _rng.randf_range(0.35, 0.80)
		_temporary_lane_bias = _rng.randf_range(-1.15, 1.15)
		_mistakes += 1
	if _mistake_remaining > 0.0:
		_driver.preferred_lane = clampf(_base_lane + _temporary_lane_bias, -3.2, 3.2)
		_driver.steering_strength *= 0.80
		return

	var overtake_bias := 0.0
	if ahead != null:
		var side := -1.0 if ((int(_racer.get_instance_id()) + rank) % 2 == 0) else 1.0
		overtake_bias = side * lerpf(0.65, 2.20, risk)
		_overtake_attempts += 1
		# Close packs on Normal/Hard get a tiny acceleration preference, not a
		# hidden top-speed teleport/rubber-band bonus.
		if rank > 1:
			_driver.acceleration *= lerpf(1.0, 1.12, risk)
	elif behind != null and rank <= maxi(3, total / 3):
		# Leaders defend a line rather than receiving extra speed.
		overtake_bias = (-0.45 if int(_racer.get_instance_id()) % 2 == 0 else 0.45) * risk

	# Late race makes AI more willing to hold a passing line. No position warp.
	if progress >= 78.0 and rank > 1:
		overtake_bias *= 1.18
	_driver.preferred_lane = clampf(_base_lane + overtake_bias, -3.2, 3.2)

func _nearest_competitor(ahead: bool, max_distance: float) -> WildDashCharacterController:
	var my_progress := RaceManager.get_track_progress(_racer)
	var best: WildDashCharacterController = null
	var best_distance := max_distance
	for candidate_node in RaceManager.racers:
		if candidate_node == _racer or not (candidate_node is WildDashCharacterController):
			continue
		var candidate := candidate_node as WildDashCharacterController
		if candidate.finished:
			continue
		var delta_progress := RaceManager.get_track_progress(candidate) - my_progress
		if ahead and delta_progress <= 0.0:
			continue
		if not ahead and delta_progress >= 0.0:
			continue
		var distance := _racer.global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func _detect_rank_change() -> void:
	if not RaceManager.active:
		return
	var rank := RaceManager.get_rank(_racer)
	if _last_rank > 0 and rank > 0 and rank != _last_rank:
		_rank_changes += 1
	_last_rank = rank

func _detect_recovery_jump() -> void:
	var current := _racer.global_position
	var distance := current.distance_to(_last_position)
	# A large single-frame position correction is the track recovery path.
	if RaceManager.active and distance >= 11.0:
		_penalty_remaining = maxf(_penalty_remaining, float(_profile.recovery_penalty))
		_recoveries += 1
		print("AI RECOVERY PENALTY racer=%s difficulty=%s seconds=%.2f" % [
			RaceManager.get_racer_label(_racer),
			WildDashDifficultySystem.get_display_name(GameManager.difficulty),
			_penalty_remaining,
		])
	_last_position = current

func get_telemetry() -> Dictionary:
	return {
		"decisions": _decision_count,
		"overtakes": _overtake_attempts,
		"rank_changes": _rank_changes,
		"mistakes": _mistakes,
		"recoveries": _recoveries,
		"reaction": float(_profile.get("reaction_interval", 0.30)),
		"risk": float(_profile.get("risk_taking", 0.58)),
		"corner_precision": float(_profile.get("corner_precision", 1.0)),
	}

func debug_force_recovery_penalty() -> float:
	_penalty_remaining = float(_profile.recovery_penalty)
	return _penalty_remaining

func debug_has_overtake_target() -> bool:
	return _nearest_competitor(true, 13.0) != null
