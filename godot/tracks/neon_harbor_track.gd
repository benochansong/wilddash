class_name WildDashNeonHarborTrack
extends Node3D

const CHECKPOINT_SCRIPT: Script = preload("res://tracks/checkpoint.gd")
const FINISH_SCRIPT: Script = preload("res://tracks/finish_line.gd")
const DYNAMIC_OBSTACLE_SCRIPT: Script = preload("res://tracks/dynamic_obstacle.gd")

const ROUTE_POINTS: Array[Vector3] = [
	Vector3(0.0, 0.0, 73.6), Vector3(0.0, 0.0, 9.2), Vector3(46.0, 0.0, -50.6),
	Vector3(96.6, 0.0, -87.4), Vector3(133.4, 0.0, -142.6), Vector3(101.2, 0.0, -202.4),
	Vector3(50.6, 0.0, -248.4), Vector3(-4.6, 0.0, -289.8), Vector3(-64.4, 0.0, -322.0),
	Vector3(-110.4, 0.0, -386.4), Vector3(-78.2, 0.0, -450.8), Vector3(-23.0, 0.0, -501.4),
	Vector3(41.4, 0.0, -529.0), Vector3(96.6, 0.0, -579.6), Vector3(133.4, 0.0, -644.0),
	Vector3(105.8, 2.8, -703.8), Vector3(50.6, 6.4, -759.0), Vector3(-9.2, 8.3, -805.0),
	Vector3(-69.0, 6.4, -855.6), Vector3(-119.6, 2.8, -915.4), Vector3(-96.6, 0.0, -975.2),
	Vector3(-41.4, 0.0, -1025.8), Vector3(18.4, 0.0, -1062.6), Vector3(73.6, 0.0, -1113.2),
	Vector3(41.4, 0.0, -1177.6), Vector3(9.2, 0.0, -1246.6),
]

