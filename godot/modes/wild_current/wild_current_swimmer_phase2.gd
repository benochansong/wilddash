class_name WildCurrentSwimmerPhase2
extends "res://modes/wild_current/wild_current_swimmer.gd"

## Round 5 Phase 2 competition layer.
## Keeps Phase 1 water locomotion intact while adding skill-based AI steering,
## shared wake drafting, light animal swim personality and non-teleport stuck
## recovery. Pack roles never change max speed directly.

const STUCK_PROBE_INTERVAL: float = 0.75
const STUCK_STEER_SECONDS: float = 1.35
const STUCK_REACQUIRE_SECONDS: float = 2.25
const DRAFT_ACCEL_SCALE: float = 1.06
const MAX_DRAFT_SPEED_BONUS: float = 0.62
const WATER_COMBAT_PUSH_DECAY: float = 9.5
const WATER_COMBAT_PUSH_MAX: float = 11.5

var pack_role: StringName = &"PLAYER"
var ai_slot: int = -1
var steering_accuracy: float = 0.72
var current_selection: float = 0.72
var burst_timing: float = 0.72
var dive_timing: float = 0.72
var obstacle_avoidance: float = 0.72
var whirlpool_avoidance: float = 0.72
var racing_line_quality: float = 0.72

var _turn_personality_scale: float = 1.0
var _momentum_scale: float = 1.0
var _lateral_current_scale: float = 1.0
var _dive_recharge_scale: float = 1.0
var _draft_active: bool = false
var _draft_leader_label: String = ""
var _stroke_timer: float = 0.48
var _progress_probe_timer: float = 0.0
var _last_progress_probe: float = 0.0
var _stuck_seconds: float = 0.0
var _recovery_steer: float = 0.0
var _reacquire_logged: bool = false
var _last_ai_line: StringName = &""
var _water_combat_push_velocity: Vector3 = Vector3.ZERO

func configure_competition(role: StringName, profile: Dictionary, slot: int) -> void:
	pack_role = role
	ai_slot = slot
	steering_accuracy = clampf(float(profile.get("steering_accuracy", 0.72)), 0.35, 0.96)
	current_selection = clampf(float(profile.get("current_selection", 0.72)), 0.35, 0.96)
	burst_timing = clampf(float(profile.get("burst_timing", 0.72)), 0.35, 0.96)
	dive_timing = clampf(float(profile.get("dive_timing", 0.72)), 0.35, 0.96)
	obstacle_avoidance = clampf(float(profile.get("obstacle_avoidance", 0.72)), 0.35, 0.96)
	whirlpool_avoidance = clampf(float(profile.get("whirlpool_avoidance", 0.72)), 0.35, 0.96)
	racing_line_quality = clampf(float(profile.get("racing_line_quality", 0.72)), 0.35, 0.96)
	_apply_animal_swim_personality()
	if racer != null:
		_last_progress_probe = RaceManager.get_track_progress(racer)

func _apply_animal_swim_personality() -> void:
	if racer == null:
		return
	# Deliberately bounded to roughly +/- 5-8 percent. No animal receives a raw
	# universal speed multiplier, so current choice and race craft remain primary.
	match racer.animal_id:
		&"bear":
			_momentum_scale = 1.06
			_turn_personality_scale = 0.94
		&"rabbit":
			_momentum_scale = 0.97
			_turn_personality_scale = 1.06
		&"elephant":
			_lateral_current_scale = 0.94
			_momentum_scale = 1.04
		&"monkey":
			_dive_recharge_scale = 0.94
			_turn_personality_scale = 1.03
		&"cat":
			_turn_personality_scale = 1.07
		&"fox":
			_turn_personality_scale = 1.02
		_:
			pass

func _process_player_swim(delta: float) -> void:
	var steer := InputManager.get_steer_axis()
	var throttle := InputManager.get_throttle_axis()
	racer.rotate_y(-steer * TURN_RESPONSE * _turn_personality_scale * delta)

	var shift_down := Input.is_physical_key_pressed(KEY_SHIFT)
	var shift_edge := shift_down and not _shift_was_down
	_shift_was_down = shift_down
	if shift_edge:
		_try_swim_burst()
	if InputManager.consume_jump():
		_try_dive_burst()

	var throttle01 := clampf(throttle, 0.0, 1.0)
	var target_speed := lerpf(BASE_SWIM_SPEED, max_swim_speed, throttle01)
	if throttle < -0.05:
		target_speed = MIN_SWIM_SPEED
	_apply_swim_motion(delta, target_speed)
	_update_swim_stroke_audio(delta)

