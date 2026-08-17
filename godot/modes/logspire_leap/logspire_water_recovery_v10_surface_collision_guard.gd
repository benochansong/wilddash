extends "res://modes/logspire_leap/logspire_water_recovery_v9_priority_camera.gd"

## Player-tested hard guard for water and recovery traversal.
## - submerged racers are reacquired at the visible water surface
## - major world geometry cannot be phased through
## - recovery stairs attach only near the entry and own the full climb
## - blocked recovery routes return to swimming instead of trapping the racer

const SUBMERGED_REACQUIRE_DEPTH: float = 0.35
const SURFACE_LOCK_OFFSET: float = 0.52
const SURFACE_LOCK_TOLERANCE: float = 0.14
const SURFACE_DESCEND_SPEED: float = 6.0
const MAJOR_WORLD_QUERY_MASK: int = 4
const MAJOR_BLOCKED_SCORE_PENALTY: float = 1000.0
const STAIR_AUTO_ATTACH_RADIUS: float = 1.5
const STAIR_CLIMB_SPEED_MPS: float = 3.4
const STAIR_CLIMB_MIN_SECONDS: float = 1.35
const STAIR_CLIMB_MAX_SECONDS: float = 5.0

var _major_blocked_target_by_id: Dictionary = {}
var _surface_reacquire_count: int = 0

func _physics_process(delta: float) -> void:
	super(delta)
	if not _configured or not RaceManager.active:
		return

	for value: Variant in RaceManager.racers.duplicate():
		var racer := value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer.finished:
			continue
		var pool: Dictionary = _pool_for_position(racer.global_position)
		if pool.is_empty():
			continue
		var water_y: float = float(pool.get("water_y", -999.0))
		var racer_id: int = racer.get_instance_id()
		if is_water_recovering(racer):
			var traversal_kind := StringName(_traversal_kind_by_id.get(racer_id, &""))
			if traversal_kind == &"":
				_enforce_surface_lock(racer, water_y, delta)
			continue
		if racer.global_position.y > water_y - SUBMERGED_REACQUIRE_DEPTH:
			continue

		_surface_reacquire_count += 1
		_fall_start_y_by_id[racer_id] = maxf(
			float(_fall_start_y_by_id.get(racer_id, water_y + 1.0)),
			water_y + 1.0
		)
		print("LOGSPIRE WATER SURFACE REACQUIRE racer=%s zone=%d body_y=%.2f water_y=%.2f floor_walk_blocked=true total=%d" % [
			RaceManager.get_racer_label(racer),
			int(pool.get("zone", 0)) + 1,
			racer.global_position.y,
			water_y,
			_surface_reacquire_count,
		])
		_enter_water(racer, int(pool.get("zone", 0)), water_y)
		if is_water_recovering(racer):
			_enforce_surface_lock(racer, water_y, delta)

func _enter_water(racer: WildDashCharacterController, zone: int, water_y: float) -> void:
	if racer != null:
		_major_blocked_target_by_id.erase(racer.get_instance_id())
	super(racer, zone, water_y)
	if racer != null and is_instance_valid(racer) and is_water_recovering(racer):
		_enforce_surface_lock(racer, water_y, 0.0)