const SEGMENT_WIDTHS: Array[float] = [
	18.0, 18.0, 16.0, 15.0, 14.0, 15.0, 14.0, 13.5, 13.0, 14.0,
	16.0, 17.0, 16.0, 15.0, 14.0, 14.0, 13.5, 13.0, 13.0, 14.0,
	15.0, 14.0, 13.0, 12.5, 18.0,
]
const CHECKPOINT_ROUTE_INDICES: Array[int] = [2, 5, 8, 11, 14, 17, 20, 23, 24]
const SHORTCUT_A_SKIP_ROUTE_INDEX := 4
const TUNNEL_SEGMENT_INDEX := 13
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
	print("NEON HARBOR TRACK READY route_points=%d checkpoints=%d length=%.1fm nodes=%d shortcuts=1" % [
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

func get_shortcut_a_saving() -> float:
	return _shortcut_saving(SHORTCUT_A_SKIP_ROUTE_INDEX)

func get_shortcut_b_saving() -> float:
	return 0.0

func get_runtime_node_count() -> int:
	return _count_nodes_recursive(self)

func get_zone_names() -> PackedStringArray:
	return PackedStringArray([
		"Harbor Boulevard", "Container Yard", "Warehouse S-Curve", "Crane District", "Dockside Straight",
		"Industrial Tunnel", "Elevated Highway", "Neon Downtown", "Shipyard Chicane", "Final Harbor Straight",
	])

func _build_materials() -> void:
	_materials[&"road"] = _mat(Color(0.055, 0.075, 0.11), 0.42, 0.08)
	_materials[&"edge"] = _emissive(Color(0.74, 0.92, 1.0), Color(0.08, 0.58, 1.0), 0.38)
	_materials[&"metal"] = _mat(Color(0.25, 0.32, 0.40), 0.34, 0.72)
	_materials[&"concrete"] = _mat(Color(0.25, 0.28, 0.34), 0.80, 0.0)
	_materials[&"building"] = _mat(Color(0.14, 0.18, 0.27), 0.72, 0.12)
	_materials[&"red"] = _mat(Color(0.58, 0.11, 0.13), 0.68, 0.22)
	_materials[&"blue"] = _mat(Color(0.08, 0.30, 0.50), 0.62, 0.28)
	_materials[&"teal"] = _mat(Color(0.04, 0.42, 0.42), 0.60, 0.26)
	_materials[&"warning"] = _emissive(Color(1.0, 0.56, 0.10), Color(1.0, 0.28, 0.02), 0.78)
	_materials[&"cyan"] = _emissive(Color(0.04, 0.92, 1.0), Color(0.0, 0.72, 1.0), 1.35)
	_materials[&"magenta"] = _emissive(Color(1.0, 0.16, 0.70), Color(1.0, 0.02, 0.48), 1.30)
	_materials[&"window"] = _emissive(Color(0.98, 0.80, 0.36), Color(1.0, 0.52, 0.08), 0.78)
	_materials[&"water"] = _mat(Color(0.015, 0.12, 0.20), 0.24, 0.35)
	_materials[&"finish"] = _emissive(Color(0.92, 0.96, 1.0), Color(0.35, 0.75, 1.0), 0.90)

func _build_night_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.025, 0.075)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.27, 0.46)
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.name = "NeonHarborWorldEnvironment"
	world.environment = env
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.name = "HarborMoonLight"
	moon.rotation_degrees = Vector3(-50.0, -32.0, 0.0)
	moon.light_color = Color(0.58, 0.72, 1.0)
	moon.light_energy = 0.42
	moon.shadow_enabled = true
	add_child(moon)
	for index in range(4):
		var light := OmniLight3D.new()
		light.position = [Vector3(35, 8, -110), Vector3(-70, 8, -360), Vector3(95, 10, -620), Vector3(-35, 10, -1035)][index]
		light.light_color = [Color(0.1, 0.88, 1.0), Color(1.0, 0.48, 0.14), Color(0.12, 0.76, 1.0), Color(1.0, 0.18, 0.66)][index]
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

	var roads: Array[Transform3D] = []
	var edges: Array[Transform3D] = []
	var rails: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	var warnings: Array[Transform3D] = []
	_track_length = 0.0
	for index in range(ROUTE_POINTS.size() - 1):
		var a: Vector3 = ROUTE_POINTS[index]
		var b: Vector3 = ROUTE_POINTS[index + 1]
		var width: float = SEGMENT_WIDTHS[index]
		var length: float = a.distance_to(b)
		_track_length += length
		roads.append(_track_xform(a, b, 0.5, 0.0, -0.20, Vector3(width, 0.50, length)))
		_add_collision_box("Road_%02d" % index, a, b, width, 0.50, -0.20, 0.0)
		for side: float in [-1.0, 1.0]:
			edges.append(_track_xform(a, b, 0.5, side * (width * 0.5 - 0.42), 0.10, Vector3(0.20, 0.05, length - 0.3)))
			rails.append(_track_xform(a, b, 0.5, side * (width * 0.5 + 0.45), 0.76, Vector3(0.30, 0.38, length)))
			var post_count: int = maxi(4, int(ceil(length / 10.0)))
			for post_index in range(post_count + 1):
				posts.append(_track_xform(a, b, float(post_index) / float(post_count), side * (width * 0.5 + 0.45), 0.65, Vector3(0.28, 1.30, 0.28)))
		if DANGEROUS_RAIL_SEGMENTS.has(index):
			_add_rail_collision(index, a, b, width)
		if index in [3, 4, 7, 8, 13, 18, 22, 23]:
			for t: float in [0.64, 0.82]:
				warnings.append(_track_xform(a, b, t, 0.0, 0.115, Vector3(width * 0.42, 0.05, 0.30)))
	_add_batch("HarborRoadSurface", roads, _materials[&"road"])
	_add_batch("HarborRoadEdges", edges, _materials[&"edge"])
	_add_batch("HarborGuardrails", rails, _materials[&"metal"])
	_add_batch("HarborGuardrailPosts", posts, _materials[&"metal"])
	_add_batch("HarborWarningMarks", warnings, _materials[&"warning"])

	_build_start_finish()
	_build_checkpoints()
	_build_container_yard()
	_build_warehouses()
	_build_cranes()
	_build_dockside()
	_build_tunnel()
	_build_elevated_supports()
	_build_neon_city()
	_build_chicane()
	_build_shortcut()
	_build_dynamic_obstacles()
	_build_street_lights()

