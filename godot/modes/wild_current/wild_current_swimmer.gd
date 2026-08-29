class_name WildCurrentSwimmer
extends Node

## Round 5-only water locomotion layer.
## It deliberately disables the shared racer's land physics loop and reuses the
## CharacterBody3D, visual, stats and RaceManager identity without land/jump
## movement. Player and AI obey the same buoyancy/current/collision rules.

const SURFACE_Y: float = 0.58
const DIVE_Y: float = -1.05
const BASE_SWIM_SPEED: float = 6.2
const MIN_SWIM_SPEED: float = 3.0
const SWIM_ACCELERATION: float = 8.8
const SWIM_DECELERATION: float = 6.2
const WATER_DRAG_RESPONSE: float = 4.3
const TURN_RESPONSE: float = 2.25
const BUOYANCY_RESPONSE: float = 8.5
const MAX_VERTICAL_SPEED: float = 4.2
const BURST_DURATION: float = 0.85
const BURST_COOLDOWN: float = 3.8
const BURST_SPEED_SCALE: float = 1.30
const DIVE_DURATION: float = 0.82
const DIVE_COOLDOWN: float = 1.65
const AI_TARGET_REACHED: float = 8.0

var racer: WildDashCharacterController
var provider: Node
var route: Array[Vector3] = []
var player_controlled: bool = false
var lane_offset: float = 0.0
var max_swim_speed: float = 12.0
var cruise_swim_speed: float = 8.2
var _swim_speed: float = 0.0
var _burst_remaining: float = 0.0
var _burst_cooldown: float = 0.0
var _dive_remaining: float = 0.0
var _dive_cooldown: float = 0.0
var _shift_was_down: bool = false
var _route_index: int = 1
var _ai_burst_clock: float = 0.0
var _ai_burst_period: float = 8.0
var _active_current: StringName = &""
var _inside_whirlpool: bool = false

func configure(
	controlled_racer: WildDashCharacterController,
	water_provider: Node,
	route_points: Array[Vector3],
	is_player_swimmer: bool,
	ai_lane_offset: float = 0.0,
) -> void:
	racer = controlled_racer
	provider = water_provider
	route = route_points.duplicate()
	player_controlled = is_player_swimmer
	lane_offset = ai_lane_offset
	if racer == null:
		return
	max_swim_speed = clampf(racer.max_speed * 0.82, 10.4, 13.6)
	cruise_swim_speed = clampf(racer.cruise_speed * 0.92, 7.2, 9.4)
	_swim_speed = BASE_SWIM_SPEED
	_ai_burst_period = 7.2 + float(racer.get_instance_id() % 7) * 0.35
	# The shared controller owns land gravity/jump. Round 5 replaces that loop
	# with this water-only driver while preserving the same CharacterBody3D.
	racer.set_physics_process(false)
	racer.floor_snap_length = 0.0
	racer.velocity = Vector3.ZERO
	racer.current_speed = _swim_speed

