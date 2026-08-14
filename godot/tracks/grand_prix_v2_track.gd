class_name WildDashGrandPrixV2Track
extends WildDashGrandPrixTrack

## Round 1 Adventure V2.5.
## Route geometry, road ribbon, playable shoulder, static collision, AI path and
## checkpoints all consume one sampled layout bundle. The old BoxShape road
## contract remains in git history only; V2.5 runtime uses section ribbons.

const ROAD_SURFACE_LIFT: float = 0.04
const FINISH_RUNOUT_DISTANCE: float = 18.0
const UV_METERS_PER_TILE: float = 8.0

var _v2_bundle: Dictionary = {}
var _v2_route: Array[Vector3] = []
var _v2_segment_widths: Array[float] = []
var _v2_segment_sections: Array[StringName] = []
var _v2_checkpoint_positions: Array[Vector3] = []
var _v2_sections: Array[WildDashGrandPrixV2Section] = []
var _v2_track_length: float = 0.0
var _v2_decoration_root: Node3D
var _v2_collision_body: StaticBody3D
var _v2_materials: Dictionary = {}
var _road_mesh_count: int = 0
var _shoulder_mesh_count: int = 0
var _road_collision_shape_count: int = 0

func _ready() -> void:
	_v2_materials = WildDashEnvironmentMaterialLibrary.get_palette()
	_v2_bundle = WildDashGrandPrixV2Layout.build_route_bundle()
	_v2_route = _v2_bundle["points"]
	_v2_segment_widths = _v2_bundle["segment_widths"]
	_v2_segment_sections = _v2_bundle["segment_sections"]
	_v2_sections = _v2_bundle["sections"]
	_v2_checkpoint_positions = WildDashGrandPrixV2Layout.build_checkpoint_positions(_v2_bundle)
	_v2_track_length = WildDashGrandPrixV2Layout.get_total_length(_v2_bundle)

	_build_v2_roots()
	_build_v2_environment()
	_build_v2_road_and_collision()
	_build_v2_start_marker()
	_build_v2_checkpoints()
	_build_v2_finish()

	RaceManager.configure_track(get_route_points(), get_checkpoint_positions())
	var elevation: Vector2 = WildDashGrandPrixV2Layout.get_elevation_range(_v2_bundle)
	print("GRAND PRIX V2.5 READY sections=%d route_points=%d segments=%d checkpoints=%d length=%.1fm elevation=%.1f..%.1f max_vertical_step=%.2f road_meshes=%d shoulder_meshes=%d road_collisions=%d collision_source=section_ribbon" % [
		_v2_sections.size(), _v2_route.size(), _v2_segment_widths.size(), _v2_checkpoint_positions.size(),
		_v2_track_length, elevation.x, elevation.y, WildDashGrandPrixV2Layout.get_max_vertical_step(_v2_bundle),
		_road_mesh_count, _shoulder_mesh_count, _road_collision_shape_count,
	])
	call_deferred("_report_performance_once")

func is_v2_layout() -> bool:
	return true

func get_route_points() -> Array[Vector3]:
	return _v2_route.duplicate()

func get_checkpoint_positions() -> Array[Vector3]:
	return _v2_checkpoint_positions.duplicate()

func get_track_length() -> float:
	return _v2_track_length

func get_start_position() -> Vector3:
	return _v2_route[0] if not _v2_route.is_empty() else Vector3.ZERO

func get_finish_position() -> Vector3:
	return _v2_route[-1] if not _v2_route.is_empty() else Vector3.ZERO

func get_shortcut_a_saving() -> float:
	return 0.0

func get_shortcut_b_saving() -> float:
	return 0.0

func get_runtime_node_count() -> int:
	return _count_v2_nodes(self)

func get_v2_sections() -> Array[WildDashGrandPrixV2Section]:
	return _v2_sections.duplicate()

