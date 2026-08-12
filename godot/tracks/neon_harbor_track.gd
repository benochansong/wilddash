class_name WildDashNeonHarborTrack
extends Node3D

const CHECKPOINT_SCRIPT: Script = preload("res://tracks/checkpoint.gd")
const FINISH_SCRIPT: Script = preload("res://tracks/finish_line.gd")
const DYNAMIC_OBSTACLE_SCRIPT: Script = preload("res://tracks/dynamic_obstacle.gd")

const ROUTE_POINTS: Array[Vector3] = [
	Vector3(0.0, 0.0, 73.6),
	Vector3(0.0, 0.0, 9.2),
	Vector3(46.0, 0.0, -50.6),
	Vector3(96.6, 0.0, -87.4),
	Vector3(133.4, 0.0, -142.6),
	Vector3(101.2, 0.0, -202.4),
	Vector3(50.6, 0.0, -248.4),
	Vector3(-4.6, 0.0, -289.8),
	Vector3(-64.4, 0.0, -322.0),
	Vector3(-110.4, 0.0, -386.4),
	Vector3(-78.2, 0.0, -450.8),
	Vector3(-23.0, 0.0, -501.4),
	Vector3(41.4, 0.0, -529.0),
	Vector3(96.6, 0.0, -579.6),
	Vector3(133.4, 0.0, -644.0),
	Vector3(105.8, 2.8, -703.8),
	Vector3(50.6, 6.4, -759.0),
	Vector3(-9.2, 8.3, -805.0),
	Vector3(-69.0, 6.4, -855.6),
	Vector3(-119.6, 2.8, -915.4),
	Vector3(-96.6, 0.0, -975.2),
	Vector3(-41.4, 0.0, -1025.8),
	Vector3(18.4, 0.0, -1062.6),
	Vector3(73.6, 0.0, -1113.2),
	Vector3(41.4, 0.0, -1177.6),
	Vector3(9.2, 0.0, -1246.6),
]

const SEGMENT_WIDTHS: Array[float] = [
	18.0, 18.0, 16.0, 15.0, 14.0,
	15.0, 14.0, 13.5, 13.0, 14.0,
	16.0, 17.0, 16.0, 15.0, 14.0,
	14.0, 13.5, 13.0, 13.0, 14.0,
	15.0, 14.0, 13.0, 12.5, 18.0,
]

const SEGMENT_NAMES: Array[String] = [
	"Start Harbor Boulevard", "Harbor Boulevard", "Container Yard Entry", "Container Yard",
	"Warehouse S Curve In", "Warehouse S Curve Out", "Crane District", "Crane District Exit",
	"Dockside Entry", "Dockside Straight", "Dockside Bend", "Industrial Approach",
	"Industrial Tunnel Entry", "Industrial Tunnel", "Tunnel Exit", "Elevated Highway Rise",
	"Elevated Highway", "Elevated Highway Bend", "Elevated Highway Descent", "Neon Downtown Entry",
	"Neon Downtown", "Neon Downtown Exit", "Shipyard Chicane In", "Shipyard Chicane Out", "Final Harbor Straight",
]

const CHECKPOINT_ROUTE_INDICES: Array[int] = [2, 5, 8, 11, 14, 17, 20, 23, 24]
const SHORTCUT_A_SKIP_ROUTE_INDEX := 4
const SHORTCUT_B_SKIP_ROUTE_INDEX := 23
const TUNNEL_SEGMENT_INDEX := 13
const ELEVATED_SEGMENTS: Array[int] = [15, 16, 17, 18]
const DANGEROUS_RAIL_SEGMENTS: Array[int] = [8, 9, 10, 12, 13, 14, 15, 16, 17, 18, 22, 23, 24]

var _track_length := 0.0
var _decoration_root: Node3D
var _collision_root: Node3D
var _materials: Dictionary = {}

func _ready() -> void:
	_build_materials()
	_build_night_environment()
	_build_track()
	RaceManager.configure_track(get_route_points(), get_checkpoint_positions())
	print("NEON HARBOR TRACK READY route_points=%d checkpoints=%d length=%.1fm nodes=%d shortcuts=2" % [
		ROUTE_POINTS.size(), CHECKPOINT_ROUTE_INDICES.size(), _track_length, get_runtime_node_count(),
	])

func get_route_points() -> Array[Vector3]:
	return ROUTE_POINTS.duplicate()

