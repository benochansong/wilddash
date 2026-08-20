class_name WildDashGrandPrixV2TerrainShell
extends Node3D

## V2.5 grounded-world shell.
## Builds route-derived near/far terrain ribbons in ~100m chunks so the road is
## visually anchored to grass, dirt, river banks, mountain slopes and canyon
## walls without turning the entire 2.6km world into one always-visible object.

const CHUNK_LENGTH: float = 100.0
const NEAR_COLLISION_WIDTH: float = 10.0
const DETAIL_ACTIVE_RADIUS: int = 3
const DETAIL_UPDATE_INTERVAL: float = 0.25

const TERRAIN_WIDTHS: Dictionary = {
	&"meadow_start": Vector2(18.0, 58.0),
	&"forest_obstacle": Vector2(15.0, 44.0),
	&"long_river": Vector2(14.0, 34.0),
	&"mountain_approach": Vector2(13.0, 42.0),
	&"mountain_ascent": Vector2(12.0, 52.0),
	&"summit_ridge": Vector2(13.0, 35.0),
	&"rough_descent": Vector2(12.0, 42.0),
	&"canyon_obstacle": Vector2(8.0, 18.0),
	&"final_sprint": Vector2(18.0, 58.0),
}

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _segment_widths: Array[float] = []
var _segment_sections: Array[StringName] = []
var _chunk_ranges: Array[Vector2i] = []
var _chunk_detail_roots: Array[Node3D] = []
var _collision_root: StaticBody3D
var _palette: Dictionary = {}
var _mesh_cache: Dictionary = {}
var _detail_elapsed: float = 0.0
var _visible_chunk_count: int = 0
var _environment_multimesh_count: int = 0
var _environment_collision_shape_count: int = 0
var _terrain_mesh_count: int = 0

func _ready() -> void:
	process_priority = 118
	call_deferred("_build_when_ready")

func _build_when_ready() -> void:
	for _frame: int in range(4):
		await get_tree().process_frame
	_track = _find_v2_track(get_parent())
	if _track == null:
		push_warning("GrandPrixV2TerrainShell: V2 track unavailable")
		return
	_route = _track.get_route_points()
	if _route.size() < 2:
		return
	var bundle: Dictionary = WildDashGrandPrixV2Layout.build_route_bundle()
	_segment_widths = bundle["segment_widths"]
	_segment_sections = bundle["segment_sections"]
	_palette = WildDashEnvironmentMaterialLibrary.get_palette()
	_build_roots()
	_chunk_ranges = _build_chunk_ranges()
	for chunk_index: int in range(_chunk_ranges.size()):
		_build_chunk(chunk_index, _chunk_ranges[chunk_index])
	_update_detail_focus(0)
	print("GRAND PRIX V2 TERRAIN SHELL READY chunks=%d chunk_target=%.0fm terrain_meshes=%d environment_multimeshes=%d near_collision_shapes=%d far_collision_shapes=0 visible_detail_chunks=%d giant_aabb=false far_shadows=false" % [
		_chunk_ranges.size(), CHUNK_LENGTH, _terrain_mesh_count, _environment_multimesh_count,
		_environment_collision_shape_count, _visible_chunk_count,
	])

func _process(delta: float) -> void:
	if _chunk_ranges.is_empty() or _route.is_empty():
		return
	_detail_elapsed += delta
	if _detail_elapsed < DETAIL_UPDATE_INTERVAL:
		return
	_detail_elapsed = 0.0
	if RaceManager.racers.is_empty():
		return
	var focus: Node3D = RaceManager.racers[0] as Node3D
	if focus == null:
		return
	var route_index: int = _nearest_route_index(focus.global_position)
	_update_detail_focus(_chunk_index_for_route_point(route_index))

func get_terrain_chunk_count() -> int:
	return _chunk_ranges.size()

func get_visible_chunk_count() -> int:
	return _visible_chunk_count

