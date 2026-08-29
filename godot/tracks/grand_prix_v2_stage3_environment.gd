class_name WildDashGrandPrixV2Stage3Environment
extends Node3D

## Stage 3 representative-map pass.
## Distributes eight obstacle families, warned dynamic hazards and inexpensive
## MultiMesh environment dressing across the named V2 sections.

const OBSTACLE_TYPES: Array[StringName] = [
	&"small_rock", &"large_boulder", &"fallen_log", &"mud_patch",
	&"rotating_log", &"moving_gate", &"rolling_boulder", &"rock_fall",
]

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _ranges: Dictionary = {}
var _root_static: Node3D
var _root_dynamic: Node3D
var _root_environment: Node3D
var _static_count: int = 0
var _dynamic_count: int = 0

func _ready() -> void:
	call_deferred("_build_when_ready")

func _build_when_ready() -> void:
	for _frame: int in range(5):
		await get_tree().process_frame
	_track = _find_v2_track(get_parent())
	if _track == null:
		push_warning("GrandPrixV2Stage3Environment: V2 track unavailable")
		return
	_route = _track.get_route_points()
	_ranges = _track.get_v2_section_ranges()
	if _route.size() < 2:
		return

	_root_static = Node3D.new()
	_root_static.name = "V2Stage3StaticObstacles"
	add_child(_root_static)
	_root_dynamic = Node3D.new()
	_root_dynamic.name = "V2Stage3DynamicHazards"
	add_child(_root_dynamic)
	_root_environment = Node3D.new()
	_root_environment.name = "V2Stage3Environment"
	add_child(_root_environment)

	_build_forest_obstacles()
	_build_mountain_obstacles()
	_build_descent_obstacles()
	_build_canyon_obstacles()
	_build_dynamic_hazards()
	_build_environment_dressing()
	_build_finale_landmarks()

	print("GRAND PRIX V2 STAGE3 READY obstacle_types=%d static=%d dynamic=%d difficulty=%s hazard_speed=%.2f warning>=1.05s multimesh_art=true" % [
		OBSTACLE_TYPES.size(), _static_count, _dynamic_count, String(GameManager.difficulty), _hazard_speed_scale(),
	])

static func get_obstacle_types() -> Array[StringName]:
	return OBSTACLE_TYPES.duplicate()

func _build_forest_obstacles() -> void:
	# LEFT = technical/agility line, CENTER = power/combat line, RIGHT = safer line.
	_spawn_light(&"forest_obstacle", 0.16, -3.7, &"forest_small_rock_l", Vector3(1.8, 1.15, 1.8), 3.8, 0.62, true, &"rock")
	_spawn_light(&"forest_obstacle", 0.28, 0.0, &"forest_fallen_log_c", Vector3(5.0, 0.70, 1.0), 4.2, 0.58, true, &"log")
	_spawn_light(&"forest_obstacle", 0.43, 3.0, &"forest_large_boulder_r", Vector3(3.2, 2.3, 3.2), 5.4, 0.48, false, &"rock")
	_spawn_light(&"forest_obstacle", 0.58, -2.7, &"forest_small_rock_l2", Vector3(1.6, 1.05, 1.6), 3.6, 0.64, true, &"rock")
	_spawn_mud_patch(&"forest_obstacle", 0.69, 2.8, 4.2)
	# Tree-gap pair makes the left technical lane readable without blocking the whole track.
	_spawn_light(&"forest_obstacle", 0.79, -4.9, &"forest_tree_gap_outer", Vector3(1.0, 3.8, 1.0), 4.5, 0.55, false, &"log")
	_spawn_light(&"forest_obstacle", 0.79, -0.8, &"forest_tree_gap_inner", Vector3(1.0, 3.8, 1.0), 4.5, 0.55, false, &"log")

func _build_mountain_obstacles() -> void:
	_spawn_light(&"mountain_ascent", 0.18, 0.0, &"mountain_center_rock", Vector3(2.7, 1.8, 2.7), 4.8, 0.54, true, &"rock")
	_spawn_light(&"mountain_ascent", 0.38, -3.4, &"mountain_rocky_left", Vector3(2.1, 1.45, 2.1), 4.3, 0.58, true, &"rock")
	_spawn_light(&"mountain_ascent", 0.63, 3.2, &"mountain_safe_boulder", Vector3(3.0, 2.2, 3.0), 5.1, 0.50, false, &"rock")
	_spawn_light(&"mountain_ascent", 0.84, 0.0, &"mountain_fallen_log", Vector3(4.8, 0.70, 1.0), 4.0, 0.60, true, &"log")

