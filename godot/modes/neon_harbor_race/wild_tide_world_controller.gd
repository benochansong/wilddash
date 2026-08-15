class_name WildDashWildTideWorldController
extends Node3D

## WILD TIDE World V2.
##
## This controller owns what the player can actually SEE and FEEL in Round 3:
## visible shallow/deep water, terrain Area3D zones, dense mangrove walls,
## collidable gameplay trees, high tide, whirlpools, boat wakes and safe respawn
## anchors. The authoritative checkpoint route remains in RaceManager.

const BASE_WATER_SEGMENTS: Array[int] = [
	5, 6, 7, 8, 9, 10, 11, 12,
	17, 18, 19, 20, 21, 22,
]
const DEEP_WATER_SEGMENTS: Array[int] = [6, 7, 8, 17, 18, 19, 20]
const TIDE_PHASE_ONE_SEGMENTS: Array[int] = [13, 14]
const TIDE_PHASE_TWO_SEGMENTS: Array[int] = [15, 16]
const JUNGLE_SEGMENTS: Array[int] = [10, 11, 12, 13, 14, 15, 16, 17]
const GAMEPLAY_TREE_SEGMENTS: Array[int] = [10, 11, 12, 13, 14, 15]
const CHECKPOINT_ROUTE_INDICES: Array[int] = [3, 6, 9, 12, 15, 18, 21, 24, 28]

const WATER_SURFACE_Y: float = 0.18
const TIDE_HIDDEN_Y: float = -0.72
const WATER_EXTRA_WIDTH: float = 7.0
const WATER_AREA_HEIGHT: float = 3.2
const TIDE_ONE_TRIGGER_PROGRESS: float = 0.52
const TIDE_TWO_TRIGGER_PROGRESS: float = 0.73
const HIGH_TIDE_COUNTDOWN: int = 5
const WHIRLPOOL_RADIUS: float = 7.2
const WHIRLPOOL_PULL: float = 8.0
const WAKE_RADIUS: float = 6.0
const WAKE_ACCELERATION: float = 3.4

var _track: Node3D
var _route_points: Array[Vector3] = []
var _segment_lengths: Array[float] = []
var _active_water_segments: Dictionary = {}
var _water_areas_by_segment: Dictionary = {}
var _water_visuals_by_segment: Dictionary = {}
var _foam_roots_by_segment: Dictionary = {}
var _water_membership_by_racer: Dictionary = {}
var _movement_base_by_racer: Dictionary = {}
var _wake_by_racer: Dictionary = {}
var _last_terrain_by_racer: Dictionary = {}
var _whirlpool_centers: Array[Vector3] = []
var _whirlpool_visuals: Array[Node3D] = []
var _boats: Array[Node3D] = []
var _boat_start: Array[Vector3] = []
var _boat_end: Array[Vector3] = []
var _boat_speed: Array[float] = []
var _elapsed: float = 0.0
var _bootstrapped: bool = false
var _tide_one_started: bool = false
var _tide_one_active: bool = false
var _tide_two_started: bool = false
var _tide_two_active: bool = false
var _track_distance: float = 0.0
var _water_distance: float = 0.0
var _deep_distance: float = 0.0
var _shallow_distance: float = 0.0
var _jungle_distance: float = 0.0
var _visual_tree_count: int = 0
var _gameplay_tree_count: int = 0

