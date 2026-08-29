class_name WildDashGrandPrixV3OffroadController
extends Node

## Grand Prix V3.5 open-edge offroad handling.
##
## Racers may leave the road and shoulder, but offroad penalties now respect the
## amount of physical side terrain available in each biome. Tight mountain and
## canyon sections stop racers before their narrow safe apron ends, while wider
## lowland sections retain the broader offroad freedom. The V3.5 world
## foundation is only a last-resort landmass, not the normal offroad surface.

const SAMPLE_INTERVAL: float = 0.08
const LOCAL_SEARCH_RADIUS: int = 12
const FULL_SEARCH_DISTANCE: float = 20.0

const OFFROAD_ENTER_DEPTH: float = 0.35
const LIGHT_OFFROAD_DEPTH: float = 1.50
const HEAVY_OFFROAD_DEPTH: float = 4.00
const DEFAULT_STOP_OFFROAD_DEPTH: float = 7.00
const STOP_HOLD_SECONDS: float = 0.18

const SECTION_STOP_DEPTHS: Dictionary = {
	&"mountain_approach": 3.40,
	&"mountain_ascent": 2.80,
	&"summit_ridge": 2.50,
	&"rough_descent": 3.00,
	&"canyon_obstacle": 2.20,
}

const RETURN_CRAWL_SPEED: float = 2.80
const RETURN_HEADING_DOT: float = 0.20
const RETURN_ACCELERATION_SCALE: float = 1.15
const RETURN_TRACTION_SPEED: float = 2.60
const RETURN_TRACTION_ACCELERATION: float = 24.0
const REENTRY_ASSIST_DEPTH: float = 2.80
const REENTRY_BLOCKED_DELAY: float = 0.16
const REENTRY_NUDGE_DISTANCE: float = 0.42
const REENTRY_NUDGE_LIFT: float = 0.08

const REENTRY_BRIDGE_INSET: float = 1.80
const REENTRY_BRIDGE_OUTSET: float = 2.40
const REENTRY_BRIDGE_LIFT: float = 0.015

const LIGHT_SPEED_RATIO: float = 0.78
const MEDIUM_SPEED_RATIO: float = 0.56
const HEAVY_SPEED_RATIO: float = 0.28
const DEEP_SPEED_RATIO: float = 0.06

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _sample_elapsed: float = 0.0
var _segment_hint: Dictionary = {}
var _section_by_racer: Dictionary = {}
var _depth_by_racer: Dictionary = {}
var _center_by_racer: Dictionary = {}
var _offroad_seconds: Dictionary = {}
var _was_offroad: Dictionary = {}
var _blocked_return_seconds: Dictionary = {}
var _reentry_nudge_count: int = 0
var _reentry_bridge_body: StaticBody3D

var _hud_layer: CanvasLayer
var _hud_label: Label

func _ready() -> void:
	process_priority = 126
	_build_hud()
	call_deferred("_bind_track_when_ready")

func _bind_track_when_ready() -> void:
	for _frame: int in range(8):
		await get_tree().process_frame
	_track = _find_v2_track(get_parent())
	if _track == null:
		push_warning("GrandPrixV3OffroadController: V2 track unavailable")
		return
	_route = _track.get_route_points()
	if _route.size() < 2:
		push_warning("GrandPrixV3OffroadController: route unavailable")
		return
	var bridge_ready: bool = _build_reentry_bridge()
	print("GRAND PRIX V3.5 OFFROAD READY open_edges=true sample_hz=%.1f default_stop=%.1fm mountain_stop=2.2..3.4m return_crawl=%.1f reentry_bridge=%s world_foundation=true" % [
		1.0 / SAMPLE_INTERVAL,
		DEFAULT_STOP_OFFROAD_DEPTH,
		RETURN_CRAWL_SPEED,
		str(bridge_ready),
	])