func _build_descent_obstacles() -> void:
	_spawn_mud_patch(&"rough_descent", 0.20, -2.8, 4.4)
	_spawn_light(&"rough_descent", 0.36, 2.8, &"descent_large_boulder", Vector3(3.2, 2.35, 3.2), 5.8, 0.46, false, &"rock")
	_spawn_light(&"rough_descent", 0.56, -2.4, &"descent_small_rock", Vector3(1.8, 1.15, 1.8), 3.9, 0.63, true, &"rock")
	_spawn_mud_patch(&"rough_descent", 0.76, 2.4, 4.0)

func _build_canyon_obstacles() -> void:
	_spawn_light(&"canyon_obstacle", 0.14, -3.0, &"canyon_small_rock", Vector3(1.8, 1.2, 1.8), 4.0, 0.61, true, &"rock")
	_spawn_light(&"canyon_obstacle", 0.31, 0.0, &"canyon_center_boulder", Vector3(3.4, 2.5, 3.4), 6.0, 0.44, false, &"rock")
	_spawn_light(&"canyon_obstacle", 0.72, 3.0, &"canyon_fallen_log", Vector3(4.8, 0.72, 1.0), 4.3, 0.57, true, &"log")

func _build_dynamic_hazards() -> void:
	var speed: float = _hazard_speed_scale()
	var cycle_bonus: float = 1.25 if GameManager.difficulty == &"wild" else 0.0

	_spawn_dynamic(
		&"forest_obstacle", 0.88, 0.0, &"forest_rotating_log", &"rotating_log",
		Vector3(8.2, 0.72, 0.86), Vector3.RIGHT, 0.0,
		5.2 + cycle_bonus, 2.1, 1.15, speed, 6.0, 0.50
	)
	_spawn_dynamic(
		&"rough_descent", 0.48, 0.0, &"descent_rolling_boulder", &"rolling_boulder",
		Vector3(2.8, 2.8, 2.8), Vector3.RIGHT, 11.0,
		6.0 + cycle_bonus, 2.0, 1.20, speed, 7.2, 0.46
	)
	_spawn_dynamic(
		&"canyon_obstacle", 0.46, 0.0, &"canyon_moving_gate", &"moving_gate",
		Vector3(2.0, 3.8, 1.0), Vector3.RIGHT, 8.5,
		5.5 + cycle_bonus, 2.3, 1.10, speed, 6.4, 0.49
	)
	_spawn_dynamic(
		&"canyon_obstacle", 0.61, -2.0, &"canyon_rock_fall", &"rock_fall",
		Vector3(2.5, 2.5, 2.5), Vector3.RIGHT, 0.0,
		6.7 + cycle_bonus, 1.8, 1.30, speed, 7.5, 0.43
	)

	if GameManager.difficulty == &"nightmare":
		_spawn_dynamic(
			&"rough_descent", 0.70, 0.0, &"descent_rolling_boulder_hard", &"rolling_boulder",
			Vector3(2.5, 2.5, 2.5), -Vector3.RIGHT, 10.0,
			5.4, 1.9, 1.10, speed, 7.0, 0.46
		)
		_spawn_dynamic(
			&"canyon_obstacle", 0.83, 0.0, &"canyon_moving_gate_hard", &"moving_gate",
			Vector3(1.8, 3.6, 1.0), Vector3.RIGHT, 8.0,
			5.0, 2.2, 1.05, speed, 6.2, 0.50
		)

func _spawn_light(
	section_id: StringName,
	progress: float,
	lateral_offset: float,
	obstacle_id: StringName,
	size: Vector3,
	strength: float,
	retention: float,
	breakable: bool,
	shape_kind: StringName
) -> void:
	var placement: Dictionary = _placement(section_id, progress, lateral_offset)
	if placement.is_empty():
		return
	var obstacle := WildDashGrandPrixV2LightObstacle.new()
	obstacle.name = String(obstacle_id)
	obstacle.position = placement["position"] as Vector3
	_root_static.add_child(obstacle)
	var forward: Vector3 = placement["forward"] as Vector3
	obstacle.look_at(obstacle.global_position + forward, Vector3.UP)
	obstacle.configure(
		obstacle_id, size,
		_rock_material() if shape_kind == &"rock" else _wood_material(),
		strength, retention, breakable, shape_kind
	)
	_static_count += 1

