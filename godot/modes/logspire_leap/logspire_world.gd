extends Node3D

const ZONE_NAMES: Array[String] = [
	"FALLEN FOREST",
	"BROKEN BRIDGE",
	"ROLLING GROVE",
	"VINE CANYON",
	"TITAN TREE",
	"SKY LOG FINALE",
]

const ROUTE_SAFE: StringName = &"safe"
const ROUTE_WILD: StringName = &"wild"

var _platform_ids: Array[StringName] = []
var _platform_positions: Array[Vector3] = []
var _platform_sizes: Array[Vector3] = []
var _platform_zones: Array[int] = []
var _platform_route_ids: Array[StringName] = []
var _platform_risks: Array[float] = []
var _platform_shortcuts: Array[bool] = []
var _platform_recovery_targets: Array[StringName] = []
var _platform_index_by_id: Dictionary = {}

var _main_route_ids: Array[StringName] = []
var _wild_route_ids: Array[StringName] = []
var _checkpoint_ids: Array[StringName] = []
var _recovery_areas: Array[Area3D] = []
var _split_platform_id: StringName = &""
var _merge_platform_id: StringName = &""
var _finish_platform_id: StringName = &""
var _course_length: float = 0.0

var _zone_materials: Array[StandardMaterial3D] = []
var _recovery_material: StandardMaterial3D
var _trunk_material: StandardMaterial3D
var _finish_material: StandardMaterial3D

func _ready() -> void:
	_build_materials()
	_build_course_data()
	_build_course_geometry()
	_build_recovery_decks()
	_build_titan_tree_landmark()
	_course_length = _route_length(get_main_route_points())
	print("LOGSPIRE WORLD READY zones=%d platforms=%d safe_length=%.1fm wild_length=%.1fm checkpoints=%d recovery_decks=%d" % [
		ZONE_NAMES.size(),
		_platform_ids.size(),
		_course_length,
		_route_length(get_route_points(ROUTE_WILD)),
		_checkpoint_ids.size(),
		_recovery_areas.size(),
	])

func get_main_route_points() -> Array[Vector3]:
	return get_route_points(ROUTE_SAFE)

func get_route_points(route_id: StringName) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var ids: Array[StringName] = get_route_ids(route_id)
	for platform_id: StringName in ids:
		points.append(get_platform_position(platform_id))
	return points

