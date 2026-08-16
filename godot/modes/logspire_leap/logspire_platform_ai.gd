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
const MIN_JUMP_DISTANCE: float = 3.4
const MIN_JUMP_TRIGGER: float = 15.8
const MAX_JUMP_TRIGGER: float = 18.0
const LAND_STATE_SECONDS: float = 0.16
const JUMP_COOLDOWN_SECONDS: float = 0.28

var _racer: WildDashCharacterController
var _driver: WildDashAIController
var _route: Array[Vector3] = []
var _safe_route: Array[Vector3] = []
var _route_id: StringName = ROUTE_SAFE
var _state: JumpState = JumpState.RUN
var _jump_cooldown: float = 0.0
var _land_state_remaining: float = 0.0
var _was_on_floor: bool = false
var _recovery_count: int = 0
var _jump_count: int = 0
var _trigger_bias: float = 0.0

func configure(
	racer: WildDashCharacterController,
	driver: WildDashAIController,
	route_points: Array[Vector3],
	safe_route_points: Array[Vector3],
	route_id: StringName
) -> void:
	_racer = racer
	_driver = driver
	_route = _copy_route(route_points)
	_safe_route = _copy_route(safe_route_points)
	_route_id = route_id
	_trigger_bias = float((racer.get_instance_id() % 7) - 3) * 0.08 if racer != null else 0.0
	_was_on_floor = racer != null and racer.is_on_floor()
	print("LOGSPIRE PLATFORM AI READY racer=%s route=%s nodes=%d difficulty=%s predictive_jump=true" % [
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
	elif _land_state_remaining <= 0.0 and _state != JumpState.RECOVER:
		_state = JumpState.RUN
	_was_on_floor = on_floor

	if not on_floor or _jump_cooldown > 0.0 or _route.size() < 3:
		return

	var target_index: int = clampi(_driver.get_route_index(), 1, _route.size() - 1)
	if target_index >= _route.size() - 1:
		return
	var target: Vector3 = _route[target_index]
	var planar_delta := target - _racer.global_position
	var height_delta: float = planar_delta.y
	planar_delta.y = 0.0
	var planar_distance: float = planar_delta.length()
	var trigger_distance: float = _get_jump_trigger_distance()

	if planar_distance <= trigger_distance + 2.0 and planar_distance > trigger_distance:
		_state = JumpState.PREPARE_JUMP
	elif planar_distance > trigger_distance + 2.0:
		_state = JumpState.RUN

	if planar_distance > trigger_distance or planar_distance < MIN_JUMP_DISTANCE:
		return
	if height_delta < -4.5:
		return

	_state = JumpState.JUMP
	var jump_scale: float = _get_jump_scale(height_delta)
	_racer.velocity.y = maxf(_racer.velocity.y, _racer.jump_velocity * jump_scale)
	_racer.current_speed = maxf(_racer.current_speed, _racer.cruise_speed * 0.96)
	_jump_cooldown = JUMP_COOLDOWN_SECONDS
	_jump_count += 1
	print("LOGSPIRE JUMP AI racer=%s from_route=%d target=%d route=%s distance=%.2f height=%.2f jump_scale=%.2f" % [
		RaceManager.get_racer_label(_racer),
		maxi(0, target_index - 1),
		target_index,
		String(_route_id),
		planar_distance,
		height_delta,
		jump_scale,
	])

func notify_recovered() -> void:
	if _racer == null or _driver == null:
		return
	_recovery_count += 1
	_state = JumpState.RECOVER
	_jump_cooldown = 0.20
	if _route_id == ROUTE_WILD and _recovery_count >= 2 and _safe_route.size() >= 2:
		_route_id = ROUTE_SAFE
		_route = _copy_route(_safe_route)
		print("LOGSPIRE AI ROUTE FALLBACK racer=%s route=safe repeated_recovery=%d" % [
			RaceManager.get_racer_label(_racer), _recovery_count,
		])
	_driver.set_race_route(_route)

func get_state_name() -> String:
	return JumpState.keys()[int(_state)]

func get_route_id() -> StringName:
	return _route_id

func get_jump_count() -> int:
	return _jump_count

func get_recovery_count() -> int:
	return _recovery_count

func _get_jump_trigger_distance() -> float:
	var trigger: float = 16.35 + clampf(_racer.current_speed - 10.0, 0.0, 8.0) * 0.10 + _trigger_bias
	match GameManager.difficulty:
		&"wild":
			trigger += 0.40
		&"nightmare":
			trigger -= 0.20
		_:
			pass
	return clampf(trigger, MIN_JUMP_TRIGGER, MAX_JUMP_TRIGGER)

func _get_jump_scale(height_delta: float) -> float:
	var scale: float = 1.08
	if height_delta > 1.0:
		scale += minf(0.12, height_delta * 0.025)
	match GameManager.difficulty:
		&"wild":
			scale += 0.04
		&"nightmare":
			scale -= 0.01
		_:
			pass
	return clampf(scale, 1.04, 1.22)

func _copy_route(points: Array[Vector3]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for point: Vector3 in points:
		result.append(point)
	return result