func get_v2_section_ranges() -> Dictionary:
	var ranges: Dictionary = _v2_bundle.get("section_ranges", {})
	return ranges.duplicate(true)

func get_v2_section_id_for_segment(segment_index: int) -> StringName:
	if segment_index < 0 or segment_index >= _v2_segment_sections.size():
		return &""
	return _v2_segment_sections[segment_index]

func get_v2_width_for_segment(segment_index: int) -> float:
	if segment_index < 0 or segment_index >= _v2_segment_widths.size():
		return 16.0
	return _v2_segment_widths[segment_index]

func get_v2_shoulder_width_for_segment(segment_index: int) -> float:
	return WildDashGrandPrixV2Geometry.shoulder_width_for_section(get_v2_section_id_for_segment(segment_index))

func get_v2_barrier_profile_for_segment(segment_index: int) -> StringName:
	return WildDashGrandPrixV2Geometry.barrier_profile_for_section(get_v2_section_id_for_segment(segment_index))

func get_v2_road_edge_point(point_index: int, side: float) -> Vector3:
	if point_index < 0 or point_index >= _v2_route.size():
		return Vector3.ZERO
	return WildDashGrandPrixV2Geometry.road_edge_point(_v2_route, _v2_segment_widths, point_index, side)

func get_v2_shoulder_edge_point(point_index: int, side: float) -> Vector3:
	if point_index < 0 or point_index >= _v2_route.size():
		return Vector3.ZERO
	return WildDashGrandPrixV2Geometry.shoulder_edge_point(
		_v2_route, _v2_segment_widths, _v2_segment_sections, point_index, side
	)

func get_v2_barrier_point(point_index: int, side: float) -> Vector3:
	if point_index < 0 or point_index >= _v2_route.size():
		return Vector3.ZERO
	return WildDashGrandPrixV2Geometry.barrier_point(
		_v2_route, _v2_segment_widths, _v2_segment_sections, point_index, side
	)

func get_v2_road_mesh_count() -> int:
	return _road_mesh_count

func get_v2_shoulder_mesh_count() -> int:
	return _shoulder_mesh_count

func get_v2_road_collision_shape_count() -> int:
	return _road_collision_shape_count

func _build_v2_roots() -> void:
	_v2_decoration_root = Node3D.new()
	_v2_decoration_root.name = "DecorationGeometry"
	add_child(_v2_decoration_root)

	_v2_collision_body = StaticBody3D.new()
	_v2_collision_body.name = "GameplayCollision"
	_v2_collision_body.collision_layer = 1
	_v2_collision_body.collision_mask = 0
	add_child(_v2_collision_body)

func _build_v2_environment() -> void:
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.name = "V2Sun"
	light.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	light.light_energy = 1.15
	light.shadow_enabled = true
	add_child(light)

	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.name = "V2WorldEnvironment"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.34, 0.58, 0.76)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.68, 0.78)
	env.ambient_light_energy = 0.78
	environment.environment = env
	add_child(environment)

func _build_v2_road_and_collision() -> void:
	if _v2_route.size() < 2:
		return
	var ranges: Dictionary = get_v2_section_ranges()
	for section: WildDashGrandPrixV2Section in _v2_sections:
		if not ranges.has(section.id):
			continue
		var section_range: Vector2i = ranges[section.id] as Vector2i
		var start_point: int = clampi(section_range.x, 0, _v2_route.size() - 2)
		var end_point: int = clampi(section_range.y + 1, start_point + 1, _v2_route.size() - 1)

		var road_mesh: ArrayMesh = _build_center_ribbon_mesh(start_point, end_point, false)
		_add_section_mesh("V2Road_%s" % String(section.id), road_mesh, _material_for_key(_material_key_for_section(section.id)))
		_road_mesh_count += 1

		var shoulder_mesh: ArrayMesh = _build_shoulder_ribbon_mesh(start_point, end_point)
		_add_section_mesh("V2Shoulder_%s" % String(section.id), shoulder_mesh, _shoulder_material_for_section(section.id))
		_shoulder_mesh_count += 1

		# Collision spans the road plus shoulder so the shoulder is actual playable
		# ground. It comes from the same sampled vertices as the visible ribbons.
		var collision_mesh: ArrayMesh = _build_center_ribbon_mesh(start_point, end_point, true)
		_add_static_trimesh_collision("RoadRibbon_%s" % String(section.id), collision_mesh)

