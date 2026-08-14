class_name WildDashGrandPrixV2Geometry
extends RefCounted

## Shared V2.5 geometry contract for road, shoulder and barriers.
## Every system derives lateral edges from the same sampled center route so a
## corner cannot use one normal for the road and a different normal for rails.

const MITER_LIMIT_RATIO: float = 1.18
const BARRIER_MARGIN: float = 0.22

const SHOULDER_WIDTHS: Dictionary = {
	&"meadow_start": 3.0,
	&"forest_obstacle": 2.25,
	&"long_river": 2.0,
	&"mountain_approach": 1.5,
	&"mountain_ascent": 1.25,
	&"summit_ridge": 1.6,
	&"rough_descent": 1.6,
	&"canyon_obstacle": 1.25,
	&"final_sprint": 3.0,
}

const BARRIER_PROFILES: Dictionary = {
	&"meadow_start": &"wood_fence",
	&"forest_obstacle": &"wood_fence",
	&"long_river": &"river_bank",
	&"mountain_approach": &"rock_border",
	&"mountain_ascent": &"danger_rail",
	&"summit_ridge": &"rope_or_wood",
	&"rough_descent": &"danger_rail",
	&"canyon_obstacle": &"rock_wall",
	&"final_sprint": &"wood_fence",
}

static func shoulder_width_for_section(section_id: StringName) -> float:
	return float(SHOULDER_WIDTHS.get(section_id, 1.5))

static func barrier_profile_for_section(section_id: StringName) -> StringName:
	return StringName(BARRIER_PROFILES.get(section_id, &"danger_rail"))

static func point_section_id(segment_sections: Array[StringName], point_index: int) -> StringName:
	if segment_sections.is_empty():
		return &""
	var segment_index: int = clampi(point_index, 0, segment_sections.size() - 1)
	return segment_sections[segment_index]

static func point_half_width(segment_widths: Array[float], point_index: int) -> float:
	if segment_widths.is_empty():
		return 8.0
	if point_index <= 0:
		return segment_widths[0] * 0.5
	if point_index >= segment_widths.size():
		return segment_widths[-1] * 0.5
	# Use the wider adjacent segment at transitions. This prevents a shared edge
	# point from pinching inward where two sections have different widths.
	return maxf(segment_widths[point_index - 1], segment_widths[point_index]) * 0.5

static func point_shoulder_width(segment_sections: Array[StringName], point_index: int) -> float:
	if segment_sections.is_empty():
		return 1.5
	if point_index <= 0:
		return shoulder_width_for_section(segment_sections[0])
	if point_index >= segment_sections.size():
		return shoulder_width_for_section(segment_sections[-1])
	var previous_width: float = shoulder_width_for_section(segment_sections[point_index - 1])
	var next_width: float = shoulder_width_for_section(segment_sections[point_index])
	return maxf(previous_width, next_width)

static func tangent_3d_at(route: Array[Vector3], point_index: int) -> Vector3:
	if route.size() < 2:
		return Vector3.FORWARD
	var index: int = clampi(point_index, 0, route.size() - 1)
	if index == 0:
		return _safe_normalized(route[1] - route[0], Vector3.FORWARD)
	if index == route.size() - 1:
		return _safe_normalized(route[-1] - route[-2], Vector3.FORWARD)
	var previous_direction: Vector3 = _safe_normalized(route[index] - route[index - 1], Vector3.FORWARD)
	var next_direction: Vector3 = _safe_normalized(route[index + 1] - route[index], previous_direction)
	var averaged: Vector3 = previous_direction + next_direction
	return _safe_normalized(averaged, next_direction)

static func planar_tangent_at(route: Array[Vector3], point_index: int) -> Vector3:
	var tangent: Vector3 = tangent_3d_at(route, point_index)
	tangent.y = 0.0
	return _safe_normalized(tangent, Vector3.FORWARD)

