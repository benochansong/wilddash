class_name WildDashGrandPrixV2Layout
extends RefCounted

## Round 1 Adventure layout source of truth.
## Route points are sampled from nine named sections at ~10m spacing.
## Every downstream system consumes the generated bundle instead of old magic indices.

const TARGET_MIN_LENGTH := 2400.0
const TARGET_MAX_LENGTH := 2700.0
const DEFAULT_SAMPLE_STEP := 10.0

static func build_sections() -> Array[WildDashGrandPrixV2Section]:
	return [
		WildDashGrandPrixV2Section.new(
			&"meadow_start", "MEADOW START", &"meadow", 20.0, 2.0, &"none", &"wide_start",
			[
				Vector3(0.0, 0.0, 80.0), Vector3(16.8, 0.0, -4.0),
				Vector3(-21.0, 1.0, -67.0), Vector3(0.0, 2.0, -130.0),
			], DEFAULT_SAMPLE_STEP
		),
		WildDashGrandPrixV2Section.new(
			&"forest_obstacle", "FOREST OBSTACLE", &"forest", 15.0, 7.0, &"forest_v2", &"technical_wide",
			[
				Vector3(0.0, 2.0, -130.0), Vector3(-58.8, 3.0, -184.6),
				Vector3(-92.4, 5.0, -256.0), Vector3(-50.4, 6.0, -319.0),
				Vector3(0.0, 7.0, -373.6),
			], DEFAULT_SAMPLE_STEP
		),
		WildDashGrandPrixV2Section.new(
			&"long_river", "LONG RIVER", &"river", 20.0, -3.0, &"river_stage_2", &"river_safe",
			[
				Vector3(0.0, 7.0, -373.6), Vector3(58.8, 1.0, -419.8),
				Vector3(105.0, -3.0, -482.8), Vector3(54.6, -4.0, -545.8),
				Vector3(-8.4, -3.0, -604.6),
			], DEFAULT_SAMPLE_STEP
		),
		WildDashGrandPrixV2Section.new(
			&"mountain_approach", "MOUNTAIN APPROACH", &"mountain", 16.0, 15.0, &"light_rock", &"climb_entry",
			[
				Vector3(-8.4, -3.0, -604.6), Vector3(-46.2, 4.0, -659.2),
				Vector3(-12.6, 10.0, -713.8), Vector3(29.4, 15.0, -747.4),
			], DEFAULT_SAMPLE_STEP
		),
		WildDashGrandPrixV2Section.new(
			&"mountain_ascent", "MOUNTAIN ASCENT", &"climb", 12.0, 57.0, &"mountain_stage_2", &"switchback_climb",
			[
				Vector3(29.4, 15.0, -747.4), Vector3(88.2, 24.0, -789.4),
				Vector3(29.4, 34.0, -835.6), Vector3(-46.2, 44.0, -877.6),
				Vector3(16.8, 52.0, -928.0), Vector3(79.8, 57.0, -970.0),
			], 9.0
		),
		WildDashGrandPrixV2Section.new(
			&"summit_ridge", "SUMMIT RIDGE", &"summit", 17.0, 58.0, &"none", &"summit_release",
			[
				Vector3(79.8, 57.0, -970.0), Vector3(113.4, 58.0, -1020.4),
				Vector3(71.4, 56.0, -1075.0),
			], DEFAULT_SAMPLE_STEP
		),
		WildDashGrandPrixV2Section.new(
			&"rough_descent", "ROUGH DESCENT", &"rough", 14.0, 10.0, &"rough_stage_2", &"controlled_descent",
			[
				Vector3(71.4, 56.0, -1075.0), Vector3(21.0, 46.0, -1125.4),
				Vector3(-37.8, 34.0, -1175.8), Vector3(-79.8, 24.0, -1238.8),
				Vector3(-33.6, 16.0, -1297.6), Vector3(25.2, 10.0, -1343.8),
			], 9.0
		),
		WildDashGrandPrixV2Section.new(
			&"canyon_obstacle", "CANYON OBSTACLE", &"canyon", 16.0, 6.0, &"canyon_stage_3", &"technical_pack",
			[
				Vector3(25.2, 10.0, -1343.8), Vector3(79.8, 9.0, -1390.0),
				Vector3(100.8, 8.0, -1457.2), Vector3(46.2, 7.0, -1516.0),
				Vector3(-12.6, 6.0, -1558.0),
			], DEFAULT_SAMPLE_STEP
		),
		WildDashGrandPrixV2Section.new(
			&"final_sprint", "FINAL FOREST SPRINT", &"final", 20.0, 2.0, &"light_final", &"final_attack",
			[
				Vector3(-12.6, 6.0, -1558.0), Vector3(-67.2, 5.0, -1616.8),
				Vector3(-29.4, 4.0, -1688.2), Vector3(21.0, 3.0, -1751.2),
				Vector3(0.0, 2.0, -1818.4),
			], DEFAULT_SAMPLE_STEP
		),
	]

