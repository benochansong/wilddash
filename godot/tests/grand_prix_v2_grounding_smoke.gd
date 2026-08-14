extends SceneTree

func _init() -> void:
	var failures: Array[String] = []
	var bundle: Dictionary = WildDashGrandPrixV2Layout.build_route_bundle()
	var points: Array[Vector3] = bundle["points"]
	var widths: Array[float] = bundle["segment_widths"]
	var sections: Array[StringName] = bundle["segment_sections"]

	if WildDashGrandPrixV2GroundingWorld.CHUNK_LENGTH < 80.0 or WildDashGrandPrixV2GroundingWorld.CHUNK_LENGTH > 120.0:
		failures.append("V2.7 grounding chunk target must remain within 80-120m")
	if absf(WildDashGrandPrixV2GroundingWorld.CHUNK_LENGTH - WildDashGrandPrixV2TerrainShell.CHUNK_LENGTH) > 0.01:
		failures.append("TerrainShell and GroundingWorld chunk targets must stay aligned")
	if WildDashGrandPrixV2GroundingWorld.SUBGRADE_TOP_DROP < 0.10 or WildDashGrandPrixV2GroundingWorld.SUBGRADE_TOP_DROP > 0.50:
		failures.append("road/subgrade top gap must remain within requested 0.10-0.50m envelope")
	if WildDashGrandPrixV2GroundingWorld.SUBGRADE_DEPTH < 0.20:
		failures.append("subgrade must have visible closed thickness")

	# Hard-reset visual contract: only route point 0 -> 1 is allowed until a real
	# graphical Meadow screenshot approves the prototype.
	if WildDashGrandPrixV2CourseGuidance.PROTOTYPE_POINT_A != 0:
		failures.append("V2.7 prototype must start at Meadow route point 0")
	if WildDashGrandPrixV2CourseGuidance.PROTOTYPE_POINT_B != 1:
		failures.append("V2.7 prototype must stop at the immediately adjacent point 1")
	if WildDashGrandPrixV2CourseGuidance.PROTOTYPE_POINT_B != WildDashGrandPrixV2CourseGuidance.PROTOTYPE_POINT_A + 1:
		failures.append("V2.7 prototype rail endpoints must be adjacent indices only")
	if WildDashGrandPrixV2CourseGuidance.SAFE_GAP < 0.50 or WildDashGrandPrixV2CourseGuidance.SAFE_GAP > 0.90:
		failures.append("V2.7 post safety gap must remain inside 0.50-0.90m")
	if WildDashGrandPrixV2CourseGuidance.ENDPOINT_TOLERANCE > 0.05:
		failures.append("V2.7 endpoint tolerance must stay at or below 5cm")

	var first_segment_length: float = points[0].distance_to(points[1]) if points.size() > 1 else INF
	if first_segment_length > WildDashGrandPrixV2CourseGuidance.MAX_REASONABLE_RAIL_SEGMENT:
		failures.append("Meadow point 0->1 is too long for the minimal guardrail prototype")

	# Reconstruct the post base positions without instantiating render nodes.
	var minimum_post_margin: float = INF
	for point_index: int in [0, 1]:
		for side: float in [-1.0, 1.0]:
			var shoulder: Vector3 = WildDashGrandPrixV2Geometry.shoulder_edge_point(points, widths, sections, point_index, side)
			var outward: Vector3 = shoulder - points[point_index]
			outward.y = 0.0
			if outward.length_squared() <= 0.000001:
				failures.append("prototype shoulder outward vector is degenerate")
				continue
			outward = outward.normalized()
			var post_base: Vector3 = shoulder + outward * (
				WildDashGrandPrixV2CourseGuidance.SAFE_GAP
				+ WildDashGrandPrixV2CourseGuidance.POST_SIZE * 0.5
			)
			var shoulder_delta: Vector3 = shoulder - points[point_index]
			var post_delta: Vector3 = post_base - points[point_index]
			shoulder_delta.y = 0.0
			post_delta.y = 0.0
			var margin: float = post_delta.length() - shoulder_delta.length()
			minimum_post_margin = minf(minimum_post_margin, margin)
			if margin < 0.50:
				failures.append("prototype post is not safely outside shoulder point=%d side=%.0f margin=%.3f" % [point_index, side, margin])

	var expected_chunks: int = _count_spatial_chunks(points, WildDashGrandPrixV2GroundingWorld.CHUNK_LENGTH)
	if expected_chunks < 22 or expected_chunks > 32:
		failures.append("2.6km course should resolve to 22-32 grounding chunks, got %d" % expected_chunks)

	if failures.is_empty():
		print("GRAND PRIX V2.7 HARD RESET SMOKE PASS prototype=0->1 expected_posts=4 expected_rails=2 multimesh_visual=false adjacent_only=true safe_gap=%.2fm endpoint_tolerance=%.2fm first_segment=%.2fm min_post_margin=%.2fm grounding_chunks=%d graphical_pass=REQUIRED" % [
			WildDashGrandPrixV2CourseGuidance.SAFE_GAP,
			WildDashGrandPrixV2CourseGuidance.ENDPOINT_TOLERANCE,
			first_segment_length, minimum_post_margin, expected_chunks,
		])
		quit(0)
		return

	for failure: String in failures:
		push_error("GRAND PRIX V2.7 HARD RESET SMOKE FAIL: %s" % failure)
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
