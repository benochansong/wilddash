class_name WildDashWildTideWorldControllerV4LongWater
extends "res://modes/neon_harbor_race/wild_tide_world_controller_v3_visual_gameplay.gd"

## Long-water gameplay/world extension for the expanded Round 3 track.
##
## The inherited V2/V3 world still owns the original flooded harbor, jungle,
## high tide, wakes and species profiles. This layer adds the seven new water
## segments at the end of the expanded track and makes them feel like a distinct
## deep-channel -> rapids -> mangrove-channel -> open-water -> final-delta race.

const LONG_WATER_SEGMENTS: Array[int] = [29, 30, 31, 32, 33, 34, 35]
const LONG_DEEP_SEGMENTS: Array[int] = [29, 30, 33, 34]
const LONG_MANGROVE_SEGMENTS: Array[int] = [31, 32]
const LONG_RAPIDS_SEGMENTS: Array[int] = [31]
const LONG_OPEN_WATER_SEGMENTS: Array[int] = [33, 34]
const LONG_FINAL_DELTA_SEGMENTS: Array[int] = [35]
const LONG_RESPAWN_ROUTE_INDICES: Array[int] = [31, 34, 36]
const LONG_CURRENT_STRENGTH: float = 0.72

var _long_dressing_built: bool = false
var _long_visual_trees: int = 0
var _long_roots: int = 0
var _long_rocks: int = 0
var _long_driftwood: int = 0

func _ready() -> void:
	super._ready()
	call_deferred("_v4_after_bootstrap")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _bootstrapped or not RaceManager.active:
		return
	_update_long_water_current(delta)

func _v4_after_bootstrap() -> void:
	for _attempt: int in range(120):
		if _bootstrapped and _route_points.size() >= 37:
			break
		await get_tree().physics_frame
	if not _bootstrapped or _route_points.size() < 37:
		push_warning("WILD TIDE LONG WATER world bootstrap skipped: expanded track unavailable")
		return
	_build_long_water_dressing()
	print("WILD TIDE LONG WATER WORLD READY long_water=%.1fm open_water=%.1fm mangrove_channel=%.1fm rapids=%.1fm water_ratio=%.1f%% visual_trees=%d roots=%d rocks=%d driftwood=%d" % [
		get_long_water_distance(),
		get_open_water_distance(),
		get_mangrove_channel_distance(),
		get_rapids_distance(),
		get_baseline_water_ratio() * 100.0,
		_long_visual_trees,
		_long_roots,
		_long_rocks,
		_long_driftwood,
	])

func _calculate_route_metrics() -> void:
	_segment_lengths.clear()
	_track_distance = 0.0
	_water_distance = 0.0
	_deep_distance = 0.0
	_shallow_distance = 0.0
	_jungle_distance = 0.0
	for segment_index: int in range(_route_points.size() - 1):
		var length: float = _route_points[segment_index].distance_to(_route_points[segment_index + 1])
		_segment_lengths.append(length)
		_track_distance += length
		var water: bool = BASE_WATER_SEGMENTS.has(segment_index) or LONG_WATER_SEGMENTS.has(segment_index)
		var deep: bool = DEEP_WATER_SEGMENTS.has(segment_index) or LONG_DEEP_SEGMENTS.has(segment_index)
		var jungle: bool = JUNGLE_SEGMENTS.has(segment_index) or LONG_MANGROVE_SEGMENTS.has(segment_index)
		if water:
			_water_distance += length
			if deep:
				_deep_distance += length
			else:
				_shallow_distance += length
		if jungle:
			_jungle_distance += length

func _build_water_world() -> void:
	super._build_water_world()
	for segment_index: int in LONG_WATER_SEGMENTS:
		_create_water_segment(segment_index, LONG_DEEP_SEGMENTS.has(segment_index), true)

func _build_whirlpools() -> void:
	super._build_whirlpools()
	_add_long_whirlpool(31)

func _build_moving_boats() -> void:
	super._build_moving_boats()
	_add_long_water_boat(34)

func _build_safe_respawn_markers() -> void:
	super._build_safe_respawn_markers()
	for route_index: int in LONG_RESPAWN_ROUTE_INDICES:
		if route_index < 0 or route_index >= _route_points.size():
			continue
		var marker: Marker3D = Marker3D.new()
		marker.name = "WildTideLongWaterRespawn_%02d" % route_index
		marker.position = _route_points[route_index] + Vector3.UP * 0.55
		marker.set_meta(&"wild_tide_water_safe", true)
		marker.add_to_group("wild_tide_safe_respawn")
		marker.add_to_group("wild_tide_long_water_respawn")
		add_child(marker)

func get_route_state() -> Dictionary:
	var state: Dictionary = super.get_route_state()
	state["long_water_distance"] = get_long_water_distance()
	state["open_water_distance"] = get_open_water_distance()
	state["mangrove_channel_distance"] = get_mangrove_channel_distance()
	state["rapids_distance"] = get_rapids_distance()
	return state

func get_long_water_distance() -> float:
	return _distance_for_segments(LONG_WATER_SEGMENTS)

