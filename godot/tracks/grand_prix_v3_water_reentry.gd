class_name WildDashGrandPrixV3WaterReentry
extends Node3D

## Grand Prix V3.8 water-edge recovery layer.
##
## The Long River keeps open edges and its speed/grip penalty, but the first
## few metres outside each shoulder become an explicit shallow re-entry band.
## The band is built from the exact shoulder edge used by the road and uses the
## same mesh for visuals and collision so there is no invisible step mismatch.
## A small input-driven inward traction assist helps racers overcome seams and
## river-side drift without steering them automatically.

const TARGET_SECTION: StringName = &"long_river"
const BAND_WIDTH: float = 3.60
const SHOULDER_OVERLAP: float = 0.40
const SURFACE_LIFT: float = 0.035
const OUTER_DROP: float = 0.09
const SAMPLE_INTERVAL: float = 0.08
const OFFROAD_ENTER_DEPTH: float = 0.25
const MAX_ASSIST_DEPTH: float = 5.50
const RETURN_HEADING_DOT: float = 0.05
const RETURN_MIN_FORWARD_SPEED: float = 4.00
const RETURN_INWARD_SPEED: float = 4.40
const RETURN_ACCELERATION: float = 42.0
const BLOCKED_REENTRY_DEPTH: float = 2.20
const BLOCKED_DELAY: float = 0.18
const BLOCKED_NUDGE: float = 0.30
const BLOCKED_LIFT: float = 0.06

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _river_range: Vector2i = Vector2i(-1, -1)
var _sample_elapsed: float = 0.0
var _samples: Dictionary = {}
var _blocked_seconds: Dictionary = {}
var _band_root: Node3D
var _band_body: StaticBody3D
var _legacy_bridge_shapes_disabled: int = 0
var _legacy_bank_visuals_hidden: int = 0
var _assist_count: int = 0

func _ready() -> void:
	process_priority = 132
	call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
	for _frame: int in range(12):
		await get_tree().process_frame
	_track = _find_v2_track(get_parent())
	if _track == null:
		push_warning("GrandPrixV3WaterReentry: V2 track unavailable")
		return
	_route = _track.get_route_points()
	var ranges: Dictionary = _track.get_v2_section_ranges()
	if _route.size() < 2 or not ranges.has(TARGET_SECTION):
		push_warning("GrandPrixV3WaterReentry: Long River route unavailable")
		return
	_river_range = ranges[TARGET_SECTION] as Vector2i
	_build_reentry_band()
	_legacy_bridge_shapes_disabled = _disable_redundant_generic_bridge()
	_legacy_bank_visuals_hidden = _hide_legacy_river_bank_visuals()
	print("GRAND PRIX V3.8 WATER REENTRY READY section=long_river band=%.2fm overlap=%.2fm drop=%.2fm slope_deg=%.2f legacy_bridge_shapes_disabled=%d legacy_bank_visuals_hidden=%d open_edge=true" % [
		BAND_WIDTH,
		SHOULDER_OVERLAP,
		OUTER_DROP,
		rad_to_deg(atan2(OUTER_DROP, BAND_WIDTH)),
		_legacy_bridge_shapes_disabled,
		_legacy_bank_visuals_hidden,
	])

func _physics_process(delta: float) -> void:
	if _track == null or _river_range.x < 0 or not RaceManager.active:
		_samples.clear()
		_blocked_seconds.clear()
		return

	_sample_elapsed += delta
	if _sample_elapsed >= SAMPLE_INTERVAL:
		_sample_elapsed = fmod(_sample_elapsed, SAMPLE_INTERVAL)
		_sample_racers()

	for candidate in RaceManager.racers:
		if not candidate is WildDashCharacterController:
			continue
		var racer: WildDashCharacterController = candidate as WildDashCharacterController
		if racer.finished:
			continue
		var key: int = racer.get_instance_id()
		if not _samples.has(key):
			continue
		var sample: Dictionary = _samples[key]
		var depth: float = float(sample.get("depth", 0.0))
		if depth <= OFFROAD_ENTER_DEPTH or depth > MAX_ASSIST_DEPTH:
			_blocked_seconds[key] = 0.0
			continue
		var center: Vector3 = sample["center"]
		var inward: Vector3 = center - racer.global_position
		inward.y = 0.0
		if inward.length_squared() <= 0.001:
			continue
		inward = inward.normalized()
		if not _is_heading_inward(racer, inward):
			_blocked_seconds[key] = 0.0
			continue
		_apply_inward_assist(racer, inward, depth, delta)
		_update_blocked_assist(racer, inward, depth, delta)

