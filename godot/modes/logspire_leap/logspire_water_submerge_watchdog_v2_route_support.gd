extends "res://modes/logspire_leap/logspire_water_submerge_watchdog.gd"

## Route-aware hard-water authority for production Round 3.
##
## Titan accessibility and CP5 corridor repairs move legitimate Safe Route
## platforms relative to the original fixed Canopy River pool layout. A racer can
## therefore be standing on a real platform while an older water pool reports the
## feet as deeply submerged. V1 intentionally ignored any support deeper than
## SUPPORTED_FLOOR_ESCAPE_DEPTH so hidden river-bed floors could not strand the
## player, but that rule also misclassified legitimate route platforms and caused
## a sudden WATER RESET / camera cut while simply traversing CP5.
##
## V2 distinguishes authored racing support from incidental world support. A
## Safe Route platform, a moving replacement for a Safe Route platform, or an
## authored route connector always keeps racing authority even if a stale pool
## overlaps it vertically. River beds and unrelated world collision still use the
## original hard escape unchanged.

const ROUTE_SUPPORT_PROBE_UP: float = 0.36
const ROUTE_SUPPORT_PROBE_DEPTH: float = 1.55
const ROUTE_SUPPORT_SAMPLE_RADIUS: float = 0.58
const ROUTE_SUPPORT_COLLISION_MASK: int = 5

var _safe_route_name_lookup: Dictionary = {}
var _route_support_log_once: Dictionary = {}

func _physics_process(delta: float) -> void:
	if _water == null or _graph == null or not RaceManager.active:
		return
	_ensure_safe_route_lookup()

	for value: Variant in RaceManager.racers.duplicate():
		var racer := value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer.finished:
			continue
		var racer_id: int = racer.get_instance_id()
		var pool: Dictionary = _pool_for_racer(racer)
		if pool.is_empty():
			_submerged_elapsed_by_id.erase(racer_id)
			continue
		var water_y: float = float(pool.get("water_y", racer.global_position.y))
		var submerged_depth: float = water_y - racer.global_position.y
		if submerged_depth < HARD_SUBMERGE_DEPTH:
			_submerged_elapsed_by_id.erase(racer_id)
			continue

		# Highest authority: authored racing geometry is never a reason to restart.
		# This specifically blocks stale Canopy River pools from teleporting a racer
		# who is correctly standing on Titan Tree / CP5 route geometry.
		var route_support: Dictionary = _route_support_hit(racer)
		if not route_support.is_empty():
			_submerged_elapsed_by_id.erase(racer_id)
			var support_name: String = String(route_support.get("support", "route"))
			var log_key: String = "%d:%s" % [racer_id, support_name]
			if not _route_support_log_once.has(log_key):
				_route_support_log_once[log_key] = true
				print("LOGSPIRE WATER RESET SUPPRESSED racer=%s support=%s body_y=%.2f water_y=%.2f depth=%.2f route_support=true stale_pool_overlap=true" % [
					RaceManager.get_racer_label(racer),
					support_name,
					racer.global_position.y,
					water_y,
					submerged_depth,
				])
			continue

		# Preserve the V1 fail-safe for non-route support. A hidden basin floor may
		# still report is_on_floor()/ray support many metres below the waterline and
		# must never become valid racing ground.
		var has_surface_support: bool = _has_surface_support(racer)
		var supported_floor_invalid: bool = has_surface_support and submerged_depth >= SUPPORTED_FLOOR_ESCAPE_DEPTH
		if has_surface_support and not supported_floor_invalid:
			_submerged_elapsed_by_id.erase(racer_id)
			continue
		if _vine_rescue_active(racer_id):
			_submerged_elapsed_by_id.erase(racer_id)
			continue

		if supported_floor_invalid and not _submerged_elapsed_by_id.has(racer_id):
			print("LOGSPIRE SUBMERGED FLOOR INVALID racer=%s zone=%d body_y=%.2f water_y=%.2f depth=%.2f support_ignored=true route_support=false force_checkpoint_pending=true" % [
				RaceManager.get_racer_label(racer),
				int(pool.get("zone", 0)) + 1,
				racer.global_position.y,
				water_y,
				submerged_depth,
			])

		var elapsed: float = float(_submerged_elapsed_by_id.get(racer_id, 0.0)) + delta
		_submerged_elapsed_by_id[racer_id] = elapsed
		if elapsed < HARD_SUBMERGE_CONFIRM_SECONDS:
			continue
		_hard_checkpoint_escape(racer, submerged_depth)
		_submerged_elapsed_by_id.erase(racer_id)

