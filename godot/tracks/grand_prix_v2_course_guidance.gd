class_name WildDashGrandPrixV2CourseGuidance
extends Node3D

## V2.5 section barrier system.
## Barriers consume the exact same averaged-tangent/miter edge points as the
## road and shoulder. No beam extends beyond shared endpoints, so rails cannot
## spear across the playable road on corners.

const SMALL_BEAM_OVERLAP: float = 0.06
const SUPPORT_STEP: int = 2

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _ranges: Dictionary = {}
var _barrier_collision_body: StaticBody3D
var _barrier_collision_shape_count: int = 0
var _barrier_chunk_count: int = 0

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	call_deferred("_build_when_ready")

func _build_when_ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_track = _find_v2_track(get_parent())
	if _track == null:
		push_warning("GrandPrixV2CourseGuidance: V2 track unavailable")
		return
	_route = _track.get_route_points()
	_ranges = _track.get_v2_section_ranges()
	if _route.size() < 2:
		return

	_barrier_collision_body = StaticBody3D.new()
	_barrier_collision_body.name = "V2VisibleBarrierCollision"
	_barrier_collision_body.collision_layer = 1
	_barrier_collision_body.collision_mask = 0
	add_child(_barrier_collision_body)

	for section: WildDashGrandPrixV2Section in _track.get_v2_sections():
		_build_section_barrier(section.id)

	print("GRAND PRIX V2.5 BARRIERS READY sections=%d chunks=%d collision_shapes=%d shared_edge_geometry=true symmetric_color=true endpoint_shared=true inner_face_collision=true" % [
		_track.get_v2_sections().size(), _barrier_chunk_count, _barrier_collision_shape_count,
	])
	call_deferred("_report_performance_once")

func get_barrier_collision_shape_count() -> int:
	return _barrier_collision_shape_count

func get_barrier_chunk_count() -> int:
	return _barrier_chunk_count

func _build_section_barrier(section_id: StringName) -> void:
	if not _ranges.has(section_id):
		return
	var section_range: Vector2i = _ranges[section_id] as Vector2i
	var start_point: int = clampi(section_range.x, 0, _route.size() - 2)
	var end_point: int = clampi(section_range.y + 1, start_point + 1, _route.size() - 1)
	var profile: StringName = WildDashGrandPrixV2Geometry.barrier_profile_for_section(section_id)
	var style: Dictionary = _style_for_profile(profile)
	var upper_transforms: Array[Transform3D] = []
	var lower_transforms: Array[Transform3D] = []
	var support_transforms: Array[Transform3D] = []

	for side: float in [-1.0, 1.0]:
		for point_index: int in range(start_point, end_point):
			var from_point: Vector3 = _track.get_v2_barrier_point(point_index, side)
			var to_point: Vector3 = _track.get_v2_barrier_point(point_index + 1, side)
			var upper_height: float = float(style.get("upper_height", 0.0))
			var upper_width: float = float(style.get("upper_width", 0.0))
			var upper_thickness: float = float(style.get("upper_thickness", 0.0))
			if upper_height > 0.0 and upper_width > 0.0:
				upper_transforms.append(_beam_transform(
					from_point + Vector3.UP * upper_height,
					to_point + Vector3.UP * upper_height,
					upper_width,
					upper_thickness
				))
			var lower_height: float = float(style.get("lower_height", 0.0))
			var lower_width: float = float(style.get("lower_width", 0.0))
			var lower_thickness: float = float(style.get("lower_thickness", 0.0))
			if lower_height > 0.0 and lower_width > 0.0:
				lower_transforms.append(_beam_transform(
					from_point + Vector3.UP * lower_height,
					to_point + Vector3.UP * lower_height,
					lower_width,
					lower_thickness
				))

		for point_index: int in range(start_point, end_point + 1, SUPPORT_STEP):
			if not bool(style.get("supports", true)):
				break
			var point: Vector3 = _track.get_v2_barrier_point(point_index, side)
			var support_height: float = float(style.get("support_height", 1.0))
			var support_size: float = float(style.get("support_size", 0.22))
			var transform: Transform3D = Transform3D(
				Basis.IDENTITY.scaled(Vector3(support_size, support_height, support_size)),
				point + Vector3.UP * support_height * 0.5
			)
			support_transforms.append(transform)

	var primary_material: Material = _material_for_profile(profile, true)
	var structure_material: Material = _material_for_profile(profile, false)
	_add_multimesh("Barrier_%s_Upper" % String(section_id), upper_transforms, primary_material)
	_add_multimesh("Barrier_%s_Lower" % String(section_id), lower_transforms, structure_material)
	_add_multimesh("Barrier_%s_Posts" % String(section_id), support_transforms, structure_material)
	_add_section_barrier_collision(section_id, profile, start_point, end_point, float(style.get("collision_height", 0.9)))
	_barrier_chunk_count += 1

