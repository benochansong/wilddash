extends "res://modes/logspire_leap/logspire_water_recovery_v7_jumpout_safe_exit.gd"

## Player-tested traversal UX pass.
## - camera-relative swimming
## - low-ledge auto vault
## - root ramps become owned auto traversals
## - ladders align first, then climb at readable speeds
## - recovery racers ignore racer-racer collision while in the river

const LOW_LEDGE_DETECTION_RADIUS: float = 2.0
const LOW_LEDGE_AUTO_VAULT_RADIUS: float = 1.0
const AUTO_VAULT_DURATION: float = 0.45
const AUTO_VAULT_ARC_HEIGHT: float = 0.70
const ROOT_SEARCH_RADIUS: float = 12.0
const ROOT_AUTO_ATTACH_RADIUS: float = 4.0
const ROOT_CLIMB_SPEED_MPS: float = 4.5
const ROOT_CLIMB_MIN_SECONDS: float = 1.25
const ROOT_CLIMB_MAX_SECONDS: float = 4.5
const LADDER_AUTO_ATTACH_RADIUS: float = 5.0
const LADDER_ALIGN_SECONDS: float = 0.32
const PLAYER_LADDER_SPEED_MPS: float = 3.2
const AI_LADDER_SPEED_MPS: float = 3.7
const LADDER_MIN_SECONDS: float = 1.8
const LADDER_MAX_SECONDS: float = 6.5
const LADDER_EXIT_SECONDS: float = 0.34
const WATER_INPUT_LOG_INTERVAL: float = 1.2
const AI_QUEUE_OFFSET_METERS: float = 1.2

var _traversal_kind_by_id: Dictionary = {}
var _traversal_elapsed_by_id: Dictionary = {}
var _traversal_duration_by_id: Dictionary = {}
var _traversal_from_by_id: Dictionary = {}
var _traversal_to_by_id: Dictionary = {}
var _traversal_path_by_id: Dictionary = {}
var _saved_collision_mask_by_id: Dictionary = {}
var _water_input_log_elapsed_by_id: Dictionary = {}

func _enter_water(racer: WildDashCharacterController, zone: int, water_y: float) -> void:
	if racer != null and is_instance_valid(racer):
		_saved_collision_mask_by_id[racer.get_instance_id()] = racer.collision_mask
	super(racer, zone, water_y)
	if racer != null and is_instance_valid(racer) and is_water_recovering(racer):
		# Layer 1 is world/track. Ignore layer 2 racers while recovering so a pack
		# cannot pin itself against a ledge, root entry, or ladder bottom.
		racer.collision_mask = 1

