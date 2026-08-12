class_name WildDashSnowpeakWinterTrack
extends Node3D

const CHECKPOINT_SCRIPT: Script = preload("res://tracks/checkpoint.gd")
const FINISH_SCRIPT: Script = preload("res://tracks/finish_line.gd")
const DYNAMIC_OBSTACLE_SCRIPT: Script = preload("res://tracks/dynamic_obstacle.gd")

const ROUTE_POINTS: Array[Vector3] = [
	Vector3(0.0, 0.0, 76.0), Vector3(0.0, 0.0, 9.5), Vector3(42.75, 0.0, -48.07),
	Vector3(91.77, 0.0, -90.25), Vector3(128.25, 0.0, -147.25), Vector3(95.0, 0.0, -204.25),
	Vector3(38.0, 0.0, -247.0), Vector3(-19.0, 0.0, -285.0), Vector3(-76.0, 4.0, -318.25),
	Vector3(-123.5, 8.0, -370.5), Vector3(-90.25, 12.0, -427.5), Vector3(-38.0, 16.0, -475.0),
	Vector3(19.0, 18.0, -517.75), Vector3(71.25, 22.0, -560.5), Vector3(114.0, 26.0, -612.75),
	Vector3(76.0, 30.0, -669.75), Vector3(19.0, 33.0, -722.0), Vector3(-42.75, 34.0, -764.75),
	Vector3(-99.75, 32.0, -807.5), Vector3(-137.75, 28.0, -864.5), Vector3(-104.5, 18.0, -921.5),
	Vector3(-47.5, 8.0, -969.0), Vector3(14.25, 3.0, -1011.75), Vector3(71.25, 0.0, -1054.5),
	Vector3(118.75, 0.0, -1102.0), Vector3(90.25, 0.0, -1159.0), Vector3(33.25, 0.0, -1201.75),
	Vector3(-28.5, 0.0, -1235.0), Vector3(-85.5, 0.0, -1282.5), Vector3(-52.25, 0.0, -1349.0),
	Vector3(0.0, 0.0, -1410.75),
]

const SEGMENT_WIDTHS: Array[float] = [
	18.0, 18.0, 16.0, 15.0, 15.0, 16.0, 17.0, 17.0, 15.0, 14.0,
	14.0, 14.0, 13.5, 13.5, 13.0, 13.0, 13.0, 13.5, 14.0, 15.0,
	16.0, 17.0, 18.0, 16.0, 15.0, 16.0, 17.0, 18.0, 18.0, 19.0,
]
const CHECKPOINT_ROUTE_INDICES: Array[int] = [2, 5, 8, 11, 14, 17, 20, 23, 26, 29]
const ICE_SEGMENTS: Array[int] = [6, 7, 18, 19]
const PACKED_SNOW_SEGMENTS: Array[int] = [4, 5, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 23, 24, 25, 26, 27]
const DANGEROUS_RAIL_SEGMENTS: Array[int] = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 27, 28, 29]
const ICE_CAVE_SEGMENT_INDEX := 13
const BLIZZARD_START_SEGMENT := 27
const SHOULDER_WIDTH := 3.2

var _track_length := 0.0
var _decoration_root: Node3D
var _collision_root: Node3D
var _materials: Dictionary = {}

func _ready() -> void:
	_build_materials()
	_build_winter_environment()
	_build_track()
	RaceManager.configure_track(get_route_points(), get_checkpoint_positions())
	print("SNOWPEAK TRACK READY route_points=%d checkpoints=%d length=%.1fm nodes=%d surfaces=4" % [
		ROUTE_POINTS.size(), CHECKPOINT_ROUTE_INDICES.size(), _track_length, get_runtime_node_count(),
	])

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

func get_runtime_node_count() -> int:
	return _count_nodes_recursive(self)

func get_zone_names() -> PackedStringArray:
	return PackedStringArray([
		"Snow Resort Village", "Pine Forest Run", "Frozen River Crossing", "Mountain Hairpins",
		"Ice Cave Tunnel", "High Alpine Pass", "Frozen Lake Sprint", "Ski Lift District",
		"Snowfield Jump Section", "Blizzard Ridge", "Final Resort Straight",
	])