static func build_route_bundle() -> Dictionary:
	var points: Array[Vector3] = []
	var segment_widths: Array[float] = []
	var segment_sections: Array[StringName] = []
	var section_ranges: Dictionary = {}
	var sections := build_sections()

	for section in sections:
		var section_start_segment := segment_widths.size()
		if points.is_empty() and not section.anchors.is_empty():
			points.append(section.anchors[0])
		for anchor_index in range(section.anchors.size() - 1):
			var from_point: Vector3 = section.anchors[anchor_index]
			var to_point: Vector3 = section.anchors[anchor_index + 1]
			var distance := from_point.distance_to(to_point)
			var sample_count := maxi(1, int(ceil(distance / section.sample_step)))
			for sample_index in range(1, sample_count + 1):
				var t := float(sample_index) / float(sample_count)
				points.append(from_point.lerp(to_point, t))
				segment_widths.append(section.target_width)
				segment_sections.append(section.id)
		var section_end_segment := maxi(section_start_segment, segment_widths.size() - 1)
		section_ranges[section.id] = Vector2i(section_start_segment, section_end_segment)

	return {
		"points": points,
		"segment_widths": segment_widths,
		"segment_sections": segment_sections,
		"section_ranges": section_ranges,
		"sections": sections,
	}

static func build_checkpoint_positions(bundle: Dictionary) -> Array[Vector3]:
	var points: Array[Vector3] = bundle["points"]
	var ranges: Dictionary = bundle["section_ranges"]
	var result: Array[Vector3] = []
	var checkpoint_specs: Array = [
		[&"meadow_start", 0.72],
		[&"forest_obstacle", 0.92],
		[&"long_river", 0.10],
		[&"long_river", 0.52],
		[&"long_river", 0.92],
		[&"mountain_approach", 0.92],
		[&"mountain_ascent", 0.48],
		[&"summit_ridge", 0.48],
		[&"rough_descent", 0.52],
		[&"canyon_obstacle", 0.55],
		[&"final_sprint", 0.18],
		[&"final_sprint", 0.82],
	]
	for spec in checkpoint_specs:
		var section_id: StringName = spec[0]
		var progress: float = spec[1]
		if not ranges.has(section_id):
			continue
		var range_value: Vector2i = ranges[section_id]
		var segment_index := clampi(
			roundi(lerpf(float(range_value.x), float(range_value.y), progress)),
			0,
			points.size() - 2
		)
		result.append(points[segment_index])
	return result

static func get_total_length(bundle: Dictionary) -> float:
	var points: Array[Vector3] = bundle["points"]
	var total := 0.0
	for index in range(points.size() - 1):
		total += points[index].distance_to(points[index + 1])
	return total

static func get_elevation_range(bundle: Dictionary) -> Vector2:
	var points: Array[Vector3] = bundle["points"]
	if points.is_empty():
		return Vector2.ZERO
	var low := points[0].y
	var high := points[0].y
	for point in points:
		low = minf(low, point.y)
		high = maxf(high, point.y)
	return Vector2(low, high)

static func get_max_vertical_step(bundle: Dictionary) -> float:
	var points: Array[Vector3] = bundle["points"]
	var result := 0.0
	for index in range(points.size() - 1):
		result = maxf(result, absf(points[index + 1].y - points[index].y))
	return result