func _physics_process(delta: float) -> void:
	if _track == null or _route.size() < 2:
		return
	if not RaceManager.active:
		_clear_runtime_state()
		_hide_hud()
		return

	_sample_elapsed += delta
	if _sample_elapsed >= SAMPLE_INTERVAL:
		var sample_delta: float = _sample_elapsed
		_sample_elapsed = fmod(_sample_elapsed, SAMPLE_INTERVAL)
		_sample_all_racers(sample_delta)

	var player_offroad: bool = false
	for candidate in RaceManager.racers:
		if not candidate is WildDashCharacterController:
			continue
		var racer: WildDashCharacterController = candidate as WildDashCharacterController
		if racer.finished:
			continue
		var key: int = racer.get_instance_id()
		var depth: float = float(_depth_by_racer.get(key, 0.0))
		if depth <= OFFROAD_ENTER_DEPTH:
			_blocked_return_seconds[key] = 0.0
			continue
		_apply_offroad_penalty(racer, depth, delta)
		if racer.is_player:
			player_offroad = true
			_update_player_hud(racer, depth)

	if not player_offroad:
		_hide_hud()

func _sample_all_racers(sample_delta: float) -> void:
	for candidate in RaceManager.racers:
		if not candidate is WildDashCharacterController:
			continue
		var racer: WildDashCharacterController = candidate as WildDashCharacterController
		if racer.finished:
			continue
		var key: int = racer.get_instance_id()
		var sample: Dictionary = _sample_route_distance(racer, key)
		if sample.is_empty():
			continue
		var depth: float = float(sample["depth"])
		_depth_by_racer[key] = depth
		_center_by_racer[key] = sample["center"]
		_segment_hint[key] = int(sample["segment"])
		_section_by_racer[key] = sample["section"]

		var offroad: bool = depth > OFFROAD_ENTER_DEPTH
		var previous: bool = bool(_was_offroad.get(key, false))
		if offroad:
			_offroad_seconds[key] = float(_offroad_seconds.get(key, 0.0)) + sample_delta
		else:
			_offroad_seconds[key] = 0.0
		if offroad != previous:
			_was_offroad[key] = offroad
			if offroad:
				print("GRAND PRIX V3.5 OFFROAD ENTER racer=%s depth=%.2fm section=%s stop=%.2fm segment=%d" % [
					racer.name,
					depth,
					String(sample["section"]),
					_stop_depth_for_key(key),
					int(sample["segment"]),
				])
			else:
				print("GRAND PRIX V3.5 OFFROAD EXIT racer=%s" % racer.name)

func _sample_route_distance(racer: WildDashCharacterController, key: int) -> Dictionary:
	var segment_count: int = _route.size() - 1
	if segment_count <= 0:
		return {}

	var hint: int = int(_segment_hint.get(key, -1))
	if hint < 0:
		var track_length: float = maxf(1.0, _track.get_track_length())
		var progress: float = RaceManager.get_track_progress(racer)
		hint = clampi(roundi((progress / track_length) * float(segment_count - 1)), 0, segment_count - 1)

	var best: Dictionary = _search_segment_range(
		racer.global_position,
		maxi(0, hint - LOCAL_SEARCH_RADIUS),
		mini(segment_count - 1, hint + LOCAL_SEARCH_RADIUS)
	)
	if best.is_empty():
		return {}

	if float(best["center_distance"]) > FULL_SEARCH_DISTANCE:
		best = _search_segment_range(racer.global_position, 0, segment_count - 1)
	return best

func _search_segment_range(position: Vector3, start_segment: int, end_segment: int) -> Dictionary:
	var point2: Vector2 = Vector2(position.x, position.z)
	var best_distance: float = INF
	var best_segment: int = -1
	var best_center: Vector3 = Vector3.ZERO

	for segment_index: int in range(start_segment, end_segment + 1):
		if segment_index < 0 or segment_index + 1 >= _route.size():
			continue
		var a: Vector3 = _route[segment_index]
		var b: Vector3 = _route[segment_index + 1]
		var a2: Vector2 = Vector2(a.x, a.z)
		var b2: Vector2 = Vector2(b.x, b.z)
		var ab: Vector2 = b2 - a2
		var length_squared: float = ab.length_squared()
		var segment_t: float = 0.0
		if length_squared > 0.0001:
			segment_t = clampf((point2 - a2).dot(ab) / length_squared, 0.0, 1.0)
		var closest2: Vector2 = a2 + ab * segment_t
		var distance: float = point2.distance_to(closest2)
		if distance >= best_distance:
			continue
		best_distance = distance
		best_segment = segment_index
		best_center = a.lerp(b, segment_t)

	if best_segment < 0:
		return {}
	var road_half_width: float = _track.get_v2_width_for_segment(best_segment) * 0.5
	var shoulder_width: float = _track.get_v2_shoulder_width_for_segment(best_segment)
	var drivable_half_width: float = road_half_width + shoulder_width
	return {
		"segment": best_segment,
		"section": _track.get_v2_section_id_for_segment(best_segment),
		"center": best_center,
		"center_distance": best_distance,
		"drivable_half_width": drivable_half_width,
		"depth": maxf(0.0, best_distance - drivable_half_width),
	}

