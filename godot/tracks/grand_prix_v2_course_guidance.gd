class_name WildDashGrandPrixV2CourseGuidance
extends Node3D

## V2.6 guardrail recovery.
## Visual rails are now intentionally simple: one post at every sampled route
## point and one BoxMesh rail ONLY between adjacent posts N -> N+1. The previous
## swept ArrayMesh/miter/bevel path is removed because it could generate long
## cross-course faces. Collision still comes from the same authoritative barrier
## inner-face polyline.

const SUPPORT_STEP: int = 1
const VISUAL_CHUNK_LENGTH: float = 100.0
const MAX_REASONABLE_CHUNK_AABB: float = 190.0
const MAX_REASONABLE_RAIL_SEGMENT: float = 18.0

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _ranges: Dictionary = {}
var _barrier_collision_body: StaticBody3D
var _barrier_collision_shape_count: int = 0
var _barrier_chunk_count: int = 0
var _barrier_multimesh_count: int = 0
var _rail_segment_count: int = 0
var _post_count: int = 0
var _max_rail_segment_length: float = 0.0

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

	print("GRAND PRIX V2.6 POST-TO-POST BARRIERS READY sections=%d chunks=%d multimeshes=%d rail_segments=%d posts=%d max_segment=%.2fm collision_shapes=%d support_step=%d adjacent_only=true swept_mesh=false miter=false bevel=false" % [
		_track.get_v2_sections().size(), _barrier_chunk_count, _barrier_multimesh_count,
		_rail_segment_count, _post_count, _max_rail_segment_length,
		_barrier_collision_shape_count, SUPPORT_STEP,
	])
	call_deferred("_report_performance_once")

func get_barrier_collision_shape_count() -> int:
	return _barrier_collision_shape_count

func get_barrier_chunk_count() -> int:
	return _barrier_chunk_count

func get_barrier_mesh_count() -> int:
	return _barrier_multimesh_count

func get_rail_segment_count() -> int:
	return _rail_segment_count

func get_post_count() -> int:
	return _post_count

func get_max_rail_segment_length() -> float:
	return _max_rail_segment_length

func _build_section_barrier(section_id: StringName) -> void:
	if not _ranges.has(section_id):
		return
	var section_range: Vector2i = _ranges[section_id] as Vector2i
	var start_point: int = clampi(section_range.x, 0, _route.size() - 2)
	var end_point: int = clampi(section_range.y + 1, start_point + 1, _route.size() - 1)
	var profile: StringName = WildDashGrandPrixV2Geometry.barrier_profile_for_section(section_id)
	var style: Dictionary = _style_for_profile(profile)
	var chunks: Array[Vector2i] = _visual_chunk_ranges(start_point, end_point)
	for point_range: Vector2i in chunks:
		_build_visual_chunk(section_id, profile, style, point_range.x, point_range.y, _barrier_chunk_count)
		_barrier_chunk_count += 1
	_add_section_barrier_collision(section_id, profile, start_point, end_point, float(style.get("collision_height", 0.9)))