func _spawn_mud_patch(section_id: StringName, progress: float, lateral_offset: float, width: float) -> void:
	var placement: Dictionary = _placement(section_id, progress, lateral_offset)
	if placement.is_empty():
		return
	var segment_index: int = int(placement["segment_index"])
	var a: Vector3 = _route[segment_index]
	var b: Vector3 = _route[segment_index + 1]
	var right: Vector3 = placement["right"] as Vector3
	var zone := WildDashTerrainZone.new()
	zone.name = "MudPatch_%03d" % segment_index
	_root_static.add_child(zone)
	zone.configure_route_box(StringName("mud_%03d" % segment_index), &"rough", a, b, width, 5.0, 0.12, 0.88)
	zone.center += right * lateral_offset
	zone.position = zone.center
	zone.half_width = width * 0.5

	var visual := MeshInstance3D.new()
	visual.name = "MudVisual_%03d" % segment_index
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.045, maxf(5.0, a.distance_to(b) * 0.70))
	mesh.material = _mud_material()
	visual.mesh = mesh
	visual.position = placement["position"] as Vector3 + Vector3.UP * 0.08
	visual.look_at(visual.position + (placement["forward"] as Vector3), Vector3.UP)
	_root_environment.add_child(visual)
	_static_count += 1

func _spawn_dynamic(
	section_id: StringName,
	progress: float,
	lateral_offset: float,
	hazard_id: StringName,
	kind: StringName,
	size: Vector3,
	local_axis: Vector3,
	travel: float,
	cycle: float,
	active: float,
	warning: float,
	speed: float,
	strength: float,
	retention: float
) -> void:
	var placement: Dictionary = _placement(section_id, progress, lateral_offset)
	if placement.is_empty():
		return
	var right: Vector3 = placement["right"] as Vector3
	var forward: Vector3 = placement["forward"] as Vector3
	var world_axis: Vector3 = right * local_axis.x + forward * local_axis.z
	if world_axis.length_squared() <= 0.001:
		world_axis = right
	var hazard := WildDashGrandPrixV2DynamicHazard.new()
	hazard.name = String(hazard_id)
	hazard.position = placement["position"] as Vector3 + Vector3.UP * (size.y * 0.5)
	_root_dynamic.add_child(hazard)
	hazard.look_at(hazard.global_position + forward, Vector3.UP)
	hazard.configure(
		hazard_id, kind, size,
		_rock_material() if kind == &"rolling_boulder" or kind == &"rock_fall" else _wood_material(),
		world_axis, travel, cycle, active, warning, speed, strength, retention
	)
	_dynamic_count += 1

func _placement(section_id: StringName, progress: float, lateral_offset: float) -> Dictionary:
	if not _ranges.has(section_id):
		return {}
	var section_range: Vector2i = _ranges[section_id] as Vector2i
	var segment_index: int = clampi(
		roundi(lerpf(float(section_range.x), float(section_range.y), clampf(progress, 0.0, 1.0))),
		section_range.x, section_range.y
	)
	if segment_index < 0 or segment_index + 1 >= _route.size():
		return {}
	var a: Vector3 = _route[segment_index]
	var b: Vector3 = _route[segment_index + 1]
	var forward: Vector3 = b - a
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
	return {
		"segment_index": segment_index,
		"position": a.lerp(b, 0.5) + right * lateral_offset,
		"forward": forward,
		"right": right,
	}

func _build_environment_dressing() -> void:
	_build_forest_multimesh(&"forest_obstacle", "Forest")
	_build_forest_multimesh(&"final_sprint", "FinalForest")
	_build_river_reeds()
	_build_mountain_cliffs()
	_build_canyon_walls()

