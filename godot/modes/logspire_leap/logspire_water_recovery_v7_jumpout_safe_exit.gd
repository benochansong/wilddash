extends "res://modes/logspire_leap/logspire_water_recovery_v6_nearest_ladder.gd"

## Recovery priority pass:
## 1) low jump-out, 2) root ramp, 3) ladder, 4) abnormal fallback only.
## Ladder finishes use audited safe exits and grant a short no-knockback window.

const MAX_JUMP_OUT_HEIGHT: float = 1.70
const JUMP_OUT_GUIDANCE_RADIUS: float = 7.5
const AI_JUMP_OUT_TRIGGER_RADIUS: float = 3.0
const RAMP_GUIDANCE_RADIUS: float = 9.0
const RAMP_ATTACH_RADIUS: float = 3.25
const RECOVERY_PROTECTION_SECONDS: float = 0.75
const SECOND_FALL_WINDOW_SECONDS: float = 3.0
const JUMP_OUT_UP_SCALE: float = 0.92
const JUMP_OUT_SPEED_SCALE: float = 0.72

var _recent_recovery_until_by_id: Dictionary = {}

func _enter_water(racer: WildDashCharacterController, zone: int, water_y: float) -> void:
	if racer != null and is_instance_valid(racer):
		var racer_id: int = racer.get_instance_id()
		var now: float = Time.get_ticks_msec() * 0.001
		if now <= float(_recent_recovery_until_by_id.get(racer_id, -1.0)):
			print("LOGSPIRE RECOVERY SECOND FALL racer=%s zone=%d within=%.1fs" % [
				RaceManager.get_racer_label(racer), zone + 1, SECOND_FALL_WINDOW_SECONDS,
			])
	super(racer, zone, water_y)