func _physics_process(delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	_burst_remaining = maxf(0.0, _burst_remaining - delta)
	_burst_cooldown = maxf(0.0, _burst_cooldown - delta)
	_dive_remaining = maxf(0.0, _dive_remaining - delta)
	_dive_cooldown = maxf(0.0, _dive_cooldown - delta)

	if racer.finished:
		_coast_finished(delta)
		_sync_visual()
		return
	if not RaceManager.active:
		_hold_on_surface(delta)
		_sync_visual()
		return

	if player_controlled:
		_process_player_swim(delta)
	else:
		_process_ai_swim(delta)
	_update_environment_telemetry()
	_sync_visual()

func _process_player_swim(delta: float) -> void:
	var steer := InputManager.get_steer_axis()
	var throttle := InputManager.get_throttle_axis()
	racer.rotate_y(-steer * TURN_RESPONSE * delta)

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

func _process_ai_swim(delta: float) -> void:
	if route.size() < 2:
		_apply_swim_motion(delta, cruise_swim_speed)
		return
	_route_index = clampi(_route_index, 1, route.size() - 1)
	var target := route[_route_index]
	target.x += lane_offset
	var planar := target - racer.global_position
	planar.y = 0.0
	if planar.length() <= AI_TARGET_REACHED and _route_index < route.size() - 1:
		_route_index += 1
		target = route[_route_index]
		target.x += lane_offset
		planar = target - racer.global_position
		planar.y = 0.0
	if planar.length_squared() > 0.001:
		var desired_yaw := atan2(-planar.normalized().x, -planar.normalized().z)
		racer.rotation.y = lerp_angle(racer.rotation.y, desired_yaw, clampf(TURN_RESPONSE * 1.35 * delta, 0.0, 1.0))

	_ai_burst_clock += delta
	if _ai_burst_clock >= _ai_burst_period and _burst_cooldown <= 0.0:
		_ai_burst_clock = 0.0
		_try_swim_burst()
	if provider != null and provider.has_method("should_ai_dive") and _dive_cooldown <= 0.0:
		var should_dive: bool = bool(provider.call("should_ai_dive", racer.global_position))
		if should_dive:
			_try_dive_burst()
	_apply_swim_motion(delta, max_swim_speed * 0.88)

func _apply_swim_motion(delta: float, requested_speed: float) -> void:
	var speed_target := clampf(requested_speed, MIN_SWIM_SPEED, max_swim_speed)
	if _burst_remaining > 0.0:
		speed_target = max_swim_speed * BURST_SPEED_SCALE
	var accel := SWIM_ACCELERATION if speed_target >= _swim_speed else SWIM_DECELERATION
	_swim_speed = move_toward(_swim_speed, speed_target, accel * delta)

	var forward := -racer.global_transform.basis.z
	forward.y = 0.0
	forward = Vector3.FORWARD if forward.length_squared() <= 0.001 else forward.normalized()
	var water_force := Vector3.ZERO
	if provider != null and provider.has_method("sample_water_force"):
		var sampled: Variant = provider.call("sample_water_force", racer.global_position, _burst_remaining > 0.0, _dive_remaining > 0.0)
		if sampled is Vector3:
			water_force = sampled

	var desired_planar := forward * _swim_speed + water_force
	var current_planar := Vector3(racer.velocity.x, 0.0, racer.velocity.z)
	var blended := current_planar.lerp(desired_planar, clampf(WATER_DRAG_RESPONSE * delta, 0.0, 0.32))
	racer.velocity.x = blended.x
	racer.velocity.z = blended.z

	var target_y := DIVE_Y if _dive_remaining > 0.0 else SURFACE_Y
	var desired_vertical := clampf((target_y - racer.global_position.y) * BUOYANCY_RESPONSE, -MAX_VERTICAL_SPEED, MAX_VERTICAL_SPEED)
	racer.velocity.y = move_toward(racer.velocity.y, desired_vertical, BUOYANCY_RESPONSE * delta)
	racer.move_and_slide()

	if racer.has_blocking_collision():
		_swim_speed = maxf(MIN_SWIM_SPEED, _swim_speed * 0.76)
		if not player_controlled:
			racer.rotate_y(0.20)
	racer.current_speed = Vector2(racer.velocity.x, racer.velocity.z).length()

func _try_swim_burst() -> void:
	if _burst_cooldown > 0.0 or racer == null:
		return
	_burst_remaining = BURST_DURATION
	_burst_cooldown = BURST_COOLDOWN
	print("r5_swim_burst racer=%s animal=%s cooldown=%.1f" % [
		RaceManager.get_racer_label(racer), String(racer.animal_id), BURST_COOLDOWN,
	])

func _try_dive_burst() -> void:
	if _dive_cooldown > 0.0 or racer == null:
		return
	_dive_remaining = DIVE_DURATION
	_dive_cooldown = DIVE_COOLDOWN
	print("r5_dive_burst racer=%s animal=%s recovery_to_surface=true" % [
		RaceManager.get_racer_label(racer), String(racer.animal_id),
	])

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
		_active_current = current_label

	var in_whirlpool := false
	if provider.has_method("is_in_whirlpool"):
		in_whirlpool = bool(provider.call("is_in_whirlpool", racer.global_position))
	if in_whirlpool and not _inside_whirlpool:
		print("r5_whirlpool_enter racer=%s" % RaceManager.get_racer_label(racer))
	elif not in_whirlpool and _inside_whirlpool:
		print("r5_whirlpool_escape racer=%s" % RaceManager.get_racer_label(racer))
	_inside_whirlpool = in_whirlpool

func force_water_reset(target_position: Vector3) -> void:
	if racer == null:
		return
	var target := target_position
	target.y = SURFACE_Y
	racer.global_position = target
	racer.velocity = Vector3.ZERO
	_swim_speed = BASE_SWIM_SPEED
	_dive_remaining = 0.0
	_inside_whirlpool = false

func get_burst_ready_ratio() -> float:
	if BURST_COOLDOWN <= 0.0:
		return 1.0
	return clampf(1.0 - _burst_cooldown / BURST_COOLDOWN, 0.0, 1.0)

func is_diving() -> bool:
	return _dive_remaining > 0.0

func _hold_on_surface(delta: float) -> void:
	var desired_vertical := clampf((SURFACE_Y - racer.global_position.y) * BUOYANCY_RESPONSE, -MAX_VERTICAL_SPEED, MAX_VERTICAL_SPEED)
	racer.velocity = racer.velocity.move_toward(Vector3(0.0, desired_vertical, 0.0), 8.0 * delta)
	racer.move_and_slide()

func _coast_finished(delta: float) -> void:
	var planar := Vector3(racer.velocity.x, 0.0, racer.velocity.z).move_toward(Vector3.ZERO, 5.0 * delta)
	racer.velocity.x = planar.x
	racer.velocity.z = planar.z
	var desired_vertical := clampf((SURFACE_Y - racer.global_position.y) * BUOYANCY_RESPONSE, -MAX_VERTICAL_SPEED, MAX_VERTICAL_SPEED)
	racer.velocity.y = move_toward(racer.velocity.y, desired_vertical, BUOYANCY_RESPONSE * delta)
	racer.move_and_slide()
	racer.current_speed = planar.length()

func _sync_visual() -> void:
	if racer != null and racer.has_method("_sync_visual"):
		racer.call("_sync_visual")
