class_name WildDashGrandPrixV2TerrainGameplay
extends Node3D

## Stage 2 Terrain Adventure implementation for Round 1.
## The V2 route remains the authority; this layer turns named sections into
## water/climb/summit/rough gameplay without creating a second navigation path.

const WATER_SURFACE_HEIGHT := 0.58
const WATER_VISUAL_EXTRA_WIDTH := 2.4
const TERRAIN_ZONE_HEIGHT := 8.0
const RIVER_CURRENT_BASE := 2.15
const RIVER_CURRENT_STRONG := 2.70
const RIVER_CURRENT_EXIT := 1.35
const VISUAL_CHUNK_LENGTH: float = 100.0

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _ranges: Dictionary = {}
var _terrain_root: Node3D
var _visual_root: Node3D
var _obstacle_root: Node3D
var _palette: Dictionary = {}
var _route_distances: PackedFloat32Array = PackedFloat32Array()
var _visual_multimesh_count: int = 0

func _ready() -> void:
	call_deferred("_build_when_ready")

func _build_when_ready() -> void:
	for _frame: int in range(3):
		await get_tree().process_frame
	_track = _find_v2_track(get_parent())
	if _track == null:
		push_warning("GrandPrixV2TerrainGameplay: V2 track unavailable")
		return
	_route = _track.get_route_points()
	_ranges = _track.get_v2_section_ranges()
	if _route.size() < 2:
		return
	_palette = WildDashEnvironmentMaterialLibrary.get_palette()
	_build_route_distances()
	_build_roots()
	_build_long_river()
	_build_mountain_gameplay()
	_build_summit_gameplay()
	_build_rough_descent()
	_build_stage2_obstacles()

	print("GRAND PRIX V2 TERRAIN READY river=%.1fm mountain=%.1fm summit=%.1fm rough=%.1fm water_visual=true ai_shared=true visual_multimeshes=%d chunk_target=%.0fm giant_aabb=false" % [
		_section_length(&"long_river"),
		_section_length(&"mountain_ascent"),
		_section_length(&"summit_ridge"),
		_section_length(&"rough_descent"),
		_visual_multimesh_count,
		VISUAL_CHUNK_LENGTH,
	])

func get_visual_multimesh_count() -> int:
	return _visual_multimesh_count

func _build_route_distances() -> void:
	_route_distances.resize(_route.size())
	if _route.is_empty():
		return
	_route_distances[0] = 0.0
	for point_index: int in range(1, _route.size()):
		_route_distances[point_index] = _route_distances[point_index - 1] + _route[point_index - 1].distance_to(_route[point_index])

func _build_roots() -> void:
	_terrain_root = Node3D.new()
	_terrain_root.name = "V2TerrainZones"
	add_child(_terrain_root)
	_visual_root = Node3D.new()
	_visual_root.name = "V2TerrainVisuals"
	add_child(_visual_root)
	_obstacle_root = Node3D.new()
	_obstacle_root.name = "V2TerrainObstacles"
	add_child(_obstacle_root)

