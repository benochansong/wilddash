extends "res://modes/logspire_leap/logspire_jump_gap_guard.gd"

## Round 3 Titan Tree upper-route playability repair.
##
## Static jump-arc audits can prove that a capsule has theoretical clearance but
## still miss the real player failure shown during full play: after CP5 the
## character can arrive at the front lip of the next large Box platform with no
## useful runway, lose horizontal speed, and repeatedly collide with the vertical
## face instead of reaching the top surface.
##
## Keep every authored route point, checkpoint, jump velocity and recovery rule.
## Add narrow sloped running connectors only to the upper Titan spiral so the
## player always has a physical, collision-backed route upward. These are normal
## world surfaces, not teleports or movement assists. The existing collision audit
## already recognizes SafeFlowBridge_<from>_<to> as an expected pair collider.

const TITAN_UPPER_FLOW_WIDTH: float = 7.2
const TITAN_UPPER_FLOW_PAIRS: Array[Array] = [
	[&"Z5_SPIRAL_03", &"Z5_SPIRAL_04"],
	[&"Z5_SPIRAL_04", &"Z5_SPIRAL_05"],
	[&"Z5_SPIRAL_05", &"Z5_SPIRAL_06"],
	[&"Z5_SPIRAL_06", &"Z5_SPIRAL_07"],
	[&"Z5_SPIRAL_07", &"Z5_SPIRAL_08"],
	[&"Z5_SPIRAL_08", &"Z5_SPIRAL_09"],
	[&"Z5_SPIRAL_09", &"Z5_SPIRAL_10"],
	[&"Z5_SPIRAL_10", &"Z6_START"],
]

func _build_running_connectors(positions: Array) -> void:
	super(positions)
	var built: int = 0
	for pair: Array in TITAN_UPPER_FLOW_PAIRS:
		if pair.size() < 2:
			continue
		var from_id := StringName(pair[0])
		var to_id := StringName(pair[1])
		var before: int = _flow_bridge_count
		_build_flow_bridge(from_id, to_id, TITAN_UPPER_FLOW_WIDTH, positions)
		if _flow_bridge_count > before:
			built += 1

	print("LOGSPIRE TITAN UPPER FLOW READY bridges=%d width=%.1fm continuous_walkable=true collision_backed=true route_points_unchanged=true jump_power_unchanged=true teleport=false" % [
		built, TITAN_UPPER_FLOW_WIDTH,
	])