func _build_start_finish() -> void:
	var start_parts: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		start_parts.append(_track_xform(ROUTE_POINTS[0], ROUTE_POINTS[1], 0.09, side * 9.6, 2.5, Vector3(0.42, 5.0, 0.42)))
	start_parts.append(_track_xform(ROUTE_POINTS[0], ROUTE_POINTS[1], 0.09, 0.0, 4.75, Vector3(20.0, 0.42, 0.42)))
	_add_batch("StartGantry", start_parts, _materials[&"metal"])
	var finish_parts: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		finish_parts.append(_track_xform(ROUTE_POINTS[-2], ROUTE_POINTS[-1], 1.0, side * 9.65, 2.7, Vector3(0.48, 5.4, 0.48)))
	finish_parts.append(_track_xform(ROUTE_POINTS[-2], ROUTE_POINTS[-1], 1.0, 0.0, 5.05, Vector3(20.2, 0.50, 0.50)))
	_add_batch("FinishGantry", finish_parts, _materials[&"cyan"])
	var finish: Vector3 = ROUTE_POINTS[-1]
	var previous: Vector3 = ROUTE_POINTS[-2]
	var stripe := CSGBox3D.new()
	stripe.name = "FinishStripe"
	stripe.size = Vector3(18.0, 0.06, 0.65)
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
	box.size = Vector3(19.5, 4.5, 6.0)
	shape.shape = box
	area.add_child(shape)

func _build_checkpoints() -> void:
	for checkpoint_index in range(CHECKPOINT_ROUTE_INDICES.size()):
		var route_index: int = CHECKPOINT_ROUTE_INDICES[checkpoint_index]
		var point: Vector3 = ROUTE_POINTS[route_index]
		var next: Vector3 = ROUTE_POINTS[min(route_index + 1, ROUTE_POINTS.size() - 1)]
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
		box.size = Vector3(SEGMENT_WIDTHS[min(route_index, SEGMENT_WIDTHS.size() - 1)] + 2.0, 5.0, 7.0)
		shape.shape = box
		area.add_child(shape)

func _build_container_yard() -> void:
	var groups: Array = [[], [], []]
	var ribs: Array[Transform3D] = []
	for route_index in [2, 3, 4]:
		var center: Vector3 = ROUTE_POINTS[route_index]
		for side: float in [-1.0, 1.0]:
			for stack in range(3):
				var origin: Vector3 = center + Vector3(side * (13.5 + float(stack) * 7.0), 1.35 + float(stack % 2) * 2.7, float(stack - 1) * 7.4)
				var container := Transform3D(Basis.IDENTITY, origin)
				container.basis = container.basis.scaled(Vector3(5.8, 2.55, 2.45))
				groups[(route_index + stack) % 3].append(container)
				for rib in range(4):
					var rib_xform := Transform3D(Basis.IDENTITY, origin + Vector3(-2.4 + float(rib) * 1.6, 0.0, -2.50))
					rib_xform.basis = rib_xform.basis.scaled(Vector3(0.12, 2.45, 0.10))
					ribs.append(rib_xform)
	_add_batch("ContainersRed", _as_xforms(groups[0]), _materials[&"red"])
	_add_batch("ContainersBlue", _as_xforms(groups[1]), _materials[&"blue"])
	_add_batch("ContainersTeal", _as_xforms(groups[2]), _materials[&"teal"])
	_add_batch("ContainerRibs", ribs, _materials[&"metal"])

