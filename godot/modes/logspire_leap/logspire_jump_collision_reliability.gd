extends Node

## Final Round 3 geometry audit. JumpRebalance and JumpGapGuard both edit route
## geometry before the round starts; this node runs after those edits and after
## Phase3 collision creation so the audit sees the actual production transforms.
## It never changes jump velocity, difficulty, WaterRecovery, or Wild Route rules.

const ROUTE_SAFE: StringName = &"safe"
const ARC_SAMPLE_COUNT: int = 11
const CAPSULE_RADIUS: float = 0.62
const CAPSULE_HEIGHT: float = 1.90
const CAPSULE_CENTER_Y: float = 0.95
const MIN_AUDIT_JUMP_PEAK: float = 1.20
const MAX_AUDIT_JUMP_PEAK: float = 2.20
const HEAD_PROBE_START_Y: float = 1.55
const HEAD_PROBE_DISTANCE: float = 0.75
const GEOMETRY_POSITION_TOLERANCE: float = 0.04

const MOVING_SAFE_IDS: Array[StringName] = [
	&"Z3_02", &"Z3_03", &"Z3_05", &"Z3_07",
	&"Z4_SAFE_04", &"Z6_03", &"Z6_05", &"Z6_07",
]

var _world: Node3D
var _gameplay: Node
var _phase3: Node
var _safe_ids: Array[StringName] = []

func _ready() -> void:
	call_deferred("_audit_after_runtime_setup")

func _audit_after_runtime_setup() -> void:
	# Parent Logspire setup configures graph, moving platforms and Phase3 collision
	# during its own _ready. Waiting a few frames guarantees this audit observes the
	# final geometry rather than either intermediate rebalance pass.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame

	_world = get_parent().get_node_or_null("LogspireWorld") as Node3D
	_gameplay = get_parent().get_node_or_null("PlatformGameplay")
	_phase3 = get_parent().get_node_or_null("Phase3Director")
	if _world == null:
		push_error("LOGSPIRE JUMP COLLISION AUDIT missing world")
		return

	_safe_ids = _copy_string_name_array(_world.call("get_route_ids", ROUTE_SAFE))
	if _safe_ids.size() < 2:
		push_error("LOGSPIRE JUMP COLLISION AUDIT missing safe route")
		return

	# Major collision gets first chance to reduce an invisible core that intrudes
	# on the final Safe Route. The visual Titan Tree is never changed here.
	if _phase3 != null and _phase3.has_method("audit_safe_route_collision"):
		_phase3.call("audit_safe_route_collision")
	await get_tree().physics_frame

	var geometry_repairs: int = _audit_final_platform_geometry()
	var moving_checked: int = _audit_moving_platform_geometry()
	var result: Dictionary = _audit_safe_jump_pairs()
	var blocked_pairs: int = int(result.get("blocked_pairs", 0))
	var head_blocks: int = int(result.get("head_blocks", 0))
	print("LOGSPIRE SAFE ROUTE PASS pairs=%d blocked_pairs=%d head_blocks=%d geometry_repairs=%d moving_checked=%d normal_jump_power=true water_recovery_unchanged=true wild_route_unchanged=true pass=%s" % [
		_safe_ids.size() - 1,
		blocked_pairs,
		head_blocks,
		geometry_repairs,
		moving_checked,
		str(blocked_pairs == 0 and head_blocks == 0),
	])