func get_environment_multimesh_count() -> int:
	return _environment_multimesh_count

func get_environment_collision_shape_count() -> int:
	return _environment_collision_shape_count

func get_terrain_mesh_count() -> int:
	return _terrain_mesh_count

func _build_roots() -> void:
	_collision_root = StaticBody3D.new()
	_collision_root.name = "V2NearTerrainCollision"
	_collision_root.collision_layer = 1
	_collision_root.collision_mask = 0
	add_child(_collision_root)

func _build_chunk_ranges() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var start_point: int = 0
	var distance: float = 0.0
	for segment_index: int in range(_route.size() - 1):
		distance += _route[segment_index].distance_to(_route[segment_index + 1])
		if distance >= CHUNK_LENGTH and segment_index + 1 < _route.size() - 1:
			result.append(Vector2i(start_point, segment_index + 1))
			start_point = segment_index + 1
			distance = 0.0
	if start_point < _route.size() - 1:
		result.append(Vector2i(start_point, _route.size() - 1))
	return result

func _build_chunk(chunk_index: int, point_range: Vector2i) -> void:
	var root: Node3D = Node3D.new()
	root.name = "V2SpatialChunk_%02d" % chunk_index
	add_child(root)

	var terrain_root: Node3D = Node3D.new()
	terrain_root.name = "Terrain"
	root.add_child(terrain_root)
	var detail_root: Node3D = Node3D.new()
	detail_root.name = "Detail"
	root.add_child(detail_root)
	_chunk_detail_roots.append(detail_root)

	var middle_point: int = clampi((point_range.x + point_range.y) / 2, 0, _route.size() - 1)
	var section_id: StringName = WildDashGrandPrixV2Geometry.point_section_id(_segment_sections, middle_point)
	var near_mesh: ArrayMesh = _build_terrain_band_mesh(point_range.x, point_range.y, false, false)
	var far_mesh: ArrayMesh = _build_terrain_band_mesh(point_range.x, point_range.y, true, false)
	_add_mesh_instance(terrain_root, "NearTerrain", near_mesh, _near_material(section_id), false)
	_add_mesh_instance(terrain_root, "FarTerrain", far_mesh, _far_material(section_id), false)
	_terrain_mesh_count += 2

	var collision_mesh: ArrayMesh = _build_terrain_band_mesh(point_range.x, point_range.y, false, true)
	_add_near_collision("NearTerrainCollision_%02d" % chunk_index, collision_mesh)

	if _range_contains_section(point_range, &"long_river"):
		var river_bed: ArrayMesh = _build_river_bed_mesh(point_range.x, point_range.y)
		if river_bed.get_surface_count() > 0:
			_add_mesh_instance(terrain_root, "RiverBed", river_bed, _river_bed_material(), false)
			_terrain_mesh_count += 1

	_build_chunk_props(detail_root, point_range, chunk_index)

