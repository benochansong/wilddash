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
	var length: float = WildDashGrandPrixV2Layout.get_total_length(bundle)
	var elevation: Vector2 = WildDashGrandPrixV2Layout.get_elevation_range(bundle)
	var max_vertical_step: float = WildDashGrandPrixV2Layout.get_max_vertical_step(bundle)

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
		failures.append("V2 route should remain densely sampled for stable ribbon physics")
	if widths.size() != points.size() - 1:
		failures.append("every route segment must have exactly one width")
	if section_ids.size() != widths.size():
		failures.append("every route segment must have exactly one section id")
	if checkpoints.size() < 10 or checkpoints.size() > 13:
		failures.append("checkpoint target is 10-13")

	var last_progress: int = -1
	for checkpoint: Vector3 in checkpoints:
		var nearest: int = _nearest_index(points, checkpoint)
		if nearest <= last_progress:
			failures.append("checkpoint ordering must strictly follow the sampled route")
			break
		last_progress = nearest

	var final_range: Vector2i = ranges.get(&"final_sprint", Vector2i(-1, -1))
	if final_range.y != widths.size() - 1:
		failures.append("final_sprint must own the last route segment before finish runout")

	# Road/shoulder architecture budgets.
	var expected_road_meshes: int = sections.size() + 1
	var expected_shoulder_meshes: int = sections.size()
	if expected_road_meshes > 24:
		failures.append("V2.5 road mesh contract exceeds section-sized budget")
	if expected_shoulder_meshes > 18:
		failures.append("V2.5 shoulder mesh contract exceeds section-sized budget")
	var expected_road_collision_shapes: int = sections.size() + 1
	if expected_road_collision_shapes > 18:
		failures.append("V2.5 road collision contract should remain section-sized")

	# Geometry contract: road, shoulder and barriers share one averaged tangent.
	var maximum_miter_ratio: float = 0.0
	var minimum_barrier_inner_margin: float = INF
	var minimum_visual_inner_margin: float = INF
	for point_index: int in range(points.size()):
		var miter_ratio: float = WildDashGrandPrixV2Geometry.miter_ratio_at(points, point_index)
		maximum_miter_ratio = maxf(maximum_miter_ratio, miter_ratio)
		if miter_ratio > WildDashGrandPrixV2Geometry.MITER_LIMIT_RATIO + 0.001:
			failures.append("miter ratio %.3f exceeds V2.5 limit at point %d" % [miter_ratio, point_index])
			break

		var required: float = WildDashGrandPrixV2Geometry.barrier_required_clearance(widths, section_ids, point_index)
		var inner_clearance: float = WildDashGrandPrixV2Geometry.barrier_clearance(points, widths, section_ids, point_index)
		var inner_margin: float = inner_clearance - required
		minimum_barrier_inner_margin = minf(minimum_barrier_inner_margin, inner_margin)
		if inner_margin + 0.001 < WildDashGrandPrixV2Geometry.MIN_BARRIER_INNER_CLEARANCE:
			failures.append("barrier collision inner-face margin %.3fm is below safety minimum at point %d" % [inner_margin, point_index])
			break

		var visual_inner_clearance: float = WildDashGrandPrixV2Geometry.barrier_visual_inner_clearance_bound(points, widths, section_ids, point_index)
		var visual_inner_margin: float = visual_inner_clearance - required
		minimum_visual_inner_margin = minf(minimum_visual_inner_margin, visual_inner_margin)
		if visual_inner_margin + 0.001 < WildDashGrandPrixV2Geometry.MIN_BARRIER_INNER_CLEARANCE:
			failures.append("thick visual barrier can intrude into shoulder at point %d margin=%.3fm" % [point_index, visual_inner_margin])
			break

		var left_point: Vector3 = WildDashGrandPrixV2Geometry.barrier_point(points, widths, section_ids, point_index, -1.0)
		var right_point: Vector3 = WildDashGrandPrixV2Geometry.barrier_point(points, widths, section_ids, point_index, 1.0)
		if absf((left_point - points[point_index]).length() - (right_point - points[point_index]).length()) > 0.01:
			failures.append("left/right barrier center geometry must remain symmetric at point %d" % point_index)
			break

		var left_inner: Vector3 = WildDashGrandPrixV2Geometry.barrier_inner_face_point(points, widths, section_ids, point_index, -1.0)
		var right_inner: Vector3 = WildDashGrandPrixV2Geometry.barrier_inner_face_point(points, widths, section_ids, point_index, 1.0)
		if absf((left_inner - points[point_index]).length() - (right_inner - points[point_index]).length()) > 0.01:
			failures.append("left/right barrier inner faces must remain symmetric at point %d" % point_index)
			break

	for section: WildDashGrandPrixV2Section in sections:
		var shoulder_width: float = WildDashGrandPrixV2Geometry.shoulder_width_for_section(section.id)
		if shoulder_width < 1.0:
			failures.append("section %s needs a real shoulder before its barrier" % String(section.id))
		var profile: StringName = WildDashGrandPrixV2Geometry.barrier_profile_for_section(section.id)
		if profile == &"":
			failures.append("section %s is missing a barrier profile" % String(section.id))
		if WildDashGrandPrixV2Geometry.barrier_half_width_for_profile(profile) <= 0.0:
			failures.append("section %s barrier profile has no visual half-width contract" % String(section.id))
		if (section.id == &"mountain_ascent" or section.id == &"rough_descent") and section.sample_step > 10.0:
			failures.append("section %s must keep <=10m sampling for tunneling safety" % String(section.id))

	# Grounded-world / performance architecture contract.
	if WildDashGrandPrixV2TerrainShell.CHUNK_LENGTH < 80.0 or WildDashGrandPrixV2TerrainShell.CHUNK_LENGTH > 120.0:
		failures.append("terrain spatial chunk target must remain within 80-120m")
	if WildDashGrandPrixV2TerrainShell.NEAR_COLLISION_WIDTH < 8.0 or WildDashGrandPrixV2TerrainShell.NEAR_COLLISION_WIDTH > 12.0:
		failures.append("near terrain collision band must remain within 8-12m")
	if WildDashGrandPrixV2Track.SUN_SHADOW_MAX_DISTANCE > 140.0:
		failures.append("V2 sun shadow distance should not cover distant course environment")

	var terrain_width_limits: Dictionary = {
		&"meadow_start": Vector4(15.0, 20.0, 40.0, 70.0),
		&"forest_obstacle": Vector4(12.0, 18.0, 30.0, 55.0),
		&"long_river": Vector4(10.0, 18.0, 25.0, 40.0),
		&"mountain_approach": Vector4(10.0, 15.0, 30.0, 50.0),
		&"mountain_ascent": Vector4(8.0, 15.0, 25.0, 60.0),
		&"summit_ridge": Vector4(10.0, 15.0, 25.0, 40.0),
		&"rough_descent": Vector4(10.0, 15.0, 25.0, 50.0),
		&"canyon_obstacle": Vector4(6.0, 10.0, 15.0, 24.0),
		&"final_sprint": Vector4(15.0, 20.0, 40.0, 70.0),
	}
	for section_id: StringName in expected_ids:
		if not WildDashGrandPrixV2TerrainShell.TERRAIN_WIDTHS.has(section_id):
			failures.append("terrain shell missing width profile for %s" % String(section_id))
			continue
		var terrain_width: Vector2 = WildDashGrandPrixV2TerrainShell.TERRAIN_WIDTHS[section_id]
		var limit: Vector4 = terrain_width_limits[section_id]
		if terrain_width.x < limit.x or terrain_width.x > limit.y:
			failures.append("%s near terrain width %.1fm outside requested range" % [String(section_id), terrain_width.x])
		if terrain_width.y < limit.z or terrain_width.y > limit.w:
			failures.append("%s far terrain width %.1fm outside requested range" % [String(section_id), terrain_width.y])

	var expected_terrain_chunks: int = _count_spatial_chunks(points, WildDashGrandPrixV2TerrainShell.CHUNK_LENGTH)
	if expected_terrain_chunks < 22 or expected_terrain_chunks > 32:
		failures.append("2.6km V2 course should resolve to roughly 22-32 spatial chunks, got %d" % expected_terrain_chunks)
	var max_visible_detail_chunks: int = WildDashGrandPrixV2TerrainShell.DETAIL_ACTIVE_RADIUS * 2 + 1
	if max_visible_detail_chunks > 9:
		failures.append("detail chunk active radius is too broad for the V2 performance budget")

	if failures.is_empty():
		print("RC9 GRAND PRIX V2.5 LAYOUT PASS sections=%d points=%d segments=%d checkpoints=%d length=%.1fm elevation=%.1f..%.1f max_y_step=%.2f road_meshes=%d shoulder_meshes=%d road_collision_shapes=%d terrain_chunks=%d chunk_target=%.0fm near_collision_width=%.0fm max_detail_chunks=%d shadow_distance=%.0fm max_miter_ratio=%.3f min_barrier_inner_margin=%.3f min_visual_inner_margin=%.3f" % [
			sections.size(), points.size(), widths.size(), checkpoints.size(), length,
			elevation.x, elevation.y, max_vertical_step, expected_road_meshes,
			expected_shoulder_meshes, expected_road_collision_shapes, expected_terrain_chunks,
			WildDashGrandPrixV2TerrainShell.CHUNK_LENGTH, WildDashGrandPrixV2TerrainShell.NEAR_COLLISION_WIDTH,
			max_visible_detail_chunks, WildDashGrandPrixV2Track.SUN_SHADOW_MAX_DISTANCE,
			maximum_miter_ratio, minimum_barrier_inner_margin, minimum_visual_inner_margin,
		])
		quit(0)
		return

	for failure: String in failures:
		push_error("RC9 GRAND PRIX V2.5 LAYOUT FAIL: %s" % failure)
	quit(1)

func _count_spatial_chunks(points: Array[Vector3], chunk_length: float) -> int:
	if points.size() < 2:
		return 0
	var count: int = 0
	var distance: float = 0.0
	for segment_index: int in range(points.size() - 1):
		distance += points[segment_index].distance_to(points[segment_index + 1])
		if distance >= chunk_length and segment_index + 1 < points.size() - 1:
			count += 1
			distance = 0.0
	if distance > 0.0:
		count += 1
	return count

func _nearest_index(points: Array[Vector3], point: Vector3) -> int:
	var best_index: int = 0
	var best_distance: float = INF
	for index: int in range(points.size()):
		var distance: float = points[index].distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index
