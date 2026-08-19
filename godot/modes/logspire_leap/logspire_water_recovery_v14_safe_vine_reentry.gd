extends "res://modes/logspire_leap/logspire_water_recovery_v13_integrated_qa.gd"

## Vine Rescue re-entry safety pass.
## Emergency vine recovery must never finish under a low platform, beside a
## recovery-deck wall, or on a route point with no readable forward runway.
## Prefer the actual Safe Route platform interior and verify capsule, floor,
## head corridor and one short forward sample before accepting the target.

const VINE_REENTRY_HEIGHT: float = 1.18
const VINE_REENTRY_BACKOFF_MIN: float = 0.75
const VINE_REENTRY_BACKOFF_MAX: float = 1.45
const VINE_REENTRY_FORWARD_SAMPLE_MIN: float = 0.70
const VINE_REENTRY_FORWARD_SAMPLE_MAX: float = 1.40

func _vine_rescue_target(racer: WildDashCharacterController) -> Vector3:
	if racer == null or not is_instance_valid(racer) or _graph == null:
		return super(racer)

	var route_ids: Array[StringName] = _safe_route_ids_for_vine()
	if route_ids.is_empty():
		var parent_target: Vector3 = super(racer)
		if parent_target != Vector3.INF and _vine_reentry_position_clear(racer, parent_target, Vector3.ZERO, 0.0):
			return parent_target
		return Vector3.INF

	var zone: int = int(_zone_by_id.get(racer.get_instance_id(), 0))
	var nearest_index: int = 0
	if _graph.has_method("get_nearest_forward_index"):
		nearest_index = int(_graph.call("get_nearest_forward_index", &"safe", racer.global_position))
	nearest_index = clampi(nearest_index, 0, route_ids.size() - 1)

	var priority_indices: Array[int] = []
	_append_unique_index(priority_indices, nearest_index, route_ids.size())
	_append_unique_index(priority_indices, nearest_index - 1, route_ids.size())
	_append_unique_index(priority_indices, nearest_index + 1, route_ids.size())
	_append_unique_index(priority_indices, nearest_index - 2, route_ids.size())
	_append_unique_index(priority_indices, nearest_index + 2, route_ids.size())

	for index: int in priority_indices:
		var platform_id: StringName = route_ids[index]
		if not _platform_matches_zone(platform_id, zone):
			continue
		var target: Vector3 = _safe_platform_reentry(racer, platform_id)
		if target != Vector3.INF:
			_log_safe_vine_target(racer, platform_id, target, "nearest_safe_route")
			return target

	# If the nearest route samples are blocked, inspect the rest of the current
	# zone before falling back to an older root or ladder exit.
	var best_target := Vector3.INF
	var best_platform: StringName = &""
	var best_distance: float = INF
	for platform_id: StringName in route_ids:
		if not _platform_matches_zone(platform_id, zone):
			continue
		var target: Vector3 = _safe_platform_reentry(racer, platform_id)
		if target == Vector3.INF:
			continue
		var planar_distance: float = Vector2(
			racer.global_position.x - target.x,
			racer.global_position.z - target.z
		).length()
		if planar_distance < best_distance:
			best_distance = planar_distance
			best_target = target
			best_platform = platform_id
	if best_target != Vector3.INF:
		_log_safe_vine_target(racer, best_platform, best_target, "zone_safe_route")
		return best_target

	var checkpoint_target: Vector3 = _checkpoint_reentry_target(racer)
	if checkpoint_target != Vector3.INF:
		print("LOGSPIRE VINE REENTRY racer=%s source=checkpoint_fallback safe=true" % RaceManager.get_racer_label(racer))
		return checkpoint_target

	var parent_target: Vector3 = super(racer)
	if parent_target != Vector3.INF and _vine_reentry_position_clear(racer, parent_target, Vector3.ZERO, 0.0):
		return parent_target
	return Vector3.INF

func _finish_assisted_recovery(racer: WildDashCharacterController, exit_position: Vector3, message: String) -> void:
	if racer != null and is_instance_valid(racer):
		var racer_id: int = racer.get_instance_id()
		var kind := StringName(_traversal_kind_by_id.get(racer_id, &""))
		if kind == &"vine_rescue" and not _vine_reentry_position_clear(racer, exit_position, Vector3.ZERO, 0.0):
			var replacement: Vector3 = _vine_rescue_target(racer)
			if replacement == Vector3.INF:
				print("LOGSPIRE VINE REENTRY BLOCKED racer=%s unsafe_exit=true resume_water=true" % RaceManager.get_racer_label(racer))
				_abort_scripted_traversal_to_swim(racer, "unsafe_vine_reentry")
				return
			print("LOGSPIRE VINE REENTRY CORRECTED racer=%s unsafe_exit=true replacement_safe=true" % RaceManager.get_racer_label(racer))
			exit_position = replacement
	super(racer, exit_position, message)