func _build_terrain_band_mesh(start_point: int, end_point: int, far_band: bool, collision_band: bool) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var distance_along: float = 0.0

	for point_index: int in range(start_point, end_point + 1):
		if point_index > start_point:
			distance_along += _route[point_index - 1].distance_to(_route[point_index])
		var section_id: StringName = WildDashGrandPrixV2Geometry.point_section_id(_segment_sections, point_index)
		var widths: Vector2 = _terrain_widths_for_section(section_id)
		var inner_extra: float = widths.x if far_band else 0.0
		var outer_extra: float = widths.y if far_band else widths.x
		if collision_band:
			inner_extra = 0.0
			outer_extra = minf(NEAR_COLLISION_WIDTH, widths.x)
		var outer_ratio: float = 1.0
		if collision_band and widths.x > 0.01:
			outer_ratio = outer_extra / widths.x

		var left_outer: Vector3 = _terrain_point(point_index, -1.0, outer_extra, section_id, 2 if far_band else 1, outer_ratio)
		var left_inner: Vector3 = _terrain_point(point_index, -1.0, inner_extra, section_id, 1 if far_band else 0, 1.0)
		var right_inner: Vector3 = _terrain_point(point_index, 1.0, inner_extra, section_id, 1 if far_band else 0, 1.0)
		var right_outer: Vector3 = _terrain_point(point_index, 1.0, outer_extra, section_id, 2 if far_band else 1, outer_ratio)
		for point: Vector3 in [left_outer, left_inner, right_inner, right_outer]:
			vertices.append(point)
			normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, distance_along / 18.0))
		uvs.append(Vector2(0.35, distance_along / 18.0))
		uvs.append(Vector2(0.65, distance_along / 18.0))
		uvs.append(Vector2(1.0, distance_along / 18.0))

	var point_count: int = end_point - start_point + 1
	for local_index: int in range(point_count - 1):
		var base: int = local_index * 4
		var next: int = base + 4
		indices.append_array(PackedInt32Array([
			base, base + 1, next,
			base + 1, next + 1, next,
			base + 2, base + 3, next + 2,
			base + 3, next + 3, next + 2,
		]))
	return _array_mesh(vertices, normals, uvs, indices)

func _terrain_point(
	point_index: int,
	side: float,
	extra_distance: float,
	section_id: StringName,
	ring: int,
	height_ratio: float
) -> Vector3:
	var base_distance: float = (
		WildDashGrandPrixV2Geometry.point_half_width(_segment_widths, point_index)
		+ WildDashGrandPrixV2Geometry.point_shoulder_width(_segment_sections, point_index)
		+ extra_distance
	)
	var point: Vector3 = _route[point_index] + WildDashGrandPrixV2Geometry.lateral_offset(
		_route, point_index, base_distance
	) * side
	if ring <= 0:
		point.y = _route[point_index].y - 0.02
	elif ring == 1:
		point.y = _route[point_index].y + _near_height_offset(section_id, side) * height_ratio
	else:
		point.y = _route[point_index].y + _far_height_offset(section_id, side)
	return point

func _build_river_bed_mesh(start_point: int, end_point: int) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var included_points: Array[int] = []
	for point_index: int in range(start_point, end_point + 1):
		var section_id: StringName = WildDashGrandPrixV2Geometry.point_section_id(_segment_sections, point_index)
		if section_id != &"long_river":
			continue
		included_points.append(point_index)
		var distance: float = WildDashGrandPrixV2Geometry.point_half_width(_segment_widths, point_index) + 4.5
		var left: Vector3 = _route[point_index] + WildDashGrandPrixV2Geometry.lateral_offset(_route, point_index, distance) * -1.0
		var right: Vector3 = _route[point_index] + WildDashGrandPrixV2Geometry.lateral_offset(_route, point_index, distance)
		left.y = _route[point_index].y - 1.10
		right.y = _route[point_index].y - 1.10
		vertices.append(left)
		vertices.append(right)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, float(included_points.size()) * 0.4))
		uvs.append(Vector2(1.0, float(included_points.size()) * 0.4))
	if included_points.size() < 2:
		return ArrayMesh.new()
	for local_index: int in range(included_points.size() - 1):
		if included_points[local_index + 1] != included_points[local_index] + 1:
			continue
		var base: int = local_index * 2
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))
	return _array_mesh(vertices, normals, uvs, indices)

