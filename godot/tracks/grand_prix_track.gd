class_name WildDashGrandPrixTrack
extends Node3D

const CHECKPOINT_SCRIPT: Script = preload("res://tracks/checkpoint.gd")
const FINISH_SCRIPT: Script = preload("res://tracks/finish_line.gd")

# Main safe route. Two physical shortcut roads bypass route point 19 and 24.
# The authoritative safe route stays continuous so rank/checkpoint projection
# remains deterministic regardless of which optional line a racer chooses.
const ROUTE_POINTS: Array[Vector3] = [
	Vector3(0, 0, 80),
	Vector3(0, 0, -64),
	Vector3(-44, 0, -144),
	Vector3(-68, 1, -224),
	Vector3(-32, 3, -304),
	Vector3(32, 5, -384),
	Vector3(72, 6, -456),
	Vector3(40, 3, -528),
	Vector3(-28, 4, -600),
	Vector3(-80, 7, -664),
	Vector3(-52, 3, -744),
	Vector3(8, -2, -824),
	Vector3(68, -4, -888),
	Vector3(84, -2, -952),
	Vector3(44, 0, -1016),
	Vector3(-16, 2, -1072),
	Vector3(-68, 2, -1128),
	Vector3(-32, 3, -1192),
	Vector3(24, 2, -1248),
	Vector3(80, 2, -1296),
	Vector3(16, 1, -1352),
	Vector3(-44, 0, -1416),
	Vector3(-80, 0, -1480),
	Vector3(-36, 0, -1536),
	Vector3(40, 0, -1592),
	Vector3(-12, 0, -1652),
	Vector3(44, 0, -1728),
	Vector3(0, 0, -1808),
]

const SEGMENT_WIDTHS: Array[float] = [
	18, 18, 14, 14, 13, 9, 16, 15, 12, 14, 15, 17, 10, 14,
	15, 13, 14, 13, 17, 16, 14, 12, 13, 17, 16, 15, 18,
]
const SEGMENT_NAMES: Array[String] = [
	"Meadow Sprint", "First Bend", "Forest Entry", "Forest Run", "Uphill Jump",
	"Narrow Bridge", "Obstacle Field", "Canyon Entry", "Cliff Turn", "Long Downhill",
	"River Approach", "River Bridge", "Moving Gate", "Spiral Entry", "Spiral Apex",
	"Spiral Exit", "Multi Jump", "Shortcut A Entry", "Safe Detour A", "A Merge Brawl",
	"Tunnel", "Technical S", "Shortcut B Entry", "Safe Detour B", "B Merge",
	"Final Technical", "Final Straight",
]
const CHECKPOINT_ROUTE_INDICES: Array[int] = [2, 4, 6, 8, 10, 12, 14, 17, 20, 22, 26]

const SHORTCUT_A_ENTRY := 18
const SHORTCUT_A_DETOUR := 19
const SHORTCUT_A_EXIT := 20
const SHORTCUT_B_ENTRY := 23
const SHORTCUT_B_DETOUR := 24
const SHORTCUT_B_EXIT := 25

var _track_length := 0.0
var _road_material: StandardMaterial3D
var _rail_material: StandardMaterial3D
var _marker_material: StandardMaterial3D
var _obstacle_material: StandardMaterial3D
var _shortcut_material: StandardMaterial3D
var _cliff_material: StandardMaterial3D
var _water_material: StandardMaterial3D