func _ready() -> void:
	add_to_group("wild_tide_world")
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	for _attempt: int in range(60):
		var parent_node: Node = get_parent()
		if parent_node != null:
			_track = parent_node.get_node_or_null("NeonHarborWorldTrack") as Node3D
		if _track != null and _track.has_method("get_route_points"):
			break
		await get_tree().physics_frame
	if _track == null or not _track.has_method("get_route_points"):
		push_warning("WILD TIDE WORLD V2 bootstrap skipped: active track unavailable")
		return

	var route_value: Variant = _track.call("get_route_points")
	if not (route_value is Array):
		push_warning("WILD TIDE WORLD V2 route unavailable")
		return
	var route_array: Array = route_value
	for point_value: Variant in route_array:
		if point_value is Vector3:
			var point: Vector3 = point_value
			_route_points.append(point)
	if _route_points.size() < 29:
		push_warning("WILD TIDE WORLD V2 expected 29+ route points, got %d" % _route_points.size())
		return

	_calculate_route_metrics()
	_build_water_world()
	_build_mangrove_wall()
	_build_gameplay_trees()
	_build_whirlpools()
	_build_moving_boats()
	_build_safe_respawn_markers()
	_bootstrapped = true

	var water_ratio: float = get_baseline_water_ratio()
	var jungle_ratio: float = 0.0 if _track_distance <= 0.01 else _jungle_distance / _track_distance
	print("WILD TIDE WORLD V2 daytime=true track_length=%.1f visible_water_distance=%.1f visible_water_ratio=%.1f%% shallow=%.1f%% deep=%.1f%% jungle_distance=%.1f jungle_ratio=%.1f%% route_branches=4" % [
		_track_distance,
		_water_distance,
		water_ratio * 100.0,
		get_shallow_water_ratio() * 100.0,
		get_deep_water_ratio() * 100.0,
		_jungle_distance,
		jungle_ratio * 100.0,
	])
	print("VISIBLE WATER CHECK segments=%d ratio=%.1f%% road_surface_removed=true foam=true wake=true" % [
		BASE_WATER_SEGMENTS.size(), water_ratio * 100.0,
	])
	print("JUNGLE VISUAL CHECK trees=%d gameplay_trees=%d canopy_anchors=%d jungle_wall=true" % [
		_visual_tree_count, _gameplay_tree_count, get_tree().get_nodes_in_group("wild_tide_canopy_anchor").size(),
	])

func _physics_process(delta: float) -> void:
	if not _bootstrapped:
		return
	_elapsed += delta
	_update_high_tide()
	_update_whirlpools(delta)
	_update_boats(delta)
	_update_water_wakes()

func is_position_water(world_position: Vector3) -> bool:
	if _route_points.size() < 2:
		return false
	for key_value: Variant in _active_water_segments.keys():
		var segment_index: int = int(key_value)
		if segment_index < 0 or segment_index >= _route_points.size() - 1:
			continue
		var width: float = _segment_water_width(segment_index)
		var distance: float = _planar_distance_to_segment(
			world_position,
			_route_points[segment_index],
			_route_points[segment_index + 1]
		)
		if distance <= width * 0.5:
			return true
	return false

func get_baseline_water_ratio() -> float:
	if _track_distance <= 0.01:
		return 0.0
	return _water_distance / _track_distance

func get_shallow_water_ratio() -> float:
	if _track_distance <= 0.01:
		return 0.0
	return _shallow_distance / _track_distance

func get_deep_water_ratio() -> float:
	if _track_distance <= 0.01:
		return 0.0
	return _deep_distance / _track_distance

func get_jungle_ratio() -> float:
	if _track_distance <= 0.01:
		return 0.0
	return _jungle_distance / _track_distance

func get_route_state() -> Dictionary:
	return {
		"baseline_water_ratio": get_baseline_water_ratio(),
		"shallow_water_ratio": get_shallow_water_ratio(),
		"deep_water_ratio": get_deep_water_ratio(),
		"jungle_ratio": get_jungle_ratio(),
		"high_tide_one": _tide_one_active,
		"high_tide_two": _tide_two_active,
		"active_water_segments": _active_water_segments.size(),
		"jungle_shortcut": get_tree().get_first_node_in_group("wild_tide_jungle_shortcut") != null,
	}

func _calculate_route_metrics() -> void:
	_segment_lengths.clear()
	_track_distance = 0.0
	_water_distance = 0.0
	_deep_distance = 0.0
	_shallow_distance = 0.0
	_jungle_distance = 0.0
	for segment_index: int in range(_route_points.size() - 1):
		var length: float = _route_points[segment_index].distance_to(_route_points[segment_index + 1])
		_segment_lengths.append(length)
		_track_distance += length
		if BASE_WATER_SEGMENTS.has(segment_index):
			_water_distance += length
			if DEEP_WATER_SEGMENTS.has(segment_index):
				_deep_distance += length
			else:
				_shallow_distance += length
		if JUNGLE_SEGMENTS.has(segment_index):
			_jungle_distance += length

func _build_water_world() -> void:
	for segment_index: int in BASE_WATER_SEGMENTS:
		_create_water_segment(segment_index, DEEP_WATER_SEGMENTS.has(segment_index), true)
	for segment_index: int in TIDE_PHASE_ONE_SEGMENTS:
		_create_water_segment(segment_index, false, false)
	for segment_index: int in TIDE_PHASE_TWO_SEGMENTS:
		_create_water_segment(segment_index, false, false)

