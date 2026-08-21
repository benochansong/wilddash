extends "res://modes/logspire_leap/logspire_platform_ai.gd"

## Phase B landing stability adapter.
## Keeps the existing Platform AI state machine, prediction and moving-platform
## logic while spreading a large field across safe landing lanes and giving
## Safe Route racers a subtle airborne correction instead of visible cheating.
## A small, explicitly selected set of AI racers can also become Finale
## contenders. They stay on the Safe Route, receive stronger late-route landing
## correction, and only after prolonged no-progress may re-anchor by one authored
## platform. The player is never eligible for this convergence assist.

const PHASE_B_SAFE_AIR_ASSIST_RANGE: float = 13.5
const PHASE_B_SAFE_AIR_RESPONSE: float = 4.6
const PHASE_B_SAFE_LANDING_RESPONSE: float = 8.8
const PHASE_B_REPEAT_AIR_RESPONSE: float = 6.2
const PHASE_B_REPEAT_LANDING_RESPONSE: float = 11.0
const PHASE_B_LANDING_WINDOW_METERS: float = 2.0
const PHASE_B_MAX_LANE_OFFSET: float = 2.20
const PHASE_B_LANE_SPACING_RATIO: float = 0.18
const PHASE_B_FIVE_LANES: int = 5

const CONTENDER_AIR_ASSIST_RANGE: float = 18.5
const CONTENDER_AIR_RESPONSE: float = 7.4
const CONTENDER_LANDING_RESPONSE: float = 13.0
const CONTENDER_STALL_SECONDS: float = 6.5
const CONTENDER_REANCHOR_COOLDOWN: float = 7.5
const CONTENDER_MAX_REANCHORS: int = 5
const CONTENDER_MIN_JUMP_SCALE: float = 1.16

var _phase_b_lane_slot: int = 2
var _phase_b_last_failed_platform: StringName = &""
var _phase_b_air_log_cooldown: float = 0.0
var _finale_contender: bool = false
var _contender_last_route_index: int = -1
var _contender_stall_seconds: float = 0.0
var _contender_reanchor_cooldown: float = 0.0
var _contender_reanchors: int = 0

func configure(
	racer: WildDashCharacterController,
	driver: WildDashAIController,
	graph: Node,
	gameplay: Node,
	route_points: Array[Vector3],
	safe_route_points: Array[Vector3],
	route_platform_ids: Array[StringName],
	safe_platform_ids: Array[StringName],
	route_id: StringName
) -> void:
	super(racer, driver, graph, gameplay, route_points, safe_route_points, route_platform_ids, safe_platform_ids, route_id)
	if racer != null:
		_phase_b_lane_slot = int(racer.get_instance_id() % PHASE_B_FIVE_LANES)
	print("LOGSPIRE PLATFORM AI V5 PHASE B racer=%s route=%s landing_lane=%d safe_air_steering=true repeated_failure_center=true" % [
		RaceManager.get_racer_label(racer), String(route_id), _phase_b_lane_slot,
	])

func set_finale_contender(enabled: bool) -> void:
	_finale_contender = enabled and _racer != null and not _racer.is_player
	_contender_stall_seconds = 0.0
	_contender_reanchor_cooldown = 0.0
	_contender_reanchors = 0
	_contender_last_route_index = _driver.get_route_index() if _driver != null else -1
	if not _finale_contender:
		return

	# Contenders are the believable competitive pack that should still be visible
	# near the player late in the climb. Keep them on the proven Safe Route rather
	# than letting a risky Wild Route failure remove the whole field from Finale.
	if _safe_route.size() >= 2:
		_route_id = ROUTE_SAFE
		_route = _copy_route(_safe_route)
		_route_ids = _copy_ids(_safe_route_ids)
		if _driver != null:
			_driver.set_race_route(_route)
			_driver.steering_strength = maxf(_driver.steering_strength, 9.1)
			_driver.acceleration = maxf(_driver.acceleration, 26.0)
			_driver.avoidance_distance = maxf(_driver.avoidance_distance, 5.6)
			_driver.lane_wander = minf(_driver.lane_wander, 0.035)
	print("r3_ai_finale_contender racer=%s animal=%s safe_route=true late_assist=true bounded_reanchor=true" % [
		RaceManager.get_racer_label(_racer), String(_racer.animal_id),
	])

func is_finale_contender() -> bool:
	return _finale_contender

func get_contender_reanchor_count() -> int:
	return _contender_reanchors

func _physics_process(delta: float) -> void:
	_phase_b_air_log_cooldown = maxf(0.0, _phase_b_air_log_cooldown - delta)
	_contender_reanchor_cooldown = maxf(0.0, _contender_reanchor_cooldown - delta)
	super(delta)
	_update_contender_convergence(delta)