func _build_long_river() -> void:
	var section_range: Vector2i = _get_range(&"long_river")
	if section_range.x < 0:
		return
	var water_transforms: Array[Transform3D] = []
	var foam_transforms: Array[Transform3D] = []
	var bank_transforms: Array[Transform3D] = []
	var denominator: float = maxf(1.0, float(section_range.y - section_range.x))

	for segment_index: int in range(section_range.x, section_range.y + 1):
		var a: Vector3 = _route[segment_index]
		var b: Vector3 = _route[segment_index + 1]
		var width: float = _track.get_v2_width_for_segment(segment_index)
		var progress: float = float(segment_index - section_range.x) / denominator
		var forward: Vector3 = _planar_forward(a, b)
		var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)

		var zone := WildDashTerrainZone.new()
		zone.name = "RiverWater_%03d" % segment_index
		_terrain_root.add_child(zone)
		zone.configure_route_box(
			StringName("river_%03d" % segment_index), &"water", a, b, width + 1.6,
			TERRAIN_ZONE_HEIGHT
		)
		if progress < 0.34:
			zone.configure_current(right, RIVER_CURRENT_BASE)
		elif progress < 0.70:
			zone.configure_current((right + forward * 0.34).normalized(), RIVER_CURRENT_STRONG)
		else:
			zone.configure_current(-right, RIVER_CURRENT_EXIT)

		water_transforms.append(_segment_transform(
			a + Vector3.UP * WATER_SURFACE_HEIGHT,
			b + Vector3.UP * WATER_SURFACE_HEIGHT,
			width + WATER_VISUAL_EXTRA_WIDTH,
			0.18,
			0.45
		))

		for side: float in [-1.0, 1.0]:
			var lateral: Vector3 = right * side * (width * 0.5 + 1.55)
			bank_transforms.append(_segment_transform(
				a + lateral + Vector3.UP * 0.18,
				b + lateral + Vector3.UP * 0.18,
				2.6,
				0.34,
				0.25
			))

		if segment_index % 3 == 0:
			var foam_center: Vector3 = a.lerp(b, 0.5) + Vector3.UP * (WATER_SURFACE_HEIGHT + 0.11)
			var foam_transform := Transform3D(Basis.IDENTITY, foam_center)
			foam_transform = foam_transform.looking_at(foam_center + forward, Vector3.UP)
			foam_transform.basis = foam_transform.basis.scaled(Vector3(width * 0.62, 0.035, 0.36))
			foam_transforms.append(foam_transform)

	_add_box_multimesh("V2LongRiverWater", water_transforms, _water_material())
	_add_box_multimesh("V2LongRiverBanks", bank_transforms, _bank_material())
	_add_box_multimesh("V2LongRiverFoam", foam_transforms, _foam_material())

func _build_mountain_gameplay() -> void:
	var section_range: Vector2i = _get_range(&"mountain_ascent")
	if section_range.x < 0:
		return
	for segment_index: int in range(section_range.x, section_range.y + 1):
		_add_terrain_zone_for_segment(segment_index, &"climb", "mountain")
	_build_mountain_mass(section_range)

func _build_summit_gameplay() -> void:
	var section_range: Vector2i = _get_range(&"summit_ridge")
	if section_range.x < 0:
		return
	for segment_index: int in range(section_range.x, section_range.y + 1):
		_add_terrain_zone_for_segment(segment_index, &"summit", "summit")
	var middle_index: int = clampi((section_range.x + section_range.y) / 2, 0, _route.size() - 2)
	var point: Vector3 = _route[middle_index]
	var next: Vector3 = _route[middle_index + 1]
	var right: Vector3 = Vector3(-_planar_forward(point, next).z, 0.0, _planar_forward(point, next).x)
	var width: float = _track.get_v2_width_for_segment(middle_index)
	var marker_transforms: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		marker_transforms.append(Transform3D(
			Basis.IDENTITY.scaled(Vector3(0.42, 5.8, 0.42)),
			point + right * side * (width * 0.5 - 0.8) + Vector3.UP * 2.9
		))
	marker_transforms.append(Transform3D(
		Basis.IDENTITY.scaled(Vector3(width - 1.6, 0.48, 0.48)),
		point + Vector3.UP * 5.55
	))
	_add_box_multimesh("V2SummitGateway", marker_transforms, _summit_material())

