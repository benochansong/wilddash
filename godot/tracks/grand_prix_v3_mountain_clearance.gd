class_name WildDashGrandPrixV3MountainClearance
extends Node

## Grand Prix V3.4 mountain-route clearance pass.
##
## The V2 terrain ribbons are wide enough that on tight mountain switchbacks a
## later strip can fold back across the active road. Visually this looks like a
## giant slab/roof; the matching near-terrain trimesh can also become a physical
## wall. V3.4 removes those wide ribbons only in the tight mountain/canyon
## sections and replaces them with narrow route-local side aprons that cannot
## span across the road.

const TERRAIN_CHUNK_LENGTH: float = 100.0
const PROBLEM_SECTIONS: Array[StringName] = [
	&"mountain_approach",
	&"mountain_ascent",
	&"summit_ridge",
	&"rough_descent",
	&"canyon_obstacle",
]

const SAFE_APRON_WIDTHS: Dictionary = {
	&"mountain_approach": 4.8,
	&"mountain_ascent": 4.2,
	&"summit_ridge": 3.8,
	&"rough_descent": 4.4,
	&"canyon_obstacle": 3.4,
}

const APRON_INSET: float = 0.18
const APRON_OUTER_DROP: float = 0.10

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _section_ranges: Dictionary = {}
var _terrain_shell: Node
var _grounding_world: Node
var _replacement_root: Node3D
var _sanitized_chunks: Array[int] = []
var _replacement_collision_shapes: int = 0

func _ready() -> void:
	process_priority = 127
	call_deferred("_configure_when_ready")

func _configure_when_ready() -> void:
	for _frame: int in range(12):
		await get_tree().process_frame
	_track = _find_v2_track(get_parent())
	if _track == null:
		push_warning("GrandPrixV3MountainClearance: V2 track unavailable")
		return
	_route = _track.get_route_points()
	_section_ranges = _track.get_v2_section_ranges()
	_terrain_shell = _find_named_recursive(get_parent(), "V2TerrainShell")
	_grounding_world = _find_named_recursive(get_parent(), "V2GroundingWorld")
	if _route.size() < 2 or _section_ranges.is_empty():
		push_warning("GrandPrixV3MountainClearance: route/section data unavailable")
		return

	var chunk_ranges: Array[Vector2i] = _build_chunk_ranges()
	_sanitize_problem_chunks(chunk_ranges)
	_build_safe_problem_aprons()
	print("GRAND PRIX V3.4 MOUNTAIN CLEARANCE READY chunks=%s wide_terrain_hidden=true near_collision_disabled=true replacement_shapes=%d camera_occlusion_source_reduced=true" % [
		str(_sanitized_chunks),
		_replacement_collision_shapes,
	])

func _build_chunk_ranges() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var start_point: int = 0
	var distance: float = 0.0
	for segment_index: int in range(_route.size() - 1):
		distance += _route[segment_index].distance_to(_route[segment_index + 1])
		if distance >= TERRAIN_CHUNK_LENGTH and segment_index + 1 < _route.size() - 1:
			result.append(Vector2i(start_point, segment_index + 1))
			start_point = segment_index + 1
			distance = 0.0
	if start_point < _route.size() - 1:
		result.append(Vector2i(start_point, _route.size() - 1))
	return result

func _sanitize_problem_chunks(chunk_ranges: Array[Vector2i]) -> void:
	for chunk_index: int in range(chunk_ranges.size()):
		var point_range: Vector2i = chunk_ranges[chunk_index]
		if not _range_hits_problem_section(point_range):
			continue
		_sanitized_chunks.append(chunk_index)
		_hide_terrain_chunk_visuals(chunk_index)
		_disable_terrain_chunk_collision(chunk_index)
		_hide_grounding_skirt(chunk_index)

func _range_hits_problem_section(point_range: Vector2i) -> bool:
	for section_id: StringName in PROBLEM_SECTIONS:
		if not _section_ranges.has(section_id):
			continue
		var section_range: Vector2i = _section_ranges[section_id] as Vector2i
		var section_end: int = section_range.y + 1
		if point_range.y >= section_range.x and point_range.x <= section_end:
			return true
	return false

func _hide_terrain_chunk_visuals(chunk_index: int) -> void:
	if _terrain_shell == null:
		return
	var chunk: Node = _terrain_shell.get_node_or_null("V2SpatialChunk_%02d" % chunk_index)
	if chunk == null:
		return
	var terrain: Node = chunk.get_node_or_null("Terrain")
	if terrain == null:
		return
	for visual_name: String in ["NearTerrain", "FarTerrain"]:
		var visual: Node = terrain.get_node_or_null(visual_name)
		if visual is VisualInstance3D:
			(visual as VisualInstance3D).visible = false

func _disable_terrain_chunk_collision(chunk_index: int) -> void:
	if _terrain_shell == null:
		return
	var collision_root: Node = _terrain_shell.get_node_or_null("V2NearTerrainCollision")
	if collision_root == null:
		return
	var collision: CollisionShape3D = collision_root.get_node_or_null("NearTerrainCollision_%02d" % chunk_index) as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", true)

