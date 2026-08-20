extends "res://modes/logspire_leap/logspire_water_recovery_v15_vine_only.gd"

## Round 3 route-corridor water authority.
##
## The authored Canopy River pools use fixed legacy heights while accessibility
## passes move production Safe Route platforms. A racer can therefore be on the
## correct route while an old pool reports the feet as submerged. Foot-ray-only
## guards are not sufficient because a short jump, ramp seam or connector exit
## can have no support for a few physics frames.
##
## Production rule:
## - while the racer is horizontally inside the current Safe Route corridor and
##   no more than ROUTE_CORRIDOR_MAX_DROP below that live route, racing owns the
##   transform and water recovery cannot start;
## - once the racer falls materially below the live route corridor, normal V15
##   water/Vine recovery remains authoritative.
##
## The corridor is computed from current PlatformGraph platform positions every
## call, so Titan accessibility and CP5 route relocation cannot stale this guard.

const ROUTE_CORRIDOR_RADIUS: float = 7.25
const ROUTE_CORRIDOR_MAX_DROP: float = 3.40
const ROUTE_CORRIDOR_MIN_SEGMENT_LENGTH: float = 0.05

var _route_corridor_log_once: Dictionary = {}

func is_route_corridor_protected(racer: WildDashCharacterController) -> bool:
	var status: Dictionary = get_route_corridor_status(racer)
	return bool(status.get("protected", false))

func get_route_corridor_status(racer: WildDashCharacterController) -> Dictionary:
	if racer == null or not is_instance_valid(racer) or _graph == null:
		return {}
	if not _graph.has_method("get_route_ids") or not _graph.has_method("get_platform_position"):
		return {}
	var ids_value: Variant = _graph.call("get_route_ids", &"safe")
	if not (ids_value is Array):
		return {}
	var ids: Array = ids_value
	if ids.size() < 2:
		return {}

	var position: Vector3 = racer.global_position
	var best_planar_distance: float = INF
	var best_route_y: float = position.y
	var best_from: StringName = &""
	var best_to: StringName = &""
	var best_t: float = 0.0

	for i: int in range(ids.size() - 1):
		var from_id := StringName(ids[i])
		var to_id := StringName(ids[i + 1])
		var a_value: Variant = _graph.call("get_platform_position", from_id)
		var b_value: Variant = _graph.call("get_platform_position", to_id)
		if not (a_value is Vector3) or not (b_value is Vector3):
			continue
		var a: Vector3 = a_value
		var b: Vector3 = b_value
		var segment_xz := Vector2(b.x - a.x, b.z - a.z)
		var length_sq: float = segment_xz.length_squared()
		if length_sq <= ROUTE_CORRIDOR_MIN_SEGMENT_LENGTH * ROUTE_CORRIDOR_MIN_SEGMENT_LENGTH:
			continue
		var rel_xz := Vector2(position.x - a.x, position.z - a.z)
		var t: float = clampf(rel_xz.dot(segment_xz) / length_sq, 0.0, 1.0)
		var sample: Vector3 = a.lerp(b, t)
		var planar_distance: float = Vector2(position.x - sample.x, position.z - sample.z).length()
		if planar_distance < best_planar_distance:
			best_planar_distance = planar_distance
			best_route_y = sample.y
			best_from = from_id
			best_to = to_id
			best_t = t

	if best_planar_distance == INF:
		return {}
	var below_route: float = best_route_y - position.y
	var protected: bool = (
		best_planar_distance <= ROUTE_CORRIDOR_RADIUS
		and below_route <= ROUTE_CORRIDOR_MAX_DROP
	)
	return {
		"protected": protected,
		"planar_distance": best_planar_distance,
		"route_y": best_route_y,
		"below_route": below_route,
		"from": best_from,
		"to": best_to,
		"t": best_t,
	}

func _is_real_water_entry(racer: WildDashCharacterController, water_y: float) -> bool:
	if is_route_corridor_protected(racer):
		_log_route_water_suppressed(racer, water_y, "entry_guard")
		return false
	return super(racer, water_y)

func should_handle_racer(racer: WildDashCharacterController) -> bool:
	if racer == null or not is_instance_valid(racer):
		return false
	if not is_water_recovering(racer) and is_route_corridor_protected(racer):
		return false
	return super(racer)

func _enter_water(racer: WildDashCharacterController, zone: int, water_y: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	if not is_water_recovering(racer) and is_route_corridor_protected(racer):
		_log_route_water_suppressed(racer, water_y, "enter_water")
		return
	super(racer, zone, water_y)

func _log_route_water_suppressed(racer: WildDashCharacterController, water_y: float, source: String) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	var status: Dictionary = get_route_corridor_status(racer)
	var from_id := StringName(status.get("from", &""))
	var to_id := StringName(status.get("to", &""))
	var key: String = "%d:%s:%s:%s" % [racer.get_instance_id(), source, String(from_id), String(to_id)]
	if _route_corridor_log_once.has(key):
		return
	_route_corridor_log_once[key] = true
	print("LOGSPIRE ROUTE WATER SUPPRESSED racer=%s source=%s segment=%s->%s planar=%.2f route_y=%.2f body_y=%.2f below_route=%.2f water_y=%.2f racing_authority=true" % [
		RaceManager.get_racer_label(racer),
		source,
		String(from_id),
		String(to_id),
		float(status.get("planar_distance", -1.0)),
		float(status.get("route_y", racer.global_position.y)),
		racer.global_position.y,
		float(status.get("below_route", 0.0)),
		water_y,
	])
