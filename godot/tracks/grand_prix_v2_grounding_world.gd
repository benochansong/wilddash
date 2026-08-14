class_name WildDashGrandPrixV2GroundingWorld
extends Node3D

## V2.6 grounded-world recovery layer.
## Adds closed road subgrade below the full road+shoulder width, sloped far-edge
## skirts to hide blue void, and one readable hero landmark per biome. Ground
## mass stays visible; only backdrop landmark roots use a wider distance chunk
## window than TerrainShell's near-detail window.

const CHUNK_LENGTH: float = 100.0
const SUBGRADE_TOP_DROP: float = 0.14
const SUBGRADE_DEPTH: float = 0.42
const TERRAIN_SKIRT_OUTSET: float = 14.0
const BACKDROP_ACTIVE_RADIUS: int = 5
const FOCUS_UPDATE_INTERVAL: float = 0.25
const MAX_REASONABLE_CHUNK_AABB: float = 210.0

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _segment_widths: Array[float] = []
var _segment_sections: Array[StringName] = []
var _section_ranges: Dictionary = {}
var _chunk_ranges: Array[Vector2i] = []
var _backdrop_roots: Array[Node3D] = []
var _subgrade_mesh_count: int = 0
var _skirt_mesh_count: int = 0
var _landmark_mesh_count: int = 0
var _visible_backdrop_chunks: int = 0
var _focus_elapsed: float = 0.0
var _debug_visuals: bool = false
var _debug_label: Label

func _ready() -> void:
	process_priority = 119
	_debug_visuals = OS.has_environment("WILDDASH_V2_WORLD_DEBUG")
	call_deferred("_build_when_ready")

func _build_when_ready() -> void:
	for _frame: int in range(5):
		await get_tree().process_frame
	_track = _find_v2_track(get_parent())
	if _track == null:
		push_warning("GrandPrixV2GroundingWorld: V2 track unavailable")
		return
	_route = _track.get_route_points()
	if _route.size() < 2:
		return
	var bundle: Dictionary = WildDashGrandPrixV2Layout.build_route_bundle()
	_segment_widths = bundle["segment_widths"]
	_segment_sections = bundle["segment_sections"]
	_section_ranges = bundle["section_ranges"]
	_chunk_ranges = _build_chunk_ranges()
	for chunk_index: int in range(_chunk_ranges.size()):
		_build_chunk(chunk_index, _chunk_ranges[chunk_index])
	_build_hero_landmarks()
	_update_backdrop_focus(0)
	if _debug_visuals:
		_build_debug_overlay()
	call_deferred("_report_world_activation")
	print("GRAND PRIX V2.6 GROUNDING READY chunks=%d subgrade_meshes=%d skirt_meshes=%d landmark_meshes=%d road_subgrade=true terrain_skirt=true giant_aabb=false debug=%s" % [
		_chunk_ranges.size(), _subgrade_mesh_count, _skirt_mesh_count, _landmark_mesh_count, str(_debug_visuals),
	])

func _process(delta: float) -> void:
	if _chunk_ranges.is_empty() or RaceManager.racers.is_empty():
		return
	_focus_elapsed += delta
	if _focus_elapsed < FOCUS_UPDATE_INTERVAL:
		return
	_focus_elapsed = 0.0
	var focus: Node3D = RaceManager.racers[0] as Node3D
	if focus == null:
		return
	var route_index: int = _nearest_route_index(focus.global_position)
	_update_backdrop_focus(_chunk_index_for_route_point(route_index))

func get_grounding_chunk_count() -> int:
	return _chunk_ranges.size()

func get_subgrade_mesh_count() -> int:
	return _subgrade_mesh_count

func get_skirt_mesh_count() -> int:
	return _skirt_mesh_count

func get_landmark_mesh_count() -> int:
	return _landmark_mesh_count

