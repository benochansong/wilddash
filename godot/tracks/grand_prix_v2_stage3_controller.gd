class_name WildDashGrandPrixV2Stage3Controller
extends Node3D

## Final Round 1 representative-map pass.
## Stage3 now owns gameplay obstacles/hazards only; V2TerrainShell owns the
## chunked decorative world so environment art is not rendered twice.

const OBSTACLE_KINDS: Array[StringName] = [
	&"small_rock", &"large_boulder", &"fallen_log", &"rotating_log",
	&"moving_gate", &"mud_patch", &"rolling_boulder", &"rock_fall",
]

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _ranges: Dictionary = {}
var _root_static: Node3D
var _root_dynamic: Node3D
var _root_environment: Node3D
var _palette: Dictionary = {}
var _static_obstacle_count: int = 0
var _dynamic_hazard_count: int = 0
var _mud_patch_count: int = 0

func _ready() -> void:
	call_deferred("_build_when_ready")

func _build_when_ready() -> void:
	for _frame: int in range(5):
		await get_tree().process_frame
	_track = _find_v2_track(get_parent())
	if _track == null:
		push_warning("GrandPrixV2Stage3Controller: V2 track unavailable")
		return
	_route = _track.get_route_points()
	_ranges = _track.get_v2_section_ranges()
	if _route.size() < 2:
		return
	_palette = WildDashEnvironmentMaterialLibrary.get_palette()
	_build_roots()
	_build_forest_obstacles()
	_build_descent_obstacles()
	_build_canyon_obstacles()
	# Decorative forest/river/mountain/canyon dressing is now generated once by
	# V2TerrainShell in ~100m chunks. Keep only the small finish gate here.
	_build_final_environment()

	var profile: Dictionary = get_difficulty_profile(GameManager.difficulty)
	print("GRAND PRIX V2 STAGE3 READY obstacle_kinds=%d static=%d dynamic=%d mud=%d hazard_speed=%.2f extra_hazards=%s decorative_world=terrain_shell" % [
		OBSTACLE_KINDS.size(), _static_obstacle_count, _dynamic_hazard_count, _mud_patch_count,
		float(profile["hazard_speed"]), str(bool(profile["extra_hazards"])),
	])

func get_dynamic_hazard_count() -> int:
	return _dynamic_hazard_count

func get_dynamic_hazard_active_count() -> int:
	if _root_dynamic == null:
		return 0
	var active_count: int = 0
	for child: Node in _root_dynamic.get_children():
		if child is WildDashGrandPrixV2DynamicHazard and (child as WildDashGrandPrixV2DynamicHazard).is_runtime_active():
			active_count += 1
	return active_count

func _build_roots() -> void:
	_root_static = Node3D.new()
	_root_static.name = "Stage3StaticObstacles"
	add_child(_root_static)
	_root_dynamic = Node3D.new()
	_root_dynamic.name = "Stage3DynamicHazards"
	add_child(_root_dynamic)
	_root_environment = Node3D.new()
	_root_environment.name = "Stage3Environment"
	add_child(_root_environment)

func _build_forest_obstacles() -> void:
	_spawn_light(&"forest_obstacle", 0.18, -4.0, &"forest_small_rock_left", Vector3(2.2, 1.35, 2.2), 3.6, 0.66, true, &"rock")
	_spawn_light(&"forest_obstacle", 0.33, 0.2, &"forest_fallen_log_center", Vector3(5.6, 0.72, 1.15), 4.1, 0.60, true, &"log")
	_spawn_mud_patch(&"forest_obstacle", 0.48, 3.8, 4.4, 11.0)
	_spawn_light(&"forest_obstacle", 0.61, 0.0, &"forest_large_boulder", Vector3(4.0, 2.7, 4.0), 5.8, 0.48, false, &"rock")
	_spawn_dynamic(&"forest_obstacle", 0.77, -0.4, &"forest_rotating_log", &"rotating_log", Vector3(7.6, 0.62, 0.92), Vector3.RIGHT, 0.0, 5.6, 2.5, 1.25, 5.0, 0.53)