func get_surface_profile_at(world_position: Vector3) -> Dictionary:
	var best_index := 0
	var best_distance := INF
	var best_lateral := 0.0
	for index in range(ROUTE_POINTS.size() - 1):
		var a: Vector3 = ROUTE_POINTS[index]
		var b: Vector3 = ROUTE_POINTS[index + 1]
		var ab := b - a
		var length_squared := ab.length_squared()
		if length_squared <= 0.001:
			continue
		var t := clampf((world_position - a).dot(ab) / length_squared, 0.0, 1.0)
		var closest := a.lerp(b, t)
		var planar_delta := Vector3(world_position.x - closest.x, 0.0, world_position.z - closest.z)
		var distance := planar_delta.length_squared()
		if distance < best_distance:
			best_distance = distance
			best_index = index
			best_lateral = (world_position - closest).dot(_right(a, b))
	var half_width: float = SEGMENT_WIDTHS[best_index] * 0.5
	var surface := &"normal_snow"
	var slip_multiplier := 1.0
	var speed_multiplier := 1.0
	if absf(best_lateral) > half_width:
		surface = &"deep_snow"
		slip_multiplier = 1.08
		speed_multiplier = 0.76
	elif ICE_SEGMENTS.has(best_index):
		surface = &"ice"
		slip_multiplier = 1.34
	elif PACKED_SNOW_SEGMENTS.has(best_index):
		surface = &"packed_snow"
		slip_multiplier = 1.12
	return {
		"surface": surface,
		"segment": best_index,
		"lateral": best_lateral,
		"half_width": half_width,
		"slip_multiplier": slip_multiplier,
		"speed_multiplier": speed_multiplier,
	}

func is_blizzard_position(world_position: Vector3) -> bool:
	return int(get_surface_profile_at(world_position).get("segment", 0)) >= BLIZZARD_START_SEGMENT

func _build_materials() -> void:
	_materials[&"road"] = _mat(Color(0.16, 0.20, 0.26), 0.58, 0.04)
	_materials[&"packed"] = _mat(Color(0.54, 0.62, 0.70), 0.76, 0.0)
	_materials[&"snow"] = _mat(Color(0.88, 0.93, 0.98), 0.94, 0.0)
	_materials[&"snow_shadow"] = _mat(Color(0.70, 0.80, 0.90), 0.92, 0.0)
	_materials[&"ice"] = _mat(Color(0.42, 0.76, 0.92), 0.20, 0.16)
	_materials[&"ice_glow"] = _emissive(Color(0.62, 0.90, 1.0), Color(0.20, 0.66, 1.0), 0.58)
	_materials[&"wood"] = _mat(Color(0.33, 0.19, 0.10), 0.88, 0.0)
	_materials[&"metal"] = _mat(Color(0.42, 0.48, 0.54), 0.36, 0.58)
	_materials[&"rock"] = _mat(Color(0.29, 0.34, 0.39), 0.91, 0.0)
	_materials[&"pine"] = _mat(Color(0.10, 0.28, 0.20), 0.92, 0.0)
	_materials[&"red"] = _mat(Color(0.78, 0.10, 0.10), 0.66, 0.08)
	_materials[&"warm"] = _emissive(Color(1.0, 0.70, 0.30), Color(1.0, 0.45, 0.10), 0.65)
	_materials[&"finish"] = _emissive(Color(0.92, 0.98, 1.0), Color(0.30, 0.72, 1.0), 0.82)

func _build_winter_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.74, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.76, 0.84, 0.94)
	env.ambient_light_energy = 1.02
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.name = "SnowpeakWorldEnvironment"
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "WinterSun"
	sun.rotation_degrees = Vector3(-48.0, -24.0, 0.0)
	sun.light_color = Color(0.92, 0.96, 1.0)
	sun.light_energy = 1.10
	sun.shadow_enabled = true
	add_child(sun)

