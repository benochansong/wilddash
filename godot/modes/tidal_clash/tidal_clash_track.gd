class_name WildDashTidalClashTrack
extends Node3D

const CHECKPOINT_SCRIPT: Script = preload("res://tracks/checkpoint.gd")
const FINISH_SCRIPT: Script = preload("res://tracks/finish_line.gd")

# 20 broad arcade-water segments. The authored route is intentionally gentle:
# enough curvature for line choice and combat, without turning TIDAL CLASH into
# another narrow road race.
const ROUTE_POINTS: Array[Vector3] = [
	Vector3(0.0, 0.0, 75.0),
	Vector3(0.0, 0.0, 0.0),
	Vector3(18.0, 0.0, -75.0),
	Vector3(40.0, 0.0, -150.0),
	Vector3(28.0, 0.0, -225.0),
	Vector3(-8.0, 0.0, -300.0),
	Vector3(-42.0, 0.0, -375.0),
	Vector3(-28.0, 0.0, -450.0),
	Vector3(18.0, 0.0, -525.0),
	Vector3(52.0, 0.0, -600.0),
	Vector3(68.0, 0.0, -675.0),
	Vector3(45.0, 0.0, -750.0),
	Vector3(0.0, 0.0, -825.0),
	Vector3(-45.0, 0.0, -900.0),
	Vector3(-60.0, 0.0, -975.0),
	Vector3(-36.0, 0.0, -1050.0),
	Vector3(0.0, 0.0, -1125.0),
	Vector3(16.0, 0.0, -1200.0),
	Vector3(8.0, 0.0, -1275.0),
	Vector3(0.0, 0.0, -1350.0),
	Vector3(0.0, 0.0, -1425.0),
]

const CHECKPOINT_ROUTE_INDICES: Array[int] = [2, 4, 6, 8, 10, 12, 14, 16, 18]
const EXPECTED_MIN_LENGTH: float = 1500.0
const EXPECTED_MAX_LENGTH: float = 1700.0

var _track_length: float = 0.0
var _cumulative: PackedFloat32Array = PackedFloat32Array()
var _water_material: StandardMaterial3D
var _foam_material: StandardMaterial3D
var _buoy_material: StandardMaterial3D
var _rock_material: StandardMaterial3D

func _ready() -> void:
	_calculate_route_metrics()
	_build_materials()
	_build_ocean_environment()
	_build_water_corridor()
	_build_route_guidance()
	_build_start_finish()
	_build_checkpoints()
	_build_world_dressing()
	RaceManager.configure_track(get_route_points(), get_checkpoint_positions())
	var length_ok: bool = _track_length >= EXPECTED_MIN_LENGTH and _track_length <= EXPECTED_MAX_LENGTH
	print("TIDAL CLASH TRACK READY points=%d checkpoints=%d length=%.1fm water_ratio=100%% corridor=true length_ok=%s" % [
		ROUTE_POINTS.size(), CHECKPOINT_ROUTE_INDICES.size(), _track_length, str(length_ok),
	])
	if not length_ok:
		push_warning("TIDAL CLASH track length outside target: %.1fm" % _track_length)

func get_route_points() -> Array[Vector3]:
	return ROUTE_POINTS.duplicate()

func get_checkpoint_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for route_index: int in CHECKPOINT_ROUTE_INDICES:
		result.append(ROUTE_POINTS[route_index])
	return result

func get_track_length() -> float:
	return _track_length

func get_start_position() -> Vector3:
	return ROUTE_POINTS[0]

func get_finish_position() -> Vector3:
	return ROUTE_POINTS[-1]

func get_segment_width(segment_index: int) -> float:
	if segment_index < 0 or segment_index >= ROUTE_POINTS.size() - 1:
		return 28.0
	var midpoint_distance: float = (float(_cumulative[segment_index]) + float(_cumulative[segment_index + 1])) * 0.5
	var progress: float = midpoint_distance / maxf(1.0, _track_length)
	return get_width_at_progress(progress)

func get_width_at_progress(progress: float) -> float:
	var p: float = clampf(progress, 0.0, 1.0)
	if p < 0.18:
		return 30.0
	if p < 0.38:
		return 27.0
	if p < 0.58:
		return 28.0
	if p < 0.82:
		return 38.0
	return 34.0

