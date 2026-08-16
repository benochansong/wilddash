extends RefCounted

## Lightweight ladder selector for racers recovering through the Canopy River.
## Distance is primary, but route progress slightly favors exits that continue
## forward through the same zone instead of sending an AI backwards.

func choose_ladder(
	racer: WildDashCharacterController,
	zone: int,
	ladders: Array,
	checkpoint_progress: int
) -> Dictionary:
	if racer == null:
		return {}
	var best: Dictionary = {}
	var best_score: float = INF
	for value: Variant in ladders:
		if not (value is Dictionary):
			continue
		var ladder: Dictionary = value
		if int(ladder.get("zone", -1)) != zone:
			continue
		var bottom_value: Variant = ladder.get("bottom", Vector3.ZERO)
		if not (bottom_value is Vector3):
			continue
		var bottom: Vector3 = bottom_value
		var planar_distance: float = Vector2(
			racer.global_position.x - bottom.x,
			racer.global_position.z - bottom.z
		).length()
		var route_index: int = int(ladder.get("route_index", 0))
		var progress_bonus: float = minf(8.0, float(route_index) * 0.08)
		var checkpoint_penalty: float = absf(float(zone - clampi(checkpoint_progress, 0, 5))) * 3.0
		var score: float = planar_distance + checkpoint_penalty - progress_bonus
		if score < best_score:
			best_score = score
			best = ladder
	return best