func _build_descent_obstacles() -> void:
	_spawn_mud_patch(&"rough_descent", 0.22, -2.6, 4.8, 12.0)
	_spawn_light(&"rough_descent", 0.39, 3.0, &"descent_small_rock", Vector3(2.2, 1.4, 2.2), 4.0, 0.62, true, &"rock")
	_spawn_dynamic(&"rough_descent", 0.58, 0.0, &"descent_rolling_boulder", &"rolling_boulder", Vector3(3.0, 3.0, 3.0), Vector3.RIGHT, 12.0, 6.2, 2.3, 1.30, 6.2, 0.48)
	if bool(get_difficulty_profile(GameManager.difficulty)["extra_hazards"]):
		_spawn_dynamic(&"rough_descent", 0.78, -1.8, &"descent_rolling_boulder_hard", &"rolling_boulder", Vector3(2.7, 2.7, 2.7), Vector3.LEFT, 10.0, 5.7, 2.0, 1.18, 5.8, 0.50)

func _build_canyon_obstacles() -> void:
	_spawn_dynamic(&"canyon_obstacle", 0.20, 0.0, &"canyon_moving_gate", &"moving_gate", Vector3(2.0, 3.4, 1.0), Vector3.RIGHT, 9.0, 5.4, 2.5, 1.15, 5.0, 0.56)
	_spawn_light(&"canyon_obstacle", 0.38, 3.8, &"canyon_large_boulder", Vector3(4.3, 3.0, 4.3), 6.0, 0.46, false, &"rock")
	_spawn_dynamic(&"canyon_obstacle", 0.56, 0.0, &"canyon_rotating_log", &"rotating_log", Vector3(8.0, 0.62, 0.95), Vector3.RIGHT, 0.0, 5.0, 2.2, 1.20, 5.5, 0.52)
	_spawn_dynamic(&"canyon_obstacle", 0.74, -2.5, &"canyon_rock_fall", &"rock_fall", Vector3(2.8, 2.8, 2.8), Vector3.ZERO, 0.0, 5.8, 1.8, 1.35, 6.4, 0.47)
	if bool(get_difficulty_profile(GameManager.difficulty)["extra_hazards"]):
		_spawn_dynamic(&"canyon_obstacle", 0.86, 2.7, &"canyon_rock_fall_hard", &"rock_fall", Vector3(2.5, 2.5, 2.5), Vector3.ZERO, 0.0, 5.1, 1.7, 1.18, 6.0, 0.49)

func _spawn_light(section_id: StringName, progress: float, lateral: float, obstacle_id: StringName, size: Vector3, impact: float, retention: float, breakable: bool, shape_kind: StringName) -> void:
	var pose: Dictionary = _sample_section_pose(section_id, progress, lateral)
	if pose.is_empty():
		return
	var obstacle: WildDashGrandPrixV2LightObstacle = WildDashGrandPrixV2LightObstacle.new()
	obstacle.name = String(obstacle_id)
	_root_static.add_child(obstacle)
	obstacle.global_position = pose["position"] as Vector3
	var forward: Vector3 = pose["forward"] as Vector3
	obstacle.look_at(obstacle.global_position + forward, Vector3.UP)
	var vertical: float = maxf(0.45, size.y * 0.45)
	obstacle.global_position += Vector3.UP * vertical
	obstacle.configure(obstacle_id, size, _rock_material() if shape_kind == &"rock" else _wood_material(), impact, retention, breakable, shape_kind)
	_static_obstacle_count += 1

