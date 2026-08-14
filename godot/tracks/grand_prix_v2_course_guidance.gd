class_name WildDashGrandPrixV2CourseGuidance
extends Node3D

## V2.8 natural-boundary mode.
## All visible guardrail rails/posts are intentionally removed from Round 1.
## Safety remains through invisible collision walls derived from the authoritative
## barrier inner-face polyline. Natural terrain will carry the visual boundary.

const VISUAL_OWNER_GROUP: StringName = &"wilddash_guardrail_visual_owner"

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _ranges: Dictionary = {}
var _collision_body: StaticBody3D
var _barrier_collision_shape_count: int = 0
var _collision_enabled: bool = true

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	call_deferred("_build_when_ready")

func _build_when_ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_track = _find_v2_track(get_parent())
	if _track == null:
		push_error("GrandPrixV2CourseGuidance V2.8: V2 track unavailable")
		return
	_route = _track.get_route_points()
	_ranges = _track.get_v2_section_ranges()
	if _route.size() < 2:
		return

	_collision_body = StaticBody3D.new()
	_collision_body.name = "V28InvisibleSafetyBarrier"
	_collision_body.collision_layer = 1
	_collision_body.collision_mask = 0
	add_child(_collision_body)
	_build_full_collision_only()
	_report_state()

func get_barrier_collision_shape_count() -> int:
	return _barrier_collision_shape_count

func get_barrier_chunk_count() -> int:
	return 0

func get_barrier_mesh_count() -> int:
	return 0

func get_rail_segment_count() -> int:
	return 0

func get_post_count() -> int:
	return 0

func get_max_rail_segment_length() -> float:
	return 0.0

func get_max_endpoint_error() -> float:
	return 0.0

func get_non_adjacent_link_count() -> int:
	return 0

func get_cross_side_link_count() -> int:
	return 0

func is_barrier_collision_enabled() -> bool:
	return _collision_enabled

func set_barrier_collision_enabled(enabled: bool) -> void:
	_collision_enabled = enabled
	if _collision_body == null:
		return
	for child: Node in _collision_body.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", not enabled)

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

func _report_state() -> void:
	await get_tree().process_frame
	var owners: Array[Node] = get_tree().get_nodes_in_group(VISUAL_OWNER_GROUP)
	print("GRAND PRIX V2.8 NATURAL BARRIER MODE visual_guardrail_owners=%d visual_guardrail_meshes=0 posts=0 rails=0 collision_shapes=%d collision_enabled=%s natural_boundary_visuals=true" % [
		owners.size(), _barrier_collision_shape_count, str(_collision_enabled),
	])
	if owners.size() != 0:
		push_error("V2.8 expected zero visible guardrail owners, got %d" % owners.size())

func _find_v2_track(node: Node) -> WildDashGrandPrixV2Track:
	if node is WildDashGrandPrixV2Track:
		return node as WildDashGrandPrixV2Track
	for child: Node in node.get_children():
		var found: WildDashGrandPrixV2Track = _find_v2_track(child)
		if found != null:
			return found
	return null
