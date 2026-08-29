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

# Progress Cache V2. Route projection is refreshed at 20 Hz. Public getters keep
# their existing API, but cached mode turns progress/rank reads into dictionary
# lookups instead of scanning the entire route for every caller.
const PROGRESS_CACHE_INTERVAL := 0.05
const LOCAL_SEARCH_RADIUS := 7
const EXPANDED_SEARCH_RADIUS := 24
const CHECKPOINT_SEARCH_MARGIN := 3
const LOCAL_DISTANCE_LIMIT_SQ := 18.0 * 18.0
const EXPANDED_DISTANCE_LIMIT_SQ := 34.0 * 34.0
const PERF_LOG_INTERVAL := 1.0

var racers: Array[Node3D] = []
var finish_order: Array[Node3D] = []
var active := false
var _race_started_at_ms := 0

var _route_points: Array[Vector3] = []
var _route_distances: Array[float] = []
var _segment_vectors: Array[Vector3] = []
var _segment_lengths: Array[float] = []
var _segment_length_squared: Array[float] = []
var _checkpoint_positions: Array[Vector3] = []
var _checkpoint_route_distances: Array[float] = []
var _checkpoint_route_indices: Array[int] = []
var _checkpoint_progress: Dictionary = {}
var _track_length := 0.0

var _progress_cache_enabled := true
var _progress_cache: Dictionary = {}
var _segment_hint: Dictionary = {}
var _rank_cache: Dictionary = {}
var _standings_cache: Array[Node3D] = []
var _cache_elapsed := 0.0

# One-second debug counters. These deliberately stay inside RaceManager so the
# baseline/cached A/B comparison measures the same call surface.
var _perf_elapsed := 0.0
var _perf_progress_queries := 0
var _perf_rank_queries := 0
var _perf_standings_queries := 0
var _perf_projection_calls := 0
var _perf_segments_tested := 0
var _perf_projection_usec_total := 0
var _perf_projection_usec_max := 0
var _perf_cache_hits := 0
var _perf_cache_misses := 0
var _perf_local_projections := 0
var _perf_expanded_projections := 0
var _perf_checkpoint_projections := 0
var _perf_full_projections := 0
var _perf_adaptive_refreshes := 0
var _perf_cache_refresh_usec := 0
var _perf_cache_refreshes := 0

func _ready() -> void:
	_progress_cache_enabled = true
	if OS.has_environment("WILDDASH_PROGRESS_CACHE"):
		_progress_cache_enabled = _env_enabled("WILDDASH_PROGRESS_CACHE")
	print("RACE PROGRESS CACHE V2 mode=%s refresh_hz=%.1f local_radius=%d expanded_radius=%d" % [
		"cached" if _progress_cache_enabled else "legacy",
		1.0 / PROGRESS_CACHE_INTERVAL,
		LOCAL_SEARCH_RADIUS,
		EXPANDED_SEARCH_RADIUS,
	])

func _physics_process(delta: float) -> void:
	if _progress_cache_enabled and active and _route_points.size() >= 2:
		_cache_elapsed += delta
		if _cache_elapsed >= PROGRESS_CACHE_INTERVAL:
			_cache_elapsed = fmod(_cache_elapsed, PROGRESS_CACHE_INTERVAL)
			_refresh_all_progress()

	if OS.is_debug_build() or OS.has_environment("WILDDASH_PROGRESS_PERF"):
		_perf_elapsed += delta
		if _perf_elapsed >= PERF_LOG_INTERVAL:
			_emit_progress_perf()
			_reset_progress_perf_interval()

