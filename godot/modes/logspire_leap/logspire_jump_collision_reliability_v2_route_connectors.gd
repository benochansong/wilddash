extends "res://modes/logspire_leap/logspire_jump_collision_reliability.gd"

## Production collision-audit adapter.
## Living Tree ramps and the Z6_04 moving branch are authored traversal surfaces,
## not obstacles. The base audit already ignores ordinary endpoint platforms and
## SafeFlowBridge connectors; this adapter adds the Phase3 route connectors while
## preserving detection of every unrelated third-party collider.

func _is_expected_pair_collider(collider: Node, from_id: StringName, to_id: StringName) -> bool:
	if super(collider, from_id, to_id):
		return true
	var owner_names: Array[String] = []
	var cursor: Node = collider
	while cursor != null and cursor != _world:
		owner_names.append(String(cursor.name))
		cursor = cursor.get_parent()

	if _pair_matches(from_id, to_id, &"Z5_SPIRAL_03", &"Z5_SPIRAL_04") and owner_names.has("LivingBranch_1"):
		return true
	if _pair_matches(from_id, to_id, &"Z5_SPIRAL_05", &"Z5_SPIRAL_06") and owner_names.has("LivingBranch_2"):
		return true
	if (
		_pair_matches(from_id, to_id, &"Z6_03", &"Z6_04")
		or _pair_matches(from_id, to_id, &"Z6_04", &"Z6_05")
	) and owner_names.has("SkyFinaleMovingBranch"):
		return true
	return false

func _pair_matches(a: StringName, b: StringName, expected_a: StringName, expected_b: StringName) -> bool:
	return (a == expected_a and b == expected_b) or (a == expected_b and b == expected_a)
