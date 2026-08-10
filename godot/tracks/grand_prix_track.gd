class_name WildDashGrandPrixTrack
extends Node3D

const CHECKPOINT_SCRIPT: Script = preload("res://tracks/checkpoint.gd")
const FINISH_SCRIPT: Script = preload("res://tracks/finish_line.gd")

const ROUTE_POINTS: Array[Vector3] = [
	Vector3(0, 0, 80),
	Vector3(0, 0, 0),
	Vector3(-45, 0, -70),
	Vector3(-70, 0, -150),
	Vector3(-40, 6, -220),
	Vector3(20, 6, -285),
	Vector3(80, 2, -350),
	Vector3(134, 4, -408),
	Vector3(187, 7, -474),
	Vector3(154, 9, -544),
	Vector3(92, 5, -598),
	Vector3(55, 4, -664),
	Vector3(39, -8, -754),
	Vector3(2, -21, -849),
	Vector3(-44, -24, -911),
	Vector3(6, -23, -985),
	Vector3(59, -18, -1051),
	Vector3(190, -15, -1090),
	Vector3(167, -11, -1150),
	Vector3(138, -8, -1216),
	Vector3(72, -6, -1245),
	Vector3(18, -3, -1307),
	Vector3(-31, 1, -1373),
	Vector3(-85, 2, -1431),
	Vector3(-140, 4, -1510),
	Vector3(-64, 0, -1567),
	Vector3(-2, -1, -1633),
	Vector3(59, 0, -1695),
	Vector3(35, 0, -1769),
	Vector3(14, 0, -1852),
]

const SEGMENT_WIDTHS: Array[float] = [
	18, 18, 14, 14, 12, 8, 16, 14, 11, 10,
	18, 17, 18, 16, 10, 20, 18, 18, 22, 22,
	20, 15, 14, 13, 13, 12, 11, 12, 18,
]
const SEGMENT_NAMES: Array[String] = [
	"Meadow Straight", "First Bend", "Forest Run", "Uphill", "Jump Approach",
	"Narrow Bridge", "Obstacle Field", "Canyon Entry", "Cliff S Curve", "Canyon Squeeze",
	"Rally Straight", "Downhill Crest", "Long Downhill", "River Approach", "River Bridge",
	"Gate Approach", "Moving Gate Detour In", "Moving Gate Detour Out", "Spiral Entry", "Wide Hairpin",
	"Hairpin Exit", "Multi Jump Approach", "Multi Jump Ridge", "Shortcut B Detour In", "Shortcut B Detour Out",
	"Tunnel", "Final S Curve", "Final Chicane", "Final Straight",
]
const CHECKPOINT_ROUTE_INDICES: Array[int] = [2, 4, 6, 9, 12, 15, 18, 21, 23, 26, 28]
const RAIL_SEGMENT_INDICES: Array[int] = [0, 1, 2, 3, 4, 5, 7, 8, 9, 12, 14, 18, 19, 23, 25, 26, 27, 28]

const SHORTCUT_A_ENTRY_ROUTE_INDEX := 16
const SHORTCUT_A_SKIP_ROUTE_INDEX := 17
const SHORTCUT_A_EXIT_ROUTE_INDEX := 18
const SHORTCUT_B_ENTRY_ROUTE_INDEX := 23
const SHORTCUT_B_SKIP_ROUTE_INDEX := 24
const SHORTCUT_B_EXIT_ROUTE_INDEX := 25

var _track_length := 0.0
var _road_material: StandardMaterial3D
var _rail_material: StandardMaterial3D
var _marker_material: StandardMaterial3D
var _obstacle_material: StandardMaterial3D
var _shortcut_material: StandardMaterial3D
var _water_material: StandardMaterial3D
var _rock_material: StandardMaterial3D
var _decoration_root: Node3D
var _collision_root: Node3D