func _build_track() -> void:
	_decoration_root = Node3D.new()
	_decoration_root.name = "DecorationGeometry"
	_decoration_root.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_decoration_root)
	_collision_root = Node3D.new()
	_collision_root.name = "GameplayCollision"
	add_child(_collision_root)

	var roads: Array[Transform3D] = []
	var packed_overlays: Array[Transform3D] = []
	var ice_overlays: Array[Transform3D] = []
	var shoulders: Array[Transform3D] = []
	var snowbanks: Array[Transform3D] = []
	var rail_beams: Array[Transform3D] = []
	var rail_posts: Array[Transform3D] = []
	var marker_red: Array[Transform3D] = []
	var marker_white: Array[Transform3D] = []
	_track_length = 0.0
	for index in range(ROUTE_POINTS.size() - 1):
		var a: Vector3 = ROUTE_POINTS[index]
		var b: Vector3 = ROUTE_POINTS[index + 1]
		var width: float = SEGMENT_WIDTHS[index]
		var length := a.distance_to(b)
		_track_length += length
		roads.append(_track_xform(a, b, 0.5, 0.0, -0.22, Vector3(width, 0.48, length)))
		_add_collision_box("Road_%02d" % index, a, b, width, 0.48, -0.22, 0.0)
		if PACKED_SNOW_SEGMENTS.has(index):
			packed_overlays.append(_track_xform(a, b, 0.5, 0.0, 0.045, Vector3(width - 0.55, 0.06, length - 0.35)))
		if ICE_SEGMENTS.has(index):
			ice_overlays.append(_track_xform(a, b, 0.5, 0.0, 0.065, Vector3(width - 0.75, 0.08, length - 0.45)))
		for side: float in [-1.0, 1.0]:
			shoulders.append(_track_xform(a, b, 0.5, side * (width * 0.5 + SHOULDER_WIDTH * 0.5), -0.23, Vector3(SHOULDER_WIDTH, 0.46, length)))
			_add_collision_box("Shoulder_%02d_%s" % [index, "L" if side < 0.0 else "R"], a, b, SHOULDER_WIDTH, 0.46, -0.23, side * (width * 0.5 + SHOULDER_WIDTH * 0.5))
			snowbanks.append(_track_xform(a, b, 0.5, side * (width * 0.5 + SHOULDER_WIDTH + 0.55), 0.42, Vector3(1.05, 0.84, maxf(1.0, length - 0.3))))
			var post_count := maxi(3, int(ceil(length / 13.0)))
			for post_index in range(post_count + 1):
				var t := float(post_index) / float(post_count)
				var marker := _track_xform(a, b, t, side * (width * 0.5 + 0.55), 0.74, Vector3(0.12, 1.48, 0.12))
				if (post_index + index) % 2 == 0:
					marker_red.append(marker)
				else:
					marker_white.append(marker)
			if DANGEROUS_RAIL_SEGMENTS.has(index):
				rail_beams.append(_track_xform(a, b, 0.5, side * (width * 0.5 + SHOULDER_WIDTH + 0.30), 0.92, Vector3(0.24, 0.30, length)))
				for t: float in [0.08, 0.28, 0.48, 0.68, 0.88]:
					rail_posts.append(_track_xform(a, b, t, side * (width * 0.5 + SHOULDER_WIDTH + 0.30), 0.65, Vector3(0.22, 1.30, 0.22)))
				_add_collision_box("WinterRail_%02d_%s" % [index, "L" if side < 0.0 else "R"], a, b, 0.48, 1.65, 0.82, side * (width * 0.5 + SHOULDER_WIDTH + 0.30))

	_add_box_batch("SnowpeakRoadSurface", roads, _materials[&"road"])
	_add_box_batch("PackedSnowSurface", packed_overlays, _materials[&"packed"])
	_add_box_batch("IceSurfacePatches", ice_overlays, _materials[&"ice"])
	_add_box_batch("SnowShoulders", shoulders, _materials[&"snow_shadow"])
	_add_box_batch("SnowBanks", snowbanks, _materials[&"snow"])
	_add_box_batch("WinterGuardrails", rail_beams, _materials[&"metal"])
	_add_box_batch("WinterGuardrailPosts", rail_posts, _materials[&"metal"])
	_add_box_batch("SnowRouteMarkersRed", marker_red, _materials[&"red"])
	_add_box_batch("SnowRouteMarkersWhite", marker_white, _materials[&"snow"])

	_build_start_finish()
	_build_checkpoints()
	_build_resort_village()
	_build_pine_forest()
	_build_frozen_river()
	_build_hairpin_chevrons()
	_build_ice_cave()
	_build_mountains()
	_build_frozen_lake()
	_build_ski_lift()
	_build_snowfield_jump()
	_build_blizzard_ridge()
	_build_winter_obstacles()