func _build_rough_descent() -> void:
	var section_range: Vector2i = _get_range(&"rough_descent")
	if section_range.x < 0:
		return
	var mud_transforms: Array[Transform3D] = []
	var gravel_transforms: Array[Transform3D] = []
	for segment_index: int in range(section_range.x, section_range.y + 1):
		_add_terrain_zone_for_segment(segment_index, &"rough", "descent")
		if segment_index % 2 == 0:
			var a: Vector3 = _route[segment_index]
			var b: Vector3 = _route[segment_index + 1]
			var width: float = _track.get_v2_width_for_segment(segment_index)
			var forward: Vector3 = _planar_forward(a, b)
			var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
			var lateral_amount: float = -width * 0.18 if segment_index % 4 == 0 else width * 0.18
			var lateral: Vector3 = right * lateral_amount
			var patch: Transform3D = _segment_transform(
				a + lateral + Vector3.UP * 0.09,
				b + lateral + Vector3.UP * 0.09,
				width * 0.46,
				0.035,
				-2.0
			)
			if segment_index % 4 == 0:
				mud_transforms.append(patch)
			else:
				gravel_transforms.append(patch)
	_add_box_multimesh("V2RoughMudPatches", mud_transforms, _mud_material())
	_add_box_multimesh("V2RoughGravelPatches", gravel_transforms, _gravel_material())

func _build_stage2_obstacles() -> void:
	_spawn_obstacle(&"long_river", 0.24, -4.2, &"river_rock_a", Vector3(3.2, 1.7, 3.2), 4.2, 0.56, false, &"rock", 0.72)
	_spawn_obstacle(&"long_river", 0.43, 3.4, &"river_log_a", Vector3(4.8, 0.75, 1.15), 3.6, 0.62, true, &"log", 0.83)
	_spawn_obstacle(&"long_river", 0.66, -2.8, &"river_rock_b", Vector3(2.8, 1.45, 2.8), 4.0, 0.58, false, &"rock", 0.70)
	_spawn_obstacle(&"long_river", 0.82, 3.8, &"river_log_b", Vector3(4.2, 0.72, 1.0), 3.4, 0.64, true, &"log", 0.82)
	_spawn_obstacle(&"mountain_ascent", 0.28, -2.8, &"mountain_rock_a", Vector3(2.4, 1.6, 2.4), 4.5, 0.55, true, &"rock", 0.78)
	_spawn_obstacle(&"mountain_ascent", 0.58, 2.6, &"mountain_rock_b", Vector3(2.2, 1.45, 2.2), 4.3, 0.57, true, &"rock", 0.74)
	_spawn_obstacle(&"mountain_ascent", 0.78, 0.0, &"mountain_log", Vector3(4.6, 0.72, 1.0), 3.9, 0.60, true, &"log", 0.74)
	_spawn_obstacle(&"rough_descent", 0.31, 2.8, &"descent_rock_a", Vector3(2.7, 1.7, 2.7), 4.8, 0.52, true, &"rock", 0.80)
	_spawn_obstacle(&"rough_descent", 0.63, -3.0, &"descent_rock_b", Vector3(2.5, 1.5, 2.5), 4.6, 0.54, true, &"rock", 0.78)

func _spawn_obstacle(
	section_id: StringName,
	progress: float,
	lateral_offset: float,
	obstacle_id: StringName,
	size: Vector3,
	impact_strength: float,
	retention: float,
	breakable: bool,
	shape_kind: StringName,
	vertical_offset: float
) -> void:
	var section_range: Vector2i = _get_range(section_id)
	if section_range.x < 0:
		return
	var segment_index: int = clampi(roundi(lerpf(float(section_range.x), float(section_range.y), clampf(progress, 0.0, 1.0))), section_range.x, section_range.y)
	var a: Vector3 = _route[segment_index]
	var b: Vector3 = _route[segment_index + 1]
	var forward: Vector3 = _planar_forward(a, b)
	var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
	var obstacle := WildDashGrandPrixV2LightObstacle.new()
	obstacle.name = String(obstacle_id)
	obstacle.position = a.lerp(b, 0.5) + right * lateral_offset + Vector3.UP * vertical_offset
	_obstacle_root.add_child(obstacle)
	obstacle.look_at(obstacle.global_position + forward, Vector3.UP)
	obstacle.configure(obstacle_id, size, _rock_material() if shape_kind == &"rock" else _wood_material(), impact_strength, retention, breakable, shape_kind)

