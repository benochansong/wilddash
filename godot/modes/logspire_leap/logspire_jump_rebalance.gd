extends Node

## Player-tested accessibility pass for LOGSPIRE LEAP.
## Safe Route is easy to complete; Wild Route remains the optional mastery path.

const ROUTE_SAFE: StringName = &"safe"
const ROUTE_WILD: StringName = &"wild"

const COYOTE_TIME_SECONDS: float = 0.18
const JUMP_BUFFER_SECONDS: float = 0.18
const FORWARD_ASSIST_BASE: float = 0.07
const FORWARD_ASSIST_MAX: float = 0.10
const LANDING_ASSIST_BASE_METERS: float = 0.55
const LANDING_ASSIST_MAX_METERS: float = 0.78
const LANDING_COLLISION_MARGIN: float = 0.45
const RECOVERY_TIME_SECONDS: float = 0.90

const EASY_GAP_REDUCTION: float = 0.28
const NORMAL_GAP_REDUCTION: float = 0.22
const DIFFICULT_GAP_REDUCTION: float = 0.13

const MOVING_LOG_SPEED_SCALE: float = 0.80
const MOVING_LOG_SIZE_SCALE: float = 1.10

const MOVING_SAFE_IDS: Array[StringName] = [
	&"Z3_02",
	&"Z3_03",
	&"Z3_05",
	&"Z3_07",
	&"Z4_SAFE_04",
	&"Z6_03",
	&"Z6_05",
	&"Z6_07",
]

var _world: Node
var _gameplay: Node
var _recovery: Node

var _safe_ids: Array[StringName] = []
var _wild_ids: Array[StringName] = []
var _wild_exclusive_ids: Array[StringName] = []
var _index_by_id: Dictionary = {}
var _old_positions: Dictionary = {}
var _old_sizes: Dictionary = {}
var _new_sizes: Dictionary = {}

var _player_target_index: int = 1
var _player_was_on_floor: bool = false
var _coyote_remaining: float = 0.0
var _jump_buffer_remaining: float = 0.0
var _landing_correction_used: float = 0.0
var _landing_assist_logged: bool = false
var _last_route_context: StringName = ROUTE_SAFE

var _failures_by_target: Dictionary = {}
var _falls_total: int = 0
var _safe_falls: int = 0
var _wild_falls: int = 0
var _recoveries: int = 0
var _repeated_failures: int = 0
var _report_printed: bool = false
var _runtime_patched: bool = false

func _ready() -> void:
	_world = get_parent().get_node_or_null("LogspireWorld")
	_gameplay = get_parent().get_node_or_null("PlatformGameplay")
	_recovery = get_parent().get_node_or_null("RecoverySystem")
	if _world == null:
		push_error("LOGSPIRE JUMP REBALANCE missing world")
		return
	_apply_course_rebalance()
	call_deferred("_post_ready_setup")

func _post_ready_setup() -> void:
	await get_tree().process_frame
	_apply_runtime_platform_forgiveness()
	if _recovery != null and _recovery.has_signal("racer_recovered"):
		var callable := Callable(self, "_on_racer_recovered")
		if not _recovery.is_connected("racer_recovered", callable):
			_recovery.connect("racer_recovered", callable)
	var finish_callable := Callable(self, "_on_racer_finished")
	if not RaceManager.racer_finished.is_connected(finish_callable):
		RaceManager.racer_finished.connect(finish_callable)
	_recalculate_player_target()
	print("LOGSPIRE JUMP ACCESSIBILITY READY coyote=%.2fs buffer=%.2fs forward_assist=%.0f-%.0f%% landing_assist=%.2f-%.2fm collision_margin=%.2fm adaptive_failures=true" % [
		COYOTE_TIME_SECONDS,
		JUMP_BUFFER_SECONDS,
		FORWARD_ASSIST_BASE * 100.0,
		FORWARD_ASSIST_MAX * 100.0,
		LANDING_ASSIST_BASE_METERS,
		LANDING_ASSIST_MAX_METERS,
		LANDING_COLLISION_MARGIN,
	])