func _apply_offroad_penalty(racer: WildDashCharacterController, depth: float, delta: float) -> void:
	var key: int = racer.get_instance_id()
	var offroad_seconds: float = float(_offroad_seconds.get(key, 0.0))
	var stop_depth: float = _stop_depth_for_key(key)
	var ratio: float = _speed_ratio_for_depth(depth, stop_depth)
	var target_speed: float = racer.max_speed * ratio
	var stopped: bool = depth >= stop_depth and offroad_seconds >= STOP_HOLD_SECONDS
	var heading_back: bool = _heading_back_toward_track(racer, key)

	if stopped:
		target_speed = RETURN_CRAWL_SPEED if heading_back else 0.0

	var depth_ratio: float = clampf(depth / maxf(0.5, stop_depth), 0.0, 1.0)
	var deceleration_scale: float = lerpf(1.45, 6.40, depth_ratio)
	var deceleration: float = maxf(8.0, racer.acceleration * deceleration_scale)
	if racer.current_speed > target_speed:
		racer.current_speed = move_toward(racer.current_speed, target_speed, deceleration * delta)
	elif heading_back and racer.current_speed < target_speed:
		var return_acceleration: float = maxf(6.0, racer.acceleration * RETURN_ACCELERATION_SCALE)
		racer.current_speed = move_toward(racer.current_speed, target_speed, return_acceleration * delta)

	# Start killing outward momentum before the physical side terrain ends. This
	# is a soft terrain drag, not a wall: the racer can still steer back normally.
	if depth >= stop_depth * 0.78:
		var edge_drag: float = clampf(1.0 - delta * lerpf(3.0, 9.0, depth_ratio), 0.0, 1.0)
		racer.velocity.x *= edge_drag
		racer.velocity.z *= edge_drag

	if heading_back:
		_apply_return_traction(racer, key, depth, stop_depth, delta)
		_update_reentry_block_assist(racer, key, depth, delta)
	else:
		_blocked_return_seconds[key] = 0.0

	if stopped and not heading_back:
		racer.current_speed = 0.0
		var planar_damping: float = clampf(1.0 - delta * 12.0, 0.0, 1.0)
		racer.velocity.x *= planar_damping
		racer.velocity.z *= planar_damping

func _apply_return_traction(racer: WildDashCharacterController, key: int, depth: float, stop_depth: float, delta: float) -> void:
	if not _center_by_racer.has(key):
		return
	var center: Vector3 = _center_by_racer[key]
	var inward: Vector3 = center - racer.global_position
	inward.y = 0.0
	if inward.length_squared() <= 0.001:
		return
	inward = inward.normalized()
	var desired_inward_speed: float = RETURN_TRACTION_SPEED * lerpf(0.70, 1.15, clampf(depth / maxf(0.5, stop_depth), 0.0, 1.0))
	var current_inward_speed: float = racer.get_knockback_velocity().dot(inward)
	if current_inward_speed >= desired_inward_speed:
		return
	var traction_step: float = minf(
		desired_inward_speed - current_inward_speed,
		RETURN_TRACTION_ACCELERATION * delta
	)
	if traction_step > 0.001:
		racer.apply_knockback(inward, traction_step)

