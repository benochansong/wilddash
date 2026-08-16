extends Node

enum JumpState {
	RUN,
	PREPARE_JUMP,
	JUMP,
	AIRBORNE,
	LAND,
	RECOVER,
}

const ROUTE_SAFE: StringName = &"safe"
const ROUTE_WILD: StringName = &"wild"
const MIN_JUMP_DISTANCE: float = 3.2
const MIN_JUMP_TRIGGER: float = 15.5
const MAX_JUMP_TRIGGER: float = 19.2
const LAND_STATE_SECONDS: float = 0.18
const JUMP_COOLDOWN_SECONDS: float = 0.28
const SAFE_TARGET_AFTER_FAILURES: int = 2
const ROUTE_FALLBACK_AFTER_FAILURES: int = 3

var _racer: WildDashCharacterController
var _driver: WildDashAIController
var _graph: Node
var _gameplay: Node
var _route: Array[Vector3] = []
var _safe_route: Array[Vector3] = []
var _route_ids: Array[StringName] = []
var _safe_route_ids: Array[StringName] = []
var _route_id: StringName = ROUTE_SAFE
var _state: JumpState = JumpState.RUN
var _jump_cooldown: float = 0.0
var _land_state_remaining: float = 0.0
var _was_on_floor: bool = false
var _recovery_count: int = 0
var _jump_count: int = 0
var _trigger_bias: float = 0.0
var _last_failed_target: int = -1
var _same_target_failures: int = 0
var _safer_landing_mode: bool = false
var _last_landed_route_index: int = 0

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
	_racer = racer
	_driver = driver
	_graph = graph
	_gameplay = gameplay
	_route = _copy_route(route_points)
	_safe_route = _copy_route(safe_route_points)
	_route_ids = _copy_ids(route_platform_ids)
	_safe_route_ids = _copy_ids(safe_platform_ids)
	_route_id = route_id
	_trigger_bias = float((racer.get_instance_id() % 7) - 3) * 0.08 if racer != null else 0.0
	_was_on_floor = racer != null and racer.is_on_floor()
	print("LOGSPIRE PLATFORM AI V2 READY racer=%s route=%s nodes=%d difficulty=%s moving_prediction=true failure_counter=true" % [
		RaceManager.get_racer_label(racer),
		String(_route_id),
		_route.size(),
		String(GameManager.difficulty),
	])

func _physics_process(delta: float) -> void:
	_jump_cooldown = maxf(0.0, _jump_cooldown - delta)
	_land_state_remaining = maxf(0.0, _land_state_remaining - delta)
	if _racer == null or _driver == null or _racer.finished or not RaceManager.active:
		return

	var on_floor: bool = _racer.is_on_floor()
	if not on_floor:
		_state = JumpState.AIRBORNE
	elif not _was_on_floor:
		_state = JumpState.LAND
		_land_state_remaining = LAND_STATE_SECONDS
		_on_successful_landing()
	elif _land_state_remaining <= 0.0 and _state != JumpState.RECOVER:
		_state = JumpState.RUN
	_was_on_floor = on_floor

	if not on_floor or _jump_cooldown > 0.0 or _route.size() < 3:
		return

	var target_index: int = clampi(_driver.get_route_index(), 1, _route.size() - 1)
	if target_index >= _route.size() - 1:
		return
	var static_target: Vector3 = _route[target_index]
	var initial_delta := static_target - _racer.global_position
	initial_delta.y = 0.0
	var initial_distance: float = initial_delta.length()
	var travel_time: float = initial_distance / maxf(6.0, _racer.current_speed)
	var platform_id: StringName = _platform_id_for_index(target_index)
	var target: Vector3 = _predicted_target(platform_id, static_target, travel_time)
	var target_velocity: Vector3 = _platform_velocity(platform_id)
	var landing_radius: float = _landing_radius(platform_id)
	var risk: float = _platform_risk(platform_id)

	if _safer_landing_mode and target_velocity.length() > 0.01:
		target -= target_velocity * minf(0.30, travel_time * 0.18)

	var planar_delta := target - _racer.global_position
	var height_delta: float = planar_delta.y
	planar_delta.y = 0.0
	var planar_distance: float = planar_delta.length()
	var trigger_distance: float = _get_jump_trigger_distance(risk, landing_radius, target_velocity.length())

	if planar_distance <= trigger_distance + 2.6 and planar_distance > trigger_distance:
		_state = JumpState.PREPARE_JUMP
		_face_target(target)
	elif planar_distance > trigger_distance + 2.6:
		_state = JumpState.RUN

	if planar_distance > trigger_distance or planar_distance < MIN_JUMP_DISTANCE:
		return
	if height_delta < -5.0:
		return

	_state = JumpState.JUMP
	_face_target(target)
	var jump_scale: float = _get_jump_scale(height_delta, risk, target_velocity.length())
	_racer.velocity.y = maxf(_racer.velocity.y, _racer.jump_velocity * jump_scale)
	_racer.current_speed = maxf(_racer.current_speed, _racer.cruise_speed * (1.00 if _safer_landing_mode else 0.96))
	_jump_cooldown = JUMP_COOLDOWN_SECONDS
	_jump_count += 1
	print("LOGSPIRE JUMP AI racer=%s from=%d target=%d platform=%s route=%s distance=%.2f height=%.2f radius=%.2f risk=%.2f moving=%.2f safer=%s" % [
		RaceManager.get_racer_label(_racer),
		maxi(0, target_index - 1),
		target_index,
		String(platform_id),
		String(_route_id),
		planar_distance,
		height_delta,
		landing_radius,
		risk,
		target_velocity.length(),
		str(_safer_landing_mode),
	])