func _build_forest_multimesh(section_id: StringName, prefix: String) -> void:
	if not _ranges.has(section_id):
		return
	var section_range: Vector2i = _ranges[section_id] as Vector2i
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	var tree_index: int = 0
	for segment_index: int in range(section_range.x, section_range.y + 1, 4):
		var a: Vector3 = _route[segment_index]
		var b: Vector3 = _route[min(segment_index + 1, _route.size() - 1)]
		var forward: Vector3 = b - a
		forward.y = 0.0
		if forward.length_squared() <= 0.001:
			forward = Vector3.FORWARD
		forward = forward.normalized()
		var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
		var width: float = _track.get_v2_width_for_segment(segment_index)
		for side: float in [-1.0, 1.0]:
			var offset: float = side * (width * 0.5 + 6.5 + float(tree_index % 3) * 2.2)
			var base: Vector3 = a + right * offset
			var height: float = 5.0 + float(tree_index % 4) * 0.75
			trunks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.55, height, 0.55)), base + Vector3.UP * (height * 0.5)))
			crowns.append(Transform3D(Basis.IDENTITY.scaled(Vector3(3.3, 3.8, 3.3)), base + Vector3.UP * (height + 1.4)))
			bushes.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.7, 1.0, 1.7)), base + right * side * 2.4 + Vector3.UP * 0.5))
			tree_index += 1
	_add_box_multimesh(prefix + "Trunks", trunks, _wood_material())
	_add_sphere_multimesh(prefix + "Crowns", crowns, _leaf_material())
	_add_sphere_multimesh(prefix + "Bushes", bushes, _bush_material())

func _build_river_reeds() -> void:
	if not _ranges.has(&"long_river"):
		return
	var section_range: Vector2i = _ranges[&"long_river"] as Vector2i
	var reeds: Array[Transform3D] = []
	var stones: Array[Transform3D] = []
	for segment_index: int in range(section_range.x, section_range.y + 1, 3):
		var a: Vector3 = _route[segment_index]
		var b: Vector3 = _route[min(segment_index + 1, _route.size() - 1)]
		var forward: Vector3 = b - a
		forward.y = 0.0
		if forward.length_squared() <= 0.001:
			forward = Vector3.FORWARD
		forward = forward.normalized()
		var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
		var width: float = _track.get_v2_width_for_segment(segment_index)
		for side: float in [-1.0, 1.0]:
			var bank: Vector3 = a + right * side * (width * 0.5 + 2.7)
			reeds.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.18, 1.8, 0.18)), bank + Vector3.UP * 0.9))
			if segment_index % 6 == 0:
				stones.append(Transform3D(Basis.IDENTITY.scaled(Vector3(2.4, 1.1, 2.0)), bank + right * side * 1.7 + Vector3.UP * 0.45))
	_add_box_multimesh("RiverReeds", reeds, _reed_material())
	_add_sphere_multimesh("RiverBankRocks", stones, _rock_material())

func _build_mountain_cliffs() -> void:
	var transforms: Array[Transform3D] = []
	for section_id: StringName in [&"mountain_approach", &"mountain_ascent", &"summit_ridge"]:
		if not _ranges.has(section_id):
			continue
		var section_range: Vector2i = _ranges[section_id] as Vector2i
		for segment_index: int in range(section_range.x, section_range.y + 1, 7):
			var placement: Dictionary = _placement(section_id, _segment_progress(section_range, segment_index), 0.0)
			if placement.is_empty():
				continue
			var right: Vector3 = placement["right"] as Vector3
			var base: Vector3 = placement["position"] as Vector3
			var width: float = _track.get_v2_width_for_segment(segment_index)
			for side: float in [-1.0, 1.0]:
				var cliff_height: float = 12.0 + float(segment_index % 5) * 2.4
				transforms.append(Transform3D(
					Basis.IDENTITY.scaled(Vector3(7.5, cliff_height, 6.4)),
					base + right * side * (width * 0.5 + 12.0) + Vector3.UP * (cliff_height * 0.5 - 1.5)
				))
	_add_sphere_multimesh("MountainRockLayers", transforms, _rock_material())

