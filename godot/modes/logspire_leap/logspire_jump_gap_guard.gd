extends Node

## Phase A final accessibility pass for LOGSPIRE LEAP.
## Safe Route is easy to complete; Wild-exclusive geometry keeps its mastery role.
## This pass runs before PlatformGraph and PlatformGameplay so every later system
## reads the same easier route geometry.

const ROUTE_SAFE: StringName = &"safe"
const ROUTE_WILD: StringName = &"wild"
const MIN_SURFACE_GAP: float = 0.75

const ZONE1_MAX_GAP: float = 2.25
const ZONE2_MAX_GAP: float = 2.80
const ZONE3_MAX_GAP: float = 2.35
const ZONE4_SAFE_MAX_GAP: float = 3.00
const TITAN_MAX_GAP: float = 3.25
const FINALE_MAX_GAP: float = 3.55
const FINAL_JUMP_MAX_GAP: float = 4.25

const ZONE1_MIN_SIZE := Vector3(14.0, 0.0, 12.5)
const ZONE2_MIN_SIZE := Vector3(12.5, 0.0, 12.0)
const ZONE3_MIN_SIZE := Vector3(15.5, 0.0, 12.5)
const ZONE4_SAFE_MIN_SIZE := Vector3(13.0, 0.0, 16.0)
const TITAN_MIN_SIZE := Vector3(12.0, 0.0, 15.0)
const FINALE_MIN_SIZE := Vector3(12.5, 0.0, 14.0)

const PLAZA_MIN_WIDTH: float = 16.0
const PLAZA_MIN_LENGTH: float = 15.0
const FLOW_BRIDGE_THICKNESS: float = 0.42

const LANDING_PLAZA_IDS: Array[StringName] = [
	&"Z1_03", &"Z1_06",
	&"Z2_03", &"Z2_06",
	&"Z3_04",
	&"Z4_SAFE_03", &"Z4_SAFE_07",
	&"Z5_APPROACH_02", &"Z5_SPIRAL_04",
	&"Z6_02",
]

var _world: Node
var _safe_ids: Array[StringName] = []
var _wild_ids: Array[StringName] = []
var _index_by_id: Dictionary = {}
var _source_positions: Dictionary = {}
var _source_sizes: Dictionary = {}
var _expanded_platforms: int = 0
var _flow_bridge_count: int = 0

func _ready() -> void:
	_world = get_parent().get_node_or_null("LogspireWorld")
	if _world == null:
		push_error("LOGSPIRE PHASE A missing world")
		return
	_apply_phase_a_safe_route()

func _apply_phase_a_safe_route() -> void:
	_safe_ids = _copy_string_name_array(_world.call("get_route_ids", ROUTE_SAFE))
	_wild_ids = _copy_string_name_array(_world.call("get_route_ids", ROUTE_WILD))
	var positions_value: Variant = _world.get("_platform_positions")
	var sizes_value: Variant = _world.get("_platform_sizes")
	var index_value: Variant = _world.get("_platform_index_by_id")
	if _safe_ids.size() < 2 or not (positions_value is Array) or not (sizes_value is Array) or not (index_value is Dictionary):
		push_error("LOGSPIRE PHASE A route data unavailable")
		return

	var positions: Array = positions_value
	var sizes: Array = sizes_value
	_index_by_id = index_value
	_snapshot_route_data(positions, sizes)
	_apply_safe_platform_sizes(sizes)
	_compact_safe_route(positions, sizes)
	_reanchor_wild_exclusive_route(positions)
	_world.set("_platform_positions", positions)
	_world.set("_platform_sizes", sizes)
	_update_route_geometry(positions, sizes)
	_build_running_connectors(positions)
	_update_course_length()
	_print_gap_report(positions, sizes)
	print("LOGSPIRE PHASE A SAFE FLOW READY expanded_platforms=%d landing_plazas=%d running_bridges=%d safe_max_gap=%.2fm wild_exclusive_preserved=true recovery_unchanged=true" % [
		_expanded_platforms,
		LANDING_PLAZA_IDS.size(),
		_flow_bridge_count,
		FINAL_JUMP_MAX_GAP,
	])

func _snapshot_route_data(positions: Array, sizes: Array) -> void:
	_source_positions.clear()
	_source_sizes.clear()
	for id_value: Variant in _index_by_id.keys():
		var platform_id := StringName(id_value)
		var index: int = int(_index_by_id.get(platform_id, -1))
		if index < 0 or index >= positions.size() or index >= sizes.size():
			continue
		_source_positions[platform_id] = positions[index]
		_source_sizes[platform_id] = sizes[index]

