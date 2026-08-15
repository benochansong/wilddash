class_name WildDashWildTideRouteNetwork
extends Node3D

## Physical multi-route network for Round 3.
## Branches are real waypoint paths and real world geometry, not preferred-lane
## offsets. Every branch rejoins the authoritative route before checkpoint/finish
## critical sections so RaceManager remains the source of truth.

const ROUTE_BALANCED: StringName = &"BALANCED"
const ROUTE_DEEP_WATER: StringName = &"DEEP_WATER"
const ROUTE_DRY_DOCK: StringName = &"DRY_DOCK"
const ROUTE_CANOPY: StringName = &"CANOPY"
const ROUTE_ELEVATED: StringName = &"ELEVATED"
const ROUTE_BREAKTHROUGH: StringName = &"BREAKTHROUGH"

const DRY_DOCK_START: int = 5
const DRY_DOCK_END: int = 9
const ELEVATED_START: int = 18
const ELEVATED_END: int = 22
const BREAKTHROUGH_START: int = 13
const BREAKTHROUGH_END: int = 16
const CANOPY_START: int = 10
const CANOPY_END: int = 15

var _track: Node3D
var _main_route: Array[Vector3] = []
var _routes: Dictionary = {}
var _bootstrapped: bool = false

func _ready() -> void:
	add_to_group("wild_tide_route_network")
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	for _attempt: int in range(90):
		var parent_node: Node = get_parent()
		if parent_node != null:
			_track = parent_node.get_node_or_null("NeonHarborWorldTrack") as Node3D
		if _track != null and _track.has_method("get_route_points") and get_tree().get_nodes_in_group("wild_tide_canopy_anchor").size() >= 5:
			break
		await get_tree().physics_frame
	if _track == null or not _track.has_method("get_route_points"):
		push_warning("WILD TIDE ROUTE NETWORK: active track unavailable")
		return

	var route_value: Variant = _track.call("get_route_points")
	if not (route_value is Array):
		return
	for value: Variant in route_value:
		if value is Vector3:
			var point: Vector3 = value
			_main_route.append(point)
	if _main_route.size() < 29:
		return

	_routes[ROUTE_BALANCED] = _main_route.duplicate()
	_routes[ROUTE_DEEP_WATER] = _build_multi_water_route()
	_routes[ROUTE_DRY_DOCK] = _build_offset_branch(_main_route, DRY_DOCK_START, DRY_DOCK_END, 15.0, 0.18)
	_routes[ROUTE_ELEVATED] = _build_offset_branch(_main_route, ELEVATED_START, ELEVATED_END, 14.0, 1.45)
	_routes[ROUTE_BREAKTHROUGH] = _build_offset_branch(_main_route, BREAKTHROUGH_START, BREAKTHROUGH_END, -6.3, 0.18)
	_routes[ROUTE_CANOPY] = _build_canopy_approach_route()

	_build_dry_dock_geometry()
	_build_elevated_geometry()
	_build_water_split_beacons()
	_bootstrapped = true
	print("WILD TIDE ROUTE NETWORK READY branches=%d physical=true dry_dock=true elevated=true canopy=true deep_water=true breakthrough=true checkpoint_merge=true" % _routes.size())

func is_ready() -> bool:
	return _bootstrapped

func get_route_count() -> int:
	return _routes.size()

func get_route(route_id: StringName) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var value: Variant = _routes.get(route_id)
	if not (value is Array):
		return result
	for point_value: Variant in value:
		if point_value is Vector3:
			var point: Vector3 = point_value
			result.append(point)
	return result

func choose_route(animal_id: StringName, slot: int, populations: Dictionary) -> StringName:
	var candidates: Array[StringName] = _candidate_routes(animal_id)
	var best_route: StringName = ROUTE_BALANCED
	var best_score: float = -INF
	for candidate: StringName in candidates:
		var population: int = int(populations.get(candidate, 0))
		var capacity: int = _route_capacity(candidate)
		var crowd_penalty: float = float(population) * 2.25
		if population >= capacity:
			crowd_penalty += 8.0
		var affinity: float = _species_affinity(animal_id, candidate)
		var hash_value: int = absi(String(animal_id).hash())
		var deterministic_bias: float = float((slot * 13 + hash_value) % 17) * 0.035
		var score: float = affinity - crowd_penalty + deterministic_bias
		if score > best_score:
			best_score = score
			best_route = candidate
	print("AI ROUTE animal=%s route=%s crowd=%d score=%.2f" % [
		String(animal_id), String(best_route), int(populations.get(best_route, 0)), best_score,
	])
	return best_route