func _build_start_finish() -> void:
	var start_parts: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		start_parts.append(_track_xform(ROUTE_POINTS[0], ROUTE_POINTS[1], 0.10, side * 9.5, 2.6, Vector3(0.45, 5.2, 0.45)))
	start_parts.append(_track_xform(ROUTE_POINTS[0], ROUTE_POINTS[1], 0.10, 0.0, 5.0, Vector3(20.0, 0.50, 0.50)))
	_add_box_batch("SnowStartGantry", start_parts, _materials[&"wood"])
	var finish_parts: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		finish_parts.append(_track_xform(ROUTE_POINTS[-2], ROUTE_POINTS[-1], 1.0, side * 10.1, 2.8, Vector3(0.48, 5.6, 0.48)))
	finish_parts.append(_track_xform(ROUTE_POINTS[-2], ROUTE_POINTS[-1], 1.0, 0.0, 5.25, Vector3(21.0, 0.55, 0.55)))
	_add_box_batch("SnowFinishGantry", finish_parts, _materials[&"finish"])
	var finish := ROUTE_POINTS[-1]
	var previous := ROUTE_POINTS[-2]
	var stripe := CSGBox3D.new()
	stripe.name = "FinishStripe"
	stripe.size = Vector3(19.0, 0.06, 0.70)
	stripe.use_collision = false
	stripe.material = _materials[&"finish"]
	stripe.position = finish + Vector3.UP * 0.11
	_decoration_root.add_child(stripe)
	stripe.look_at(finish + (finish - previous).normalized() + Vector3.UP * 0.11, Vector3.UP)
	var area := Area3D.new()
	area.name = "FinishLine"
	area.set_script(FINISH_SCRIPT)
	area.position = finish + Vector3.UP * 1.8
	area.collision_mask = 2
	add_child(area)
	area.look_at(finish + (finish - previous).normalized() + Vector3.UP * 1.8, Vector3.UP)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 4.5, 6.0)
	shape.shape = box
	area.add_child(shape)

func _build_checkpoints() -> void:
	for checkpoint_index in range(CHECKPOINT_ROUTE_INDICES.size()):
		var route_index := CHECKPOINT_ROUTE_INDICES[checkpoint_index]
		var point := ROUTE_POINTS[route_index]
		var next := ROUTE_POINTS[min(route_index + 1, ROUTE_POINTS.size() - 1)]
		var area := Area3D.new()
		area.name = "Checkpoint_%02d" % (checkpoint_index + 1)
		area.set_script(CHECKPOINT_SCRIPT)
		area.set("checkpoint_index", checkpoint_index)
		area.position = point + Vector3.UP * 1.8
		area.collision_mask = 2
		add_child(area)
		area.look_at(next + Vector3.UP * 1.8, Vector3.UP)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(SEGMENT_WIDTHS[min(route_index, SEGMENT_WIDTHS.size() - 1)] + 4.0, 5.0, 7.0)
		shape.shape = box
		area.add_child(shape)

func _build_resort_village() -> void:
	var lodge_bodies: Array[Transform3D] = []
	var roofs: Array[Transform3D] = []
	var windows: Array[Transform3D] = []
	var chimneys: Array[Transform3D] = []
	for anchor in [Vector3(-23, 3.0, 35), Vector3(24, 3.5, 13), Vector3(-26, 4.0, -8), Vector3(28, 3.0, -28), Vector3(-30, 3.5, -1390)]:
		var body := Transform3D(Basis.IDENTITY, anchor)
		body.basis = body.basis.scaled(Vector3(11.0, 6.0, 8.0))
		lodge_bodies.append(body)
		var roof := Transform3D(Basis.IDENTITY, anchor + Vector3.UP * 3.45)
		roof.basis = roof.basis.rotated(Vector3.FORWARD, 0.10).scaled(Vector3(12.5, 0.75, 9.0))
		roofs.append(roof)
		for window_index in range(3):
			var win := Transform3D(Basis.IDENTITY, anchor + Vector3(-3.0 + float(window_index) * 3.0, 0.7, -4.05))
			win.basis = win.basis.scaled(Vector3(1.1, 1.2, 0.10))
			windows.append(win)
		var chimney := Transform3D(Basis.IDENTITY, anchor + Vector3(3.2, 4.6, 1.2))
		chimney.basis = chimney.basis.scaled(Vector3(0.75, 3.0, 0.75))
		chimneys.append(chimney)
	_add_box_batch("ResortLodges", lodge_bodies, _materials[&"wood"])
	_add_box_batch("ResortSnowRoofs", roofs, _materials[&"snow"])
	_add_box_batch("ResortWarmWindows", windows, _materials[&"warm"])
	_add_box_batch("ResortChimneys", chimneys, _materials[&"rock"])