func get_visible_backdrop_chunk_count() -> int:
	return _visible_backdrop_chunks

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
	root.name = "V2GroundingChunk_%02d" % chunk_index
	add_child(root)
	var ground_root: Node3D = Node3D.new()
	ground_root.name = "GroundMass"
	root.add_child(ground_root)
	var backdrop_root: Node3D = Node3D.new()
	backdrop_root.name = "Backdrop"
	root.add_child(backdrop_root)
	_backdrop_roots.append(backdrop_root)

	var middle_point: int = clampi((point_range.x + point_range.y) / 2, 0, _route.size() - 1)
	var section_id: StringName = WildDashGrandPrixV2Geometry.point_section_id(_segment_sections, middle_point)
	var subgrade: ArrayMesh = _build_subgrade_mesh(point_range.x, point_range.y)
	_add_mesh_instance(ground_root, "RoadSubgrade", subgrade, _subgrade_material(section_id), false)
	_subgrade_mesh_count += 1
	var skirt: ArrayMesh = _build_terrain_skirt_mesh(point_range.x, point_range.y)
	_add_mesh_instance(ground_root, "TerrainSkirt", skirt, _skirt_material(section_id), false)
	_skirt_mesh_count += 1

func _build_subgrade_mesh(start_point: int, end_point: int) -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point_index: int in range(start_point, end_point):
		var normal0: Vector3 = WildDashGrandPrixV2Geometry.road_normal_at(_route, point_index)
		var normal1: Vector3 = WildDashGrandPrixV2Geometry.road_normal_at(_route, point_index + 1)
		var lift: float = WildDashGrandPrixV2Track.ROAD_SURFACE_LIFT - SUBGRADE_TOP_DROP
		var l0_top: Vector3 = _track.get_v2_shoulder_edge_point(point_index, -1.0) + normal0 * lift
		var r0_top: Vector3 = _track.get_v2_shoulder_edge_point(point_index, 1.0) + normal0 * lift
		var l1_top: Vector3 = _track.get_v2_shoulder_edge_point(point_index + 1, -1.0) + normal1 * lift
		var r1_top: Vector3 = _track.get_v2_shoulder_edge_point(point_index + 1, 1.0) + normal1 * lift
		var l0_bottom: Vector3 = l0_top - Vector3.UP * SUBGRADE_DEPTH
		var r0_bottom: Vector3 = r0_top - Vector3.UP * SUBGRADE_DEPTH
		var l1_bottom: Vector3 = l1_top - Vector3.UP * SUBGRADE_DEPTH
		var r1_bottom: Vector3 = r1_top - Vector3.UP * SUBGRADE_DEPTH
		_add_quad(surface, l0_top, r0_top, l1_top, r1_top)
		_add_quad(surface, l0_bottom, l1_bottom, r0_bottom, r1_bottom)
		_add_quad(surface, l0_top, l1_top, l0_bottom, l1_bottom)
		_add_quad(surface, r0_top, r0_bottom, r1_top, r1_bottom)
	surface.generate_normals()
	return surface.commit()

func _build_terrain_skirt_mesh(start_point: int, end_point: int) -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		for point_index: int in range(start_point, end_point):
			var section0: StringName = WildDashGrandPrixV2Geometry.point_section_id(_segment_sections, point_index)
			var section1: StringName = WildDashGrandPrixV2Geometry.point_section_id(_segment_sections, point_index + 1)
			var top0: Vector3 = _far_terrain_point(point_index, side, section0)
			var top1: Vector3 = _far_terrain_point(point_index + 1, side, section1)
			var outward0: Vector3 = top0 - _route[point_index]
			outward0.y = 0.0
			outward0 = outward0.normalized() if outward0.length_squared() > 0.0001 else Vector3.RIGHT * side
			var outward1: Vector3 = top1 - _route[point_index + 1]
			outward1.y = 0.0
			outward1 = outward1.normalized() if outward1.length_squared() > 0.0001 else Vector3.RIGHT * side
			var bottom0: Vector3 = top0 + outward0 * TERRAIN_SKIRT_OUTSET - Vector3.UP * _skirt_drop(section0)
			var bottom1: Vector3 = top1 + outward1 * TERRAIN_SKIRT_OUTSET - Vector3.UP * _skirt_drop(section1)
			_add_quad(surface, top0, bottom0, top1, bottom1)
	surface.generate_normals()
	return surface.commit()