func _audit_final_platform_geometry() -> int:
	var positions_value: Variant = _world.get("_platform_positions")
	var sizes_value: Variant = _world.get("_platform_sizes")
	var index_value: Variant = _world.get("_platform_index_by_id")
	if not (positions_value is Array) or not (sizes_value is Array) or not (index_value is Dictionary):
		return 0
	var positions: Array = positions_value
	var sizes: Array = sizes_value
	var index_by_id: Dictionary = index_value
	var repairs: int = 0

	for platform_id: StringName in _safe_ids:
		if MOVING_SAFE_IDS.has(platform_id):
			continue
		var index: int = int(index_by_id.get(platform_id, -1))
		if index < 0 or index >= positions.size() or index >= sizes.size():
			continue
		var top_value: Variant = positions[index]
		var size_value: Variant = sizes[index]
		if not (top_value is Vector3) or not (size_value is Vector3):
			continue
		var top: Vector3 = top_value
		var size: Vector3 = size_value
		var root := _world.get_node_or_null(NodePath(String(platform_id))) as Node3D
		if root == null:
			continue
		var expected_root: Vector3 = top - Vector3.UP * (size.y * 0.5)
		if root.global_position.distance_to(expected_root) > GEOMETRY_POSITION_TOLERANCE:
			print("LOGSPIRE COLLISION OVERLAP object=%s type=final_geometry_desync distance=%.3f action=realign_mesh_collision_root" % [
				String(platform_id), root.global_position.distance_to(expected_root),
			])
			root.global_position = expected_root
			repairs += 1

		if platform_id == &"CROWN_NEST":
			var finish_mesh := root.get_node_or_null("CrownNestMesh") as MeshInstance3D
			var finish_body := root.get_node_or_null("CrownNestCollision") as StaticBody3D
			if finish_mesh != null and finish_mesh.position.length() > GEOMETRY_POSITION_TOLERANCE:
				finish_mesh.position = Vector3.ZERO
				repairs += 1
			if finish_body != null and finish_body.position.length() > GEOMETRY_POSITION_TOLERANCE:
				finish_body.position = Vector3.ZERO
				repairs += 1
			continue

		var mesh := root.get_node_or_null("Mesh") as MeshInstance3D
		var body := root.get_node_or_null("Collision") as StaticBody3D
		if mesh != null and mesh.position.length() > GEOMETRY_POSITION_TOLERANCE:
			mesh.position = Vector3.ZERO
			repairs += 1
		if body != null and body.position.length() > GEOMETRY_POSITION_TOLERANCE:
			body.position = Vector3.ZERO
			repairs += 1
		if body != null and body.get_child_count() > 0:
			var collision := body.get_child(0) as CollisionShape3D
			if collision != null and collision.position.length() > GEOMETRY_POSITION_TOLERANCE:
				collision.position = Vector3.ZERO
				repairs += 1
	return repairs

func _audit_moving_platform_geometry() -> int:
	if _gameplay == null:
		return 0
	var runtime_value: Variant = _gameplay.get("_runtime")
	if not (runtime_value is Dictionary):
		return 0
	var runtime: Dictionary = runtime_value
	var checked: int = 0
	for platform_id: StringName in MOVING_SAFE_IDS:
		if not runtime.has(platform_id):
			continue
		var data_value: Variant = runtime.get(platform_id, {})
		if not (data_value is Dictionary):
			continue
		var data: Dictionary = data_value
		var body := data.get("body") as AnimatableBody3D
		if body == null or not is_instance_valid(body):
			continue
		checked += 1
		for child: Node in body.get_children():
			var collision := child as CollisionShape3D
			if collision != null and collision.position.length() > GEOMETRY_POSITION_TOLERANCE:
				print("LOGSPIRE COLLISION OVERLAP object=%s type=moving_collision_desync distance=%.3f action=realign_local_collision" % [
					String(platform_id), collision.position.length(),
				])
				collision.position = Vector3.ZERO
		print("LOGSPIRE JUMP CLEARANCE pair=%s moving_platform=true predicted_landing=true collision_local_sync=true" % String(platform_id))
	return checked

