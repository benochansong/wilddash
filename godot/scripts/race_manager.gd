extends Node

signal race_started
signal racer_finished(racer: Node3D, rank: int)
signal race_finished(rank: int)
signal race_completed
signal checkpoint_reached(racer: Node3D, checkpoint_index: int, total: int)

const MAX_RACERS := 50
const MAX_AI_RACERS := 49
const QUALIFYING_RANK := 25
const VERTICAL_SLICE_RACERS := 4
const CHECKPOINT_ASSIST_RADIUS := 14.0
const FINISH_LATERAL_ASSIST_RADIUS := 11.0
const FINISH_CROSSING_MARGIN := 0.35

var racers: Array[Node3D] = []
var finish_order: Array[Node3D] = []
var active := false
var _race_started_at_ms := 0

var _route_points: Array[Vector3] = []
var _route_distances: Array[float] = []
var _checkpoint_positions: Array[Vector3] = []
var _checkpoint_route_distances: Array[float] = []
var _checkpoint_progress: Dictionary = {}
var _track_length := 0.0

func configure_track(route_points: Array[Vector3], checkpoint_positions: Array[Vector3]) -> void:
	_route_points.clear()
	_route_distances.clear()
	_checkpoint_positions.clear()
	_checkpoint_route_distances.clear()
	_track_length = 0.0

	for point in route_points:
		_route_points.append(point)
	for point in checkpoint_positions:
		_checkpoint_positions.append(point)

	if _route_points.is_empty():
		return
	_route_distances.append(0.0)
	for i in range(1, _route_points.size()):
		_track_length += _route_points[i - 1].distance_to(_route_points[i])
		_route_distances.append(_track_length)
	for point in _checkpoint_positions:
		_checkpoint_route_distances.append(_project_route_distance_unbounded(point))

	for racer in racers:
		_checkpoint_progress[racer.get_instance_id()] = 0
	print("RACE TRACK CONFIGURED points=%d checkpoints=%d length=%.1fm" % [_route_points.size(), _checkpoint_positions.size(), _track_length])

func clear_track() -> void:
	_route_points.clear()
	_route_distances.clear()
	_checkpoint_positions.clear()
	_checkpoint_route_distances.clear()
	_checkpoint_progress.clear()
	_track_length = 0.0

func register_racer(racer: Node3D) -> void:
	if racer == null or racers.has(racer):
		return
	racers.append(racer)
	_checkpoint_progress[racer.get_instance_id()] = 0

func unregister_racer(racer: Node3D) -> void:
	if racer == null:
		return
	racers.erase(racer)
	finish_order.erase(racer)
	_checkpoint_progress.erase(racer.get_instance_id())

func clear_racers() -> void:
	racers.clear()
	finish_order.clear()
	_checkpoint_progress.clear()

func start_race() -> void:
	finish_order.clear()
	for racer in racers:
		_checkpoint_progress[racer.get_instance_id()] = 0
	active = true
	_race_started_at_ms = Time.get_ticks_msec()
	GameManager.set_state(GameManager.GameState.RACE)
	race_started.emit()

func record_checkpoint(racer: Node3D, checkpoint_index: int) -> bool:
	if racer == null or checkpoint_index < 0 or checkpoint_index >= _checkpoint_positions.size():
		return false
	if not racers.has(racer):
		register_racer(racer)
	var id := racer.get_instance_id()
	var expected := int(_checkpoint_progress.get(id, 0))
	if checkpoint_index < expected:
		return true
	if checkpoint_index != expected:
		print("CHECKPOINT REJECTED racer=%s expected=%d got=%d" % [get_racer_label(racer), expected + 1, checkpoint_index + 1])
		return false
	_checkpoint_progress[id] = expected + 1
	checkpoint_reached.emit(racer, checkpoint_index, _checkpoint_positions.size())
	print("CHECKPOINT PASS racer=%s checkpoint=%d/%d" % [get_racer_label(racer), checkpoint_index + 1, _checkpoint_positions.size()])
	return true

func sync_checkpoint_from_position(racer: Node3D) -> bool:
	# Area3D is the primary trigger. This proximity seam makes high-speed racers
	# and low-FPS machines robust against tunneling through a thin checkpoint.
	# Only the next ordered checkpoint can be granted, so shortcuts cannot skip
	# gates or jump straight to the finish.
	if racer == null or _checkpoint_positions.is_empty():
		return false
	var expected := get_checkpoint_progress(racer)
	if expected >= _checkpoint_positions.size():
		return false
	var checkpoint := _checkpoint_positions[expected]
	var planar_delta := racer.global_position - checkpoint
	planar_delta.y = 0.0
	if planar_delta.length() > CHECKPOINT_ASSIST_RADIUS:
		return false
	var vertical_delta := absf(racer.global_position.y - checkpoint.y)
	if vertical_delta > 8.0:
		return false
	return record_checkpoint(racer, expected)

func sync_finish_from_position(racer: Node3D) -> bool:
	# Finish fallback is crossing-based, not radius-based. The old 18 m radius
	# could mark a racer finished before the visible stripe and immediately put
	# the controller into its finish coast. We now require the racer centre to
	# move beyond the finish plane while still being inside the final lane.
	if racer == null or finish_order.has(racer) or not can_finish(racer) or _route_points.size() < 2:
		return false
	var finish := _route_points[_route_points.size() - 1]
	var previous := _route_points[_route_points.size() - 2]
	var direction := finish - previous
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return false
	direction = direction.normalized()

	var planar_delta := racer.global_position - finish
	var vertical_delta := absf(planar_delta.y)
	planar_delta.y = 0.0
	if vertical_delta > 10.0:
		return false
	var forward_distance := planar_delta.dot(direction)
	if forward_distance < FINISH_CROSSING_MARGIN:
		return false
	var lateral_delta := planar_delta - direction * forward_distance
	if lateral_delta.length() > FINISH_LATERAL_ASSIST_RADIUS:
		return false
	return record_finish(racer) < MAX_RACERS