func _build_chunk_props(detail_root: Node3D, point_range: Vector2i, chunk_index: int) -> void:
	var near_trunks: Array[Transform3D] = []
	var near_canopies: Array[Transform3D] = []
	var far_trunks: Array[Transform3D] = []
	var far_canopies: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var reeds: Array[Transform3D] = []
	var houses: Array[Transform3D] = []
	var roofs: Array[Transform3D] = []
	var hay: Array[Transform3D] = []
	var mountains: Array[Transform3D] = []
	var canyon_walls: Array[Transform3D] = []

	for point_index: int in range(point_range.x, point_range.y + 1, 3):
		var section_id: StringName = WildDashGrandPrixV2Geometry.point_section_id(_segment_sections, point_index)
		var tangent: Vector3 = WildDashGrandPrixV2Geometry.planar_tangent_at(_route, point_index)
		var right: Vector3 = Vector3(-tangent.z, 0.0, tangent.x)
		var base_distance: float = (
			WildDashGrandPrixV2Geometry.point_half_width(_segment_widths, point_index)
			+ WildDashGrandPrixV2Geometry.point_shoulder_width(_segment_sections, point_index)
		)
		for side: float in [-1.0, 1.0]:
			var phase: int = abs(point_index * 17 + chunk_index * 11 + int(side * 5.0))
			match section_id:
				&"meadow_start", &"final_sprint":
					var tree_offset: float = base_distance + 11.0 + float(phase % 6)
					_append_tree(near_trunks, near_canopies, _route[point_index] + right * side * tree_offset, 4.6 + float(phase % 3) * 0.6)
					var bush_point: Vector3 = _route[point_index] + right * side * (base_distance + 7.0 + float(phase % 3))
					bushes.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.6, 1.1, 1.5)), bush_point + Vector3.UP * 0.55))
					if point_index % 6 == 0:
						var house_point: Vector3 = _route[point_index] + right * side * (base_distance + 20.0 + float(phase % 8))
						_append_house(houses, roofs, house_point, tangent, 0.9 + float(phase % 3) * 0.12)
					if point_index % 9 == 0:
						var hay_point: Vector3 = _route[point_index] + right * side * (base_distance + 13.0)
						hay.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.4, 1.15, 1.4)), hay_point + Vector3.UP * 0.58))
				&"forest_obstacle":
					var near_tree_point: Vector3 = _route[point_index] + right * side * (base_distance + 7.5 + float(phase % 5))
					_append_tree(near_trunks, near_canopies, near_tree_point, 5.2 + float(phase % 4) * 0.65)
					var far_tree_point: Vector3 = _route[point_index] + right * side * (base_distance + 21.0 + float(phase % 8))
					_append_far_tree(far_trunks, far_canopies, far_tree_point, 4.2 + float(phase % 3) * 0.5)
					bushes.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.9, 1.2, 1.8)), _route[point_index] + right * side * (base_distance + 5.0) + Vector3.UP * 0.6))
				&"long_river":
					var reed_point: Vector3 = _route[point_index] + right * side * (base_distance + 3.5 + float(phase % 4))
					reeds.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.28, 1.55, 0.28)), reed_point + Vector3.UP * 0.78))
					if point_index % 6 == 0:
						rocks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(2.2, 1.25, 1.9)), reed_point + right * side * 2.2 + Vector3.UP * 0.62))
				&"mountain_approach", &"mountain_ascent", &"rough_descent":
					var rock_point: Vector3 = _route[point_index] + right * side * (base_distance + 5.5 + float(phase % 4))
					rocks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(2.6, 1.7, 2.3)), rock_point + Vector3.UP * 0.65))
					if point_index % 6 == 0:
						var mountain_height: float = 17.0 + float(phase % 5) * 3.0
						var mountain_point: Vector3 = _route[point_index] + right * side * (base_distance + 30.0 + float(phase % 14))
						mountains.append(Transform3D(Basis.IDENTITY.scaled(Vector3(9.0 + float(phase % 4), mountain_height, 9.0 + float(phase % 3))), mountain_point + Vector3.UP * (mountain_height * 0.35 - 2.0)))
				&"summit_ridge":
					if point_index % 6 == 0:
						rocks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(2.4, 1.4, 2.0)), _route[point_index] + right * side * (base_distance + 8.0) + Vector3.UP * 0.55))
				&"canyon_obstacle":
					var wall_height: float = 12.0 + float(phase % 4) * 2.5
					var wall_point: Vector3 = _route[point_index] + right * side * (base_distance + 9.5)
					canyon_walls.append(Transform3D(Basis.IDENTITY.scaled(Vector3(5.5, wall_height, 6.5)), wall_point + Vector3.UP * (wall_height * 0.42)))

	_add_multimesh(detail_root, "NearTreeTrunks", _cached_mesh(&"trunk"), near_trunks, _wood_material(), true)
	_add_multimesh(detail_root, "NearTreeCanopies", _cached_mesh(&"canopy"), near_canopies, _leaf_material(), true)
	_add_multimesh(detail_root, "FarTreeTrunks", _cached_mesh(&"far_trunk"), far_trunks, _wood_material(), false)
	_add_multimesh(detail_root, "FarTreeCanopies", _cached_mesh(&"far_canopy"), far_canopies, _leaf_material(), false)
	_add_multimesh(detail_root, "Bushes", _cached_mesh(&"bush"), bushes, _leaf_material(), false)
	_add_multimesh(detail_root, "Rocks", _cached_mesh(&"rock"), rocks, _rock_material(), true)
	_add_multimesh(detail_root, "Reeds", _cached_mesh(&"reed"), reeds, _reeds_material(), false)
	_add_multimesh(detail_root, "HouseBodies", _cached_mesh(&"house"), houses, _house_material(), false)
	_add_multimesh(detail_root, "HouseRoofs", _cached_mesh(&"roof"), roofs, _roof_material(), false)
	_add_multimesh(detail_root, "HayBales", _cached_mesh(&"hay"), hay, _hay_material(), false)
	_add_multimesh(detail_root, "FarMountains", _cached_mesh(&"mountain"), mountains, _rock_material(), false)
	_add_multimesh(detail_root, "CanyonWalls", _cached_mesh(&"wall"), canyon_walls, _canyon_material(), true)