func _build_center_ribbon_mesh(start_point: int, end_point: int, include_shoulder: bool) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var distance_along: float = 0.0

	for point_index: int in range(start_point, end_point + 1):
		if point_index > start_point:
			distance_along += _v2_route[point_index - 1].distance_to(_v2_route[point_index])
		var normal: Vector3 = WildDashGrandPrixV2Geometry.road_normal_at(_v2_route, point_index)
		var left: Vector3
		var right: Vector3
		if include_shoulder:
			left = get_v2_shoulder_edge_point(point_index, -1.0)
			right = get_v2_shoulder_edge_point(point_index, 1.0)
		else:
			left = get_v2_road_edge_point(point_index, -1.0)
			right = get_v2_road_edge_point(point_index, 1.0)
		left += normal * ROAD_SURFACE_LIFT
		right += normal * ROAD_SURFACE_LIFT
		vertices.append(left)
		vertices.append(right)
		normals.append(normal)
		normals.append(normal)
		uvs.append(Vector2(0.0, distance_along / UV_METERS_PER_TILE))
		uvs.append(Vector2(1.0, distance_along / UV_METERS_PER_TILE))

	var point_count: int = end_point - start_point + 1
	for local_index: int in range(point_count - 1):
		var base: int = local_index * 2
		indices.append(base)
		indices.append(base + 1)
		indices.append(base + 2)
		indices.append(base + 1)
		indices.append(base + 3)
		indices.append(base + 2)

	return _array_mesh(vertices, normals, uvs, indices)

func _build_shoulder_ribbon_mesh(start_point: int, end_point: int) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var distance_along: float = 0.0

	for point_index: int in range(start_point, end_point + 1):
		if point_index > start_point:
			distance_along += _v2_route[point_index - 1].distance_to(_v2_route[point_index])
		var normal: Vector3 = WildDashGrandPrixV2Geometry.road_normal_at(_v2_route, point_index)
		var left_outer: Vector3 = get_v2_shoulder_edge_point(point_index, -1.0) + normal * (ROAD_SURFACE_LIFT - 0.01)
		var left_inner: Vector3 = get_v2_road_edge_point(point_index, -1.0) + normal * (ROAD_SURFACE_LIFT - 0.01)
		var right_inner: Vector3 = get_v2_road_edge_point(point_index, 1.0) + normal * (ROAD_SURFACE_LIFT - 0.01)
		var right_outer: Vector3 = get_v2_shoulder_edge_point(point_index, 1.0) + normal * (ROAD_SURFACE_LIFT - 0.01)
		for point: Vector3 in [left_outer, left_inner, right_inner, right_outer]:
			vertices.append(point)
			normals.append(normal)
		uvs.append(Vector2(0.0, distance_along / UV_METERS_PER_TILE))
		uvs.append(Vector2(0.22, distance_along / UV_METERS_PER_TILE))
		uvs.append(Vector2(0.78, distance_along / UV_METERS_PER_TILE))
		uvs.append(Vector2(1.0, distance_along / UV_METERS_PER_TILE))

	var point_count: int = end_point - start_point + 1
	for local_index: int in range(point_count - 1):
		var base: int = local_index * 4
		var next: int = base + 4
		# Left strip: outer -> inner.
		indices.append(base)
		indices.append(base + 1)
		indices.append(next)
		indices.append(base + 1)
		indices.append(next + 1)
		indices.append(next)
		# Right strip: inner -> outer.
		indices.append(base + 2)
		indices.append(base + 3)
		indices.append(next + 2)
		indices.append(base + 3)
		indices.append(next + 3)
		indices.append(next + 2)

	return _array_mesh(vertices, normals, uvs, indices)