func _build_warehouses() -> void:
	var bodies: Array[Transform3D] = []
	var trim: Array[Transform3D] = []
	var bays: Array[Transform3D] = []
	for route_index in [4, 5, 6, 11, 12]:
		var center: Vector3 = ROUTE_POINTS[route_index]
		var right: Vector3 = _segment_right(min(route_index, ROUTE_POINTS.size() - 2))
		for side: float in [-1.0, 1.0]:
			var origin: Vector3 = center + right * side * 18.0 + Vector3.UP * 4.0
			var body := Transform3D(Basis.IDENTITY, origin)
			body.basis = body.basis.scaled(Vector3(13.0, 8.0, 10.0))
			bodies.append(body)
			var roof := Transform3D(Basis.IDENTITY, origin + Vector3.UP * 4.35)
			roof.basis = roof.basis.scaled(Vector3(13.8, 0.45, 10.8))
			trim.append(roof)
			var bay := Transform3D(Basis.IDENTITY, origin + right * -side * 6.7 + Vector3.DOWN * 1.4)
			bay.basis = bay.basis.scaled(Vector3(0.30, 3.6, 5.0))
			bays.append(bay)
	_add_batch("WarehouseBodies", bodies, _materials[&"building"])
	_add_batch("WarehouseRoofTrim", trim, _materials[&"metal"])
	_add_batch("WarehouseLoadingBays", bays, _materials[&"warning"])

func _build_cranes() -> void:
	var parts: Array[Transform3D] = []
	for anchor: Vector3 in [Vector3(-92, 0, -325), Vector3(-132, 0, -410), Vector3(-78, 0, -470)]:
		for side: float in [-1.0, 1.0]:
			var leg := Transform3D(Basis.IDENTITY, anchor + Vector3(side * 5.5, 6.0, 0.0))
			leg.basis = leg.basis.scaled(Vector3(0.65, 12.0, 0.65))
			parts.append(leg)
		var top := Transform3D(Basis.IDENTITY, anchor + Vector3(0.0, 11.8, 0.0))
		top.basis = top.basis.scaled(Vector3(15.0, 0.65, 0.65))
		parts.append(top)
		var boom := Transform3D(Basis.IDENTITY, anchor + Vector3(7.5, 14.0, 0.0))
		boom.basis = boom.basis.rotated(Vector3.FORWARD, -0.18).scaled(Vector3(14.0, 0.45, 0.45))
		parts.append(boom)
	_add_batch("HarborCranes", parts, _materials[&"warning"])

func _build_dockside() -> void:
	var water := CSGBox3D.new()
	water.name = "HarborWater"
	water.size = Vector3(170.0, 0.35, 360.0)
	water.position = Vector3(-150.0, -1.15, -530.0)
	water.use_collision = false
	water.material = _materials[&"water"]
	_decoration_root.add_child(water)

func _build_tunnel() -> void:
	var a: Vector3 = ROUTE_POINTS[TUNNEL_SEGMENT_INDEX]
	var b: Vector3 = ROUTE_POINTS[TUNNEL_SEGMENT_INDEX + 1]
	var width: float = SEGMENT_WIDTHS[TUNNEL_SEGMENT_INDEX]
	var length: float = a.distance_to(b)
	var panels: Array[Transform3D] = []
	var lights: Array[Transform3D] = []
	var pipes: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		panels.append(_track_xform(a, b, 0.5, side * (width * 0.5 + 0.45), 2.5, Vector3(0.70, 5.4, length)))
		for pipe_index in range(6):
			pipes.append(_track_xform(a, b, 0.10 + float(pipe_index) * 0.16, side * (width * 0.5 - 0.55), 3.65, Vector3(0.20, 0.20, 7.0)))
	panels.append(_track_xform(a, b, 0.5, 0.0, 5.0, Vector3(width + 1.5, 0.75, length)))
	for light_index in range(9):
		lights.append(_track_xform(a, b, 0.06 + float(light_index) * 0.11, 0.0, 4.48, Vector3(2.8, 0.12, 0.55)))
	_add_batch("IndustrialTunnelPanels", panels, _materials[&"concrete"])
	_add_batch("IndustrialTunnelPipes", pipes, _materials[&"metal"])
	_add_batch("IndustrialTunnelLights", lights, _materials[&"cyan"])
	_add_collision_box("TunnelWallL", a, b, 0.75, 5.5, 2.5, -(width * 0.5 + 0.45))
	_add_collision_box("TunnelWallR", a, b, 0.75, 5.5, 2.5, width * 0.5 + 0.45)
	_add_collision_box("TunnelRoof", a, b, width + 1.5, 0.80, 5.0, 0.0)

