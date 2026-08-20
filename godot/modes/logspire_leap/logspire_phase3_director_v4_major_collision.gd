extends "res://modes/logspire_leap/logspire_phase3_director_v3_water_priority.gd"

## Player-tested collision authority for the large Phase 3 tree geometry.
## Visual geometry and gameplay collision are deliberately separate. The major
## collision pass audits the final Safe Route before play and may reduce only the
## invisible collision core when a normal jump corridor would otherwise be hit.

const MAJOR_WORLD_COLLISION_LAYER: int = 5 # layer 1 gameplay + layer 3 traversal query
const TITAN_TRUNK_COLLISION_RADIUS: float = 9.15
const TITAN_TRUNK_COLLISION_HEIGHT: float = 84.0
const TITAN_ROOT_COLLISION_SIZE := Vector3(4.6, 2.0, 22.0)
const SAFE_ROUTE_COLLISION_MARGIN: float = 1.45
const TITAN_TRUNK_HARD_MIN_RADIUS: float = 3.8
const TITAN_ROOT_VERTICAL_MARGIN: float = 2.6

var _major_collision_root: Node3D

func configure(world: Node, graph: Node) -> void:
	super(world, graph)
	_build_major_world_collision()
	audit_safe_route_collision()

func _build_major_world_collision() -> void:
	if _world == null:
		return
	var existing := _world.get_node_or_null("LogspireMajorWorldCollision") as Node3D
	if existing != null:
		existing.queue_free()

	_major_collision_root = Node3D.new()
	_major_collision_root.name = "LogspireMajorWorldCollision"
	_world.add_child(_major_collision_root)

	# Titan visuals remain untouched. This cylinder is gameplay-only and can be
	# conservatively reduced by the Safe Route audit without changing the mesh.
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = TITAN_TRUNK_COLLISION_RADIUS
	trunk_shape.height = TITAN_TRUNK_COLLISION_HEIGHT
	_add_major_static_body(
		"TitanTrunkCollision",
		Vector3(_titan_center.x, 37.0, _titan_center.z),
		Vector3.ZERO,
		trunk_shape
	)

	# Giant-root collision is smaller than the visible root mesh. Root collision
	# stays near the basin floor and is independently audited against the route.
	for i: int in range(8):
		var angle: float = TAU * float(i) / 8.0
		var direction := Vector3(sin(angle), 0.0, cos(angle))
		var root_shape := BoxShape3D.new()
		root_shape.size = TITAN_ROOT_COLLISION_SIZE
		_add_major_static_body(
			"TitanRootCollision_%02d" % i,
			Vector3(_titan_center.x, 2.0, _titan_center.z) + direction * 9.0,
			Vector3(0.0, angle, 0.0),
			root_shape
		)

	print("LOGSPIRE MAJOR WORLD COLLISION READY trunk=1 roots=8 layer1=true traversal_query_layer=4 phase_through=false visual_collision_separate=true")

func audit_safe_route_collision() -> void:
	if _world == null or _major_collision_root == null:
		return
	var ids_value: Variant = _world.call("get_route_ids", &"safe")
	if not (ids_value is Array):
		return
	var safe_ids: Array = ids_value
	if safe_ids.size() < 2:
		return

	var trunk_body := _major_collision_root.get_node_or_null("TitanTrunkCollision") as StaticBody3D
	var trunk_adjusted: bool = false
	var closest_trunk_distance: float = INF
	if trunk_body != null and trunk_body.get_child_count() > 0:
		var trunk_collision := trunk_body.get_child(0) as CollisionShape3D
		var trunk_shape := trunk_collision.shape as CylinderShape3D if trunk_collision != null else null
		if trunk_shape != null:
			closest_trunk_distance = _closest_safe_route_planar_distance(_titan_center, safe_ids)
			var allowed_radius: float = maxf(TITAN_TRUNK_HARD_MIN_RADIUS, closest_trunk_distance - SAFE_ROUTE_COLLISION_MARGIN)
			if allowed_radius < trunk_shape.radius - 0.01:
				print("LOGSPIRE COLLISION OVERLAP object=TitanTrunkCollision route=safe closest=%.2f old_radius=%.2f allowed=%.2f action=shrink_collision_only" % [
					closest_trunk_distance, trunk_shape.radius, allowed_radius,
				])
				trunk_shape.radius = allowed_radius
				trunk_adjusted = true

	var root_overlap_count: int = 0
	for child: Node in _major_collision_root.get_children():
		var root_body := child as StaticBody3D
		if root_body == null or not String(root_body.name).begins_with("TitanRootCollision_"):
			continue
		if _root_collision_intrudes_safe_route(root_body, safe_ids):
			root_overlap_count += 1
			var collision := root_body.get_child(0) as CollisionShape3D if root_body.get_child_count() > 0 else null
			var shape := collision.shape as BoxShape3D if collision != null else null
			if shape != null:
				var old_size: Vector3 = shape.size
				shape.size = Vector3(minf(old_size.x, 3.8), old_size.y, minf(old_size.z, 16.0))
				print("LOGSPIRE COLLISION OVERLAP object=%s route=safe old_size=(%.2f,%.2f,%.2f) new_size=(%.2f,%.2f,%.2f) action=shrink_collision_only" % [
					String(root_body.name), old_size.x, old_size.y, old_size.z, shape.size.x, shape.size.y, shape.size.z,
				])

	print("LOGSPIRE TITAN COLLISION AUDIT closest_trunk=%.2f trunk_radius=%.2f trunk_adjusted=%s root_overlaps=%d visual_mesh_unchanged=true safe_route_margin=%.2f" % [
		closest_trunk_distance,
		_get_trunk_collision_radius(),
		str(trunk_adjusted),
		root_overlap_count,
		SAFE_ROUTE_COLLISION_MARGIN,
	])

