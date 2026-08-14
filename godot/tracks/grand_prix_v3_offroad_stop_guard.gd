class_name WildDashGrandPrixV3OffroadStopGuard
extends Node

## Grand Prix V3.6 final offroad stop guard.
##
## The normal offroad controller provides the gradual loss of grip and speed.
## This guard only acts after a racer has already reached the intended deep-
## offroad stop line. Holding steering/throttle outward must not let the racer
## creep a few centimetres farther every physics frame until it eventually
## reaches the edge of the land mesh. This is not a roadside wall: racers can
## freely leave the road, cross the shoulder and drive several metres offroad
## before the soft stop line is reached.

const LOCAL_SEARCH_RADIUS: int = 12
const SOFT_STOP_SLOP: float = 0.28
const DEFAULT_STOP_DEPTH: float = 7.0

const SECTION_STOP_DEPTHS: Dictionary = {
	&"mountain_approach": 3.40,
	&"mountain_ascent": 2.80,
	&"summit_ridge": 2.50,
	&"rough_descent": 3.00,
	&"canyon_obstacle": 2.20,
}

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _segment_hint: Dictionary = {}
var _clamp_count: int = 0

func _ready() -> void:
	process_priority = 135
	call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
	for _frame: int in range(10):
		await get_tree().process_frame
	_track = _find_v2_track(get_parent())
	if _track == null:
		push_warning("GrandPrixV3OffroadStopGuard: V2 track unavailable")
		return
	_route = _track.get_route_points()
	if _route.size() < 2:
		push_warning("GrandPrixV3OffroadStopGuard: route unavailable")
		return
	print("GRAND PRIX V3.6 OFFROAD SOFT STOP READY default=%.1fm mountain=2.2..3.4m roadside_wall=false post_slowdown_guard=true" % DEFAULT_STOP_DEPTH)

func _physics_process(_delta: float) -> void:
	if _track == null or _route.size() < 2 or not RaceManager.active:
		return
	for candidate in RaceManager.racers:
		if not candidate is WildDashCharacterController:
			continue
		var racer: WildDashCharacterController = candidate as WildDashCharacterController
		if racer.finished:
			continue
		_enforce_soft_stop(racer)

func _enforce_soft_stop(racer: WildDashCharacterController) -> void:
	var key: int = racer.get_instance_id()
	var sample: Dictionary = _sample_route(racer, key)
	if sample.is_empty():
		return
	var stop_depth: float = _stop_depth_for_section(sample["section"] as StringName)
	var depth: float = float(sample["depth"])
	if depth <= stop_depth + SOFT_STOP_SLOP:
		return

	var center: Vector3 = sample["center"]
	var planar_offset: Vector3 = racer.global_position - center
	planar_offset.y = 0.0
	if planar_offset.length_squared() <= 0.001:
		return
	var direction: Vector3 = planar_offset.normalized()
	var max_center_distance: float = float(sample["drivable_half_width"]) + stop_depth
	var corrected: Vector3 = center + direction * max_center_distance
	corrected.y = racer.global_position.y
	racer.global_position = corrected
	racer.current_speed = 0.0
	racer.velocity.x = 0.0
	racer.velocity.z = 0.0
	_clamp_count += 1
	if racer.is_player and (_clamp_count <= 3 or _clamp_count % 60 == 0):
		print("GRAND PRIX V3.6 OFFROAD SOFT STOP HOLD racer=%s section=%s depth=%.2f stop=%.2f count=%d" % [
			racer.name,
			String(sample["section"]),
			depth,
			stop_depth,
			_clamp_count,
		])

func _sample_route(racer: WildDashCharacterController, key: int) -> Dictionary:
	var segment_count: int = _route.size() - 1
	if segment_count <= 0:
		return {}
	var hint: int = int(_segment_hint.get(key, -1))
	if hint < 0:
		var track_length: float = maxf(1.0, _track.get_track_length())
		var progress: float = RaceManager.get_track_progress(racer)
		hint = clampi(roundi((progress / track_length) * float(segment_count - 1)), 0, segment_count - 1)

	var point2: Vector2 = Vector2(racer.global_position.x, racer.global_position.z)
	var best_distance: float = INF
	var best_segment: int = -1
	var best_center: Vector3 = Vector3.ZERO
	var start_segment: int = maxi(0, hint - LOCAL_SEARCH_RADIUS)
	var end_segment: int = mini(segment_count - 1, hint + LOCAL_SEARCH_RADIUS)

	for segment_index: int in range(start_segment, end_segment + 1):
		var a: Vector3 = _route[segment_index]
		var b: Vector3 = _route[segment_index + 1]
		var a2: Vector2 = Vector2(a.x, a.z)
		var b2: Vector2 = Vector2(b.x, b.z)
		var ab: Vector2 = b2 - a2
		var length_squared: float = ab.length_squared()
		var segment_t: float = 0.0
		if length_squared > 0.0001:
			segment_t = clampf((point2 - a2).dot(ab) / length_squared, 0.0, 1.0)
		var closest2: Vector2 = a2 + ab * segment_t
		var distance: float = point2.distance_to(closest2)
		if distance >= best_distance:
			continue
		best_distance = distance
		best_segment = segment_index
		best_center = a.lerp(b, segment_t)

	if best_segment < 0:
		return {}
	_segment_hint[key] = best_segment
	var road_half_width: float = _track.get_v2_width_for_segment(best_segment) * 0.5
	var shoulder_width: float = _track.get_v2_shoulder_width_for_segment(best_segment)
	var drivable_half_width: float = road_half_width + shoulder_width
	return {
		"segment": best_segment,
		"section": _track.get_v2_section_id_for_segment(best_segment),
		"center": best_center,
		"center_distance": best_distance,
		"drivable_half_width": drivable_half_width,
		"depth": maxf(0.0, best_distance - drivable_half_width),
	}

func _stop_depth_for_section(section_id: StringName) -> float:
	return float(SECTION_STOP_DEPTHS.get(section_id, DEFAULT_STOP_DEPTH))

func _find_v2_track(root: Node) -> WildDashGrandPrixV2Track:
	if root == null:
		return null
	if root is WildDashGrandPrixV2Track:
		return root as WildDashGrandPrixV2Track
	for child: Node in root.get_children():
		var found: WildDashGrandPrixV2Track = _find_v2_track(child)
		if found != null:
			return found
	return null