func _apply_safe_platform_sizes(sizes: Array) -> void:
	_expanded_platforms = 0
	for platform_id: StringName in _safe_ids:
		if platform_id == &"START":
			continue
		var index: int = int(_index_by_id.get(platform_id, -1))
		if index < 0 or index >= sizes.size():
			continue
		var size: Vector3 = sizes[index]
		var original: Vector3 = size
		var zone: int = int(_world.call("get_platform_zone", platform_id))
		var minimum: Vector3 = _minimum_size_for(zone, platform_id)
		size.x = maxf(size.x, minimum.x)
		size.z = maxf(size.z, minimum.z)
		if LANDING_PLAZA_IDS.has(platform_id):
			size.x = maxf(size.x, PLAZA_MIN_WIDTH)
			size.z = maxf(size.z, PLAZA_MIN_LENGTH)
		if platform_id == &"CROWN_NEST":
			size.x = maxf(size.x, 32.0)
			size.z = maxf(size.z, 26.0)
		if size.x > original.x + 0.01 or size.z > original.z + 0.01:
			_expanded_platforms += 1
		sizes[index] = size

func _compact_safe_route(positions: Array, sizes: Array) -> void:
	var previous_id: StringName = _safe_ids[0]
	var previous_new: Vector3 = _source_positions.get(previous_id, positions[int(_index_by_id.get(previous_id, 0))])
	positions[int(_index_by_id.get(previous_id, 0))] = previous_new

	for i: int in range(1, _safe_ids.size()):
		var platform_id: StringName = _safe_ids[i]
		var index: int = int(_index_by_id.get(platform_id, -1))
		var previous_index: int = int(_index_by_id.get(previous_id, -1))
		if index < 0 or previous_index < 0:
			continue
		var old_previous: Vector3 = _source_positions.get(previous_id, previous_new)
		var old_current: Vector3 = _source_positions.get(platform_id, positions[index])
		var old_delta: Vector3 = old_current - old_previous
		var planar := Vector3(old_delta.x, 0.0, old_delta.z)
		var planar_distance: float = planar.length()
		var direction: Vector3 = Vector3.FORWARD if planar_distance <= 0.001 else planar / planar_distance
		var previous_size: Vector3 = sizes[previous_index]
		var current_size: Vector3 = sizes[index]
		var current_gap: float = maxf(0.0, planar_distance - (previous_size.z + current_size.z) * 0.5)
		var gap_cap: float = _max_gap_for(platform_id)
		var target_gap: float = minf(current_gap, gap_cap)
		if current_gap > 0.0:
			target_gap = maxf(MIN_SURFACE_GAP, target_gap)
		var target_distance: float = target_gap + (previous_size.z + current_size.z) * 0.5
		var new_current := previous_new + direction * target_distance + Vector3.UP * old_delta.y
		positions[index] = new_current
		previous_id = platform_id
		previous_new = new_current

func _reanchor_wild_exclusive_route(positions: Array) -> void:
	var split_id := StringName(_world.call("get_split_platform_id"))
	var merge_id := StringName(_world.call("get_merge_platform_id"))
	if split_id == &"" or merge_id == &"":
		return
	var split_index: int = int(_index_by_id.get(split_id, -1))
	var merge_index: int = int(_index_by_id.get(merge_id, -1))
	if split_index < 0 or merge_index < 0:
		return
	var old_split: Vector3 = _source_positions.get(split_id, positions[split_index])
	var old_merge: Vector3 = _source_positions.get(merge_id, positions[merge_index])
	var new_split: Vector3 = positions[split_index]
	var new_merge: Vector3 = positions[merge_index]
	var old_line: Vector3 = old_merge - old_split
	var old_length_sq: float = maxf(0.001, old_line.length_squared())
	for platform_id: StringName in _wild_ids:
		if _safe_ids.has(platform_id):
			continue
		var index: int = int(_index_by_id.get(platform_id, -1))
		if index < 0:
			continue
		var old_position: Vector3 = _source_positions.get(platform_id, positions[index])
		var t: float = clampf((old_position - old_split).dot(old_line) / old_length_sq, 0.0, 1.0)
		var old_anchor: Vector3 = old_split.lerp(old_merge, t)
		var offset: Vector3 = old_position - old_anchor
		positions[index] = new_split.lerp(new_merge, t) + offset