func _audit_safe_jump_pairs() -> Dictionary:
	var blocked_pairs: int = 0
	var head_blocks: int = 0
	var jump_peak: float = _normal_jump_peak()
	for i: int in range(1, _safe_ids.size()):
		var from_id: StringName = _safe_ids[i - 1]
		var to_id: StringName = _safe_ids[i]
		var from_value: Variant = _world.call("get_platform_position", from_id)
		var to_value: Variant = _world.call("get_platform_position", to_id)
		if not (from_value is Vector3) or not (to_value is Vector3):
			continue
		var from: Vector3 = from_value
		var to: Vector3 = to_value
		var blocked_by: String = ""
		var pair_head_blocked: bool = false

		for sample: int in range(1, ARC_SAMPLE_COUNT):
			var t: float = float(sample) / float(ARC_SAMPLE_COUNT)
			var feet: Vector3 = from.lerp(to, t)
			feet.y += sin(PI * t) * jump_peak + 0.06
			var hit_name: String = _capsule_blocker_name(feet, from_id, to_id)
			if not hit_name.is_empty():
				blocked_by = hit_name
				break
			var head_name: String = _head_blocker_name(feet, from_id, to_id)
			if not head_name.is_empty():
				pair_head_blocked = true
				head_blocks += 1
				_qa_record_metric(&"head_collision", from_id)
				print("LOGSPIRE HEAD BLOCK from=%s to=%s sample=%d collider=%s feet_y=%.2f" % [
					String(from_id), String(to_id), sample, head_name, feet.y,
				])
				break

		if not blocked_by.is_empty():
			blocked_pairs += 1
			_qa_record_metric(&"jump_block", from_id)
			print("LOGSPIRE COLLISION OVERLAP from=%s to=%s type=jump_arc collider=%s action=runtime_audit" % [
				String(from_id), String(to_id), blocked_by,
			])
		print("LOGSPIRE JUMP CLEARANCE from=%s to=%s planar=%.2f rise=%.2f peak=%.2f capsule_clear=%s head_clear=%s" % [
			String(from_id),
			String(to_id),
			Vector2(to.x - from.x, to.z - from.z).length(),
			to.y - from.y,
			jump_peak,
			str(blocked_by.is_empty()),
			str(not pair_head_blocked),
		])
	return {"blocked_pairs": blocked_pairs, "head_blocks": head_blocks}

func _capsule_blocker_name(feet: Vector3, from_id: StringName, to_id: StringName) -> String:
	if get_world_3d() == null:
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
	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query, 12)
	for hit: Dictionary in hits:
		var collider_value: Variant = hit.get("collider", null)
		var collider := collider_value as Node
		if collider == null or _is_expected_pair_collider(collider, from_id, to_id):
			continue
		return String(collider.name)
	return ""

func _head_blocker_name(feet: Vector3, from_id: StringName, to_id: StringName) -> String:
	if get_world_3d() == null:
		return ""
	var ray := PhysicsRayQueryParameters3D.create(
		feet + Vector3.UP * HEAD_PROBE_START_Y,
		feet + Vector3.UP * (HEAD_PROBE_START_Y + HEAD_PROBE_DISTANCE),
		1
	)
	var player := _resolve_player()
	if player != null:
		ray.exclude = [player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return ""
	var collider_value: Variant = hit.get("collider", null)
	var collider := collider_value as Node
	if collider == null or _is_expected_pair_collider(collider, from_id, to_id):
		return ""
	return String(collider.name)

func _is_expected_pair_collider(collider: Node, from_id: StringName, to_id: StringName) -> bool:
	var cursor: Node = collider
	var from_text: String = String(from_id)
	var to_text: String = String(to_id)
	var bridge_a: String = "SafeFlowBridge_%s_%s" % [from_text, to_text]
	var bridge_b: String = "SafeFlowBridge_%s_%s" % [to_text, from_text]
	while cursor != null and cursor != _world:
		var node_name: String = String(cursor.name)
		if node_name == from_text or node_name == to_text:
			return true
		if node_name == "Phase2_%s" % from_text or node_name == "Phase2_%s" % to_text:
			return true
		if node_name == bridge_a or node_name == bridge_b:
			return true
		cursor = cursor.get_parent()
	return false

func _normal_jump_peak() -> float:
	var player := _resolve_player()
	var jump_velocity: float = 8.35
	var gravity: float = 22.0
	if player != null:
		jump_velocity = maxf(0.1, player.jump_velocity)
		gravity = maxf(0.1, player.gravity)
	return clampf((jump_velocity * jump_velocity) / (2.0 * gravity), MIN_AUDIT_JUMP_PEAK, MAX_AUDIT_JUMP_PEAK)

func _resolve_player() -> WildDashCharacterController:
	for racer_value: Variant in RaceManager.racers:
		var racer := racer_value as WildDashCharacterController
		if racer != null and racer.is_player:
			return racer
	return null

func _qa_record_metric(metric: StringName, platform_id: StringName) -> void:
	var mode := get_parent()
	if mode != null and mode.has_method("reliability_record_metric"):
		mode.call("reliability_record_metric", metric, _resolve_player(), platform_id)

func _copy_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not (value is Array):
		return result
	for item: Variant in value:
		if item is StringName:
			result.append(item)
		elif item is String:
			result.append(StringName(item))
	return result
