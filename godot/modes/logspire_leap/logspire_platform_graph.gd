extends Node

const ROUTE_SAFE: StringName = &"safe"
const ROUTE_WILD: StringName = &"wild"

var _world: Node
var _safe_ids: Array[StringName] = []
var _wild_ids: Array[StringName] = []
var _safe_points: Array[Vector3] = []
var _wild_points: Array[Vector3] = []
var _ready_for_race: bool = false

func configure(world: Node) -> void:
	_world = world
	_safe_ids = _copy_string_name_array(_world.call("get_route_ids", ROUTE_SAFE))
	_wild_ids = _copy_string_name_array(_world.call("get_route_ids", ROUTE_WILD))
	_safe_points = _copy_vector3_array(_world.call("get_route_points", ROUTE_SAFE))
	_wild_points = _copy_vector3_array(_world.call("get_route_points", ROUTE_WILD))
	_ready_for_race = _safe_points.size() >= 2 and _wild_points.size() >= 2
	print("LOGSPIRE PLATFORM GRAPH V2 READY safe_nodes=%d wild_nodes=%d safe_length=%.1fm wild_length=%.1fm route_choice=weighted_by_difficulty" % [
		_safe_points.size(),
		_wild_points.size(),
		_route_length(_safe_points),
		_route_length(_wild_points),
	])

func is_ready_for_race() -> bool:
	return _ready_for_race

func choose_route(slot: int, difficulty: StringName) -> StringName:
	# WILD difficulty is the accessibility preset: mostly safe with occasional
	# shortcut variety. NORMAL mixes both. NIGHTMARE prefers the Wild Route but
	# deliberately keeps a safe-route minority so the field never looks scripted.
	if difficulty == &"wild":
		return ROUTE_WILD if slot % 6 == 5 else ROUTE_SAFE
	if difficulty == &"nightmare":
		return ROUTE_SAFE if slot % 3 == 2 else ROUTE_WILD
	return ROUTE_WILD if slot % 3 == 1 else ROUTE_SAFE

func get_route_points(route_id: StringName) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var source: Array[Vector3] = _wild_points if route_id == ROUTE_WILD else _safe_points
	for point: Vector3 in source:
		result.append(point)
	return result

func get_route_ids(route_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var source: Array[StringName] = _wild_ids if route_id == ROUTE_WILD else _safe_ids
	for platform_id: StringName in source:
		result.append(platform_id)
	return result

func get_platform_position(platform_id: StringName) -> Vector3:
	if _world == null:
		return Vector3.ZERO
	var value: Variant = _world.call("get_platform_position", platform_id)
	if value is Vector3:
		return value
	return Vector3.ZERO

func get_platform_forward(platform_id: StringName, route_id: StringName = ROUTE_SAFE) -> Vector3:
	var ids: Array[StringName] = get_route_ids(route_id)
	var index: int = ids.find(platform_id)
	if index < 0:
		ids = get_route_ids(ROUTE_SAFE)
		index = ids.find(platform_id)
	if index < 0:
		return Vector3.FORWARD
	var current: Vector3 = get_platform_position(ids[index])
	var direction := Vector3.FORWARD
	if index + 1 < ids.size():
		direction = get_platform_position(ids[index + 1]) - current
	elif index > 0:
		direction = current - get_platform_position(ids[index - 1])
	direction.y = 0.0
	return Vector3.FORWARD if direction.length_squared() <= 0.001 else direction.normalized()

func get_landing_radius(platform_id: StringName) -> float:
	if _world == null:
		return 4.0
	return float(_world.call("get_platform_landing_radius", platform_id))

func get_risk(platform_id: StringName) -> float:
	if _world == null:
		return 0.0
	return float(_world.call("get_platform_risk", platform_id))

func is_shortcut(platform_id: StringName) -> bool:
	return _world != null and bool(_world.call("is_shortcut_platform", platform_id))

func get_shortcut_value_seconds() -> float:
	var saving_meters: float = maxf(0.0, _route_length(_safe_points) - _route_length(_wild_points))
	return clampf(saving_meters / 11.5 + 2.6, 4.0, 8.0)

func get_last_checkpoint_id(checkpoint_progress: int) -> StringName:
	if _world == null:
		return &""
	if checkpoint_progress <= 0:
		var safe_ids: Array[StringName] = get_route_ids(ROUTE_SAFE)
		return &"" if safe_ids.is_empty() else safe_ids[0]
	var value: Variant = _world.call("get_checkpoint_platform_id", checkpoint_progress - 1)
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return &""

func get_nearest_forward_index(route_id: StringName, position: Vector3) -> int:
	var points: Array[Vector3] = get_route_points(route_id)
	if points.is_empty():
		return 0
	var best_index: int = 0
	var best_distance: float = INF
	for i: int in range(points.size()):
		var distance: float = position.distance_squared_to(points[i])
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return mini(best_index + 1, points.size() - 1)

func get_route_length(route_id: StringName) -> float:
	return _route_length(get_route_points(route_id))

func _copy_vector3_array(value: Variant) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not (value is Array):
		return result
	for item: Variant in value:
		if item is Vector3:
			result.append(item)
	return result

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

func _route_length(points: Array[Vector3]) -> float:
	var total: float = 0.0
	for i: int in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total