func _predicted_target(platform_id: StringName, fallback: Vector3, travel_time: float) -> Vector3:
	var predicted: Vector3 = super(platform_id, fallback, travel_time)
	if platform_id == &"" or _route_id != ROUTE_SAFE:
		return predicted
	return predicted + _phase_b_landing_offset(platform_id)

func _apply_tutorial_air_assist(delta: float) -> void:
	if _racer == null or _driver == null or _route.is_empty():
		return
	var target_index: int = clampi(_driver.get_route_index(), 1, _route.size() - 1)
	var platform_id: StringName = _platform_id_for_index(target_index)
	var tutorial_target: bool = _is_tutorial_target(platform_id)
	if _route_id != ROUTE_SAFE and not tutorial_target:
		return

	var base_target: Vector3 = _route[target_index]
	var target: Vector3 = _predicted_target(platform_id, base_target, 0.0)
	var planar := target - _racer.global_position
	planar.y = 0.0
	var distance: float = planar.length()
	var contender_late: bool = _finale_contender and _is_contender_late_target(platform_id)
	var assist_range: float = TUTORIAL_AIR_ASSIST_RANGE if tutorial_target else PHASE_B_SAFE_AIR_ASSIST_RANGE
	if contender_late:
		assist_range = CONTENDER_AIR_ASSIST_RANGE
	if distance <= 0.001 or distance > assist_range:
		return

	var direction: Vector3 = planar / distance
	var desired_speed: float = minf(_racer.max_speed, maxf(_racer.current_speed, _racer.cruise_speed))
	if _same_target_failures >= 2 or contender_late:
		desired_speed = minf(_racer.max_speed, maxf(desired_speed, _racer.cruise_speed * 1.04))
	var desired_velocity := direction * desired_speed
	var current_velocity := Vector3(_racer.velocity.x, 0.0, _racer.velocity.z)
	var landing_radius: float = _landing_radius(platform_id)
	var near_landing: bool = _racer.velocity.y <= 0.0 and distance <= landing_radius + PHASE_B_LANDING_WINDOW_METERS
	var response: float
	if tutorial_target:
		response = TUTORIAL_LANDING_STEER_RESPONSE if near_landing else TUTORIAL_AIR_STEER_RESPONSE
	elif contender_late:
		response = CONTENDER_LANDING_RESPONSE if near_landing else CONTENDER_AIR_RESPONSE
	elif _same_target_failures >= 2:
		response = PHASE_B_REPEAT_LANDING_RESPONSE if near_landing else PHASE_B_REPEAT_AIR_RESPONSE
	else:
		response = PHASE_B_SAFE_LANDING_RESPONSE if near_landing else PHASE_B_SAFE_AIR_RESPONSE
	var max_blend: float = 0.30 if contender_late and near_landing else (0.24 if near_landing else 0.16)
	var blend: float = clampf(delta * response, 0.0, max_blend)
	var adjusted := current_velocity.lerp(desired_velocity, blend)
	_racer.velocity.x = adjusted.x
	_racer.velocity.z = adjusted.z

	if near_landing and _phase_b_air_log_cooldown <= 0.0:
		_phase_b_air_log_cooldown = 1.2
		print("LOGSPIRE AI LANDING ASSIST racer=%s platform=%s route=%s distance=%.2f lane=%d failures=%d response=%.1f contender=%s teleport=false" % [
			RaceManager.get_racer_label(_racer), String(platform_id), String(_route_id), distance,
			_phase_b_lane_slot, _same_target_failures, response, str(contender_late),
		])

func _get_jump_trigger_distance(risk: float, landing_radius: float, moving_speed: float, tilt: float, shortcut: bool) -> float:
	var trigger: float = super(risk, landing_radius, moving_speed, tilt, shortcut)
	if not _finale_contender or _driver == null:
		return trigger
	var target_index: int = clampi(_driver.get_route_index(), 1, maxi(1, _route_ids.size() - 1))
	var platform_id: StringName = _platform_id_for_index(target_index)
	if _is_contender_late_target(platform_id):
		trigger += 0.90
	return clampf(trigger, MIN_JUMP_TRIGGER, MAX_JUMP_TRIGGER)

func _get_jump_scale(height_delta: float, risk: float, moving_speed: float, tilt: float, shortcut: bool) -> float:
	var scale: float = super(height_delta, risk, moving_speed, tilt, shortcut)
	if not _finale_contender or _driver == null:
		return scale
	var target_index: int = clampi(_driver.get_route_index(), 1, maxi(1, _route_ids.size() - 1))
	var platform_id: StringName = _platform_id_for_index(target_index)
	if _is_contender_late_target(platform_id):
		scale = maxf(scale + 0.045, CONTENDER_MIN_JUMP_SCALE)
	return clampf(scale, 1.03, 1.28)

