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
	Vector3(125, 2, -410),
	Vector3(90, 0, -475),
	Vector3(20, 0, -500),
	Vector3(-45, -2, -545),
	Vector3(-95, -8, -625),
	Vector3(-45, -10, -710),
	Vector3(100, -6, -770),
	Vector3(55, -2, -900),
	Vector3(30, 0, -990),
	Vector3(0, 0, -1080),
]

const SEGMENT_WIDTHS: Array[float] = [18, 18, 14, 14, 12, 8, 15, 16, 13, 14, 12, 14, 17, 16, 15, 18]
const SEGMENT_NAMES: Array[String] = [
	"Meadow Straight", "First Bend", "Forest Run", "Uphill", "Jump Approach",
	"Narrow Bridge", "Obstacle Field", "S Curves", "Hairpin Entry", "Hairpin Exit",
	"Tunnel", "Downhill Rush", "Split Approach", "Safe Detour", "Merge Run", "Final Straight",
]
const CHECKPOINT_ROUTE_INDICES: Array[int] = [2, 4, 6, 8, 10, 12, 15]

var _track_length := 0.0
var _road_material: StandardMaterial3D
var _rail_material: StandardMaterial3D
var _marker_material: StandardMaterial3D
var _obstacle_material: StandardMaterial3D
var _shortcut_material: StandardMaterial3D

func _ready() -> void:
	_road_material = _make_material(Color(0.12, 0.17, 0.24), 0.92)
	_rail_material = _make_material(Color(0.16, 0.76, 0.84), 0.65)
	_marker_material = _make_material(Color(0.9, 1.0, 0.18), 0.55, true)
	_obstacle_material = _make_material(Color(1.0, 0.28, 0.42), 0.72)
	_shortcut_material = _make_material(Color(0.22, 0.42, 0.28), 0.9)
	_build_track()
	RaceManager.configure_track(get_route_points(), get_checkpoint_positions())
	print("GRAND PRIX TRACK READY route_points=%d checkpoints=%d length=%.1fm" % [ROUTE_POINTS.size(), CHECKPOINT_ROUTE_INDICES.size(), _track_length])

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

func _build_track() -> void:
	_track_length = 0.0
	for i in range(ROUTE_POINTS.size() - 1):
		var a := ROUTE_POINTS[i]
		var b := ROUTE_POINTS[i + 1]
		var width := SEGMENT_WIDTHS[i]
		_track_length += a.distance_to(b)
		_create_segment("Road_%02d_%s" % [i, SEGMENT_NAMES[i].replace(" ", "_")], a, b, width, 0.5, _road_material, true, -0.22)
		# The split approach intentionally opens into a cliff-side choice. The
		# narrow shortcut added below has no rails; the main route remains safe.
		if i != 12:
			_create_guardrails(i, a, b, width)

	_build_start_line()
	_build_checkpoints()
	_build_finish_line()
	_build_static_obstacles()
	_build_dynamic_obstacles()
	_build_bridge_details()
	_build_tunnel()
	_build_shortcut()
	_build_forest_dressing()

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
	var a := ROUTE_POINTS[0]
	var b := ROUTE_POINTS[1]
	_create_marker("StartLine", a, b, SEGMENT_WIDTHS[0])

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
	add_child(marker)
	marker.look_at(look_target + Vector3.UP * 0.04, Vector3.UP)

func _build_static_obstacles() -> void:
	_add_static_box("ForestBlockA", ROUTE_POINTS[3] + Vector3(3.2, 1.0, 0), Vector3(2.4, 2.0, 2.4))
	_add_static_box("ForestBlockB", ROUTE_POINTS[3] + Vector3(-3.0, 0.8, -12), Vector3(2.0, 1.6, 3.0))
	_add_static_box("ObstacleFieldA", ROUTE_POINTS[6] + Vector3(-4.0, 0.9, 2.0), Vector3(2.4, 1.8, 2.4))
	_add_static_box("ObstacleFieldB", ROUTE_POINTS[6] + Vector3(3.6, 0.7, -8.0), Vector3(3.0, 1.4, 2.2))
	_add_static_box("HairpinBollard", ROUTE_POINTS[9] + Vector3(0, 1.2, 0), Vector3(2.8, 2.4, 2.8))
	_add_static_box("FinalChicaneA", ROUTE_POINTS[15] + Vector3(-4.2, 0.8, 12), Vector3(2.2, 1.6, 3.0))
	_add_static_box("FinalChicaneB", ROUTE_POINTS[15] + Vector3(4.2, 0.8, -5), Vector3(2.2, 1.6, 3.0))

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
	_add_dynamic_box("MovingGate", ROUTE_POINTS[14] + Vector3.UP * 1.0, Vector3(3.2, 2.0, 0.9), WildDashDynamicObstacle.MotionType.SWEEP, 1.25, 4.2)

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

func _build_bridge_details() -> void:
	var a := ROUTE_POINTS[5]
	var b := ROUTE_POINTS[6]
	var midpoint := (a + b) * 0.5
	var river := CSGBox3D.new()
	river.name = "BridgeRiver"
	river.position = Vector3(midpoint.x, -5.0, midpoint.z)
	river.size = Vector3(95, 0.3, 95)
	river.use_collision = false
	river.material = _make_material(Color(0.05, 0.32, 0.56), 0.35)
	add_child(river)

func _build_tunnel() -> void:
	var a := ROUTE_POINTS[10]
	var b := ROUTE_POINTS[11]
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

func _build_shortcut() -> void:
	# Risk/reward branch: a narrow, exposed line cuts the long safe detour from
	# checkpoint 6 to the merge. It saves distance but offers almost no margin.
	var a := ROUTE_POINTS[12]
	var b := ROUTE_POINTS[14]
	_create_segment("RiskyShortcut", a, b, 5.5, 0.42, _shortcut_material, true, -0.18)
	_add_dynamic_box("ShortcutSweeper", (a + b) * 0.5 + Vector3.UP * 0.8, Vector3(5.0, 0.55, 0.7), WildDashDynamicObstacle.MotionType.ROTATE, 1.8, 0.0)

func _build_forest_dressing() -> void:
	var anchor := ROUTE_POINTS[3]
	for i in range(12):
		var side := -1.0 if i % 2 == 0 else 1.0
		var x_offset := 11.0 + float(i % 3) * 3.0
		var z_offset := float(i - 6) * 9.0
		var tree := CSGCylinder3D.new()
		tree.name = "ForestTree_%02d" % i
		tree.position = anchor + Vector3(side * x_offset, 2.0, z_offset)
		tree.radius = 0.6
		tree.height = 4.0 + float(i % 3)
		tree.sides = 7
		tree.use_collision = false
		tree.material = _make_material(Color(0.12, 0.42 + float(i % 2) * 0.08, 0.2), 0.95)
		add_child(tree)

func _make_material(color: Color, roughness: float, emission := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emission:
		material.emission_enabled = true
		material.emission = color * 0.4
	return material