func _spawn_mud_patch(section_id: StringName, progress: float, lateral: float, width: float, length: float) -> void:
	var pose: Dictionary = _sample_section_pose(section_id, progress, lateral)
	if pose.is_empty():
		return
	var center: Vector3 = pose["position"] as Vector3
	var forward: Vector3 = pose["forward"] as Vector3
	var half: float = length * 0.5
	var from_point: Vector3 = center - forward * half
	var to_point: Vector3 = center + forward * half
	var zone: WildDashTerrainZone = WildDashTerrainZone.new()
	zone.name = "Stage3Mud_%02d" % _mud_patch_count
	_root_static.add_child(zone)
	zone.configure_route_box(StringName("stage3_mud_%02d" % _mud_patch_count), &"rough", from_point, to_point, width, 5.0)
	var patch: MeshInstance3D = MeshInstance3D.new()
	patch.name = "MudVisual"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(width, 0.05, length)
	patch.mesh = mesh
	patch.material_override = _mud_material()
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patch.global_position = center + Vector3.UP * 0.08
	patch.look_at(patch.global_position + forward, Vector3.UP)
	_root_static.add_child(patch)
	_mud_patch_count += 1

func _spawn_dynamic(section_id: StringName, progress: float, lateral: float, hazard_id: StringName, kind: StringName, size: Vector3, axis_local: Vector3, travel: float, cycle: float, active: float, warning: float, impact: float, retention: float) -> void:
	var pose: Dictionary = _sample_section_pose(section_id, progress, lateral)
	if pose.is_empty():
		return
	var forward: Vector3 = pose["forward"] as Vector3
	var right: Vector3 = pose["right"] as Vector3
	var world_axis: Vector3 = right
	if axis_local == Vector3.LEFT:
		world_axis = -right
	elif axis_local == Vector3.FORWARD:
		world_axis = forward
	elif axis_local == Vector3.BACK:
		world_axis = -forward
	elif axis_local == Vector3.ZERO:
		world_axis = Vector3.ZERO
	var hazard: WildDashGrandPrixV2DynamicHazard = WildDashGrandPrixV2DynamicHazard.new()
	hazard.name = String(hazard_id)
	_root_dynamic.add_child(hazard)
	hazard.global_position = pose["position"] as Vector3
	var y_offset: float = maxf(0.55, size.y * 0.52)
	hazard.global_position += Vector3.UP * y_offset
	if kind == &"rotating_log" or kind == &"moving_gate":
		hazard.look_at(hazard.global_position + forward, Vector3.UP)
	var difficulty: Dictionary = get_difficulty_profile(GameManager.difficulty)
	hazard.configure(hazard_id, kind, size, _rock_material() if kind == &"rolling_boulder" or kind == &"rock_fall" else _wood_material(), world_axis, travel, cycle, active, warning, float(difficulty["hazard_speed"]), impact, retention)
	_dynamic_hazard_count += 1

# Legacy environment builders remain for reference/fallback, but are no longer
# called in V2.5 because V2TerrainShell owns chunked world dressing.
func _build_environment() -> void:
	_build_forest_environment()
	_build_river_environment()
	_build_mountain_environment()
	_build_canyon_environment()
	_build_final_environment()

func _build_forest_environment() -> void:
	var trees: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	for section_id: StringName in [&"forest_obstacle", &"final_sprint"]:
		var section_range: Vector2i = _get_range(section_id)
		if section_range.x < 0:
			continue
		for segment_index: int in range(section_range.x, section_range.y + 1, 3):
			var a: Vector3 = _route[segment_index]
			var b: Vector3 = _route[segment_index + 1]
			var forward: Vector3 = _planar_forward(a, b)
			var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
			var road_width: float = _track.get_v2_width_for_segment(segment_index)
			for side: float in [-1.0, 1.0]:
				var tree_height: float = 5.2 + float((segment_index * 7 + int(side * 3.0)) % 5) * 0.75
				var origin: Vector3 = a + right * side * (road_width * 0.5 + 5.5 + float(segment_index % 3))
				trees.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.35, tree_height, 1.35)), origin + Vector3.UP * tree_height * 0.5))
				if segment_index % 2 == 0:
					var bush_origin: Vector3 = a + right * side * (road_width * 0.5 + 2.8)
					bushes.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.8, 1.1, 1.8)), bush_origin + Vector3.UP * 0.55))
	_add_multimesh("ForestTrees", CylinderMesh.new(), trees, _leaf_material())
	_add_multimesh("ForestBushes", SphereMesh.new(), bushes, _bush_material())