func _add_section_barrier_collision(
	section_id: StringName,
	profile: StringName,
	start_point: int,
	end_point: int,
	height: float
) -> void:
	if height <= 0.0:
		return
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for side: float in [-1.0, 1.0]:
		for point_index: int in range(start_point, end_point):
			# Gameplay collision sits on the visual barrier's inner face, so a thick
			# river bank or rock wall cannot visually occupy playable shoulder space.
			var p0: Vector3 = WildDashGrandPrixV2Geometry.barrier_inner_face_point(
				_route, _track._v2_segment_widths, _track._v2_segment_sections, point_index, side
			)
			var p1: Vector3 = WildDashGrandPrixV2Geometry.barrier_inner_face_point(
				_route, _track._v2_segment_widths, _track._v2_segment_sections, point_index + 1, side
			)
			var base_index: int = vertices.size()
			vertices.append(p0 + Vector3.UP * 0.05)
			vertices.append(p1 + Vector3.UP * 0.05)
			vertices.append(p0 + Vector3.UP * height)
			vertices.append(p1 + Vector3.UP * height)
			indices.append(base_index)
			indices.append(base_index + 2)
			indices.append(base_index + 1)
			indices.append(base_index + 1)
			indices.append(base_index + 2)
			indices.append(base_index + 3)

	if vertices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shape: Shape3D = mesh.create_trimesh_shape()
	if shape == null:
		return
	if shape is ConcavePolygonShape3D:
		(shape as ConcavePolygonShape3D).backface_collision = true
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "BarrierCollision_%s_%s" % [String(section_id), String(profile)]
	collision.shape = shape
	_barrier_collision_body.add_child(collision)
	_barrier_collision_shape_count += 1

func _style_for_profile(profile: StringName) -> Dictionary:
	match profile:
		&"wood_fence":
			return {
				"upper_height": 0.92, "upper_width": 0.22, "upper_thickness": 0.18,
				"lower_height": 0.46, "lower_width": 0.16, "lower_thickness": 0.14,
				"support_height": 1.12, "support_size": 0.20, "supports": true,
				"collision_height": 1.00,
			}
		&"river_bank":
			return {
				"upper_height": 0.38, "upper_width": 0.58, "upper_thickness": 0.40,
				"lower_height": 0.0, "lower_width": 0.0, "lower_thickness": 0.0,
				"support_height": 0.0, "support_size": 0.0, "supports": false,
				"collision_height": 0.68,
			}
		&"rock_border":
			return {
				"upper_height": 0.48, "upper_width": 0.54, "upper_thickness": 0.42,
				"lower_height": 0.0, "lower_width": 0.0, "lower_thickness": 0.0,
				"support_height": 0.0, "support_size": 0.0, "supports": false,
				"collision_height": 0.82,
			}
		&"rope_or_wood":
			return {
				"upper_height": 0.94, "upper_width": 0.13, "upper_thickness": 0.12,
				"lower_height": 0.50, "lower_width": 0.10, "lower_thickness": 0.10,
				"support_height": 1.18, "support_size": 0.18, "supports": true,
				"collision_height": 0.86,
			}
		&"rock_wall":
			return {
				"upper_height": 0.68, "upper_width": 0.78, "upper_thickness": 0.70,
				"lower_height": 0.30, "lower_width": 0.70, "lower_thickness": 0.52,
				"support_height": 0.0, "support_size": 0.0, "supports": false,
				"collision_height": 1.24,
			}
		_:
			return {
				"upper_height": 1.12, "upper_width": 0.28, "upper_thickness": 0.24,
				"lower_height": 0.57, "lower_width": 0.20, "lower_thickness": 0.17,
				"support_height": 1.24, "support_size": 0.22, "supports": true,
				"collision_height": 1.12,
			}