func get_route_ids(route_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var source: Array[StringName] = _wild_route_ids if route_id == ROUTE_WILD else _main_route_ids
	for platform_id: StringName in source:
		result.append(platform_id)
	return result

func get_checkpoint_positions() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for platform_id: StringName in _checkpoint_ids:
		points.append(get_platform_position(platform_id))
	return points

func get_checkpoint_platform_id(index: int) -> StringName:
	if _checkpoint_ids.is_empty():
		return &""
	return _checkpoint_ids[clampi(index, 0, _checkpoint_ids.size() - 1)]

func get_start_position() -> Vector3:
	if _main_route_ids.is_empty():
		return Vector3.ZERO
	return get_platform_position(_main_route_ids[0]) + Vector3.UP * 1.15

func get_finish_position() -> Vector3:
	return get_platform_position(_finish_platform_id)

func get_course_length() -> float:
	return _course_length

func get_platform_count() -> int:
	return _platform_ids.size()

func get_platform_position(platform_id: StringName) -> Vector3:
	var index: int = int(_platform_index_by_id.get(platform_id, -1))
	if index < 0 or index >= _platform_positions.size():
		return Vector3.ZERO
	return _platform_positions[index]

func get_platform_zone(platform_id: StringName) -> int:
	var index: int = int(_platform_index_by_id.get(platform_id, -1))
	if index < 0 or index >= _platform_zones.size():
		return 0
	return _platform_zones[index]

func get_platform_landing_radius(platform_id: StringName) -> float:
	var index: int = int(_platform_index_by_id.get(platform_id, -1))
	if index < 0 or index >= _platform_sizes.size():
		return 4.0
	return maxf(3.0, _platform_sizes[index].x * 0.42)

func get_platform_risk(platform_id: StringName) -> float:
	var index: int = int(_platform_index_by_id.get(platform_id, -1))
	if index < 0 or index >= _platform_risks.size():
		return 0.0
	return _platform_risks[index]

func is_shortcut_platform(platform_id: StringName) -> bool:
	var index: int = int(_platform_index_by_id.get(platform_id, -1))
	return index >= 0 and index < _platform_shortcuts.size() and _platform_shortcuts[index]

func get_recovery_target(platform_id: StringName) -> StringName:
	var index: int = int(_platform_index_by_id.get(platform_id, -1))
	if index < 0 or index >= _platform_recovery_targets.size():
		return &""
	return _platform_recovery_targets[index]

func get_recovery_areas() -> Array[Area3D]:
	var result: Array[Area3D] = []
	for area: Area3D in _recovery_areas:
		result.append(area)
	return result

func get_zone_name_for_checkpoint_progress(checkpoint_progress: int) -> String:
	if checkpoint_progress <= 0:
		return ZONE_NAMES[0]
	if checkpoint_progress == 1:
		return ZONE_NAMES[1]
	if checkpoint_progress == 2:
		return ZONE_NAMES[2]
	if checkpoint_progress == 3:
		return ZONE_NAMES[3]
	if checkpoint_progress <= 5:
		return ZONE_NAMES[4]
	return ZONE_NAMES[5]

func get_zone_count() -> int:
	return ZONE_NAMES.size()

func get_safe_route_id() -> StringName:
	return ROUTE_SAFE

func get_wild_route_id() -> StringName:
	return ROUTE_WILD

func get_split_platform_id() -> StringName:
	return _split_platform_id

func get_merge_platform_id() -> StringName:
	return _merge_platform_id

func _build_materials() -> void:
	_zone_materials.clear()
	_zone_materials.append(_make_material(Color(0.24, 0.34, 0.18)))
	_zone_materials.append(_make_material(Color(0.34, 0.27, 0.16)))
	_zone_materials.append(_make_material(Color(0.43, 0.31, 0.17)))
	_zone_materials.append(_make_material(Color(0.34, 0.39, 0.18)))
	_zone_materials.append(_make_material(Color(0.55, 0.37, 0.16)))
	_zone_materials.append(_make_material(Color(0.64, 0.46, 0.22)))
	_recovery_material = _make_material(Color(0.12, 0.34, 0.31))
	_trunk_material = _make_material(Color(0.26, 0.15, 0.07))
	_finish_material = _make_material(Color(0.75, 0.52, 0.18))

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material

func _build_course_data() -> void:
	_platform_ids.clear()
	_platform_positions.clear()
	_platform_sizes.clear()
	_platform_zones.clear()
	_platform_route_ids.clear()
	_platform_risks.clear()
	_platform_shortcuts.clear()
	_platform_recovery_targets.clear()
	_platform_index_by_id.clear()
	_main_route_ids.clear()
	_wild_route_ids.clear()
	_checkpoint_ids.clear()

	var current := Vector3(0.0, 1.0, 0.0)
	_append_main_platform(&"START", current, Vector3(28.0, 1.0, 22.0), 0, 0.0)

	for i: int in range(1, 8):
		current = Vector3(sin(float(i) * 0.72) * 3.5, 1.0 + float(i) * 0.65, -15.0 * float(i))
		_append_main_platform(StringName("Z1_%02d" % i), current, Vector3(12.0, 0.8, 10.5), 0, 0.08)
	_checkpoint_ids.append(_main_route_ids[-1])

	var zone_start := current
	for i: int in range(1, 9):
		var lane_x: float = (-5.5 if i % 2 == 0 else 5.5) + sin(float(i) * 0.6) * 1.4
		current = Vector3(lane_x, zone_start.y + float(i), zone_start.z - 15.0 * float(i))
		_append_main_platform(StringName("Z2_%02d" % i), current, Vector3(9.5, 0.8, 10.0), 1, 0.18, _checkpoint_ids[0])
	_checkpoint_ids.append(_main_route_ids[-1])

	zone_start = current
	for i: int in range(1, 9):
		current = Vector3(sin(float(i) * 0.9) * 5.0, zone_start.y + float(i) * 0.85, zone_start.z - 16.0 * float(i))
		_append_main_platform(StringName("Z3_%02d" % i), current, Vector3(14.0, 0.8, 11.0), 2, 0.22, _checkpoint_ids[1])
	_checkpoint_ids.append(_main_route_ids[-1])

	_split_platform_id = _main_route_ids[-1]
	var split_position := current
	var safe_ids: Array[StringName] = []
	for i: int in range(1, 10):
		var safe_x: float = -8.0 + sin(float(i) * 1.05) * 13.0
		var safe_position := Vector3(
			safe_x,
			split_position.y + float(i),
			split_position.z - 16.0 * float(i)
		)
		var safe_id := StringName("Z4_SAFE_%02d" % i)
		_register_platform(safe_id, safe_position, Vector3(10.5, 0.8, 24.0), 3, ROUTE_SAFE, 0.20, false, _checkpoint_ids[2])
		safe_ids.append(safe_id)

	var merge_position := Vector3(0.0, split_position.y + 10.0, split_position.z - 160.0)
	_merge_platform_id = &"Z4_MERGE"
	_register_platform(_merge_platform_id, merge_position, Vector3(15.0, 0.8, 18.0), 3, ROUTE_SAFE, 0.10, false, _checkpoint_ids[2])
	for safe_id: StringName in safe_ids:
		_main_route_ids.append(safe_id)
	_main_route_ids.append(_merge_platform_id)

	var wild_only_ids: Array[StringName] = []
	for i: int in range(1, 8):
		var t: float = float(i) / 8.0
		var wild_position := split_position.lerp(merge_position, t)
		wild_position.x = 10.0 + sin(float(i) * 0.72) * 2.2
		var wild_id := StringName("Z4_WILD_%02d" % i)
		_register_platform(wild_id, wild_position, Vector3(7.0, 0.8, 15.5), 3, ROUTE_WILD, 0.62, true, _checkpoint_ids[2])
		wild_only_ids.append(wild_id)

	for platform_id: StringName in _main_route_ids:
		_wild_route_ids.append(platform_id)
		if platform_id == _split_platform_id:
			break
	for wild_id: StringName in wild_only_ids:
		_wild_route_ids.append(wild_id)
	_wild_route_ids.append(_merge_platform_id)
	_checkpoint_ids.append(_merge_platform_id)
	current = merge_position

	current = Vector3(0.0, current.y + 1.8, current.z - 22.0)
	_append_main_platform(&"Z5_APPROACH_01", current, Vector3(11.0, 0.8, 17.0), 4, 0.24, _checkpoint_ids[3])
	current = Vector3(0.0, current.y + 1.8, current.z - 24.0)
	_append_main_platform(&"Z5_APPROACH_02", current, Vector3(10.0, 0.8, 17.0), 4, 0.28, _checkpoint_ids[3])

	var titan_center := Vector3(0.0, 0.0, merge_position.z - 90.0)
	var spiral_ids: Array[StringName] = []
	for i: int in range(10):
		var angle: float = deg_to_rad(90.0 + float(i) * 42.0)
		var spiral_position := Vector3(
			titan_center.x + cos(angle) * 20.0,
			merge_position.y + 5.0 + float(i) * 2.2,
			titan_center.z + sin(angle) * 20.0
		)
		var spiral_id := StringName("Z5_SPIRAL_%02d" % (i + 1))
		_append_main_platform(spiral_id, spiral_position, Vector3(8.5, 0.8, 13.0), 4, 0.34, _checkpoint_ids[3])
		spiral_ids.append(spiral_id)
		current = spiral_position
	_checkpoint_ids.append(spiral_ids[5])

	var sky_start := Vector3(current.x * 0.35, current.y + 1.2, current.z - 18.0)
	_append_main_platform(&"Z6_START", sky_start, Vector3(11.0, 0.8, 14.0), 5, 0.28, _checkpoint_ids[4])
	_checkpoint_ids.append(&"Z6_START")
	current = sky_start

	for i: int in range(1, 8):
		current = Vector3(
			sin(float(i) * 0.8) * 3.0,
			sky_start.y + float(i) * 1.1,
			sky_start.z - 17.0 * float(i)
		)
		_append_main_platform(StringName("Z6_%02d" % i), current, Vector3(9.0, 0.8, 11.5), 5, 0.42, _checkpoint_ids[5])

	var finish_position := Vector3(0.0, current.y + 0.8, current.z - 18.0)
	_finish_platform_id = &"CROWN_NEST"
	_register_platform(_finish_platform_id, finish_position, Vector3(30.0, 1.0, 24.0), 5, ROUTE_SAFE, 0.0, false, _checkpoint_ids[5])
	_main_route_ids.append(_finish_platform_id)

	var merge_index: int = _main_route_ids.find(_merge_platform_id)
	if merge_index >= 0:
		for i: int in range(merge_index + 1, _main_route_ids.size()):
			_wild_route_ids.append(_main_route_ids[i])

func _append_main_platform(
	platform_id: StringName,
	position: Vector3,
	size: Vector3,
	zone: int,
	risk: float,
	recovery_target: StringName = &""
) -> void:
	_register_platform(platform_id, position, size, zone, ROUTE_SAFE, risk, false, recovery_target)
	_main_route_ids.append(platform_id)

func _register_platform(
	platform_id: StringName,
	position: Vector3,
	size: Vector3,
	zone: int,
	route_id: StringName,
	risk: float,
	shortcut: bool,
	recovery_target: StringName
) -> void:
	if _platform_index_by_id.has(platform_id):
		return
	_platform_index_by_id[platform_id] = _platform_ids.size()
	_platform_ids.append(platform_id)
	_platform_positions.append(position)
	_platform_sizes.append(size)
	_platform_zones.append(clampi(zone, 0, ZONE_NAMES.size() - 1))
	_platform_route_ids.append(route_id)
	_platform_risks.append(clampf(risk, 0.0, 1.0))
	_platform_shortcuts.append(shortcut)
	_platform_recovery_targets.append(recovery_target)

func _build_course_geometry() -> void:
	for i: int in range(_platform_ids.size()):
		var platform_id: StringName = _platform_ids[i]
		if platform_id == _finish_platform_id:
			_create_finish_platform(platform_id, _platform_positions[i], _platform_sizes[i])
			continue
		var forward: Vector3 = _get_platform_forward(platform_id)
		_create_box_platform(
			platform_id,
			_platform_positions[i],
			_platform_sizes[i],
			_zone_materials[_platform_zones[i]],
			forward
		)

	_create_forest_floor()

func _create_box_platform(
	platform_id: StringName,
	top_position: Vector3,
	size: Vector3,
	material: StandardMaterial3D,
	forward: Vector3
) -> void:
	var root := Node3D.new()
	root.name = String(platform_id)
	root.position = top_position - Vector3.UP * (size.y * 0.5)
	var planar_forward := Vector3(forward.x, 0.0, forward.z)
	if planar_forward.length_squared() > 0.001:
		planar_forward = planar_forward.normalized()
		root.rotation.y = atan2(-planar_forward.x, -planar_forward.z)
	add_child(root)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	root.add_child(mesh_instance)

	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	root.add_child(body)

func _create_finish_platform(platform_id: StringName, top_position: Vector3, size: Vector3) -> void:
	var root := Node3D.new()
	root.name = String(platform_id)
	root.position = top_position - Vector3.UP * (size.y * 0.5)
	add_child(root)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "CrownNestMesh"
	var mesh := CylinderMesh.new()
	mesh.top_radius = size.x * 0.5
	mesh.bottom_radius = size.x * 0.5
	mesh.height = size.y
	mesh.material = _finish_material
	mesh_instance.mesh = mesh
	root.add_child(mesh_instance)

	var body := StaticBody3D.new()
	body.name = "CrownNestCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = size.x * 0.5
	shape.height = size.y
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)

	var marker := Label3D.new()
	marker.name = "FinishLabel"
	marker.text = "THE CROWN NEST\nWILD FINISH"
	marker.position = Vector3(0.0, 4.0, 0.0)
	marker.font_size = 72
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(marker)