func _append_tree(trunks: Array[Transform3D], canopies: Array[Transform3D], ground: Vector3, height: float) -> void:
	var trunk_height: float = height * 0.48
	trunks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.48, trunk_height, 0.48)), ground + Vector3.UP * trunk_height * 0.5))
	canopies.append(Transform3D(Basis.IDENTITY.scaled(Vector3(2.25, height * 0.62, 2.25)), ground + Vector3.UP * (trunk_height + height * 0.28)))

func _append_far_tree(trunks: Array[Transform3D], canopies: Array[Transform3D], ground: Vector3, height: float) -> void:
	var trunk_height: float = height * 0.46
	trunks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.30, trunk_height, 0.30)), ground + Vector3.UP * trunk_height * 0.5))
	canopies.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.55, height * 0.58, 1.55)), ground + Vector3.UP * (trunk_height + height * 0.25)))

func _append_house(bodies: Array[Transform3D], roofs: Array[Transform3D], ground: Vector3, forward: Vector3, scale_factor: float) -> void:
	var basis: Basis = Basis.looking_at(forward, Vector3.UP)
	var body_transform: Transform3D = Transform3D(basis.scaled(Vector3(5.0, 3.2, 4.2) * scale_factor), ground + Vector3.UP * 1.6 * scale_factor)
	bodies.append(body_transform)
	var roof_basis: Basis = basis * Basis(Vector3.UP, PI * 0.25)
	roofs.append(Transform3D(roof_basis.scaled(Vector3(4.0, 2.0, 4.0) * scale_factor), ground + Vector3.UP * 4.0 * scale_factor))

func _add_mesh_instance(parent: Node3D, node_name: String, mesh: ArrayMesh, material: Material, cast_shadow: bool) -> void:
	if mesh.get_surface_count() == 0:
		return
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

func _add_near_collision(node_name: String, mesh: ArrayMesh) -> void:
	if mesh.get_surface_count() == 0:
		return
	var shape: Shape3D = mesh.create_trimesh_shape()
	if shape == null:
		return
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = node_name
	collision.shape = shape
	_collision_root.add_child(collision)
	_environment_collision_shape_count += 1