func _far_terrain_point(point_index: int, side: float, section_id: StringName) -> Vector3:
	var widths: Vector2 = WildDashGrandPrixV2TerrainShell.TERRAIN_WIDTHS.get(section_id, Vector2(12.0, 36.0)) as Vector2
	var distance: float = (
		WildDashGrandPrixV2Geometry.point_half_width(_segment_widths, point_index)
		+ WildDashGrandPrixV2Geometry.point_shoulder_width(_segment_sections, point_index)
		+ widths.y
	)
	var point: Vector3 = _route[point_index] + WildDashGrandPrixV2Geometry.lateral_offset(_route, point_index, distance) * side
	point.y = _route[point_index].y + _far_height_offset(section_id, side)
	return point

func _build_hero_landmarks() -> void:
	for section_variant: Variant in _section_ranges.keys():
		var section_id: StringName = StringName(section_variant)
		var section_range: Vector2i = _section_ranges[section_id] as Vector2i
		var point_index: int = clampi((section_range.x + section_range.y + 1) / 2, 0, _route.size() - 1)
		var chunk_index: int = _chunk_index_for_route_point(point_index)
		if chunk_index < 0 or chunk_index >= _backdrop_roots.size():
			continue
		var parent: Node3D = _backdrop_roots[chunk_index]
		var tangent: Vector3 = WildDashGrandPrixV2Geometry.planar_tangent_at(_route, point_index)
		var right: Vector3 = Vector3(-tangent.z, 0.0, tangent.x)
		var edge: float = WildDashGrandPrixV2Geometry.point_half_width(_segment_widths, point_index) + WildDashGrandPrixV2Geometry.point_shoulder_width(_segment_sections, point_index)
		match section_id:
			&"meadow_start":
				_add_farm(parent, _route[point_index] + right * (edge + 25.0), tangent, "MeadowFarm")
			&"forest_obstacle":
				_add_tree(parent, _route[point_index] - right * (edge + 13.0), 10.5, "ForestHeroLeft")
				_add_tree(parent, _route[point_index] + right * (edge + 13.0), 10.5, "ForestHeroRight")
			&"long_river":
				_add_tree(parent, _route[point_index] + right * (edge + 20.0), 9.0, "RiverTreeLineHero")
			&"mountain_approach":
				_add_mountain(parent, _route[point_index] - right * (edge + 32.0), 22.0, "MountainApproachMass")
			&"mountain_ascent":
				_add_mountain(parent, _route[point_index] - right * (edge + 36.0), 31.0, "MountainAscentMass")
			&"summit_ridge":
				_add_summit_marker(parent, _route[point_index], right, edge + 2.5)
			&"rough_descent":
				_add_mountain(parent, _route[point_index] - right * (edge + 28.0), 20.0, "DescentMass")
			&"canyon_obstacle":
				_add_canyon_walls(parent, _route[point_index], right, edge + 10.0)
			&"final_sprint":
				_add_farm(parent, _route[point_index] - right * (edge + 24.0), tangent, "FinalBarn")

func _add_farm(parent: Node3D, ground: Vector3, forward: Vector3, prefix: String) -> void:
	var basis: Basis = Basis.looking_at(forward, Vector3.UP)
	_add_box(parent, prefix + "_Body", Transform3D(basis.scaled(Vector3(8.0, 4.6, 6.0)), ground + Vector3.UP * 2.3), _farm_material(), false)
	var roof_basis: Basis = basis * Basis(Vector3.UP, PI * 0.25)
	_add_cone(parent, prefix + "_Roof", Transform3D(roof_basis.scaled(Vector3(5.2, 2.6, 5.2)), ground + Vector3.UP * 5.4), _roof_material(), false, 4)

