class_name WildDashGrandPrixV2Track
extends WildDashGrandPrixTrack

## Round 1 Adventure V2.
## Route geometry, collision, AI path and checkpoints all consume one sampled
## layout bundle. The legacy track remains in source control as a fallback, but
## the V2 runtime does not depend on its index-specific recovery decks.

const ROAD_THICKNESS := 0.82
const ROAD_TOP_OFFSET := 0.04
const COLLISION_OVERLAP := 1.10
const JOINT_PLATE_LENGTH := 4.2
const EDGE_WALL_HEIGHT := 1.35
const EDGE_WALL_THICKNESS := 0.34
const FINISH_RUNOUT_DISTANCE := 18.0

var _v2_bundle: Dictionary = {}
var _v2_route: Array[Vector3] = []
var _v2_segment_widths: Array[float] = []
var _v2_segment_sections: Array[StringName] = []
var _v2_checkpoint_positions: Array[Vector3] = []
var _v2_sections: Array[WildDashGrandPrixV2Section] = []
var _v2_track_length := 0.0
var _v2_decoration_root: Node3D
var _v2_collision_body: StaticBody3D
var _v2_materials: Dictionary = {}

func _ready() -> void:
	_v2_materials = WildDashEnvironmentMaterialLibrary.get_palette()
	_v2_bundle = WildDashGrandPrixV2Layout.build_route_bundle()
	_v2_route = _v2_bundle["points"]
	_v2_segment_widths = _v2_bundle["segment_widths"]
	_v2_segment_sections = _v2_bundle["segment_sections"]
	_v2_sections = _v2_bundle["sections"]
	_v2_checkpoint_positions = WildDashGrandPrixV2Layout.build_checkpoint_positions(_v2_bundle)
	_v2_track_length = WildDashGrandPrixV2Layout.get_total_length(_v2_bundle)

	_build_v2_roots()
	_build_v2_environment()
	_build_v2_road_and_collision()
	_build_v2_start_marker()
	_build_v2_checkpoints()
	_build_v2_finish()

	RaceManager.configure_track(get_route_points(), get_checkpoint_positions())
	var elevation := WildDashGrandPrixV2Layout.get_elevation_range(_v2_bundle)
	print("GRAND PRIX V2 READY sections=%d route_points=%d segments=%d checkpoints=%d length=%.1fm elevation=%.1f..%.1f max_vertical_step=%.2f collision_source=route_bundle" % [
		_v2_sections.size(), _v2_route.size(), _v2_segment_widths.size(), _v2_checkpoint_positions.size(),
		_v2_track_length, elevation.x, elevation.y, WildDashGrandPrixV2Layout.get_max_vertical_step(_v2_bundle),
	])

func is_v2_layout() -> bool:
	return true

func get_route_points() -> Array[Vector3]:
	return _v2_route.duplicate()

func get_checkpoint_positions() -> Array[Vector3]:
	return _v2_checkpoint_positions.duplicate()

func get_track_length() -> float:
	return _v2_track_length

func get_start_position() -> Vector3:
	return _v2_route[0] if not _v2_route.is_empty() else Vector3.ZERO

func get_finish_position() -> Vector3:
	return _v2_route[-1] if not _v2_route.is_empty() else Vector3.ZERO

func get_shortcut_a_saving() -> float:
	return 0.0

func get_shortcut_b_saving() -> float:
	return 0.0

func get_runtime_node_count() -> int:
	return _count_v2_nodes(self)

func get_v2_sections() -> Array[WildDashGrandPrixV2Section]:
	return _v2_sections.duplicate()

func get_v2_section_ranges() -> Dictionary:
	var ranges: Dictionary = _v2_bundle.get("section_ranges", {})
	return ranges.duplicate(true)

func get_v2_section_id_for_segment(segment_index: int) -> StringName:
	if segment_index < 0 or segment_index >= _v2_segment_sections.size():
		return &""
	return _v2_segment_sections[segment_index]

func get_v2_width_for_segment(segment_index: int) -> float:
	if segment_index < 0 or segment_index >= _v2_segment_widths.size():
		return 16.0
	return _v2_segment_widths[segment_index]

func _build_v2_roots() -> void:
	_v2_decoration_root = Node3D.new()
	_v2_decoration_root.name = "DecorationGeometry"
	add_child(_v2_decoration_root)

	_v2_collision_body = StaticBody3D.new()
	_v2_collision_body.name = "GameplayCollision"
	_v2_collision_body.collision_layer = 1
	_v2_collision_body.collision_mask = 0
	add_child(_v2_collision_body)

