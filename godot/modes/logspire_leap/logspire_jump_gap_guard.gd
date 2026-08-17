extends Node

## Final safety guard after the main jump rebalance.
## Zone 1 is a tutorial: broad landings and very short gaps.
## Early Zone 2 remains forgiving before the course begins asking for precision.
## Titan Tree and Sky Finale retain their existing spectacle-oriented reductions.

const ROUTE_SAFE: StringName = &"safe"
const TITAN_EXTRA_REDUCTION: float = 0.20
const SKY_EXTRA_REDUCTION: float = 0.06
const MIN_SURFACE_GAP: float = 0.75

const TUTORIAL_ZONE1_MAX_SURFACE_GAP: float = 2.60
const TUTORIAL_ZONE2_MAX_SURFACE_GAP: float = 3.20
const TUTORIAL_ZONE1_WIDTH_SCALE: float = 1.12
const TUTORIAL_ZONE1_LENGTH_SCALE: float = 1.10
const TUTORIAL_ZONE2_WIDTH_SCALE: float = 1.08
const TUTORIAL_ZONE2_LENGTH_SCALE: float = 1.06

var _world: Node

func _ready() -> void:
	_world = get_parent().get_node_or_null("LogspireWorld")
	if _world == null:
		push_error("LOGSPIRE GAP GUARD missing world")
		return
	_apply_guard()

func _apply_guard() -> void:
	var route_ids: Array[StringName] = _copy_string_name_array(_world.call("get_route_ids", ROUTE_SAFE))
	var positions_value: Variant = _world.get("_platform_positions")
	var sizes_value: Variant = _world.get("_platform_sizes")
	var index_value: Variant = _world.get("_platform_index_by_id")
	if route_ids.size() < 2 or not (positions_value is Array) or not (sizes_value is Array) or not (index_value is Dictionary):
		return
	var positions: Array = positions_value
	var sizes: Array = sizes_value
	var index_by_id: Dictionary = index_value

	_apply_tutorial_platform_sizes(route_ids, sizes, index_by_id)

	var source_positions: Dictionary = {}
	for platform_id: StringName in route_ids:
		var index: int = int(index_by_id.get(platform_id, -1))
		if index >= 0 and index < positions.size():
			source_positions[platform_id] = positions[index]

	var previous_id: StringName = route_ids[0]
	var previous_new: Vector3 = source_positions.get(previous_id, Vector3.ZERO)
	for i: int in range(1, route_ids.size()):
		var platform_id: StringName = route_ids[i]
		var index: int = int(index_by_id.get(platform_id, -1))
		if index < 0 or index >= positions.size():
			continue
		var zone: int = int(_world.call("get_platform_zone", platform_id))
		var old_previous: Vector3 = source_positions.get(previous_id, previous_new)
		var old_current: Vector3 = source_positions.get(platform_id, positions[index])
		var delta: Vector3 = old_current - old_previous
		var planar := Vector3(delta.x, 0.0, delta.z)
		var distance: float = planar.length()
		var direction: Vector3 = Vector3.FORWARD if distance <= 0.001 else planar / distance
		var previous_index: int = int(index_by_id.get(previous_id, -1))
		var previous_size: Vector3 = sizes[previous_index] if previous_index >= 0 else Vector3(8.0, 1.0, 8.0)
		var current_size: Vector3 = sizes[index]
		var current_gap: float = maxf(0.0, distance - (previous_size.z + current_size.z) * 0.5)
		var target_gap: float = current_gap
		var tutorial_max_gap: float = _tutorial_max_gap(platform_id, zone)
		if tutorial_max_gap > 0.0:
			target_gap = minf(current_gap, tutorial_max_gap)
		else:
			var reduction: float = TITAN_EXTRA_REDUCTION if zone == 4 else (SKY_EXTRA_REDUCTION if zone == 5 else 0.0)
			if reduction > 0.0 and current_gap > MIN_SURFACE_GAP:
				target_gap = maxf(MIN_SURFACE_GAP, current_gap * (1.0 - reduction))

		var new_position: Vector3
		if target_gap < current_gap - 0.001:
			var target_distance: float = target_gap + (previous_size.z + current_size.z) * 0.5
			new_position = previous_new + direction * target_distance + Vector3.UP * delta.y
		else:
			new_position = previous_new + delta
		positions[index] = new_position
		_update_root_geometry(platform_id, new_position, current_size)
		previous_id = platform_id
		previous_new = new_position

	_world.set("_platform_positions", positions)
	_world.set("_platform_sizes", sizes)
	_update_course_length(route_ids)
	print("LOGSPIRE GAP GUARD READY zone1_tutorial_max_gap=%.1fm zone2_early_max_gap=%.1fm zone1_broad_landings=true titan_extra_reduction=%.0f%% sky_extra_reduction=%.0f%% never_widen=true" % [
		TUTORIAL_ZONE1_MAX_SURFACE_GAP,
		TUTORIAL_ZONE2_MAX_SURFACE_GAP,
		TITAN_EXTRA_REDUCTION * 100.0,
		SKY_EXTRA_REDUCTION * 100.0,
	])