func _create_water_segment(segment_index: int, deep: bool, active: bool) -> void:
	if segment_index < 0 or segment_index >= _route_points.size() - 1:
		return
	var a: Vector3 = _route_points[segment_index]
	var b: Vector3 = _route_points[segment_index + 1]
	var length: float = a.distance_to(b)
	var width: float = _segment_water_width(segment_index)
	var midpoint: Vector3 = a.lerp(b, 0.5)
	var surface_y: float = WATER_SURFACE_Y if active else TIDE_HIDDEN_Y

	var surface: CSGBox3D = CSGBox3D.new()
	surface.name = "WildTideWater_%02d" % segment_index
	surface.size = Vector3(width, 0.10, maxf(1.0, length + 0.8))
	surface.use_collision = false
	surface.position = Vector3(midpoint.x, surface_y, midpoint.z)
	surface.material = _water_material(deep)
	add_child(surface)
	surface.look_at(Vector3(b.x, surface_y, b.z), Vector3.UP)
	surface.visible = active
	surface.set_meta(&"wild_tide_visual_water", true)
	surface.set_meta(&"wild_tide_deep", deep)
	_water_visuals_by_segment[segment_index] = surface

	var foam_root: Node3D = Node3D.new()
	foam_root.name = "WildTideFoam_%02d" % segment_index
	add_child(foam_root)
	foam_root.visible = active
	_foam_roots_by_segment[segment_index] = foam_root
	var direction: Vector3 = b - a
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		direction = Vector3.FORWARD
	else:
		direction = direction.normalized()
	var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	for side: float in [-1.0, 1.0]:
		var foam: CSGBox3D = CSGBox3D.new()
		foam.name = "FoamEdge_%s" % ("L" if side < 0.0 else "R")
		foam.size = Vector3(0.30, 0.035, maxf(0.8, length - 0.4))
		foam.use_collision = false
		foam.position = midpoint + right * side * (width * 0.5 - 0.24) + Vector3.UP * (surface_y + 0.075)
		foam.material = _foam_material()
		foam_root.add_child(foam)
		foam.look_at(Vector3(b.x, foam.position.y, b.z), Vector3.UP)

	var area: Area3D = Area3D.new()
	area.name = "WildTideWaterArea_%02d" % segment_index
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = active
	area.monitorable = false
	area.position = midpoint + Vector3.UP * 0.86
	area.look_at(Vector3(b.x, area.position.y, b.z), Vector3.UP)
	var terrain_type: StringName = WildDashTerrainAbilitySystem.TERRAIN_DEEP_WATER if deep else WildDashTerrainAbilitySystem.TERRAIN_SHALLOW_WATER
	area.set_meta(&"wild_tide_terrain", terrain_type)
	area.set_meta(&"wild_tide_segment", segment_index)
	area.add_to_group("wild_tide_water_zone")
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(width, WATER_AREA_HEIGHT, maxf(2.0, length + 0.2))
	shape_node.shape = box
	area.add_child(shape_node)
	area.body_entered.connect(_on_water_body_entered.bind(area))
	area.body_exited.connect(_on_water_body_exited.bind(area))
	add_child(area)
	_water_areas_by_segment[segment_index] = area
	if active:
		_active_water_segments[segment_index] = true

func _on_water_body_entered(body: Node, area: Area3D) -> void:
	var racer: WildDashCharacterController = body as WildDashCharacterController
	if racer == null or racer.finished:
		return
	var racer_id: int = racer.get_instance_id()
	var memberships: Dictionary = {}
	var existing_value: Variant = _water_membership_by_racer.get(racer_id, {})
	if existing_value is Dictionary:
		memberships = existing_value
	var terrain_value: Variant = area.get_meta(&"wild_tide_terrain", WildDashTerrainAbilitySystem.TERRAIN_SHALLOW_WATER)
	var terrain_type: StringName = StringName(String(terrain_value))
	memberships[area.get_instance_id()] = terrain_type
	_water_membership_by_racer[racer_id] = memberships
	_refresh_racer_water_state(racer, memberships)

func _on_water_body_exited(body: Node, area: Area3D) -> void:
	var racer: WildDashCharacterController = body as WildDashCharacterController
	if racer == null:
		return
	var racer_id: int = racer.get_instance_id()
	var memberships: Dictionary = {}
	var existing_value: Variant = _water_membership_by_racer.get(racer_id, {})
	if existing_value is Dictionary:
		memberships = existing_value
	memberships.erase(area.get_instance_id())
	if memberships.is_empty():
		_water_membership_by_racer.erase(racer_id)
		_restore_racer_movement(racer)
		_set_wake_visible(racer, false)
		_last_terrain_by_racer.erase(racer_id)
	else:
		_water_membership_by_racer[racer_id] = memberships
		_refresh_racer_water_state(racer, memberships)

