class_name WildDashGrandPrixV3WorldFoundation
extends Node3D

## Grand Prix V3.6 continuous land mantle.
##
## V3.5 used one broad low slab below the whole course. That prevented a void
## fall, but it still let racers drop down to a visibly separate lower floor.
## Round 1 is not a floating track, so V3.6 removes that stacked-floor model and
## builds actual route-height land directly outside both shoulders for the whole
## course. The mantle follows the sampled road elevation and always extends well
## beyond the offroad stop depth. Tight mountain/canyon widths stay conservative
## so the mantle does not bridge over nearby switchbacks at another elevation.

const SHOULDER_OVERLAP: float = 0.35
const OUTER_DROP: float = 0.14
const SURFACE_LIFT: float = 0.01

const SECTION_LAND_WIDTHS: Dictionary = {
	&"meadow_start": 18.0,
	&"forest_obstacle": 15.0,
	&"long_river": 14.0,
	&"mountain_approach": 8.0,
	&"mountain_ascent": 7.0,
	&"summit_ridge": 6.5,
	&"rough_descent": 7.5,
	&"canyon_obstacle": 5.5,
	&"final_sprint": 18.0,
}

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _mantle_root: Node3D
var _mantle_body: StaticBody3D
var _mantle_visual: MeshInstance3D

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
	_mantle_root.name = "V36ContinuousLandMantle"
	add_child(_mantle_root)

	_mantle_visual = MeshInstance3D.new()
	_mantle_visual.name = "ContinuousLandVisual"
	_mantle_visual.mesh = mesh
	_mantle_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.23, 0.31, 0.20, 1.0)
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
	_mantle_body.name = "V36ContinuousLandCollision"
	_mantle_body.collision_layer = 1
	_mantle_body.collision_mask = 0
	_mantle_root.add_child(_mantle_body)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "ContinuousLandShape"
	collision.shape = shape
	_mantle_body.add_child(collision)

	print("GRAND PRIX V3.6 CONTINUOUS LAND READY route_points=%d segments=%d low_floor=false stacked_floor=false two_sided=true meadow_width=18.0m mountain_width=6.5..8.0m canyon_width=5.5m" % [
		_route.size(),
		_route.size() - 1,
	])

func _build_land_mantle_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var distance_along: float = 0.0

	for point_index: int in range(_route.size()):
		if point_index > 0:
			distance_along += _route[point_index - 1].distance_to(_route[point_index])
		var segment_index: int = clampi(point_index, 0, _route.size() - 2)
		if point_index >= _route.size() - 1:
			segment_index = _route.size() - 2
		var section_id: StringName = _track.get_v2_section_id_for_segment(segment_index)
		var land_width: float = float(SECTION_LAND_WIDTHS.get(section_id, 12.0))
		var right: Vector3 = _right_at(point_index)
		var left_edge: Vector3 = _track.get_v2_shoulder_edge_point(point_index, -1.0)
		var right_edge: Vector3 = _track.get_v2_shoulder_edge_point(point_index, 1.0)

		var left_inner: Vector3 = left_edge + right * SHOULDER_OVERLAP + Vector3.UP * SURFACE_LIFT
		var left_outer: Vector3 = left_edge - right * land_width - Vector3.UP * OUTER_DROP
		var right_inner: Vector3 = right_edge - right * SHOULDER_OVERLAP + Vector3.UP * SURFACE_LIFT
		var right_outer: Vector3 = right_edge + right * land_width - Vector3.UP * OUTER_DROP

		vertices.append(left_outer)
		vertices.append(left_inner)
		vertices.append(right_inner)
		vertices.append(right_outer)
		for _normal_index: int in range(4):
			normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, distance_along / 18.0))
		uvs.append(Vector2(0.35, distance_along / 18.0))
		uvs.append(Vector2(0.65, distance_along / 18.0))
		uvs.append(Vector2(1.0, distance_along / 18.0))

	for point_index: int in range(_route.size() - 1):
		var base: int = point_index * 4
		var next: int = base + 4
		indices.append_array(PackedInt32Array([
			base, base + 1, next,
			base + 1, next + 1, next,
			base + 2, base + 3, next + 2,
			base + 3, next + 3, next + 2,
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