func _update_swimming(racer: WildDashCharacterController, delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	_cancel_stale_checkpoint_recovery(racer)
	racer.collision_mask = 1
	var racer_id: int = racer.get_instance_id()
	var zone: int = int(_zone_by_id.get(racer_id, 0))
	var water_y: float = float(_water_y_by_id.get(racer_id, racer.global_position.y))
	var controlled_by_player: bool = racer.is_player and DisplayServer.get_name() != "headless"

	# 1) LOW LEDGE / AUTO VAULT
	var jump_out: Dictionary = _nearest_recovery_entry(racer, "get_jump_outs_for_zone", zone, JUMP_OUT_GUIDANCE_RADIUS)
	if not jump_out.is_empty() and float(jump_out.get("height", 99.0)) <= MAX_JUMP_OUT_HEIGHT:
		var jump_distance: float = _entry_distance(racer, jump_out)
		var should_vault: bool = jump_distance <= LOW_LEDGE_AUTO_VAULT_RADIUS
		if controlled_by_player and jump_distance <= LOW_LEDGE_DETECTION_RADIUS and InputManager.consume_jump():
			should_vault = true
		elif not controlled_by_player and jump_distance <= LOW_LEDGE_DETECTION_RADIUS:
			should_vault = true
		if should_vault and _vault_landing_is_safe(racer, jump_out):
			_begin_auto_vault(racer, jump_out)
			return
		if controlled_by_player:
			_set_hud_message("RECOVERY ROUTE · %s" % ("JUMP BACK UP! · SPACE" if jump_distance <= LOW_LEDGE_DETECTION_RADIUS else "SWIM TO LOW LEDGE"))
			_apply_manual_recovery_swim(racer, water_y, delta)
		else:
			_apply_ai_recovery_swim(racer, jump_out, water_y, delta)
		return

	# 2) ROOT AUTO CLIMB
	var ramp: Dictionary = _nearest_recovery_entry(racer, "get_root_ramps_for_zone", zone, ROOT_SEARCH_RADIUS)
	if not ramp.is_empty():
		var ramp_distance: float = _entry_distance(racer, ramp)
		if ramp_distance <= ROOT_AUTO_ATTACH_RADIUS:
			_begin_root_climb(racer, ramp)
			return
		if controlled_by_player:
			_set_hud_message("RECOVERY ROUTE · SWIM TO THE ROOT")
			_apply_manual_recovery_swim(racer, water_y, delta)
		else:
			_apply_ai_recovery_swim(racer, ramp, water_y, delta)
		return

	# 3) LADDER ALIGN + SLOW CLIMB
	var ladder: Dictionary = _nearest_physical_ladder(racer)
	if ladder.is_empty():
		var current_value: Variant = _ladder_by_id.get(racer_id, {})
		if current_value is Dictionary:
			ladder = current_value
	if ladder.is_empty() and _ladder_system != null:
		var all_ladders: Array = _ladder_system.call("get_all_ladders")
		ladder = _water_ai.call("choose_ladder", racer, zone, all_ladders, RaceManager.get_checkpoint_progress(racer))
	if ladder.is_empty():
		if controlled_by_player:
			_set_hud_message("RECOVERY ROUTE · FIND AN EXIT")
			_apply_manual_recovery_swim(racer, water_y, delta)
		return

	_ladder_by_id[racer_id] = ladder
	var ladder_distance: float = _planar_distance_to_ladder(racer, ladder)
	if ladder_distance <= LADDER_AUTO_ATTACH_RADIUS:
		_begin_ladder_climb(racer, ladder)
		return
	if controlled_by_player:
		_set_hud_message("RECOVERY ROUTE · SWIM TO THE LADDER · %.0fm" % ladder_distance)
		_apply_manual_recovery_swim(racer, water_y, delta)
	else:
		_apply_ai_recovery_swim(racer, {"entry": ladder.get("bottom", racer.global_position)}, water_y, delta)

func _apply_manual_recovery_swim(racer: WildDashCharacterController, water_y: float, delta: float) -> void:
	var racer_id: int = racer.get_instance_id()
	var camera: Camera3D = get_viewport().get_camera_3d()
	var direction_value: Variant = _swim.call("get_player_direction", camera)
	var direction: Vector3 = direction_value if direction_value is Vector3 else Vector3.ZERO
	_swim.call("apply_swim", racer, direction, water_y, delta)
	_water_elapsed_by_id[racer_id] = float(_water_elapsed_by_id.get(racer_id, 0.0)) + delta
	var log_elapsed: float = float(_water_input_log_elapsed_by_id.get(racer_id, 0.0)) + delta
	if log_elapsed >= WATER_INPUT_LOG_INTERVAL:
		log_elapsed = 0.0
		var axis: Vector2 = InputManager.get_move_vector()
		var camera_forward := Vector3.FORWARD
		if camera != null:
			camera_forward = -camera.global_transform.basis.z
			camera_forward.y = 0.0
			if camera_forward.length_squared() > 0.001:
				camera_forward = camera_forward.normalized()
		print("LOGSPIRE WATER INPUT racer=%s input=(%.2f,%.2f) camera_forward=(%.2f,%.2f) move_direction=(%.2f,%.2f)" % [
			RaceManager.get_racer_label(racer), axis.x, axis.y, camera_forward.x, camera_forward.z, direction.x, direction.z,
		])
	_water_input_log_elapsed_by_id[racer_id] = log_elapsed

func _apply_ai_recovery_swim(racer: WildDashCharacterController, target: Dictionary, water_y: float, delta: float) -> void:
	var racer_id: int = racer.get_instance_id()
	var entry_value: Variant = target.get("entry", racer.global_position)
	var point: Vector3 = entry_value if entry_value is Vector3 else racer.global_position
	var raw_direction := point - racer.global_position
	raw_direction.y = 0.0
	if raw_direction.length_squared() > 0.001:
		var forward := raw_direction.normalized()
		var right := Vector3(-forward.z, 0.0, forward.x)
		var slot: int = int(racer_id % 3) - 1
		point += right * float(slot) * AI_QUEUE_OFFSET_METERS
	var direction := point - racer.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		direction = direction.normalized()
	_swim.call("apply_swim", racer, direction, water_y, delta)
	_water_elapsed_by_id[racer_id] = float(_water_elapsed_by_id.get(racer_id, 0.0)) + delta

func _begin_auto_vault(racer: WildDashCharacterController, entry: Dictionary) -> void:
	var racer_id: int = racer.get_instance_id()
	var landing_value: Variant = entry.get("landing", racer.global_position + Vector3.UP * 1.2)
	var landing: Vector3 = landing_value if landing_value is Vector3 else racer.global_position + Vector3.UP * 1.2
	_state_by_id[racer_id] = WaterState.LADDER_CLIMB
	_traversal_kind_by_id[racer_id] = &"auto_vault"
	_traversal_elapsed_by_id[racer_id] = 0.0
	_traversal_duration_by_id[racer_id] = AUTO_VAULT_DURATION
	_traversal_from_by_id[racer_id] = racer.global_position
	_traversal_to_by_id[racer_id] = landing
	_ladder_by_id[racer_id] = entry
	racer.velocity = Vector3.ZERO
	_log_congestion(racer, "low_ledge")
	print("LOGSPIRE AUTO VAULT racer=%s height=%.2f duration=%.2f" % [
		RaceManager.get_racer_label(racer), float(entry.get("height", 0.0)), AUTO_VAULT_DURATION,
	])

func _begin_root_climb(racer: WildDashCharacterController, ramp: Dictionary) -> void:
	var racer_id: int = racer.get_instance_id()
	var path: Array = []
	path.append(racer.global_position)
	var authored_value: Variant = ramp.get("path_points", [])
	if authored_value is Array:
		for point_value: Variant in authored_value:
			if point_value is Vector3:
				path.append(point_value)
	if path.size() < 2:
		var entry_value: Variant = ramp.get("entry", racer.global_position)
		var exit_value: Variant = ramp.get("exit", racer.global_position + Vector3.UP * 2.0)
		if entry_value is Vector3:
			path.append(entry_value)
		if exit_value is Vector3:
			path.append(exit_value)
	var path_length: float = _path_length(path)
	var duration: float = clampf(path_length / ROOT_CLIMB_SPEED_MPS, ROOT_CLIMB_MIN_SECONDS, ROOT_CLIMB_MAX_SECONDS)
	_state_by_id[racer_id] = WaterState.LADDER_CLIMB
	_traversal_kind_by_id[racer_id] = &"root_climb"
	_traversal_elapsed_by_id[racer_id] = 0.0
	_traversal_duration_by_id[racer_id] = duration
	_traversal_path_by_id[racer_id] = path
	_ladder_by_id[racer_id] = ramp
	racer.velocity = Vector3.ZERO
	_log_congestion(racer, "root")
	print("LOGSPIRE ROOT AUTO CLIMB racer=%s duration=%.2f speed=%.1f path_points=%d" % [
		RaceManager.get_racer_label(racer), duration, ROOT_CLIMB_SPEED_MPS, path.size(),
	])

func _begin_ladder_climb(racer: WildDashCharacterController, ladder: Dictionary) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	_cancel_stale_checkpoint_recovery(racer)
	var racer_id: int = racer.get_instance_id()
	var bottom_value: Variant = ladder.get("bottom", racer.global_position)
	var bottom: Vector3 = bottom_value if bottom_value is Vector3 else racer.global_position
	var align_target := racer.global_position
	align_target.x = bottom.x
	align_target.z = bottom.z
	_state_by_id[racer_id] = WaterState.LADDER_CLIMB
	_traversal_kind_by_id[racer_id] = &"ladder_align"
	_traversal_elapsed_by_id[racer_id] = 0.0
	_traversal_duration_by_id[racer_id] = LADDER_ALIGN_SECONDS
	_traversal_from_by_id[racer_id] = racer.global_position
	_traversal_to_by_id[racer_id] = align_target
	_ladder_by_id[racer_id] = ladder
	racer.velocity = Vector3.ZERO
	_log_congestion(racer, "ladder")
	print("LOGSPIRE LADDER ALIGN racer=%s ladder=%s duration=%.2f" % [
		RaceManager.get_racer_label(racer), String(ladder.get("id", &"")), LADDER_ALIGN_SECONDS,
	])

func _update_ladder_climb(racer: WildDashCharacterController, delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	_cancel_stale_checkpoint_recovery(racer)
	racer.collision_mask = 1
	var racer_id: int = racer.get_instance_id()
	var kind := StringName(_traversal_kind_by_id.get(racer_id, &""))
	match kind:
		&"auto_vault":
			_update_auto_vault(racer, delta)
		&"root_climb":
			_update_root_climb(racer, delta)
		&"ladder_align":
			_update_ladder_align(racer, delta)
		&"ladder_climb":
			_update_slow_ladder_climb(racer, delta)
		&"ladder_exit":
			_update_ladder_exit(racer, delta)
		_:
			super(racer, delta)

func _update_auto_vault(racer: WildDashCharacterController, delta: float) -> void:
	var racer_id: int = racer.get_instance_id()
	var t: float = _advance_traversal(racer_id, delta)
	var from: Vector3 = _traversal_from_by_id.get(racer_id, racer.global_position)
	var to: Vector3 = _traversal_to_by_id.get(racer_id, racer.global_position)
	var position := from.lerp(to, t)
	position.y += sin(t * PI) * AUTO_VAULT_ARC_HEIGHT
	racer.global_position = position
	racer.velocity = Vector3.ZERO
	if t >= 1.0:
		_finish_assisted_recovery(racer, to, "JUMP OUT! · BACK TO THE RACE")

func _update_root_climb(racer: WildDashCharacterController, delta: float) -> void:
	var racer_id: int = racer.get_instance_id()
	var t: float = _advance_traversal(racer_id, delta)
	var path_value: Variant = _traversal_path_by_id.get(racer_id, [])
	var path: Array = path_value if path_value is Array else []
	var position: Vector3 = _point_on_path(path, t)
	racer.global_position = position
	racer.velocity = Vector3.ZERO
	if path.size() >= 2:
		var ahead: Vector3 = _point_on_path(path, minf(1.0, t + 0.04))
		var direction := ahead - position
		direction.y = 0.0
		if direction.length_squared() > 0.001:
			racer.rotation.y = atan2(-direction.x, -direction.z)
	if t >= 1.0:
		var exit_position: Vector3 = path[path.size() - 1] if not path.is_empty() else racer.global_position
		_finish_assisted_recovery(racer, exit_position, "ROOT CLIMB COMPLETE · BACK TO THE RACE")

func _update_ladder_align(racer: WildDashCharacterController, delta: float) -> void:
	var racer_id: int = racer.get_instance_id()
	var t: float = _advance_traversal(racer_id, delta)
	var from: Vector3 = _traversal_from_by_id.get(racer_id, racer.global_position)
	var to: Vector3 = _traversal_to_by_id.get(racer_id, racer.global_position)
	racer.global_position = from.lerp(to, t)
	racer.velocity = Vector3.ZERO
	if t < 1.0:
		return
	var ladder_value: Variant = _ladder_by_id.get(racer_id, {})
	var ladder: Dictionary = ladder_value if ladder_value is Dictionary else {}
	var bottom_value: Variant = ladder.get("bottom", racer.global_position)
	var exit_value: Variant = ladder.get("safe_exit", ladder.get("exit", racer.global_position + Vector3.UP * 4.0))
	var bottom: Vector3 = bottom_value if bottom_value is Vector3 else racer.global_position
	var safe_exit: Vector3 = exit_value if exit_value is Vector3 else racer.global_position + Vector3.UP * 4.0
	var climb_from := racer.global_position
	climb_from.x = bottom.x
	climb_from.z = bottom.z
	climb_from.y = maxf(climb_from.y, bottom.y)
	var climb_to := Vector3(bottom.x, safe_exit.y, bottom.z)
	var climb_height: float = maxf(1.0, climb_to.y - climb_from.y)
	var climb_speed: float = PLAYER_LADDER_SPEED_MPS if racer.is_player else AI_LADDER_SPEED_MPS
	var duration: float = clampf(climb_height / climb_speed, LADDER_MIN_SECONDS, LADDER_MAX_SECONDS)
	_traversal_kind_by_id[racer_id] = &"ladder_climb"
	_traversal_elapsed_by_id[racer_id] = 0.0
	_traversal_duration_by_id[racer_id] = duration
	_traversal_from_by_id[racer_id] = climb_from
	_traversal_to_by_id[racer_id] = climb_to
	_climb_duration_by_id[racer_id] = duration
	print("LOGSPIRE LADDER CLIMB racer=%s ladder=%s height=%.2f speed=%.2f duration=%.2f" % [
		RaceManager.get_racer_label(racer), String(ladder.get("id", &"")), climb_height, climb_speed, duration,
	])

func _update_slow_ladder_climb(racer: WildDashCharacterController, delta: float) -> void:
	var racer_id: int = racer.get_instance_id()
	var t: float = _advance_traversal(racer_id, delta)
	var from: Vector3 = _traversal_from_by_id.get(racer_id, racer.global_position)
	var to: Vector3 = _traversal_to_by_id.get(racer_id, racer.global_position)
	var position := from.lerp(to, t)
	position.x = from.x
	position.z = from.z
	racer.global_position = position
	racer.velocity = Vector3.ZERO
	if t < 1.0:
		return
	var ladder_value: Variant = _ladder_by_id.get(racer_id, {})
	var ladder: Dictionary = ladder_value if ladder_value is Dictionary else {}
	var safe_exit_value: Variant = ladder.get("safe_exit", ladder.get("exit", to))
	var safe_exit: Vector3 = safe_exit_value if safe_exit_value is Vector3 else to
	_traversal_kind_by_id[racer_id] = &"ladder_exit"
	_traversal_elapsed_by_id[racer_id] = 0.0
	_traversal_duration_by_id[racer_id] = LADDER_EXIT_SECONDS
	_traversal_from_by_id[racer_id] = to
	_traversal_to_by_id[racer_id] = safe_exit

func _update_ladder_exit(racer: WildDashCharacterController, delta: float) -> void:
	var racer_id: int = racer.get_instance_id()
	var t: float = _advance_traversal(racer_id, delta)
	var from: Vector3 = _traversal_from_by_id.get(racer_id, racer.global_position)
	var to: Vector3 = _traversal_to_by_id.get(racer_id, racer.global_position)
	racer.global_position = from.lerp(to, t)
	racer.velocity = Vector3.ZERO
	if t >= 1.0:
		_finish_water_recovery(racer)

func _finish_water_recovery(racer: WildDashCharacterController) -> void:
	_restore_recovery_collision(racer)
	super(racer)
	_clear_v8_runtime(racer.get_instance_id())

func _finish_assisted_recovery(racer: WildDashCharacterController, exit_position: Vector3, message: String) -> void:
	var racer_id: int = racer.get_instance_id()
	var target_value: Variant = _ladder_by_id.get(racer_id, {})
	var target: Dictionary = target_value if target_value is Dictionary else {}
	var platform_id := StringName(target.get("platform_id", &""))
	racer.reset_motion(exit_position)
	_restore_recovery_collision(racer)
	_release_racer_control(racer)
	_state_by_id[racer_id] = WaterState.RACING
	racer.set_meta(WATER_META, false)
	racer.current_speed = maxf(4.4, racer.cruise_speed * 0.58)
	_water_recoveries += 1
	_apply_recovery_protection(racer)
	_notify_platform_ai_recovered(racer)
	if racer.is_player and DisplayServer.get_name() != "headless":
		_set_hud_message(message)
	water_recovered.emit(racer, platform_id)
	_clear_water_runtime(racer_id)
	_clear_v8_runtime(racer_id)

func _vault_landing_is_safe(racer: WildDashCharacterController, entry: Dictionary) -> bool:
	var landing_value: Variant = entry.get("landing", Vector3.ZERO)
	if not (landing_value is Vector3):
		return false
	var landing: Vector3 = landing_value
	var space := get_world_3d().direct_space_state
	var down := PhysicsRayQueryParameters3D.create(landing + Vector3.UP * 1.5, landing - Vector3.UP * 1.5, 1)
	down.exclude = [racer.get_rid()]
	var floor_hit: Dictionary = space.intersect_ray(down)
	if floor_hit.is_empty():
		return false
	var head := PhysicsRayQueryParameters3D.create(landing + Vector3.UP * 0.9, landing + Vector3.UP * 2.4, 1)
	head.exclude = [racer.get_rid()]
	return space.intersect_ray(head).is_empty()

func _advance_traversal(racer_id: int, delta: float) -> float:
	var elapsed: float = float(_traversal_elapsed_by_id.get(racer_id, 0.0)) + delta
	_traversal_elapsed_by_id[racer_id] = elapsed
	var duration: float = maxf(0.01, float(_traversal_duration_by_id.get(racer_id, 0.01)))
	return clampf(elapsed / duration, 0.0, 1.0)

func _path_length(path: Array) -> float:
	var total: float = 0.0
	for i: int in range(1, path.size()):
		if path[i - 1] is Vector3 and path[i] is Vector3:
			total += (path[i] as Vector3).distance_to(path[i - 1] as Vector3)
	return total

func _point_on_path(path: Array, ratio: float) -> Vector3:
	if path.is_empty():
		return Vector3.ZERO
	if path.size() == 1 or not (path[0] is Vector3):
		return path[0] if path[0] is Vector3 else Vector3.ZERO
	var total: float = _path_length(path)
	if total <= 0.001:
		return path[path.size() - 1] if path[path.size() - 1] is Vector3 else Vector3.ZERO
	var target_distance: float = total * clampf(ratio, 0.0, 1.0)
	var walked: float = 0.0
	for i: int in range(1, path.size()):
		if not (path[i - 1] is Vector3) or not (path[i] is Vector3):
			continue
		var a: Vector3 = path[i - 1]
		var b: Vector3 = path[i]
		var segment: float = a.distance_to(b)
		if walked + segment >= target_distance:
			var local_t: float = 0.0 if segment <= 0.001 else (target_distance - walked) / segment
			return a.lerp(b, local_t)
		walked += segment
	return path[path.size() - 1] if path[path.size() - 1] is Vector3 else Vector3.ZERO

func _restore_recovery_collision(racer: WildDashCharacterController) -> void:
	if racer == null:
		return
	var racer_id: int = racer.get_instance_id()
	if _saved_collision_mask_by_id.has(racer_id):
		racer.collision_mask = int(_saved_collision_mask_by_id[racer_id])
	else:
		racer.collision_mask = 3

func _start_checkpoint_fallback(racer: WildDashCharacterController, reason: String) -> void:
	_restore_recovery_collision(racer)
	super(racer, reason)

func _log_congestion(racer: WildDashCharacterController, target: String) -> void:
	var nearby: int = 0
	for value: Variant in RaceManager.racers:
		var other := value as WildDashCharacterController
		if other == null or not is_instance_valid(other):
			continue
		if other.global_position.distance_to(racer.global_position) <= 5.0:
			nearby += 1
	if nearby >= 3:
		print("LOGSPIRE RECOVERY CONGESTION target=%s racers=%d collision_relief=true" % [target, nearby])

func _clear_v8_runtime(racer_id: int) -> void:
	_traversal_kind_by_id.erase(racer_id)
	_traversal_elapsed_by_id.erase(racer_id)
	_traversal_duration_by_id.erase(racer_id)
	_traversal_from_by_id.erase(racer_id)
	_traversal_to_by_id.erase(racer_id)
	_traversal_path_by_id.erase(racer_id)
	_saved_collision_mask_by_id.erase(racer_id)
	_water_input_log_elapsed_by_id.erase(racer_id)