func get_open_water_distance() -> float:
	return _distance_for_segments(LONG_OPEN_WATER_SEGMENTS)

func get_mangrove_channel_distance() -> float:
	return _distance_for_segments(LONG_MANGROVE_SEGMENTS)

func get_rapids_distance() -> float:
	return _distance_for_segments(LONG_RAPIDS_SEGMENTS)

func _distance_for_segments(segments: Array[int]) -> float:
	var result: float = 0.0
	for segment_index: int in segments:
		if segment_index < 0 or segment_index >= _route_points.size() - 1:
			continue
		result += _route_points[segment_index].distance_to(_route_points[segment_index + 1])
	return result

func _add_long_whirlpool(segment_index: int) -> void:
	if segment_index < 0 or segment_index >= _route_points.size() - 1:
		return
	var center: Vector3 = _route_points[segment_index].lerp(_route_points[segment_index + 1], 0.56)
	_whirlpool_centers.append(center)
	var root: Node3D = Node3D.new()
	root.name = "LongWaterWhirlpool"
	root.position = center + Vector3.UP * 0.28
	add_child(root)
	_whirlpool_visuals.append(root)
	var material: StandardMaterial3D = _emissive_material(Color(0.06, 0.76, 0.92), Color(0.20, 0.96, 1.0), 0.58)
	for marker_index: int in range(12):
		var marker: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.24
		sphere.height = 0.32
		marker.mesh = sphere
		var angle: float = float(marker_index) / 12.0 * TAU
		var radius: float = 3.8 + float(marker_index % 3) * 0.72
		marker.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		marker.material_override = material
		root.add_child(marker)

func _add_long_water_boat(segment_index: int) -> void:
	if segment_index < 0 or segment_index >= _route_points.size() - 1:
		return
	var a: Vector3 = _route_points[segment_index]
	var b: Vector3 = _route_points[segment_index + 1]
	var direction: Vector3 = b - a
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	direction = direction.normalized()
	var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	var start: Vector3 = a + right * -7.0 + Vector3.UP * 0.62
	var finish: Vector3 = b + right * 7.0 + Vector3.UP * 0.62
	var boat: Node3D = Node3D.new()
	boat.name = "WildTideLongWaterBoat"
	boat.position = start
	add_child(boat)
	var hull: MeshInstance3D = MeshInstance3D.new()
	var hull_mesh: BoxMesh = BoxMesh.new()
	hull_mesh.size = Vector3(2.3, 0.66, 5.0)
	hull.mesh = hull_mesh
	hull.material_override = _simple_material(Color(0.96, 0.60, 0.12), 0.44)
	boat.add_child(hull)
	var wake: MeshInstance3D = MeshInstance3D.new()
	var wake_mesh: BoxMesh = BoxMesh.new()
	wake_mesh.size = Vector3(2.8, 0.035, 4.8)
	wake.mesh = wake_mesh
	wake.position = Vector3(0.0, -0.48, 3.4)
	wake.material_override = _foam_material()
	boat.add_child(wake)
	_boats.append(boat)
	_boat_start.append(start)
	_boat_end.append(finish)
	_boat_speed.append(10.5)

func _update_long_water_current(delta: float) -> void:
	if _route_points.size() <= 32:
		return
	var a: Vector3 = _route_points[31]
	var b: Vector3 = _route_points[32]
	var direction: Vector3 = b - a
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	direction = direction.normalized()
	var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	var half_width: float = _segment_water_width(31) * 0.5
	for value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer.finished or not racer.has_meta(&"wild_tide_terrain"):
			continue
		if _planar_distance_to_segment(racer.global_position, a, b) > half_width:
			continue
		var phase: float = sin((_elapsed + float(racer.get_instance_id() % 17)) * 0.82)
		var push: float = LONG_CURRENT_STRENGTH * (0.72 + absf(phase) * 0.28)
		if racer.animal_id == &"crocodile":
			push *= 0.42
		racer.velocity += right * phase * push * delta