func notify_recovered() -> void:
	if _driver != null:
		var failed_index: int = clampi(_driver.get_route_index(), 1, maxi(1, _route.size() - 1))
		_phase_b_last_failed_platform = _platform_id_for_index(failed_index)
	var failures_before: int = _same_target_failures
	super()
	# The legacy V4 reset after a third failure is useful for route fallback, but
	# on the new Safe Route we keep the strong assist tier armed until progress is
	# actually made. This avoids an endless fail/reset/fail cycle.
	if failures_before >= 2:
		_same_target_failures = 2
		_safer_landing_mode = true
	print("LOGSPIRE AI FALL REPORT zone=%s racer=%s target=%s failure_count=%d route=%s stronger_assist=%s contender=%s" % [
		_phase_b_zone_name(_phase_b_last_failed_platform),
		RaceManager.get_racer_label(_racer),
		String(_phase_b_last_failed_platform),
		_same_target_failures,
		String(_route_id),
		str(_same_target_failures >= 2),
		str(_finale_contender),
	])

func get_phase_b_last_failed_platform() -> StringName:
	return _phase_b_last_failed_platform

func _update_contender_convergence(delta: float) -> void:
	if not _finale_contender or _racer == null or _driver == null:
		return
	if _racer.finished or not RaceManager.active or _route.is_empty():
		return

	var target_index: int = clampi(_driver.get_route_index(), 1, _route.size() - 1)
	var platform_id: StringName = _platform_id_for_index(target_index)
	if not _is_contender_late_target(platform_id):
		_contender_stall_seconds = 0.0
		_contender_last_route_index = target_index
		return

	if target_index > _contender_last_route_index:
		_contender_last_route_index = target_index
		_contender_stall_seconds = 0.0
		return
	if target_index < _contender_last_route_index:
		_contender_last_route_index = target_index
		_contender_stall_seconds = 0.0
		return

	_contender_stall_seconds += delta
	if _contender_stall_seconds < CONTENDER_STALL_SECONDS:
		return
	if _contender_reanchor_cooldown > 0.0 or _contender_reanchors >= CONTENDER_MAX_REANCHORS:
		return
	if platform_id == &"CROWN_NEST":
		# The last visible bridge/jump should still be completed normally.
		return
	_bounded_contender_reanchor(target_index, platform_id)

func _bounded_contender_reanchor(target_index: int, platform_id: StringName) -> void:
	if _racer == null or _driver == null or _racer.is_player:
		return
	if target_index < 1 or target_index >= _route.size():
		return
	var target: Vector3 = _route[target_index] + Vector3.UP * 1.25
	_racer.reset_motion(target)
	_racer.current_speed = maxf(_racer.current_speed, _racer.cruise_speed * 0.92)
	_driver.set_race_route(_route)
	RaceManager.sync_checkpoint_from_position(_racer)
	_contender_reanchors += 1
	_contender_stall_seconds = 0.0
	_contender_reanchor_cooldown = CONTENDER_REANCHOR_COOLDOWN
	_contender_last_route_index = _driver.get_route_index()
	print("r3_ai_contender_reanchor racer=%s animal=%s platform=%s count=%d bounded_one_platform=true player=false" % [
		RaceManager.get_racer_label(_racer), String(_racer.animal_id), String(platform_id), _contender_reanchors,
	])

func _is_contender_late_target(platform_id: StringName) -> bool:
	var text: String = String(platform_id)
	return text.begins_with("Z5_") or text.begins_with("Z6_") or platform_id == &"CROWN_NEST"

func _phase_b_landing_offset(platform_id: StringName) -> Vector3:
	if _racer == null or _graph == null or _same_target_failures >= 2:
		return Vector3.ZERO
	var forward_value: Variant = _graph.call("get_platform_forward", platform_id, _route_id)
	var forward: Vector3 = forward_value if forward_value is Vector3 else Vector3.FORWARD
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	var lane_unit: float = float(_phase_b_lane_slot - 2)
	var landing_radius: float = _landing_radius(platform_id)
	var spacing: float = minf(1.10, landing_radius * PHASE_B_LANE_SPACING_RATIO)
	var offset_amount: float = clampf(lane_unit * spacing, -PHASE_B_MAX_LANE_OFFSET, PHASE_B_MAX_LANE_OFFSET)
	return right * offset_amount

func _phase_b_zone_name(platform_id: StringName) -> String:
	var text: String = String(platform_id)
	if text.begins_with("Z1_"):
		return "ZONE_1"
	if text.begins_with("Z2_"):
		return "ZONE_2"
	if text.begins_with("Z3_"):
		return "ZONE_3"
	if text.begins_with("Z4_"):
		return "ZONE_4"
	if text.begins_with("Z5_"):
		return "TITAN_TREE"
	if text.begins_with("Z6_") or platform_id == &"CROWN_NEST":
		return "FINALE"
	return "UNKNOWN"
