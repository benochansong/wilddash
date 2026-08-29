class_name WildDashGrandPrixV2GuardrailMesh
extends RefCounted

## V2.6 recovery helper.
## Keep guardrail geometry deliberately simple and local: every visible rail
## connects ONLY point N to point N+1. The rail centerline is shifted outward
## from the authoritative barrier inner-face by half of its depth, so the box
## body cannot protrude back over the shoulder. No swept strip, no miter fan,
## no bevel triangulation, and no non-adjacent vertex connection is allowed.

const OUTWARD_CLEARANCE: float = 0.02

static func rail_anchor(
	track: WildDashGrandPrixV2Track,
	route: Array[Vector3],
	point_index: int,
	side: float,
	rail_depth: float,
	height: float
) -> Vector3:
	var inner: Vector3 = track.get_v2_barrier_inner_face_point(point_index, side)
	var outward: Vector3 = _safe_outward(route, point_index, side, inner)
	return inner + outward * (rail_depth * 0.5 + OUTWARD_CLEARANCE) + Vector3.UP * height

static func rail_segment_transform(
	track: WildDashGrandPrixV2Track,
	route: Array[Vector3],
	from_index: int,
	to_index: int,
	side: float,
	rail_depth: float,
	rail_height: float,
	vertical_thickness: float
) -> Transform3D:
	# This function intentionally accepts adjacent route indices only. If a caller
	# ever passes a skip link, return identity-sized-at-origin instead of drawing a
	# giant rail across the course.
	if track == null or route.size() < 2:
		return Transform3D.IDENTITY
	if to_index != from_index + 1:
		push_error("V2.6 guardrail rejected non-adjacent link %d -> %d" % [from_index, to_index])
		return Transform3D.IDENTITY
	if from_index < 0 or to_index >= route.size():
		return Transform3D.IDENTITY

	var from_point: Vector3 = rail_anchor(track, route, from_index, side, rail_depth, rail_height)
	var to_point: Vector3 = rail_anchor(track, route, to_index, side, rail_depth, rail_height)
	var delta: Vector3 = to_point - from_point
	var length: float = delta.length()
	if length <= 0.001:
		return Transform3D.IDENTITY

	# Build the box basis explicitly. Do NOT use looking_at().scaled(); explicit
	# local axes make it unambiguous that Z is rail length, X is rail depth and Y
	# is vertical thickness even on sloped road segments.
	var z_axis: Vector3 = delta / length
	var x_axis: Vector3 = Vector3.UP.cross(z_axis)
	if x_axis.length_squared() <= 0.000001:
		x_axis = Vector3.RIGHT
	else:
		x_axis = x_axis.normalized()
	var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
	if y_axis.dot(Vector3.UP) < 0.0:
		x_axis = -x_axis
		y_axis = -y_axis

	var basis: Basis = Basis(
		x_axis * rail_depth,
		y_axis * vertical_thickness,
		z_axis * length
	)
	return Transform3D(basis, (from_point + to_point) * 0.5)

static func rail_segment_length(
	track: WildDashGrandPrixV2Track,
	route: Array[Vector3],
	from_index: int,
	to_index: int,
	side: float,
	rail_depth: float,
	height: float
) -> float:
	if to_index != from_index + 1 or from_index < 0 or to_index >= route.size():
		return 0.0
	return rail_anchor(track, route, from_index, side, rail_depth, height).distance_to(
		rail_anchor(track, route, to_index, side, rail_depth, height)
	)

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
	var center: Vector3 = inner + outward * (support_size * 0.5 + OUTWARD_CLEARANCE)
	center.y += support_height * 0.5
	return Transform3D(
		Basis.IDENTITY.scaled(Vector3(support_size, support_height, support_size)),
		center
	)

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

static func _safe_outward(route: Array[Vector3], point_index: int, side: float, inner: Vector3) -> Vector3:
	var outward: Vector3 = inner - route[point_index]
	outward.y = 0.0
	if outward.length_squared() <= 0.000001:
		var tangent: Vector3 = WildDashGrandPrixV2Geometry.planar_tangent_at(route, point_index)
		outward = Vector3(-tangent.z, 0.0, tangent.x) * side
	if outward.length_squared() <= 0.000001:
		return Vector3.RIGHT * side
	return outward.normalized()