func _build_river_environment() -> void:
	var reeds: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var section_range: Vector2i = _get_range(&"long_river")
	if section_range.x < 0:
		return
	for segment_index: int in range(section_range.x, section_range.y + 1, 2):
		var a: Vector3 = _route[segment_index]
		var b: Vector3 = _route[segment_index + 1]
		var forward: Vector3 = _planar_forward(a, b)
		var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
		var width: float = _track.get_v2_width_for_segment(segment_index)
		for side: float in [-1.0, 1.0]:
			var origin: Vector3 = a + right * side * (width * 0.5 + 2.4)
			reeds.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.25, 1.45, 0.25)), origin + Vector3.UP * 0.72))
			if segment_index % 4 == 0:
				var rock_origin: Vector3 = origin + right * side * 1.8
				rocks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(2.2, 1.2, 2.0)), rock_origin + Vector3.UP * 0.6))
	_add_multimesh("RiverReeds", CylinderMesh.new(), reeds, _reeds_material())
	_add_multimesh("RiverBankRocks", SphereMesh.new(), rocks, _rock_material())

func _build_mountain_environment() -> void:
	var cliffs: Array[Transform3D] = []
	for section_id: StringName in [&"mountain_approach", &"mountain_ascent", &"summit_ridge", &"rough_descent"]:
		var section_range: Vector2i = _get_range(section_id)
		if section_range.x < 0:
			continue
		for segment_index: int in range(section_range.x, section_range.y + 1, 6):
			var a: Vector3 = _route[segment_index]
			var b: Vector3 = _route[segment_index + 1]
			var forward: Vector3 = _planar_forward(a, b)
			var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
			var width: float = _track.get_v2_width_for_segment(segment_index)
			for side: float in [-1.0, 1.0]:
				var height: float = 11.0 + float((segment_index * 3) % 6) * 2.4
				var radius: float = 5.0 + float(segment_index % 4) * 1.2
				var origin: Vector3 = a + right * side * (width * 0.5 + 9.0 + float(segment_index % 3) * 2.0)
				cliffs.append(Transform3D(Basis.IDENTITY.scaled(Vector3(radius, height, radius)), origin + Vector3.UP * height * 0.40))
	var cliff_mesh: CylinderMesh = CylinderMesh.new()
	cliff_mesh.top_radius = 0.28
	cliff_mesh.bottom_radius = 1.0
	cliff_mesh.height = 1.0
	cliff_mesh.radial_segments = 7
	_add_multimesh("MountainCliffForms", cliff_mesh, cliffs, _rock_material())

func _build_canyon_environment() -> void:
	var walls: Array[Transform3D] = []
	var section_range: Vector2i = _get_range(&"canyon_obstacle")
	if section_range.x < 0:
		return
	for segment_index: int in range(section_range.x, section_range.y + 1, 3):
		var a: Vector3 = _route[segment_index]
		var b: Vector3 = _route[segment_index + 1]
		var forward: Vector3 = _planar_forward(a, b)
		var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
		var width: float = _track.get_v2_width_for_segment(segment_index)
		for side: float in [-1.0, 1.0]:
			var height: float = 10.0 + float(segment_index % 4) * 2.6
			var origin: Vector3 = a + right * side * (width * 0.5 + 7.5)
			walls.append(Transform3D(Basis.IDENTITY.scaled(Vector3(5.0, height, 5.8)), origin + Vector3.UP * height * 0.45))
	_add_multimesh("CanyonWalls", BoxMesh.new(), walls, _canyon_material())

