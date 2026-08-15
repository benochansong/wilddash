class_name WildDashGrandPrixV3WorldFoundation
extends Node3D

## Grand Prix V3.9 continuous land mantle.
##
## The route-height mantle is the authoritative off-road physics surface. Flat
## meadow/forest/river land stays broad and recoverable, while mountain/highland
## sections rise away from both shoulders as low-poly embankments so the road
## reads as a real hill road instead of a ribbon suspended over the sky.
## Visual and collision are generated from the same mesh.

const SHOULDER_OVERLAP: float = 0.35
const OUTER_DROP: float = 0.14
const SURFACE_LIFT: float = 0.01
const MID_DISTANCE_RATIO: float = 0.46
const MID_HEIGHT_RATIO: float = 0.36

const SECTION_LAND_WIDTHS: Dictionary = {
	&"meadow_start": 18.0,
	&"forest_obstacle": 15.0,
	&"long_river": 14.0,
	&"mountain_approach": 18.0,
	&"mountain_ascent": 20.0,
	&"summit_ridge": 16.0,
	&"rough_descent": 18.0,
	&"canyon_obstacle": 14.0,
	&"final_sprint": 18.0,
}

const SECTION_EMBANKMENT_HEIGHTS: Dictionary = {
	&"mountain_approach": 6.0,
	&"mountain_ascent": 8.0,
	&"summit_ridge": 4.5,
	&"rough_descent": 6.0,
	&"canyon_obstacle": 8.0,
}

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _mantle_root: Node3D
var _mantle_body: StaticBody3D
var _mantle_visual: MeshInstance3D
var _legacy_collision_shapes_disabled: int = 0

func _ready() -> void:
	process_priority = 124
	call_deferred("_build_when_ready")

func _build_when_ready() -> void:
	for _frame: int in range(8):
		await get_tree().process_frame
	_track = _find_v2_track(get_parent())
	if _track == null:
		push_warning("GrandPrixV3WorldFoundation: V2 track unavailable")
		return
	_route = _track.get_route_points()
	if _route.size() < 2:
		push_warning("GrandPrixV3WorldFoundation: route unavailable")
		return

	var mesh: ArrayMesh = _build_land_mantle_mesh()
	if mesh.get_surface_count() == 0:
		push_warning("GrandPrixV3WorldFoundation: mantle mesh empty")
		return

	_mantle_root = Node3D.new()
	_mantle_root.name = "V39ContinuousLandMantle"
	add_child(_mantle_root)

	_mantle_visual = MeshInstance3D.new()
	_mantle_visual.name = "ContinuousLandVisual"
	_mantle_visual.mesh = mesh
	_mantle_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.27, 0.31, 0.20, 1.0)
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mantle_visual.material_override = material
	_mantle_root.add_child(_mantle_visual)

	var shape: Shape3D = mesh.create_trimesh_shape()
	if shape == null:
		push_warning("GrandPrixV3WorldFoundation: mantle collision generation failed")
		return
	if shape is ConcavePolygonShape3D:
		(shape as ConcavePolygonShape3D).backface_collision = true

	_mantle_body = StaticBody3D.new()
	_mantle_body.name = "V39ContinuousLandCollision"
	_mantle_body.collision_layer = 1
	_mantle_body.collision_mask = 0
	_mantle_root.add_child(_mantle_body)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "ContinuousLandShape"
	collision.shape = shape
	_mantle_body.add_child(collision)

	# The old V2 side collider follows a different height profile. Keeping it
	# together with the authoritative V3 mantle can form hidden lips at re-entry.
	_legacy_collision_shapes_disabled = _disable_legacy_near_terrain_collision()

	print("GRAND PRIX V3.9 CONTINUOUS MOUNTAIN LAND READY route_points=%d segments=%d authoritative_offroad_collision=true legacy_side_shapes_disabled=%d mountain_width=16..20m mountain_height=4.5..8.0m visual_collision_same_mesh=true open_edge_return_preserved=true" % [
		_route.size(),
		_route.size() - 1,
		_legacy_collision_shapes_disabled,
	])