func _build_elevated_supports() -> void:
	var supports: Array[Transform3D] = []
	for segment_index in [15, 16, 17, 18]:
		var a: Vector3 = ROUTE_POINTS[segment_index]
		var b: Vector3 = ROUTE_POINTS[segment_index + 1]
		for t: float in [0.28, 0.72]:
			var point: Vector3 = a.lerp(b, t)
			var height: float = maxf(3.0, point.y + 6.0)
			var support := Transform3D(Basis.IDENTITY, Vector3(point.x, point.y - height * 0.5 - 0.3, point.z))
			support.basis = support.basis.scaled(Vector3(1.1, height, 1.1))
			supports.append(support)
	_add_batch("ElevatedHighwaySupports", supports, _materials[&"concrete"])

func _build_neon_city() -> void:
	var buildings: Array[Transform3D] = []
	var cyan: Array[Transform3D] = []
	var magenta: Array[Transform3D] = []
	var windows: Array[Transform3D] = []
	for route_index in range(20, 23):
		var center: Vector3 = ROUTE_POINTS[route_index]
		var right: Vector3 = _segment_right(route_index)
		for side: float in [-1.0, 1.0]:
			for building_index in range(3):
				var distance: float = 16.0 + float(building_index) * 8.0
				var height: float = 9.0 + float((route_index + building_index) % 4) * 3.0
				var origin: Vector3 = center + right * side * distance + Vector3(0.0, height * 0.5 - 0.2, float(building_index - 1) * 9.0)
				var building := Transform3D(Basis.IDENTITY, origin)
				building.basis = building.basis.scaled(Vector3(7.0, height, 7.0))
				buildings.append(building)
				var sign := Transform3D(Basis.IDENTITY, origin - right * side * 3.7 + Vector3.UP * 1.2)
				sign.basis = sign.basis.scaled(Vector3(2.4, 1.0, 0.12))
				if (route_index + building_index) % 2 == 0:
					cyan.append(sign)
				else:
					magenta.append(sign)
				for window_index in range(3):
					var win := Transform3D(Basis.IDENTITY, origin + Vector3(0.0, -2.0 + float(window_index) * 2.2, -3.58))
					win.basis = win.basis.scaled(Vector3(3.8, 0.45, 0.10))
					windows.append(win)
	_add_batch("NeonCityBuildings", buildings, _materials[&"building"])
	_add_batch("NeonCyanSigns", cyan, _materials[&"cyan"])
	_add_batch("NeonMagentaSigns", magenta, _materials[&"magenta"])
	_add_batch("NeonBuildingWindows", windows, _materials[&"window"])

func _build_chicane() -> void:
	var barriers: Array[Transform3D] = []
	for segment_index in [22, 23]:
		var a: Vector3 = ROUTE_POINTS[segment_index]
		var b: Vector3 = ROUTE_POINTS[segment_index + 1]
		var width: float = SEGMENT_WIDTHS[segment_index]
		for sample_index in range(3):
			var t: float = 0.30 + float(sample_index) * 0.22
			var side: float = -1.0 if sample_index % 2 == 0 else 1.0
			barriers.append(_track_xform(a, b, t, side * (width * 0.5 - 1.05), 0.55, Vector3(0.70, 1.10, 4.2)))
	_add_batch("ShipyardChicaneBarriers", barriers, _materials[&"warning"])

func _build_shortcut() -> void:
	var a: Vector3 = ROUTE_POINTS[SHORTCUT_A_SKIP_ROUTE_INDEX - 1]
	var b: Vector3 = ROUTE_POINTS[SHORTCUT_A_SKIP_ROUTE_INDEX + 1]
	var width := 6.0
	_add_batch("HarborShortcutRoads", [_track_xform(a, b, 0.5, 0.0, -0.16, Vector3(width, 0.42, a.distance_to(b)))], _materials[&"concrete"])
	_add_collision_box("ShortcutA", a, b, width, 0.42, -0.16, 0.0)

func _build_dynamic_obstacles() -> void:
	_create_dynamic_barrier("CargoBarrier", ROUTE_POINTS[7].lerp(ROUTE_POINTS[8], 0.55), 5.5, 1.05, 3.8)
	_create_dynamic_barrier("WarehouseGate", ROUTE_POINTS[21].lerp(ROUTE_POINTS[22], 0.58), 4.6, 1.20, 3.2)