func _ready() -> void:
	_road_material = _make_material(Color(0.12, 0.17, 0.24), 0.92)
	_rail_material = _make_material(Color(0.16, 0.76, 0.84), 0.65)
	_marker_material = _make_material(Color(0.9, 1.0, 0.18), 0.55, true)
	_obstacle_material = _make_material(Color(1.0, 0.28, 0.42), 0.72)
	_shortcut_material = _make_material(Color(0.24, 0.45, 0.29), 0.88)
	_cliff_material = _make_material(Color(0.28, 0.20, 0.15), 0.96)
	_water_material = _make_material(Color(0.05, 0.32, 0.56), 0.35)
	_build_track()
	RaceManager.configure_track(get_route_points(), get_checkpoint_positions())
	print("GRAND PRIX TRACK READY route_points=%d checkpoints=%d length=%.1fm shortcuts=2" % [
		ROUTE_POINTS.size(), CHECKPOINT_ROUTE_INDICES.size(), _track_length,
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
	return _shortcut_saving(SHORTCUT_A_ENTRY, SHORTCUT_A_DETOUR, SHORTCUT_A_EXIT)

func get_shortcut_b_saving() -> float:
	return _shortcut_saving(SHORTCUT_B_ENTRY, SHORTCUT_B_DETOUR, SHORTCUT_B_EXIT)

func get_shortcut_route(use_a: bool, use_b: bool) -> Array[Vector3]:
	var route: Array[Vector3] = []
	for i in range(ROUTE_POINTS.size()):
		if use_a and i == SHORTCUT_A_DETOUR:
			continue
		if use_b and i == SHORTCUT_B_DETOUR:
			continue
		route.append(ROUTE_POINTS[i])
	return route

func _shortcut_saving(entry: int, detour: int, exit_index: int) -> float:
	var a := ROUTE_POINTS[entry]
	var d := ROUTE_POINTS[detour]
	var b := ROUTE_POINTS[exit_index]
	return maxf(0.0, a.distance_to(d) + d.distance_to(b) - a.distance_to(b))

func _build_track() -> void:
	_track_length = 0.0
	for i in range(ROUTE_POINTS.size() - 1):
		var a := ROUTE_POINTS[i]
		var b := ROUTE_POINTS[i + 1]
		var width := SEGMENT_WIDTHS[i]
		_track_length += a.distance_to(b)
		_create_segment("Road_%02d_%s" % [i, SEGMENT_NAMES[i].replace(" ", "_")], a, b, width, 0.5, _road_material, true, -0.22)
		# The two shortcut entries intentionally open onto exposed optional lanes.
		if i not in [SHORTCUT_A_ENTRY, SHORTCUT_B_ENTRY]:
			_create_guardrails(i, a, b, width)

	_build_start_line()
	_build_checkpoints()
	_build_finish_line()
	_build_static_obstacles()
	_build_dynamic_obstacles()
	_build_forest_dressing()
	_build_canyon_cliff()
	_build_river_bridge_details()
	_build_multi_jump()
	_build_tunnel()
	_build_shortcuts()
	_build_finish_runoff()

func _create_segment(node_name: String, a: Vector3, b: Vector3, width: float, height: float, material: Material, collision: bool, vertical_offset := 0.0) -> CSGBox3D:
	var segment := CSGBox3D.new()
	segment.name = node_name
	segment.size = Vector3(width, height, a.distance_to(b))
	segment.use_collision = collision
	segment.material = material
	segment.position = (a + b) * 0.5 + Vector3.UP * vertical_offset
	add_child(segment)
	segment.look_at(b + Vector3.UP * vertical_offset, Vector3.UP)
	return segment

func _create_guardrails(index: int, a: Vector3, b: Vector3, width: float) -> void:
	var planar := b - a
	planar.y = 0.0
	if planar.length_squared() < 0.01:
		return
	var direction := planar.normalized()
	var right := Vector3(-direction.z, 0.0, direction.x)
	var midpoint := (a + b) * 0.5 + Vector3.UP * 0.65
	for side in [-1.0, 1.0]:
		var rail := CSGBox3D.new()
		rail.name = "Rail_%02d_%s" % [index, "L" if side < 0.0 else "R"]
		rail.size = Vector3(0.35, 1.35, a.distance_to(b))
		rail.use_collision = true
		rail.material = _rail_material
		rail.position = midpoint + right * (width * 0.5 + 0.2) * side
		add_child(rail)
		rail.look_at(b + right * (width * 0.5 + 0.2) * side + Vector3.UP * 0.65, Vector3.UP)

func _build_start_line() -> void:
	_create_marker("StartLine", ROUTE_POINTS[0], ROUTE_POINTS[1], SEGMENT_WIDTHS[0])

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
		area.position = point + Vector3.UP * 1.7
		area.collision_mask = 2
		add_child(area)
		area.look_at(next_point + Vector3.UP * 1.7, Vector3.UP)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(width + 2.0, 4.2, 7.0)
		shape.shape = box
		area.add_child(shape)
		_create_marker("CheckpointStripe_%02d" % (checkpoint_index + 1), point, next_point, width)

func _build_finish_line() -> void:
	var finish := ROUTE_POINTS[ROUTE_POINTS.size() - 1]
	var previous := ROUTE_POINTS[ROUTE_POINTS.size() - 2]
	var direction := (finish - previous).normalized()
	var next_point := finish + direction * 8.0
	var area := Area3D.new()
	area.name = "FinishLine"
	area.set_script(FINISH_SCRIPT)
	area.position = finish + Vector3.UP * 1.8
	area.collision_mask = 2
	add_child(area)
	area.look_at(next_point + Vector3.UP * 1.8, Vector3.UP)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SEGMENT_WIDTHS[SEGMENT_WIDTHS.size() - 1] + 2.0, 4.2, 7.0)
	shape.shape = box
	area.add_child(shape)
	_create_marker("FinishStripe", finish, next_point, SEGMENT_WIDTHS[SEGMENT_WIDTHS.size() - 1])

func _create_marker(node_name: String, point: Vector3, look_target: Vector3, width: float) -> void:
	var marker := CSGBox3D.new()
	marker.name = node_name
	marker.size = Vector3(width, 0.07, 1.2)
	marker.use_collision = false
	marker.material = _marker_material
	marker.position = point + Vector3.UP * 0.04
	add_child(marker)
	marker.look_at(look_target + Vector3.UP * 0.04, Vector3.UP)

func _build_static_obstacles() -> void:
	_add_static_box("ForestBlockA", ROUTE_POINTS[3] + Vector3(3.0, 1.0, 0), Vector3(2.2, 2.0, 2.2))
	_add_static_box("ForestBlockB", ROUTE_POINTS[4] + Vector3(-3.0, 0.8, -8), Vector3(2.0, 1.6, 2.6))
	_add_static_box("ObstacleFieldA", ROUTE_POINTS[7] + Vector3(-4.0, 0.9, 2.0), Vector3(2.4, 1.8, 2.4))
	_add_static_box("ObstacleFieldB", ROUTE_POINTS[7] + Vector3(4.2, 0.8, -7.0), Vector3(2.8, 1.6, 2.2))
	_add_static_box("SpiralBollard", ROUTE_POINTS[15] + Vector3(0, 1.1, 0), Vector3(2.6, 2.2, 2.6))
	_add_static_box("TechnicalS_A", ROUTE_POINTS[22] + Vector3(-3.8, 0.8, 4), Vector3(2.2, 1.6, 3.0))
	_add_static_box("FinalChicaneA", ROUTE_POINTS[26] + Vector3(-4.4, 0.8, 8), Vector3(2.2, 1.6, 3.0))
	_add_static_box("FinalChicaneB", ROUTE_POINTS[26] + Vector3(4.4, 0.8, -7), Vector3(2.2, 1.6, 3.0))

func _add_static_box(node_name: String, world_position: Vector3, size: Vector3) -> void:
	var obstacle := CSGBox3D.new()
	obstacle.name = node_name
	obstacle.position = world_position
	obstacle.size = size
	obstacle.use_collision = true
	obstacle.material = _obstacle_material
	add_child(obstacle)

func _build_dynamic_obstacles() -> void:
	_add_dynamic_box("RotatingSweeper", ROUTE_POINTS[7] + Vector3.UP * 1.0, Vector3(10.0, 0.65, 0.8), WildDashDynamicObstacle.MotionType.ROTATE, 1.35, 0.0)
	_add_dynamic_box("CanyonSweeper", ROUTE_POINTS[9] + Vector3.UP * 0.9, Vector3(7.0, 0.6, 0.75), WildDashDynamicObstacle.MotionType.ROTATE, 1.18, 0.0)
	_add_dynamic_box("MovingGateA", ROUTE_POINTS[13] + Vector3.UP * 1.0, Vector3(3.0, 2.1, 0.9), WildDashDynamicObstacle.MotionType.SWEEP, 1.30, 4.0)
	_add_dynamic_box("MovingGateB", ROUTE_POINTS[14] + Vector3.UP * 1.0, Vector3(3.0, 2.1, 0.9), WildDashDynamicObstacle.MotionType.SWEEP, 1.05, 4.8)
	_add_dynamic_box("FinalSweeper", ROUTE_POINTS[26] + Vector3.UP * 0.9, Vector3(8.0, 0.55, 0.7), WildDashDynamicObstacle.MotionType.ROTATE, 1.45, 0.0)

func _add_dynamic_box(node_name: String, world_position: Vector3, size: Vector3, motion: WildDashDynamicObstacle.MotionType, speed: float, amplitude: float) -> void:
	var body := WildDashDynamicObstacle.new()
	body.name = node_name
	body.position = world_position
	body.motion_type = motion
	body.motion_speed = speed
	body.amplitude = amplitude
	body.collision_layer = 1
	body.collision_mask = 2
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _obstacle_material
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _build_forest_dressing() -> void:
	var anchor := ROUTE_POINTS[3]
	for i in range(14):
		var side := -1.0 if i % 2 == 0 else 1.0
		var x_offset := 11.0 + float(i % 3) * 3.0
		var z_offset := float(i - 7) * 8.0
		var tree := CSGCylinder3D.new()
		tree.name = "ForestTree_%02d" % i
		tree.position = anchor + Vector3(side * x_offset, 2.5, z_offset)
		tree.radius = 0.7
		tree.height = 5.0
		tree.sides = 8
		tree.use_collision = false
		tree.material = _make_material(Color(0.12, 0.38, 0.18), 0.95)
		add_child(tree)

func _build_canyon_cliff() -> void:
	for route_index in [8, 9, 10]:
		var point := ROUTE_POINTS[route_index]
		for side in [-1.0, 1.0]:
			var cliff := CSGBox3D.new()
			cliff.name = "CanyonDecor_%02d_%s" % [route_index, "L" if side < 0.0 else "R"]
			cliff.position = point + Vector3(side * 17.0, -3.5, 0.0)
			cliff.size = Vector3(13.0, 10.0, 35.0)
			cliff.use_collision = false
			cliff.material = _cliff_material
			add_child(cliff)

func _build_river_bridge_details() -> void:
	var a := ROUTE_POINTS[11]
	var b := ROUTE_POINTS[12]
	var midpoint := (a + b) * 0.5
	var river := CSGBox3D.new()
	river.name = "GrandRiver"
	river.position = Vector3(midpoint.x, -7.0, midpoint.z)
	river.size = Vector3(125, 0.3, 125)
	river.use_collision = false
	river.material = _water_material
	add_child(river)

func _build_multi_jump() -> void:
	# Three low ramps give Rabbit a natural Spring Leap line, while every racer
	# can still clear them at normal speed or use Recovery Feather.
	var a := ROUTE_POINTS[16]
	var b := ROUTE_POINTS[17]
	for ratio in [0.25, 0.50, 0.75]:
		var point := a.lerp(b, float(ratio))
		var ramp := CSGBox3D.new()
		ramp.name = "MultiJump_%02d" % int(float(ratio) * 100.0)
		ramp.position = point + Vector3.UP * 0.25
		ramp.size = Vector3(8.5, 0.5, 5.0)
		ramp.rotation_degrees.x = -9.0
		ramp.use_collision = true
		ramp.material = _marker_material
		add_child(ramp)

func _build_tunnel() -> void:
	var a := ROUTE_POINTS[20]
	var b := ROUTE_POINTS[21]
	var midpoint := (a + b) * 0.5
	var planar := b - a
	planar.y = 0.0
	var direction := planar.normalized()
	var right := Vector3(-direction.z, 0.0, direction.x)
	var length := a.distance_to(b)
	for side in [-1.0, 1.0]:
		var wall := CSGBox3D.new()
		wall.name = "TunnelWall_%s" % ("L" if side < 0.0 else "R")
		wall.size = Vector3(0.6, 5.0, length)
		wall.position = midpoint + right * 6.0 * side + Vector3.UP * 2.0
		wall.use_collision = true
		wall.material = _rail_material
		add_child(wall)
		wall.look_at(b + right * 6.0 * side + Vector3.UP * 2.0, Vector3.UP)
	var roof := CSGBox3D.new()
	roof.name = "TunnelRoof"
	roof.size = Vector3(12.5, 0.6, length)
	roof.position = midpoint + Vector3.UP * 4.6
	roof.use_collision = true
	roof.material = _rail_material
	add_child(roof)
	roof.look_at(b + Vector3.UP * 4.6, Vector3.UP)

func _build_shortcuts() -> void:
	var a1 := ROUTE_POINTS[SHORTCUT_A_ENTRY]
	var b1 := ROUTE_POINTS[SHORTCUT_A_EXIT]
	_create_segment("RiskyShortcutA", a1, b1, 6.2, 0.42, _shortcut_material, true, -0.18)
	_add_dynamic_box("ShortcutASweeper", (a1 + b1) * 0.5 + Vector3.UP * 0.8, Vector3(5.2, 0.55, 0.7), WildDashDynamicObstacle.MotionType.ROTATE, 1.65, 0.0)

	var a2 := ROUTE_POINTS[SHORTCUT_B_ENTRY]
	var b2 := ROUTE_POINTS[SHORTCUT_B_EXIT]
	_create_segment("ComebackShortcutB", a2, b2, 6.8, 0.42, _shortcut_material, true, -0.18)
	_add_dynamic_box("ShortcutBGate", (a2 + b2) * 0.5 + Vector3.UP * 0.9, Vector3(2.5, 1.8, 0.8), WildDashDynamicObstacle.MotionType.SWEEP, 1.25, 2.8)

func _build_finish_runoff() -> void:
	var finish := ROUTE_POINTS[ROUTE_POINTS.size() - 1]
	var previous := ROUTE_POINTS[ROUTE_POINTS.size() - 2]
	var direction := (finish - previous).normalized()
	_create_segment("FinishRunoff", finish, finish + direction * 30.0, 18.0, 0.5, _road_material, true, -0.22)

func _make_material(color: Color, roughness: float, emission := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emission:
		material.emission_enabled = true
		material.emission = color * 0.45
	return material