func _process_ai_swim(delta: float) -> void:
	if route.size() < 2:
		_apply_swim_motion(delta, cruise_swim_speed)
		return

	_route_index = clampi(_route_index, 1, route.size() - 1)
	var target := route[_route_index]
	var target_x := target.x + lane_offset
	if provider != null and provider.has_method("get_ai_line_target_x"):
		target_x = float(provider.call(
			"get_ai_line_target_x",
			racer,
			lane_offset,
			pack_role,
			current_selection,
			racing_line_quality,
		))
	target.x = target_x + _recovery_steer

	var planar := target - racer.global_position
	planar.y = 0.0
	if planar.length() <= AI_TARGET_REACHED and _route_index < route.size() - 1:
		_route_index += 1
		target = route[_route_index]
		target_x = target.x + lane_offset
		if provider != null and provider.has_method("get_ai_line_target_x"):
			target_x = float(provider.call(
				"get_ai_line_target_x",
				racer,
				lane_offset,
				pack_role,
				current_selection,
				racing_line_quality,
			))
		target.x = target_x + _recovery_steer
		planar = target - racer.global_position
		planar.y = 0.0

	if planar.length_squared() > 0.001:
		var desired_yaw := atan2(-planar.normalized().x, -planar.normalized().z)
		var steering_response := TURN_RESPONSE * (1.10 + steering_accuracy * 0.34) * _turn_personality_scale
		racer.rotation.y = lerp_angle(racer.rotation.y, desired_yaw, clampf(steering_response * delta, 0.0, 1.0))

	_ai_burst_clock += delta
	var strategic_burst := false
	if provider != null and provider.has_method("should_ai_burst_phase2"):
		strategic_burst = bool(provider.call(
			"should_ai_burst_phase2",
			racer,
			pack_role,
			burst_timing,
			_ai_burst_clock,
		))
	var adaptive_period := lerpf(8.2, 6.2, burst_timing)
	if (strategic_burst or _ai_burst_clock >= adaptive_period) and _burst_cooldown <= 0.0:
		_ai_burst_clock = 0.0
		_try_swim_burst()

	if _dive_cooldown <= 0.0 and provider != null:
		var should_dive := false
		if provider.has_method("should_ai_dive_for_profile"):
			should_dive = bool(provider.call(
				"should_ai_dive_for_profile",
				racer.global_position,
				dive_timing,
				obstacle_avoidance,
			))
		elif provider.has_method("should_ai_dive"):
			should_dive = bool(provider.call("should_ai_dive", racer.global_position))
		if should_dive:
			_try_dive_burst()

	_apply_swim_motion(delta, max_swim_speed * 0.88)
	_update_ai_stuck_recovery(delta)