func configure_track(route_points: Array[Vector3], checkpoint_positions: Array[Vector3]) -> void:
	_route_points.clear()
	_route_distances.clear()
	_segment_vectors.clear()
	_segment_lengths.clear()
	_segment_length_squared.clear()
	_checkpoint_positions.clear()
	_checkpoint_route_distances.clear()
	_checkpoint_route_indices.clear()
	_track_length = 0.0
	_reset_progress_caches()

	for point in route_points:
		_route_points.append(point)
	for point in checkpoint_positions:
		_checkpoint_positions.append(point)

	if _route_points.is_empty():
		return

	_route_distances.append(0.0)
	for i in range(_route_points.size() - 1):
		var segment := _route_points[i + 1] - _route_points[i]
		var length_squared := segment.length_squared()
		var length := sqrt(length_squared) if length_squared > 0.0001 else 0.0
		_segment_vectors.append(segment)
		_segment_length_squared.append(length_squared)
		_segment_lengths.append(length)
		_track_length += length
		_route_distances.append(_track_length)

	# Checkpoint route locations are configured once using the precise path. They
	# are then reused for progress clamping and checkpoint-bounded fallbacks.
	for point in _checkpoint_positions:
		var projection := _project_route_distance_full(point, false)
		_checkpoint_route_distances.append(float(projection.get("progress", 0.0)))
		_checkpoint_route_indices.append(int(projection.get("segment", 0)))

	for racer in racers:
		if racer != null and is_instance_valid(racer):
			_checkpoint_progress[racer.get_instance_id()] = 0

	if _progress_cache_enabled and not racers.is_empty():
		_refresh_all_progress(true)
	print("RACE TRACK CONFIGURED points=%d segments=%d checkpoints=%d length=%.1fm progress_cache=%s" % [
		_route_points.size(), _segment_vectors.size(), _checkpoint_positions.size(), _track_length,
		str(_progress_cache_enabled),
	])

func clear_track() -> void:
	_route_points.clear()
	_route_distances.clear()
	_segment_vectors.clear()
	_segment_lengths.clear()
	_segment_length_squared.clear()
	_checkpoint_positions.clear()
	_checkpoint_route_distances.clear()
	_checkpoint_route_indices.clear()
	_checkpoint_progress.clear()
	_track_length = 0.0
	_reset_progress_caches()

func register_racer(racer: Node3D) -> void:
	if racer == null or racers.has(racer):
		return
	racers.append(racer)
	var id := racer.get_instance_id()
	_checkpoint_progress[id] = 0
	_progress_cache.erase(id)
	_segment_hint.erase(id)
	_rank_cache.erase(id)
	if _progress_cache_enabled and _route_points.size() >= 2:
		_refresh_racer_progress(racer, true)
		_rebuild_rank_and_standings()

func unregister_racer(racer: Node3D) -> void:
	if racer == null:
		return
	var id := racer.get_instance_id()
	racers.erase(racer)
	finish_order.erase(racer)
	_checkpoint_progress.erase(id)
	_progress_cache.erase(id)
	_segment_hint.erase(id)
	_rank_cache.erase(id)
	_rebuild_rank_and_standings()

func clear_racers() -> void:
	racers.clear()
	finish_order.clear()
	_checkpoint_progress.clear()
	_reset_progress_caches()

func start_race() -> void:
	finish_order.clear()
	_reset_progress_caches()
	for racer in racers:
		if racer != null and is_instance_valid(racer):
			_checkpoint_progress[racer.get_instance_id()] = 0
	active = true
	_race_started_at_ms = Time.get_ticks_msec()
	_cache_elapsed = 0.0
	if _progress_cache_enabled:
		_refresh_all_progress(true)
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
	if _progress_cache_enabled:
		# Keep the segment hint but immediately refresh the clamp bounds so ranking
		# does not wait for the next 50 ms cache tick after a checkpoint pass.
		_progress_cache.erase(id)
		_refresh_racer_progress(racer)
		_rebuild_rank_and_standings()
	checkpoint_reached.emit(racer, checkpoint_index, _checkpoint_positions.size())
	print("CHECKPOINT PASS racer=%s checkpoint=%d/%d" % [get_racer_label(racer), checkpoint_index + 1, _checkpoint_positions.size()])
	return true