func _ensure_safe_route_lookup() -> void:
	if not _safe_route_name_lookup.is_empty() or _graph == null or not _graph.has_method("get_route_ids"):
		return
	var value: Variant = _graph.call("get_route_ids", &"safe")
	if not (value is Array):
		return
	for route_value: Variant in value:
		var route_id := StringName(route_value)
		_safe_route_name_lookup[String(route_id)] = true
	print("LOGSPIRE ROUTE WATER AUTHORITY READY safe_support_ids=%d route_connector=true moving_platform_alias=true" % _safe_route_name_lookup.size())

func _route_support_hit(racer: WildDashCharacterController) -> Dictionary:
	if racer == null or not is_instance_valid(racer):
		return {}
	var world: World3D = racer.get_world_3d()
	if world == null:
		return {}

	var right: Vector3 = racer.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() <= 0.001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var forward: Vector3 = -racer.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var diagonal_a := (right + forward).normalized()
	var diagonal_b := (right - forward).normalized()
	var offsets: Array[Vector3] = [
		Vector3.ZERO,
		right * ROUTE_SUPPORT_SAMPLE_RADIUS,
		-right * ROUTE_SUPPORT_SAMPLE_RADIUS,
		forward * ROUTE_SUPPORT_SAMPLE_RADIUS,
		-forward * ROUTE_SUPPORT_SAMPLE_RADIUS,
		diagonal_a * ROUTE_SUPPORT_SAMPLE_RADIUS,
		-diagonal_a * ROUTE_SUPPORT_SAMPLE_RADIUS,
		diagonal_b * ROUTE_SUPPORT_SAMPLE_RADIUS,
		-diagonal_b * ROUTE_SUPPORT_SAMPLE_RADIUS,
	]

	for offset: Vector3 in offsets:
		var from: Vector3 = racer.global_position + offset + Vector3.UP * ROUTE_SUPPORT_PROBE_UP
		var to: Vector3 = racer.global_position + offset - Vector3.UP * ROUTE_SUPPORT_PROBE_DEPTH
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = ROUTE_SUPPORT_COLLISION_MASK
		query.exclude = [racer.get_rid()]
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.hit_from_inside = true
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var collider := hit.get("collider") as Node
		var support_name: String = _route_support_name(collider)
		if not support_name.is_empty():
			return {"support": support_name, "collider": collider}
	return {}

func _route_support_name(collider: Node) -> String:
	var node := collider
	var depth: int = 0
	while node != null and depth < 7:
		if bool(node.get_meta(&"logspire_route_connector", false)):
			return String(node.name)
		var node_name: String = String(node.name)
		if _safe_route_name_lookup.has(node_name):
			return node_name
		if node_name.begins_with("Phase2_"):
			var authored_name: String = node_name.trim_prefix("Phase2_")
			if _safe_route_name_lookup.has(authored_name):
				return node_name
		# Some production helper bodies prefix the platform id while preserving it
		# in the node name. Match only complete known ids to avoid blessing generic
		# world geometry such as Recovery_Z*_Deck or Titan roots.
		for route_name: Variant in _safe_route_name_lookup.keys():
			var route_text: String = String(route_name)
			if route_text.length() >= 4 and node_name.contains(route_text):
				return node_name
		node = node.get_parent()
		depth += 1
	return ""
