class_name WildDashWildTideRespawnGuard
extends Node

## Flood/Titan safety net. The authoritative RaceManager checkpoint respawn remains
## first choice; this guard only replaces a candidate if it would be submerged or
## dangerously close to a Titan hazard, then chooses a nearby authored safe anchor.

const FALL_Y: float = -27.5
const HAZARD_SAFE_RADIUS: float = 10.0

var _safe_anchors: Array[Marker3D] = []
var _world: WildDashWildTideWorldController
var _titan: WildDashMangroveTitanController
var _initialized: bool = false

func _ready() -> void:
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	for _attempt: int in range(60):
		var parent_node: Node = get_parent()
		if parent_node != null:
			_world = parent_node.get_node_or_null("WildTideWorldController") as WildDashWildTideWorldController
			_titan = parent_node.get_node_or_null("MangroveTitanController") as WildDashMangroveTitanController
		_safe_anchors.clear()
		for node: Node in get_tree().get_nodes_in_group("wild_tide_safe_respawn"):
			var marker: Marker3D = node as Marker3D
			if marker != null:
				_safe_anchors.append(marker)
		if _world != null and not _safe_anchors.is_empty():
			break
		await get_tree().physics_frame
	_initialized = _world != null and not _safe_anchors.is_empty()
	print("WILD TIDE RESPAWN GUARD ready=%s safe_anchors=%d" % [str(_initialized), _safe_anchors.size()])

func _physics_process(_delta: float) -> void:
	if not _initialized or not RaceManager.active:
		return
	for racer_value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = racer_value as WildDashCharacterController
		if racer == null or racer.finished or racer.global_position.y >= FALL_Y:
			continue
		var candidate: Vector3 = RaceManager.get_respawn_position(racer)
		if _is_candidate_safe(candidate):
			_respawn(racer, candidate, "checkpoint")
		else:
			_respawn(racer, _nearest_safe_anchor(candidate), "wild_tide_anchor")

func _is_candidate_safe(position: Vector3) -> bool:
	if _world != null and _world.is_position_water(position):
		return false
	if _titan != null and _titan.get_active_hazard() != &"":
		if position.distance_to(_titan.get_active_hazard_center()) < HAZARD_SAFE_RADIUS:
			return false
	return true

func _nearest_safe_anchor(from_position: Vector3) -> Vector3:
	var best_position: Vector3 = from_position + Vector3.UP * 0.8
	var best_distance: float = INF
	for marker: Marker3D in _safe_anchors:
		if marker == null or not is_instance_valid(marker):
			continue
		var position: Vector3 = marker.global_position + Vector3.UP * 0.35
		if _world != null and _world.is_position_water(position):
			continue
		var distance: float = from_position.distance_squared_to(position)
		if distance < best_distance:
			best_distance = distance
			best_position = position
	return best_position

func _respawn(racer: WildDashCharacterController, position: Vector3, source: String) -> void:
	racer.reset_motion(position)
	racer.current_speed = maxf(racer.current_speed, racer.cruise_speed * 0.70)
	print("WILD TIDE SAFE RESPAWN racer=%s source=%s position=%s" % [
		RaceManager.get_racer_label(racer), source, str(position),
	])
