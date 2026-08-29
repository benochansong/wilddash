class_name WildDashWildTideDaylightTrack
extends WildDashNeonHarborGroundCircuit

## Round 3 visual foundation for WILD TIDE — JUNGLE HARBOR.
##
## The previous grounded Neon Harbor generator always built a dark night
## environment and rendered a black road surface over every route segment. The
## Wild Tide runtime then placed water slightly above that road, so the gameplay
## metadata said "water" while the player still read a dark paved circuit.
## This generator makes the daytime/tropical visual state authoritative and
## deliberately omits visible road meshes on authored water segments while
## preserving hidden road collision underneath as a safe support floor.

const WILD_TIDE_WATER_SEGMENTS: Array[int] = [
	5, 6, 7, 8, 9, 10, 11, 12,
	17, 18, 19, 20, 21, 22,
]
const WILD_TIDE_DEEP_SEGMENTS: Array[int] = [6, 7, 8, 17, 18, 19, 20]
const WILD_TIDE_JUNGLE_SEGMENTS: Array[int] = [10, 11, 12, 13, 14, 15, 16, 17]

var _wild_tide_water_distance: float = 0.0
var _wild_tide_deep_distance: float = 0.0
var _wild_tide_shallow_distance: float = 0.0

func _ready() -> void:
	_v2_build_materials()
	_v2_build_night_environment()
	_v2_build_world_floor()
	_v2_build_road()
	_v2_build_start_finish()
	_v2_build_checkpoints()
	RaceManager.configure_track(get_route_points(), get_checkpoint_positions())
	var total: float = maxf(0.01, _v2_track_length)
	print("WILD TIDE DAYLIGHT TRACK READY route_points=%d checkpoints=%d length=%.1fm daytime=true visible_water=%.1f%% shallow=%.1f%% deep=%.1f%% hidden_support=true" % [
		V2_ROUTE_POINTS.size(),
		V2_CHECKPOINT_ROUTE_INDICES.size(),
		_v2_track_length,
		_wild_tide_water_distance / total * 100.0,
		_wild_tide_shallow_distance / total * 100.0,
		_wild_tide_deep_distance / total * 100.0,
	])

func get_zone_names() -> PackedStringArray:
	return PackedStringArray([
		"Harbor Start",
		"Flooded Harbor Split",
		"Mangrove Jungle",
		"Flooded Midfield",
		"Final Delta Sprint",
	])

func get_segment_width(segment_index: int) -> float:
	if segment_index < 0 or segment_index >= V2_SEGMENT_WIDTHS.size():
		return 16.0
	return V2_SEGMENT_WIDTHS[segment_index]

func is_wild_tide_water_segment(segment_index: int) -> bool:
	return WILD_TIDE_WATER_SEGMENTS.has(segment_index)

func is_wild_tide_deep_segment(segment_index: int) -> bool:
	return WILD_TIDE_DEEP_SEGMENTS.has(segment_index)

func get_visible_water_ratio() -> float:
	if _v2_track_length <= 0.01:
		return 0.0
	return _wild_tide_water_distance / _v2_track_length

func get_shallow_water_ratio() -> float:
	if _v2_track_length <= 0.01:
		return 0.0
	return _wild_tide_shallow_distance / _v2_track_length

func get_deep_water_ratio() -> float:
	if _v2_track_length <= 0.01:
		return 0.0
	return _wild_tide_deep_distance / _v2_track_length

func _v2_build_materials() -> void:
	_v2_materials.clear()
	_v2_materials[&"road"] = _v2_material(Color(0.31, 0.32, 0.30), 0.82, 0.02)
	_v2_materials[&"city_ground"] = _v2_material(Color(0.24, 0.36, 0.19), 0.94, 0.0)
	_v2_materials[&"edge_cyan"] = _v2_emissive(Color(0.08, 0.73, 0.86), Color(0.03, 0.38, 0.50), 0.22)
	_v2_materials[&"edge_magenta"] = _v2_emissive(Color(0.98, 0.66, 0.12), Color(0.75, 0.30, 0.02), 0.26)
	_v2_materials[&"metal"] = _v2_material(Color(0.46, 0.48, 0.46), 0.58, 0.34)
	_v2_materials[&"finish"] = _v2_emissive(Color(1.0, 0.88, 0.20), Color(1.0, 0.48, 0.04), 0.72)

