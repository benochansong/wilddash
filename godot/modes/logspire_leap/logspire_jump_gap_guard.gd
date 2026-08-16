extends Node

## Final safety guard after the main jump rebalance.
## Titan Tree and Sky Finale gaps must never become larger than the already
## rebalanced values; these zones keep spectacle without restoring punishing gaps.

const ROUTE_SAFE: StringName = &"safe"
const TITAN_EXTRA_REDUCTION: float = 0.20
const SKY_EXTRA_REDUCTION: float = 0.06
const MIN_SURFACE_GAP: float = 0.75

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
		var reduction: float = TITAN_EXTRA_REDUCTION if zone == 4 else (SKY_EXTRA_REDUCTION if zone == 5 else 0.0)
		var new_position: Vector3
		if reduction > 0.0 and current_gap > MIN_SURFACE_GAP:
			var target_gap: float = maxf(MIN_SURFACE_GAP, current_gap * (1.0 - reduction))
			var target_distance: float = target_gap + (previous_size.z + current_size.z) * 0.5
			new_position = previous_new + direction * target_distance + Vector3.UP * delta.y
		else:
			new_position = previous_new + delta
		positions[index] = new_position
		_update_root_position(platform_id, new_position, current_size)
		previous_id = platform_id
		previous_new = new_position

	_world.set("_platform_positions", positions)
	_update_course_length(route_ids)
	print("LOGSPIRE GAP GUARD READY titan_extra_reduction=%.0f%% sky_extra_reduction=%.0f%% never_widen=true" % [
		TITAN_EXTRA_REDUCTION * 100.0,
		SKY_EXTRA_REDUCTION * 100.0,
	])

func _update_root_position(platform_id: StringName, top_position: Vector3, size: Vector3) -> void:
	var root := _world.get_node_or_null(NodePath(String(platform_id))) as Node3D
	if root != null:
		root.position = top_position - Vector3.UP * (size.y * 0.5)

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