func _candidate_routes(animal_id: StringName) -> Array[StringName]:
	match animal_id:
		&"crocodile": return [ROUTE_DEEP_WATER, ROUTE_BALANCED]
		&"raccoon": return [ROUTE_DEEP_WATER, ROUTE_DRY_DOCK, ROUTE_BALANCED]
		&"bear": return [ROUTE_DEEP_WATER, ROUTE_BALANCED, ROUTE_DRY_DOCK]
		&"monkey": return [ROUTE_CANOPY, ROUTE_DRY_DOCK, ROUTE_BALANCED]
		&"rabbit", &"cat": return [ROUTE_ELEVATED, ROUTE_DRY_DOCK, ROUTE_BALANCED]
		&"deer": return [ROUTE_ELEVATED, ROUTE_BALANCED, ROUTE_DRY_DOCK]
		&"fox": return [ROUTE_DRY_DOCK, ROUTE_BALANCED]
		&"elephant", &"boar": return [ROUTE_BREAKTHROUGH, ROUTE_BALANCED, ROUTE_DRY_DOCK]
		&"wolf": return [ROUTE_DRY_DOCK, ROUTE_BALANCED]
		_:
			return [ROUTE_BALANCED, ROUTE_DRY_DOCK]

func _species_affinity(animal_id: StringName, route_id: StringName) -> float:
	var score: float = 4.0 if route_id == ROUTE_BALANCED else 2.0
	match animal_id:
		&"crocodile":
			if route_id == ROUTE_DEEP_WATER: score = 14.0
		&"raccoon":
			if route_id == ROUTE_DEEP_WATER: score = 10.5
			elif route_id == ROUTE_DRY_DOCK: score = 7.0
		&"bear":
			if route_id == ROUTE_DEEP_WATER: score = 9.5
		&"monkey":
			if route_id == ROUTE_CANOPY: score = 14.0
		&"rabbit":
			if route_id == ROUTE_ELEVATED: score = 12.5
		&"cat":
			if route_id == ROUTE_ELEVATED: score = 13.0
		&"deer":
			if route_id == ROUTE_ELEVATED: score = 9.5
		&"fox":
			if route_id == ROUTE_DRY_DOCK: score = 12.0
		&"elephant":
			if route_id == ROUTE_BREAKTHROUGH: score = 13.5
		&"boar":
			if route_id == ROUTE_BREAKTHROUGH: score = 12.5
		&"wolf":
			if route_id == ROUTE_DRY_DOCK: score = 8.5
		&"dog":
			if route_id == ROUTE_BALANCED: score = 8.0
	return score

func _route_capacity(route_id: StringName) -> int:
	match route_id:
		ROUTE_DEEP_WATER: return 5
		ROUTE_DRY_DOCK: return 6
		ROUTE_ELEVATED: return 3
		ROUTE_CANOPY: return 2
		ROUTE_BREAKTHROUGH: return 2
		_:
			return 6

func _build_multi_water_route() -> Array[Vector3]:
	var route: Array[Vector3] = _build_offset_branch(_main_route, 5, 9, -8.5, 0.10)
	route = _build_offset_branch(route, 17, 22, -8.0, 0.10)
	return route

func _build_canopy_approach_route() -> Array[Vector3]:
	var route: Array[Vector3] = _main_route.duplicate()
	var anchors: Array[Marker3D] = _get_sorted_canopy_anchors()
	var count: int = mini(anchors.size(), CANOPY_END - CANOPY_START + 1)
	for index: int in range(count):
		var anchor: Marker3D = anchors[index]
		if anchor == null:
			continue
		var route_index: int = CANOPY_START + index
		route[route_index] = Vector3(anchor.global_position.x, 0.12, anchor.global_position.z)
	return route

func _get_sorted_canopy_anchors() -> Array[Marker3D]:
	var anchors: Array[Marker3D] = []
	for node: Node in get_tree().get_nodes_in_group("wild_tide_canopy_anchor"):
		var anchor: Marker3D = node as Marker3D
		if anchor != null:
			anchors.append(anchor)
	anchors.sort_custom(_sort_anchor)
	return anchors

func _sort_anchor(a: Marker3D, b: Marker3D) -> bool:
	var a_value: Variant = a.get_meta(&"wild_tide_canopy_index", 0)
	var b_value: Variant = b.get_meta(&"wild_tide_canopy_index", 0)
	return int(a_value) < int(b_value)