func _apply_swim_motion(delta: float, requested_speed: float) -> void:
	var speed_target := clampf(requested_speed, MIN_SWIM_SPEED, max_swim_speed)
	if _burst_remaining > 0.0:
		speed_target = max_swim_speed * BURST_SPEED_SCALE

	var draft_bonus := 0.0
	var draft_leader := ""
	var draft_now := false
	if provider != null and provider.has_method("sample_wake_draft"):
		var draft_value: Variant = provider.call("sample_wake_draft", racer)
		if draft_value is Dictionary:
			var draft: Dictionary = draft_value
			draft_now = bool(draft.get("active", false))
			draft_bonus = clampf(float(draft.get("speed_bonus", 0.0)), 0.0, MAX_DRAFT_SPEED_BONUS)
			draft_leader = str(draft.get("leader", ""))
	_update_draft_telemetry(draft_now, draft_leader)
	speed_target += draft_bonus

	var accel := SWIM_ACCELERATION if speed_target >= _swim_speed else SWIM_DECELERATION
	if draft_now and speed_target >= _swim_speed:
		accel *= DRAFT_ACCEL_SCALE
	_swim_speed = move_toward(_swim_speed, speed_target, accel * delta)

	var forward := -racer.global_transform.basis.z
	forward.y = 0.0
	forward = Vector3.FORWARD if forward.length_squared() <= 0.001 else forward.normalized()
	var water_force := Vector3.ZERO
	if provider != null and provider.has_method("sample_water_force"):
		var sampled: Variant = provider.call("sample_water_force", racer.global_position, _burst_remaining > 0.0, _dive_remaining > 0.0)
		if sampled is Vector3:
			water_force = sampled
	water_force.x *= _lateral_current_scale

	_water_combat_push_velocity = _water_combat_push_velocity.move_toward(Vector3.ZERO, WATER_COMBAT_PUSH_DECAY * delta)
	var desired_planar := forward * _swim_speed + water_force + _water_combat_push_velocity
	var current_planar := Vector3(racer.velocity.x, 0.0, racer.velocity.z)
	var drag_response := WATER_DRAG_RESPONSE / _momentum_scale
	var blended := current_planar.lerp(desired_planar, clampf(drag_response * delta, 0.0, 0.32))
	racer.velocity.x = blended.x
	racer.velocity.z = blended.z

	var target_y := DIVE_Y if _dive_remaining > 0.0 else SURFACE_Y
	var desired_vertical := clampf((target_y - racer.global_position.y) * BUOYANCY_RESPONSE, -MAX_VERTICAL_SPEED, MAX_VERTICAL_SPEED)
	racer.velocity.y = move_toward(racer.velocity.y, desired_vertical, BUOYANCY_RESPONSE * delta)
	racer.move_and_slide()

	if racer.has_blocking_collision():
		_swim_speed = maxf(MIN_SWIM_SPEED, _swim_speed * 0.78)
		if not player_controlled:
			var escape_sign := -1.0 if ((ai_slot + _route_index) % 2 == 0) else 1.0
			racer.rotate_y(escape_sign * (0.10 + obstacle_avoidance * 0.12))
	racer.current_speed = Vector2(racer.velocity.x, racer.velocity.z).length()

func apply_water_combat_push(direction: Vector3, strength: float, speed_retention: float = 0.82) -> bool:
	if racer == null or racer.finished:
		return false
	var planar := Vector3(direction.x, 0.0, direction.z)
	if planar.length_squared() <= 0.0001:
		return false
	var impulse := planar.normalized() * clampf(strength, 0.0, WATER_COMBAT_PUSH_MAX)
	_water_combat_push_velocity += impulse
	if _water_combat_push_velocity.length() > WATER_COMBAT_PUSH_MAX:
		_water_combat_push_velocity = _water_combat_push_velocity.normalized() * WATER_COMBAT_PUSH_MAX
	# Immediate kick plus persistent water-drift component. This is intentionally
	# handled by the Round 5 swimmer because land CharacterController physics is
	# disabled while WILD CURRENT is active.
	racer.velocity.x += impulse.x * 0.58
	racer.velocity.z += impulse.z * 0.58
	_swim_speed = maxf(MIN_SWIM_SPEED, _swim_speed * clampf(speed_retention, 0.65, 1.0))
	print("r5_water_combat_push racer=%s strength=%.2f retention=%.2f diving=%s" % [
		RaceManager.get_racer_label(racer), strength, speed_retention, str(is_diving()),
	])
	return true

func _try_swim_burst() -> void:
	if _burst_cooldown > 0.0 or racer == null:
		return
	_burst_remaining = BURST_DURATION
	_burst_cooldown = BURST_COOLDOWN
	print("r5_swim_burst racer=%s animal=%s cooldown=%.1f pack=%s" % [
		RaceManager.get_racer_label(racer), String(racer.animal_id), BURST_COOLDOWN, String(pack_role),
	])
	_emit_audio_hook(&"swim_burst")

func _try_dive_burst() -> void:
	if _dive_cooldown > 0.0 or racer == null:
		return
	_dive_remaining = DIVE_DURATION
	_dive_cooldown = DIVE_COOLDOWN * _dive_recharge_scale
	print("r5_dive_burst racer=%s animal=%s recovery_to_surface=true pack=%s recharge_scale=%.2f" % [
		RaceManager.get_racer_label(racer), String(racer.animal_id), String(pack_role), _dive_recharge_scale,
	])
	_emit_audio_hook(&"dive")