func get_checkpoint_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for route_index in CHECKPOINT_ROUTE_INDICES:
		result.append(ROUTE_POINTS[route_index])
	return result

func get_track_length() -> float:
	return _track_length

func get_start_position() -> Vector3:
	return ROUTE_POINTS[0]

func get_finish_position() -> Vector3:
	return ROUTE_POINTS[ROUTE_POINTS.size() - 1]

func get_shortcut_a_saving() -> float:
	return _shortcut_saving(SHORTCUT_A_SKIP_ROUTE_INDEX)

func get_shortcut_b_saving() -> float:
	return _shortcut_saving(SHORTCUT_B_SKIP_ROUTE_INDEX)

func get_runtime_node_count() -> int:
	return _count_nodes_recursive(self)

func get_zone_names() -> PackedStringArray:
	return PackedStringArray([
		"Harbor Boulevard", "Container Yard", "Warehouse S-Curve", "Crane District",
		"Dockside Straight", "Industrial Tunnel", "Elevated Highway", "Neon Downtown",
		"Shipyard Chicane", "Final Harbor Straight",
	])

func _build_materials() -> void:
	_materials[&"road"] = _make_material(Color(0.055, 0.075, 0.11), 0.42, 0.08)
	_materials[&"road_edge"] = _make_emissive_material(Color(0.78, 0.92, 1.0), Color(0.18, 0.55, 0.85), 0.35)
	_materials[&"metal"] = _make_material(Color(0.24, 0.31, 0.38), 0.34, 0.72)
	_materials[&"concrete"] = _make_material(Color(0.25, 0.28, 0.34), 0.80, 0.0)
	_materials[&"warehouse"] = _make_material(Color(0.16, 0.20, 0.29), 0.72, 0.15)
	_materials[&"container_red"] = _make_material(Color(0.58, 0.11, 0.13), 0.68, 0.22)
	_materials[&"container_blue"] = _make_material(Color(0.08, 0.30, 0.50), 0.62, 0.28)
	_materials[&"container_teal"] = _make_material(Color(0.04, 0.42, 0.42), 0.60, 0.26)
	_materials[&"warning"] = _make_emissive_material(Color(1.0, 0.56, 0.10), Color(1.0, 0.26, 0.02), 0.75)
	_materials[&"neon_cyan"] = _make_emissive_material(Color(0.04, 0.92, 1.0), Color(0.0, 0.72, 1.0), 1.4)
	_materials[&"neon_magenta"] = _make_emissive_material(Color(1.0, 0.16, 0.70), Color(1.0, 0.02, 0.48), 1.3)
	_materials[&"window"] = _make_emissive_material(Color(0.98, 0.80, 0.36), Color(1.0, 0.52, 0.08), 0.75)
	_materials[&"water"] = _make_material(Color(0.015, 0.12, 0.20), 0.24, 0.35)
	_materials[&"finish"] = _make_emissive_material(Color(0.92, 0.96, 1.0), Color(0.35, 0.75, 1.0), 0.85)

func _build_night_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.012, 0.025, 0.075)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.18, 0.27, 0.46)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.name = "NeonHarborWorldEnvironment"
	world_environment.environment = environment
	add_child(world_environment)

	var moon := DirectionalLight3D.new()
	moon.name = "HarborMoonLight"
	moon.rotation_degrees = Vector3(-50.0, -32.0, 0.0)
	moon.light_color = Color(0.58, 0.72, 1.0)
	moon.light_energy = 0.42
	moon.shadow_enabled = true
	add_child(moon)

	for light_data in [
		[Vector3(35, 8, -110), Color(0.10, 0.88, 1.0)],
		[Vector3(-70, 8, -360), Color(1.0, 0.48, 0.14)],
		[Vector3(95, 10, -620), Color(0.12, 0.76, 1.0)],
		[Vector3(-80, 13, -900), Color(1.0, 0.18, 0.66)],
		[Vector3(-20, 9, -1035), Color(0.10, 0.88, 1.0)],
	]:
		var light := OmniLight3D.new()
		light.position = light_data[0]
		light.light_color = light_data[1]
		light.light_energy = 2.0
		light.omni_range = 34.0
		light.shadow_enabled = false
		add_child(light)