func _add_terrain_zone_for_segment(segment_index: int, terrain_type: StringName, prefix: String) -> void:
	if segment_index < 0 or segment_index + 1 >= _route.size():
		return
	var a: Vector3 = _route[segment_index]
	var b: Vector3 = _route[segment_index + 1]
	var width: float = _track.get_v2_width_for_segment(segment_index)
	var zone := WildDashTerrainZone.new()
	zone.name = "%s_%03d" % [prefix, segment_index]
	_terrain_root.add_child(zone)
	zone.configure_route_box(StringName("%s_%03d" % [prefix, segment_index]), terrain_type, a, b, width + 0.8, TERRAIN_ZONE_HEIGHT)

func _build_mountain_mass(section_range: Vector2i) -> void:
	var transforms: Array[Transform3D] = []
	var stride: int = 6
	var mountain_index: int = 0
	for segment_index: int in range(section_range.x, section_range.y + 1, stride):
		var a: Vector3 = _route[segment_index]
		var b: Vector3 = _route[min(segment_index + 1, _route.size() - 1)]
		var forward: Vector3 = _planar_forward(a, b)
		var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
		var width: float = _track.get_v2_width_for_segment(segment_index)
		for side: float in [-1.0, 1.0]:
			var height: float = 18.0 + float((mountain_index * 7) % 5) * 3.2
			var radius: float = 7.0 + float((mountain_index * 5) % 4) * 1.8
			var lateral: float = side * (width * 0.5 + 10.0 + float(mountain_index % 3) * 3.5)
			var origin: Vector3 = a + right * lateral + Vector3.UP * (height * 0.44 - 1.5)
			var basis := Basis(Vector3.UP, float(mountain_index) * 0.47).scaled(Vector3(radius, height, radius * 0.82))
			transforms.append(Transform3D(basis, origin))
			mountain_index += 1
	_add_mountain_multimesh("V2MountainMass", transforms, _rock_material())

func _section_length(section_id: StringName) -> float:
	var section_range: Vector2i = _get_range(section_id)
	if section_range.x < 0:
		return 0.0
	var total: float = 0.0
	for segment_index: int in range(section_range.x, section_range.y + 1):
		total += _route[segment_index].distance_to(_route[segment_index + 1])
	return total

func _get_range(section_id: StringName) -> Vector2i:
	if not _ranges.has(section_id):
		return Vector2i(-1, -1)
	return _ranges[section_id] as Vector2i

func _find_v2_track(node: Node) -> WildDashGrandPrixV2Track:
	if node is WildDashGrandPrixV2Track:
		return node as WildDashGrandPrixV2Track
	for child: Node in node.get_children():
		var found: WildDashGrandPrixV2Track = _find_v2_track(child)
		if found != null:
			return found
	return null

func _planar_forward(a: Vector3, b: Vector3) -> Vector3:
	var result: Vector3 = b - a
	result.y = 0.0
	if result.length_squared() <= 0.001:
		return Vector3.FORWARD
	return result.normalized()

func _segment_transform(from_point: Vector3, to_point: Vector3, width: float, height: float, length_extra: float) -> Transform3D:
	var distance: float = from_point.distance_to(to_point)
	var midpoint: Vector3 = (from_point + to_point) * 0.5
	var transform := Transform3D(Basis.IDENTITY, midpoint)
	transform = transform.looking_at(to_point, Vector3.UP)
	transform.basis = transform.basis.scaled(Vector3(width, height, distance + length_extra))
	return transform