func _build_street_lights() -> void:
	var posts: Array[Transform3D] = []
	var lamps: Array[Transform3D] = []
	for segment_index in [0, 1, 2, 8, 9, 10, 19, 20, 21, 24]:
		var a: Vector3 = ROUTE_POINTS[segment_index]
		var b: Vector3 = ROUTE_POINTS[segment_index + 1]
		var width: float = SEGMENT_WIDTHS[segment_index]
		for t: float in [0.24, 0.52, 0.80]:
			for side: float in [-1.0, 1.0]:
				posts.append(_track_xform(a, b, t, side * (width * 0.5 + 1.6), 2.1, Vector3(0.16, 4.2, 0.16)))
				lamps.append(_track_xform(a, b, t, side * (width * 0.5 + 1.25), 4.15, Vector3(0.85, 0.18, 0.36)))
	_add_batch("StreetLightPosts", posts, _materials[&"metal"])
	_add_batch("StreetLampGlow", lamps, _materials[&"window"])

func _create_dynamic_barrier(node_name: String, position: Vector3, width: float, speed: float, amplitude: float) -> void:
	var body := AnimatableBody3D.new()
	body.name = node_name
	body.set_script(DYNAMIC_OBSTACLE_SCRIPT)
	body.set("motion_type", WildDashDynamicObstacle.MotionType.SWEEP)
	body.set("motion_speed", speed)
	body.set("amplitude", amplitude)
	body.position = position + Vector3.UP * 1.15
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

func _add_rail_collision(index: int, a: Vector3, b: Vector3, width: float) -> void:
	for side: float in [-1.0, 1.0]:
		_add_collision_box("Rail_%02d_%s" % [index, "L" if side < 0.0 else "R"], a, b, 0.45, 1.55, 0.72, side * (width * 0.5 + 0.45))

func _add_collision_box(node_name: String, a: Vector3, b: Vector3, width: float, height: float, vertical: float, lateral: float) -> void:
	var direction: Vector3 = b - a
	var right: Vector3 = _right(a, b)
	var collision := CSGBox3D.new()
	collision.name = node_name
	collision.size = Vector3(width, height, a.distance_to(b))
	collision.use_collision = true
	collision.visible = false
	collision.position = (a + b) * 0.5 + right * lateral + Vector3.UP * vertical
	_collision_root.add_child(collision)
	collision.look_at(b + right * lateral + Vector3.UP * vertical, Vector3.UP)

func _shortcut_saving(skip_index: int) -> float:
	var a: Vector3 = ROUTE_POINTS[skip_index - 1]
	var middle: Vector3 = ROUTE_POINTS[skip_index]
	var b: Vector3 = ROUTE_POINTS[skip_index + 1]
	return a.distance_to(middle) + middle.distance_to(b) - a.distance_to(b)

func _segment_right(index: int) -> Vector3:
	return _right(ROUTE_POINTS[index], ROUTE_POINTS[index + 1])

func _right(a: Vector3, b: Vector3) -> Vector3:
	var direction: Vector3 = b - a
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return Vector3.RIGHT
	direction = direction.normalized()
	return Vector3(-direction.z, 0.0, direction.x)

func _track_xform(a: Vector3, b: Vector3, t: float, lateral: float, vertical: float, size: Vector3) -> Transform3D:
	var direction: Vector3 = b - a
	var origin: Vector3 = a.lerp(b, t) + _right(a, b) * lateral + Vector3.UP * vertical
	var xform := Transform3D(Basis.IDENTITY, origin)
	xform = xform.looking_at(origin + direction.normalized(), Vector3.UP)
	xform.basis = xform.basis.scaled(size)
	return xform

func _add_batch(node_name: String, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
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

func _as_xforms(values: Array) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for value in values:
		if value is Transform3D:
			result.append(value)
	return result

func _mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _emissive(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := _mat(color, 0.42, 0.18)
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material

func _count_nodes_recursive(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes_recursive(child)
	return count