func _build_v2_environment() -> void:
	var light := DirectionalLight3D.new()
	light.name = "V2Sun"
	light.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	light.light_energy = 1.15
	light.shadow_enabled = true
	add_child(light)

	var environment := WorldEnvironment.new()
	environment.name = "V2WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.34, 0.58, 0.76)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.68, 0.78)
	env.ambient_light_energy = 0.78
	environment.environment = env
	add_child(environment)

func _build_v2_road_and_collision() -> void:
	if _v2_route.size() < 2:
		return
	var visual_groups: Dictionary = {}
	for segment_index in range(_v2_route.size() - 1):
		var a := _v2_route[segment_index]
		var b := _v2_route[segment_index + 1]
		var width := get_v2_width_for_segment(segment_index)
		var section_id := get_v2_section_id_for_segment(segment_index)
		var material_key := _material_key_for_section(section_id)
		if not visual_groups.has(material_key):
			visual_groups[material_key] = []
		var rotation := _road_rotation(a, b)
		var local_up := rotation.basis.y.normalized()
		var center := (a + b) * 0.5 + local_up * (-ROAD_THICKNESS * 0.5 + ROAD_TOP_OFFSET)
		rotation.origin = center

		var visual_transform := rotation
		visual_transform.basis = visual_transform.basis.scaled(Vector3(
			width,
			ROAD_THICKNESS,
			a.distance_to(b) + COLLISION_OVERLAP
		))
		(visual_groups[material_key] as Array).append(visual_transform)

		_add_floor_collision(rotation, width, a.distance_to(b) + COLLISION_OVERLAP, segment_index)
		_add_edge_collision(rotation, width, a.distance_to(b) + COLLISION_OVERLAP, segment_index)

	for point_index in range(1, _v2_route.size() - 1):
		_add_joint_plate(point_index)

	for raw_key: Variant in visual_groups.keys():
		var material_key: StringName = StringName(raw_key)
		var transforms: Array = visual_groups[raw_key]
		_add_visual_multimesh("V2Road_%s" % String(material_key).capitalize(), transforms, _material_for_key(material_key))

func _add_floor_collision(rotation: Transform3D, width: float, length: float, segment_index: int) -> void:
	var collision := CollisionShape3D.new()
	collision.name = "RoadFloor_%03d" % segment_index
	var shape := BoxShape3D.new()
	shape.size = Vector3(width + 0.25, ROAD_THICKNESS, length)
	collision.shape = shape
	collision.transform = rotation
	_v2_collision_body.add_child(collision)

func _add_edge_collision(rotation: Transform3D, width: float, length: float, segment_index: int) -> void:
	for side in [-1.0, 1.0]:
		var collision := CollisionShape3D.new()
		collision.name = "RoadEdge_%03d_%s" % [segment_index, "L" if side < 0.0 else "R"]
		var shape := BoxShape3D.new()
		shape.size = Vector3(EDGE_WALL_THICKNESS, EDGE_WALL_HEIGHT, length)
		collision.shape = shape
		var edge_transform := rotation
		edge_transform.origin += rotation.basis.x.normalized() * side * (width * 0.5 + EDGE_WALL_THICKNESS * 0.35)
		edge_transform.origin += rotation.basis.y.normalized() * (ROAD_THICKNESS * 0.5 + EDGE_WALL_HEIGHT * 0.5 - 0.06)
		collision.transform = edge_transform
		_v2_collision_body.add_child(collision)

func _add_joint_plate(point_index: int) -> void:
	var previous := _v2_route[point_index - 1]
	var point := _v2_route[point_index]
	var following := _v2_route[point_index + 1]
	var rotation := _road_rotation(previous, following)
	var local_up := rotation.basis.y.normalized()
	rotation.origin = point + local_up * (-ROAD_THICKNESS * 0.5 + ROAD_TOP_OFFSET)
	var width := maxf(get_v2_width_for_segment(point_index - 1), get_v2_width_for_segment(point_index)) + 0.85
	var collision := CollisionShape3D.new()
	collision.name = "JointPlate_%03d" % point_index
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, ROAD_THICKNESS + 0.08, JOINT_PLATE_LENGTH)
	collision.shape = shape
	collision.transform = rotation
	_v2_collision_body.add_child(collision)

func _build_v2_start_marker() -> void:
	if _v2_route.size() < 2:
		return
	_add_marker_visual("V2StartStripe", _v2_route[0], _v2_route[1], get_v2_width_for_segment(0), _material_for_key(&"warning"))