func _build_reentry_band() -> void:
	var start_point: int = clampi(_river_range.x, 0, _route.size() - 2)
	var end_point: int = clampi(_river_range.y + 1, start_point + 1, _route.size() - 1)
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var distance_along: float = 0.0

	for point_index: int in range(start_point, end_point + 1):
		if point_index > start_point:
			distance_along += _route[point_index - 1].distance_to(_route[point_index])
		var center: Vector3 = _route[point_index]
		var normal: Vector3 = WildDashGrandPrixV2Geometry.road_normal_at(_route, point_index)
		var left_edge: Vector3 = _track.get_v2_shoulder_edge_point(point_index, -1.0)
		var right_edge: Vector3 = _track.get_v2_shoulder_edge_point(point_index, 1.0)
		var left_outward: Vector3 = _planar_direction(center, left_edge, Vector3.LEFT)
		var right_outward: Vector3 = _planar_direction(center, right_edge, Vector3.RIGHT)
		var surface_offset: Vector3 = normal * WildDashGrandPrixV2Track.ROAD_SURFACE_LIFT + Vector3.UP * SURFACE_LIFT

		var left_inner: Vector3 = left_edge - left_outward * SHOULDER_OVERLAP + surface_offset
		var left_outer: Vector3 = left_edge + left_outward * BAND_WIDTH + surface_offset - Vector3.UP * OUTER_DROP
		var right_inner: Vector3 = right_edge - right_outward * SHOULDER_OVERLAP + surface_offset
		var right_outer: Vector3 = right_edge + right_outward * BAND_WIDTH + surface_offset - Vector3.UP * OUTER_DROP

		vertices.append(left_outer)
		vertices.append(left_inner)
		vertices.append(right_inner)
		vertices.append(right_outer)
		for _normal_index: int in range(4):
			normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, distance_along / 10.0))
		uvs.append(Vector2(0.45, distance_along / 10.0))
		uvs.append(Vector2(0.55, distance_along / 10.0))
		uvs.append(Vector2(1.0, distance_along / 10.0))

	var point_count: int = end_point - start_point + 1
	for local_index: int in range(point_count - 1):
		var base: int = local_index * 4
		var next: int = base + 4
		indices.append_array(PackedInt32Array([
			base, base + 1, next,
			base + 1, next + 1, next,
			base + 2, base + 3, next + 2,
			base + 3, next + 3, next + 2,
		]))

	if vertices.is_empty() or indices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	_band_root = Node3D.new()
	_band_root.name = "V38WaterReentryBand"
	add_child(_band_root)

	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = "WaterReentryVisual"
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.30, 0.27, 0.16, 1.0)
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = material
	_band_root.add_child(visual)

	var shape: Shape3D = mesh.create_trimesh_shape()
	if shape == null:
		push_warning("GrandPrixV3WaterReentry: collision generation failed")
		return
	if shape is ConcavePolygonShape3D:
		(shape as ConcavePolygonShape3D).backface_collision = true
	_band_body = StaticBody3D.new()
	_band_body.name = "V38WaterReentryCollision"
	_band_body.collision_layer = 1
	_band_body.collision_mask = 0
	_band_root.add_child(_band_body)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "WaterReentryShape"
	collision.shape = shape
	_band_body.add_child(collision)

func _sample_racers() -> void:
	for candidate in RaceManager.racers:
		if not candidate is WildDashCharacterController:
			continue
		var racer: WildDashCharacterController = candidate as WildDashCharacterController
		var key: int = racer.get_instance_id()
		var sample: Dictionary = _sample_river_route(racer.global_position)
		if sample.is_empty():
			_samples.erase(key)
			continue
		_samples[key] = sample

func _sample_river_route(position: Vector3) -> Dictionary:
	var point2: Vector2 = Vector2(position.x, position.z)
	var best_distance: float = INF
	var best_segment: int = -1
	var best_center: Vector3 = Vector3.ZERO
	for segment_index: int in range(_river_range.x, _river_range.y + 1):
		if segment_index < 0 or segment_index + 1 >= _route.size():
			continue
		var a: Vector3 = _route[segment_index]
		var b: Vector3 = _route[segment_index + 1]
		var a2: Vector2 = Vector2(a.x, a.z)
		var b2: Vector2 = Vector2(b.x, b.z)
		var ab: Vector2 = b2 - a2
		var length_squared: float = ab.length_squared()
		var t: float = 0.0
		if length_squared > 0.0001:
			t = clampf((point2 - a2).dot(ab) / length_squared, 0.0, 1.0)
		var closest2: Vector2 = a2 + ab * t
		var distance: float = point2.distance_to(closest2)
		if distance >= best_distance:
			continue
		best_distance = distance
		best_segment = segment_index
		best_center = a.lerp(b, t)
	if best_segment < 0:
		return {}
	var drivable_half_width: float = _track.get_v2_width_for_segment(best_segment) * 0.5 + _track.get_v2_shoulder_width_for_segment(best_segment)
	var depth: float = maxf(0.0, best_distance - drivable_half_width)
	if depth > MAX_ASSIST_DEPTH + 1.5:
		return {}
	return {
		"segment": best_segment,
		"center": best_center,
		"depth": depth,
	}