func _update_swimming(racer: WildDashCharacterController, delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	var racer_id: int = racer.get_instance_id()
	var zone: int = int(_zone_by_id.get(racer_id, 0))
	var target: Dictionary = _choose_recovery_target(racer, zone)
	if target.is_empty() or StringName(target.get("recovery_type", &"")) != TARGET_ROOT:
		super(racer, delta)
		return

	_cancel_stale_checkpoint_recovery(racer)
	racer.collision_mask = 1
	var water_y: float = float(_water_y_by_id.get(racer_id, racer.global_position.y))
	var controlled_by_player: bool = racer.is_player and DisplayServer.get_name() != "headless"
	var previous_value: Variant = _preferred_target_by_id.get(racer_id, {})
	var previous: Dictionary = previous_value if previous_value is Dictionary else {}
	if _target_signature(previous) != _target_signature(target):
		print("LOGSPIRE RECOVERY TARGET racer=%s from=%s to=%s score=%.2f player_priority=%s" % [
			RaceManager.get_racer_label(racer),
			_target_signature(previous),
			_target_signature(target),
			float(target.get("target_score", 0.0)),
			str(racer.is_player),
		])
	_preferred_target_by_id[racer_id] = target
	_update_recovery_camera_focus(racer, target)
	_set_ux_state(racer, RecoveryUXState.ROOT_APPROACH)
	var target_distance: float = _distance_to_target(racer, target)
	if target_distance <= STAIR_AUTO_ATTACH_RADIUS:
		_begin_root_climb(racer, target)
		return
	if controlled_by_player:
		_set_hud_message("RECOVERY ROUTE · SWIM TO THE STAIRS · %.0fm" % target_distance)
		_apply_manual_recovery_swim(racer, water_y, delta)
	else:
		_apply_ai_recovery_swim(racer, target, water_y, delta)

func _begin_root_climb(racer: WildDashCharacterController, ramp: Dictionary) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	var racer_id: int = racer.get_instance_id()
	print("LOGSPIRE STAIR ATTACH racer=%s target=%s radius=%.1f" % [
		RaceManager.get_racer_label(racer),
		_target_signature(ramp),
		STAIR_AUTO_ATTACH_RADIUS,
	])
	super(racer, ramp)
	var path_value: Variant = _traversal_path_by_id.get(racer_id, [])
	var path: Array = path_value if path_value is Array else []
	var path_length: float = _path_length(path)
	var duration: float = clampf(path_length / STAIR_CLIMB_SPEED_MPS, STAIR_CLIMB_MIN_SECONDS, STAIR_CLIMB_MAX_SECONDS)
	_traversal_duration_by_id[racer_id] = duration
	print("LOGSPIRE STAIR CLIMB racer=%s duration=%.2f speed=%.1f path_points=%d" % [
		RaceManager.get_racer_label(racer),
		duration,
		STAIR_CLIMB_SPEED_MPS,
		path.size(),
	])

func _update_root_climb(racer: WildDashCharacterController, delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	var racer_id: int = racer.get_instance_id()
	var was_stair: bool = StringName(_traversal_kind_by_id.get(racer_id, &"")) == &"root_climb"
	super(racer, delta)
	if was_stair and (not is_instance_valid(racer) or not is_water_recovering(racer) or StringName(_traversal_kind_by_id.get(racer_id, &"")) != &"root_climb"):
		if is_instance_valid(racer):
			print("LOGSPIRE STAIR EXIT racer=%s safe=true" % RaceManager.get_racer_label(racer))

func _update_ladder_climb(racer: WildDashCharacterController, delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	var racer_id: int = racer.get_instance_id()
	var before: Vector3 = racer.global_position
	var target_before_value: Variant = _preferred_target_by_id.get(racer_id, _ladder_by_id.get(racer_id, {}))
	var target_before: Dictionary = target_before_value if target_before_value is Dictionary else {}
	var was_recovering: bool = is_water_recovering(racer)

	super(racer, delta)

	if not was_recovering or not is_instance_valid(racer) or not is_water_recovering(racer):
		return
	var after: Vector3 = racer.global_position
	if before.distance_squared_to(after) <= 0.0001:
		return
	if not _major_world_motion_blocked(racer, before, after):
		return

	racer.global_position = before
	racer.velocity = Vector3.ZERO
	var signature: String = _target_signature(target_before)
	if not signature.is_empty():
		_major_blocked_target_by_id[racer_id] = signature
	_abort_scripted_traversal_to_swim(racer, "major_world_collision")
	print("LOGSPIRE RECOVERY WORLD BLOCK racer=%s target=%s world_collision=true phase_through=false" % [
		RaceManager.get_racer_label(racer), signature,
	])

func _score_recovery_target(racer: WildDashCharacterController, target: Dictionary, current_zone: int) -> float:
	var score: float = super(racer, target, current_zone)
	if racer == null:
		return score
	var blocked: String = String(_major_blocked_target_by_id.get(racer.get_instance_id(), ""))
	if not blocked.is_empty() and _target_signature(target) == blocked:
		score += MAJOR_BLOCKED_SCORE_PENALTY
	return score

func _finish_water_recovery(racer: WildDashCharacterController) -> void:
	if racer != null:
		_major_blocked_target_by_id.erase(racer.get_instance_id())
	super(racer)

func _finish_assisted_recovery(racer: WildDashCharacterController, exit_position: Vector3, message: String) -> void:
	if racer != null:
		_major_blocked_target_by_id.erase(racer.get_instance_id())
	super(racer, exit_position, message)

func _start_checkpoint_fallback(racer: WildDashCharacterController, reason: String) -> void:
	if racer != null:
		_major_blocked_target_by_id.erase(racer.get_instance_id())
	super(racer, reason)

func _enforce_surface_lock(racer: WildDashCharacterController, water_y: float, delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	var target_y: float = water_y + SURFACE_LOCK_OFFSET
	var difference: float = target_y - racer.global_position.y
	if difference > SURFACE_LOCK_TOLERANCE:
		racer.move_and_collide(Vector3.UP * difference)
	elif difference < -SURFACE_LOCK_TOLERANCE and delta > 0.0:
		var descend: float = minf(-difference, SURFACE_DESCEND_SPEED * delta)
		racer.move_and_collide(Vector3.DOWN * descend)
	racer.velocity.y = 0.0

func _major_world_motion_blocked(
	racer: WildDashCharacterController,
	from_position: Vector3,
	to_position: Vector3
) -> bool:
	if racer == null:
		return false
	var motion: Vector3 = to_position - from_position
	if motion.length_squared() <= 0.0001:
		return false
	var saved_position: Vector3 = racer.global_position
	var saved_mask: int = racer.collision_mask
	racer.global_position = from_position
	racer.collision_mask = MAJOR_WORLD_QUERY_MASK
	var hit: KinematicCollision3D = racer.move_and_collide(motion, true)
	racer.collision_mask = saved_mask
	racer.global_position = saved_position
	return hit != null

func _abort_scripted_traversal_to_swim(racer: WildDashCharacterController, reason: String) -> void:
	if racer == null:
		return
	var racer_id: int = racer.get_instance_id()
	var target_value: Variant = _preferred_target_by_id.get(racer_id, _ladder_by_id.get(racer_id, {}))
	var target: Dictionary = target_value if target_value is Dictionary else {}
	var zone: int = int(_zone_by_id.get(racer_id, 0))
	print("LOGSPIRE RECOVERY PATH BLOCKED object=%s zone=%d reason=%s" % [
		_target_signature(target),
		zone + 1,
		reason,
	])
	_state_by_id[racer_id] = WaterState.SWIMMING
	_traversal_kind_by_id.erase(racer_id)
	_traversal_elapsed_by_id.erase(racer_id)
	_traversal_duration_by_id.erase(racer_id)
	_traversal_from_by_id.erase(racer_id)
	_traversal_to_by_id.erase(racer_id)
	_traversal_path_by_id.erase(racer_id)
	_preferred_target_by_id.erase(racer_id)
	_ladder_by_id.erase(racer_id)
	_set_traversal_action_lock(racer, false)
	_set_ux_state(racer, RecoveryUXState.SWIMMING)
	if racer.is_player and DisplayServer.get_name() != "headless":
		_set_hud_message("RECOVERY ROUTE · OBSTACLE AHEAD · FIND ANOTHER EXIT")
	print("LOGSPIRE RECOVERY TRAVERSAL ABORT racer=%s reason=%s state=SWIMMING" % [
		RaceManager.get_racer_label(racer), reason,
	])