func _physics_process(delta: float) -> void:
	if not RaceManager.active:
		return
	var player := _resolve_player()
	if player == null or player.finished:
		return

	_last_route_context = _detect_route_context(player)
	var on_floor: bool = player.is_on_floor()
	if on_floor:
		_coyote_remaining = COYOTE_TIME_SECONDS
	else:
		_coyote_remaining = maxf(0.0, _coyote_remaining - delta)
	_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)

	var jump_pressed: bool = Input.is_action_just_pressed(&"jump")
	if jump_pressed:
		_landing_correction_used = 0.0
		_landing_assist_logged = false
		if not on_floor:
			if _coyote_remaining > 0.0 and player.velocity.y <= 1.0:
				player.velocity.y = maxf(player.velocity.y, player.jump_velocity)
				_coyote_remaining = 0.0
				_jump_buffer_remaining = 0.0
				print("LOGSPIRE JUMP ASSIST type=extended_coyote seconds=%.2f" % COYOTE_TIME_SECONDS)
			else:
				_jump_buffer_remaining = JUMP_BUFFER_SECONDS
		_apply_forward_jump_assist(player)
		_log_jump_balance(player)

	if on_floor and not _player_was_on_floor:
		if _jump_buffer_remaining > 0.0:
			player.velocity.y = maxf(player.velocity.y, player.jump_velocity)
			_jump_buffer_remaining = 0.0
			_coyote_remaining = 0.0
			_landing_correction_used = 0.0
			_landing_assist_logged = false
			_apply_forward_jump_assist(player)
			print("LOGSPIRE JUMP ASSIST type=extended_buffer seconds=%.2f" % JUMP_BUFFER_SECONDS)
		_recalculate_player_target()

	if not on_floor:
		_apply_landing_magnet(player, delta)

	_player_was_on_floor = on_floor

func _apply_course_rebalance() -> void:
	_safe_ids = _copy_string_name_array(_world.call("get_route_ids", ROUTE_SAFE))
	_wild_ids = _copy_string_name_array(_world.call("get_route_ids", ROUTE_WILD))
	if _safe_ids.size() < 2:
		push_error("LOGSPIRE JUMP REBALANCE safe route unavailable")
		return

	var ids_value: Variant = _world.get("_platform_ids")
	var positions_value: Variant = _world.get("_platform_positions")
	var sizes_value: Variant = _world.get("_platform_sizes")
	var index_value: Variant = _world.get("_platform_index_by_id")
	if not (ids_value is Array) or not (positions_value is Array) or not (sizes_value is Array) or not (index_value is Dictionary):
		push_error("LOGSPIRE JUMP REBALANCE world data unavailable")
		return

	var all_ids: Array = ids_value
	var positions: Array = positions_value
	var sizes: Array = sizes_value
	_index_by_id = index_value

	for id_value: Variant in all_ids:
		var platform_id := StringName(id_value)
		var index: int = int(_index_by_id.get(platform_id, -1))
		if index < 0 or index >= positions.size() or index >= sizes.size():
			continue
		_old_positions[platform_id] = positions[index]
		_old_sizes[platform_id] = sizes[index]
		_new_sizes[platform_id] = sizes[index]

	for platform_id: StringName in _safe_ids:
		if platform_id == &"START":
			continue
		var index: int = int(_index_by_id.get(platform_id, -1))
		if index < 0:
			continue
		var original_size: Vector3 = sizes[index]
		var zone: int = int(_world.call("get_platform_zone", platform_id))
		var risk: float = float(_world.call("get_platform_risk", platform_id))
		var width_scale: float = _width_scale_for(zone, risk, platform_id)
		var length_scale: float = _length_scale_for(zone, risk, platform_id)
		var updated_size := Vector3(original_size.x * width_scale, original_size.y, original_size.z * length_scale)
		if platform_id == &"CROWN_NEST":
			updated_size = Vector3(original_size.x * 1.08, original_size.y, original_size.z * 1.08)
		sizes[index] = updated_size
		_new_sizes[platform_id] = updated_size

	var previous_id: StringName = _safe_ids[0]
	var previous_new: Vector3 = _old_positions.get(previous_id, Vector3.ZERO)
	positions[int(_index_by_id.get(previous_id, 0))] = previous_new

	for i: int in range(1, _safe_ids.size()):
		var platform_id: StringName = _safe_ids[i]
		var index: int = int(_index_by_id.get(platform_id, -1))
		if index < 0:
			continue
		var old_previous: Vector3 = _old_positions.get(previous_id, previous_new)
		var old_current: Vector3 = _old_positions.get(platform_id, positions[index])
		var old_delta: Vector3 = old_current - old_previous
		var planar := Vector3(old_delta.x, 0.0, old_delta.z)
		var planar_distance: float = planar.length()
		var direction: Vector3 = Vector3.FORWARD if planar_distance <= 0.001 else planar / planar_distance
		var old_previous_size: Vector3 = _old_sizes.get(previous_id, Vector3(8.0, 1.0, 8.0))
		var old_current_size: Vector3 = _old_sizes.get(platform_id, Vector3(8.0, 1.0, 8.0))
		var new_previous_size: Vector3 = _new_sizes.get(previous_id, old_previous_size)
		var new_current_size: Vector3 = _new_sizes.get(platform_id, old_current_size)
		var old_gap: float = planar_distance - (old_previous_size.z + old_current_size.z) * 0.5
		var zone: int = int(_world.call("get_platform_zone", platform_id))
		var risk: float = float(_world.call("get_platform_risk", platform_id))
		var reduction: float = _gap_reduction_for(zone, risk, platform_id)
		var target_planar_distance: float
		if old_gap > 0.0:
			var target_gap: float = maxf(_minimum_gap_for(zone, risk), old_gap * (1.0 - reduction))
			target_planar_distance = target_gap + (new_previous_size.z + new_current_size.z) * 0.5
		else:
			target_planar_distance = maxf(3.0, planar_distance * 0.97)
		var vertical_scale: float = 0.96 if zone <= 3 else 0.94
		var new_current := previous_new + direction * target_planar_distance + Vector3.UP * (old_delta.y * vertical_scale)
		positions[index] = new_current
		previous_id = platform_id
		previous_new = new_current

	_reanchor_wild_route(positions)
	_world.set("_platform_positions", positions)
	_world.set("_platform_sizes", sizes)
	_update_course_geometry(positions, sizes)
	_recenter_recovery_decks()
	_add_zone1_recovery_area()
	_update_course_length()
	_print_gap_report()