func _material_for_profile(profile: StringName, primary: bool) -> Material:
	match profile:
		&"wood_fence":
			return _make_material(Color(0.43, 0.25, 0.10), 0.78, 0.02)
		&"river_bank":
			return _make_material(Color(0.36, 0.37, 0.32), 0.92, 0.0)
		&"rock_border", &"rock_wall":
			return _make_material(Color(0.31, 0.32, 0.31), 0.94, 0.0)
		&"rope_or_wood":
			return _make_material(Color(0.58, 0.40, 0.18) if primary else Color(0.34, 0.20, 0.09), 0.86, 0.0)
		_:
			return _make_material(Color(0.08, 0.82, 0.72) if primary else Color(0.22, 0.19, 0.14), 0.44, 0.14)

func _beam_transform(from: Vector3, to: Vector3, width: float, height: float) -> Transform3D:
	var distance: float = from.distance_to(to)
	var midpoint: Vector3 = (from + to) * 0.5
	var transform: Transform3D = Transform3D(Basis.IDENTITY, midpoint)
	transform = transform.looking_at(to, Vector3.UP)
	transform.basis = transform.basis.scaled(Vector3(width, height, distance + SMALL_BEAM_OVERLAP))
	return transform

func _add_multimesh(node_name: String, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3.ONE
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	multimesh.custom_aabb = _tight_aabb(transforms, 8.0)
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	add_child(instance)

func _tight_aabb(transforms: Array[Transform3D], margin: float) -> AABB:
	var minimum: Vector3 = transforms[0].origin
	var maximum: Vector3 = transforms[0].origin
	for transform: Transform3D in transforms:
		minimum.x = minf(minimum.x, transform.origin.x)
		minimum.y = minf(minimum.y, transform.origin.y)
		minimum.z = minf(minimum.z, transform.origin.z)
		maximum.x = maxf(maximum.x, transform.origin.x)
		maximum.y = maxf(maximum.y, transform.origin.y)
		maximum.z = maxf(maximum.z, transform.origin.z)
	var padding: Vector3 = Vector3.ONE * margin
	return AABB(minimum - padding, maximum - minimum + padding * 2.0)

func _find_v2_track(node: Node) -> WildDashGrandPrixV2Track:
	if node is WildDashGrandPrixV2Track:
		return node as WildDashGrandPrixV2Track
	for child: Node in node.get_children():
		var found: WildDashGrandPrixV2Track = _find_v2_track(child)
		if found != null:
			return found
	return null

func _report_performance_once() -> void:
	await get_tree().create_timer(1.5).timeout
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var node_count: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var draw_calls: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var physics_objects: float = Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	print("GRAND PRIX V2 BARRIER PERF fps=%.1f guardrail_chunks=%d barrier_collision_shapes=%d monitor_nodes=%.0f draw_calls=%.0f physics_active=%.0f" % [
		fps, _barrier_chunk_count, _barrier_collision_shape_count, node_count, draw_calls, physics_objects,
	])

func _make_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
