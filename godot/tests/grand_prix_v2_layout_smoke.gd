extends SceneTree

func _init() -> void:
	var failures: Array[String] = []
	var sections: Array[WildDashGrandPrixV2Section] = WildDashGrandPrixV2Layout.build_sections()
	var bundle: Dictionary = WildDashGrandPrixV2Layout.build_route_bundle()
	var points: Array[Vector3] = bundle["points"]
	var widths: Array[float] = bundle["segment_widths"]
	var section_ids: Array[StringName] = bundle["segment_sections"]
	var ranges: Dictionary = bundle["section_ranges"]
	var checkpoints: Array[Vector3] = WildDashGrandPrixV2Layout.build_checkpoint_positions(bundle)
	var length := WildDashGrandPrixV2Layout.get_total_length(bundle)
	var elevation := WildDashGrandPrixV2Layout.get_elevation_range(bundle)
	var max_vertical_step := WildDashGrandPrixV2Layout.get_max_vertical_step(bundle)

	var expected_ids: Array[StringName] = [
		&"meadow_start", &"forest_obstacle", &"long_river",
		&"mountain_approach", &"mountain_ascent", &"summit_ridge",
		&"rough_descent", &"canyon_obstacle", &"final_sprint",
	]
	if sections.size() != expected_ids.size():
		failures.append("Grand Prix V2 must contain exactly 9 named sections")
	for section_id: StringName in expected_ids:
		if not ranges.has(section_id):
			failures.append("missing section range: %s" % String(section_id))

	if length < WildDashGrandPrixV2Layout.TARGET_MIN_LENGTH or length > WildDashGrandPrixV2Layout.TARGET_MAX_LENGTH:
		failures.append("route length %.1fm is outside 2400-2700m" % length)
	if elevation.y - points[0].y < 40.0:
		failures.append("summit must rise at least 40m above start")
	if elevation.y < 50.0:
		failures.append("summit target should reach roughly 50-60m")
	if elevation.x > 0.0:
		failures.append("river lowland should descend below start elevation")
	if max_vertical_step > 3.0:
		failures.append("sampled route vertical step %.2fm is too abrupt" % max_vertical_step)

	if points.size() < 200:
		failures.append("V2 route should be densely sampled for stable physics")
	if widths.size() != points.size() - 1:
		failures.append("every route segment must have exactly one width")
	if section_ids.size() != widths.size():
		failures.append("every route segment must have exactly one section id")
	if checkpoints.size() < 10 or checkpoints.size() > 13:
		failures.append("checkpoint target is 10-13")

	var last_progress := -1
	for checkpoint: Vector3 in checkpoints:
		var nearest := _nearest_index(points, checkpoint)
		if nearest <= last_progress:
			failures.append("checkpoint ordering must strictly follow the sampled route")
			break
		last_progress = nearest

	var final_range: Vector2i = ranges.get(&"final_sprint", Vector2i(-1, -1))
	if final_range.y != widths.size() - 1:
		failures.append("final_sprint must own the last route segment before finish runout")

	# V2 collision generation is one floor + two edge shapes per route segment,
	# plus one joint plate for every interior point. The runtime track uses this
	# exact contract from the same bundle.
	var expected_collision_shapes := widths.size() * 3 + maxi(0, points.size() - 2)
	if expected_collision_shapes < 700:
		failures.append("collision contract is unexpectedly sparse: %d" % expected_collision_shapes)

	if failures.is_empty():
		print("RC9 GRAND PRIX V2 LAYOUT PASS sections=%d points=%d segments=%d checkpoints=%d length=%.1fm elevation=%.1f..%.1f max_y_step=%.2f expected_collision_shapes=%d" % [
			sections.size(), points.size(), widths.size(), checkpoints.size(), length,
			elevation.x, elevation.y, max_vertical_step, expected_collision_shapes,
		])
		quit(0)
		return

	for failure: String in failures:
		push_error("RC9 GRAND PRIX V2 LAYOUT FAIL: %s" % failure)
	quit(1)

func _nearest_index(points: Array[Vector3], point: Vector3) -> int:
	var best_index := 0
	var best_distance := INF
	for index in range(points.size()):
		var distance := points[index].distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index