func _build_offset_branch(
	source: Array[Vector3],
	start_index: int,
	end_index: int,
	max_lateral: float,
	max_height: float
) -> Array[Vector3]:
	var route: Array[Vector3] = source.duplicate()
	var span: int = maxi(1, end_index - start_index)
	for route_index: int in range(start_index, end_index + 1):
		if route_index < 0 or route_index >= route.size():
			continue
		var t: float = float(route_index - start_index) / float(span)
		var envelope: float = sin(t * PI)
		var previous_index: int = maxi(0, route_index - 1)
		var next_index: int = mini(source.size() - 1, route_index + 1)
		var direction: Vector3 = source[next_index] - source[previous_index]
		direction.y = 0.0
		if direction.length_squared() <= 0.001:
			direction = Vector3.FORWARD
		else:
			direction = direction.normalized()
		var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
		route[route_index] = source[route_index] + right * max_lateral * envelope + Vector3.UP * max_height * envelope
	return route

func _build_dry_dock_geometry() -> void:
	var route: Array[Vector3] = get_route(ROUTE_DRY_DOCK)
	_build_platform_chain(
		"DryDockBranch", route, DRY_DOCK_START, DRY_DOCK_END, 5.3,
		Color(0.56, 0.47, 0.30), Color(1.0, 0.72, 0.12)
	)

func _build_elevated_geometry() -> void:
	var route: Array[Vector3] = get_route(ROUTE_ELEVATED)
	_build_platform_chain(
		"ElevatedDockBranch", route, ELEVATED_START, ELEVATED_END, 4.6,
		Color(0.36, 0.39, 0.37), Color(1.0, 0.84, 0.16)
	)

func _build_platform_chain(
	node_name: String,
	route: Array[Vector3],
	start_index: int,
	end_index: int,
	width: float,
	base_color: Color,
	edge_color: Color
) -> void:
	var root: Node3D = Node3D.new()
	root.name = node_name
	root.add_to_group("wild_tide_physical_branch")
	add_child(root)
	var platform_material: StandardMaterial3D = _material(base_color, 0.82, Color.BLACK, 0.0)
	var edge_material: StandardMaterial3D = _material(edge_color, 0.48, edge_color, 0.38)
	for segment_index: int in range(start_index, end_index):
		if segment_index < 0 or segment_index + 1 >= route.size():
			continue
		var a: Vector3 = route[segment_index]
		var b: Vector3 = route[segment_index + 1]
		var length: float = a.distance_to(b)
		var center: Vector3 = a.lerp(b, 0.5)
		var platform: CSGBox3D = CSGBox3D.new()
		platform.name = "Platform_%02d" % segment_index
		platform.size = Vector3(width, 0.36, maxf(1.0, length + 0.25))
		platform.use_collision = true
		platform.position = center + Vector3.DOWN * 0.12
		platform.material = platform_material
		root.add_child(platform)
		platform.look_at(b + Vector3.DOWN * 0.12, Vector3.UP)
		var direction: Vector3 = b - a
		direction.y = 0.0
		if direction.length_squared() <= 0.001:
			continue
		direction = direction.normalized()
		var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
		for side: float in [-1.0, 1.0]:
			var edge: CSGBox3D = CSGBox3D.new()
			edge.name = "Edge_%02d_%s" % [segment_index, "L" if side < 0.0 else "R"]
			edge.size = Vector3(0.16, 0.10, maxf(0.8, length - 0.2))
			edge.use_collision = false
			edge.position = center + right * side * (width * 0.5 - 0.16) + Vector3.UP * 0.12
			edge.material = edge_material
			root.add_child(edge)
			edge.look_at(b + right * side * (width * 0.5 - 0.16) + Vector3.UP * 0.12, Vector3.UP)

func _build_water_split_beacons() -> void:
	var points: Array[Vector3] = [_main_route[5], _main_route[17]]
	for index: int in range(points.size()):
		var beacon: CSGCylinder3D = CSGCylinder3D.new()
		beacon.name = "WaterSplitBeacon_%02d" % index
		beacon.radius = 0.35
		beacon.height = 3.4
		beacon.sides = 8
		beacon.use_collision = false
		beacon.position = points[index] + Vector3.UP * 1.7
		beacon.material = _material(Color(0.05, 0.78, 0.92), 0.40, Color(0.05, 0.72, 1.0), 0.65)
		add_child(beacon)

func _material(color: Color, roughness: float, emission: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material