func _reanchor_wild_route(positions: Array) -> void:
	var split_id := StringName(_world.call("get_split_platform_id"))
	var merge_id := StringName(_world.call("get_merge_platform_id"))
	if split_id == &"" or merge_id == &"":
		return
	var old_split: Vector3 = _old_positions.get(split_id, Vector3.ZERO)
	var old_merge: Vector3 = _old_positions.get(merge_id, Vector3.ZERO)
	var new_split: Vector3 = positions[int(_index_by_id.get(split_id, 0))]
	var new_merge: Vector3 = positions[int(_index_by_id.get(merge_id, 0))]
	var old_line: Vector3 = old_merge - old_split
	var old_length_sq: float = maxf(0.001, old_line.length_squared())

	_wild_exclusive_ids.clear()
	for platform_id: StringName in _wild_ids:
		if _safe_ids.has(platform_id):
			continue
		_wild_exclusive_ids.append(platform_id)
		var old_position: Vector3 = _old_positions.get(platform_id, Vector3.ZERO)
		var t: float = clampf((old_position - old_split).dot(old_line) / old_length_sq, 0.0, 1.0)
		var old_anchor: Vector3 = old_split.lerp(old_merge, t)
		var offset: Vector3 = old_position - old_anchor
		var new_position: Vector3 = new_split.lerp(new_merge, t) + Vector3(offset.x * 0.98, offset.y * 0.95, offset.z * 0.98)
		var index: int = int(_index_by_id.get(platform_id, -1))
		if index >= 0 and index < positions.size():
			positions[index] = new_position

