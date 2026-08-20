extends "res://modes/logspire_leap/logspire_jump_rebalance_v2_phase_b.gd"

## Round 3 Titan Tree accessibility hotfix.
## The original Zone 5 authored platforms rise by roughly 1.8m to 2.2m per
## platform. Dog's baseline jump cannot reliably clear that as a vertical ledge.
## Keep the horizontal route and challenge intact, but cap Safe Route upward
## steps through Titan Tree and propagate the resulting height shift through all
## later platforms so the course remains continuous.

const TITAN_TREE_ZONE_INDEX: int = 4
const TITAN_TREE_MAX_SAFE_RISE: float = 1.10

func _apply_course_rebalance() -> void:
	super()
	_apply_titan_tree_vertical_accessibility()

func _apply_titan_tree_vertical_accessibility() -> void:
	if _world == null or _safe_ids.size() < 2:
		return
	var positions_value: Variant = _world.get("_platform_positions")
	var sizes_value: Variant = _world.get("_platform_sizes")
	if not (positions_value is Array) or not (sizes_value is Array):
		push_warning("LOGSPIRE TITAN ACCESSIBILITY world arrays unavailable")
		return
	var positions: Array = positions_value
	var sizes: Array = sizes_value
	var first_index: int = int(_index_by_id.get(_safe_ids[0], -1))
	if first_index < 0 or first_index >= positions.size():
		return

	var accumulated_shift: float = 0.0
	var previous_position: Vector3 = positions[first_index]
	var clamped_steps: int = 0
	var total_lowering: float = 0.0

	for i: int in range(1, _safe_ids.size()):
		var platform_id: StringName = _safe_ids[i]
		var index: int = int(_index_by_id.get(platform_id, -1))
		if index < 0 or index >= positions.size():
			continue
		var adjusted: Vector3 = positions[index]
		adjusted.y += accumulated_shift
		var zone: int = int(_world.call("get_platform_zone", platform_id))
		if zone == TITAN_TREE_ZONE_INDEX:
			var rise: float = adjusted.y - previous_position.y
			if rise > TITAN_TREE_MAX_SAFE_RISE:
				var correction: float = TITAN_TREE_MAX_SAFE_RISE - rise
				accumulated_shift += correction
				adjusted.y += correction
				total_lowering += -correction
				clamped_steps += 1
		positions[index] = adjusted
		previous_position = adjusted

	if clamped_steps <= 0:
		return

	_world.set("_platform_positions", positions)
	_update_course_geometry(positions, sizes)
	_recenter_recovery_decks()
	_update_course_length()
	print("LOGSPIRE TITAN ACCESSIBILITY READY clamped_steps=%d max_safe_rise=%.2fm propagated_lowering=%.2fm route_continuous=true" % [
		clamped_steps,
		TITAN_TREE_MAX_SAFE_RISE,
		total_lowering,
	])