func _update_swimming(racer: WildDashCharacterController, delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	_cancel_stale_checkpoint_recovery(racer)
	var racer_id: int = racer.get_instance_id()
	var zone: int = int(_zone_by_id.get(racer_id, 0))
	var water_y: float = float(_water_y_by_id.get(racer_id, racer.global_position.y))
	var controlled_by_player: bool = racer.is_player and DisplayServer.get_name() != "headless"
	var jump_out: Dictionary = _nearest_recovery_entry(racer, "get_jump_outs_for_zone", zone, JUMP_OUT_GUIDANCE_RADIUS)
	if not jump_out.is_empty() and float(jump_out.get("height", 99.0)) <= MAX_JUMP_OUT_HEIGHT:
		var jump_distance: float = _entry_distance(racer, jump_out)
		if controlled_by_player:
			_set_hud_message("RECOVERY ROUTE · JUMP BACK UP! · SPACE")
			if Input.is_action_just_pressed("jump"):
				_perform_jump_out(racer, jump_out, water_y)
				return
			_apply_manual_recovery_swim(racer, water_y, delta)
			return
		if jump_distance <= AI_JUMP_OUT_TRIGGER_RADIUS:
			_perform_jump_out(racer, jump_out, water_y)
			return
		_apply_ai_recovery_swim(racer, jump_out, water_y, delta)
		return

	var ramp: Dictionary = _nearest_recovery_entry(racer, "get_root_ramps_for_zone", zone, RAMP_GUIDANCE_RADIUS)
	if not ramp.is_empty():
		var ramp_distance: float = _entry_distance(racer, ramp)
		if ramp_distance <= RAMP_ATTACH_RADIUS:
			_finish_to_root_ramp(racer, ramp)
			return
		if controlled_by_player:
			_set_hud_message("RECOVERY ROUTE · FOLLOW THE ROOT")
			_apply_manual_recovery_swim(racer, water_y, delta)
		else:
			_apply_ai_recovery_swim(racer, ramp, water_y, delta)
		return

	super(racer, delta)

func _perform_jump_out(racer: WildDashCharacterController, entry: Dictionary, water_y: float) -> void:
	var racer_id: int = racer.get_instance_id()
	var landing_value: Variant = entry.get("landing", racer.global_position + Vector3.UP * 1.2)
	var landing: Vector3 = landing_value if landing_value is Vector3 else racer.global_position + Vector3.UP * 1.2
	var to_landing := landing - racer.global_position
	to_landing.y = 0.0
	if to_landing.length_squared() <= 0.001:
		to_landing = -racer.global_transform.basis.z
	else:
		to_landing = to_landing.normalized()
	racer.rotation.y = atan2(-to_landing.x, -to_landing.z)
	_release_racer_control(racer)
	_state_by_id[racer_id] = WaterState.RACING
	racer.set_meta(WATER_META, false)
	var position := racer.global_position
	position.y = water_y + 0.58
	racer.global_position = position
	racer.current_speed = maxf(racer.cruise_speed * JUMP_OUT_SPEED_SCALE, 4.8)
	racer.velocity = to_landing * racer.current_speed
	racer.velocity.y = maxf(6.2, racer.jump_velocity * JUMP_OUT_UP_SCALE)
	_apply_recovery_protection(racer)
	_notify_platform_ai_recovered(racer)
	var platform_id := StringName(entry.get("platform_id", &""))
	if racer.is_player and DisplayServer.get_name() != "headless":
		_set_hud_message("JUMP OUT! · BACK TO THE RACE")
	print("LOGSPIRE WATER JUMP OUT racer=%s zone=%d platform=%s max_height=%.2f impulse=%.2f" % [
		RaceManager.get_racer_label(racer), int(entry.get("zone", 0)) + 1, String(platform_id), MAX_JUMP_OUT_HEIGHT, racer.velocity.y,
	])
	water_recovered.emit(racer, platform_id)
	_clear_water_runtime(racer_id)

func _finish_to_root_ramp(racer: WildDashCharacterController, ramp: Dictionary) -> void:
	var racer_id: int = racer.get_instance_id()
	var entry_value: Variant = ramp.get("entry", racer.global_position)
	var exit_value: Variant = ramp.get("exit", racer.global_position + Vector3.FORWARD)
	var entry_position: Vector3 = entry_value if entry_value is Vector3 else racer.global_position
	var exit_position: Vector3 = exit_value if exit_value is Vector3 else entry_position + Vector3.FORWARD
	var direction := exit_position - entry_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		direction = Vector3.FORWARD
	else:
		direction = direction.normalized()
	# Short capture onto the first broad root step; traversal itself remains under
	# normal racer/AI control rather than teleporting to the route platform.
	racer.reset_motion(entry_position)
	racer.rotation.y = atan2(-direction.x, -direction.z)
	racer.current_speed = maxf(4.6, racer.cruise_speed * 0.58)
	_release_racer_control(racer)
	_state_by_id[racer_id] = WaterState.RACING
	racer.set_meta(WATER_META, false)
	_apply_recovery_protection(racer)
	_notify_platform_ai_recovered(racer)
	var platform_id := StringName(ramp.get("platform_id", &""))
	if racer.is_player and DisplayServer.get_name() != "headless":
		_set_hud_message("FOLLOW THE ROOT · BACK TO THE COURSE")
	print("LOGSPIRE ROOT RAMP EXIT racer=%s zone=%d platform=%s checkpoint_restart=false" % [
		RaceManager.get_racer_label(racer), int(ramp.get("zone", 0)) + 1, String(platform_id),
	])
	water_recovered.emit(racer, platform_id)
	_clear_water_runtime(racer_id)

func _finish_water_recovery(racer: WildDashCharacterController) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	_cancel_stale_checkpoint_recovery(racer)
	var racer_id: int = racer.get_instance_id()
	var ladder_value: Variant = _ladder_by_id.get(racer_id, {})
	var ladder: Dictionary = ladder_value if ladder_value is Dictionary else {}
	var exit_value: Variant = ladder.get("safe_exit", ladder.get("exit", racer.global_position))
	var exit_position: Vector3 = exit_value if exit_value is Vector3 else racer.global_position
	racer.reset_motion(exit_position)
	var platform_id := StringName(ladder.get("platform_id", &""))
	var platform_value: Variant = _graph.call("get_platform_position", platform_id)
	if platform_value is Vector3:
		var toward_route: Vector3 = platform_value - exit_position
		toward_route.y = 0.0
		if toward_route.length_squared() > 0.001:
			toward_route = toward_route.normalized()
			racer.rotation.y = atan2(-toward_route.x, -toward_route.z)
	racer.current_speed = maxf(racer.cruise_speed * 0.58, 4.4)
	_release_racer_control(racer)
	_state_by_id[racer_id] = WaterState.RACING
	racer.set_meta(WATER_META, false)
	_water_recoveries += 1
	_apply_recovery_protection(racer)
	var recovery_time: float = float(_water_elapsed_by_id.get(racer_id, 0.0)) + float(_climb_duration_by_id.get(racer_id, LADDER_CLIMB_SECONDS))
	_notify_platform_ai_recovered(racer)
	if racer.is_player and DisplayServer.get_name() != "headless":
		_set_hud_message("SAFE DECK! · BACK TO THE RACE")
	print("LOGSPIRE LADDER SAFE EXIT racer=%s zone=%d platform=%s edge_margin=%.2fm protection=%.2fs" % [
		RaceManager.get_racer_label(racer), int(ladder.get("zone", 0)) + 1, String(platform_id), float(ladder.get("edge_margin", 0.0)), RECOVERY_PROTECTION_SECONDS,
	])
	print("LOGSPIRE WATER RECOVERY racer=%s recovery_time=%.2f ladder=%s total=%d" % [
		RaceManager.get_racer_label(racer), recovery_time, String(ladder.get("id", &"")), _water_recoveries,
	])
	water_recovered.emit(racer, platform_id)
	_clear_water_runtime(racer_id)

func _nearest_recovery_entry(racer: WildDashCharacterController, method_name: String, zone: int, max_distance: float) -> Dictionary:
	if racer == null or _ladder_system == null or not _ladder_system.has_method(method_name):
		return {}
	var candidates_value: Variant = _ladder_system.call(method_name, zone)
	if not (candidates_value is Array):
		return {}
	var best: Dictionary = {}
	var best_distance: float = max_distance
	for value: Variant in candidates_value:
		if not (value is Dictionary):
			continue
		var candidate: Dictionary = value
		var distance: float = _entry_distance(racer, candidate)
		if distance <= best_distance:
			best_distance = distance
			best = candidate
	return best

func _entry_distance(racer: WildDashCharacterController, entry: Dictionary) -> float:
	var entry_value: Variant = entry.get("entry", racer.global_position)
	if not (entry_value is Vector3):
		return INF
	var point: Vector3 = entry_value
	return Vector2(racer.global_position.x - point.x, racer.global_position.z - point.z).length()

func _apply_manual_recovery_swim(racer: WildDashCharacterController, water_y: float, delta: float) -> void:
	var racer_id: int = racer.get_instance_id()
	var direction: Vector3 = _swim.call("get_player_direction")
	_swim.call("apply_swim", racer, direction, water_y, delta)
	_water_elapsed_by_id[racer_id] = float(_water_elapsed_by_id.get(racer_id, 0.0)) + delta

func _apply_ai_recovery_swim(racer: WildDashCharacterController, target: Dictionary, water_y: float, delta: float) -> void:
	var racer_id: int = racer.get_instance_id()
	var entry_value: Variant = target.get("entry", racer.global_position)
	var point: Vector3 = entry_value if entry_value is Vector3 else racer.global_position
	var direction := point - racer.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		direction = direction.normalized()
	_swim.call("apply_swim", racer, direction, water_y, delta)
	_water_elapsed_by_id[racer_id] = float(_water_elapsed_by_id.get(racer_id, 0.0)) + delta

func _apply_recovery_protection(racer: WildDashCharacterController) -> void:
	if racer == null:
		return
	var now: float = Time.get_ticks_msec() * 0.001
	racer.set_meta(&"logspire_recovery_protection_until", now + RECOVERY_PROTECTION_SECONDS)
	_recent_recovery_until_by_id[racer.get_instance_id()] = now + SECOND_FALL_WINDOW_SECONDS