func _build_canyon_walls() -> void:
	if not _ranges.has(&"canyon_obstacle"):
		return
	var section_range: Vector2i = _ranges[&"canyon_obstacle"] as Vector2i
	var walls: Array[Transform3D] = []
	for segment_index: int in range(section_range.x, section_range.y + 1, 4):
		var a: Vector3 = _route[segment_index]
		var b: Vector3 = _route[min(segment_index + 1, _route.size() - 1)]
		var forward: Vector3 = b - a
		forward.y = 0.0
		if forward.length_squared() <= 0.001:
			forward = Vector3.FORWARD
		forward = forward.normalized()
		var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
		var width: float = _track.get_v2_width_for_segment(segment_index)
		for side: float in [-1.0, 1.0]:
			walls.append(Transform3D(
				Basis.IDENTITY.scaled(Vector3(7.0, 13.0 + float(segment_index % 3) * 2.0, 8.0)),
				a + right * side * (width * 0.5 + 10.5) + Vector3.UP * 5.2
			))
	_add_sphere_multimesh("CanyonCliffWalls", walls, _canyon_material())

func _build_finale_landmarks() -> void:
	var placement: Dictionary = _placement(&"final_sprint", 0.94, 0.0)
	if placement.is_empty():
		return
	var base: Vector3 = placement["position"] as Vector3
	var right: Vector3 = placement["right"] as Vector3
	var forward: Vector3 = placement["forward"] as Vector3
	var segment_index: int = int(placement["segment_index"])
	var width: float = _track.get_v2_width_for_segment(segment_index)
	var pieces: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		pieces.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.55, 5.8, 0.55)), base + right * side * (width * 0.5 - 1.1) + Vector3.UP * 2.9))
	pieces.append(Transform3D(Basis.IDENTITY.scaled(Vector3(width - 2.2, 0.55, 0.70)), base + Vector3.UP * 5.55))
	_add_box_multimesh("FinalGrandGate", pieces, _finish_material())

	var flags: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		for step: int in range(4):
			flags.append(Transform3D(
				Basis.IDENTITY.scaled(Vector3(0.9, 0.75, 0.08)),
				base - forward * float(step * 12) + right * side * (width * 0.5 - 0.8) + Vector3.UP * 3.4
			))
	_add_box_multimesh("FinalFlags", flags, _flag_material())

func _segment_progress(section_range: Vector2i, segment_index: int) -> float:
	var denominator: float = maxf(1.0, float(section_range.y - section_range.x))
	return clampf(float(segment_index - section_range.x) / denominator, 0.0, 1.0)

func _hazard_speed_scale() -> float:
	if GameManager.difficulty == &"wild":
		return 0.72
	if GameManager.difficulty == &"nightmare":
		return 1.22
	return 1.0

func _find_v2_track(node: Node) -> WildDashGrandPrixV2Track:
	if node is WildDashGrandPrixV2Track:
		return node as WildDashGrandPrixV2Track
	for child: Node in node.get_children():
		var found: WildDashGrandPrixV2Track = _find_v2_track(child)
		if found != null:
			return found
	return null

func _add_box_multimesh(node_name: String, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	_add_multimesh(node_name, mesh, transforms, material)

func _add_sphere_multimesh(node_name: String, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 7
	mesh.rings = 4
	_add_multimesh(node_name, mesh, transforms, material)

func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], material: Material) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	multimesh.custom_aabb = AABB(Vector3(-340.0, -40.0, -1980.0), Vector3(680.0, 170.0, 2200.0))
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	_root_environment.add_child(instance)

func _simple_material(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _rock_material() -> Material:
	return _simple_material(Color(0.31, 0.33, 0.34), 0.94)

func _canyon_material() -> Material:
	return _simple_material(Color(0.38, 0.24, 0.16), 0.95)

func _wood_material() -> Material:
	return _simple_material(Color(0.30, 0.17, 0.075), 0.90)

func _mud_material() -> Material:
	return _simple_material(Color(0.18, 0.095, 0.05), 0.99)

func _leaf_material() -> Material:
	return _simple_material(Color(0.11, 0.37, 0.16), 0.88)

func _bush_material() -> Material:
	return _simple_material(Color(0.18, 0.46, 0.18), 0.91)

func _reed_material() -> Material:
	return _simple_material(Color(0.38, 0.52, 0.12), 0.90)

func _finish_material() -> StandardMaterial3D:
	var material := _simple_material(Color(0.08, 0.82, 0.72), 0.44)
	material.metallic = 0.15
	return material

func _flag_material() -> StandardMaterial3D:
	var material := _simple_material(Color(1.0, 0.42, 0.08), 0.46)
	material.emission_enabled = true
	material.emission = Color(0.55, 0.12, 0.02)
	material.emission_energy_multiplier = 0.65
	return material