func _update_reentry_block_assist(racer: WildDashCharacterController, key: int, depth: float, delta: float) -> void:
	if depth > REENTRY_ASSIST_DEPTH or not racer.has_blocking_collision():
		_blocked_return_seconds[key] = 0.0
		return
	var blocked_seconds: float = float(_blocked_return_seconds.get(key, 0.0)) + delta
	_blocked_return_seconds[key] = blocked_seconds
	if blocked_seconds < REENTRY_BLOCKED_DELAY:
		return
	_blocked_return_seconds[key] = 0.0
	_nudge_across_reentry_seam(racer, key)

func _nudge_across_reentry_seam(racer: WildDashCharacterController, key: int) -> void:
	if not _center_by_racer.has(key):
		return
	var center: Vector3 = _center_by_racer[key]
	var inward: Vector3 = center - racer.global_position
	inward.y = 0.0
	if inward.length_squared() <= 0.001:
		return
	inward = inward.normalized()
	racer.global_position += inward * REENTRY_NUDGE_DISTANCE + Vector3.UP * REENTRY_NUDGE_LIFT
	_reentry_nudge_count += 1
	print("GRAND PRIX V3.5 REENTRY ASSIST racer=%s nudge=%d distance=%.2fm" % [
		racer.name,
		_reentry_nudge_count,
		REENTRY_NUDGE_DISTANCE,
	])

func _stop_depth_for_key(key: int) -> float:
	var section_id: StringName = StringName(_section_by_racer.get(key, &""))
	return float(SECTION_STOP_DEPTHS.get(section_id, DEFAULT_STOP_OFFROAD_DEPTH))

func _speed_ratio_for_depth(depth: float, stop_depth: float) -> float:
	if depth <= OFFROAD_ENTER_DEPTH:
		return 1.0
	var light_end: float = minf(LIGHT_OFFROAD_DEPTH, maxf(0.85, stop_depth * 0.35))
	var heavy_end: float = minf(HEAVY_OFFROAD_DEPTH, maxf(light_end + 0.35, stop_depth * 0.68))
	if depth <= light_end:
		var light_t: float = inverse_lerp(OFFROAD_ENTER_DEPTH, light_end, depth)
		return lerpf(LIGHT_SPEED_RATIO, MEDIUM_SPEED_RATIO, light_t)
	if depth <= heavy_end:
		var heavy_t: float = inverse_lerp(light_end, heavy_end, depth)
		return lerpf(MEDIUM_SPEED_RATIO, HEAVY_SPEED_RATIO, heavy_t)
	if depth <= stop_depth:
		var deep_t: float = inverse_lerp(heavy_end, stop_depth, depth)
		return lerpf(HEAVY_SPEED_RATIO, DEEP_SPEED_RATIO, deep_t)
	return 0.0

func _heading_back_toward_track(racer: WildDashCharacterController, key: int) -> bool:
	if not _center_by_racer.has(key):
		return false
	var center: Vector3 = _center_by_racer[key]
	var inward: Vector3 = center - racer.global_position
	inward.y = 0.0
	if inward.length_squared() <= 0.001:
		return true
	inward = inward.normalized()
	var forward: Vector3 = -racer.global_transform.basis.z.normalized()
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		return false
	return forward.normalized().dot(inward) >= RETURN_HEADING_DOT