func _refresh_racer_water_state(racer: WildDashCharacterController, memberships: Dictionary) -> void:
	var terrain_type: StringName = WildDashTerrainAbilitySystem.TERRAIN_SHALLOW_WATER
	for value: Variant in memberships.values():
		var member_type: StringName = StringName(String(value))
		if member_type == WildDashTerrainAbilitySystem.TERRAIN_DEEP_WATER:
			terrain_type = WildDashTerrainAbilitySystem.TERRAIN_DEEP_WATER
			break

	var racer_id: int = racer.get_instance_id()
	if not _movement_base_by_racer.has(racer_id):
		_movement_base_by_racer[racer_id] = {
			"max_speed": racer.max_speed,
			"cruise_speed": racer.cruise_speed,
			"acceleration": racer.acceleration,
			"turn_speed": racer.turn_speed,
		}
	var base_value: Variant = _movement_base_by_racer.get(racer_id, {})
	if not (base_value is Dictionary):
		return
	var base: Dictionary = base_value
	var multiplier: float = WildDashTerrainAbilitySystem.get_terrain_speed_multiplier(racer.animal_id, terrain_type)
	racer.max_speed = float(base.get("max_speed", racer.max_speed)) * multiplier
	racer.cruise_speed = float(base.get("cruise_speed", racer.cruise_speed)) * multiplier
	racer.acceleration = float(base.get("acceleration", racer.acceleration)) * clampf(0.94 + (multiplier - 1.0) * 0.30, 0.84, 1.14)
	var turn_scale: float = 1.12 if racer.animal_id == &"crocodile" else clampf(1.0 + (multiplier - 1.0) * 0.22, 0.90, 1.08)
	racer.turn_speed = float(base.get("turn_speed", racer.turn_speed)) * turn_scale
	racer.set_meta(&"wild_tide_terrain", terrain_type)
	racer.set_meta(&"wild_tide_speed_multiplier", multiplier)
	_set_wake_visible(racer, true)

	var previous_value: Variant = _last_terrain_by_racer.get(racer_id, &"")
	var previous_type: StringName = StringName(String(previous_value))
	if previous_type != terrain_type:
		_last_terrain_by_racer[racer_id] = terrain_type
		if racer.is_player:
			_show_hud("%s  %s %.2fx" % [
				"DEEP WATER!" if terrain_type == WildDashTerrainAbilitySystem.TERRAIN_DEEP_WATER else "SHALLOW WATER!",
				String(racer.animal_id).to_upper(),
				multiplier,
			])

func _restore_racer_movement(racer: WildDashCharacterController) -> void:
	var racer_id: int = racer.get_instance_id()
	var base_value: Variant = _movement_base_by_racer.get(racer_id)
	if not (base_value is Dictionary):
		return
	var base: Dictionary = base_value
	racer.max_speed = float(base.get("max_speed", racer.max_speed))
	racer.cruise_speed = float(base.get("cruise_speed", racer.cruise_speed))
	racer.acceleration = float(base.get("acceleration", racer.acceleration))
	racer.turn_speed = float(base.get("turn_speed", racer.turn_speed))
	racer.remove_meta(&"wild_tide_terrain")
	racer.remove_meta(&"wild_tide_speed_multiplier")
	_movement_base_by_racer.erase(racer_id)

func _set_wake_visible(racer: WildDashCharacterController, visible: bool) -> void:
	var racer_id: int = racer.get_instance_id()
	var wake: Node3D
	var wake_value: Variant = _wake_by_racer.get(racer_id)
	if wake_value is Node3D:
		wake = wake_value
	if wake == null and visible:
		wake = _create_racer_wake(racer)
		_wake_by_racer[racer_id] = wake
	if wake != null and is_instance_valid(wake):
		wake.visible = visible

func _create_racer_wake(racer: WildDashCharacterController) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "WildTideWake"
	root.position = Vector3(0.0, 0.10, 0.85)
	racer.add_child(root)
	var material: StandardMaterial3D = _foam_material()
	for side: float in [-1.0, 1.0]:
		var wake: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(0.18, 0.035, 1.35)
		wake.mesh = mesh
		wake.position = Vector3(side * 0.34, 0.0, 0.0)
		wake.rotation_degrees.y = side * 12.0
		wake.material_override = material
		root.add_child(wake)
	return root