func _build_track() -> void:
	_decoration_root = Node3D.new()
	_decoration_root.name = "DecorationGeometry"
	_decoration_root.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_decoration_root)

	_collision_root = Node3D.new()
	_collision_root.name = "GameplayCollision"
	add_child(_collision_root)

	var road_transforms: Array[Transform3D] = []
	var edge_transforms: Array[Transform3D] = []
	var rail_transforms: Array[Transform3D] = []
	var rail_post_transforms: Array[Transform3D] = []
	var warning_transforms: Array[Transform3D] = []
	_track_length = 0.0

	for index in range(ROUTE_POINTS.size() - 1):
		var a := ROUTE_POINTS[index]
		var b := ROUTE_POINTS[index + 1]
		var width := SEGMENT_WIDTHS[index]
		var length := a.distance_to(b)
		_track_length += length
		road_transforms.append(_track_transform_at(a, b, 0.5, 0.0, -0.20, Vector3(width, 0.50, length)))
		_create_collision_segment("Road_%02d" % index, a, b, Vector3(width, 0.50, length), -0.20)
		for side in [-1.0, 1.0]:
			edge_transforms.append(_track_transform_at(a, b, 0.5, side * (width * 0.5 - 0.42), 0.10, Vector3(0.20, 0.05, maxf(0.5, length - 0.3))))
			rail_transforms.append(_track_transform_at(a, b, 0.5, side * (width * 0.5 + 0.45), 0.76, Vector3(0.30, 0.38, length)))
			var post_count := maxi(4, int(ceil(length / 10.0)))
			for post_index in range(post_count + 1):
				var t := float(post_index) / float(post_count)
				rail_post_transforms.append(_track_transform_at(a, b, t, side * (width * 0.5 + 0.45), 0.65, Vector3(0.28, 1.30, 0.28)))
		if DANGEROUS_RAIL_SEGMENTS.has(index):
			_create_guardrail_collision(index, a, b, width)
		if index in [3, 4, 7, 8, 13, 18, 22, 23]:
			for t in [0.64, 0.82]:
				warning_transforms.append(_track_transform_at(a, b, t, 0.0, 0.115, Vector3(width * 0.42, 0.05, 0.30)))

	_add_box_multimesh("HarborRoadSurface", road_transforms, _materials[&"road"])
	_add_box_multimesh("HarborRoadEdges", edge_transforms, _materials[&"road_edge"])
	_add_box_multimesh("HarborGuardrails", rail_transforms, _materials[&"metal"])
	_add_box_multimesh("HarborGuardrailPosts", rail_post_transforms, _materials[&"metal"])
	_add_box_multimesh("HarborWarningMarks", warning_transforms, _materials[&"warning"])

	_build_start_and_finish()
	_build_checkpoints()
	_build_container_yard()
	_build_warehouses()
	_build_crane_district()
	_build_dockside()
	_build_industrial_tunnel()
	_build_elevated_highway()
	_build_neon_downtown()
	_build_shipyard_chicane()
	_build_shortcuts()
	_build_dynamic_obstacles()
	_build_street_lights()

func _build_start_and_finish() -> void:
	var start_a := ROUTE_POINTS[0]
	var start_b := ROUTE_POINTS[1]
	var start_width := SEGMENT_WIDTHS[0]
	var gantry: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		gantry.append(_track_transform_at(start_a, start_b, 0.09, side * (start_width * 0.5 + 0.60), 2.5, Vector3(0.42, 5.0, 0.42)))
	gantry.append(_track_transform_at(start_a, start_b, 0.09, 0.0, 4.75, Vector3(start_width + 2.0, 0.42, 0.42)))
	_add_box_multimesh("StartGantry", gantry, _materials[&"metal"])

	var finish := ROUTE_POINTS[-1]
	var previous := ROUTE_POINTS[-2]
	var finish_width := SEGMENT_WIDTHS[-1]
	var finish_frame: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		finish_frame.append(_track_transform_at(previous, finish, 1.0, side * (finish_width * 0.5 + 0.65), 2.7, Vector3(0.48, 5.4, 0.48)))
	finish_frame.append(_track_transform_at(previous, finish, 1.0, 0.0, 5.05, Vector3(finish_width + 2.2, 0.50, 0.50)))
	_add_box_multimesh("FinishGantry", finish_frame, _materials[&"neon_cyan"])

	var stripe := CSGBox3D.new()
	stripe.name = "FinishStripe"
	stripe.size = Vector3(finish_width, 0.06, 0.65)
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
	box.size = Vector3(finish_width + 1.5, 4.5, 6.0)
	shape.shape = box
	area.add_child(shape)

