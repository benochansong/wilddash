class_name WildDashNeonHarborGroundCircuit
extends Node3D

## Neon Harbor V2 / Phase 1 grounded city circuit.
##
## This rebuild intentionally starts with the race foundation only:
## - mostly-flat 1.5 km route
## - continuous collidable city floor under and around the road
## - 9 checkpoints
## - start/finish gates
## - no elevated-highway dependency
## - no continuous guardrail tunnel
##
## District art, ability shortcuts, cargo lane logic and final neon polish are
## layered in later phases only after this grounded route is graphically proven.

const CHECKPOINT_SCRIPT: Script = preload("res://tracks/checkpoint.gd")
const FINISH_SCRIPT: Script = preload("res://tracks/finish_line.gd")

const ROUTE_POINTS: Array[Vector3] = [
	Vector3(0.0, 0.0, 56.0),
	Vector3(0.0, 0.0, 14.0),
	Vector3(42.0, 0.0, -24.5),
	Vector3(91.0, 0.0, -42.0),
	Vector3(133.0, 0.0, -80.5),
	Vector3(129.5, 0.0, -129.5),
	Vector3(87.5, 0.0, -161.0),
	Vector3(38.5, 0.0, -171.5),
	Vector3(-14.0, 0.0, -161.0),
	Vector3(-59.5, 0.0, -189.0),
	Vector3(-98.0, 0.0, -227.5),
	Vector3(-108.5, 0.0, -280.0),
	Vector3(-77.0, 0.0, -318.5),
	Vector3(-28.0, 0.0, -332.5),
	Vector3(24.5, 0.0, -322.0),
	Vector3(73.5, 0.0, -350.0),
	Vector3(108.5, 0.0, -392.0),
	Vector3(101.5, 0.0, -441.0),
	Vector3(59.5, 0.0, -472.5),
	Vector3(7.0, 0.0, -483.0),
	Vector3(-45.5, 0.0, -469.0),
	Vector3(-87.5, 0.0, -497.0),
	Vector3(-101.5, 0.0, -546.0),
	Vector3(-73.5, 0.0, -591.5),
	Vector3(-24.5, 0.0, -612.5),
	Vector3(31.5, 0.0, -605.5),
	Vector3(73.5, 0.0, -633.5),
	Vector3(80.5, 0.0, -682.5),
	Vector3(42.0, 0.0, -724.5),
	Vector3(0.0, 0.0, -756.0),
]

const SEGMENT_WIDTHS: Array[float] = [
	20.0, 20.0, 18.0, 18.0,
	16.0, 14.0, 15.0, 16.0,
	11.0, 10.0, 12.0, 13.0,
	15.0, 15.0, 14.0, 15.0,
	18.0, 18.0, 17.0, 18.0, 18.0,
	16.0, 18.0, 18.0, 16.0,
	18.0, 18.0, 20.0, 20.0,
]

const CHECKPOINT_ROUTE_INDICES: Array[int] = [3, 6, 9, 12, 15, 18, 21, 24, 28]

const CITY_FLOOR_SIZE: Vector3 = Vector3(380.0, 0.50, 900.0)
const CITY_FLOOR_CENTER: Vector3 = Vector3(8.0, -0.30, -350.0)

var _track_length: float = 0.0
var _materials: Dictionary = {}
var _visual_root: Node3D
var _collision_root: Node3D