func _update_environment_telemetry() -> void:
	if provider == null or racer == null:
		return
	var current_label: StringName = &""
	if provider.has_method("current_label_at"):
		current_label = StringName(provider.call("current_label_at", racer.global_position))
	if current_label != _active_current:
		if _active_current != &"":
			print("r5_current_exit racer=%s current=%s" % [RaceManager.get_racer_label(racer), String(_active_current)])
		if current_label != &"":
			print("r5_current_enter racer=%s current=%s" % [RaceManager.get_racer_label(racer), String(current_label)])
			if current_label in [&"FAST", &"RAPID"]:
				_emit_audio_hook(&"current_fast")
		_active_current = current_label

	var in_whirlpool := false
	if provider.has_method("is_in_whirlpool"):
		in_whirlpool = bool(provider.call("is_in_whirlpool", racer.global_position))
	if in_whirlpool and not _inside_whirlpool:
		print("r5_whirlpool_enter racer=%s" % RaceManager.get_racer_label(racer))
		_emit_audio_hook(&"whirlpool")
	elif not in_whirlpool and _inside_whirlpool:
		print("r5_whirlpool_escape racer=%s" % RaceManager.get_racer_label(racer))
	_inside_whirlpool = in_whirlpool

func note_ai_line(line_id: StringName) -> void:
	if player_controlled or line_id == _last_ai_line:
		return
	_last_ai_line = line_id
	print("r5_ai_current_choice racer=%s pack=%s choice=%s current_skill=%.2f line_skill=%.2f" % [
		RaceManager.get_racer_label(racer), String(pack_role), String(line_id), current_selection, racing_line_quality,
	])

func get_pack_role() -> StringName:
	return pack_role

func is_bursting() -> bool:
	return _burst_remaining > 0.0

func get_stuck_seconds() -> float:
	return _stuck_seconds

func _update_draft_telemetry(active_now: bool, leader_label: String) -> void:
	if active_now == _draft_active and (not active_now or leader_label == _draft_leader_label):
		return
	if _draft_active:
		print("r5_draft_exit racer=%s leader=%s" % [RaceManager.get_racer_label(racer), _draft_leader_label])
	if active_now:
		print("r5_draft_enter racer=%s leader=%s shared_physics=true" % [RaceManager.get_racer_label(racer), leader_label])
	_draft_active = active_now
	_draft_leader_label = leader_label

func _update_swim_stroke_audio(delta: float) -> void:
	if not player_controlled:
		return
	_stroke_timer -= delta
	if _stroke_timer > 0.0 or racer.current_speed < 4.8 or _dive_remaining > 0.0:
		return
	_stroke_timer = 0.68
	_emit_audio_hook(&"swim_stroke")

func _emit_audio_hook(event_id: StringName) -> void:
	if provider != null and provider.has_method("emit_swim_audio"):
		provider.call("emit_swim_audio", racer, event_id)

func _update_ai_stuck_recovery(delta: float) -> void:
	if player_controlled or racer == null:
		return
	_progress_probe_timer += delta
	if _progress_probe_timer < STUCK_PROBE_INTERVAL:
		return
	_progress_probe_timer = 0.0
	var progress_now := RaceManager.get_track_progress(racer)
	var gained := progress_now - _last_progress_probe
	_last_progress_probe = progress_now
	if gained < 0.42 and racer.current_speed < 3.1:
		_stuck_seconds += STUCK_PROBE_INTERVAL
	else:
		_stuck_seconds = maxf(0.0, _stuck_seconds - STUCK_PROBE_INTERVAL * 1.5)
		_recovery_steer = move_toward(_recovery_steer, 0.0, 1.8)
		_reacquire_logged = false
		return

	if _stuck_seconds >= STUCK_STEER_SECONDS:
		var sign_value := -1.0 if ((ai_slot + _route_index) % 2 == 0) else 1.0
		_recovery_steer = sign_value * lerpf(1.6, 3.2, obstacle_avoidance)
	if _stuck_seconds >= STUCK_REACQUIRE_SECONDS:
		_reacquire_route()
		if not _reacquire_logged:
			_reacquire_logged = true
			print("r5_ai_route_reacquire racer=%s pack=%s stuck=%.2f teleport=false" % [
				RaceManager.get_racer_label(racer), String(pack_role), _stuck_seconds,
			])

func _reacquire_route() -> void:
	if route.size() < 2 or racer == null:
		return
	var nearest_index := _route_index
	var nearest_distance := INF
	for index in range(1, route.size()):
		var distance := racer.global_position.distance_squared_to(route[index])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	_route_index = clampi(maxi(_route_index, nearest_index), 1, route.size() - 1)