func _build_land_mantle_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var distance_along: float = 0.0

	# Six vertices per route point: three rings on each side. Keeping left/right
	# separate means no terrain triangle can span over the road on a switchback.
	for point_index: int in range(_route.size()):
		if point_index > 0:
			distance_along += _route[point_index - 1].distance_to(_route[point_index])
		var segment_index: int = clampi(point_index, 0, _route.size() - 2)
		if point_index >= _route.size() - 1:
			segment_index = _route.size() - 2
		var section_id: StringName = _track.get_v2_section_id_for_segment(segment_index)
		var land_width: float = float(SECTION_LAND_WIDTHS.get(section_id, 12.0))
		var embankment_height: float = float(SECTION_EMBANKMENT_HEIGHTS.get(section_id, 0.0))
		var right: Vector3 = _right_at(point_index)
		var left_edge: Vector3 = _track.get_v2_shoulder_edge_point(point_index, -1.0)
		var right_edge: Vector3 = _track.get_v2_shoulder_edge_point(point_index, 1.0)

		var mid_distance: float = land_width * MID_DISTANCE_RATIO
		var mid_height: float = embankment_height * MID_HEIGHT_RATIO
		var outer_height: float = embankment_height
		if embankment_height <= 0.001:
			mid_height = -OUTER_DROP * MID_DISTANCE_RATIO
			outer_height = -OUTER_DROP

		var left_inner: Vector3 = left_edge + right * SHOULDER_OVERLAP + Vector3.UP * SURFACE_LIFT
		var left_mid: Vector3 = left_edge - right * mid_distance + Vector3.UP * mid_height
		var left_outer: Vector3 = left_edge - right * land_width + Vector3.UP * outer_height
		var right_inner: Vector3 = right_edge - right * SHOULDER_OVERLAP + Vector3.UP * SURFACE_LIFT
		var right_mid: Vector3 = right_edge + right * mid_distance + Vector3.UP * mid_height
		var right_outer: Vector3 = right_edge + right * land_width + Vector3.UP * outer_height

		vertices.append(left_outer)
		vertices.append(left_mid)
		vertices.append(left_inner)
		vertices.append(right_inner)
		vertices.append(right_mid)
		vertices.append(right_outer)
		for _normal_index: int in range(6):
			normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, distance_along / 18.0))
		uvs.append(Vector2(0.20, distance_along / 18.0))
		uvs.append(Vector2(0.42, distance_along / 18.0))
		uvs.append(Vector2(0.58, distance_along / 18.0))
		uvs.append(Vector2(0.80, distance_along / 18.0))
		uvs.append(Vector2(1.0, distance_along / 18.0))

	for point_index: int in range(_route.size() - 1):
		var base: int = point_index * 6
		var next: int = base + 6
		indices.append_array(PackedInt32Array([
			base, base + 1, next,
			base + 1, next + 1, next,
			base + 1, base + 2, next + 1,
			base + 2, next + 2, next + 1,
			base + 3, base + 4, next + 3,
			base + 4, next + 4, next + 3,
			base + 4, base + 5, next + 4,
			base + 5, next + 5, next + 4,
		]))

	var mesh: ArrayMesh = ArrayMesh.new()
	if vertices.is_empty() or indices.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _disable_legacy_near_terrain_collision() -> int:
	var terrain_shell: Node = _find_named_recursive(get_parent(), "V2TerrainShell")
	if terrain_shell == null:
		return 0
	var collision_root: Node = terrain_shell.get_node_or_null("V2NearTerrainCollision")
	if collision_root == null:
		return 0
	return _disable_collision_shapes_recursive(collision_root)

func _disable_collision_shapes_recursive(root: Node) -> int:
	var disabled: int = 0
	for child: Node in root.get_children():
		if child is CollisionShape3D:
			var shape_node: CollisionShape3D = child as CollisionShape3D
			shape_node.set_deferred("disabled", true)
			disabled += 1
		else:
			disabled += _disable_collision_shapes_recursive(child)
	return disabled

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

func get_land_width_for_section(section_id: StringName) -> float:
	return float(SECTION_LAND_WIDTHS.get(section_id, 12.0))

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
