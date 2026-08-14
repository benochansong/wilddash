class_name WildDashGrandPrixV2CourseGuidance
extends Node3D

## V2.7 HARD RESET guardrail diagnostic.
## Do not build the 2.6 km visual rail yet. This script intentionally renders
## exactly four Meadow posts and two rails so post A -> post B can be verified
## on screen before any scaling/chunking/MultiMesh work resumes.

const VISUAL_OWNER_GROUP: StringName = &"wilddash_guardrail_visual_owner"
const PROTOTYPE_POINT_A: int = 0
const PROTOTYPE_POINT_B: int = 1
const SAFE_GAP: float = 0.75
const POST_SIZE: float = 0.30
const POST_HEIGHT: float = 1.25
const RAIL_DEPTH: float = 0.18
const RAIL_THICKNESS: float = 0.18
const RAIL_HEIGHT: float = 0.92
const ENDPOINT_TOLERANCE: float = 0.05
const MAX_REASONABLE_RAIL_SEGMENT: float = 18.0

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _ranges: Dictionary = {}
var _visual_root: Node3D
var _collision_body: StaticBody3D
var _barrier_collision_shape_count: int = 0
var _visual_mesh_count: int = 0
var _rail_segment_count: int = 0
var _post_count: int = 0
var _left_posts: int = 0
var _right_posts: int = 0
var _left_rails: int = 0
var _right_rails: int = 0
var _non_adjacent_links: int = 0
var _cross_side_links: int = 0
var _max_endpoint_error: float = 0.0
var _max_rail_segment_length: float = 0.0

func _ready() -> void:
	add_to_group(VISUAL_OWNER_GROUP)
	if DisplayServer.get_name() == "headless":
		return
	call_deferred("_build_when_ready")

func _build_when_ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_track = _find_v2_track(get_parent())
	if _track == null:
		push_error("GrandPrixV2CourseGuidance V2.7: V2 track unavailable")
		return
	_route = _track.get_route_points()
	_ranges = _track.get_v2_section_ranges()
	if _route.size() <= PROTOTYPE_POINT_B:
		push_error("GrandPrixV2CourseGuidance V2.7: route too short for prototype")
		return

	_visual_root = Node3D.new()
	_visual_root.name = "V27GuardrailPrototype"
	add_child(_visual_root)

	_collision_body = StaticBody3D.new()
	_collision_body.name = "V27BarrierCollision"
	_collision_body.collision_layer = 1
	_collision_body.collision_mask = 0
	add_child(_collision_body)

	_build_full_collision_only()
	_build_meadow_two_post_prototype()
	call_deferred("_report_owner_and_geometry")

func get_barrier_collision_shape_count() -> int:
	return _barrier_collision_shape_count

func get_barrier_chunk_count() -> int:
	return 1

func get_barrier_mesh_count() -> int:
	return _visual_mesh_count

func get_rail_segment_count() -> int:
	return _rail_segment_count

func get_post_count() -> int:
	return _post_count

func get_max_rail_segment_length() -> float:
	return _max_rail_segment_length

func get_max_endpoint_error() -> float:
	return _max_endpoint_error

func get_non_adjacent_link_count() -> int:
	return _non_adjacent_links

func get_cross_side_link_count() -> int:
	return _cross_side_links