func _build_long_water_dressing() -> void:
	if _long_dressing_built or _route_points.size() < 37:
		return
	_long_dressing_built = true
	var trunk_transforms: Array[Transform3D] = []
	var crown_transforms: Array[Transform3D] = []
	var root_transforms: Array[Transform3D] = []
	var rock_transforms: Array[Transform3D] = []
	var drift_transforms: Array[Transform3D] = []

	for segment_index: int in LONG_MANGROVE_SEGMENTS:
		var a: Vector3 = _route_points[segment_index]
		var b: Vector3 = _route_points[segment_index + 1]
		var direction: Vector3 = b - a
		direction.y = 0.0
		if direction.length_squared() <= 0.001:
			continue
		direction = direction.normalized()
		var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
		var water_half: float = _segment_water_width(segment_index) * 0.5
		for sample_index: int in range(4):
			var t: float = 0.12 + float(sample_index) * 0.25
			for side: float in [-1.0, 1.0]:
				var seed: int = segment_index * 23 + sample_index * 7 + (3 if side > 0.0 else 0)
				var lateral: float = water_half + 2.8 + float(seed % 3) * 1.3
				var base_position: Vector3 = a.lerp(b, t) + right * side * lateral
				var height: float = 7.0 + float(seed % 5) * 0.65
				var trunk: Transform3D = Transform3D(Basis.IDENTITY, base_position + Vector3.UP * (height * 0.5))
				trunk.basis = trunk.basis.scaled(Vector3(0.72, height * 0.5, 0.72))
				trunk_transforms.append(trunk)
				var crown: Transform3D = Transform3D(Basis.IDENTITY, base_position + Vector3.UP * (height + 1.0))
				crown.basis = crown.basis.scaled(Vector3(3.0, 1.6, 2.8))
				crown_transforms.append(crown)
				_long_visual_trees += 1
				var root_position: Vector3 = base_position - right * side * 1.1 + Vector3.UP * 0.20
				var root: Transform3D = Transform3D(Basis(Vector3.UP, side * 0.38), root_position)
				root.basis = root.basis.scaled(Vector3(0.32, 0.25, 2.7))
				root_transforms.append(root)
				_long_roots += 1
				if sample_index % 2 == 0:
					var rock_position: Vector3 = base_position + direction * 1.1 + Vector3.UP * 0.30
					var rock: Transform3D = Transform3D(Basis.IDENTITY, rock_position)
					rock.basis = rock.basis.scaled(Vector3(0.72, 0.38, 0.86))
					rock_transforms.append(rock)
					_long_rocks += 1

	# Sparse driftwood gives the open section readable motion/scale without
	# turning it into an obstacle maze.
	for segment_index: int in LONG_OPEN_WATER_SEGMENTS:
		var a: Vector3 = _route_points[segment_index]
		var b: Vector3 = _route_points[segment_index + 1]
		var direction: Vector3 = b - a
		direction.y = 0.0
		if direction.length_squared() <= 0.001:
			continue
		direction = direction.normalized()
		var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
		for sample_index: int in range(2):
			var t: float = 0.32 + float(sample_index) * 0.36
			var side: float = -1.0 if (segment_index + sample_index) % 2 == 0 else 1.0
			var position: Vector3 = a.lerp(b, t) + right * side * 8.0 + Vector3.UP * 0.32
			var drift: Transform3D = Transform3D(Basis(Vector3.UP, float(sample_index) * 0.55), position)
			drift.basis = drift.basis.scaled(Vector3(0.26, 0.20, 2.8))
			drift_transforms.append(drift)
			_long_driftwood += 1

	var trunk_mesh: CylinderMesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.76
	trunk_mesh.bottom_radius = 1.0
	trunk_mesh.height = 2.0
	trunk_mesh.radial_segments = 7
	_v3_add_multimesh("LongWaterMangroveTrunks", trunk_mesh, trunk_transforms, _simple_material(Color(0.23, 0.12, 0.045), 0.96))
	var crown_mesh: SphereMesh = SphereMesh.new()
	crown_mesh.radius = 1.0
	crown_mesh.height = 2.0
	crown_mesh.radial_segments = 8
	crown_mesh.rings = 5
	_v3_add_multimesh("LongWaterMangroveCanopy", crown_mesh, crown_transforms, _emissive_material(Color(0.045, 0.46, 0.12), Color(0.03, 0.28, 0.07), 0.14))
	var root_mesh: BoxMesh = BoxMesh.new()
	root_mesh.size = Vector3.ONE
	_v3_add_multimesh("LongWaterMangroveRoots", root_mesh, root_transforms, _simple_material(Color(0.30, 0.16, 0.065), 0.96))
	var rock_mesh: SphereMesh = SphereMesh.new()
	rock_mesh.radius = 1.0
	rock_mesh.height = 1.5
	rock_mesh.radial_segments = 7
	rock_mesh.rings = 4
	_v3_add_multimesh("LongWaterWetRocks", rock_mesh, rock_transforms, _simple_material(Color(0.17, 0.22, 0.20), 0.42))
	var drift_mesh: BoxMesh = BoxMesh.new()
	drift_mesh.size = Vector3.ONE
	_v3_add_multimesh("LongWaterDriftwood", drift_mesh, drift_transforms, _simple_material(Color(0.30, 0.18, 0.07), 0.88))

	_build_rapids_foam_bands()

func _build_rapids_foam_bands() -> void:
	if _route_points.size() <= 32:
		return
	var a: Vector3 = _route_points[31]
	var b: Vector3 = _route_points[32]
	var direction: Vector3 = b - a
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	direction = direction.normalized()
	var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	var material: StandardMaterial3D = _foam_material()
	for band_index: int in range(7):
		var t: float = 0.12 + float(band_index) * 0.12
		var center: Vector3 = a.lerp(b, t) + Vector3.UP * 0.285
		var band: CSGBox3D = CSGBox3D.new()
		band.name = "LongWaterRapidFoam_%02d" % band_index
		band.size = Vector3(11.0 + float(band_index % 3) * 2.0, 0.025, 0.38)
		band.use_collision = false
		band.position = center + right * (float((band_index % 3) - 1) * 1.2)
		band.material = material
		add_child(band)
		band.look_at(center + direction, Vector3.UP)