func notify_recovered() -> void:
	if _racer == null or _driver == null:
		return
	_recovery_count += 1
	_state = JumpState.RECOVER
	_jump_cooldown = 0.18
	var failed_target: int = clampi(_driver.get_route_index(), 1, maxi(1, _route.size() - 1))
	if failed_target == _last_failed_target:
		_same_target_failures += 1
	else:
		_last_failed_target = failed_target
		_same_target_failures = 1

	_safer_landing_mode = _same_target_failures >= SAFE_TARGET_AFTER_FAILURES
	print("LOGSPIRE AI RECOVERY racer=%s route=%s target=%d same_target_failures=%d safer_landing=%s" % [
		RaceManager.get_racer_label(_racer), String(_route_id), failed_target, _same_target_failures, str(_safer_landing_mode),
	])

	if _same_target_failures >= ROUTE_FALLBACK_AFTER_FAILURES and _safe_route.size() >= 2:
		if _route_id != ROUTE_SAFE:
			_route_id = ROUTE_SAFE
			_route = _copy_route(_safe_route)
			_route_ids = _copy_ids(_safe_route_ids)
			print("LOGSPIRE AI ROUTE racer=%s difficulty=%s route=safe reason=repeated_failure failures=%d" % [
				RaceManager.get_racer_label(_racer), String(GameManager.difficulty), _same_target_failures,
			])
		_driver.set_race_route(_route)
		_same_target_failures = 0
		_last_failed_target = -1
		_safer_landing_mode = true
	else:
		_driver.set_race_route(_route)

func get_state_name() -> String:
	return JumpState.keys()[int(_state)]

func get_route_id() -> StringName:
	return _route_id

func get_jump_count() -> int:
	return _jump_count

func get_recovery_count() -> int:
	return _recovery_count

func get_same_target_failures() -> int:
	return _same_target_failures

func _on_successful_landing() -> void:
	if _driver == null:
		return
	var route_index: int = _driver.get_route_index()
	if route_index > _last_landed_route_index:
		_last_landed_route_index = route_index
		if _last_failed_target >= 0 and route_index > _last_failed_target:
			_last_failed_target = -1
			_same_target_failures = 0
			_safer_landing_mode = false

func _get_jump_trigger_distance(risk: float, landing_radius: float, moving_speed: float) -> float:
	var trigger: float = 16.20 + clampf(_racer.current_speed - 10.0, 0.0, 9.0) * 0.11 + _trigger_bias
	trigger += clampf(moving_speed * 0.08, 0.0, 0.65)
	trigger += clampf(risk * 0.60, 0.0, 0.55)
	if landing_radius < 4.0:
		trigger += 0.35
	if _safer_landing_mode:
		trigger += 0.75
	match GameManager.difficulty:
		&"wild":
			trigger += 0.45
		&"nightmare":
			trigger -= 0.18
		_:
			pass
	return clampf(trigger, MIN_JUMP_TRIGGER, MAX_JUMP_TRIGGER)

func _get_jump_scale(height_delta: float, risk: float, moving_speed: float) -> float:
	var scale: float = 1.07
	if height_delta > 0.8:
		scale += minf(0.13, height_delta * 0.025)
	scale += minf(0.05, moving_speed * 0.01)
	scale += minf(0.035, risk * 0.04)
	if _safer_landing_mode:
		scale += 0.045
	match GameManager.difficulty:
		&"wild":
			scale += 0.04
		&"nightmare":
			scale -= 0.015
		_:
			pass
	return clampf(scale, 1.03, 1.24)

func _platform_id_for_index(index: int) -> StringName:
	if index < 0 or index >= _route_ids.size():
		return &""
	return _route_ids[index]

func _predicted_target(platform_id: StringName, fallback: Vector3, travel_time: float) -> Vector3:
	if platform_id == &"" or _gameplay == null or not _gameplay.has_method("predict_landing"):
		return fallback
	var value: Variant = _gameplay.call("predict_landing", platform_id, travel_time)
	return value if value is Vector3 else fallback

func _platform_velocity(platform_id: StringName) -> Vector3:
	if platform_id == &"" or _gameplay == null or not _gameplay.has_method("get_platform_velocity"):
		return Vector3.ZERO
	var value: Variant = _gameplay.call("get_platform_velocity", platform_id)
	return value if value is Vector3 else Vector3.ZERO

func _landing_radius(platform_id: StringName) -> float:
	if platform_id == &"" or _graph == null:
		return 4.0
	return float(_graph.call("get_landing_radius", platform_id))

func _platform_risk(platform_id: StringName) -> float:
	if platform_id == &"" or _graph == null:
		return 0.0
	return float(_graph.call("get_risk", platform_id))

func _face_target(target: Vector3) -> void:
	if _racer == null:
		return
	var direction := target - _racer.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	direction = direction.normalized()
	_racer.rotation.y = lerp_angle(_racer.rotation.y, atan2(-direction.x, -direction.z), 0.42)

func _copy_route(points: Array[Vector3]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for point: Vector3 in points:
		result.append(point)
	return result

func _copy_ids(ids: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for platform_id: StringName in ids:
		result.append(platform_id)
	return result