func _array_mesh(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _add_section_mesh(node_name: String, mesh: ArrayMesh, material: Material) -> void:
	if mesh.get_surface_count() == 0:
		return
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	_v2_decoration_root.add_child(instance)

func _add_static_trimesh_collision(node_name: String, mesh: ArrayMesh) -> void:
	if mesh.get_surface_count() == 0:
		return
	var shape: Shape3D = mesh.create_trimesh_shape()
	if shape == null:
		push_warning("GrandPrixV2Track: failed to create trimesh collision for %s" % node_name)
		return
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = node_name
	collision.shape = shape
	_v2_collision_body.add_child(collision)
	_road_collision_shape_count += 1

func _build_v2_start_marker() -> void:
	if _v2_route.size() < 2:
		return
	_add_marker_visual("V2StartStripe", _v2_route[0], _v2_route[1], get_v2_width_for_segment(0), _material_for_key(&"warning"))

func _build_v2_checkpoints() -> void:
	for checkpoint_index: int in range(_v2_checkpoint_positions.size()):
		var point: Vector3 = _v2_checkpoint_positions[checkpoint_index]
		var route_index: int = _nearest_route_index(point)
		var next_index: int = mini(route_index + 1, _v2_route.size() - 1)
		var next_point: Vector3 = _v2_route[next_index]
		var width: float = get_v2_width_for_segment(mini(route_index, _v2_segment_widths.size() - 1))

		var area: Area3D = Area3D.new()
		area.name = "V2Checkpoint_%02d" % (checkpoint_index + 1)
		area.set_script(CHECKPOINT_SCRIPT)
		area.set("checkpoint_index", checkpoint_index)
		area.position = point + Vector3.UP * 1.75
		area.collision_mask = 2
		add_child(area)
		area.look_at(next_point + Vector3.UP * 1.75, Vector3.UP)
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(width + 1.5, 4.2, 7.0)
		collision.shape = shape
		area.add_child(collision)
		_add_marker_visual("V2CheckpointStripe_%02d" % (checkpoint_index + 1), point, next_point, width, _material_for_key(&"warning"))

func _build_v2_finish() -> void:
	if _v2_route.size() < 2:
		return
	var finish: Vector3 = _v2_route[-1]
	var previous: Vector3 = _v2_route[-2]
	var direction: Vector3 = finish - previous
	if direction.length_squared() <= 0.001:
		return
	var next_point: Vector3 = finish + direction.normalized() * FINISH_RUNOUT_DISTANCE
	var finish_width: float = get_v2_width_for_segment(_v2_segment_widths.size() - 1)
	var runout_mesh: ArrayMesh = _build_runout_mesh(finish, next_point, finish_width)
	_add_section_mesh("V2FinishRunout", runout_mesh, _material_for_key(&"asphalt"))
	_add_static_trimesh_collision("RoadRibbon_finish_runout", runout_mesh)
	_road_mesh_count += 1

	var area: Area3D = Area3D.new()
	area.name = "FinishLine"
	area.set_script(FINISH_SCRIPT)
	area.position = finish + Vector3.UP * 1.8
	area.collision_mask = 2
	add_child(area)
	area.look_at(next_point + Vector3.UP * 1.8, Vector3.UP)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(finish_width + 1.5, 4.2, 7.0)
	collision.shape = shape
	area.add_child(collision)
	_add_marker_visual("V2FinishStripe", finish, next_point, finish_width, _material_for_key(&"warning"))

func _build_runout_mesh(from: Vector3, to: Vector3, width: float) -> ArrayMesh:
	var direction: Vector3 = to - from
	var planar: Vector3 = Vector3(direction.x, 0.0, direction.z)
	if planar.length_squared() <= 0.001:
		planar = Vector3.FORWARD
	planar = planar.normalized()
	var right: Vector3 = Vector3(-planar.z, 0.0, planar.x)
	var normal: Vector3 = Vector3.UP
	var half_width: float = width * 0.5
	var vertices: PackedVector3Array = PackedVector3Array([
		from - right * half_width + normal * ROAD_SURFACE_LIFT,
		from + right * half_width + normal * ROAD_SURFACE_LIFT,
		to - right * half_width + normal * ROAD_SURFACE_LIFT,
		to + right * half_width + normal * ROAD_SURFACE_LIFT,
	])
	var normals: PackedVector3Array = PackedVector3Array([normal, normal, normal, normal])
	var uvs: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0),
		Vector2(0.0, FINISH_RUNOUT_DISTANCE / UV_METERS_PER_TILE), Vector2(1.0, FINISH_RUNOUT_DISTANCE / UV_METERS_PER_TILE),
	])
	var indices: PackedInt32Array = PackedInt32Array([0, 1, 2, 1, 3, 2])
	return _array_mesh(vertices, normals, uvs, indices)