func _build_reentry_bridge() -> bool:
	if _track == null or _route.size() < 2:
		return false
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()

	for point_index: int in range(_route.size()):
		var tangent: Vector3 = _route_tangent(point_index)
		var right: Vector3 = Vector3(-tangent.z, 0.0, tangent.x)
		var left_edge: Vector3 = _track.get_v2_shoulder_edge_point(point_index, -1.0)
		var right_edge: Vector3 = _track.get_v2_shoulder_edge_point(point_index, 1.0)
		var lift: Vector3 = Vector3.UP * REENTRY_BRIDGE_LIFT
		vertices.append(left_edge + right * REENTRY_BRIDGE_INSET + lift)
		vertices.append(left_edge - right * REENTRY_BRIDGE_OUTSET + lift)
		vertices.append(right_edge - right * REENTRY_BRIDGE_INSET + lift)
		vertices.append(right_edge + right * REENTRY_BRIDGE_OUTSET + lift)

	for point_index: int in range(_route.size() - 1):
		var base: int = point_index * 4
		var next: int = base + 4
		indices.append_array(PackedInt32Array([
			base, base + 1, next,
			base + 1, next + 1, next,
			base + 2, next + 2, base + 3,
			base + 3, next + 2, next + 3,
		]))

	if vertices.is_empty() or indices.is_empty():
		return false
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shape: Shape3D = mesh.create_trimesh_shape()
	if shape == null:
		return false
	if shape is ConcavePolygonShape3D:
		(shape as ConcavePolygonShape3D).backface_collision = true

	_reentry_bridge_body = StaticBody3D.new()
	_reentry_bridge_body.name = "V35OffroadReentryBridge"
	_reentry_bridge_body.collision_layer = 1
	_reentry_bridge_body.collision_mask = 0
	add_child(_reentry_bridge_body)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "OffroadReentryBridgeCollision"
	collision.shape = shape
	_reentry_bridge_body.add_child(collision)
	print("GRAND PRIX V3.5 REENTRY BRIDGE READY vertices=%d triangles=%d two_sided=true" % [
		vertices.size(),
		indices.size() / 3,
	])
	return true

func _route_tangent(point_index: int) -> Vector3:
	if _route.size() < 2:
		return Vector3.FORWARD
	var tangent: Vector3
	if point_index <= 0:
		tangent = _route[1] - _route[0]
	elif point_index >= _route.size() - 1:
		tangent = _route[-1] - _route[-2]
	else:
		tangent = _route[point_index + 1] - _route[point_index - 1]
	tangent.y = 0.0
	if tangent.length_squared() <= 0.001:
		return Vector3.FORWARD
	return tangent.normalized()

func _build_hud() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "OffroadFeedbackLayer"
	_hud_layer.layer = 42
	add_child(_hud_layer)
	_hud_label = Label.new()
	_hud_label.name = "OffroadFeedback"
	_hud_label.position = Vector2(560.0, 122.0)
	_hud_label.size = Vector2(480.0, 50.0)
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_label.add_theme_font_size_override("font_size", 22)
	_hud_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28))
	_hud_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_hud_label.add_theme_constant_override("shadow_offset_x", 2)
	_hud_label.add_theme_constant_override("shadow_offset_y", 2)
	_hud_label.visible = false
	_hud_layer.add_child(_hud_label)

func _update_player_hud(racer: WildDashCharacterController, depth: float) -> void:
	if _hud_label == null:
		return
	var key: int = racer.get_instance_id()
	var seconds: float = float(_offroad_seconds.get(key, 0.0))
	var stop_depth: float = _stop_depth_for_key(key)
	var stopped: bool = depth >= stop_depth and seconds >= STOP_HOLD_SECONDS
	var heading_back: bool = _heading_back_toward_track(racer, key)
	if stopped:
		if heading_back:
			_hud_label.text = "OFF ROAD  ·  RETURN ASSIST  ·  CRAWL TO TRACK"
		else:
			_hud_label.text = "OFF ROAD  ·  TERRAIN LIMIT  ·  TURN BACK"
	elif heading_back:
		var return_ratio_percent: int = roundi(_speed_ratio_for_depth(depth, stop_depth) * 100.0)
		_hud_label.text = "OFF ROAD  ·  RETURN TRACTION  ·  SPEED LIMIT %d%%" % return_ratio_percent
	else:
		var ratio_percent: int = roundi(_speed_ratio_for_depth(depth, stop_depth) * 100.0)
		_hud_label.text = "OFF ROAD  ·  GRIP LOST  ·  SPEED LIMIT %d%%" % ratio_percent
	_hud_label.visible = true

func _hide_hud() -> void:
	if _hud_label != null:
		_hud_label.visible = false

func _clear_runtime_state() -> void:
	_sample_elapsed = 0.0
	_segment_hint.clear()
	_section_by_racer.clear()
	_depth_by_racer.clear()
	_center_by_racer.clear()
	_offroad_seconds.clear()
	_was_offroad.clear()
	_blocked_return_seconds.clear()

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