func _build_v2_checkpoints() -> void:
	for checkpoint_index in range(_v2_checkpoint_positions.size()):
		var point := _v2_checkpoint_positions[checkpoint_index]
		var route_index := _nearest_route_index(point)
		var next_index := mini(route_index + 1, _v2_route.size() - 1)
		var next_point := _v2_route[next_index]
		var width := get_v2_width_for_segment(mini(route_index, _v2_segment_widths.size() - 1))

		var area := Area3D.new()
		area.name = "V2Checkpoint_%02d" % (checkpoint_index + 1)
		area.set_script(CHECKPOINT_SCRIPT)
		area.set("checkpoint_index", checkpoint_index)
		area.position = point + Vector3.UP * 1.75
		area.collision_mask = 2
		add_child(area)
		area.look_at(next_point + Vector3.UP * 1.75, Vector3.UP)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(width + 1.5, 4.2, 7.0)
		collision.shape = shape
		area.add_child(collision)
		_add_marker_visual("V2CheckpointStripe_%02d" % (checkpoint_index + 1), point, next_point, width, _material_for_key(&"warning"))

func _build_v2_finish() -> void:
	if _v2_route.size() < 2:
		return
	var finish := _v2_route[-1]
	var previous := _v2_route[-2]
	var direction := finish - previous
	if direction.length_squared() <= 0.001:
		return
	var next_point := finish + direction.normalized() * FINISH_RUNOUT_DISTANCE
	var finish_width := get_v2_width_for_segment(_v2_segment_widths.size() - 1)

	var rotation := _road_rotation(finish, next_point)
	var local_up := rotation.basis.y.normalized()
	rotation.origin = (finish + next_point) * 0.5 + local_up * (-ROAD_THICKNESS * 0.5 + ROAD_TOP_OFFSET)
	var visual_transform := rotation
	visual_transform.basis = visual_transform.basis.scaled(Vector3(finish_width, ROAD_THICKNESS, FINISH_RUNOUT_DISTANCE + COLLISION_OVERLAP))
	_add_visual_multimesh("V2FinishRunout", [visual_transform], _material_for_key(&"asphalt"))
	_add_floor_collision(rotation, finish_width, FINISH_RUNOUT_DISTANCE + COLLISION_OVERLAP, _v2_segment_widths.size())

	var area := Area3D.new()
	area.name = "FinishLine"
	area.set_script(FINISH_SCRIPT)
	area.position = finish + Vector3.UP * 1.8
	area.collision_mask = 2
	add_child(area)
	area.look_at(next_point + Vector3.UP * 1.8, Vector3.UP)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(finish_width + 1.5, 4.2, 7.0)
	collision.shape = shape
	area.add_child(collision)
	_add_marker_visual("V2FinishStripe", finish, next_point, finish_width, _material_for_key(&"warning"))

func _add_marker_visual(node_name: String, point: Vector3, target: Vector3, width: float, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.07, 1.25)
	mesh.material = material
	var marker := MeshInstance3D.new()
	marker.name = node_name
	marker.mesh = mesh
	marker.position = point + Vector3.UP * 0.08
	_v2_decoration_root.add_child(marker)
	marker.look_at(target + Vector3.UP * 0.08, Vector3.UP)

func _add_visual_multimesh(node_name: String, transforms: Array, material: Material) -> void:
	if transforms.is_empty():
		return
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = cube
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	multimesh.custom_aabb = AABB(Vector3(-260.0, -30.0, -1900.0), Vector3(520.0, 120.0, 2050.0))
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	_v2_decoration_root.add_child(instance)

func _road_rotation(a: Vector3, b: Vector3) -> Transform3D:
	var direction := b - a
	if direction.length_squared() <= 0.001:
		direction = Vector3.FORWARD
	var midpoint := (a + b) * 0.5
	var transform := Transform3D(Basis.IDENTITY, midpoint)
	return transform.looking_at(midpoint + direction.normalized(), Vector3.UP)

func _material_key_for_section(section_id: StringName) -> StringName:
	match section_id:
		&"forest_obstacle", &"mountain_approach", &"mountain_ascent", &"rough_descent", &"canyon_obstacle":
			return &"dirt_road"
		&"long_river":
			return &"bridge_road"
		_:
			return &"asphalt"

func _material_for_key(key: StringName) -> Material:
	if key == &"warning" and _v2_materials.has(&"curb_warning"):
		return _v2_materials[&"curb_warning"] as Material
	if _v2_materials.has(key):
		return _v2_materials[key] as Material
	if _v2_materials.has(&"asphalt"):
		return _v2_materials[&"asphalt"] as Material
	var fallback := StandardMaterial3D.new()
	fallback.albedo_color = Color(0.14, 0.17, 0.19)
	fallback.roughness = 0.88
	return fallback

func _nearest_route_index(point: Vector3) -> int:
	var best_index := 0
	var best_distance := INF
	for index in range(_v2_route.size()):
		var distance := point.distance_squared_to(_v2_route[index])
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index

func _count_v2_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_v2_nodes(child)
	return count