func _add_multimesh(
	parent: Node3D,
	node_name: String,
	mesh: Mesh,
	transforms: Array[Transform3D],
	material: Material,
	cast_shadow: bool
) -> void:
	if transforms.is_empty():
		return
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	multimesh.custom_aabb = _tight_aabb(transforms, 2.0)
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	_environment_multimesh_count += 1

func _tight_aabb(transforms: Array[Transform3D], margin: float) -> AABB:
	var minimum: Vector3 = transforms[0].origin
	var maximum: Vector3 = transforms[0].origin
	for transform: Transform3D in transforms:
		var extents: Vector3 = Vector3(
			transform.basis.x.length(), transform.basis.y.length(), transform.basis.z.length()
		) * 0.7 + Vector3.ONE * 0.35
		minimum.x = minf(minimum.x, transform.origin.x - extents.x)
		minimum.y = minf(minimum.y, transform.origin.y - extents.y)
		minimum.z = minf(minimum.z, transform.origin.z - extents.z)
		maximum.x = maxf(maximum.x, transform.origin.x + extents.x)
		maximum.y = maxf(maximum.y, transform.origin.y + extents.y)
		maximum.z = maxf(maximum.z, transform.origin.z + extents.z)
	var padding: Vector3 = Vector3.ONE * margin
	return AABB(minimum - padding, maximum - minimum + padding * 2.0)

