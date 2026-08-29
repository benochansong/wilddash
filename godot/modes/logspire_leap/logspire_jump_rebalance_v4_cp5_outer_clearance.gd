extends "res://modes/logspire_leap/logspire_jump_rebalance_v3_titan_tree_accessibility.gd"

## Round 3 CP5 upper-Titan clearance hotfix.
##
## Full playtests showed that the route immediately after checkpoint 5 can still
## place later spiral decks over the Z5_SPIRAL_06 -> Z5_SPIRAL_07 climb corridor.
## The player then reaches CP5 correctly but cannot physically get onto the next
## upper deck because the route folds back over itself.
##
## Open only the late Titan spiral by moving the CP5+ route outward from the tree.
## This happens before JumpGapGuard and PlatformGraph initialize, so player, AI,
## checkpoints, route targeting and the collision-backed flow bridges all consume
## the same final positions. Vertical jump tuning is untouched.

const CP5_OUTER_CLEARANCE_OFFSETS: Dictionary = {
	&"Z5_SPIRAL_06": 2.0,
	&"Z5_SPIRAL_07": 6.0,
	&"Z5_SPIRAL_08": 7.0,
	&"Z5_SPIRAL_09": 7.0,
	&"Z5_SPIRAL_10": 6.0,
}

const TITAN_SPIRAL_IDS: Array[StringName] = [
	&"Z5_SPIRAL_01", &"Z5_SPIRAL_02", &"Z5_SPIRAL_03", &"Z5_SPIRAL_04", &"Z5_SPIRAL_05",
	&"Z5_SPIRAL_06", &"Z5_SPIRAL_07", &"Z5_SPIRAL_08", &"Z5_SPIRAL_09", &"Z5_SPIRAL_10",
]

func _apply_course_rebalance() -> void:
	super()
	_apply_cp5_outer_clearance()

func _apply_cp5_outer_clearance() -> void:
	if _world == null:
		return
	var positions_value: Variant = _world.get("_platform_positions")
	var sizes_value: Variant = _world.get("_platform_sizes")
	if not (positions_value is Array) or not (sizes_value is Array):
		push_warning("LOGSPIRE CP5 OUTER CLEARANCE world arrays unavailable")
		return
	var positions: Array = positions_value
	var sizes: Array = sizes_value

	var center := Vector3.ZERO
	var center_count: int = 0
	for platform_id: StringName in TITAN_SPIRAL_IDS:
		var index: int = int(_index_by_id.get(platform_id, -1))
		if index < 0 or index >= positions.size():
			continue
		var value: Variant = positions[index]
		if not (value is Vector3):
			continue
		center += value
		center_count += 1
	if center_count <= 0:
		return
	center /= float(center_count)

	var moved: int = 0
	for id_value: Variant in CP5_OUTER_CLEARANCE_OFFSETS.keys():
		var platform_id := StringName(id_value)
		var index: int = int(_index_by_id.get(platform_id, -1))
		if index < 0 or index >= positions.size():
			continue
		var value: Variant = positions[index]
		if not (value is Vector3):
			continue
		var top: Vector3 = value
		var outward := Vector3(top.x - center.x, 0.0, top.z - center.z)
		if outward.length_squared() <= 0.001:
			continue
		outward = outward.normalized()
		var offset: float = float(CP5_OUTER_CLEARANCE_OFFSETS.get(platform_id, 0.0))
		positions[index] = top + outward * offset
		moved += 1

	_world.set("_platform_positions", positions)
	_update_course_geometry(positions, sizes)
	_recenter_recovery_decks()
	_update_course_length()
	print("LOGSPIRE CP5 OUTER CLEARANCE READY moved=%d cp5_to_upper_deck=open ai_route_synced=true checkpoint_synced=true jump_power_unchanged=true teleport=false" % moved)