static func road_normal_at(route: Array[Vector3], point_index: int) -> Vector3:
	var tangent: Vector3 = tangent_3d_at(route, point_index)
	var planar: Vector3 = Vector3(tangent.x, 0.0, tangent.z)
	planar = _safe_normalized(planar, Vector3.FORWARD)
	var right: Vector3 = Vector3(-planar.z, 0.0, planar.x)
	var normal: Vector3 = right.cross(tangent)
	if normal.y < 0.0:
		normal = -normal
	return _safe_normalized(normal, Vector3.UP)

static func lateral_offset(route: Array[Vector3], point_index: int, distance: float) -> Vector3:
	if route.size() < 2 or distance <= 0.0:
		return Vector3.ZERO
	var index: int = clampi(point_index, 0, route.size() - 1)
	var current_right: Vector3 = _right_from_planar(planar_tangent_at(route, index))
	if index == 0 or index == route.size() - 1:
		return current_right * distance

	var previous_direction: Vector3 = route[index] - route[index - 1]
	previous_direction.y = 0.0
	previous_direction = _safe_normalized(previous_direction, planar_tangent_at(route, index))
	var next_direction: Vector3 = route[index + 1] - route[index]
	next_direction.y = 0.0
	next_direction = _safe_normalized(next_direction, previous_direction)
	var previous_right: Vector3 = _right_from_planar(previous_direction)
	var next_right: Vector3 = _right_from_planar(next_direction)
	var miter: Vector3 = previous_right + next_right
	if miter.length_squared() <= 0.0001:
		return current_right * distance
	miter = miter.normalized()
	var denominator: float = absf(miter.dot(previous_right))
	if denominator <= 0.12:
		return current_right * distance
	var requested_length: float = distance / denominator
	var clamped_length: float = minf(requested_length, distance * MITER_LIMIT_RATIO)
	return miter * clamped_length

static func road_edge_point(
	route: Array[Vector3],
	segment_widths: Array[float],
	point_index: int,
	side: float
) -> Vector3:
	var distance: float = point_half_width(segment_widths, point_index)
	return route[point_index] + lateral_offset(route, point_index, distance) * side

static func shoulder_edge_point(
	route: Array[Vector3],
	segment_widths: Array[float],
	segment_sections: Array[StringName],
	point_index: int,
	side: float
) -> Vector3:
	var distance: float = point_half_width(segment_widths, point_index) + point_shoulder_width(segment_sections, point_index)
	return route[point_index] + lateral_offset(route, point_index, distance) * side

static func barrier_point(
	route: Array[Vector3],
	segment_widths: Array[float],
	segment_sections: Array[StringName],
	point_index: int,
	side: float
) -> Vector3:
	var distance: float = point_half_width(segment_widths, point_index) + point_shoulder_width(segment_sections, point_index) + BARRIER_MARGIN
	return route[point_index] + lateral_offset(route, point_index, distance) * side

static func barrier_clearance(
	route: Array[Vector3],
	segment_widths: Array[float],
	segment_sections: Array[StringName],
	point_index: int
) -> float:
	var point: Vector3 = barrier_point(route, segment_widths, segment_sections, point_index, 1.0)
	var center: Vector3 = route[point_index]
	var delta: Vector3 = point - center
	delta.y = 0.0
	return delta.length()

static func barrier_required_clearance(
	segment_widths: Array[float],
	segment_sections: Array[StringName],
	point_index: int
) -> float:
	return point_half_width(segment_widths, point_index) + point_shoulder_width(segment_sections, point_index)

static func miter_ratio_at(route: Array[Vector3], point_index: int) -> float:
	var offset: Vector3 = lateral_offset(route, point_index, 1.0)
	return offset.length()

static func _right_from_planar(planar: Vector3) -> Vector3:
	return Vector3(-planar.z, 0.0, planar.x).normalized()

static func _safe_normalized(value: Vector3, fallback: Vector3) -> Vector3:
	if value.length_squared() <= 0.000001:
		return fallback.normalized()
	return value.normalized()