func _hide_grounding_skirt(chunk_index: int) -> void:
	if _grounding_world == null:
		return
	var chunk: Node = _grounding_world.get_node_or_null("V2GroundingChunk_%02d" % chunk_index)
	if chunk == null:
		return
	var skirt: Node = chunk.get_node_or_null("GroundMass/TerrainSkirt")
	if skirt is VisualInstance3D:
		(skirt as VisualInstance3D).visible = false

func _build_safe_problem_aprons() -> void:
	_replacement_root = Node3D.new()
	_replacement_root.name = "V34SafeMountainAprons"
	get_parent().add_child(_replacement_root)

	for section_id: StringName in PROBLEM_SECTIONS:
		if not _section_ranges.has(section_id):
			continue
		var section_range: Vector2i = _section_ranges[section_id] as Vector2i
		var start_segment: int = clampi(section_range.x, 0, _route.size() - 2)
		var end_segment: int = clampi(section_range.y, start_segment, _route.size() - 2)
		var apron_width: float = float(SAFE_APRON_WIDTHS.get(section_id, 4.0))
		var mesh: ArrayMesh = _build_section_apron_mesh(start_segment, end_segment, apron_width)
		if mesh.get_surface_count() == 0:
			continue
		_add_apron_visual(section_id, mesh)
		_add_apron_collision(section_id, mesh)

func _build_section_apron_mesh(start_segment: int, end_segment: int, apron_width: float) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()

	for segment_index: int in range(start_segment, end_segment + 1):
		if segment_index + 1 >= _route.size():
			break
		for side: float in [-1.0, 1.0]:
			var edge0: Vector3 = _track.get_v2_shoulder_edge_point(segment_index, side)
			var edge1: Vector3 = _track.get_v2_shoulder_edge_point(segment_index + 1, side)
			var right0: Vector3 = _right_at(segment_index)
			var right1: Vector3 = _right_at(segment_index + 1)
			var inner0: Vector3 = edge0 - right0 * side * APRON_INSET + Vector3.UP * 0.015
			var inner1: Vector3 = edge1 - right1 * side * APRON_INSET + Vector3.UP * 0.015
			var outer0: Vector3 = edge0 + right0 * side * apron_width - Vector3.UP * APRON_OUTER_DROP
			var outer1: Vector3 = edge1 + right1 * side * apron_width - Vector3.UP * APRON_OUTER_DROP
			var base: int = vertices.size()
			vertices.append(inner0)
			vertices.append(outer0)
			vertices.append(inner1)
			vertices.append(outer1)
			for _normal_index: int in range(4):
				normals.append(Vector3.UP)
			uvs.append(Vector2(0.0, 0.0))
			uvs.append(Vector2(1.0, 0.0))
			uvs.append(Vector2(0.0, 1.0))
			uvs.append(Vector2(1.0, 1.0))
			indices.append_array(PackedInt32Array([
				base, base + 1, base + 2,
				base + 1, base + 3, base + 2,
			]))

	var mesh: ArrayMesh = ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _add_apron_visual(section_id: StringName, mesh: ArrayMesh) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "SafeApron_%s" % String(section_id)
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = StandardMaterial3D.new()
	match section_id:
		&"canyon_obstacle": material.albedo_color = Color(0.30, 0.22, 0.16)
		&"summit_ridge": material.albedo_color = Color(0.38, 0.39, 0.36)
		_: material.albedo_color = Color(0.28, 0.30, 0.24)
	material.roughness = 0.96
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	_replacement_root.add_child(instance)

func _add_apron_collision(section_id: StringName, mesh: ArrayMesh) -> void:
	var shape: Shape3D = mesh.create_trimesh_shape()
	if shape == null:
		return
	if shape is ConcavePolygonShape3D:
		(shape as ConcavePolygonShape3D).backface_collision = true
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "SafeApronCollision_%s" % String(section_id)
	body.collision_layer = 1
	body.collision_mask = 0
	_replacement_root.add_child(body)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	_replacement_collision_shapes += 1

func _right_at(point_index: int) -> Vector3:
	if _route.size() < 2:
		return Vector3.RIGHT
	var tangent: Vector3
	if point_index <= 0:
		tangent = _route[1] - _route[0]
	elif point_index >= _route.size() - 1:
		tangent = _route[-1] - _route[-2]
	else:
		tangent = _route[point_index + 1] - _route[point_index - 1]
	tangent.y = 0.0
	if tangent.length_squared() <= 0.001:
		return Vector3.RIGHT
	tangent = tangent.normalized()
	return Vector3(-tangent.z, 0.0, tangent.x).normalized()

func _find_v2_track(root: Node) -> WildDashGrandPrixV2Track:
	if root == null:
		return null
	if root is WildDashGrandPrixV2Track:
		return root as WildDashGrandPrixV2Track
	for child: Node in root.get_children():
		var found: WildDashGrandPrixV2Track = _find_v2_track(child)
		if found != null:
			return found
	return null

func _find_named_recursive(root: Node, target_name: String) -> Node:
	if root == null:
		return null
	if String(root.name) == target_name:
		return root
	for child: Node in root.get_children():
		var found: Node = _find_named_recursive(child, target_name)
		if found != null:
			return found
	return null