func _is_heading_inward(racer: WildDashCharacterController, inward: Vector3) -> bool:
	var forward: Vector3 = -racer.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		return false
	return forward.normalized().dot(inward) >= RETURN_HEADING_DOT

func _apply_inward_assist(racer: WildDashCharacterController, inward: Vector3, depth: float, delta: float) -> void:
	var depth_scale: float = clampf(depth / MAX_ASSIST_DEPTH, 0.0, 1.0)
	var target_inward_speed: float = RETURN_INWARD_SPEED * lerpf(0.85, 1.15, depth_scale)
	var current_inward_speed: float = racer.get_knockback_velocity().dot(inward)
	var traction_step: float = minf(maxf(0.0, target_inward_speed - current_inward_speed), RETURN_ACCELERATION * delta)
	if traction_step > 0.001:
		racer.apply_knockback(inward, traction_step)
	racer.current_speed = maxf(racer.current_speed, minf(RETURN_MIN_FORWARD_SPEED, racer.max_speed * 0.34))

func _update_blocked_assist(racer: WildDashCharacterController, inward: Vector3, depth: float, delta: float) -> void:
	var key: int = racer.get_instance_id()
	if depth > BLOCKED_REENTRY_DEPTH or not racer.has_blocking_collision():
		_blocked_seconds[key] = 0.0
		return
	var blocked: float = float(_blocked_seconds.get(key, 0.0)) + delta
	_blocked_seconds[key] = blocked
	if blocked < BLOCKED_DELAY:
		return
	_blocked_seconds[key] = 0.0
	racer.global_position += inward * BLOCKED_NUDGE + Vector3.UP * BLOCKED_LIFT
	_assist_count += 1
	if racer.is_player and (_assist_count <= 4 or _assist_count % 30 == 0):
		print("GRAND PRIX V3.8 WATER REENTRY NUDGE racer=%s depth=%.2f count=%d" % [racer.name, depth, _assist_count])

func _disable_redundant_generic_bridge() -> int:
	var bridge: Node = _find_named_recursive(get_parent(), "V35OffroadReentryBridge")
	if bridge == null:
		return 0
	return _disable_collision_shapes_recursive(bridge)

func _hide_legacy_river_bank_visuals() -> int:
	var hidden: int = 0
	var banks: Array[Node] = _find_all_named_recursive(get_parent(), "V2LongRiverBanks")
	for node: Node in banks:
		if node is Node3D:
			(node as Node3D).visible = false
			hidden += 1
	return hidden

func _disable_collision_shapes_recursive(root: Node) -> int:
	var disabled: int = 0
	for child: Node in root.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", true)
			disabled += 1
		else:
			disabled += _disable_collision_shapes_recursive(child)
	return disabled

func _find_named_recursive(root: Node, target_name: String) -> Node:
	if root == null:
		return null
	if String(root.name) == target_name:
		return root
	for child: Node in root.get_children():
		var found: Node = _find_named_recursive(child, target_name)
		if found != null:
			return found
	return null

func _find_all_named_recursive(root: Node, target_name: String) -> Array[Node]:
	var result: Array[Node] = []
	if root == null:
		return result
	if String(root.name) == target_name:
		result.append(root)
	for child: Node in root.get_children():
		result.append_array(_find_all_named_recursive(child, target_name))
	return result

func _planar_direction(from_point: Vector3, to_point: Vector3, fallback: Vector3) -> Vector3:
	var direction: Vector3 = to_point - from_point
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return fallback
	return direction.normalized()

func _find_v2_track(root: Node) -> WildDashGrandPrixV2Track:
	if root == null:
		return null
	if root is WildDashGrandPrixV2Track:
		return root as WildDashGrandPrixV2Track
	for child: Node in root.get_children():
		var found: WildDashGrandPrixV2Track = _find_v2_track(child)
		if found != null:
			return found
	return null