func _build_checkpoints() -> void:
	for checkpoint_index in range(CHECKPOINT_ROUTE_INDICES.size()):
		var route_index := CHECKPOINT_ROUTE_INDICES[checkpoint_index]
		var point := ROUTE_POINTS[route_index]
		var next_point := ROUTE_POINTS[min(route_index + 1, ROUTE_POINTS.size() - 1)]
		var width := SEGMENT_WIDTHS[min(route_index, SEGMENT_WIDTHS.size() - 1)]
		var area := Area3D.new()
		area.name = "Checkpoint_%02d" % (checkpoint_index + 1)
		area.set_script(CHECKPOINT_SCRIPT)
		area.set("checkpoint_index", checkpoint_index)
		area.position = point + Vector3.UP * 1.8
		area.collision_mask = 2
		add_child(area)
		area.look_at(next_point + Vector3.UP * 1.8, Vector3.UP)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(width + 2.0, 5.0, 7.0)
		shape.shape = box
		area.add_child(shape)

func _build_container_yard() -> void:
	var red: Array[Transform3D] = []
	var blue: Array[Transform3D] = []
	var teal: Array[Transform3D] = []
	var ribs: Array[Transform3D] = []
	var centers := [ROUTE_POINTS[2], ROUTE_POINTS[3], ROUTE_POINTS[4]]
	for center_index in range(centers.size()):
		var center: Vector3 = centers[center_index]
		for side in [-1.0, 1.0]:
			for stack in range(3):
				var offset := Vector3(side * (13.5 + stack * 7.0), 1.35 + float(stack % 2) * 2.7, float(stack - 1) * 7.4)
				var transform := Transform3D(Basis.IDENTITY, center + offset)
				transform.basis = transform.basis.scaled(Vector3(5.8, 2.55, 2.45))
				match (center_index + stack) % 3:
					0: red.append(transform)
					1: blue.append(transform)
					_: teal.append(transform)
				for rib in range(4):
					var rib_t := -2.4 + float(rib) * 1.6
					var rib_transform := Transform3D(Basis.IDENTITY, center + offset + Vector3(rib_t, 0.0, -2.50))
					rib_transform.basis = rib_transform.basis.scaled(Vector3(0.12, 2.45, 0.10))
					ribs.append(rib_transform)
	_add_box_multimesh("ContainersRed", red, _materials[&"container_red"])
	_add_box_multimesh("ContainersBlue", blue, _materials[&"container_blue"])
	_add_box_multimesh("ContainersTeal", teal, _materials[&"container_teal"])
	_add_box_multimesh("ContainerRibs", ribs, _materials[&"metal"])

func _build_warehouses() -> void:
	var bodies: Array[Transform3D] = []
	var trims: Array[Transform3D] = []
	var bays: Array[Transform3D] = []
	for index in [4, 5, 6, 11, 12]:
		var center := ROUTE_POINTS[index]
		for side in [-1.0, 1.0]:
			var right := _segment_right(maxi(0, mini(index, ROUTE_POINTS.size() - 2)))
			var origin := center + right * side * 18.0 + Vector3.UP * 4.0
			var body := Transform3D(Basis.IDENTITY, origin)
			body.basis = body.basis.scaled(Vector3(13.0, 8.0, 10.0))
			bodies.append(body)
			var trim := Transform3D(Basis.IDENTITY, origin + Vector3.UP * 4.35)
			trim.basis = trim.basis.scaled(Vector3(13.8, 0.45, 10.8))
			trims.append(trim)
			var bay := Transform3D(Basis.IDENTITY, origin + Vector3(-side * 6.7, -1.4, 0.0))
			bay.basis = bay.basis.scaled(Vector3(0.30, 3.6, 5.0))
			bays.append(bay)
	_add_box_multimesh("WarehouseBodies", bodies, _materials[&"warehouse"])
	_add_box_multimesh("WarehouseRoofTrim", trims, _materials[&"metal"])
	_add_box_multimesh("WarehouseLoadingBays", bays, _materials[&"warning"])