func _update_course_geometry(positions: Array, sizes: Array) -> void:
	for platform_id: StringName in _safe_ids:
		var index: int = int(_index_by_id.get(platform_id, -1))
		if index < 0 or index >= positions.size() or index >= sizes.size():
			continue
		_update_single_platform_geometry(platform_id, positions[index], sizes[index], ROUTE_SAFE)
	for platform_id: StringName in _wild_exclusive_ids:
		var index: int = int(_index_by_id.get(platform_id, -1))
		if index < 0 or index >= positions.size() or index >= sizes.size():
			continue
		_update_single_platform_geometry(platform_id, positions[index], sizes[index], ROUTE_WILD)

func _update_single_platform_geometry(platform_id: StringName, top: Vector3, size: Vector3, route_id: StringName) -> void:
	var root := _world.get_node_or_null(NodePath(String(platform_id))) as Node3D
	if root == null:
		return
	root.position = top - Vector3.UP * (size.y * 0.5)
	var forward: Vector3 = _route_forward(platform_id, route_id)
	if forward.length_squared() > 0.001:
		root.rotation.y = atan2(-forward.x, -forward.z)

	if platform_id == &"CROWN_NEST":
		var finish_mesh := root.get_node_or_null("CrownNestMesh") as MeshInstance3D
		if finish_mesh != null:
			var cylinder := finish_mesh.mesh as CylinderMesh
			if cylinder != null:
				cylinder.top_radius = size.x * 0.5
				cylinder.bottom_radius = size.x * 0.5
				cylinder.height = size.y
		var finish_body := root.get_node_or_null("CrownNestCollision") as StaticBody3D
		if finish_body != null:
			var finish_collision := finish_body.get_child(0) as CollisionShape3D if finish_body.get_child_count() > 0 else null
			if finish_collision != null:
				var finish_shape := finish_collision.shape as CylinderShape3D
				if finish_shape != null:
					finish_shape.radius = size.x * 0.5 + LANDING_COLLISION_MARGIN
					finish_shape.height = size.y
		return

	var mesh_instance := root.get_node_or_null("Mesh") as MeshInstance3D
	if mesh_instance != null:
		var box_mesh := mesh_instance.mesh as BoxMesh
		if box_mesh != null:
			box_mesh.size = size
	var body := root.get_node_or_null("Collision") as StaticBody3D
	if body != null and body.get_child_count() > 0:
		var collision := body.get_child(0) as CollisionShape3D
		if collision != null:
			var box_shape := collision.shape as BoxShape3D
			if box_shape != null:
				box_shape.size = size + Vector3(LANDING_COLLISION_MARGIN * 2.0, 0.0, LANDING_COLLISION_MARGIN * 2.0)

	if route_id == ROUTE_SAFE and platform_id != &"START" and not MOVING_SAFE_IDS.has(platform_id):
		_add_landing_guide(root, size)

func _add_landing_guide(root: Node3D, size: Vector3) -> void:
	if root.get_node_or_null("LandingGuide") != null:
		return
	var guide := MeshInstance3D.new()
	guide.name = "LandingGuide"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(maxf(2.4, size.x * 0.46), 0.07, minf(2.5, size.z * 0.22))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.58, 0.82, 0.22)
	material.roughness = 0.72
	mesh.material = material
	guide.mesh = mesh
	guide.position = Vector3(0.0, size.y * 0.5 + 0.05, 0.0)
	root.add_child(guide)

func _recenter_recovery_decks() -> void:
	var deck_names: Array[String] = ["Recovery_Z2", "Recovery_Z3", "Recovery_Z4", "Recovery_Z5", "Recovery_Z6"]
	for zone_offset: int in range(deck_names.size()):
		var zone: int = zone_offset + 1
		var sum := Vector3.ZERO
		var count: int = 0
		var min_y: float = INF
		for platform_id: StringName in _safe_ids:
			if int(_world.call("get_platform_zone", platform_id)) != zone:
				continue
			var position: Vector3 = _world.call("get_platform_position", platform_id)
			sum += position
			count += 1
			min_y = minf(min_y, position.y)
		if count <= 0:
			continue
		var center: Vector3 = sum / float(count)
		var top := Vector3(center.x, min_y - (4.0 + float(zone_offset) * 0.65), center.z)
		var deck_root := _world.get_node_or_null(NodePath(deck_names[zone_offset] + "_Deck")) as Node3D
		if deck_root != null:
			deck_root.position = top - Vector3.UP * 0.30
		var area := _world.get_node_or_null(NodePath(deck_names[zone_offset])) as Area3D
		if area != null:
			area.position = top + Vector3.UP * 1.20