func _minimum_size_for(zone: int, platform_id: StringName) -> Vector3:
	if platform_id == &"CROWN_NEST":
		return Vector3(32.0, 0.0, 26.0)
	match zone:
		0:
			return ZONE1_MIN_SIZE
		1:
			return ZONE2_MIN_SIZE
		2:
			return ZONE3_MIN_SIZE
		3:
			return ZONE4_SAFE_MIN_SIZE
		4:
			return TITAN_MIN_SIZE
		5:
			return FINALE_MIN_SIZE
	return Vector3(10.0, 0.0, 12.0)

func _max_gap_for(platform_id: StringName) -> float:
	if platform_id == &"CROWN_NEST":
		return FINAL_JUMP_MAX_GAP
	var zone: int = int(_world.call("get_platform_zone", platform_id))
	match zone:
		0:
			return ZONE1_MAX_GAP
		1:
			return ZONE2_MAX_GAP
		2:
			return ZONE3_MAX_GAP
		3:
			return ZONE4_SAFE_MAX_GAP
		4:
			return TITAN_MAX_GAP
		5:
			return FINALE_MAX_GAP
	return 3.5

func _update_route_geometry(positions: Array, sizes: Array) -> void:
	for platform_id: StringName in _safe_ids:
		_update_single_platform_geometry(platform_id, positions, sizes, ROUTE_SAFE)
	for platform_id: StringName in _wild_ids:
		if _safe_ids.has(platform_id):
			continue
		_update_single_platform_geometry(platform_id, positions, sizes, ROUTE_WILD)

func _update_single_platform_geometry(platform_id: StringName, positions: Array, sizes: Array, route_id: StringName) -> void:
	var index: int = int(_index_by_id.get(platform_id, -1))
	if index < 0 or index >= positions.size() or index >= sizes.size():
		return
	var top: Vector3 = positions[index]
	var size: Vector3 = sizes[index]
	var root := _world.get_node_or_null(NodePath(String(platform_id))) as Node3D
	if root == null:
		return
	root.position = top - Vector3.UP * (size.y * 0.5)
	var forward: Vector3 = _route_forward(platform_id, route_id, positions)
	if forward.length_squared() > 0.001:
		root.rotation.y = atan2(-forward.x, -forward.z)

	if platform_id == &"CROWN_NEST":
		var finish_mesh := root.get_node_or_null("CrownNestMesh") as MeshInstance3D
		if finish_mesh != null and finish_mesh.mesh is CylinderMesh:
			var cylinder := finish_mesh.mesh as CylinderMesh
			cylinder.top_radius = size.x * 0.5
			cylinder.bottom_radius = size.x * 0.5
			cylinder.height = size.y
		var finish_body := root.get_node_or_null("CrownNestCollision") as StaticBody3D
		if finish_body != null and finish_body.get_child_count() > 0:
			var finish_collision := finish_body.get_child(0) as CollisionShape3D
			if finish_collision != null and finish_collision.shape is CylinderShape3D:
				var finish_shape := finish_collision.shape as CylinderShape3D
				finish_shape.radius = size.x * 0.5 + 0.55
				finish_shape.height = size.y
		return

	var mesh := root.get_node_or_null("Mesh") as MeshInstance3D
	if mesh != null and mesh.mesh is BoxMesh:
		(mesh.mesh as BoxMesh).size = size
	var body := root.get_node_or_null("Collision") as StaticBody3D
	if body != null and body.get_child_count() > 0:
		var collision := body.get_child(0) as CollisionShape3D
		if collision != null and collision.shape is BoxShape3D:
			var shape := collision.shape as BoxShape3D
			shape.size = Vector3(size.x + 0.80, size.y, size.z + 0.80)

func _route_forward(platform_id: StringName, route_id: StringName, positions: Array) -> Vector3:
	var ids: Array[StringName] = _wild_ids if route_id == ROUTE_WILD else _safe_ids
	var route_index: int = ids.find(platform_id)
	if route_index < 0:
		return Vector3.FORWARD
	var current_index: int = int(_index_by_id.get(platform_id, -1))
	if current_index < 0:
		return Vector3.FORWARD
	var current: Vector3 = positions[current_index]
	var direction := Vector3.FORWARD
	if route_index + 1 < ids.size():
		var next_index: int = int(_index_by_id.get(ids[route_index + 1], -1))
		if next_index >= 0:
			direction = positions[next_index] - current
	elif route_index > 0:
		var previous_index: int = int(_index_by_id.get(ids[route_index - 1], -1))
		if previous_index >= 0:
			direction = current - positions[previous_index]
	direction.y = 0.0
	return Vector3.FORWARD if direction.length_squared() <= 0.001 else direction.normalized()

