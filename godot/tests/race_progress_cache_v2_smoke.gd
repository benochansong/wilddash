extends SceneTree

const MAX_PROGRESS_ERROR := 0.25
const MAX_AVG_SEGMENTS := 20.0

func _init() -> void:
	var failures: Array[String] = []
	if not RaceManager.is_progress_cache_enabled():
		failures.append("Progress Cache V2 must be enabled by default for the production path")

	var bundle: Dictionary = WildDashGrandPrixV2Layout.build_route_bundle()
	var points: Array[Vector3] = bundle["points"]
	if points.size() < 200:
		failures.append("Grand Prix V2 route fixture is unexpectedly small")
		_finish(failures)
		return

	RaceManager.clear_racers()
	RaceManager.clear_track()
	# Precision/local-search tests intentionally omit checkpoints so the raw route
	# projection can be compared directly without checkpoint clamping hiding error.
	RaceManager.configure_track(points, [])

	var probe := Node3D.new()
	probe.name = "ProgressCacheProbe"
	root.add_child(probe)
	RaceManager.register_racer(probe)

	var sample_count := 0
	var max_error := 0.0
	for point_index in range(1, points.size() - 1, 6):
		var tangent := points[point_index + 1] - points[point_index - 1]
		tangent.y = 0.0
		if tangent.length_squared() <= 0.001:
			tangent = Vector3.FORWARD
		else:
			tangent = tangent.normalized()
		var right := Vector3(-tangent.z, 0.0, tangent.x)
		for lateral in [-2.0, 0.0, 2.0]:
			probe.global_position = points[point_index] + right * lateral
			RaceManager.invalidate_racer_progress(probe, false)
			var cached := RaceManager.get_track_progress(probe)
			var precise := RaceManager.get_track_progress_precise(probe)
			var error := absf(cached - precise)
			max_error = maxf(max_error, error)
			sample_count += 1
			if error > MAX_PROGRESS_ERROR:
				failures.append("precision mismatch index=%d lateral=%.1f cached=%.3f precise=%.3f error=%.3f" % [
					point_index, lateral, cached, precise, error,
				])
				break
		if not failures.is_empty():
			break

	if sample_count < 100:
		failures.append("precision regression must sample at least 100 positions")

	# Teleport recovery: retain an intentionally stale hint and make sure adaptive
	# fallback recovers to the precise route position.
	probe.global_position = points[12]
	RaceManager.invalidate_racer_progress(probe, true)
	RaceManager.get_track_progress(probe)
	probe.global_position = points[220]
	RaceManager.invalidate_racer_progress(probe, false)
	var teleport_cached := RaceManager.get_track_progress(probe)
	var teleport_precise := RaceManager.get_track_progress_precise(probe)
	if absf(teleport_cached - teleport_precise) > MAX_PROGRESS_ERROR:
		failures.append("teleport fallback failed cached=%.3f precise=%.3f" % [teleport_cached, teleport_precise])

	# Backtracking must remain legal. Progress is not forced monotonic; the existing
	# checkpoint clamp remains the only monotonic race-rule boundary.
	probe.global_position = points[160]
	RaceManager.invalidate_racer_progress(probe, true)
	var forward_progress := RaceManager.get_track_progress(probe)
	probe.global_position = points[157]
	RaceManager.invalidate_racer_progress(probe, false)
	var backtrack_progress := RaceManager.get_track_progress(probe)
	if backtrack_progress >= forward_progress:
		failures.append("local cache incorrectly forced progress monotonic during backtrack")

	RaceManager.unregister_racer(probe)
	probe.queue_free()

	# Ranking parity across a 15-racer snapshot.
	var racers: Array[Node3D] = []
	for i in range(15):
		var racer := Node3D.new()
		racer.name = "RankProbe_%02d" % i
		root.add_child(racer)
		RaceManager.register_racer(racer)
		var route_index := clampi(12 + i * 16, 1, points.size() - 2)
		racer.global_position = points[route_index]
		RaceManager.invalidate_racer_progress(racer, true)
		racers.append(racer)
	RaceManager.call("_refresh_all_progress", true)

	var precise_progress: Dictionary = {}
	for racer in racers:
		precise_progress[racer.get_instance_id()] = RaceManager.get_track_progress_precise(racer)
	for racer in racers:
		var own := float(precise_progress[racer.get_instance_id()])
		var expected_rank := 1
		for rival in racers:
			if rival == racer:
				continue
			if float(precise_progress[rival.get_instance_id()]) > own:
				expected_rank += 1
		var cached_rank := RaceManager.get_rank(racer)
		if cached_rank != expected_rank:
			failures.append("rank parity failed racer=%s expected=%d cached=%d" % [racer.name, expected_rank, cached_rank])
			break

	# Complexity budget after warm-up: move every racer one nearby sample and run
	# one cache refresh. The hot path should stay inside the +/-7 local window.
	RaceManager.call("_reset_progress_perf_interval")
	for i in range(racers.size()):
		var route_index := clampi(13 + i * 16, 1, points.size() - 2)
		racers[i].global_position = points[route_index]
	RaceManager.call("_refresh_all_progress")
	var perf := RaceManager.get_progress_cache_debug_snapshot()
	var avg_segments := float(perf.get("avg_segments_per_projection", 999.0))
	var full_projections := int(perf.get("full_projections", 999))
	if avg_segments > MAX_AVG_SEGMENTS:
		failures.append("local projection budget exceeded avg_segments=%.2f" % avg_segments)
	if full_projections > 1:
		failures.append("warm local refresh unexpectedly used %d full projections" % full_projections)

	for racer in racers:
		RaceManager.unregister_racer(racer)
		racer.queue_free()
	RaceManager.clear_racers()
	RaceManager.clear_track()

	if failures.is_empty():
		print("RACE PROGRESS CACHE V2 PASS samples=%d max_error=%.4fm rank_racers=%d avg_segments=%.2f full_fallbacks=%d" % [
			sample_count, max_error, racers.size(), avg_segments, full_projections,
		])
	_finish(failures)

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		quit(0)
		return
	for failure in failures:
		push_error("RACE PROGRESS CACHE V2 FAIL: %s" % failure)
	quit(1)