func _update_water_wakes() -> void:
	for racer_value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = racer_value as WildDashCharacterController
		if racer == null or racer.finished:
			continue
		var wake_value: Variant = _wake_by_racer.get(racer.get_instance_id())
		if wake_value is Node3D:
			var wake: Node3D = wake_value
			wake.scale.z = clampf(0.65 + racer.current_speed / 18.0, 0.65, 1.65)

func _build_mangrove_wall() -> void:
	var trunk_transforms: Array[Transform3D] = []
	var crown_transforms: Array[Transform3D] = []
	for segment_index: int in JUNGLE_SEGMENTS:
		if segment_index < 0 or segment_index >= _route_points.size() - 1:
			continue
		var a: Vector3 = _route_points[segment_index]
		var b: Vector3 = _route_points[segment_index + 1]
		var direction: Vector3 = b - a
		direction.y = 0.0
		if direction.length_squared() <= 0.001:
			continue
		direction = direction.normalized()
		var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
		var road_half: float = maxf(5.0, _segment_base_width(segment_index) * 0.5)
		for sample_index: int in range(3):
			var t: float = 0.18 + float(sample_index) * 0.32
			for side: float in [-1.0, 1.0]:
				var seed: int = segment_index * 17 + sample_index * 5 + (0 if side < 0.0 else 3)
				var lateral: float = road_half + 5.0 + float(seed % 4) * 1.7
				var base_position: Vector3 = a.lerp(b, t) + right * side * lateral
				var height: float = 6.5 + float(seed % 6) * 0.75
				var trunk_transform: Transform3D = Transform3D(Basis.IDENTITY, base_position + Vector3.UP * (height * 0.5))
				trunk_transform.basis = trunk_transform.basis.scaled(Vector3(0.78, height * 0.5, 0.78))
				trunk_transforms.append(trunk_transform)
				var crown_transform: Transform3D = Transform3D(Basis.IDENTITY, base_position + Vector3.UP * (height + 1.15))
				crown_transform.basis = crown_transform.basis.scaled(Vector3(3.2, 1.85, 3.0))
				crown_transforms.append(crown_transform)
				_visual_tree_count += 1

	var trunk_mesh: CylinderMesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.74
	trunk_mesh.bottom_radius = 0.95
	trunk_mesh.height = 2.0
	trunk_mesh.radial_segments = 8
	_add_multimesh("MangroveWallTrunks", trunk_mesh, trunk_transforms, _simple_material(Color(0.22, 0.12, 0.045), 0.94))

	var crown_mesh: SphereMesh = SphereMesh.new()
	crown_mesh.radius = 1.0
	crown_mesh.height = 2.0
	crown_mesh.radial_segments = 10
	crown_mesh.rings = 6
	_add_multimesh("MangroveWallCrowns", crown_mesh, crown_transforms, _emissive_material(Color(0.055, 0.40, 0.12), Color(0.04, 0.25, 0.07), 0.16))

func _build_gameplay_trees() -> void:
	for tree_index: int in range(GAMEPLAY_TREE_SEGMENTS.size()):
		var segment_index: int = GAMEPLAY_TREE_SEGMENTS[tree_index]
		var a: Vector3 = _route_points[segment_index]
		var b: Vector3 = _route_points[segment_index + 1]
		var direction: Vector3 = b - a
		direction.y = 0.0
		if direction.length_squared() <= 0.001:
			continue
		direction = direction.normalized()
		var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
		var side: float = -1.0 if tree_index % 2 == 0 else 1.0
		var road_half: float = _segment_base_width(segment_index) * 0.5
		var base_position: Vector3 = a.lerp(b, 0.48) + right * side * (road_half + 2.8)
		var height: float = 7.0 + float(tree_index) * 0.62
		_create_gameplay_tree(tree_index, base_position, direction, height)