func _add_box_multimesh(node_name: String, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3.ONE
	_add_chunked_multimesh(node_name, mesh, transforms, material)

func _add_mountain_multimesh(node_name: String, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	var mountain: CylinderMesh = CylinderMesh.new()
	mountain.top_radius = 0.22
	mountain.bottom_radius = 1.0
	mountain.height = 1.0
	mountain.radial_segments = 7
	mountain.rings = 1
	_add_chunked_multimesh(node_name, mountain, transforms, material)

func _add_chunked_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], material: Material) -> void:
	var buckets: Dictionary = {}
	for transform: Transform3D in transforms:
		var chunk_index: int = _chunk_for_origin(transform.origin)
		var bucket: Array = buckets.get(chunk_index, [])
		bucket.append(transform)
		buckets[chunk_index] = bucket
	var keys: Array = buckets.keys()
	keys.sort()
	for chunk_key: Variant in keys:
		var chunk_transforms: Array = buckets[chunk_key]
		if chunk_transforms.is_empty():
			continue
		var multimesh: MultiMesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = chunk_transforms.size()
		for index: int in range(chunk_transforms.size()):
			multimesh.set_instance_transform(index, chunk_transforms[index] as Transform3D)
		multimesh.custom_aabb = _tight_aabb(chunk_transforms, 2.0)
		var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
		instance.name = "%s_Chunk_%02d" % [node_name, int(chunk_key)]
		instance.multimesh = multimesh
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual_root.add_child(instance)
		_visual_multimesh_count += 1

func _chunk_for_origin(origin: Vector3) -> int:
	if _route.is_empty() or _route_distances.is_empty():
		return 0
	var best_index: int = 0
	var best_distance: float = INF
	for point_index: int in range(_route.size()):
		var distance: float = origin.distance_squared_to(_route[point_index])
		if distance < best_distance:
			best_distance = distance
			best_index = point_index
	return int(floor(_route_distances[best_index] / VISUAL_CHUNK_LENGTH))

func _tight_aabb(transforms: Array, margin: float) -> AABB:
	var first: Transform3D = transforms[0] as Transform3D
	var minimum: Vector3 = first.origin
	var maximum: Vector3 = first.origin
	for value: Variant in transforms:
		var transform: Transform3D = value as Transform3D
		var extents: Vector3 = Vector3(transform.basis.x.length(), transform.basis.y.length(), transform.basis.z.length()) * 0.7 + Vector3.ONE * 0.3
		minimum.x = minf(minimum.x, transform.origin.x - extents.x)
		minimum.y = minf(minimum.y, transform.origin.y - extents.y)
		minimum.z = minf(minimum.z, transform.origin.z - extents.z)
		maximum.x = maxf(maximum.x, transform.origin.x + extents.x)
		maximum.y = maxf(maximum.y, transform.origin.y + extents.y)
		maximum.z = maxf(maximum.z, transform.origin.z + extents.z)
	var padding: Vector3 = Vector3.ONE * margin
	return AABB(minimum - padding, maximum - minimum + padding * 2.0)

func _material_from_palette(key: StringName, fallback: Color) -> Material:
	if _palette.has(key):
		return _palette[key] as Material
	var material := StandardMaterial3D.new()
	material.albedo_color = fallback
	material.roughness = 0.82
	return material

func _water_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.06, 0.48, 0.72, 1.0)
	material.roughness = 0.22
	material.metallic = 0.05
	return material

func _foam_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.72, 0.94, 1.0, 1.0)
	material.roughness = 0.32
	return material

func _bank_material() -> Material:
	return _material_from_palette(&"dirt", Color(0.34, 0.24, 0.13))

func _rock_material() -> Material:
	return _material_from_palette(&"rock", Color(0.32, 0.34, 0.36))

func _wood_material() -> Material:
	return _material_from_palette(&"wood", Color(0.34, 0.20, 0.09))

func _mud_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.19, 0.11, 0.065, 1.0)
	material.roughness = 0.98
	return material

func _gravel_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.30, 0.31, 0.30, 1.0)
	material.roughness = 0.94
	return material

func _summit_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.58, 0.12, 1.0)
	material.roughness = 0.45
	return material