func _add_tree(parent: Node3D, ground: Vector3, height: float, prefix: String) -> void:
	_add_cylinder(parent, prefix + "_Trunk", Transform3D(Basis.IDENTITY.scaled(Vector3(0.75, height * 0.48, 0.75)), ground + Vector3.UP * height * 0.24), _wood_material(), true, 7)
	_add_cone(parent, prefix + "_Canopy", Transform3D(Basis.IDENTITY.scaled(Vector3(3.6, height * 0.64, 3.6)), ground + Vector3.UP * height * 0.70), _leaf_material(), true, 8)

func _add_mountain(parent: Node3D, ground: Vector3, height: float, prefix: String) -> void:
	_add_cone(parent, prefix, Transform3D(Basis.IDENTITY.scaled(Vector3(16.0, height, 16.0)), ground + Vector3.UP * (height * 0.42 - 2.0)), _rock_material(), false, 8)

func _add_summit_marker(parent: Node3D, center: Vector3, right: Vector3, distance: float) -> void:
	for side: float in [-1.0, 1.0]:
		_add_box(parent, "SummitPost_%s" % str(side), Transform3D(Basis.IDENTITY.scaled(Vector3(0.55, 5.0, 0.55)), center + right * side * distance + Vector3.UP * 2.5), _wood_material(), true)
	_add_box(parent, "SummitBeam", Transform3D(Basis.IDENTITY.scaled(Vector3(distance * 2.0, 0.45, 0.45)), center + Vector3.UP * 4.7), _wood_material(), true)

func _add_canyon_walls(parent: Node3D, center: Vector3, right: Vector3, distance: float) -> void:
	for side: float in [-1.0, 1.0]:
		_add_box(parent, "CanyonHeroWall_%s" % str(side), Transform3D(Basis.IDENTITY.scaled(Vector3(8.0, 16.0, 12.0)), center + right * side * distance + Vector3.UP * 6.5), _canyon_material(), true)

func _add_box(parent: Node3D, node_name: String, transform: Transform3D, material: Material, cast_shadow: bool) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3.ONE
	_add_primitive(parent, node_name, mesh, transform, material, cast_shadow)

func _add_cone(parent: Node3D, node_name: String, transform: Transform3D, material: Material, cast_shadow: bool, segments: int) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.08
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = segments
	mesh.rings = 1
	_add_primitive(parent, node_name, mesh, transform, material, cast_shadow)

func _add_cylinder(parent: Node3D, node_name: String, transform: Transform3D, material: Material, cast_shadow: bool, segments: int) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = segments
	mesh.rings = 1
	_add_primitive(parent, node_name, mesh, transform, material, cast_shadow)

func _add_primitive(parent: Node3D, node_name: String, mesh: Mesh, transform: Transform3D, material: Material, cast_shadow: bool) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.transform = transform
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	_landmark_mesh_count += 1

func _add_mesh_instance(parent: Node3D, node_name: String, mesh: ArrayMesh, material: Material, cast_shadow: bool) -> void:
	_validate_chunk_aabb(node_name, mesh.get_aabb())
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

func _validate_chunk_aabb(node_name: String, bounds: AABB) -> void:
	if bounds.size.x > MAX_REASONABLE_CHUNK_AABB or bounds.size.z > MAX_REASONABLE_CHUNK_AABB:
		push_warning("V2.6 oversized grounding chunk AABB %s size=(%.1f, %.1f, %.1f)" % [node_name, bounds.size.x, bounds.size.y, bounds.size.z])

func _add_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
	surface.add_vertex(c)
	surface.add_vertex(b)
	surface.add_vertex(d)

func _update_backdrop_focus(focus_chunk: int) -> void:
	_visible_backdrop_chunks = 0
	for chunk_index: int in range(_backdrop_roots.size()):
		var visible_now: bool = abs(chunk_index - focus_chunk) <= BACKDROP_ACTIVE_RADIUS
		_backdrop_roots[chunk_index].visible = visible_now
		if visible_now:
			_visible_backdrop_chunks += 1
	if _debug_label != null:
		_debug_label.text = "V2.6 WORLD ACTIVE\nBackdrop %d / %d" % [_visible_backdrop_chunks, _chunk_ranges.size()]