func _build_final_environment() -> void:
	var section_range: Vector2i = _get_range(&"final_sprint")
	if section_range.x < 0:
		return
	var final_index: int = clampi(section_range.y, 0, _route.size() - 2)
	var point: Vector3 = _route[final_index + 1]
	var previous: Vector3 = _route[final_index]
	var forward: Vector3 = _planar_forward(previous, point)
	var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
	var width: float = _track.get_v2_width_for_segment(final_index)
	var pieces: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		pieces.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.55, 6.4, 0.55)), point + right * side * (width * 0.5 - 1.0) + Vector3.UP * 3.2))
	pieces.append(Transform3D(Basis.IDENTITY.scaled(Vector3(width - 2.0, 0.62, 0.62)), point + Vector3.UP * 6.1))
	_add_multimesh("GrandFinishGate", BoxMesh.new(), pieces, _finish_material())

func _sample_section_pose(section_id: StringName, progress: float, lateral: float) -> Dictionary:
	var section_range: Vector2i = _get_range(section_id)
	if section_range.x < 0:
		return {}
	var segment_index: int = clampi(roundi(lerpf(float(section_range.x), float(section_range.y), clampf(progress, 0.0, 1.0))), section_range.x, section_range.y)
	var a: Vector3 = _route[segment_index]
	var b: Vector3 = _route[segment_index + 1]
	var forward: Vector3 = _planar_forward(a, b)
	var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
	return {"position": a.lerp(b, 0.5) + right * lateral, "forward": forward, "right": right, "segment_index": segment_index}

static func get_difficulty_profile(difficulty: StringName) -> Dictionary:
	match difficulty:
		&"wild": return {"hazard_speed": 0.78, "current_scale": 0.82, "extra_hazards": false, "ai_risk_scale": 0.86}
		&"nightmare": return {"hazard_speed": 1.18, "current_scale": 1.18, "extra_hazards": true, "ai_risk_scale": 1.12}
		_: return {"hazard_speed": 1.0, "current_scale": 1.0, "extra_hazards": false, "ai_risk_scale": 1.0}

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
	var direction: Vector3 = b - a
	direction.y = 0.0
	return Vector3.FORWARD if direction.length_squared() <= 0.001 else direction.normalized()

func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	if mesh is CylinderMesh:
		var cylinder: CylinderMesh = mesh as CylinderMesh
		if cylinder.height <= 0.0: cylinder.height = 1.0
		if cylinder.top_radius <= 0.0: cylinder.top_radius = 0.55
		if cylinder.bottom_radius <= 0.0: cylinder.bottom_radius = 0.75
		cylinder.radial_segments = maxi(6, cylinder.radial_segments)
	elif mesh is SphereMesh:
		var sphere: SphereMesh = mesh as SphereMesh
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 7
		sphere.rings = 4
	elif mesh is BoxMesh:
		(mesh as BoxMesh).size = Vector3.ONE
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
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root_environment.add_child(instance)

func _tight_aabb(transforms: Array[Transform3D], margin: float) -> AABB:
	var minimum: Vector3 = transforms[0].origin
	var maximum: Vector3 = transforms[0].origin
	for transform: Transform3D in transforms:
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
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = fallback
	material.roughness = 0.86
	return material

func _rock_material() -> Material:
	return _material_from_palette(&"rock", Color(0.31, 0.33, 0.34))
func _wood_material() -> Material:
	return _material_from_palette(&"wood", Color(0.34, 0.20, 0.09))
func _leaf_material() -> Material:
	return _material_from_palette(&"grass", Color(0.12, 0.34, 0.16))
func _bush_material() -> Material:
	return _material_from_palette(&"grass", Color(0.09, 0.42, 0.18))
func _reeds_material() -> Material:
	return _material_from_palette(&"grass", Color(0.30, 0.48, 0.16))
func _mud_material() -> Material:
	return _material_from_palette(&"dirt", Color(0.20, 0.11, 0.06))
func _canyon_material() -> Material:
	return _material_from_palette(&"rock", Color(0.40, 0.25, 0.16))

func _finish_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.56, 0.10, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.90, 0.22, 0.04)
	material.emission_energy_multiplier = 1.1
	material.roughness = 0.42
	return material
