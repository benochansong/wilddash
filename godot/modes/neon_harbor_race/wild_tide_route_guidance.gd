class_name WildDashWildTideRouteGuidance
extends Node3D

## Round-1-style world guidance for the rebuilt Round 3. Arrows are deliberately
## simple CSG pieces so they remain readable in GL Compatibility without relying
## on texture imports or a custom shader.

const MAIN_ARROW_INDICES: Array[int] = [1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27]
const WATER_ARROW_INDICES: Array[int] = [5, 7, 9, 17, 19, 21]
const CANOPY_ARROW_INDICES: Array[int] = [10, 11, 12, 13]
const SHORTCUT_ARROW_INDICES: Array[int] = [14, 20]

var _route_points: Array[Vector3] = []
var _main_count: int = 0
var _water_count: int = 0
var _canopy_count: int = 0
var _shortcut_count: int = 0

func _ready() -> void:
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	var track: Node = null
	for _attempt: int in range(60):
		var parent_node: Node = get_parent()
		if parent_node != null:
			track = parent_node.get_node_or_null("NeonHarborWorldTrack")
		if track != null and track.has_method("get_route_points"):
			break
		await get_tree().physics_frame
	if track == null or not track.has_method("get_route_points"):
		return
	var route_value: Variant = track.call("get_route_points")
	if not (route_value is Array):
		return
	for value: Variant in route_value:
		if value is Vector3:
			var point: Vector3 = value
			_route_points.append(point)
	if _route_points.size() < 29:
		return

	var main_material: StandardMaterial3D = _arrow_material(Color(1.0, 0.64, 0.06), 0.42)
	var water_material: StandardMaterial3D = _arrow_material(Color(0.06, 0.88, 1.0), 0.52)
	var canopy_material: StandardMaterial3D = _arrow_material(Color(0.30, 1.0, 0.22), 0.46)
	var shortcut_material: StandardMaterial3D = _arrow_material(Color(1.0, 0.26, 0.05), 0.52)

	for route_index: int in MAIN_ARROW_INDICES:
		if _create_route_arrow(route_index, 0.32, main_material, "MainArrow"):
			_main_count += 1
	for route_index: int in WATER_ARROW_INDICES:
		if _create_offset_arrow(route_index, -4.2, 0.38, water_material, "WaterArrow"):
			_water_count += 1
	for route_index: int in CANOPY_ARROW_INDICES:
		if _create_offset_arrow(route_index, -5.4, 0.42, canopy_material, "CanopyArrow"):
			_canopy_count += 1
	for route_index: int in SHORTCUT_ARROW_INDICES:
		if _create_offset_arrow(route_index, 5.0, 0.38, shortcut_material, "ShortcutArrow"):
			_shortcut_count += 1

	_create_split_sign(5, "WATER ROUTE", -6.0, Color(0.06, 0.88, 1.0))
	_create_split_sign(5, "LAND ROUTE", 6.0, Color(1.0, 0.68, 0.08))
	_create_split_sign(10, "CANOPY", -6.0, Color(0.30, 1.0, 0.22))
	_create_split_sign(18, "HIGH ROUTE", 6.0, Color(1.0, 0.84, 0.18))

	print("ARROW GUIDE READY main=%d water=%d canopy=%d shortcut=%d world_space=true round1_style=true" % [
		_main_count, _water_count, _canopy_count, _shortcut_count,
	])

func _create_route_arrow(
	route_index: int,
	height: float,
	material: StandardMaterial3D,
	prefix: String
) -> bool:
	if route_index < 0 or route_index >= _route_points.size() - 1:
		return false
	var point: Vector3 = _route_points[route_index]
	var next: Vector3 = _route_points[route_index + 1]
	_create_arrow_shape("%s_%02d" % [prefix, route_index], point + Vector3.UP * height, next, material)
	return true

func _create_offset_arrow(
	route_index: int,
	lateral: float,
	height: float,
	material: StandardMaterial3D,
	prefix: String
) -> bool:
	if route_index < 0 or route_index >= _route_points.size() - 1:
		return false
	var point: Vector3 = _route_points[route_index]
	var next: Vector3 = _route_points[route_index + 1]
	var direction: Vector3 = next - point
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return false
	direction = direction.normalized()
	var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	var arrow_position: Vector3 = point + right * lateral + Vector3.UP * height
	_create_arrow_shape("%s_%02d" % [prefix, route_index], arrow_position, arrow_position + direction * 5.0, material)
	return true

func _create_arrow_shape(node_name: String, position: Vector3, target: Vector3, material: StandardMaterial3D) -> void:
	var root: Node3D = Node3D.new()
	root.name = node_name
	root.position = position
	add_child(root)
	root.look_at(Vector3(target.x, position.y, target.z), Vector3.UP)

	var stem: CSGBox3D = CSGBox3D.new()
	stem.name = "Stem"
	stem.size = Vector3(0.62, 0.06, 2.6)
	stem.use_collision = false
	stem.position = Vector3(0.0, 0.0, 0.25)
	stem.material = material
	root.add_child(stem)

	for side: float in [-1.0, 1.0]:
		var wing: CSGBox3D = CSGBox3D.new()
		wing.name = "HeadL" if side < 0.0 else "HeadR"
		wing.size = Vector3(0.52, 0.065, 1.65)
		wing.use_collision = false
		wing.position = Vector3(side * 0.48, 0.01, -1.08)
		wing.rotation.y = side * deg_to_rad(42.0)
		wing.material = material
		root.add_child(wing)

func _create_split_sign(route_index: int, text: String, lateral: float, color: Color) -> void:
	if route_index < 0 or route_index >= _route_points.size() - 1:
		return
	var point: Vector3 = _route_points[route_index]
	var next: Vector3 = _route_points[route_index + 1]
	var direction: Vector3 = next - point
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	direction = direction.normalized()
	var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	var sign_position: Vector3 = point + right * lateral + Vector3.UP * 3.0

	var label: Label3D = Label3D.new()
	label.name = text.replace(" ", "_")
	label.text = text
	label.font_size = 42
	label.modulate = color
	label.outline_size = 10
	label.position = sign_position
	add_child(label)
	var approach: Vector3 = sign_position - direction * 6.0
	label.look_at(Vector3(approach.x, sign_position.y, approach.z), Vector3.UP)

func _arrow_material(color: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.38
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