func _report_world_activation() -> void:
	await get_tree().create_timer(1.2).timeout
	var terrain_shell: Node = get_parent().get_node_or_null("V2TerrainShell")
	var guidance: Node = get_parent().get_node_or_null("V2CourseGuidance")
	var terrain_active: bool = terrain_shell != null and terrain_shell.has_method("get_terrain_chunk_count")
	var terrain_chunks: int = int(terrain_shell.call("get_terrain_chunk_count")) if terrain_active else 0
	var visible_chunks: int = int(terrain_shell.call("get_visible_chunk_count")) if terrain_active else 0
	var terrain_meshes: int = int(terrain_shell.call("get_terrain_mesh_count")) if terrain_active else 0
	var environment_multimeshes: int = int(terrain_shell.call("get_environment_multimesh_count")) if terrain_active else 0
	var guardrail_chunks: int = int(guidance.call("get_barrier_chunk_count")) if guidance != null and guidance.has_method("get_barrier_chunk_count") else 0
	print("GRAND PRIX V2.6 WORLD ACTIVE terrain_shell_active=%s terrain_chunks=%d visible_chunks=%d terrain_meshes=%d environment_multimeshes=%d guardrail_chunks=%d grounding_chunks=%d subgrade_meshes=%d skirt_meshes=%d landmark_meshes=%d backdrop_visible=%d" % [
		str(terrain_active), terrain_chunks, visible_chunks, terrain_meshes, environment_multimeshes,
		guardrail_chunks, _chunk_ranges.size(), _subgrade_mesh_count, _skirt_mesh_count,
		_landmark_mesh_count, _visible_backdrop_chunks,
	])

func _build_debug_overlay() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "V2WorldDebugLayer"
	add_child(layer)
	_debug_label = Label.new()
	_debug_label.name = "V2WorldDebugLabel"
	_debug_label.position = Vector2(18.0, 90.0)
	_debug_label.text = "V2.6 WORLD ACTIVE"
	layer.add_child(_debug_label)

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

func _skirt_drop(section_id: StringName) -> float:
	match section_id:
		&"mountain_approach", &"mountain_ascent", &"rough_descent": return 26.0
		&"canyon_obstacle": return 24.0
		&"long_river": return 16.0
		_: return 18.0

func _subgrade_material(section_id: StringName) -> Material:
	if _debug_visuals:
		return _material(Color(0.96, 0.38, 0.05), 1.0)
	match section_id:
		&"meadow_start", &"forest_obstacle", &"final_sprint", &"long_river": return _material(Color(0.26, 0.19, 0.10), 0.98)
		_: return _material(Color(0.25, 0.24, 0.22), 0.98)

func _skirt_material(section_id: StringName) -> Material:
	if _debug_visuals:
		return _material(Color(0.62, 0.15, 0.78), 1.0)
	match section_id:
		&"meadow_start", &"forest_obstacle", &"final_sprint": return _material(Color(0.14, 0.30, 0.13), 1.0)
		&"long_river": return _material(Color(0.18, 0.22, 0.13), 1.0)
		&"canyon_obstacle": return _canyon_material()
		_: return _rock_material()

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _wood_material() -> Material:
	return _material(Color(0.34, 0.20, 0.09), 0.90)

func _leaf_material() -> Material:
	return _material(Color(0.12, 0.36, 0.15), 0.94)

func _rock_material() -> Material:
	return _material(Color(0.31, 0.32, 0.31), 0.98)

func _canyon_material() -> Material:
	return _material(Color(0.40, 0.25, 0.16), 0.98)

func _farm_material() -> Material:
	return _material(Color(0.66, 0.48, 0.28), 0.90)

func _roof_material() -> Material:
	return _material(Color(0.39, 0.13, 0.07), 0.95)