func _build_running_connectors(positions: Array) -> void:
	_remove_old_running_connectors()
	_flow_bridge_count = 0
	_build_flow_bridge(&"Z1_02", &"Z1_03", 9.0, positions)
	_build_flow_bridge(&"Z1_05", &"Z1_06", 9.0, positions)
	_build_flow_bridge(&"Z2_02", &"Z2_03", 8.5, positions)
	_build_flow_bridge(&"Z2_05", &"Z2_06", 8.5, positions)
	_build_flow_bridge(&"Z4_SAFE_02", &"Z4_SAFE_03", 8.5, positions)
	_build_flow_bridge(&"Z4_SAFE_06", &"Z4_SAFE_07", 8.5, positions)
	_build_flow_bridge(&"Z5_APPROACH_01", &"Z5_APPROACH_02", 9.0, positions)
	_build_flow_bridge(&"Z6_01", &"Z6_02", 8.5, positions)

func _remove_old_running_connectors() -> void:
	for child: Node in _world.get_children():
		if String(child.name).begins_with("SafeFlowBridge_"):
			child.queue_free()

func _build_flow_bridge(from_id: StringName, to_id: StringName, width: float, positions: Array) -> void:
	var from_index: int = int(_index_by_id.get(from_id, -1))
	var to_index: int = int(_index_by_id.get(to_id, -1))
	if from_index < 0 or to_index < 0:
		return
	var from_top: Vector3 = positions[from_index]
	var to_top: Vector3 = positions[to_index]
	var route: Vector3 = to_top - from_top
	var length: float = route.length()
	if length <= 1.0:
		return
	var bridge := Node3D.new()
	bridge.name = "SafeFlowBridge_%s_%s" % [String(from_id), String(to_id)]
	_world.add_child(bridge)
	var lowered_from := from_top - Vector3.UP * 0.22
	var lowered_to := to_top - Vector3.UP * 0.22
	bridge.global_position = lowered_from.lerp(lowered_to, 0.5)
	bridge.look_at(lowered_to, Vector3.UP)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.38, 0.24, 0.10)
	material.roughness = 0.92
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, FLOW_BRIDGE_THICKNESS, length + 1.6)
	box.material = material
	mesh.mesh = box
	bridge.add_child(mesh)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	bridge.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width + 0.55, FLOW_BRIDGE_THICKNESS, length + 1.8)
	collision.shape = shape
	body.add_child(collision)
	_flow_bridge_count += 1

func _update_course_length() -> void:
	var total: float = 0.0
	for i: int in range(_safe_ids.size() - 1):
		var a: Vector3 = _world.call("get_platform_position", _safe_ids[i])
		var b: Vector3 = _world.call("get_platform_position", _safe_ids[i + 1])
		total += a.distance_to(b)
	_world.set("_course_length", total)

func _print_gap_report(positions: Array, sizes: Array) -> void:
	var sums: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var maxima: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var counts: Array[int] = [0, 0, 0, 0, 0, 0]
	for i: int in range(1, _safe_ids.size()):
		var previous_id: StringName = _safe_ids[i - 1]
		var platform_id: StringName = _safe_ids[i]
		var previous_index: int = int(_index_by_id.get(previous_id, -1))
		var index: int = int(_index_by_id.get(platform_id, -1))
		if previous_index < 0 or index < 0:
			continue
		var a: Vector3 = positions[previous_index]
		var b: Vector3 = positions[index]
		var planar := Vector3(b.x - a.x, 0.0, b.z - a.z)
		var gap: float = maxf(0.0, planar.length() - (sizes[previous_index].z + sizes[index].z) * 0.5)
		var zone: int = clampi(int(_world.call("get_platform_zone", platform_id)), 0, 5)
		sums[zone] += gap
		maxima[zone] = maxf(maxima[zone], gap)
		counts[zone] += 1
	for zone: int in range(6):
		var average: float = sums[zone] / float(maxi(1, counts[zone]))
		print("LOGSPIRE PHASE A GAP REPORT zone=%d average=%.2fm max=%.2fm transitions=%d" % [zone + 1, average, maxima[zone], counts[zone]])

func _copy_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not (value is Array):
		return result
	for item: Variant in value:
		if item is StringName:
			result.append(item)
		elif item is String:
			result.append(StringName(item))
	return result