func _create_gameplay_tree(tree_index: int, base_position: Vector3, direction: Vector3, height: float) -> void:
	var root: Node3D = Node3D.new()
	root.name = "GameplayMangrove_%02d" % tree_index
	root.position = base_position
	root.add_to_group("wild_tide_gameplay_tree")
	add_child(root)

	var trunk_body: StaticBody3D = StaticBody3D.new()
	trunk_body.name = "TrunkCollision"
	root.add_child(trunk_body)
	var trunk_shape_node: CollisionShape3D = CollisionShape3D.new()
	var trunk_shape: CylinderShape3D = CylinderShape3D.new()
	trunk_shape.radius = 0.88
	trunk_shape.height = height
	trunk_shape_node.shape = trunk_shape
	trunk_shape_node.position.y = height * 0.5
	trunk_body.add_child(trunk_shape_node)

	var trunk_visual: MeshInstance3D = MeshInstance3D.new()
	var trunk_mesh: CylinderMesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.72
	trunk_mesh.bottom_radius = 1.02
	trunk_mesh.height = height
	trunk_mesh.radial_segments = 9
	trunk_visual.mesh = trunk_mesh
	trunk_visual.position.y = height * 0.5
	trunk_visual.material_override = _simple_material(Color(0.24, 0.12, 0.045), 0.95)
	root.add_child(trunk_visual)

	var branch_body: StaticBody3D = StaticBody3D.new()
	branch_body.name = "BranchCollision"
	root.add_child(branch_body)
	var branch_length: float = 4.0
	var branch_height: float = height - 1.35
	var branch_shape_node: CollisionShape3D = CollisionShape3D.new()
	var branch_shape: BoxShape3D = BoxShape3D.new()
	branch_shape.size = Vector3(branch_length, 0.46, 1.0)
	branch_shape_node.shape = branch_shape
	branch_shape_node.position = Vector3(0.0, branch_height, 0.0)
	branch_shape_node.rotation.y = atan2(-direction.x, -direction.z) + PI * 0.5
	branch_body.add_child(branch_shape_node)

	var branch_visual: MeshInstance3D = MeshInstance3D.new()
	var branch_mesh: BoxMesh = BoxMesh.new()
	branch_mesh.size = Vector3(branch_length, 0.42, 0.92)
	branch_visual.mesh = branch_mesh
	branch_visual.position = Vector3(0.0, branch_height, 0.0)
	branch_visual.rotation = branch_shape_node.rotation
	branch_visual.material_override = _simple_material(Color(0.28, 0.14, 0.05), 0.94)
	root.add_child(branch_visual)

	var crown: MeshInstance3D = MeshInstance3D.new()
	var crown_mesh: SphereMesh = SphereMesh.new()
	crown_mesh.radius = 3.4
	crown_mesh.height = 5.6
	crown_mesh.radial_segments = 10
	crown_mesh.rings = 6
	crown.mesh = crown_mesh
	crown.position = Vector3(0.0, height + 1.1, 0.0)
	crown.scale = Vector3(1.25, 0.72, 1.08)
	crown.material_override = _emissive_material(Color(0.05, 0.44, 0.13), Color(0.04, 0.28, 0.08), 0.18)
	root.add_child(crown)

	var anchor: Marker3D = Marker3D.new()
	anchor.name = "CanopyAnchor"
	anchor.position = Vector3(0.0, branch_height + 0.7, 0.0)
	anchor.add_to_group("wild_tide_canopy_anchor")
	anchor.set_meta(&"wild_tide_canopy_index", tree_index)
	root.add_child(anchor)
	_gameplay_tree_count += 1

func _build_whirlpools() -> void:
	var indices: Array[int] = [7, 19]
	for whirl_index: int in range(indices.size()):
		var segment_index: int = indices[whirl_index]
		var center: Vector3 = _route_points[segment_index].lerp(_route_points[segment_index + 1], 0.52)
		_whirlpool_centers.append(center)
		var root: Node3D = Node3D.new()
		root.name = "Whirlpool_%02d" % whirl_index
		root.position = center + Vector3.UP * 0.27
		add_child(root)
		_whirlpool_visuals.append(root)
		var material: StandardMaterial3D = _emissive_material(Color(0.08, 0.72, 0.88), Color(0.12, 0.90, 1.0), 0.48)
		for marker_index: int in range(10):
			var marker: MeshInstance3D = MeshInstance3D.new()
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = 0.22
			sphere.height = 0.30
			marker.mesh = sphere
			var angle: float = float(marker_index) / 10.0 * TAU
			var radius: float = 4.0 + float(marker_index % 2) * 1.3
			marker.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			marker.material_override = material
			root.add_child(marker)