func sample_route(progress: float) -> Vector3:
	if ROUTE_POINTS.is_empty():
		return Vector3.ZERO
	if _cumulative.size() != ROUTE_POINTS.size() or _track_length <= 0.01:
		return ROUTE_POINTS[0]
	var target: float = clampf(progress, 0.0, 1.0) * _track_length
	var segment_index: int = _segment_for_distance(target)
	var start_distance: float = float(_cumulative[segment_index])
	var end_distance: float = float(_cumulative[segment_index + 1])
	var segment_length: float = maxf(0.001, end_distance - start_distance)
	var local_t: float = clampf((target - start_distance) / segment_length, 0.0, 1.0)
	return ROUTE_POINTS[segment_index].lerp(ROUTE_POINTS[segment_index + 1], local_t)

func route_direction(progress: float) -> Vector3:
	if ROUTE_POINTS.size() < 2:
		return Vector3.FORWARD
	var target: float = clampf(progress, 0.0, 0.9999) * maxf(1.0, _track_length)
	var index: int = _segment_for_distance(target)
	var direction: Vector3 = ROUTE_POINTS[index + 1] - ROUTE_POINTS[index]
	direction.y = 0.0
	return Vector3.FORWARD if direction.length_squared() <= 0.001 else direction.normalized()

func route_right(progress: float) -> Vector3:
	var direction: Vector3 = route_direction(progress)
	return Vector3(-direction.z, 0.0, direction.x)

func lateral_offset(position: Vector3, progress: float) -> float:
	var center: Vector3 = sample_route(progress)
	var offset: Vector3 = position - center
	offset.y = 0.0
	return offset.dot(route_right(progress))

func _calculate_route_metrics() -> void:
	_cumulative = PackedFloat32Array()
	_cumulative.append(0.0)
	_track_length = 0.0
	for index: int in range(ROUTE_POINTS.size() - 1):
		_track_length += ROUTE_POINTS[index].distance_to(ROUTE_POINTS[index + 1])
		_cumulative.append(_track_length)

func _segment_for_distance(target: float) -> int:
	if ROUTE_POINTS.size() < 2:
		return 0
	for index: int in range(1, _cumulative.size()):
		if float(_cumulative[index]) >= target:
			return index - 1
	return ROUTE_POINTS.size() - 2

func _build_materials() -> void:
	_water_material = StandardMaterial3D.new()
	_water_material.albedo_color = Color(0.025, 0.38, 0.58, 0.94)
	_water_material.metallic = 0.12
	_water_material.roughness = 0.22
	_water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_foam_material = StandardMaterial3D.new()
	_foam_material.albedo_color = Color(0.82, 0.98, 1.0, 0.88)
	_foam_material.emission_enabled = true
	_foam_material.emission = Color(0.18, 0.74, 0.90)
	_foam_material.emission_energy_multiplier = 0.72
	_foam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_foam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_buoy_material = StandardMaterial3D.new()
	_buoy_material.albedo_color = Color(1.0, 0.53, 0.08)
	_buoy_material.roughness = 0.58

	_rock_material = StandardMaterial3D.new()
	_rock_material.albedo_color = Color(0.16, 0.22, 0.25)
	_rock_material.roughness = 0.92

func _build_ocean_environment() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.34, 0.55)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.50, 0.78, 0.90)
	env.ambient_light_energy = 0.78
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "TidalClashWorldEnvironment"
	world.environment = env
	add_child(world)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "OceanSun"
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.18
	sun.shadow_enabled = true
	add_child(sun)

	# Large visual ocean has no racer collision; the gameplay floor/corridor below
	# remains the only navigation authority.
	var ocean: MeshInstance3D = MeshInstance3D.new()
	ocean.name = "OpenOceanVisual"
	var ocean_mesh: BoxMesh = BoxMesh.new()
	ocean_mesh.size = Vector3(1150.0, 0.08, 1900.0)
	ocean.mesh = ocean_mesh
	ocean.position = Vector3(0.0, -0.16, -700.0)
	var deep: StandardMaterial3D = StandardMaterial3D.new()
	deep.albedo_color = Color(0.012, 0.20, 0.38)
	deep.roughness = 0.28
	deep.metallic = 0.10
	ocean.material_override = deep
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ocean)