func _closest_safe_route_planar_distance(point: Vector3, safe_ids: Array) -> float:
	var best: float = INF
	for i: int in range(1, safe_ids.size()):
		var a_value: Variant = _world.call("get_platform_position", StringName(safe_ids[i - 1]))
		var b_value: Variant = _world.call("get_platform_position", StringName(safe_ids[i]))
		if not (a_value is Vector3) or not (b_value is Vector3):
			continue
		best = minf(best, _point_to_segment_planar_distance(point, a_value, b_value))
	return best

func _point_to_segment_planar_distance(point: Vector3, a: Vector3, b: Vector3) -> float:
	var p := Vector2(point.x, point.z)
	var start := Vector2(a.x, a.z)
	var finish := Vector2(b.x, b.z)
	var segment := finish - start
	var length_sq: float = segment.length_squared()
	if length_sq <= 0.0001:
		return p.distance_to(start)
	var t: float = clampf((p - start).dot(segment) / length_sq, 0.0, 1.0)
	return p.distance_to(start + segment * t)

func _root_collision_intrudes_safe_route(root_body: StaticBody3D, safe_ids: Array) -> bool:
	if root_body == null or root_body.get_child_count() <= 0:
		return false
	var collision := root_body.get_child(0) as CollisionShape3D
	var shape := collision.shape as BoxShape3D if collision != null else null
	if shape == null:
		return false
	var half_height: float = shape.size.y * 0.5 + TITAN_ROOT_VERTICAL_MARGIN
	var root_y: float = root_body.global_position.y
	var planar_guard: float = maxf(shape.size.x, shape.size.z) * 0.5 + SAFE_ROUTE_COLLISION_MARGIN
	for i: int in range(1, safe_ids.size()):
		var a: Vector3 = _world.call("get_platform_position", StringName(safe_ids[i - 1]))
		var b: Vector3 = _world.call("get_platform_position", StringName(safe_ids[i]))
		var segment_min_y: float = minf(a.y, b.y)
		var segment_max_y: float = maxf(a.y, b.y)
		if segment_min_y > root_y + half_height or segment_max_y < root_y - half_height:
			continue
		if _point_to_segment_planar_distance(root_body.global_position, a, b) <= planar_guard:
			return true
	return false

func _get_trunk_collision_radius() -> float:
	if _major_collision_root == null:
		return 0.0
	var body := _major_collision_root.get_node_or_null("TitanTrunkCollision") as StaticBody3D
	if body == null or body.get_child_count() <= 0:
		return 0.0
	var collision := body.get_child(0) as CollisionShape3D
	var shape := collision.shape as CylinderShape3D if collision != null else null
	return shape.radius if shape != null else 0.0

func _add_major_static_body(
	body_name: String,
	position: Vector3,
	rotation_value: Vector3,
	shape: Shape3D
) -> void:
	if _major_collision_root == null:
		return
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = MAJOR_WORLD_COLLISION_LAYER
	body.collision_mask = 0
	body.add_to_group("logspire_major_world_collision")
	_major_collision_root.add_child(body)
	body.global_position = position
	body.rotation = rotation_value
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)