func _add_marker_visual(node_name: String, point: Vector3, target: Vector3, width: float, material: Material) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(width, 0.07, 1.25)
	mesh.material = material
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.name = node_name
	marker.mesh = mesh
	marker.position = point + Vector3.UP * 0.08
	_v2_decoration_root.add_child(marker)
	marker.look_at(target + Vector3.UP * 0.08, Vector3.UP)

func _material_key_for_section(section_id: StringName) -> StringName:
	match section_id:
		&"forest_obstacle", &"mountain_approach", &"mountain_ascent", &"rough_descent", &"canyon_obstacle":
			return &"dirt_road"
		&"long_river":
			return &"bridge_road"
		_:
			return &"asphalt"

func _shoulder_material_for_section(section_id: StringName) -> Material:
	if section_id == &"long_river" and _v2_materials.has(&"rock"):
		return _v2_materials[&"rock"] as Material
	if _v2_materials.has(&"dirt"):
		return _v2_materials[&"dirt"] as Material
	if _v2_materials.has(&"dirt_road"):
		return _v2_materials[&"dirt_road"] as Material
	return _material_for_key(&"asphalt")

func _material_for_key(key: StringName) -> Material:
	if key == &"warning" and _v2_materials.has(&"curb_warning"):
		return _v2_materials[&"curb_warning"] as Material
	if _v2_materials.has(key):
		return _v2_materials[key] as Material
	if _v2_materials.has(&"asphalt"):
		return _v2_materials[&"asphalt"] as Material
	var fallback: StandardMaterial3D = StandardMaterial3D.new()
	fallback.albedo_color = Color(0.14, 0.17, 0.19)
	fallback.roughness = 0.88
	return fallback

func _nearest_route_index(point: Vector3) -> int:
	var best_index: int = 0
	var best_distance: float = INF
	for index: int in range(_v2_route.size()):
		var distance: float = point.distance_squared_to(_v2_route[index])
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index

func _count_v2_nodes(node: Node) -> int:
	var count: int = 1
	for child: Node in node.get_children():
		count += _count_v2_nodes(child)
	return count

func _report_performance_once() -> void:
	await get_tree().create_timer(1.5).timeout
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var node_count: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var draw_calls: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var physics_objects: float = Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	print("GRAND PRIX V2 PERF fps=%.1f road_meshes=%d shoulder_meshes=%d road_collision_shapes=%d runtime_nodes=%d monitor_nodes=%.0f draw_calls=%.0f physics_active=%.0f" % [
		fps, _road_mesh_count, _shoulder_mesh_count, _road_collision_shape_count,
		get_runtime_node_count(), node_count, draw_calls, physics_objects,
	])