func _build_water_corridor() -> void:
	var surface_transforms: Array[Transform3D] = []
	for index: int in range(ROUTE_POINTS.size() - 1):
		var a: Vector3 = ROUTE_POINTS[index]
		var b: Vector3 = ROUTE_POINTS[index + 1]
		var length: float = a.distance_to(b)
		var width: float = get_segment_width(index)
		var direction: Vector3 = b - a
		direction.y = 0.0
		if direction.length_squared() <= 0.001:
			continue
		direction = direction.normalized()
		var yaw: float = atan2(direction.x, direction.z)
		var midpoint: Vector3 = a.lerp(b, 0.5)

		var basis: Basis = Basis(Vector3.UP, yaw)
		basis = basis.scaled(Vector3(width, 0.055, length + 0.8))
		surface_transforms.append(Transform3D(basis, midpoint + Vector3(0.0, -0.055, 0.0)))

		_add_hidden_floor(index, midpoint, yaw, width, length)
		_add_corridor_wall(index, midpoint, direction, yaw, width, length, -1.0)
		_add_corridor_wall(index, midpoint, direction, yaw, width, length, 1.0)

	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3.ONE
	_add_multimesh("TidalWaterSurface", mesh, surface_transforms, _water_material)

func _add_hidden_floor(index: int, midpoint: Vector3, yaw: float, width: float, length: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "WaterFloor_%02d" % index
	body.position = midpoint + Vector3(0.0, -0.38, 0.0)
	body.rotation.y = yaw
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(width, 0.68, length + 0.9)
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)

func _add_corridor_wall(
	index: int,
	midpoint: Vector3,
	direction: Vector3,
	yaw: float,
	width: float,
	length: float,
	side: float
) -> void:
	var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "RaceCorridor_%02d_%s" % [index, "L" if side < 0.0 else "R"]
	body.position = midpoint + right * side * (width * 0.5 + 0.65) + Vector3.UP * 1.15
	body.rotation.y = yaw
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(0.85, 3.0, length + 1.4)
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)

func _build_route_guidance() -> void:
	var foam_transforms: Array[Transform3D] = []
	for index: int in range(ROUTE_POINTS.size() - 1):
		var a: Vector3 = ROUTE_POINTS[index]
		var b: Vector3 = ROUTE_POINTS[index + 1]
		var direction: Vector3 = b - a
		direction.y = 0.0
		var length: float = direction.length()
		if length <= 0.01:
			continue
		direction = direction.normalized()
		var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
		var width: float = get_segment_width(index)
		var yaw: float = atan2(direction.x, direction.z)
		for side: float in [-1.0, 1.0]:
			var basis: Basis = Basis(Vector3.UP, yaw)
			basis = basis.scaled(Vector3(0.18, 0.025, length))
			var position: Vector3 = a.lerp(b, 0.5) + right * side * (width * 0.5 - 1.15) + Vector3.UP * 0.035
			foam_transforms.append(Transform3D(basis, position))
	var foam_mesh: BoxMesh = BoxMesh.new()
	foam_mesh.size = Vector3.ONE
	_add_multimesh("RaceCorridorFoam", foam_mesh, foam_transforms, _foam_material)

func _build_start_finish() -> void:
	_add_gate("OceanStartGate", 0.012, Color(0.25, 0.96, 1.0))
	_add_gate("TidalFinishGate", 0.998, Color(1.0, 0.88, 0.24))

	var finish: Vector3 = get_finish_position()
	var direction: Vector3 = route_direction(0.999)
	var area: Area3D = Area3D.new()
	area.name = "FinishLine"
	area.set_script(FINISH_SCRIPT)
	area.position = finish + Vector3.UP * 1.8
	area.rotation.y = atan2(direction.x, direction.z)
	area.collision_mask = 2
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(get_width_at_progress(1.0) + 2.0, 4.5, 7.0)
	shape_node.shape = shape
	area.add_child(shape_node)
	add_child(area)

func _add_gate(node_name: String, progress: float, color: Color) -> void:
	var center: Vector3 = sample_route(progress)
	var right: Vector3 = route_right(progress)
	var width: float = get_width_at_progress(progress)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 0.72
	material.emission_energy_multiplier = 1.1
	for side: float in [-1.0, 1.0]:
		var post: MeshInstance3D = MeshInstance3D.new()
		post.name = "%s_Post" % node_name
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = 0.28
		mesh.bottom_radius = 0.36
		mesh.height = 4.8
		mesh.radial_segments = 8
		post.mesh = mesh
		post.position = center + right * side * (width * 0.5 - 1.3) + Vector3.UP * 2.35
		post.material_override = material
		add_child(post)