func _build_meadow_two_post_prototype() -> void:
	var left_positions: Array[Vector3] = [
		_post_base_position(PROTOTYPE_POINT_A, -1.0),
		_post_base_position(PROTOTYPE_POINT_B, -1.0),
	]
	var right_positions: Array[Vector3] = [
		_post_base_position(PROTOTYPE_POINT_A, 1.0),
		_post_base_position(PROTOTYPE_POINT_B, 1.0),
	]

	_add_post("LeftPost_000", left_positions[0], _debug_material(Color(0.95, 0.08, 0.08)))
	_add_post("LeftPost_001", left_positions[1], _debug_material(Color(0.95, 0.08, 0.08)))
	_left_posts = 2
	_add_post("RightPost_000", right_positions[0], _debug_material(Color(0.08, 0.20, 0.95)))
	_add_post("RightPost_001", right_positions[1], _debug_material(Color(0.08, 0.20, 0.95)))
	_right_posts = 2

	_add_rail_between_posts(
		"LeftRail_000_001", left_positions[0], left_positions[1], -1.0,
		PROTOTYPE_POINT_A, PROTOTYPE_POINT_B, _debug_material(Color(1.0, 0.88, 0.05))
	)
	_left_rails = 1
	_add_rail_between_posts(
		"RightRail_000_001", right_positions[0], right_positions[1], 1.0,
		PROTOTYPE_POINT_A, PROTOTYPE_POINT_B, _debug_material(Color(0.05, 0.90, 0.95))
	)
	_right_rails = 1

func _post_base_position(point_index: int, side: float) -> Vector3:
	var shoulder: Vector3 = _track.get_v2_shoulder_edge_point(point_index, side)
	var outward: Vector3 = shoulder - _route[point_index]
	outward.y = 0.0
	if outward.length_squared() <= 0.000001:
		var tangent: Vector3 = WildDashGrandPrixV2Geometry.planar_tangent_at(_route, point_index)
		outward = Vector3(-tangent.z, 0.0, tangent.x) * side
	outward = outward.normalized()
	var result: Vector3 = shoulder + outward * (SAFE_GAP + POST_SIZE * 0.5)
	result.y = shoulder.y + 0.02
	return result

func _add_post(node_name: String, base_position: Vector3, material: Material) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(POST_SIZE, POST_HEIGHT, POST_SIZE)
	var post: MeshInstance3D = MeshInstance3D.new()
	post.name = node_name
	post.mesh = mesh
	post.material_override = material
	post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	post.position = base_position + Vector3.UP * POST_HEIGHT * 0.5
	_visual_root.add_child(post)
	_post_count += 1
	_visual_mesh_count += 1

func _add_rail_between_posts(
	node_name: String,
	post_a_base: Vector3,
	post_b_base: Vector3,
	side: float,
	from_index: int,
	to_index: int,
	material: Material
) -> void:
	if to_index != from_index + 1:
		_non_adjacent_links += 1
		push_error("V2.7 rejected non-adjacent guardrail link %d -> %d" % [from_index, to_index])
		return
	if side != -1.0 and side != 1.0:
		_cross_side_links += 1
		push_error("V2.7 rejected invalid guardrail side %.1f" % side)
		return

	var from_point: Vector3 = post_a_base + Vector3.UP * RAIL_HEIGHT
	var to_point: Vector3 = post_b_base + Vector3.UP * RAIL_HEIGHT
	var delta: Vector3 = to_point - from_point
	var length: float = delta.length()
	if length <= 0.001:
		push_error("V2.7 rejected zero-length guardrail segment")
		return
	if length > MAX_REASONABLE_RAIL_SEGMENT:
		push_error("V2.7 rejected unexpectedly long adjacent guardrail %.2fm" % length)
		return

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

	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(RAIL_DEPTH, RAIL_THICKNESS, length)
	var rail: MeshInstance3D = MeshInstance3D.new()
	rail.name = node_name
	rail.mesh = mesh
	rail.material_override = material
	rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rail.transform = Transform3D(Basis(x_axis, y_axis, z_axis), (from_point + to_point) * 0.5)
	_visual_root.add_child(rail)

	var actual_a: Vector3 = rail.position - rail.transform.basis.z * (length * 0.5)
	var actual_b: Vector3 = rail.position + rail.transform.basis.z * (length * 0.5)
	var endpoint_error: float = maxf(actual_a.distance_to(from_point), actual_b.distance_to(to_point))
	_max_endpoint_error = maxf(_max_endpoint_error, endpoint_error)
	_max_rail_segment_length = maxf(_max_rail_segment_length, length)
	_rail_segment_count += 1
	_visual_mesh_count += 1
	if endpoint_error > ENDPOINT_TOLERANCE:
		push_error("V2.7 guardrail endpoint error %.3fm exceeds %.3fm" % [endpoint_error, ENDPOINT_TOLERANCE])