func _visual_chunk_ranges(start_point: int, end_point: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var chunk_start: int = start_point
	var distance: float = 0.0
	for point_index: int in range(start_point, end_point):
		distance += _route[point_index].distance_to(_route[point_index + 1])
		if distance >= VISUAL_CHUNK_LENGTH and point_index + 1 < end_point:
			result.append(Vector2i(chunk_start, point_index + 1))
			chunk_start = point_index + 1
			distance = 0.0
	if chunk_start < end_point:
		result.append(Vector2i(chunk_start, end_point))
	return result

func _build_visual_chunk(
	section_id: StringName,
	profile: StringName,
	style: Dictionary,
	start_point: int,
	end_point: int,
	chunk_index: int
) -> void:
	var upper_transforms: Array[Transform3D] = []
	var lower_transforms: Array[Transform3D] = []
	var post_transforms: Array[Transform3D] = []
	var upper_height: float = float(style.get("upper_height", 0.0))
	var upper_depth: float = float(style.get("upper_width", 0.0))
	var upper_thickness: float = float(style.get("upper_thickness", 0.0))
	var lower_height: float = float(style.get("lower_height", 0.0))
	var lower_depth: float = float(style.get("lower_width", 0.0))
	var lower_thickness: float = float(style.get("lower_thickness", 0.0))
	var support_height: float = float(style.get("support_height", 1.0))
	var support_size: float = float(style.get("support_size", 0.22))

	for side: float in [-1.0, 1.0]:
		# Rails: adjacent route point only. There is no code path that can connect
		# point N to N+2, another side, another chunk, or another section.
		for point_index: int in range(start_point, end_point):
			if upper_height > 0.0 and upper_depth > 0.0 and upper_thickness > 0.0:
				upper_transforms.append(WildDashGrandPrixV2GuardrailMesh.rail_segment_transform(
					_track, _route, point_index, point_index + 1, side,
					upper_depth, upper_height, upper_thickness
				))
				_record_segment_length(point_index, side, upper_depth, upper_height)
			if lower_height > 0.0 and lower_depth > 0.0 and lower_thickness > 0.0:
				lower_transforms.append(WildDashGrandPrixV2GuardrailMesh.rail_segment_transform(
					_track, _route, point_index, point_index + 1, side,
					lower_depth, lower_height, lower_thickness
				))
				_record_segment_length(point_index, side, lower_depth, lower_height)

		if bool(style.get("supports", true)):
			for point_index: int in range(start_point, end_point + 1, SUPPORT_STEP):
				post_transforms.append(WildDashGrandPrixV2GuardrailMesh.support_transform(
					_track, _route, point_index, side, support_size, support_height
				))
				_post_count += 1

	var prefix: String = "V2GuardrailChunk_%02d_%s" % [chunk_index, String(section_id)]
	var primary_material: Material = _material_for_profile(profile, true)
	var structure_material: Material = _material_for_profile(profile, false)
	_add_box_multimesh(prefix + "_UpperRail", upper_transforms, primary_material)
	_add_box_multimesh(prefix + "_LowerRail", lower_transforms, structure_material)
	_add_box_multimesh(prefix + "_Posts", post_transforms, structure_material)

func _record_segment_length(point_index: int, side: float, depth: float, height: float) -> void:
	var length: float = WildDashGrandPrixV2GuardrailMesh.rail_segment_length(
		_track, _route, point_index, point_index + 1, side, depth, height
	)
	_rail_segment_count += 1
	_max_rail_segment_length = maxf(_max_rail_segment_length, length)
	if length > MAX_REASONABLE_RAIL_SEGMENT:
		push_warning("V2.6 long adjacent guardrail segment point=%d->%d length=%.2fm" % [
			point_index, point_index + 1, length,
		])

func _add_section_barrier_collision(section_id: StringName, profile: StringName, start_point: int, end_point: int, height: float) -> void:
	if height <= 0.0:
		return
	var mesh: ArrayMesh = WildDashGrandPrixV2GuardrailMesh.build_inner_collision_wall(
		_track, _route, start_point, end_point, height
	)
	if mesh.get_surface_count() == 0:
		return
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

func _add_box_multimesh(node_name: String, transforms: Array[Transform3D], material: Material) -> void:
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
	multimesh.custom_aabb = _tight_aabb(transforms, 1.0)
	_validate_mesh_aabb(node_name, multimesh.custom_aabb)
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_barrier_multimesh_count += 1

func _validate_mesh_aabb(node_name: String, bounds: AABB) -> void:
	if bounds.size.x > MAX_REASONABLE_CHUNK_AABB or bounds.size.z > MAX_REASONABLE_CHUNK_AABB:
		push_warning("V2.6 oversized guardrail chunk AABB %s size=(%.1f, %.1f, %.1f)" % [
			node_name, bounds.size.x, bounds.size.y, bounds.size.z,
		])

func _tight_aabb(transforms: Array[Transform3D], margin: float) -> AABB:
	var minimum: Vector3 = transforms[0].origin
	var maximum: Vector3 = transforms[0].origin
	for transform: Transform3D in transforms:
		var extents: Vector3 = Vector3(
			transform.basis.x.length(), transform.basis.y.length(), transform.basis.z.length()
		) * 0.7 + Vector3.ONE * 0.25
		minimum.x = minf(minimum.x, transform.origin.x - extents.x)
		minimum.y = minf(minimum.y, transform.origin.y - extents.y)
		minimum.z = minf(minimum.z, transform.origin.z - extents.z)
		maximum.x = maxf(maximum.x, transform.origin.x + extents.x)
		maximum.y = maxf(maximum.y, transform.origin.y + extents.y)
		maximum.z = maxf(maximum.z, transform.origin.z + extents.z)
	var padding: Vector3 = Vector3.ONE * margin
	return AABB(minimum - padding, maximum - minimum + padding * 2.0)

func _style_for_profile(profile: StringName) -> Dictionary:
	match profile:
		&"wood_fence":
			return {"upper_height": 0.92, "upper_width": 0.22, "upper_thickness": 0.18, "lower_height": 0.46, "lower_width": 0.16, "lower_thickness": 0.14, "support_height": 1.12, "support_size": 0.20, "supports": true, "collision_height": 1.00}
		&"river_bank":
			return {"upper_height": 0.38, "upper_width": 0.58, "upper_thickness": 0.40, "lower_height": 0.0, "lower_width": 0.0, "lower_thickness": 0.0, "support_height": 0.0, "support_size": 0.0, "supports": false, "collision_height": 0.68}
		&"rock_border":
			return {"upper_height": 0.48, "upper_width": 0.54, "upper_thickness": 0.42, "lower_height": 0.0, "lower_width": 0.0, "lower_thickness": 0.0, "support_height": 0.0, "support_size": 0.0, "supports": false, "collision_height": 0.82}
		&"rope_or_wood":
			return {"upper_height": 0.94, "upper_width": 0.13, "upper_thickness": 0.12, "lower_height": 0.50, "lower_width": 0.10, "lower_thickness": 0.10, "support_height": 1.18, "support_size": 0.18, "supports": true, "collision_height": 0.86}
		&"rock_wall":
			return {"upper_height": 0.68, "upper_width": 0.78, "upper_thickness": 0.70, "lower_height": 0.30, "lower_width": 0.70, "lower_thickness": 0.52, "support_height": 0.0, "support_size": 0.0, "supports": false, "collision_height": 1.24}
		_:
			return {"upper_height": 1.12, "upper_width": 0.28, "upper_thickness": 0.24, "lower_height": 0.57, "lower_width": 0.20, "lower_thickness": 0.17, "support_height": 1.24, "support_size": 0.22, "supports": true, "collision_height": 1.12}

func _material_for_profile(profile: StringName, primary: bool) -> Material:
	match profile:
		&"wood_fence": return _make_material(Color(0.43, 0.25, 0.10), 0.78, 0.02)
		&"river_bank": return _make_material(Color(0.36, 0.37, 0.32), 0.92, 0.0)
		&"rock_border", &"rock_wall": return _make_material(Color(0.31, 0.32, 0.31), 0.94, 0.0)
		&"rope_or_wood": return _make_material(Color(0.58, 0.40, 0.18) if primary else Color(0.34, 0.20, 0.09), 0.86, 0.0)
		_: return _make_material(Color(0.08, 0.82, 0.72) if primary else Color(0.22, 0.19, 0.14), 0.44, 0.14)

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
	print("GRAND PRIX V2.6 POST-TO-POST BARRIER PERF fps=%.1f chunks=%d multimeshes=%d rail_segments=%d posts=%d max_segment=%.2fm collision_shapes=%d monitor_nodes=%.0f draw_calls=%.0f physics_active=%.0f" % [
		fps, _barrier_chunk_count, _barrier_multimesh_count, _rail_segment_count,
		_post_count, _max_rail_segment_length, _barrier_collision_shape_count,
		node_count, draw_calls, physics_objects,
	])

func _make_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