func _build_checkpoints() -> void:
	for checkpoint_index: int in range(CHECKPOINT_ROUTE_INDICES.size()):
		var route_index: int = CHECKPOINT_ROUTE_INDICES[checkpoint_index]
		var point: Vector3 = ROUTE_POINTS[route_index]
		var progress: float = float(_cumulative[route_index]) / maxf(1.0, _track_length)
		var direction: Vector3 = route_direction(progress)
		var area: Area3D = Area3D.new()
		area.name = "Checkpoint_%02d" % (checkpoint_index + 1)
		area.set_script(CHECKPOINT_SCRIPT)
		area.set("checkpoint_index", checkpoint_index)
		area.position = point + Vector3.UP * 1.8
		area.rotation.y = atan2(direction.x, direction.z)
		area.collision_mask = 2
		var shape_node: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(get_width_at_progress(progress) + 3.5, 4.8, 7.5)
		shape_node.shape = shape
		area.add_child(shape_node)
		add_child(area)

func _build_world_dressing() -> void:
	_build_buoys()
	_build_distant_rocks()
	_build_lighthouse()
	_build_ocean_platform()

func _build_buoys() -> void:
	var transforms: Array[Transform3D] = []
	for index: int in range(0, ROUTE_POINTS.size() - 1, 2):
		var progress: float = float(_cumulative[index]) / maxf(1.0, _track_length)
		var center: Vector3 = sample_route(progress)
		var right: Vector3 = route_right(progress)
		var width: float = get_width_at_progress(progress)
		for side: float in [-1.0, 1.0]:
			var basis: Basis = Basis.IDENTITY.scaled(Vector3(0.55, 1.15, 0.55))
			transforms.append(Transform3D(basis, center + right * side * (width * 0.5 + 3.4) + Vector3.UP * 0.55))
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.55
	mesh.bottom_radius = 0.72
	mesh.height = 1.2
	mesh.radial_segments = 8
	_add_multimesh("OceanBuoys", mesh, transforms, _buoy_material)

func _build_distant_rocks() -> void:
	var transforms: Array[Transform3D] = []
	var positions: Array[Vector3] = [
		Vector3(-120.0, 1.4, -170.0), Vector3(138.0, 1.7, -310.0),
		Vector3(-155.0, 2.0, -560.0), Vector3(165.0, 1.5, -760.0),
		Vector3(-145.0, 1.8, -1010.0), Vector3(135.0, 1.6, -1240.0),
	]
	for index: int in range(positions.size()):
		var scale: float = 5.0 + float(index % 3) * 1.5
		var basis: Basis = Basis(Vector3.UP, float(index) * 0.53).scaled(Vector3(scale, 2.6 + float(index % 2), scale * 0.82))
		transforms.append(Transform3D(basis, positions[index]))
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 1.7
	mesh.radial_segments = 8
	mesh.rings = 5
	_add_multimesh("DistantOceanRocks", mesh, transforms, _rock_material)

func _build_lighthouse() -> void:
	var root: Node3D = Node3D.new()
	root.name = "DistantLighthouse"
	root.position = Vector3(-118.0, 0.0, -1120.0)
	add_child(root)
	var tower: MeshInstance3D = MeshInstance3D.new()
	var tower_mesh: CylinderMesh = CylinderMesh.new()
	tower_mesh.top_radius = 1.8
	tower_mesh.bottom_radius = 2.5
	tower_mesh.height = 17.0
	tower_mesh.radial_segments = 10
	tower.mesh = tower_mesh
	tower.position.y = 8.5
	var white: StandardMaterial3D = StandardMaterial3D.new()
	white.albedo_color = Color(0.90, 0.94, 0.93)
	tower.material_override = white
	root.add_child(tower)
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.position = Vector3(0.0, 17.0, 0.0)
	lamp.light_color = Color(1.0, 0.86, 0.48)
	lamp.light_energy = 2.6
	lamp.omni_range = 34.0
	root.add_child(lamp)

func _build_ocean_platform() -> void:
	var platform: MeshInstance3D = MeshInstance3D.new()
	platform.name = "DistantOceanPlatform"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(20.0, 2.0, 18.0)
	platform.mesh = mesh
	platform.position = Vector3(130.0, 1.0, -920.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.31, 0.34)
	material.roughness = 0.82
	platform.material_override = material
	add_child(platform)

func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