func _v2_build_night_environment() -> void:
	# Compatibility override: the base calls this method by its old name, but
	# Round 3 is now explicitly a bright tropical daytime race.
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.48, 0.76, 0.94)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.74, 0.86, 0.92)
	environment.ambient_light_energy = 1.18
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "WildTideDayWorldEnvironment"
	world.environment = environment
	add_child(world)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "WildTideSun"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.92, 0.78)
	sun.light_energy = 1.34
	sun.shadow_enabled = true
	add_child(sun)

func _v2_build_world_floor() -> void:
	_v2_visual_root = Node3D.new()
	_v2_visual_root.name = "WildTideDayVisuals"
	add_child(_v2_visual_root)
	_v2_collision_root = Node3D.new()
	_v2_collision_root.name = "WildTideDayCollision"
	add_child(_v2_collision_root)

	# Collision stays continuous so water routes remain safe even though their
	# visible pavement is removed. The support floor itself is hidden.
	var floor_collision: CSGBox3D = CSGBox3D.new()
	floor_collision.name = "WildTideContinuousSupportFloor"
	floor_collision.size = V2_CITY_FLOOR_SIZE
	floor_collision.position = V2_CITY_FLOOR_CENTER
	floor_collision.use_collision = true
	floor_collision.collision_layer = 1
	floor_collision.collision_mask = 0
	floor_collision.visible = false
	_v2_collision_root.add_child(floor_collision)

	var ground_visual: CSGBox3D = CSGBox3D.new()
	ground_visual.name = "WildTideTropicalGround"
	ground_visual.size = V2_CITY_FLOOR_SIZE
	ground_visual.position = V2_CITY_FLOOR_CENTER + Vector3.DOWN * 0.04
	ground_visual.use_collision = false
	ground_visual.material = _v2_materials[&"city_ground"]
	_v2_visual_root.add_child(ground_visual)

func _v2_build_road() -> void:
	var road_transforms: Array[Transform3D] = []
	var cyan_edges: Array[Transform3D] = []
	var orange_edges: Array[Transform3D] = []
	_v2_track_length = 0.0
	_wild_tide_water_distance = 0.0
	_wild_tide_deep_distance = 0.0
	_wild_tide_shallow_distance = 0.0

	for segment_index: int in range(V2_ROUTE_POINTS.size() - 1):
		var a: Vector3 = V2_ROUTE_POINTS[segment_index]
		var b: Vector3 = V2_ROUTE_POINTS[segment_index + 1]
		var width: float = V2_SEGMENT_WIDTHS[segment_index]
		var length: float = a.distance_to(b)
		_v2_track_length += length

		# The hidden support collision exists on land and water. Only the visible
		# pavement is omitted on water segments so the water surface can actually
		# be seen from the chase camera.
		_v2_add_road_collision("WildTideSupport_%02d" % segment_index, a, b, width, length)
		if WILD_TIDE_WATER_SEGMENTS.has(segment_index):
			_wild_tide_water_distance += length
			if WILD_TIDE_DEEP_SEGMENTS.has(segment_index):
				_wild_tide_deep_distance += length
			else:
				_wild_tide_shallow_distance += length
			continue

		road_transforms.append(_v2_track_xform(
			a, b, 0.5, 0.0, 0.02,
			Vector3(width, 0.16, length + 0.35)
		))
		for side: float in [-1.0, 1.0]:
			var edge_transform: Transform3D = _v2_track_xform(
				a,
				b,
				0.5,
				side * (width * 0.5 - 0.28),
				0.115,
				Vector3(0.18, 0.05, maxf(0.5, length - 0.30))
			)
			if side < 0.0:
				cyan_edges.append(edge_transform)
			else:
				orange_edges.append(edge_transform)

	_v2_add_batch("WildTideLandRoadSurface", road_transforms, _v2_materials[&"road"])
	_v2_add_batch("WildTideLandEdgeCyan", cyan_edges, _v2_materials[&"edge_cyan"])
	_v2_add_batch("WildTideLandEdgeOrange", orange_edges, _v2_materials[&"edge_magenta"])