func _ready() -> void:
	_road_material = _make_material(Color(0.12, 0.17, 0.24), 0.92)
	_rail_material = _make_material(Color(0.16, 0.76, 0.84), 0.65)
	_marker_material = _make_material(Color(0.9, 1.0, 0.18), 0.55, true)
	_obstacle_material = _make_material(Color(1.0, 0.28, 0.42), 0.72)
	_shortcut_material = _make_material(Color(0.22, 0.42, 0.28), 0.9)
	_water_material = _make_material(Color(0.05, 0.32, 0.56), 0.35)
	_rock_material = _make_material(Color(0.32, 0.24, 0.19), 0.96)
	_build_track()
	RaceManager.configure_track(get_route_points(), get_checkpoint_positions())
	print("GRAND PRIX TRACK READY route_points=%d checkpoints=%d length=%.1fm nodes=%d" % [
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
	return _shortcut_saving(SHORTCUT_A_ENTRY_ROUTE_INDEX, SHORTCUT_A_SKIP_ROUTE_INDEX, SHORTCUT_A_EXIT_ROUTE_INDEX)

func get_shortcut_b_saving() -> float:
	return _shortcut_saving(SHORTCUT_B_ENTRY_ROUTE_INDEX, SHORTCUT_B_SKIP_ROUTE_INDEX, SHORTCUT_B_EXIT_ROUTE_INDEX)

func get_runtime_node_count() -> int:
	return _count_nodes_recursive(self)

func _build_track() -> void:
	_decoration_root = Node3D.new()
	_decoration_root.name = "DecorationGeometry"
	add_child(_decoration_root)
	_collision_root = Node3D.new()
	_collision_root.name = "GameplayCollision"
	add_child(_collision_root)

	_track_length = 0.0
	for i in range(ROUTE_POINTS.size() - 1):
		var a := ROUTE_POINTS[i]
		var b := ROUTE_POINTS[i + 1]
		var width := SEGMENT_WIDTHS[i]
		_track_length += a.distance_to(b)
		_create_segment(
			"Road_%02d_%s" % [i, SEGMENT_NAMES[i].replace(" ", "_")],
			a, b, width, 0.5, _road_material, true, -0.22
		)
		if RAIL_SEGMENT_INDICES.has(i):
			_create_guardrails(i, a, b, width)

	_build_start_line()
	_build_checkpoints()
	_build_finish_line()
	_build_static_obstacles()
	_build_dynamic_obstacles()
	_build_bridge_details()
	_build_canyon_section()
	_build_multi_jump()
	_build_tunnel()
	_build_shortcuts()
	_build_forest_dressing()

func _create_segment(
	node_name: String,
	a: Vector3,
	b: Vector3,
	width: float,
	height: float,
	material: Material,
	collision: bool,
	vertical_offset := 0.0
) -> CSGBox3D:
	var segment := CSGBox3D.new()
	segment.name = node_name
	segment.size = Vector3(width, height, a.distance_to(b))
	segment.use_collision = collision
	segment.material = material
	segment.position = (a + b) * 0.5 + Vector3.UP * vertical_offset
	_collision_root.add_child(segment)
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
		_collision_root.add_child(rail)
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
		box.size = Vector3(width + 1.5, 4.0, 6.0)
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
	box.size = Vector3(SEGMENT_WIDTHS[SEGMENT_WIDTHS.size() - 1] + 1.5, 4.2, 7.0)
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
	_decoration_root.add_child(marker)
	marker.look_at(look_target + Vector3.UP * 0.04, Vector3.UP)

func _build_static_obstacles() -> void:
	_add_static_box("ForestBlockA", ROUTE_POINTS[3] + Vector3(3.2, 1.0, 0), Vector3(2.4, 2.0, 2.4))
	_add_static_box("ForestBlockB", ROUTE_POINTS[3] + Vector3(-3.0, 0.8, -12), Vector3(2.0, 1.6, 3.0))
	_add_static_box("ObstacleFieldA", ROUTE_POINTS[6] + Vector3(-4.0, 0.9, 2.0), Vector3(2.4, 1.8, 2.4))
	_add_static_box("ObstacleFieldB", ROUTE_POINTS[6] + Vector3(3.6, 0.7, -8.0), Vector3(3.0, 1.4, 2.2))
	# Wide hairpin stays collision-heavy enough for Elephant Stampede body battles.
	_add_static_box("HairpinIsland", ROUTE_POINTS[19] + Vector3(6.0, 1.4, -3.0), Vector3(4.2, 2.8, 4.2))
	# Cat's late technical section rewards precise Shadow Step without making it mandatory.
	_add_static_box("FinalChicaneA", ROUTE_POINTS[27] + Vector3(-3.3, 0.8, 7.0), Vector3(2.2, 1.6, 3.0))
	_add_static_box("FinalChicaneB", ROUTE_POINTS[27] + Vector3(3.3, 0.8, -5.0), Vector3(2.2, 1.6, 3.0))

func _add_static_box(node_name: String, world_position: Vector3, size: Vector3) -> void:
	var obstacle := CSGBox3D.new()
	obstacle.name = node_name
	obstacle.position = world_position
	obstacle.size = size
	obstacle.use_collision = true
	obstacle.material = _obstacle_material
	_collision_root.add_child(obstacle)

func _build_dynamic_obstacles() -> void:
	_add_dynamic_box(
		"RotatingSweeper", ROUTE_POINTS[6] + Vector3.UP * 1.0, Vector3(10.0, 0.65, 0.8),
		WildDashDynamicObstacle.MotionType.ROTATE, 1.35, 0.0
	)
	# Three staggered gates create a readable timing section rather than a wall.
	_add_dynamic_box(
		"MovingGateA", ROUTE_POINTS[16] + Vector3.UP * 1.1, Vector3(3.2, 2.2, 0.9),
		WildDashDynamicObstacle.MotionType.SWEEP, 1.15, 5.2
	)
	_add_dynamic_box(
		"MovingGateB", ROUTE_POINTS[17] + Vector3.UP * 1.1, Vector3(3.6, 2.4, 0.9),
		WildDashDynamicObstacle.MotionType.SWEEP, 1.30, 6.0
	)
	_add_dynamic_box(
		"MovingGateC", ROUTE_POINTS[18] + Vector3.UP * 1.0, Vector3(3.0, 2.0, 0.9),
		WildDashDynamicObstacle.MotionType.SWEEP, 1.45, 4.8
	)

func _add_dynamic_box(
	node_name: String,
	world_position: Vector3,
	size: Vector3,
	motion: WildDashDynamicObstacle.MotionType,
	speed: float,
	amplitude: float
) -> void:
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
	_collision_root.add_child(body)

func _build_bridge_details() -> void:
	# Existing forest bridge river.
	var first_midpoint := (ROUTE_POINTS[5] + ROUTE_POINTS[6]) * 0.5
	_add_visual_box(
		"BridgeRiver", Vector3(first_midpoint.x, -5.0, first_midpoint.z),
		Vector3(95, 0.3, 95), _water_material
	)
	# New long-race river crossing.
	var river_midpoint := (ROUTE_POINTS[14] + ROUTE_POINTS[15]) * 0.5
	_add_visual_box(
		"LongRiver", Vector3(river_midpoint.x, -28.0, river_midpoint.z),
		Vector3(140, 0.35, 125), _water_material
	)

func _build_canyon_section() -> void:
	# Decorative cliff masses are one MultiMesh and carry no collision.
	# Gameplay boundaries remain the simplified rails under GameplayCollision.
	var rock_mesh := BoxMesh.new()
	rock_mesh.size = Vector3(8.0, 14.0, 8.0)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = rock_mesh
	multimesh.instance_count = 14
	for i in range(multimesh.instance_count):
		var anchor_index := 7 + (i % 4)
		var anchor := ROUTE_POINTS[anchor_index]
		var side := -1.0 if i % 2 == 0 else 1.0
		var scale_y := 0.75 + float(i % 4) * 0.16
		var basis := Basis.IDENTITY.scaled(Vector3(1.0, scale_y, 1.0))
		var position := anchor + Vector3(side * (14.0 + float(i % 3) * 5.0), 2.0 + scale_y * 4.0, float(i - 7) * 3.0)
		multimesh.set_instance_transform(i, Transform3D(basis, position))
	var instance := MultiMeshInstance3D.new()
	instance.name = "CanyonCliffDressing"
	instance.multimesh = multimesh
	instance.material_override = _rock_material
	_decoration_root.add_child(instance)

func _build_multi_jump() -> void:
	# Low hurdles make the normal jump viable while Rabbit can clear them with
	# Spring Leap and maintain more speed. They are intentionally not character locked.
	for i in range(3):
		var anchor_index := 21 + mini(i, 1)
		var a := ROUTE_POINTS[anchor_index]
		var b := ROUTE_POINTS[anchor_index + 1]
		var t := 0.28 + float(i) * 0.23
		var point := a.lerp(b, clampf(t, 0.15, 0.82))
		var tangent := b - a
		tangent.y = 0.0
		var hurdle := CSGBox3D.new()
		hurdle.name = "MultiJumpHurdle_%02d" % (i + 1)
		hurdle.size = Vector3(7.2, 0.65 + float(i) * 0.12, 0.85)
		hurdle.position = point + Vector3.UP * 0.22
		hurdle.use_collision = true
		hurdle.material = _obstacle_material
		_collision_root.add_child(hurdle)
		hurdle.look_at(point + tangent.normalized() * 5.0 + Vector3.UP * 0.22, Vector3.UP)

func _build_tunnel() -> void:
	var a := ROUTE_POINTS[25]
	var b := ROUTE_POINTS[26]
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
		_collision_root.add_child(wall)
		wall.look_at(b + right * 6.0 * side + Vector3.UP * 2.0, Vector3.UP)
	var roof := CSGBox3D.new()
	roof.name = "TunnelRoof"
	roof.size = Vector3(12.5, 0.6, length)
	roof.position = midpoint + Vector3.UP * 4.6
	roof.use_collision = true
	roof.material = _rail_material
	_collision_root.add_child(roof)
	roof.look_at(b + Vector3.UP * 4.6, Vector3.UP)

func _build_shortcuts() -> void:
	var a_entry := ROUTE_POINTS[SHORTCUT_A_ENTRY_ROUTE_INDEX]
	var a_exit := ROUTE_POINTS[SHORTCUT_A_EXIT_ROUTE_INDEX]
	_create_segment("ShortcutA_RiskyMid", a_entry, a_exit, 6.2, 0.42, _shortcut_material, true, -0.18)
	_add_dynamic_box(
		"ShortcutASweeper", (a_entry + a_exit) * 0.5 + Vector3.UP * 0.8,
		Vector3(5.0, 0.55, 0.7), WildDashDynamicObstacle.MotionType.ROTATE, 1.8, 0.0
	)

	var b_entry := ROUTE_POINTS[SHORTCUT_B_ENTRY_ROUTE_INDEX]
	var b_exit := ROUTE_POINTS[SHORTCUT_B_EXIT_ROUTE_INDEX]
	_create_segment("ShortcutB_ComebackLine", b_entry, b_exit, 5.8, 0.42, _shortcut_material, true, -0.18)
	# A low hurdle keeps the second shortcut skill/item-friendly rather than Rabbit-only.
	var midpoint := (b_entry + b_exit) * 0.5
	_add_static_box("ShortcutBJumpBlock", midpoint + Vector3.UP * 0.45, Vector3(4.5, 0.9, 1.0))

func _build_forest_dressing() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.55
	trunk_mesh.bottom_radius = 0.7
	trunk_mesh.height = 5.0
	trunk_mesh.radial_segments = 7
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = trunk_mesh
	multimesh.instance_count = 12
	var anchor := ROUTE_POINTS[3]
	for i in range(multimesh.instance_count):
		var side := -1.0 if i % 2 == 0 else 1.0
		var x_offset := 11.0 + float(i % 3) * 3.0
		var z_offset := float(i - 6) * 9.0
		var height_scale := 0.85 + float(i % 3) * 0.16
		var basis := Basis.IDENTITY.scaled(Vector3(1.0, height_scale, 1.0))
		multimesh.set_instance_transform(
			i,
			Transform3D(basis, anchor + Vector3(side * x_offset, 2.0, z_offset))
		)
	var trees := MultiMeshInstance3D.new()
	trees.name = "ForestTrees"
	trees.multimesh = multimesh
	trees.material_override = _make_material(Color(0.12, 0.46, 0.2), 0.95)
	_decoration_root.add_child(trees)

func _add_visual_box(node_name: String, world_position: Vector3, size: Vector3, material: Material) -> void:
	var visual := CSGBox3D.new()
	visual.name = node_name
	visual.position = world_position
	visual.size = size
	visual.use_collision = false
	visual.material = material
	_decoration_root.add_child(visual)

func _shortcut_saving(entry_index: int, skip_index: int, exit_index: int) -> float:
	var entry := ROUTE_POINTS[entry_index]
	var detour := ROUTE_POINTS[skip_index]
	var exit := ROUTE_POINTS[exit_index]
	var safe_distance := entry.distance_to(detour) + detour.distance_to(exit)
	var shortcut_distance := entry.distance_to(exit)
	return maxf(0.0, safe_distance - shortcut_distance)

func _count_nodes_recursive(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_nodes_recursive(child)
	return total

func _make_material(color: Color, roughness: float, emission := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emission:
		material.emission_enabled = true
		material.emission = color * 0.4
	return material