func _add_zone1_recovery_area() -> void:
	if _world.get_node_or_null("Recovery_Z1_Accessible") != null:
		return
	var zone_positions: Array[Vector3] = []
	for platform_id: StringName in _safe_ids:
		if int(_world.call("get_platform_zone", platform_id)) == 0 and platform_id != &"START":
			zone_positions.append(_world.call("get_platform_position", platform_id))
	if zone_positions.is_empty():
		return
	var center := Vector3.ZERO
	for point: Vector3 in zone_positions:
		center += point
	center /= float(zone_positions.size())
	var area := Area3D.new()
	area.name = "Recovery_Z1_Accessible"
	area.position = Vector3(center.x, 0.18, center.z)
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.monitorable = false
	area.set_meta(&"logspire_recovery_target", &"START")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(82.0, 0.75, 130.0)
	collision.shape = shape
	area.add_child(collision)
	_world.add_child(area)
	var recovery_areas_value: Variant = _world.get("_recovery_areas")
	if recovery_areas_value is Array:
		var recovery_areas: Array = recovery_areas_value
		recovery_areas.append(area)
		_world.set("_recovery_areas", recovery_areas)

func _update_course_length() -> void:
	var total: float = 0.0
	for i: int in range(_safe_ids.size() - 1):
		var a: Vector3 = _world.call("get_platform_position", _safe_ids[i])
		var b: Vector3 = _world.call("get_platform_position", _safe_ids[i + 1])
		total += a.distance_to(b)
	_world.set("_course_length", total)

func _apply_runtime_platform_forgiveness() -> void:
	if _runtime_patched or _gameplay == null:
		return
	var runtime_value: Variant = _gameplay.get("_runtime")
	if not (runtime_value is Dictionary):
		return
	var runtime: Dictionary = runtime_value
	if runtime.is_empty():
		return
	for platform_id: StringName in MOVING_SAFE_IDS:
		if not runtime.has(platform_id):
			continue
		var data: Dictionary = runtime[platform_id]
		var kind: StringName = data.get("kind", &"")
		var body := data.get("body") as AnimatableBody3D
		if body != null:
			body.scale = Vector3(MOVING_LOG_SIZE_SCALE, 1.05, MOVING_LOG_SIZE_SCALE)
		if kind == &"rolling":
			data["angular_speed"] = float(data.get("angular_speed", 0.0)) * MOVING_LOG_SPEED_SCALE
		elif kind == &"swing":
			data["amplitude"] = float(data.get("amplitude", 0.0)) * MOVING_LOG_SPEED_SCALE
		runtime[platform_id] = data
	_gameplay.set("_runtime", runtime)
	_runtime_patched = true
	print("LOGSPIRE MOVING PLATFORM REBALANCE speed_scale=%.2f size_scale=%.2f rolling_easier=true swing_easier=true" % [MOVING_LOG_SPEED_SCALE, MOVING_LOG_SIZE_SCALE])

func _apply_forward_jump_assist(player: WildDashCharacterController) -> void:
	var target_id: StringName = _current_target_id()
	if target_id == &"":
		return
	var target: Vector3 = _world.call("get_platform_position", target_id)
	var to_target: Vector3 = target - player.global_position
	to_target.y = 0.0
	if to_target.length_squared() <= 0.001:
		return
	to_target = to_target.normalized()
	var facing: Vector3 = -player.global_transform.basis.z
	facing.y = 0.0
	if facing.length_squared() <= 0.001:
		return
	facing = facing.normalized()
	if facing.dot(to_target) < 0.52:
		return
	var failure_count: int = int(_failures_by_target.get(target_id, 0))
	var assist_ratio: float = minf(FORWARD_ASSIST_MAX, FORWARD_ASSIST_BASE + float(mini(3, failure_count)) * 0.01)
	var impulse_strength: float = clampf(player.current_speed * assist_ratio, 0.62, 1.45)
	var impulse_value: Variant = player.get("_skill_impulse_velocity")
	var impulse: Vector3 = impulse_value if impulse_value is Vector3 else Vector3.ZERO
	player.set("_skill_impulse_velocity", impulse + to_target * impulse_strength)
	print("LOGSPIRE JUMP ASSIST type=forward target=%s ratio=%.2f impulse=%.2f failures=%d" % [String(target_id), assist_ratio, impulse_strength, failure_count])