func _create_forest_floor() -> void:
	var floor_material := _make_material(Color(0.10, 0.20, 0.09))
	_create_box_platform(&"FOREST_FLOOR", Vector3(0.0, -0.3, -55.0), Vector3(90.0, 0.6, 150.0), floor_material, Vector3.FORWARD)

func _build_recovery_decks() -> void:
	_create_recovery_deck("Recovery_Z2", Vector3(0.0, -2.0, -165.0), Vector3(70.0, 0.6, 125.0), _checkpoint_ids[0])
	_create_recovery_deck("Recovery_Z3", Vector3(0.0, 7.5, -290.0), Vector3(80.0, 0.6, 135.0), _checkpoint_ids[1])
	_create_recovery_deck("Recovery_Z4", Vector3(0.0, 14.5, -440.0), Vector3(100.0, 0.6, 190.0), _checkpoint_ids[2])
	_create_recovery_deck("Recovery_Z5", Vector3(0.0, 22.0, -585.0), Vector3(90.0, 0.6, 115.0), _checkpoint_ids[3])
	_create_recovery_deck("Recovery_Z6", Vector3(0.0, 47.0, -720.0), Vector3(90.0, 0.6, 180.0), _checkpoint_ids[4])

func _create_recovery_deck(name_text: String, top_position: Vector3, size: Vector3, target_id: StringName) -> void:
	_create_box_platform(StringName(name_text + "_Deck"), top_position, size, _recovery_material, Vector3.FORWARD)
	var area := Area3D.new()
	area.name = name_text
	area.position = top_position + Vector3.UP * 1.2
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.monitorable = false
	area.set_meta(&"logspire_recovery_target", target_id)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 2.2, size.z)
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	_recovery_areas.append(area)