func get_checkpoint_progress(racer: Node3D) -> int:
	if racer == null:
		return 0
	return int(_checkpoint_progress.get(racer.get_instance_id(), 0))

func get_checkpoint_count() -> int:
	return _checkpoint_positions.size()

func can_finish(racer: Node3D) -> bool:
	return _checkpoint_positions.is_empty() or get_checkpoint_progress(racer) >= _checkpoint_positions.size()

func record_finish(racer: Node3D) -> int:
	if racer == null:
		return MAX_RACERS
	if not can_finish(racer):
		print("FINISH REJECTED racer=%s checkpoints=%d/%d" % [get_racer_label(racer), get_checkpoint_progress(racer), get_checkpoint_count()])
		return MAX_RACERS
	if finish_order.has(racer):
		return finish_order.find(racer) + 1
	if not racers.has(racer):
		register_racer(racer)

	finish_order.append(racer)
	var rank := finish_order.size()
	if racer is WildDashCharacterController:
		var controller := racer as WildDashCharacterController
		controller.set_finished(rank)

	racer_finished.emit(racer, rank)
	if racer is WildDashCharacterController and (racer as WildDashCharacterController).is_player:
		race_finished.emit(rank)

	if finish_order.size() >= racers.size() and not racers.is_empty():
		active = false
		race_completed.emit()
	return rank

func finish_race(player: Node3D) -> int:
	return record_finish(player)

func get_rank(racer: Node3D) -> int:
	if racer == null:
		return MAX_RACERS
	if finish_order.has(racer):
		return finish_order.find(racer) + 1

	var progress := get_track_progress(racer)
	var ahead := finish_order.size()
	for rival in racers:
		if rival == racer or finish_order.has(rival):
			continue
		if get_track_progress(rival) > progress:
			ahead += 1
	return ahead + 1

func get_standings() -> Array[Node3D]:
	var standings := racers.duplicate()
	standings.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var a_finished := finish_order.find(a)
		var b_finished := finish_order.find(b)
		if a_finished >= 0 or b_finished >= 0:
			if a_finished >= 0 and b_finished >= 0:
				return a_finished < b_finished
			return a_finished >= 0
		return get_track_progress(a) > get_track_progress(b)
	)
	return standings

func get_track_progress(racer: Node3D) -> float:
	if racer == null:
		return 0.0
	if _route_points.size() < 2:
		return -racer.global_position.z
	var raw := _project_route_distance_unbounded(racer.global_position)
	var passed := get_checkpoint_progress(racer)
	var minimum := 0.0
	if passed > 0 and passed - 1 < _checkpoint_route_distances.size():
		minimum = _checkpoint_route_distances[passed - 1]
	var maximum := _track_length
	if passed < _checkpoint_route_distances.size():
		maximum = _checkpoint_route_distances[passed]
	return clampf(raw, minimum, maximum)

func get_test_track_progress(racer: Node3D) -> float:
	# Compatibility name retained for benchmark/legacy callers. Grand Prix now
	# uses ordered checkpoints plus projected route distance.
	return get_track_progress(racer)

func get_progress_percent(racer: Node3D) -> float:
	if _track_length <= 0.01:
		return 0.0
	return clampf(get_track_progress(racer) / _track_length * 100.0, 0.0, 100.0)

func get_track_length() -> float:
	return _track_length

func get_route_points() -> Array[Vector3]:
	return _route_points.duplicate()

func get_respawn_position(racer: Node3D) -> Vector3:
	if _route_points.is_empty():
		return Vector3.ZERO
	var passed := get_checkpoint_progress(racer)
	if passed <= 0 or _checkpoint_positions.is_empty():
		return _route_points[0] + Vector3.UP * 1.6
	var checkpoint_index := mini(passed - 1, _checkpoint_positions.size() - 1)
	return _checkpoint_positions[checkpoint_index] + Vector3.UP * 1.6

func get_elapsed_seconds() -> float:
	if _race_started_at_ms <= 0:
		return 0.0
	return maxf(0.0, (Time.get_ticks_msec() - _race_started_at_ms) / 1000.0)

func get_racer_label(racer: Node3D) -> String:
	if racer is WildDashCharacterController:
		var controller := racer as WildDashCharacterController
		var label := String(controller.animal_id).capitalize()
		if controller.is_player:
			label += " (YOU)"
		return label
	return racer.name

func qualifies(rank: int) -> bool:
	return rank > 0 and rank <= QUALIFYING_RANK

func _project_route_distance_unbounded(position: Vector3) -> float:
	if _route_points.size() < 2:
		return -position.z
	var best_distance_squared := INF
	var best_route_distance := 0.0
	for i in range(_route_points.size() - 1):
		var a := _route_points[i]
		var b := _route_points[i + 1]
		var segment := b - a
		var length_squared := segment.length_squared()
		if length_squared <= 0.0001:
			continue
		var t := clampf((position - a).dot(segment) / length_squared, 0.0, 1.0)
		var closest := a + segment * t
		var distance_squared := position.distance_squared_to(closest)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_route_distance = _route_distances[i] + segment.length() * t
	return best_route_distance