func _apply_landing_magnet(player: WildDashCharacterController, delta: float) -> void:
	if player.velocity.y > 1.0:
		return
	var target_id: StringName = _current_target_id()
	if target_id == &"":
		return
	var target: Vector3 = _world.call("get_platform_position", target_id)
	var vertical: float = player.global_position.y - target.y
	if vertical < 0.10 or vertical > 4.6:
		return
	var planar := Vector3(target.x - player.global_position.x, 0.0, target.z - player.global_position.z)
	var distance: float = planar.length()
	var landing_radius: float = float(_world.call("get_platform_landing_radius", target_id))
	var failure_count: int = int(_failures_by_target.get(target_id, 0))
	var max_total: float = minf(LANDING_ASSIST_MAX_METERS, LANDING_ASSIST_BASE_METERS + float(mini(3, failure_count)) * 0.08)
	if distance > landing_radius + max_total + 0.35 or distance <= landing_radius * 0.48:
		return
	var remaining: float = maxf(0.0, max_total - _landing_correction_used)
	if remaining <= 0.001 or planar.length_squared() <= 0.001:
		return
	var step: float = minf(remaining, minf(distance * 0.08, delta * 2.8))
	if step <= 0.001:
		return
	player.global_position += planar.normalized() * step
	_landing_correction_used += step
	if not _landing_assist_logged:
		_landing_assist_logged = true
		print("LOGSPIRE JUMP ASSIST type=landing_magnet target=%s max=%.2fm failures=%d" % [String(target_id), max_total, failure_count])

func _recalculate_player_target() -> void:
	var player := _resolve_player()
	if player == null or _safe_ids.is_empty():
		return
	var best_index: int = 0
	var best_distance: float = INF
	for i: int in range(_safe_ids.size()):
		var point: Vector3 = _world.call("get_platform_position", _safe_ids[i])
		var distance: float = player.global_position.distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	_player_target_index = mini(best_index + 1, _safe_ids.size() - 1)

func _current_target_id() -> StringName:
	if _safe_ids.is_empty():
		return &""
	return _safe_ids[clampi(_player_target_index, 0, _safe_ids.size() - 1)]

func _detect_route_context(player: WildDashCharacterController) -> StringName:
	if _wild_exclusive_ids.is_empty():
		return ROUTE_SAFE
	var nearest_wild: float = INF
	for platform_id: StringName in _wild_exclusive_ids:
		var point: Vector3 = _world.call("get_platform_position", platform_id)
		var delta := Vector3(point.x - player.global_position.x, 0.0, point.z - player.global_position.z)
		nearest_wild = minf(nearest_wild, delta.length())
	return ROUTE_WILD if nearest_wild <= 9.0 else ROUTE_SAFE

func _on_racer_recovered(racer: WildDashCharacterController, _target_id: StringName) -> void:
	if racer == null:
		return
	if racer.is_player:
		var failed_id: StringName = _current_target_id()
		var failures: int = int(_failures_by_target.get(failed_id, 0)) + 1
		_failures_by_target[failed_id] = failures
		_falls_total += 1
		_recoveries += 1
		if _last_route_context == ROUTE_WILD:
			_wild_falls += 1
		else:
			_safe_falls += 1
		if failures >= 2:
			_repeated_failures += 1
		print("LOGSPIRE FALL RECOVERY zone=%s route=%s failed_jump=%s recovery_time=%.2f failure_count=%d adaptive_assist=%s" % [
			_zone_name_for_platform(failed_id),
			String(_last_route_context),
			String(failed_id),
			RECOVERY_TIME_SECONDS,
			failures,
			"stronger" if failures >= 2 else "base",
		])
		call_deferred("_recalculate_player_target")
	else:
		# Existing Platform AI already switches to safer landing after repeated failure.
		racer.current_speed = maxf(racer.current_speed, racer.cruise_speed * 0.78)

