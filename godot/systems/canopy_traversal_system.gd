class_name WildDashCanopyTraversalSystem
extends RefCounted

## Arc-based fake swing used by Monkey. This deliberately avoids rope joints and
## RigidBody feedback loops: the route is deterministic, visually readable and
## can later be driven from authoritative network state using progress + speed.
## While attached, this controller temporarily owns the racer's physics tick so
## CharacterBody arena movement cannot overwrite the deterministic swing path.

const DEFAULT_GRAB_DISTANCE: float = 3.4
const MIN_SWING_SPEED: float = 4.2
const SWING_ACCELERATION: float = 9.0
const INPUT_SPEED_BONUS: float = 1.8

var _routes: Array[WildDashCanopyVineRoute] = []
var _active_route: WildDashCanopyVineRoute
var _progress: float = 0.0
var _direction: float = 1.0
var _speed: float = MIN_SWING_SPEED
var _speed_ratio: float = 0.0

func set_routes(routes: Array[WildDashCanopyVineRoute]) -> void:
	_routes = routes.duplicate()
	if _active_route != null and not _routes.has(_active_route):
		_reset_state()

func get_routes() -> Array[WildDashCanopyVineRoute]:
	return _routes.duplicate()

func is_swinging() -> bool:
	return _active_route != null and _active_route.enabled

func get_active_vine_id() -> StringName:
	return &"" if _active_route == null else _active_route.vine_id

func find_nearest_vine(position: Vector3, max_distance: float = DEFAULT_GRAB_DISTANCE) -> WildDashCanopyVineRoute:
	var best: WildDashCanopyVineRoute
	var best_distance: float = max_distance
	for route: WildDashCanopyVineRoute in _routes:
		if route == null or not route.enabled:
			continue
		var distance: float = _nearest_curve_distance(route, position)
		if distance <= best_distance:
			best_distance = distance
			best = route
	return best

func can_grab_vine(
	racer: WildDashCharacterController,
	route: WildDashCanopyVineRoute,
	max_distance: float = DEFAULT_GRAB_DISTANCE
) -> bool:
	if racer == null or route == null or not route.enabled:
		return false
	if racer.animal_id != &"monkey":
		return false
	return _nearest_curve_distance(route, racer.global_position) <= max_distance

func grab_vine(racer: WildDashCharacterController, route: WildDashCanopyVineRoute) -> bool:
	if not can_grab_vine(racer, route):
		return false
	_active_route = route
	_progress = _nearest_progress(route, racer.global_position)
	var route_direction: Vector3 = route.end_position - route.start_position
	route_direction.y = 0.0
	var planar_velocity: Vector3 = Vector3(racer.velocity.x, 0.0, racer.velocity.z)
	if route_direction.length_squared() > 0.001 and planar_velocity.length_squared() > 0.25:
		_direction = 1.0 if planar_velocity.normalized().dot(route_direction.normalized()) >= 0.0 else -1.0
	else:
		_direction = 1.0 if _progress <= 0.5 else -1.0
	var inherited_speed: float = planar_velocity.length()
	_speed = clampf(maxf(MIN_SWING_SPEED, inherited_speed), MIN_SWING_SPEED, route.max_swing_speed)
	_speed_ratio = clampf(_speed / route.max_swing_speed, 0.0, 1.0)
	racer.set_physics_process(false)
	racer.global_position = route.sample(_progress)
	racer.velocity = route.tangent(_progress) * _direction * _speed
	return true

func update_swing(racer: WildDashCharacterController, delta: float, input_axis: float) -> bool:
	if racer == null:
		_reset_state()
		return true
	if _active_route == null or not _active_route.enabled:
		cancel_vine(racer)
		return true
	var route_length: float = _active_route.approximate_length()
	var center_pull: float = sin(clampf(_progress, 0.0, 1.0) * PI)
	var target_speed: float = _active_route.max_swing_speed * lerpf(0.72, 1.0, center_pull)
	target_speed += absf(input_axis) * INPUT_SPEED_BONUS
	_speed = move_toward(_speed, target_speed, SWING_ACCELERATION * delta)
	_speed = clampf(_speed, MIN_SWING_SPEED, _active_route.max_swing_speed + INPUT_SPEED_BONUS)
	var progress_step: float = (_speed / route_length) * delta * _direction
	_progress += progress_step
	var reached_end: bool = _progress <= 0.0 or _progress >= 1.0
	_progress = clampf(_progress, 0.0, 1.0)
	_speed_ratio = clampf(_speed / maxf(0.1, _active_route.max_swing_speed), 0.0, 1.0)
	var tangent: Vector3 = _active_route.tangent(_progress) * _direction
	racer.global_position = _active_route.sample(_progress)
	racer.velocity = tangent * _speed
	return reached_end

func release_vine(racer: WildDashCharacterController, jump_release: bool = true) -> Vector3:
	if racer == null or _active_route == null:
		if racer != null:
			racer.set_physics_process(true)
		_reset_state()
		return Vector3.ZERO
	var tangent: Vector3 = _active_route.tangent(_progress) * _direction
	var release_velocity: Vector3 = tangent * maxf(_speed, MIN_SWING_SPEED)
	if jump_release:
		release_velocity += Vector3.UP * _active_route.release_boost
	racer.set_physics_process(true)
	_reset_state()
	return release_velocity

func cancel_vine(racer: WildDashCharacterController) -> void:
	if racer != null:
		racer.set_physics_process(true)
	_reset_state()

func get_swing_speed_ratio() -> float:
	return _speed_ratio

func calculate_swing_velocity() -> Vector3:
	if _active_route == null:
		return Vector3.ZERO
	return _active_route.tangent(_progress) * _direction * _speed

func perform_swing_attack() -> float:
	return lerpf(0.75, 1.35, clampf(_speed_ratio, 0.0, 1.0))

func clear_active_vine() -> void:
	## State-only reset for tests/non-character setup. Runtime mode code should use
	## cancel_vine(racer) so the CharacterBody physics callback is restored.
	_reset_state()

func _reset_state() -> void:
	_active_route = null
	_progress = 0.0
	_direction = 1.0
	_speed = MIN_SWING_SPEED
	_speed_ratio = 0.0

func _nearest_curve_distance(route: WildDashCanopyVineRoute, position: Vector3) -> float:
	var best: float = INF
	for i: int in range(13):
		var point: Vector3 = route.sample(float(i) / 12.0)
		best = minf(best, point.distance_to(position))
	return best

func _nearest_progress(route: WildDashCanopyVineRoute, position: Vector3) -> float:
	var best_progress: float = 0.0
	var best_distance: float = INF
	for i: int in range(25):
		var progress: float = float(i) / 24.0
		var distance: float = route.sample(progress).distance_squared_to(position)
		if distance < best_distance:
			best_distance = distance
			best_progress = progress
	return best_progress
