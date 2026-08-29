class_name WildDashWildTideRespawnGuardV2LongWater
extends "res://modes/neon_harbor_race/wild_tide_respawn_guard.gd"

## Long-water checkpoints are intentionally inside gameplay water. The water
## course has hidden support collision, so a checkpoint on water is a valid safe
## respawn instead of a reason to throw the racer hundreds of metres backward.

func _is_candidate_safe(position: Vector3) -> bool:
	if _titan != null and _titan.get_active_hazard() != &"":
		if position.distance_to(_titan.get_active_hazard_center()) < HAZARD_SAFE_RADIUS:
			return false
	# Water itself is safe in Wild Tide: every active water segment has a hidden
	# support floor and explicit gameplay Area. Falling below the course remains
	# handled by the guard before this check.
	return true

func _nearest_safe_anchor(from_position: Vector3) -> Vector3:
	var best_position: Vector3 = from_position + Vector3.UP * 0.8
	var best_distance: float = INF
	for marker: Marker3D in _safe_anchors:
		if marker == null or not is_instance_valid(marker):
			continue
		var position: Vector3 = marker.global_position + Vector3.UP * 0.35
		if _titan != null and _titan.get_active_hazard() != &"":
			if position.distance_to(_titan.get_active_hazard_center()) < HAZARD_SAFE_RADIUS:
				continue
		var distance: float = from_position.distance_squared_to(position)
		if distance < best_distance:
			best_distance = distance
			best_position = position
	return best_position