func _on_racer_finished(racer: Node3D, _rank: int) -> void:
	var typed := racer as WildDashCharacterController
	if typed == null or not typed.is_player or _report_printed:
		return
	_report_printed = true
	print("LOGSPIRE DIFFICULTY REPORT falls=%d safe_route_falls=%d wild_route_falls=%d recoveries=%d repeated_failures=%d target_safe_first_try=85-95%% ai_safe_stability_target=95%%" % [
		_falls_total,
		_safe_falls,
		_wild_falls,
		_recoveries,
		_repeated_failures,
	])

func _log_jump_balance(player: WildDashCharacterController) -> void:
	var target_id: StringName = _current_target_id()
	if target_id == &"":
		return
	var target_index: int = _safe_ids.find(target_id)
	var gap: float = 0.0
	if target_index > 0:
		gap = _surface_gap(_safe_ids[target_index - 1], target_id, false)
	var size: Vector3 = _new_sizes.get(target_id, Vector3(8.0, 1.0, 8.0))
	var failures: int = int(_failures_by_target.get(target_id, 0))
	print("LOGSPIRE JUMP BALANCE zone=%s gap=%.2f platform_width=%.2f route=%s safe_route=%s assist=forward_%.0f%%+landing_%.2fm failure_count=%d" % [
		_zone_name_for_platform(target_id),
		gap,
		size.x,
		String(_last_route_context),
		str(_last_route_context == ROUTE_SAFE),
		minf(FORWARD_ASSIST_MAX, FORWARD_ASSIST_BASE + float(mini(3, failures)) * 0.01) * 100.0,
		minf(LANDING_ASSIST_MAX_METERS, LANDING_ASSIST_BASE_METERS + float(mini(3, failures)) * 0.08),
		failures,
	])

func _print_gap_report() -> void:
	var before_total: float = 0.0
	var after_total: float = 0.0
	var count: int = 0
	var zone_before: Dictionary = {}
	var zone_after: Dictionary = {}
	var zone_count: Dictionary = {}
	for i: int in range(1, _safe_ids.size()):
		var current_id: StringName = _safe_ids[i]
		var previous_id: StringName = _safe_ids[i - 1]
		var before_gap: float = _surface_gap_pair(previous_id, current_id, true)
		var after_gap: float = _surface_gap_pair(previous_id, current_id, false)
		before_total += before_gap
		after_total += after_gap
		count += 1
		var zone: int = int(_world.call("get_platform_zone", current_id))
		zone_before[zone] = float(zone_before.get(zone, 0.0)) + before_gap
		zone_after[zone] = float(zone_after.get(zone, 0.0)) + after_gap
		zone_count[zone] = int(zone_count.get(zone, 0)) + 1
	var before_average: float = before_total / maxf(1.0, float(count))
	var after_average: float = after_total / maxf(1.0, float(count))
	var reduction_percent: float = 0.0 if before_average <= 0.001 else (1.0 - after_average / before_average) * 100.0
	print("LOGSPIRE JUMP REBALANCE SUMMARY avg_gap_before=%.2fm avg_gap_after=%.2fm reduction=%.1f%% platform_width_increase=18-25%% collision_margin=%.2fm safe_route=easier wild_route=mastery" % [
		before_average, after_average, reduction_percent, LANDING_COLLISION_MARGIN,
	])
	for zone: int in range(6):
		var amount: int = int(zone_count.get(zone, 0))
		if amount <= 0:
			continue
		var before_zone: float = float(zone_before.get(zone, 0.0)) / float(amount)
		var after_zone: float = float(zone_after.get(zone, 0.0)) / float(amount)
		var zone_reduction: float = 0.0 if before_zone <= 0.001 else (1.0 - after_zone / before_zone) * 100.0
		print("LOGSPIRE JUMP REBALANCE ZONE zone=%d name=%s gap_before=%.2fm gap_after=%.2fm reduction=%.1f%%" % [
			zone + 1, _zone_name(zone), before_zone, after_zone, zone_reduction,
		])