func sync_checkpoint_from_position(racer: Node3D) -> bool:
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

	if _progress_cache_enabled:
		_rebuild_rank_and_standings()
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
	_perf_rank_queries += 1
	if racer == null:
		return MAX_RACERS
	if finish_order.has(racer):
		return finish_order.find(racer) + 1

	if not _progress_cache_enabled:
		return _get_rank_legacy(racer)

	var id := racer.get_instance_id()
	if not _rank_cache.has(id):
		if not _progress_cache.has(id):
			_refresh_racer_progress(racer)
		_rebuild_rank_and_standings()
	return int(_rank_cache.get(id, racers.size()))

func get_standings() -> Array[Node3D]:
	_perf_standings_queries += 1
	if not _progress_cache_enabled:
		return _get_standings_legacy()
	if _standings_cache.size() != racers.size():
		_rebuild_rank_and_standings()
	return _standings_cache.duplicate()

func get_track_progress(racer: Node3D) -> float:
	_perf_progress_queries += 1
	if racer == null:
		return 0.0
	if _route_points.size() < 2:
		return -racer.global_position.z

	if not _progress_cache_enabled:
		return _compute_precise_progress(racer, true)

	var id := racer.get_instance_id()
	if _progress_cache.has(id):
		_perf_cache_hits += 1
		return float(_progress_cache[id])

	_perf_cache_misses += 1
	return _refresh_racer_progress(racer)

func get_track_progress_precise(racer: Node3D) -> float:
	if racer == null:
		return 0.0
	if _route_points.size() < 2:
		return -racer.global_position.z
	return _compute_precise_progress(racer, true)

func get_test_track_progress(racer: Node3D) -> float:
	return get_track_progress(racer)

func get_progress_percent(racer: Node3D) -> float:
	if _track_length <= 0.01:
		return 0.0
	return clampf(get_track_progress(racer) / _track_length * 100.0, 0.0, 100.0)

func get_track_length() -> float:
	return _track_length

func get_route_points() -> Array[Vector3]:
	return _route_points.duplicate()

func get_route_point_count() -> int:
	return _route_points.size()

func get_route_point(index: int) -> Vector3:
	if index < 0 or index >= _route_points.size():
		return Vector3.ZERO
	return _route_points[index]

func get_route_segment_count() -> int:
	return _segment_vectors.size()

func get_respawn_position(racer: Node3D) -> Vector3:
	if _route_points.is_empty():
		return Vector3.ZERO
	var passed := get_checkpoint_progress(racer)
	if passed <= 0 or _checkpoint_positions.is_empty() or _checkpoint_route_distances.is_empty():
		return _route_points[0] + Vector3.UP * 1.6
	var checkpoint_index := mini(passed - 1, _checkpoint_positions.size() - 1)
	var checkpoint_distance := _checkpoint_route_distances[checkpoint_index]
	var desired_distance := checkpoint_distance + 6.0
	for i in range(_route_distances.size()):
		if _route_distances[i] >= desired_distance:
			return _route_points[i] + Vector3.UP * 1.6
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

func is_progress_cache_enabled() -> bool:
	return _progress_cache_enabled

func invalidate_racer_progress(racer: Node3D, clear_hint: bool = false) -> void:
	if racer == null:
		return
	var id := racer.get_instance_id()
	_progress_cache.erase(id)
	_rank_cache.erase(id)
	if clear_hint:
		_segment_hint.erase(id)

func get_progress_cache_debug_snapshot() -> Dictionary:
	var projections := maxi(1, _perf_projection_calls)
	return {
		"mode": "cached" if _progress_cache_enabled else "legacy",
		"racers": racers.size(),
		"route_segments": _segment_vectors.size(),
		"progress_queries": _perf_progress_queries,
		"rank_queries": _perf_rank_queries,
		"standings_queries": _perf_standings_queries,
		"cache_hits": _perf_cache_hits,
		"cache_misses": _perf_cache_misses,
		"projection_calls": _perf_projection_calls,
		"segments_tested": _perf_segments_tested,
		"avg_segments_per_projection": float(_perf_segments_tested) / float(projections),
		"local_projections": _perf_local_projections,
		"expanded_projections": _perf_expanded_projections,
		"checkpoint_projections": _perf_checkpoint_projections,
		"full_projections": _perf_full_projections,
		"projection_usec": _perf_projection_usec_total,
		"projection_usec_max": _perf_projection_usec_max,
		"cache_refresh_usec": _perf_cache_refresh_usec,
		"cache_refreshes": _perf_cache_refreshes,
	}