func _build_titan_tree_landmark() -> void:
	var merge_position: Vector3 = get_platform_position(_merge_platform_id)
	var trunk := MeshInstance3D.new()
	trunk.name = "TitanTreeGraybox"
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 7.0
	trunk_mesh.bottom_radius = 10.0
	trunk_mesh.height = 72.0
	trunk_mesh.material = _trunk_material
	trunk.mesh = trunk_mesh
	trunk.position = Vector3(0.0, 26.0, merge_position.z - 90.0)
	add_child(trunk)

	var crown := MeshInstance3D.new()
	crown.name = "TitanCanopyGraybox"
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 18.0
	crown_mesh.height = 32.0
	crown_mesh.material = _zone_materials[4]
	crown.mesh = crown_mesh
	crown.position = Vector3(0.0, 60.0, merge_position.z - 90.0)
	add_child(crown)

func _get_platform_forward(platform_id: StringName) -> Vector3:
	var main_index: int = _main_route_ids.find(platform_id)
	if main_index >= 0:
		if main_index + 1 < _main_route_ids.size():
			return get_platform_position(_main_route_ids[main_index + 1]) - get_platform_position(platform_id)
		if main_index > 0:
			return get_platform_position(platform_id) - get_platform_position(_main_route_ids[main_index - 1])

	var wild_index: int = _wild_route_ids.find(platform_id)
	if wild_index >= 0:
		if wild_index + 1 < _wild_route_ids.size():
			return get_platform_position(_wild_route_ids[wild_index + 1]) - get_platform_position(platform_id)
		if wild_index > 0:
			return get_platform_position(platform_id) - get_platform_position(_wild_route_ids[wild_index - 1])
	return Vector3.FORWARD

func _route_length(points: Array[Vector3]) -> float:
	var total: float = 0.0
	for i: int in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total