func _build_crane_district() -> void:
	var crane_parts: Array[Transform3D] = []
	for anchor in [Vector3(-92, 0, -325), Vector3(-132, 0, -410), Vector3(-78, 0, -470)]:
		for side in [-1.0, 1.0]:
			var leg := Transform3D(Basis.IDENTITY, anchor + Vector3(side * 5.5, 6.0, 0.0))
			leg.basis = leg.basis.scaled(Vector3(0.65, 12.0, 0.65))
			crane_parts.append(leg)
		var top := Transform3D(Basis.IDENTITY, anchor + Vector3(0.0, 11.8, 0.0))
		top.basis = top.basis.scaled(Vector3(15.0, 0.65, 0.65))
		crane_parts.append(top)
		var boom := Transform3D(Basis.IDENTITY, anchor + Vector3(7.5, 14.0, 0.0))
		boom.basis = boom.basis.rotated(Vector3.FORWARD, -0.18).scaled(Vector3(14.0, 0.45, 0.45))
		crane_parts.append(boom)
	_add_box_multimesh("HarborCranes", crane_parts, _materials[&"warning"])

func _build_dockside() -> void:
	var water := CSGBox3D.new()
	water.name = "HarborWater"
	water.size = Vector3(170.0, 0.35, 360.0)
	water.position = Vector3(-150.0, -1.15, -530.0)
	water.use_collision = false
	water.material = _materials[&"water"]
	_decoration_root.add_child(water)

	var dock_posts: Array[Transform3D] = []
	for index in range(13):
		var origin := Vector3(-145.0 + float(index % 2) * 8.0, 1.2, -350.0 - float(index) * 24.0)
		var post := Transform3D(Basis.IDENTITY, origin)
		post.basis = post.basis.scaled(Vector3(0.55, 2.4, 0.55))
		dock_posts.append(post)
	_add_box_multimesh("DockPosts", dock_posts, _materials[&"metal"])

func _build_industrial_tunnel() -> void:
	var a := ROUTE_POINTS[TUNNEL_SEGMENT_INDEX]
	var b := ROUTE_POINTS[TUNNEL_SEGMENT_INDEX + 1]
	var width := SEGMENT_WIDTHS[TUNNEL_SEGMENT_INDEX]
	var length := a.distance_to(b)
	var walls: Array[Transform3D] = []
	var lights: Array[Transform3D] = []
	var pipes: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		walls.append(_track_transform_at(a, b, 0.5, side * (width * 0.5 + 0.45), 2.5, Vector3(0.70, 5.4, length)))
		for pipe_index in range(6):
			pipes.append(_track_transform_at(a, b, 0.10 + float(pipe_index) * 0.16, side * (width * 0.5 - 0.55), 3.65, Vector3(0.20, 0.20, 7.0)))
	walls.append(_track_transform_at(a, b, 0.5, 0.0, 5.0, Vector3(width + 1.5, 0.75, length)))
	for light_index in range(9):
		lights.append(_track_transform_at(a, b, 0.06 + float(light_index) * 0.11, 0.0, 4.48, Vector3(2.8, 0.12, 0.55)))
	_add_box_multimesh("IndustrialTunnelPanels", walls, _materials[&"concrete"])
	_add_box_multimesh("IndustrialTunnelPipes", pipes, _materials[&"metal"])
	_add_box_multimesh("IndustrialTunnelLights", lights, _materials[&"neon_cyan"])

	_create_collision_segment("TunnelWallL", a, b, Vector3(0.75, 5.5, length), 2.5, -(width * 0.5 + 0.45))
	_create_collision_segment("TunnelWallR", a, b, Vector3(0.75, 5.5, length), 2.5, width * 0.5 + 0.45)
	_create_collision_segment("TunnelRoof", a, b, Vector3(width + 1.5, 0.80, length), 5.0)

func _build_elevated_highway() -> void:
	var supports: Array[Transform3D] = []
	for segment_index in ELEVATED_SEGMENTS:
		var a := ROUTE_POINTS[segment_index]
		var b := ROUTE_POINTS[segment_index + 1]
		for t in [0.28, 0.72]:
			var point := a.lerp(b, t)
			var height := maxf(3.0, point.y + 6.0)
			var support := Transform3D(Basis.IDENTITY, Vector3(point.x, point.y - height * 0.5 - 0.3, point.z))
			support.basis = support.basis.scaled(Vector3(1.1, height, 1.1))
			supports.append(support)
	_add_box_multimesh("ElevatedHighwaySupports", supports, _materials[&"concrete"])