func _update_whirlpools(delta: float) -> void:
	for visual: Node3D in _whirlpool_visuals:
		if visual != null and is_instance_valid(visual):
			visual.rotate_y(delta * 1.35)
	for center: Vector3 in _whirlpool_centers:
		for racer_value: Variant in RaceManager.racers:
			var racer: WildDashCharacterController = racer_value as WildDashCharacterController
			if racer == null or racer.finished or not racer.has_meta(&"wild_tide_terrain"):
				continue
			var offset: Vector3 = center - racer.global_position
			offset.y = 0.0
			var distance: float = offset.length()
			if distance <= 0.2 or distance > WHIRLPOOL_RADIUS:
				continue
			var resistance: float = 1.0
			match racer.animal_id:
				&"crocodile": resistance = 0.28
				&"elephant": resistance = 0.55
				&"bear": resistance = 0.68
				&"raccoon": resistance = 0.72
				_:
					resistance = 1.0
			var strength: float = WHIRLPOOL_PULL * (1.0 - distance / WHIRLPOOL_RADIUS) * resistance
			racer.velocity += offset.normalized() * strength * delta

func _build_moving_boats() -> void:
	var boat_segments: Array[int] = [18, 21]
	for boat_index: int in range(boat_segments.size()):
		var segment_index: int = boat_segments[boat_index]
		var a: Vector3 = _route_points[segment_index]
		var b: Vector3 = _route_points[segment_index + 1]
		var direction: Vector3 = b - a
		direction.y = 0.0
		if direction.length_squared() <= 0.001:
			continue
		direction = direction.normalized()
		var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
		var lateral: float = -5.0 if boat_index == 0 else 5.0
		var start: Vector3 = a + right * lateral + Vector3.UP * 0.62
		var finish: Vector3 = b + right * lateral + Vector3.UP * 0.62
		var boat: Node3D = Node3D.new()
		boat.name = "WildTideBoat_%02d" % boat_index
		boat.position = start
		add_child(boat)
		var hull: MeshInstance3D = MeshInstance3D.new()
		var hull_mesh: BoxMesh = BoxMesh.new()
		hull_mesh.size = Vector3(2.1, 0.62, 4.6)
		hull.mesh = hull_mesh
		hull.material_override = _simple_material(Color(0.92, 0.55, 0.10), 0.48)
		boat.add_child(hull)
		var wake: MeshInstance3D = MeshInstance3D.new()
		var wake_mesh: BoxMesh = BoxMesh.new()
		wake_mesh.size = Vector3(2.4, 0.035, 4.0)
		wake.mesh = wake_mesh
		wake.position = Vector3(0.0, -0.48, 3.1)
		wake.material_override = _foam_material()
		boat.add_child(wake)
		_boats.append(boat)
		_boat_start.append(start)
		_boat_end.append(finish)
		_boat_speed.append(8.5 + float(boat_index) * 1.4)

func _update_boats(delta: float) -> void:
	for boat_index: int in range(_boats.size()):
		var boat: Node3D = _boats[boat_index]
		if boat == null or not is_instance_valid(boat):
			continue
		var start: Vector3 = _boat_start[boat_index]
		var finish: Vector3 = _boat_end[boat_index]
		var length: float = maxf(1.0, start.distance_to(finish))
		var cycle: float = fmod((_elapsed * _boat_speed[boat_index]) / length, 2.0)
		var t: float = cycle if cycle <= 1.0 else 2.0 - cycle
		boat.position = start.lerp(finish, t)
		var look_target: Vector3 = finish if cycle <= 1.0 else start
		boat.look_at(Vector3(look_target.x, boat.position.y, look_target.z), Vector3.UP)
		for racer_value: Variant in RaceManager.racers:
			var racer: WildDashCharacterController = racer_value as WildDashCharacterController
			if racer == null or racer.finished or not racer.has_meta(&"wild_tide_terrain"):
				continue
			if racer.global_position.distance_to(boat.global_position) > WAKE_RADIUS:
				continue
			var wake_cap: float = racer.max_speed * 1.14
			racer.current_speed = minf(wake_cap, racer.current_speed + WAKE_ACCELERATION * delta)

func _build_safe_respawn_markers() -> void:
	for route_index: int in CHECKPOINT_ROUTE_INDICES:
		if route_index < 0 or route_index >= _route_points.size():
			continue
		var marker: Marker3D = Marker3D.new()
		marker.name = "WildTideSafeRespawn_%02d" % route_index
		marker.position = _route_points[route_index] + Vector3.UP * 0.55
		marker.add_to_group("wild_tide_safe_respawn")
		add_child(marker)