func _build_pine_forest() -> void:
	var trunks: Array[Transform3D] = []
	var foliage: Array[Transform3D] = []
	for route_index in range(2, 8):
		var center := ROUTE_POINTS[route_index]
		var right := _segment_right(min(route_index, ROUTE_POINTS.size() - 2))
		for side: float in [-1.0, 1.0]:
			for tree_index in range(4):
				var origin := center + right * side * (14.0 + float(tree_index) * 4.8) + Vector3(0.0, 0.0, float(tree_index - 1) * 6.0)
				var trunk := Transform3D(Basis.IDENTITY, origin + Vector3.UP * 1.3)
				trunk.basis = trunk.basis.scaled(Vector3(0.30, 2.6, 0.30))
				trunks.append(trunk)
				var crown := Transform3D(Basis.IDENTITY, origin + Vector3.UP * 4.0)
				crown.basis = crown.basis.scaled(Vector3(1.45, 2.3, 1.45))
				foliage.append(crown)
	_add_box_batch("PineTrunks", trunks, _materials[&"wood"])
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 1.0
	cone.height = 2.0
	_add_mesh_batch("SnowPineFoliage", cone, foliage, _materials[&"pine"])

func _build_frozen_river() -> void:
	var ice := CSGBox3D.new()
	ice.name = "FrozenRiverScenery"
	ice.size = Vector3(145.0, 0.28, 170.0)
	ice.position = Vector3(5.0, -0.72, -277.0)
	ice.use_collision = false
	ice.material = _materials[&"ice"]
	_decoration_root.add_child(ice)
	var cracks: Array[Transform3D] = []
	for index in range(9):
		var crack := Transform3D(Basis.IDENTITY, Vector3(-45.0 + float(index) * 12.0, -0.54, -240.0 - float(index % 3) * 18.0))
		crack.basis = crack.basis.rotated(Vector3.UP, float(index) * 0.31).scaled(Vector3(8.0, 0.04, 0.10))
		cracks.append(crack)
	_add_box_batch("FrozenRiverCracks", cracks, _materials[&"ice_glow"])

func _build_hairpin_chevrons() -> void:
	var chevrons: Array[Transform3D] = []
	for segment_index in [8, 9, 10, 11, 12]:
		var a := ROUTE_POINTS[segment_index]
		var b := ROUTE_POINTS[segment_index + 1]
		var width := SEGMENT_WIDTHS[segment_index]
		for t: float in [0.28, 0.55, 0.82]:
			chevrons.append(_track_xform(a, b, t, width * 0.5 + 4.2, 1.05, Vector3(0.20, 1.5, 1.8)))
	_add_box_batch("HairpinChevrons", chevrons, _materials[&"red"])

func _build_ice_cave() -> void:
	var a := ROUTE_POINTS[ICE_CAVE_SEGMENT_INDEX]
	var b := ROUTE_POINTS[ICE_CAVE_SEGMENT_INDEX + 1]
	var width := SEGMENT_WIDTHS[ICE_CAVE_SEGMENT_INDEX]
	var length := a.distance_to(b)
	var panels: Array[Transform3D] = []
	var lights: Array[Transform3D] = []
	var icicles: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		panels.append(_track_xform(a, b, 0.5, side * (width * 0.5 + 0.75), 2.7, Vector3(1.2, 5.6, length)))
	panels.append(_track_xform(a, b, 0.5, 0.0, 5.1, Vector3(width + 2.6, 1.0, length)))
	for index in range(8):
		lights.append(_track_xform(a, b, 0.08 + float(index) * 0.12, 0.0, 4.35, Vector3(2.4, 0.12, 0.42)))
		icicles.append(_track_xform(a, b, 0.11 + float(index) * 0.11, -width * 0.28 if index % 2 == 0 else width * 0.28, 4.15, Vector3(0.18, 1.6 + float(index % 3) * 0.35, 0.18)))
	_add_box_batch("IceCaveWalls", panels, _materials[&"ice"])
	_add_box_batch("IceCaveEmbeddedLights", lights, _materials[&"ice_glow"])
	_add_box_batch("IceCaveIcicles", icicles, _materials[&"ice_glow"])
	_add_collision_box("IceCaveWallL", a, b, 1.25, 5.8, 2.7, -(width * 0.5 + 0.75))
	_add_collision_box("IceCaveWallR", a, b, 1.25, 5.8, 2.7, width * 0.5 + 0.75)
	_add_collision_box("IceCaveRoof", a, b, width + 2.6, 1.0, 5.1, 0.0)

