extends "res://modes/logspire_leap/logspire_water_submerge_watchdog_v2_route_support.gd"

## Live-route-aware hard reset authority.
##
## V2 correctly protects authored support when a foot ray hits it, but a racer can
## be legitimately airborne for a few frames over a jump seam or connector. In
## those frames no support collider exists and the stale legacy water height can
## still start the hard-reset timer. Production V3 asks WaterRecovery V16 whether
## the racer is spatially inside the live Safe Route corridor before permitting
## any deep-water reset.

func _route_support_hit(racer: WildDashCharacterController) -> Dictionary:
	var physical_support: Dictionary = super(racer)
	if not physical_support.is_empty():
		return physical_support
	if _water == null or not _water.has_method("is_route_corridor_protected"):
		return {}
	if not bool(_water.call("is_route_corridor_protected", racer)):
		return {}
	var status_value: Variant = _water.call("get_route_corridor_status", racer) if _water.has_method("get_route_corridor_status") else {}
	var status: Dictionary = status_value if status_value is Dictionary else {}
	var from_id := StringName(status.get("from", &""))
	var to_id := StringName(status.get("to", &""))
	return {
		"support": "LiveRouteCorridor:%s->%s" % [String(from_id), String(to_id)],
		"route_corridor": true,
		"planar_distance": float(status.get("planar_distance", -1.0)),
		"below_route": float(status.get("below_route", 0.0)),
	}