func _refresh_all_progress(force_full: bool = false) -> void:
	if _route_points.size() < 2:
		return
	var started_usec := Time.get_ticks_usec()
	for racer in racers:
		if racer == null or not is_instance_valid(racer) or finish_order.has(racer):
			continue
		_refresh_racer_progress(racer, force_full)
	_rebuild_rank_and_standings()
	_perf_cache_refresh_usec += maxi(0, Time.get_ticks_usec() - started_usec)
	_perf_cache_refreshes += 1

func _refresh_racer_progress(racer: Node3D, force_full: bool = false) -> float:
	if racer == null or not is_instance_valid(racer):
		return 0.0
	if _route_points.size() < 2:
		return -racer.global_position.z

	var id := racer.get_instance_id()
	var projection: Dictionary
	if force_full or not _segment_hint.has(id):
		projection = _project_route_distance_full(racer.global_position)
	else:
		projection = _project_route_distance_adaptive(racer)
	var raw := float(projection.get("progress", 0.0))
	var segment_index := int(projection.get("segment", 0))
	var clamped := _clamp_progress_for_checkpoint(racer, raw)
	_progress_cache[id] = clamped
	_segment_hint[id] = segment_index
	return clamped

func _project_route_distance_adaptive(racer: Node3D) -> Dictionary:
	_perf_adaptive_refreshes += 1
	var id := racer.get_instance_id()
	var hint := clampi(int(_segment_hint.get(id, 0)), 0, maxi(0, _segment_vectors.size() - 1))
	var local_min := maxi(0, hint - LOCAL_SEARCH_RADIUS)
	var local_max := mini(_segment_vectors.size() - 1, hint + LOCAL_SEARCH_RADIUS)
	var result := _project_route_distance_range(racer.global_position, local_min, local_max, &"local")
	if not _projection_is_suspicious(result, local_min, local_max, LOCAL_DISTANCE_LIMIT_SQ):
		return result

	var expanded_min := maxi(0, hint - EXPANDED_SEARCH_RADIUS)
	var expanded_max := mini(_segment_vectors.size() - 1, hint + EXPANDED_SEARCH_RADIUS)
	result = _project_route_distance_range(racer.global_position, expanded_min, expanded_max, &"expanded")
	if not _projection_is_suspicious(result, expanded_min, expanded_max, EXPANDED_DISTANCE_LIMIT_SQ):
		return result

	var bounds := _checkpoint_search_bounds(racer)
	if bounds.x >= 0 and bounds.y >= bounds.x:
		result = _project_route_distance_range(racer.global_position, bounds.x, bounds.y, &"checkpoint")
		if not _projection_is_suspicious(result, bounds.x, bounds.y, EXPANDED_DISTANCE_LIMIT_SQ):
			return result

	return _project_route_distance_full(racer.global_position)

func _checkpoint_search_bounds(racer: Node3D) -> Vector2i:
	if _segment_vectors.is_empty() or _checkpoint_route_indices.is_empty():
		return Vector2i(-1, -1)
	var passed := get_checkpoint_progress(racer)
	var min_segment := 0
	var max_segment := _segment_vectors.size() - 1
	if passed > 0:
		var previous_cp := mini(passed - 1, _checkpoint_route_indices.size() - 1)
		min_segment = maxi(0, _checkpoint_route_indices[previous_cp] - CHECKPOINT_SEARCH_MARGIN)
	if passed < _checkpoint_route_indices.size():
		max_segment = mini(_segment_vectors.size() - 1, _checkpoint_route_indices[passed] + CHECKPOINT_SEARCH_MARGIN)
	return Vector2i(min_segment, max_segment)