func _apply_tutorial_platform_sizes(route_ids: Array[StringName], sizes: Array, index_by_id: Dictionary) -> void:
	for platform_id: StringName in route_ids:
		if platform_id == &"START":
			continue
		var index: int = int(index_by_id.get(platform_id, -1))
		if index < 0 or index >= sizes.size():
			continue
		var size: Vector3 = sizes[index]
		var zone: int = int(_world.call("get_platform_zone", platform_id))
		if zone == 0:
			size.x *= TUTORIAL_ZONE1_WIDTH_SCALE
			size.z *= TUTORIAL_ZONE1_LENGTH_SCALE
		elif _is_early_zone2(platform_id):
			size.x *= TUTORIAL_ZONE2_WIDTH_SCALE
			size.z *= TUTORIAL_ZONE2_LENGTH_SCALE
		else:
			continue
		sizes[index] = size

func _tutorial_max_gap(platform_id: StringName, zone: int) -> float:
	if zone == 0:
		return TUTORIAL_ZONE1_MAX_SURFACE_GAP
	if _is_early_zone2(platform_id):
		return TUTORIAL_ZONE2_MAX_SURFACE_GAP
	return -1.0

func _is_early_zone2(platform_id: StringName) -> bool:
	return platform_id == &"Z2_01" or platform_id == &"Z2_02" or platform_id == &"Z2_03"

func _update_root_geometry(platform_id: StringName, top_position: Vector3, size: Vector3) -> void:
	var root := _world.get_node_or_null(NodePath(String(platform_id))) as Node3D
	if root == null:
		return
	root.position = top_position - Vector3.UP * (size.y * 0.5)
	if platform_id == &"CROWN_NEST":
		return
	var mesh := root.get_node_or_null("Mesh") as MeshInstance3D
	if mesh != null and mesh.mesh is BoxMesh:
		(mesh.mesh as BoxMesh).size = size
	var body := root.get_node_or_null("Collision") as StaticBody3D
	if body != null and body.get_child_count() > 0:
		var collision := body.get_child(0) as CollisionShape3D
		if collision != null and collision.shape is BoxShape3D:
			var shape := collision.shape as BoxShape3D
			shape.size = Vector3(size.x + 0.70, size.y, size.z + 0.70)

func _update_course_length(route_ids: Array[StringName]) -> void:
	var total: float = 0.0
	for i: int in range(route_ids.size() - 1):
		var a: Vector3 = _world.call("get_platform_position", route_ids[i])
		var b: Vector3 = _world.call("get_platform_position", route_ids[i + 1])
		total += a.distance_to(b)
	_world.set("_course_length", total)

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