func _ready() -> void:
	_build_materials()
	_build_night_environment()
	_build_world_floor()
	_build_road()
	_build_start_finish()
	_build_checkpoints()
	RaceManager.configure_track(get_route_points(), get_checkpoint_positions())
	print("NEON HARBOR V2 PHASE1 GROUNDED CIRCUIT READY route_points=%d checkpoints=%d length=%.1fm vertical_range=0.0m city_floor=380x900m guardrail=false elevated_highway=false" % [
		ROUTE_POINTS.size(),
		CHECKPOINT_ROUTE_INDICES.size(),
		_track_length,
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
	return 0.0

func get_shortcut_b_saving() -> float:
	return 0.0

func get_runtime_node_count() -> int:
	return _count_nodes_recursive(self)

func get_zone_names() -> PackedStringArray:
	return PackedStringArray([
		"Harbor Festival Boulevard",
		"Container Grid",
		"Neon Market Alley",
		"Canal Promenade",
		"Cargo Logistics Yard",
		"Neon Downtown Plaza",
		"Shipyard Final Sprint",
	])

func _build_materials() -> void:
	_materials[&"road"] = _material(Color(0.045, 0.055, 0.075), 0.44, 0.10)
	_materials[&"city_ground"] = _material(Color(0.105, 0.125, 0.145), 0.88, 0.0)
	_materials[&"edge_cyan"] = _emissive(Color(0.05, 0.72, 0.88), Color(0.02, 0.48, 0.75), 0.70)
	_materials[&"edge_magenta"] = _emissive(Color(0.90, 0.16, 0.64), Color(0.68, 0.02, 0.42), 0.66)
	_materials[&"metal"] = _material(Color(0.28, 0.34, 0.42), 0.38, 0.55)
	_materials[&"finish"] = _emissive(Color(0.88, 0.96, 1.0), Color(0.18, 0.70, 1.0), 0.95)

func _build_night_environment() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.010, 0.018, 0.050)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.18, 0.25, 0.40)
	environment.ambient_light_energy = 0.82
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "NeonHarborV2WorldEnvironment"
	world.environment = environment
	add_child(world)

	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.name = "NeonHarborV2Moon"
	moon.rotation_degrees = Vector3(-52.0, -30.0, 0.0)
	moon.light_color = Color(0.58, 0.70, 1.0)
	moon.light_energy = 0.52
	moon.shadow_enabled = true
	add_child(moon)

func _build_world_floor() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "V2UrbanVisuals"
	add_child(_visual_root)
	_collision_root = Node3D.new()
	_collision_root.name = "V2UrbanCollision"
	add_child(_collision_root)

	var floor: CSGBox3D = CSGBox3D.new()
	floor.name = "ContinuousHarborDistrictFloor"
	floor.size = CITY_FLOOR_SIZE
	floor.position = CITY_FLOOR_CENTER
	floor.use_collision = true
	floor.collision_layer = 1
	floor.collision_mask = 0
	floor.material = _materials[&"city_ground"]
	_collision_root.add_child(floor)

func _build_road() -> void:
	var road_transforms: Array[Transform3D] = []
	var cyan_edges: Array[Transform3D] = []
	var magenta_edges: Array[Transform3D] = []
	_track_length = 0.0

	for segment_index: int in range(ROUTE_POINTS.size() - 1):
		var a: Vector3 = ROUTE_POINTS[segment_index]
		var b: Vector3 = ROUTE_POINTS[segment_index + 1]
		var width: float = SEGMENT_WIDTHS[segment_index]
		var length: float = a.distance_to(b)
		_track_length += length

		road_transforms.append(_track_xform(a, b, 0.5, 0.0, 0.015, Vector3(width, 0.16, length + 0.35)))
		_add_road_collision("Road_%02d" % segment_index, a, b, width, length)

		for side: float in [-1.0, 1.0]:
			var edge_transform: Transform3D = _track_xform(
				a,
				b,
				0.5,
				side * (width * 0.5 - 0.28),
				0.105,
				Vector3(0.16, 0.05, maxf(0.5, length - 0.30))
			)
			if side < 0.0:
				cyan_edges.append(edge_transform)
			else:
				magenta_edges.append(edge_transform)

	_add_batch("V2RoadSurface", road_transforms, _materials[&"road"])
	_add_batch("V2RoadEdgeCyan", cyan_edges, _materials[&"edge_cyan"])
	_add_batch("V2RoadEdgeMagenta", magenta_edges, _materials[&"edge_magenta"])