func _safe_route_ids_for_vine() -> Array[StringName]:
	var result: Array[StringName] = []
	if _graph == null or not _graph.has_method("get_route_ids"):
		return result
	var value: Variant = _graph.call("get_route_ids", &"safe")
	if not (value is Array):
		return result
	for item: Variant in value:
		if item is StringName:
			result.append(item)
		elif item is String:
			result.append(StringName(item))
	return result

func _append_unique_index(indices: Array[int], index: int, size: int) -> void:
	if index < 0 or index >= size or indices.has(index):
		return
	indices.append(index)

func _platform_matches_zone(platform_id: StringName, zone: int) -> bool:
	if _world == null or not is_instance_valid(_world) or not _world.has_method("get_platform_zone"):
		return true
	return int(_world.call("get_platform_zone", platform_id)) == zone

func _safe_platform_reentry(racer: WildDashCharacterController, platform_id: StringName) -> Vector3:
	if racer == null or not is_instance_valid(racer) or _graph == null:
		return Vector3.INF
	var position_value: Variant = _graph.call("get_platform_position", platform_id)
	if not (position_value is Vector3):
		return Vector3.INF
	var platform_position: Vector3 = position_value
	var forward_value: Variant = _graph.call("get_platform_forward", platform_id, &"safe")
	var forward: Vector3 = forward_value if forward_value is Vector3 else Vector3.FORWARD
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var landing_radius: float = 4.0
	if _graph.has_method("get_landing_radius"):
		landing_radius = maxf(3.0, float(_graph.call("get_landing_radius", platform_id)))
	var backoff: float = clampf(landing_radius * 0.22, VINE_REENTRY_BACKOFF_MIN, VINE_REENTRY_BACKOFF_MAX)
	var interior_target: Vector3 = platform_position - forward * backoff + Vector3.UP * VINE_REENTRY_HEIGHT
	if _vine_reentry_position_clear(racer, interior_target, forward, landing_radius):
		return interior_target
	var center_target: Vector3 = platform_position + Vector3.UP * VINE_REENTRY_HEIGHT
	if _vine_reentry_position_clear(racer, center_target, forward, landing_radius):
		return center_target
	return Vector3.INF

func _vine_reentry_position_clear(
	racer: WildDashCharacterController,
	position: Vector3,
	forward: Vector3,
	landing_radius: float
) -> bool:
	if racer == null or not is_instance_valid(racer) or position == Vector3.INF:
		return false
	if not _exit_position_clear(racer, position):
		return false
	if forward.length_squared() <= 0.001 or landing_radius <= 0.0:
		return true
	var sample_distance: float = clampf(
		landing_radius * 0.24,
		VINE_REENTRY_FORWARD_SAMPLE_MIN,
		VINE_REENTRY_FORWARD_SAMPLE_MAX
	)
	var ahead: Vector3 = position + forward.normalized() * sample_distance
	if not _exit_position_clear(racer, ahead):
		return false
	return _head_segment_clear(racer, position, ahead)

func _checkpoint_reentry_target(racer: WildDashCharacterController) -> Vector3:
	if racer == null or not is_instance_valid(racer) or _graph == null or not _graph.has_method("get_last_checkpoint_id"):
		return Vector3.INF
	var value: Variant = _graph.call("get_last_checkpoint_id", RaceManager.get_checkpoint_progress(racer))
	var platform_id: StringName = &""
	if value is StringName:
		platform_id = value
	elif value is String:
		platform_id = StringName(value)
	if platform_id == &"":
		return Vector3.INF
	return _safe_platform_reentry(racer, platform_id)

func _log_safe_vine_target(racer: WildDashCharacterController, platform_id: StringName, target: Vector3, source: String) -> void:
	print("LOGSPIRE VINE REENTRY racer=%s platform=%s source=%s safe=true x=%.2f y=%.2f z=%.2f" % [
		RaceManager.get_racer_label(racer),
		String(platform_id),
		source,
		target.x,
		target.y,
		target.z,
	])