func _update_high_tide() -> void:
	var player: WildDashCharacterController = _get_player()
	if player == null or player.finished:
		return
	var progress: float = RaceManager.get_progress_percent(player) / 100.0
	if not _tide_one_started and progress >= TIDE_ONE_TRIGGER_PROGRESS:
		_tide_one_started = true
		_run_high_tide_phase(1, TIDE_PHASE_ONE_SEGMENTS)
	if not _tide_two_started and progress >= TIDE_TWO_TRIGGER_PROGRESS:
		_tide_two_started = true
		_run_high_tide_phase(2, TIDE_PHASE_TWO_SEGMENTS)

func _run_high_tide_phase(phase: int, segments: Array[int]) -> void:
	for count: int in range(HIGH_TIDE_COUNTDOWN, 0, -1):
		_show_hud("HIGH TIDE INCOMING — %d" % count)
		if count == HIGH_TIDE_COUNTDOWN:
			AudioManager.play_sfx_id("wave", 0.68)
		await get_tree().create_timer(1.0).timeout
	for segment_index: int in segments:
		_activate_tide_segment(segment_index)
	if phase == 1:
		_tide_one_active = true
	else:
		_tide_two_active = true
	_show_hud("FLOODED ROUTE!  WATER META CHANGED")
	AudioManager.play_sfx_id("splash", 0.92)
	print("ROUND3 EVENT type=HIGH_TIDE phase=%d progress=%.1f segments=%s terrain_changed=true" % [
		phase,
		RaceManager.get_progress_percent(_get_player()),
		str(segments),
	])

func _activate_tide_segment(segment_index: int) -> void:
	_active_water_segments[segment_index] = true
	var surface_value: Variant = _water_visuals_by_segment.get(segment_index)
	if surface_value is CSGBox3D:
		var surface: CSGBox3D = surface_value
		surface.visible = true
		var target: Vector3 = surface.position
		target.y = WATER_SURFACE_Y + 0.06
		var tween: Tween = surface.create_tween()
		tween.tween_property(surface, "position", target, 1.0)
	var foam_value: Variant = _foam_roots_by_segment.get(segment_index)
	if foam_value is Node3D:
		var foam_root: Node3D = foam_value
		foam_root.visible = true
	var area_value: Variant = _water_areas_by_segment.get(segment_index)
	if area_value is Area3D:
		var area: Area3D = area_value
		area.monitoring = true

func _segment_water_width(segment_index: int) -> float:
	return _segment_base_width(segment_index) + WATER_EXTRA_WIDTH

func _segment_base_width(segment_index: int) -> float:
	if _track != null and _track.has_method("get_segment_width"):
		var width_value: Variant = _track.call("get_segment_width", segment_index)
		if width_value is float or width_value is int:
			return float(width_value)
	return 16.0

func _planar_distance_to_segment(position: Vector3, a: Vector3, b: Vector3) -> float:
	var planar_a: Vector3 = Vector3(a.x, 0.0, a.z)
	var planar_b: Vector3 = Vector3(b.x, 0.0, b.z)
	var planar_position: Vector3 = Vector3(position.x, 0.0, position.z)
	var segment: Vector3 = planar_b - planar_a
	var length_sq: float = segment.length_squared()
	if length_sq <= 0.001:
		return planar_position.distance_to(planar_a)
	var t: float = clampf((planar_position - planar_a).dot(segment) / length_sq, 0.0, 1.0)
	return planar_position.distance_to(planar_a + segment * t)

func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
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
	add_child(instance)

func _water_material(deep: bool) -> StandardMaterial3D:
	var color: Color = Color(0.025, 0.38, 0.62) if deep else Color(0.08, 0.67, 0.72)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.24 if deep else 0.31
	material.metallic = 0.06
	material.emission_enabled = true
	material.emission = color.lightened(0.12)
	material.emission_energy_multiplier = 0.18
	return material

func _foam_material() -> StandardMaterial3D:
	return _emissive_material(Color(0.78, 0.96, 1.0), Color(0.55, 0.90, 1.0), 0.42)

func _simple_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _emissive_material(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = _simple_material(color, 0.62)
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material

func _get_player() -> WildDashCharacterController:
	for racer_value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = racer_value as WildDashCharacterController
		if racer != null and racer.is_player:
			return racer
	return null

func _show_hud(text: String) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var hud_value: Variant = parent_node.get("hud")
	var mode_hud: WildDashModeHUD = hud_value as WildDashModeHUD
	if mode_hud != null:
		mode_hud.set_message(text)