func _array_mesh(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
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

func _cached_mesh(key: StringName) -> Mesh:
	if _mesh_cache.has(key):
		return _mesh_cache[key] as Mesh
	var mesh: Mesh
	match key:
		&"trunk", &"far_trunk", &"reed", &"hay":
			var cylinder: CylinderMesh = CylinderMesh.new()
			cylinder.top_radius = 0.5
			cylinder.bottom_radius = 0.5
			cylinder.height = 1.0
			cylinder.radial_segments = 7 if key != &"reed" else 5
			cylinder.rings = 1
			mesh = cylinder
		&"canopy", &"far_canopy", &"mountain", &"roof":
			var cone: CylinderMesh = CylinderMesh.new()
			cone.top_radius = 0.08 if key != &"roof" else 0.0
			cone.bottom_radius = 1.0
			cone.height = 1.0
			cone.radial_segments = 7 if key != &"roof" else 4
			cone.rings = 1
			mesh = cone
		&"bush", &"rock":
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			sphere.radial_segments = 7
			sphere.rings = 4
			mesh = sphere
		_:
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3.ONE
			mesh = box
	_mesh_cache[key] = mesh
	return mesh

func _terrain_widths_for_section(section_id: StringName) -> Vector2:
	return TERRAIN_WIDTHS.get(section_id, Vector2(12.0, 36.0)) as Vector2

func _near_height_offset(section_id: StringName, side: float) -> float:
	match section_id:
		&"meadow_start", &"final_sprint": return -0.18
		&"forest_obstacle": return -0.35
		&"long_river": return 0.45
		&"mountain_approach": return 1.6 if side < 0.0 else -2.2
		&"mountain_ascent": return 3.8 if side < 0.0 else -4.8
		&"summit_ridge": return -0.25
		&"rough_descent": return 2.2 if side < 0.0 else -3.8
		&"canyon_obstacle": return 4.8
		_: return -0.2

func _far_height_offset(section_id: StringName, side: float) -> float:
	match section_id:
		&"meadow_start", &"final_sprint": return -2.0
		&"forest_obstacle": return -3.0
		&"long_river": return 0.15
		&"mountain_approach": return 7.5 if side < 0.0 else -8.5
		&"mountain_ascent": return 16.0 if side < 0.0 else -18.0
		&"summit_ridge": return -2.0
		&"rough_descent": return 9.0 if side < 0.0 else -13.0
		&"canyon_obstacle": return 14.0
		_: return -2.0

func _range_contains_section(point_range: Vector2i, section_id: StringName) -> bool:
	for point_index: int in range(point_range.x, point_range.y + 1):
		if WildDashGrandPrixV2Geometry.point_section_id(_segment_sections, point_index) == section_id:
			return true
	return false

func _update_detail_focus(focus_chunk: int) -> void:
	_visible_chunk_count = 0
	for chunk_index: int in range(_chunk_detail_roots.size()):
		var visible_now: bool = abs(chunk_index - focus_chunk) <= DETAIL_ACTIVE_RADIUS
		_chunk_detail_roots[chunk_index].visible = visible_now
		if visible_now:
			_visible_chunk_count += 1

func _chunk_index_for_route_point(point_index: int) -> int:
	for chunk_index: int in range(_chunk_ranges.size()):
		var point_range: Vector2i = _chunk_ranges[chunk_index]
		if point_index >= point_range.x and point_index <= point_range.y:
			return chunk_index
	return maxi(0, _chunk_ranges.size() - 1)

func _nearest_route_index(point: Vector3) -> int:
	var best_index: int = 0
	var best_distance: float = INF
	for index: int in range(_route.size()):
		var distance: float = point.distance_squared_to(_route[index])
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index

func _find_v2_track(node: Node) -> WildDashGrandPrixV2Track:
	if node is WildDashGrandPrixV2Track:
		return node as WildDashGrandPrixV2Track
	for child: Node in node.get_children():
		var found: WildDashGrandPrixV2Track = _find_v2_track(child)
		if found != null:
			return found
	return null

func _near_material(section_id: StringName) -> Material:
	match section_id:
		&"meadow_start", &"forest_obstacle", &"final_sprint": return _material_from_palette(&"grass", Color(0.20, 0.42, 0.17))
		&"long_river": return _material_from_palette(&"dirt", Color(0.34, 0.26, 0.14))
		&"mountain_approach", &"mountain_ascent", &"summit_ridge", &"rough_descent", &"canyon_obstacle": return _material_from_palette(&"rock", Color(0.33, 0.32, 0.29))
		_: return _material_from_palette(&"dirt", Color(0.30, 0.25, 0.16))

func _far_material(section_id: StringName) -> Material:
	match section_id:
		&"meadow_start", &"forest_obstacle", &"final_sprint": return _flat_material(Color(0.16, 0.34, 0.15), 0.98)
		&"long_river": return _flat_material(Color(0.25, 0.28, 0.16), 0.98)
		&"canyon_obstacle": return _flat_material(Color(0.35, 0.22, 0.14), 0.98)
		_: return _flat_material(Color(0.28, 0.29, 0.28), 0.98)

func _material_from_palette(key: StringName, fallback: Color) -> Material:
	if _palette.has(key):
		return _palette[key] as Material
	return _flat_material(fallback, 0.90)

func _flat_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _wood_material() -> Material:
	return _material_from_palette(&"wood", Color(0.34, 0.20, 0.09))

func _leaf_material() -> Material:
	return _material_from_palette(&"grass", Color(0.12, 0.36, 0.15))

func _rock_material() -> Material:
	return _material_from_palette(&"rock", Color(0.31, 0.32, 0.31))

func _reeds_material() -> Material:
	return _flat_material(Color(0.30, 0.48, 0.15), 0.95)

func _house_material() -> Material:
	return _flat_material(Color(0.72, 0.58, 0.38), 0.88)

func _roof_material() -> Material:
	return _flat_material(Color(0.40, 0.16, 0.09), 0.92)

func _hay_material() -> Material:
	return _flat_material(Color(0.76, 0.61, 0.18), 0.96)

func _canyon_material() -> Material:
	return _flat_material(Color(0.40, 0.25, 0.16), 0.96)

func _river_bed_material() -> Material:
	return _flat_material(Color(0.10, 0.16, 0.15), 1.0)