func _build_full_collision_only() -> void:
	for section: WildDashGrandPrixV2Section in _track.get_v2_sections():
		if not _ranges.has(section.id):
			continue
		var section_range: Vector2i = _ranges[section.id] as Vector2i
		var start_point: int = clampi(section_range.x, 0, _route.size() - 2)
		var end_point: int = clampi(section_range.y + 1, start_point + 1, _route.size() - 1)
		var mesh: ArrayMesh = _build_inner_collision_mesh(start_point, end_point, 1.1)
		if mesh.get_surface_count() == 0:
			continue
		var shape: Shape3D = mesh.create_trimesh_shape()
		if shape == null:
			continue
		if shape is ConcavePolygonShape3D:
			(shape as ConcavePolygonShape3D).backface_collision = true
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.name = "BarrierCollision_%s" % String(section.id)
		collision.shape = shape
		_collision_body.add_child(collision)
		_barrier_collision_shape_count += 1

func _build_inner_collision_mesh(start_point: int, end_point: int, height: float) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for side: float in [-1.0, 1.0]:
		for point_index: int in range(start_point, end_point):
			var p0: Vector3 = _track.get_v2_barrier_inner_face_point(point_index, side)
			var p1: Vector3 = _track.get_v2_barrier_inner_face_point(point_index + 1, side)
			var base: int = vertices.size()
			vertices.append(p0 + Vector3.UP * 0.04)
			vertices.append(p1 + Vector3.UP * 0.04)
			vertices.append(p0 + Vector3.UP * height)
			vertices.append(p1 + Vector3.UP * height)
			indices.append_array(PackedInt32Array([
				base, base + 2, base + 1,
				base + 1, base + 2, base + 3,
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

func _report_owner_and_geometry() -> void:
	await get_tree().process_frame
	var owners: Array[Node] = get_tree().get_nodes_in_group(VISUAL_OWNER_GROUP)
	print("GRAND PRIX GUARDRAIL OWNER CHECK visual_guardrail_owners=%d owner=%s" % [
		owners.size(), name if owners.size() == 1 else "INVALID",
	])
	print("GRAND PRIX V2.7 POST RAIL VERIFIED visual_guardrail_owners=%d left_posts=%d right_posts=%d left_rails=%d right_rails=%d non_adjacent_links=%d cross_side_links=%d max_endpoint_error=%.4fm max_segment_length=%.2fm multimesh_debug_phase=false prototype_points=%d->%d visual_meshes=%d collision_shapes=%d" % [
		owners.size(), _left_posts, _right_posts, _left_rails, _right_rails,
		_non_adjacent_links, _cross_side_links, _max_endpoint_error,
		_max_rail_segment_length, PROTOTYPE_POINT_A, PROTOTYPE_POINT_B,
		_visual_mesh_count, _barrier_collision_shape_count,
	])
	if owners.size() != 1:
		push_error("V2.7 guardrail owner check failed: expected exactly one visual owner")
	if _left_posts != 2 or _right_posts != 2 or _left_rails != 1 or _right_rails != 1:
		push_error("V2.7 Meadow minimal visual must remain exactly 4 posts + 2 rails")
	if _non_adjacent_links != 0 or _cross_side_links != 0 or _max_endpoint_error > ENDPOINT_TOLERANCE:
		push_error("V2.7 Meadow minimal guardrail geometry verification failed")

func _debug_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _find_v2_track(node: Node) -> WildDashGrandPrixV2Track:
	if node is WildDashGrandPrixV2Track:
		return node as WildDashGrandPrixV2Track
	for child: Node in node.get_children():
		var found: WildDashGrandPrixV2Track = _find_v2_track(child)
		if found != null:
			return found
	return null