func _build_mountains() -> void:
	var peaks: Array[Transform3D] = []
	for anchor in [Vector3(-210, 44, -540), Vector3(220, 58, -730), Vector3(-230, 64, -940), Vector3(210, 48, -1150)]:
		var peak := Transform3D(Basis.IDENTITY, anchor)
		peak.basis = peak.basis.scaled(Vector3(40.0, 55.0, 40.0))
		peaks.append(peak)
	var mountain := CylinderMesh.new()
	mountain.top_radius = 0.0
	mountain.bottom_radius = 1.0
	mountain.height = 2.0
	_add_mesh_batch("DistantSnowMountains", mountain, peaks, _materials[&"snow_shadow"])

func _build_frozen_lake() -> void:
	var lake := CSGBox3D.new()
	lake.name = "FrozenLakeScenery"
	lake.size = Vector3(220.0, 0.32, 250.0)
	lake.position = Vector3(-35.0, 0.2, -840.0)
	lake.use_collision = false
	lake.material = _materials[&"ice"]
	_decoration_root.add_child(lake)
	var flags: Array[Transform3D] = []
	for segment_index in [17, 18, 19, 20]:
		var a := ROUTE_POINTS[segment_index]
		var b := ROUTE_POINTS[segment_index + 1]
		var width := SEGMENT_WIDTHS[segment_index]
		for t: float in [0.18, 0.42, 0.66, 0.90]:
			for side: float in [-1.0, 1.0]:
				flags.append(_track_xform(a, b, t, side * (width * 0.5 + 1.2), 1.5, Vector3(0.15, 3.0, 0.15)))
	_add_box_batch("FrozenLakeRouteFlags", flags, _materials[&"red"])

func _build_ski_lift() -> void:
	var towers: Array[Transform3D] = []
	var gondolas: Array[Transform3D] = []
	for route_index in [20, 21, 22]:
		var center := ROUTE_POINTS[route_index]
		var tower := Transform3D(Basis.IDENTITY, center + Vector3(22.0, 6.0, 0.0))
		tower.basis = tower.basis.scaled(Vector3(0.8, 12.0, 0.8))
		towers.append(tower)
		var cross := Transform3D(Basis.IDENTITY, center + Vector3(22.0, 11.4, 0.0))
		cross.basis = cross.basis.scaled(Vector3(8.0, 0.35, 0.35))
		towers.append(cross)
		var gondola := Transform3D(Basis.IDENTITY, center + Vector3(18.0, 9.6, float(route_index - 21) * 6.0))
		gondola.basis = gondola.basis.scaled(Vector3(2.2, 1.5, 1.7))
		gondolas.append(gondola)
	_add_box_batch("SkiLiftTowers", towers, _materials[&"metal"])
	_add_box_batch("SkiLiftGondolas", gondolas, _materials[&"red"])

func _build_snowfield_jump() -> void:
	var a := ROUTE_POINTS[23]
	var b := ROUTE_POINTS[24]
	var ramp := CSGBox3D.new()
	ramp.name = "SnowfieldRamp"
	ramp.size = Vector3(8.5, 0.65, 9.0)
	ramp.use_collision = true
	ramp.material = _materials[&"packed"]
	ramp.position = a.lerp(b, 0.55) + Vector3.UP * 0.32
	_collision_root.add_child(ramp)
	ramp.look_at(b + Vector3.UP * 0.32, Vector3.UP)
	ramp.rotate_object_local(Vector3.RIGHT, -0.075)
	var gates: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		gates.append(_track_xform(a, b, 0.30, side * 4.8, 1.7, Vector3(0.14, 3.4, 0.14)))
		gates.append(_track_xform(a, b, 0.80, side * 4.8, 1.7, Vector3(0.14, 3.4, 0.14)))
	_add_box_batch("SnowJumpGuidePoles", gates, _materials[&"red"])

