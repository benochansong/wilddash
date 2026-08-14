class_name WildDashGrandPrixV2GuardrailMesh
extends RefCounted

## V2.6 continuous guardrail geometry.
## The authoritative edge is always the barrier inner face. Rail thickness grows
## only away from the road, so a visual beam can no longer protrude back over
## the shoulder at a tight bend. Very sharp sampled corners duplicate only the
## OUTER cross-section to form an outward bevel while keeping the inner vertex
## pinned to the safety polyline used by collision.

const BEVEL_MITER_THRESHOLD: float = 1.12
const MIN_OUTWARD_DOT: float = 0.08

static func build_swept_beam(
	track: WildDashGrandPrixV2Track,
	route: Array[Vector3],
	start_point: int,
	end_point: int,
	bottom_height: float,
	top_height: float,
	outward_width: float
) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	if track == null or route.size() < 2 or end_point <= start_point:
		return mesh
	if top_height <= bottom_height or outward_width <= 0.0:
		return mesh

	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		var cross_sections: Array[Dictionary] = _build_cross_sections(
			track, route, start_point, end_point, side, outward_width
		)
		for index: int in range(cross_sections.size() - 1):
			_add_prism_segment(surface, cross_sections[index], cross_sections[index + 1], bottom_height, top_height)
	if surface.get_vertex_count() == 0:
		return mesh
	surface.generate_normals()
	return surface.commit()

static func build_inner_collision_wall(
	track: WildDashGrandPrixV2Track,
	route: Array[Vector3],
	start_point: int,
	end_point: int,
	height: float
) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	if track == null or route.size() < 2 or end_point <= start_point or height <= 0.0:
		return ArrayMesh.new()

	for side: float in [-1.0, 1.0]:
		for point_index: int in range(start_point, end_point):
			var p0: Vector3 = track.get_v2_barrier_inner_face_point(point_index, side)
			var p1: Vector3 = track.get_v2_barrier_inner_face_point(point_index + 1, side)
			var base_index: int = vertices.size()
			vertices.append(p0 + Vector3.UP * 0.04)
			vertices.append(p1 + Vector3.UP * 0.04)
			vertices.append(p0 + Vector3.UP * height)
			vertices.append(p1 + Vector3.UP * height)
			indices.append_array(PackedInt32Array([
				base_index, base_index + 2, base_index + 1,
				base_index + 1, base_index + 2, base_index + 3,
			]))

	var mesh: ArrayMesh = ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func support_transform(
	track: WildDashGrandPrixV2Track,
	route: Array[Vector3],
	point_index: int,
	side: float,
	support_size: float,
	support_height: float
) -> Transform3D:
	var inner: Vector3 = track.get_v2_barrier_inner_face_point(point_index, side)
	var outward: Vector3 = _safe_outward(route, point_index, side, inner)
	# The inside face of the post is also pinned outside the authoritative line.
	var center: Vector3 = inner + outward * (support_size * 0.5 + 0.015)
	center.y += support_height * 0.5
	return Transform3D(
		Basis.IDENTITY.scaled(Vector3(support_size, support_height, support_size)),
		center
	)

static func count_bevel_points(route: Array[Vector3], start_point: int, end_point: int) -> int:
	var count: int = 0
	for point_index: int in range(maxi(start_point + 1, 1), mini(end_point, route.size() - 1)):
		if WildDashGrandPrixV2Geometry.miter_ratio_at(route, point_index) > BEVEL_MITER_THRESHOLD:
			count += 1
	return count

static func _build_cross_sections(
	track: WildDashGrandPrixV2Track,
	route: Array[Vector3],
	start_point: int,
	end_point: int,
	side: float,
	outward_width: float
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for point_index: int in range(start_point, end_point + 1):
		var inner: Vector3 = track.get_v2_barrier_inner_face_point(point_index, side)
		var radial_outward: Vector3 = _safe_outward(route, point_index, side, inner)
		var sharp: bool = (
			point_index > start_point
			and point_index < end_point
			and WildDashGrandPrixV2Geometry.miter_ratio_at(route, point_index) > BEVEL_MITER_THRESHOLD
		)
		if not sharp:
			result.append({"inner": inner, "outer": inner + radial_outward * outward_width})
			continue

		# Outward-only bevel. Both cross-sections share the exact same authoritative
		# inner vertex, while the outer vertex follows incoming/outgoing segment
		# normals. This removes rectangular beam overhang without moving inward.
		var previous_direction: Vector3 = route[point_index] - route[point_index - 1]
		previous_direction.y = 0.0
		previous_direction = _safe_normalized(previous_direction, Vector3.FORWARD)
		var next_direction: Vector3 = route[point_index + 1] - route[point_index]
		next_direction.y = 0.0
		next_direction = _safe_normalized(next_direction, previous_direction)
		var previous_outward: Vector3 = Vector3(-previous_direction.z, 0.0, previous_direction.x) * side
		var next_outward: Vector3 = Vector3(-next_direction.z, 0.0, next_direction.x) * side
		if previous_outward.dot(radial_outward) < MIN_OUTWARD_DOT:
			previous_outward = radial_outward
		if next_outward.dot(radial_outward) < MIN_OUTWARD_DOT:
			next_outward = radial_outward
		result.append({"inner": inner, "outer": inner + previous_outward.normalized() * outward_width})
		result.append({"inner": inner, "outer": inner + next_outward.normalized() * outward_width})
	return result

static func _add_prism_segment(
	surface: SurfaceTool,
	from_section: Dictionary,
	to_section: Dictionary,
	bottom_height: float,
	top_height: float
) -> void:
	var a_inner: Vector3 = from_section["inner"] as Vector3
	var a_outer: Vector3 = from_section["outer"] as Vector3
	var b_inner: Vector3 = to_section["inner"] as Vector3
	var b_outer: Vector3 = to_section["outer"] as Vector3
	var a_ib: Vector3 = a_inner + Vector3.UP * bottom_height
	var a_it: Vector3 = a_inner + Vector3.UP * top_height
	var a_ob: Vector3 = a_outer + Vector3.UP * bottom_height
	var a_ot: Vector3 = a_outer + Vector3.UP * top_height
	var b_ib: Vector3 = b_inner + Vector3.UP * bottom_height
	var b_it: Vector3 = b_inner + Vector3.UP * top_height
	var b_ob: Vector3 = b_outer + Vector3.UP * bottom_height
	var b_ot: Vector3 = b_outer + Vector3.UP * top_height

	_add_quad(surface, a_it, b_it, a_ot, b_ot) # top
	_add_quad(surface, a_ib, a_ob, b_ib, b_ob) # underside
	_add_quad(surface, a_ib, b_ib, a_it, b_it) # authoritative inner face
	_add_quad(surface, a_ob, a_ot, b_ob, b_ot) # outer face

static func _add_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
	surface.add_vertex(c)
	surface.add_vertex(b)
	surface.add_vertex(d)

static func _safe_outward(route: Array[Vector3], point_index: int, side: float, inner: Vector3) -> Vector3:
	var outward: Vector3 = inner - route[point_index]
	outward.y = 0.0
	if outward.length_squared() <= 0.000001:
		var tangent: Vector3 = WildDashGrandPrixV2Geometry.planar_tangent_at(route, point_index)
		outward = Vector3(-tangent.z, 0.0, tangent.x) * side
	return _safe_normalized(outward, Vector3.RIGHT * side)

static func _safe_normalized(value: Vector3, fallback: Vector3) -> Vector3:
	if value.length_squared() <= 0.000001:
		return fallback.normalized()
	return value.normalized()