func _build_neon_downtown() -> void:
	var buildings: Array[Transform3D] = []
	var cyan_signs: Array[Transform3D] = []
	var magenta_signs: Array[Transform3D] = []
	var windows: Array[Transform3D] = []
	for index in range(20, 23):
		var center := ROUTE_POINTS[index]
		var right := _segment_right(index)
		for side in [-1.0, 1.0]:
			for building_index in range(3):
				var distance := 16.0 + float(building_index) * 8.0
				var height := 9.0 + float((index + building_index) % 4) * 3.0
				var origin := center + right * side * distance + Vector3(0.0, height * 0.5 - 0.2, float(building_index - 1) * 9.0)
				var building := Transform3D(Basis.IDENTITY, origin)
				building.basis = building.basis.scaled(Vector3(7.0, height, 7.0))
				buildings.append(building)
				var sign := Transform3D(Basis.IDENTITY, origin + Vector3(-right.x * side * 3.7, 1.2, -right.z * side * 3.7))
				sign.basis = sign.basis.scaled(Vector3(2.4, 1.0, 0.12))
				if (index + building_index) % 2 == 0:
					cyan_signs.append(sign)
				else:
					magenta_signs.append(sign)
				for window_index in range(3):
					var win := Transform3D(Basis.IDENTITY, origin + Vector3(0.0, -2.0 + float(window_index) * 2.2, -3.58))
					win.basis = win.basis.scaled(Vector3(3.8, 0.45, 0.10))
					windows.append(win)
	_add_box_multimesh("NeonCityBuildings", buildings, _materials[&"warehouse"])
	_add_box_multimesh("NeonCyanSigns", cyan_signs, _materials[&"neon_cyan"])
	_add_box_multimesh("NeonMagentaSigns", magenta_signs, _materials[&"neon_magenta"])
	_add_box_multimesh("NeonBuildingWindows", windows, _materials[&"window"])

func _build_shipyard_chicane() -> void:
	var barriers: Array[Transform3D] = []
	for segment_index in [22, 23]:
		var a := ROUTE_POINTS[segment_index]
		var b := ROUTE_POINTS[segment_index + 1]
		var width := SEGMENT_WIDTHS[segment_index]
		for t in [0.30, 0.52, 0.74]:
			var side := -1.0 if int(t * 100.0) % 2 == 0 else 1.0
			barriers.append(_track_transform_at(a, b, t, side * (width * 0.5 - 1.05), 0.55, Vector3(0.70, 1.10, 4.2)))
	_add_box_multimesh("ShipyardChicaneBarriers", barriers, _materials[&"warning"])

func _build_shortcuts() -> void:
	var shortcut_a := _shortcut_transform(SHORTCUT_A_SKIP_ROUTE_INDEX, 6.0)
	var shortcut_b := _shortcut_transform(SHORTCUT_B_SKIP_ROUTE_INDEX, 5.6)
	_add_box_multimesh("HarborShortcutRoads", [shortcut_a[0], shortcut_b[0]], _materials[&"concrete"])
	_create_shortcut_collision("ShortcutA", SHORTCUT_A_SKIP_ROUTE_INDEX, 6.0)
	_create_shortcut_collision("ShortcutB", SHORTCUT_B_SKIP_ROUTE_INDEX, 5.6)

func _build_dynamic_obstacles() -> void:
	_create_dynamic_barrier("CargoBarrier", ROUTE_POINTS[7].lerp(ROUTE_POINTS[8], 0.55), 5.5, 1.05, 3.8)
	_create_dynamic_barrier("WarehouseGate", ROUTE_POINTS[21].lerp(ROUTE_POINTS[22], 0.58), 4.6, 1.20, 3.2)

func _build_street_lights() -> void:
	var posts: Array[Transform3D] = []
	var lamps: Array[Transform3D] = []
	for segment_index in [0, 1, 2, 8, 9, 10, 19, 20, 21, 24]:
		var a := ROUTE_POINTS[segment_index]
		var b := ROUTE_POINTS[segment_index + 1]
		var width := SEGMENT_WIDTHS[segment_index]
		for t in [0.24, 0.52, 0.80]:
			for side in [-1.0, 1.0]:
				posts.append(_track_transform_at(a, b, t, side * (width * 0.5 + 1.6), 2.1, Vector3(0.16, 4.2, 0.16)))
				lamps.append(_track_transform_at(a, b, t, side * (width * 0.5 + 1.25), 4.15, Vector3(0.85, 0.18, 0.36)))
	_add_box_multimesh("StreetLightPosts", posts, _materials[&"metal"])
	_add_box_multimesh("StreetLampGlow", lamps, _materials[&"window"])

