extends "res://modes/logspire_leap/logspire_ladder_system_v4_safe_exit.gd"

## Adds stable authored traversal points to the safe-exit recovery network.
## Root ramps remain visible geometry, but V8 water recovery can now own the
## complete climb instead of dropping racers onto the first step and hoping
## the normal race controller can finish the route.

const ROOT_PATH_POINT_COUNT: int = 5

func configure(world: Node, graph: Node, water_heights: Dictionary) -> void:
	super(world, graph, water_heights)
	_enrich_root_paths()
	print("LOGSPIRE RECOVERY PATHS READY root_ramps=%d path_points=%d" % [
		_root_ramps.size(), ROOT_PATH_POINT_COUNT,
	])

func _enrich_root_paths() -> void:
	for i: int in range(_root_ramps.size()):
		var ramp: Dictionary = _root_ramps[i]
		var entry_value: Variant = ramp.get("entry", Vector3.ZERO)
		var exit_value: Variant = ramp.get("exit", Vector3.ZERO)
		if not (entry_value is Vector3) or not (exit_value is Vector3):
			continue
		var entry: Vector3 = entry_value
		var exit_position: Vector3 = exit_value
		var points: Array[Vector3] = []
		for point_index: int in range(ROOT_PATH_POINT_COUNT):
			var t: float = float(point_index) / float(ROOT_PATH_POINT_COUNT - 1)
			var point := entry.lerp(exit_position, t)
			# A tiny lift keeps the capsule from scraping the visible root steps.
			if point_index > 0 and point_index < ROOT_PATH_POINT_COUNT - 1:
				point.y += 0.12
			points.append(point)
		ramp["path_points"] = points
		ramp["path_point_count"] = ROOT_PATH_POINT_COUNT
		_root_ramps[i] = ramp