func _project_route_distance_full(position: Vector3, count_metrics: bool = true) -> Dictionary:
	if _segment_vectors.is_empty():
		return {"progress": -position.z, "segment": 0, "distance_squared": 0.0}
	return _project_route_distance_range(position, 0, _segment_vectors.size() - 1, &"full", count_metrics)

func _project_route_distance_range(
	position: Vector3,
	min_segment: int,
	max_segment: int,
	kind: StringName,
	count_metrics: bool = true
) -> Dictionary:
	if _segment_vectors.is_empty():
		return {"progress": -position.z, "segment": 0, "distance_squared": 0.0}

	var first := clampi(min_segment, 0, _segment_vectors.size() - 1)
	var last := clampi(max_segment, first, _segment_vectors.size() - 1)
	var started_usec := Time.get_ticks_usec() if count_metrics else 0
	var best_distance_squared := INF
	var best_route_distance := 0.0
	var best_segment := first
	var tested := 0

	for i in range(first, last + 1):
		var length_squared := _segment_length_squared[i]
		if length_squared <= 0.0001:
			continue
		tested += 1
		var a := _route_points[i]
		var segment := _segment_vectors[i]
		var t := clampf((position - a).dot(segment) / length_squared, 0.0, 1.0)
		var closest := a + segment * t
		var distance_squared := position.distance_squared_to(closest)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_segment = i
			best_route_distance = _route_distances[i] + _segment_lengths[i] * t

	if count_metrics:
		var elapsed_usec := maxi(0, Time.get_ticks_usec() - started_usec)
		_perf_projection_calls += 1
		_perf_segments_tested += tested
		_perf_projection_usec_total += elapsed_usec
		_perf_projection_usec_max = maxi(_perf_projection_usec_max, elapsed_usec)
		match kind:
			&"local": _perf_local_projections += 1
			&"expanded": _perf_expanded_projections += 1
			&"checkpoint": _perf_checkpoint_projections += 1
			_: _perf_full_projections += 1

	return {
		"progress": best_route_distance,
		"segment": best_segment,
		"distance_squared": best_distance_squared,
	}

func _projection_is_suspicious(result: Dictionary, min_segment: int, max_segment: int, distance_limit_sq: float) -> bool:
	var segment := int(result.get("segment", min_segment))
	var distance_squared := float(result.get("distance_squared", INF))
	var touches_window_edge := segment == min_segment or segment == max_segment
	return touches_window_edge or distance_squared > distance_limit_sq

func _compute_precise_progress(racer: Node3D, count_metrics: bool) -> float:
	var result := _project_route_distance_full(racer.global_position, count_metrics)
	return _clamp_progress_for_checkpoint(racer, float(result.get("progress", 0.0)))

func _clamp_progress_for_checkpoint(racer: Node3D, raw: float) -> float:
	var passed := get_checkpoint_progress(racer)
	var minimum := 0.0
	if passed > 0 and passed - 1 < _checkpoint_route_distances.size():
		minimum = _checkpoint_route_distances[passed - 1]
	var maximum := _track_length
	if passed < _checkpoint_route_distances.size():
		maximum = _checkpoint_route_distances[passed]
	return clampf(raw, minimum, maximum)

func _get_rank_legacy(racer: Node3D) -> int:
	var progress := get_track_progress(racer)
	var ahead := finish_order.size()
	for rival in racers:
		if rival == racer or finish_order.has(rival):
			continue
		if get_track_progress(rival) > progress:
			ahead += 1
	return ahead + 1

func _get_standings_legacy() -> Array[Node3D]:
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

