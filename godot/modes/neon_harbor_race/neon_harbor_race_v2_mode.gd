extends "res://modes/neon_harbor_race/neon_harbor_race_mode.gd"

## Neon Harbor V2 Phase 1 adapter.
## Ability shortcuts and tactical lane branches belong to Phase 3. Until the
## grounded route is graphically proven, every AI shortcut request is routed
## back to the authoritative main course so Phase 1 validates one clean path.

func _build_shortcut_route(_skip_route_index: int) -> Array[Vector3]:
	return _build_race_route_with_runout()
