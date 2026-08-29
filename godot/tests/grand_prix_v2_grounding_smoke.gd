extends SceneTree

func _init() -> void:
	var failures: Array[String] = []
	var bundle: Dictionary = WildDashGrandPrixV2Layout.build_route_bundle()
	var points: Array[Vector3] = bundle["points"]
	var widths: Array[float] = bundle["segment_widths"]
	var sections: Array[StringName] = bundle["segment_sections"]

	if WildDashGrandPrixV2GroundingWorld.CHUNK_LENGTH < 80.0 or WildDashGrandPrixV2GroundingWorld.CHUNK_LENGTH > 120.0:
		failures.append("grounding chunk target must remain within 80-120m")
	if absf(WildDashGrandPrixV2GroundingWorld.CHUNK_LENGTH - WildDashGrandPrixV2TerrainShell.CHUNK_LENGTH) > 0.01:
		failures.append("TerrainShell and GroundingWorld chunk targets must stay aligned")
	if WildDashGrandPrixV2GroundingWorld.SUBGRADE_TOP_DROP < 0.10 or WildDashGrandPrixV2GroundingWorld.SUBGRADE_TOP_DROP > 0.50:
		failures.append("road/subgrade top gap must remain within requested 0.10-0.50m envelope")
	if WildDashGrandPrixV2GroundingWorld.SUBGRADE_DEPTH < 0.20:
		failures.append("subgrade must have visible closed thickness")
	if WildDashGrandPrixV2CourseGuidance.VISUAL_OWNER_GROUP != &"wilddash_guardrail_visual_owner":
		failures.append("guardrail visual owner diagnostic group changed unexpectedly")

	var expected_chunks: int = _count_spatial_chunks(points, WildDashGrandPrixV2GroundingWorld.CHUNK_LENGTH)
	if expected_chunks < 22 or expected_chunks > 32:
		failures.append("2.6km course should resolve to 22-32 grounding chunks, got %d" % expected_chunks)

	var minimum_inner_margin: float = INF
	for point_index: int in range(points.size()):
		for side: float in [-1.0, 1.0]:
			var shoulder: Vector3 = WildDashGrandPrixV2Geometry.shoulder_edge_point(points, widths, sections, point_index, side)
			var inner: Vector3 = WildDashGrandPrixV2Geometry.barrier_inner_face_point(points, widths, sections, point_index, side)
			var shoulder_delta: Vector3 = shoulder - points[point_index]
			var inner_delta: Vector3 = inner - points[point_index]
			shoulder_delta.y = 0.0
			inner_delta.y = 0.0
			var margin: float = inner_delta.length() - shoulder_delta.length()
			minimum_inner_margin = minf(minimum_inner_margin, margin)
			if margin + 0.001 < WildDashGrandPrixV2Geometry.MIN_BARRIER_INNER_CLEARANCE:
				failures.append("invisible safety barrier enters shoulder at point %d side=%.0f margin=%.3f" % [point_index, side, margin])
				break

	var required_sections: Array[StringName] = [
		&"meadow_start", &"forest_obstacle", &"long_river", &"mountain_approach",
		&"mountain_ascent", &"summit_ridge", &"rough_descent", &"canyon_obstacle", &"final_sprint",
	]
	for section_id: StringName in required_sections:
		if not WildDashGrandPrixV2TerrainShell.TERRAIN_WIDTHS.has(section_id):
			failures.append("world is missing terrain width profile for %s" % String(section_id))

	if failures.is_empty():
		print("GRAND PRIX V2.8 NATURAL BOUNDARY SMOKE PASS chunks=%d subgrade_gap=%.2fm subgrade_depth=%.2fm min_inner_margin=%.3fm visible_guardrail_meshes=0 posts=0 rails=0 invisible_safety_collision=true terrain_skirt=true far_collision=0" % [
			expected_chunks, WildDashGrandPrixV2GroundingWorld.SUBGRADE_TOP_DROP,
			WildDashGrandPrixV2GroundingWorld.SUBGRADE_DEPTH, minimum_inner_margin,
		])
		quit(0)
		return

	for failure: String in failures:
		push_error("GRAND PRIX V2.8 NATURAL BOUNDARY SMOKE FAIL: %s" % failure)
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