func _rebuild_rank_and_standings() -> void:
	_rank_cache.clear()
	_standings_cache.clear()

	for finished in finish_order:
		if finished != null and is_instance_valid(finished):
			_standings_cache.append(finished)

	var unfinished: Array[Node3D] = []
	for racer in racers:
		if racer == null or not is_instance_valid(racer) or finish_order.has(racer):
			continue
		var id := racer.get_instance_id()
		if not _progress_cache.has(id):
			_refresh_racer_progress(racer)
		unfinished.append(racer)

	# Preserve legacy tie semantics: only strictly-greater progress counts ahead,
	# so racers tied at the same snapshot receive the same rank.
	for racer in unfinished:
		var racer_id := racer.get_instance_id()
		var progress := float(_progress_cache.get(racer_id, 0.0))
		var ahead := finish_order.size()
		for rival in unfinished:
			if rival == racer:
				continue
			if float(_progress_cache.get(rival.get_instance_id(), 0.0)) > progress:
				ahead += 1
		_rank_cache[racer_id] = ahead + 1

	unfinished.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var a_progress := float(_progress_cache.get(a.get_instance_id(), 0.0))
		var b_progress := float(_progress_cache.get(b.get_instance_id(), 0.0))
		if is_equal_approx(a_progress, b_progress):
			return racers.find(a) < racers.find(b)
		return a_progress > b_progress
	)
	for racer in unfinished:
		_standings_cache.append(racer)

func _reset_progress_caches() -> void:
	_progress_cache.clear()
	_segment_hint.clear()
	_rank_cache.clear()
	_standings_cache.clear()
	_cache_elapsed = 0.0

func _emit_progress_perf() -> void:
	var seconds := maxf(0.001, _perf_elapsed)
	var projection_calls := maxi(1, _perf_projection_calls)
	var adaptive := maxi(1, _perf_adaptive_refreshes)
	var fallback_ratio := float(_perf_full_projections) / float(adaptive) * 100.0 if _progress_cache_enabled else 100.0
	var label := "RACE PROGRESS CACHE PERF" if _progress_cache_enabled else "RACE PROGRESS PERF BASELINE"
	print("%s mode=%s racers=%d route_segments=%d progress_queries=%d rank_queries=%d standings_queries=%d cache_hits=%d cache_misses=%d projection_calls=%d local=%d expanded=%d checkpoint=%d full=%d segments_tested=%d segment_tests_per_sec=%.0f avg_segments_per_projection=%.2f projection_ms_per_sec=%.3f projection_usec_max=%d cache_refresh_ms=%.3f cache_refreshes=%d fallback_ratio=%.2f%%" % [
		label,
		"cached" if _progress_cache_enabled else "legacy",
		racers.size(),
		_segment_vectors.size(),
		_perf_progress_queries,
		_perf_rank_queries,
		_perf_standings_queries,
		_perf_cache_hits,
		_perf_cache_misses,
		_perf_projection_calls,
		_perf_local_projections,
		_perf_expanded_projections,
		_perf_checkpoint_projections,
		_perf_full_projections,
		_perf_segments_tested,
		float(_perf_segments_tested) / seconds,
		float(_perf_segments_tested) / float(projection_calls),
		float(_perf_projection_usec_total) / 1000.0 / seconds,
		_perf_projection_usec_max,
		float(_perf_cache_refresh_usec) / 1000.0,
		_perf_cache_refreshes,
		fallback_ratio,
	])

func _reset_progress_perf_interval() -> void:
	_perf_elapsed = 0.0
	_perf_progress_queries = 0
	_perf_rank_queries = 0
	_perf_standings_queries = 0
	_perf_projection_calls = 0
	_perf_segments_tested = 0
	_perf_projection_usec_total = 0
	_perf_projection_usec_max = 0
	_perf_cache_hits = 0
	_perf_cache_misses = 0
	_perf_local_projections = 0
	_perf_expanded_projections = 0
	_perf_checkpoint_projections = 0
	_perf_full_projections = 0
	_perf_adaptive_refreshes = 0
	_perf_cache_refresh_usec = 0
	_perf_cache_refreshes = 0

func _env_enabled(name: String) -> bool:
	if not OS.has_environment(name):
		return false
	var value := OS.get_environment(name).strip_edges().to_lower()
	return value == "1" or value == "true" or value == "yes" or value == "on"