func _surface_gap_pair(a_id: StringName, b_id: StringName, use_old: bool) -> float:
	var a_position: Vector3
	var b_position: Vector3
	var a_size: Vector3
	var b_size: Vector3
	if use_old:
		a_position = _old_positions.get(a_id, Vector3.ZERO)
		b_position = _old_positions.get(b_id, Vector3.ZERO)
		a_size = _old_sizes.get(a_id, Vector3(8.0, 1.0, 8.0))
		b_size = _old_sizes.get(b_id, Vector3(8.0, 1.0, 8.0))
	else:
		a_position = _world.call("get_platform_position", a_id)
		b_position = _world.call("get_platform_position", b_id)
		a_size = _new_sizes.get(a_id, _old_sizes.get(a_id, Vector3(8.0, 1.0, 8.0)))
		b_size = _new_sizes.get(b_id, _old_sizes.get(b_id, Vector3(8.0, 1.0, 8.0)))
	var planar := Vector3(b_position.x - a_position.x, 0.0, b_position.z - a_position.z)
	return maxf(0.0, planar.length() - (a_size.z + b_size.z) * 0.5)

func _surface_gap(a_id: StringName, b_id: StringName, use_old: bool) -> float:
	return _surface_gap_pair(a_id, b_id, use_old)

func _gap_reduction_for(zone: int, risk: float, platform_id: StringName) -> float:
	if platform_id == &"CROWN_NEST":
		return DIFFICULT_GAP_REDUCTION
	if zone == 0:
		return EASY_GAP_REDUCTION
	if zone == 1:
		return 0.25
	if zone == 2:
		return 0.24
	if zone == 3:
		return 0.24
	if risk <= 0.20:
		return EASY_GAP_REDUCTION
	if risk <= 0.32:
		return NORMAL_GAP_REDUCTION
	return DIFFICULT_GAP_REDUCTION

func _width_scale_for(zone: int, risk: float, platform_id: StringName) -> float:
	if platform_id == &"CROWN_NEST":
		return 1.08
	if zone == 0:
		return 1.25
	if zone in [1, 2, 3]:
		return 1.22
	if risk <= 0.32:
		return 1.20
	return 1.18

func _length_scale_for(zone: int, risk: float, platform_id: StringName) -> float:
	if platform_id == &"CROWN_NEST":
		return 1.08
	if zone <= 1:
		return 1.06
	if zone <= 3:
		return 1.05
	return 1.03 if risk > 0.32 else 1.04

func _minimum_gap_for(zone: int, risk: float) -> float:
	if zone == 0:
		return 1.4
	if zone <= 3 and risk <= 0.25:
		return 1.8
	return 2.2

func _route_forward(platform_id: StringName, route_id: StringName) -> Vector3:
	var ids: Array[StringName] = _wild_ids if route_id == ROUTE_WILD else _safe_ids
	var index: int = ids.find(platform_id)
	if index < 0:
		return Vector3.FORWARD
	var current: Vector3 = _world.call("get_platform_position", platform_id)
	var direction := Vector3.FORWARD
	if index + 1 < ids.size():
		direction = _world.call("get_platform_position", ids[index + 1]) - current
	elif index > 0:
		direction = current - _world.call("get_platform_position", ids[index - 1])
	direction.y = 0.0
	return Vector3.FORWARD if direction.length_squared() <= 0.001 else direction.normalized()

func _zone_name_for_platform(platform_id: StringName) -> String:
	return _zone_name(int(_world.call("get_platform_zone", platform_id)))

func _zone_name(zone: int) -> String:
	match zone:
		0:
			return "FALLEN FOREST"
		1:
			return "BROKEN BRIDGE"
		2:
			return "ROLLING GROVE"
		3:
			return "VINE CANYON"
		4:
			return "TITAN TREE"
		_:
			return "SKY LOG FINALE"

func _resolve_player() -> WildDashCharacterController:
	for racer_value: Variant in RaceManager.racers:
		var racer := racer_value as WildDashCharacterController
		if racer != null and racer.is_player:
			return racer
	return null

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