func _build_blizzard_ridge() -> void:
	var wind_markers: Array[Transform3D] = []
	for segment_index in [27, 28, 29]:
		var a := ROUTE_POINTS[segment_index]
		var b := ROUTE_POINTS[segment_index + 1]
		var width := SEGMENT_WIDTHS[segment_index]
		for t: float in [0.20, 0.50, 0.80]:
			for side: float in [-1.0, 1.0]:
				wind_markers.append(_track_xform(a, b, t, side * (width * 0.5 + 1.0), 1.1, Vector3(0.18, 2.2, 0.18)))
	_add_box_batch("BlizzardRouteMarkers", wind_markers, _materials[&"red"])

func _build_winter_obstacles() -> void:
	_create_dynamic_box("SnowplowCrossing", ROUTE_POINTS[7].lerp(ROUTE_POINTS[8], 0.55), 6.2, 1.05, 4.0, WildDashDynamicObstacle.MotionType.SWEEP)
	_create_dynamic_sphere("RollingSnowball", ROUTE_POINTS[18].lerp(ROUTE_POINTS[19], 0.52), 1.35, 0.72, 3.0)
	_create_dynamic_box("SkiGateObstacle", ROUTE_POINTS[25].lerp(ROUTE_POINTS[26], 0.55), 5.2, 1.35, 0.0, WildDashDynamicObstacle.MotionType.ROTATE)

func _create_dynamic_box(node_name: String, world_position: Vector3, width: float, speed: float, amplitude: float, motion_type: WildDashDynamicObstacle.MotionType) -> void:
	var body := AnimatableBody3D.new()
	body.name = node_name
	body.set_script(DYNAMIC_OBSTACLE_SCRIPT)
	body.set("motion_type", motion_type)
	body.set("motion_speed", speed)
	body.set("amplitude", amplitude)
	body.position = world_position + Vector3.UP * 1.15
	_collision_root.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 2.3, 0.85)
	shape.shape = box
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 2.3, 0.85)
	visual.mesh = mesh
	visual.material_override = _materials[&"red"]
	body.add_child(visual)

func _create_dynamic_sphere(node_name: String, world_position: Vector3, radius: float, speed: float, amplitude: float) -> void:
	var body := AnimatableBody3D.new()
	body.name = node_name
	body.set_script(DYNAMIC_OBSTACLE_SCRIPT)
	body.set("motion_type", WildDashDynamicObstacle.MotionType.SWEEP)
	body.set("motion_speed", speed)
	body.set("amplitude", amplitude)
	body.position = world_position + Vector3.UP * radius
	_collision_root.add_child(body)
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius
	shape.shape = sphere_shape
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	visual.mesh = sphere
	visual.material_override = _materials[&"snow"]
	body.add_child(visual)

func _add_collision_box(node_name: String, a: Vector3, b: Vector3, width: float, height: float, vertical: float, lateral: float) -> void:
	var right := _right(a, b)
	var collision := CSGBox3D.new()
	collision.name = node_name
	collision.size = Vector3(width, height, a.distance_to(b))
	collision.use_collision = true
	collision.visible = false
	collision.position = (a + b) * 0.5 + right * lateral + Vector3.UP * vertical
	_collision_root.add_child(collision)
	collision.look_at(b + right * lateral + Vector3.UP * vertical, Vector3.UP)

func _segment_right(index: int) -> Vector3:
	return _right(ROUTE_POINTS[index], ROUTE_POINTS[index + 1])

func _right(a: Vector3, b: Vector3) -> Vector3:
	var direction := b - a
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return Vector3.RIGHT
	direction = direction.normalized()
	return Vector3(-direction.z, 0.0, direction.x)

func _track_xform(a: Vector3, b: Vector3, t: float, lateral: float, vertical: float, size: Vector3) -> Transform3D:
	var direction := b - a
	var origin := a.lerp(b, t) + _right(a, b) * lateral + Vector3.UP * vertical
	var xform := Transform3D(Basis.IDENTITY, origin)
	xform = xform.looking_at(origin + direction.normalized(), Vector3.UP)
	xform.basis = xform.basis.scaled(size)
	return xform

func _add_box_batch(node_name: String, transforms: Array[Transform3D], material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	_add_mesh_batch(node_name, mesh, transforms, material)

func _add_mesh_batch(node_name: String, mesh: Mesh, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for index in range(transforms.size()):
		mm.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = mm
	instance.material_override = material
	_decoration_root.add_child(instance)

func _mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _emissive(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := _mat(color, 0.44, 0.08)
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material

func _count_nodes_recursive(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes_recursive(child)
	return count
