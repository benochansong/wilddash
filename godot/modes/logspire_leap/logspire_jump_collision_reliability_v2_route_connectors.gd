extends "res://modes/logspire_leap/logspire_jump_collision_reliability.gd"

## Production collision-audit adapter.
## Living Tree ramps, the Z6_04 moving branch, and explicitly tagged late Titan
## CP5 traversal ramps are authored traversal surfaces, not obstacles. The base
## audit already ignores ordinary endpoint platforms and SafeFlowBridge
## connectors; this adapter adds the Phase3 route connectors while preserving
## detection of every unrelated third-party collider.
##
## The base audit printed only the StaticBody name (`Collision`), which hid the
## owning platform. V2 reports the ancestry label as well so a third-platform
## overlap in the curved Titan spiral can be repaired deterministically.

func _capsule_blocker_name(feet: Vector3, from_id: StringName, to_id: StringName) -> String:
	var physics_world: World3D = _physics_world()
	if physics_world == null:
		return ""
	var shape := CapsuleShape3D.new()
	shape.radius = CAPSULE_RADIUS
	shape.height = CAPSULE_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * CAPSULE_CENTER_Y)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var player := _resolve_player()
	if player != null:
		query.exclude = [player.get_rid()]
	var hits: Array[Dictionary] = physics_world.direct_space_state.intersect_shape(query, 12)
	for hit: Dictionary in hits:
		var collider := hit.get("collider", null) as Node
		if collider == null or _is_expected_pair_collider(collider, from_id, to_id):
			continue
		return _collider_label(collider)
	return ""

func _head_blocker_name(feet: Vector3, from_id: StringName, to_id: StringName) -> String:
	var physics_world: World3D = _physics_world()
	if physics_world == null:
		return ""
	var ray := PhysicsRayQueryParameters3D.create(
		feet + Vector3.UP * HEAD_PROBE_START_Y,
		feet + Vector3.UP * (HEAD_PROBE_START_Y + HEAD_PROBE_DISTANCE),
		1
	)
	var player := _resolve_player()
	if player != null:
		ray.exclude = [player.get_rid()]
	var hit: Dictionary = physics_world.direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return ""
	var collider := hit.get("collider", null) as Node
	if collider == null or _is_expected_pair_collider(collider, from_id, to_id):
		return ""
	return _collider_label(collider)

func _collider_label(collider: Node) -> String:
	var names: Array[String] = []
	var cursor: Node = collider
	while cursor != null and cursor != _world and names.size() < 5:
		names.append(String(cursor.name))
		cursor = cursor.get_parent()
	return "<-".join(names)

func _is_expected_pair_collider(collider: Node, from_id: StringName, to_id: StringName) -> bool:
	if super(collider, from_id, to_id):
		return true
	var owner_names: Array[String] = []
	var cursor: Node = collider
	while cursor != null and cursor != _world:
		if bool(cursor.get_meta("logspire_route_connector", false)):
			var route_from := StringName(cursor.get_meta("logspire_route_from", &""))
			var route_to := StringName(cursor.get_meta("logspire_route_to", &""))
			if _pair_matches(from_id, to_id, route_from, route_to):
				return true
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