func _build_start_finish() -> void:
	var start_a: Vector3 = ROUTE_POINTS[0]
	var start_b: Vector3 = ROUTE_POINTS[1]
	var finish_a: Vector3 = ROUTE_POINTS[-2]
	var finish_b: Vector3 = ROUTE_POINTS[-1]

	var start_parts: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		start_parts.append(_track_xform(start_a, start_b, 0.12, side * 10.3, 2.5, Vector3(0.42, 5.0, 0.42)))
	start_parts.append(_track_xform(start_a, start_b, 0.12, 0.0, 4.75, Vector3(21.0, 0.42, 0.42)))
	_add_batch("V2StartGantry", start_parts, _materials[&"metal"])

	var finish_parts: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		finish_parts.append(_track_xform(finish_a, finish_b, 0.96, side * 10.3, 2.7, Vector3(0.46, 5.4, 0.46)))
	finish_parts.append(_track_xform(finish_a, finish_b, 0.96, 0.0, 5.05, Vector3(21.0, 0.48, 0.48)))
	_add_batch("V2FinishGantry", finish_parts, _materials[&"finish"])

	var finish_position: Vector3 = ROUTE_POINTS[-1]
	var finish_direction: Vector3 = (finish_position - ROUTE_POINTS[-2]).normalized()
	var finish_area: Area3D = Area3D.new()
	finish_area.name = "FinishLine"
	finish_area.set_script(FINISH_SCRIPT)
	finish_area.position = finish_position + Vector3.UP * 1.8
	finish_area.collision_mask = 2
	add_child(finish_area)
	finish_area.look_at(finish_position + finish_direction + Vector3.UP * 1.8, Vector3.UP)
	var finish_shape: CollisionShape3D = CollisionShape3D.new()
	var finish_box: BoxShape3D = BoxShape3D.new()
	finish_box.size = Vector3(21.5, 4.5, 6.0)
	finish_shape.shape = finish_box
	finish_area.add_child(finish_shape)

func _build_checkpoints() -> void:
	for checkpoint_index: int in range(CHECKPOINT_ROUTE_INDICES.size()):
		var route_index: int = CHECKPOINT_ROUTE_INDICES[checkpoint_index]
		var point: Vector3 = ROUTE_POINTS[route_index]
		var next: Vector3 = ROUTE_POINTS[min(route_index + 1, ROUTE_POINTS.size() - 1)]
		var width: float = SEGMENT_WIDTHS[min(route_index, SEGMENT_WIDTHS.size() - 1)]
		var area: Area3D = Area3D.new()
		area.name = "Checkpoint_%02d" % (checkpoint_index + 1)
		area.set_script(CHECKPOINT_SCRIPT)
		area.set("checkpoint_index", checkpoint_index)
		area.position = point + Vector3.UP * 1.8
		area.collision_mask = 2
		add_child(area)
		area.look_at(next + Vector3.UP * 1.8, Vector3.UP)
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(width + 4.0, 4.5, 8.0)
		shape.shape = box
		area.add_child(shape)

func _add_road_collision(node_name: String, a: Vector3, b: Vector3, width: float, length: float) -> void:
	var collision: CSGBox3D = CSGBox3D.new()
	collision.name = node_name
	collision.size = Vector3(width, 0.30, length + 0.50)
	collision.use_collision = true
	collision.visible = false
	collision.position = (a + b) * 0.5 + Vector3.DOWN * 0.10
	_collision_root.add_child(collision)
	collision.look_at(b + Vector3.DOWN * 0.10, Vector3.UP)

func _track_xform(a: Vector3, b: Vector3, t: float, lateral: float, vertical: float, size: Vector3) -> Transform3D:
	var direction: Vector3 = b - a
	var right: Vector3 = _right(a, b)
	var origin: Vector3 = a.lerp(b, t) + right * lateral + Vector3.UP * vertical
	var transform: Transform3D = Transform3D(Basis.IDENTITY, origin)
	transform = transform.looking_at(origin + direction.normalized(), Vector3.UP)
	transform.basis = transform.basis.scaled(size)
	return transform

func _right(a: Vector3, b: Vector3) -> Vector3:
	var direction: Vector3 = b - a
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return Vector3.RIGHT
	direction = direction.normalized()
	return Vector3(-direction.z, 0.0, direction.x)

func _add_batch(node_name: String, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3.ONE
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	_visual_root.add_child(instance)

func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _emissive(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = _material(color, 0.46, 0.12)
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material

func _count_nodes_recursive(root: Node) -> int:
	var count: int = 1
	for child: Node in root.get_children():
		count += _count_nodes_recursive(child)
	return count