func _create_dynamic_barrier(node_name: String, origin: Vector3, width: float, speed: float, amplitude: float) -> void:
	var body := AnimatableBody3D.new()
	body.name = node_name
	body.set_script(DYNAMIC_OBSTACLE_SCRIPT)
	body.set("motion_type", WildDashDynamicObstacle.MotionType.SWEEP)
	body.set("motion_speed", speed)
	body.set("amplitude", amplitude)
	body.position = origin + Vector3.UP * 1.15
	_collision_root.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 2.3, 0.8)
	shape.shape = box
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 2.3, 0.8)
	visual.mesh = mesh
	visual.material_override = _materials[&"warning"]
	body.add_child(visual)

func _create_guardrail_collision(index: int, a: Vector3, b: Vector3, width: float) -> void:
	var length := a.distance_to(b)
	for side in [-1.0, 1.0]:
		_create_collision_segment("Rail_%02d_%s" % [index, "L" if side < 0.0 else "R"], a, b, Vector3(0.45, 1.55, length), 0.72, side * (width * 0.5 + 0.45))

func _create_collision_segment(node_name: String, a: Vector3, b: Vector3, size: Vector3, vertical_offset: float, lateral_offset := 0.0) -> void:
	var collision := CSGBox3D.new()
	collision.name = node_name
	collision.size = size
	collision.use_collision = true
	collision.visible = false
	collision.transform = _track_transform_at(a, b, 0.5, lateral_offset, vertical_offset, size)
	# _track_transform_at encodes scale in the basis for MultiMesh; CSGBox3D has
	# an explicit size, so keep only orientation/origin here.
	collision.scale = Vector3.ONE
	_collision_root.add_child(collision)
	collision.look_at(b + _segment_right_by_points(a, b) * lateral_offset + Vector3.UP * vertical_offset, Vector3.UP)

func _create_shortcut_collision(node_name: String, skip_index: int, width: float) -> void:
	var a := ROUTE_POINTS[skip_index - 1]
	var b := ROUTE_POINTS[skip_index + 1]
	_create_collision_segment(node_name, a, b, Vector3(width, 0.42, a.distance_to(b)), -0.16)

func _shortcut_transform(skip_index: int, width: float) -> Array[Transform3D]:
	var a := ROUTE_POINTS[skip_index - 1]
	var b := ROUTE_POINTS[skip_index + 1]
	return [_track_transform_at(a, b, 0.5, 0.0, -0.16, Vector3(width, 0.42, a.distance_to(b)))]

func _shortcut_saving(skip_index: int) -> float:
	var a := ROUTE_POINTS[skip_index - 1]
	var middle := ROUTE_POINTS[skip_index]
	var b := ROUTE_POINTS[skip_index + 1]
	return a.distance_to(middle) + middle.distance_to(b) - a.distance_to(b)

func _segment_right(segment_index: int) -> Vector3:
	return _segment_right_by_points(ROUTE_POINTS[segment_index], ROUTE_POINTS[segment_index + 1])

func _segment_right_by_points(a: Vector3, b: Vector3) -> Vector3:
	var direction := b - a
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return Vector3.RIGHT
	direction = direction.normalized()
	return Vector3(-direction.z, 0.0, direction.x)

func _track_transform_at(a: Vector3, b: Vector3, t: float, lateral_offset: float, vertical_offset: float, size: Vector3) -> Transform3D:
	var direction := b - a
	var right := _segment_right_by_points(a, b)
	var origin := a.lerp(b, t) + right * lateral_offset + Vector3.UP * vertical_offset
	var transform := Transform3D(Basis.IDENTITY, origin)
	transform = transform.looking_at(origin + direction.normalized(), Vector3.UP)
	transform.basis = transform.basis.scaled(size)
	return transform

func _add_box_multimesh(node_name: String, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	_decoration_root.add_child(instance)

func _make_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _make_emissive_material(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := _make_material(color, 0.42, 0.18)
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material

func _count_nodes_recursive(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes_recursive(child)
	return count
