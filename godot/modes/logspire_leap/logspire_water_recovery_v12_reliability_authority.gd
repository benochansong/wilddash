extends "res://modes/logspire_leap/logspire_water_recovery_v10_surface_collision_guard.gd"

## Round 3 water/recovery reliability pass.
## WATER owns vertical motion. Scripted root/ladder traversal temporarily owns the
## full transform only after a clearance audit. Blocked targets remain excluded
## for the rest of the current water recovery so the racer cannot loop forever.
## Normal water recovery is strictly Root -> Ladder -> Vine fail-safe; the older
## V9 Jump-out candidate remains available in source but is not selected here.

const IMMEDIATE_REACQUIRE_DEPTH: float = 0.18
const DEEP_WATER_GUARD_DEPTH: float = 0.70
const SURFACE_SEARCH_STEP: float = 0.90
const SURFACE_SEARCH_RADIUS: float = 2.70
const SURFACE_BLOCK_LOG_INTERVAL: float = 0.40
const RACER_CAPSULE_RADIUS: float = 0.62
const RACER_CAPSULE_HEIGHT: float = 1.90
const RACER_CAPSULE_CENTER_Y: float = 1.02
const HEAD_CLEARANCE_Y: float = 1.15
const EXIT_FLOOR_CHECK_UP: float = 0.65
const EXIT_FLOOR_CHECK_DOWN: float = 1.80

var _blocked_targets_by_id: Dictionary = {}
var _surface_block_log_time_by_id: Dictionary = {}

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
		var racer_id: int = racer.get_instance_id()
		var water_y: float = float(pool.get("water_y", racer.global_position.y))

		if is_water_recovering(racer):
			var traversal_kind := StringName(_traversal_kind_by_id.get(racer_id, &""))
			if traversal_kind == &"" and racer.global_position.y < water_y - DEEP_WATER_GUARD_DEPTH:
				print("LOGSPIRE SURFACE REACQUIRE racer=%s zone=%d reason=deep_guard body_y=%.2f water_y=%.2f" % [
					RaceManager.get_racer_label(racer), int(pool.get("zone", 0)) + 1, racer.global_position.y, water_y,
				])
				_enforce_surface_lock(racer, water_y, delta)
			continue

		if racer.global_position.y <= water_y - IMMEDIATE_REACQUIRE_DEPTH:
			print("LOGSPIRE SURFACE REACQUIRE racer=%s zone=%d reason=immediate_capture body_y=%.2f water_y=%.2f" % [
				RaceManager.get_racer_label(racer), int(pool.get("zone", 0)) + 1, racer.global_position.y, water_y,
			])
			_enter_water(racer, int(pool.get("zone", 0)), water_y)

func _enter_water(racer: WildDashCharacterController, zone: int, water_y: float) -> void:
	if racer != null and is_instance_valid(racer):
		var racer_id: int = racer.get_instance_id()
		_blocked_targets_by_id.erase(racer_id)
		_surface_block_log_time_by_id.erase(racer_id)
		print("LOGSPIRE WATER ENTER racer=%s zone=%d water_y=%.2f authority=surface_recovery" % [
			RaceManager.get_racer_label(racer), zone + 1, water_y,
		])
	super(racer, zone, water_y)

func _update_swimming(racer: WildDashCharacterController, delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	_cancel_stale_checkpoint_recovery(racer)
	racer.collision_mask = 1
	var racer_id: int = racer.get_instance_id()
	var zone: int = int(_zone_by_id.get(racer_id, 0))
	var water_y: float = float(_water_y_by_id.get(racer_id, racer.global_position.y))
	var controlled_by_player: bool = racer.is_player and DisplayServer.get_name() != "headless"

	# If the racer physically reaches a ladder, capture it immediately. This does
	# not change route guidance; it only prevents a touched ladder from being lost.
	var captured_ladder: Dictionary = _ladder_capture_candidate(racer, zone)
	if not captured_ladder.is_empty():
		captured_ladder["recovery_type"] = TARGET_LADDER
		_preferred_target_by_id[racer_id] = captured_ladder
		_ladder_by_id[racer_id] = captured_ladder
		_update_recovery_camera_focus(racer, captured_ladder)
		_begin_ladder_climb(racer, captured_ladder)
		return

	# V10 _choose_recovery_target returns a valid Root first, then a Ladder. Do not
	# delegate this path to V9 because V9 also considers legacy Jump-out targets.
	var target: Dictionary = _choose_recovery_target(racer, zone)
	if target.is_empty():
		_preferred_target_by_id.erase(racer_id)
		_ladder_by_id.erase(racer_id)
		_set_ux_state(racer, RecoveryUXState.SWIMMING)
		_clear_recovery_camera_focus_if_needed(racer)
		if controlled_by_player:
			_set_hud_message("RECOVERY ROUTE · FIND A ROOT OR LADDER")
			_apply_manual_recovery_swim(racer, water_y, delta)
		else:
			racer.velocity.y = 0.0
		return

	var previous_value: Variant = _preferred_target_by_id.get(racer_id, {})
	var previous: Dictionary = previous_value if previous_value is Dictionary else {}
	if _target_signature(previous) != _target_signature(target):
		print("LOGSPIRE RECOVERY TARGET racer=%s from=%s to=%s score=%.2f player_priority=%s strict_priority=ROOT_LADDER_VINE" % [
			RaceManager.get_racer_label(racer),
			_target_signature(previous),
			_target_signature(target),
			float(target.get("target_score", 0.0)),
			str(racer.is_player),
		])
	_preferred_target_by_id[racer_id] = target
	_update_recovery_camera_focus(racer, target)
	var recovery_type := StringName(target.get("recovery_type", &""))
	var target_distance: float = _distance_to_target(racer, target)

	if recovery_type == TARGET_ROOT:
		_set_ux_state(racer, RecoveryUXState.ROOT_APPROACH)
		if target_distance <= STAIR_AUTO_ATTACH_RADIUS:
			_begin_root_climb(racer, target)
			return
		if controlled_by_player:
			_set_hud_message("RECOVERY ROUTE · SWIM TO THE ROOT · %.0fm" % target_distance)
			_apply_manual_recovery_swim(racer, water_y, delta)
		else:
			_apply_ai_recovery_swim(racer, target, water_y, delta)
		return

	if recovery_type == TARGET_LADDER:
		_set_ux_state(racer, RecoveryUXState.LADDER_APPROACH)
		_ladder_by_id[racer_id] = target
		if target_distance <= LADDER_AUTO_ATTACH_RADIUS:
			_begin_ladder_climb(racer, target)
			return
		if controlled_by_player:
			_set_hud_message("RECOVERY ROUTE · SWIM TO THE LADDER · %.0fm" % target_distance)
			_apply_manual_recovery_swim(racer, water_y, delta)
		else:
			var bottom_value: Variant = target.get("bottom", racer.global_position)
			var bottom: Vector3 = bottom_value if bottom_value is Vector3 else racer.global_position
			_apply_ai_recovery_swim(racer, {"entry": bottom}, water_y, delta)
		return

	# Unknown legacy recovery types are not normal paths in the reliability pass.
	_reject_recovery_target(racer, target, "unsupported_recovery_type")

func _enforce_surface_lock(racer: WildDashCharacterController, water_y: float, delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	var racer_id: int = racer.get_instance_id()
	var traversal_kind := StringName(_traversal_kind_by_id.get(racer_id, &""))
	if traversal_kind != &"":
		return

	racer.collision_mask = 1
	var target_y: float = water_y + SURFACE_LOCK_OFFSET
	var difference: float = target_y - racer.global_position.y
	var step_delta: float = maxf(delta, 1.0 / 60.0)

	if difference > SURFACE_LOCK_TOLERANCE:
		var ascend: float = minf(difference, SURFACE_ASCEND_SPEED * step_delta)
		var hit: KinematicCollision3D = racer.move_and_collide(Vector3.UP * ascend)
		if hit != null and target_y - racer.global_position.y > SURFACE_LOCK_TOLERANCE:
			_log_surface_blocked(racer, water_y, hit)
			var safe_surface: Vector3 = _find_safe_surface_position(racer, water_y)
			if safe_surface != Vector3.INF:
				racer.reset_motion(safe_surface)
				racer.collision_mask = 1
				print("LOGSPIRE SURFACE REACQUIRE racer=%s reason=blocked_surface_search x=%.2f y=%.2f z=%.2f" % [
					RaceManager.get_racer_label(racer), safe_surface.x, safe_surface.y, safe_surface.z,
				])
	elif difference < -SURFACE_LOCK_TOLERANCE:
		var descend: float = minf(-difference, SURFACE_DESCEND_SPEED * step_delta)
		if not racer.test_move(racer.global_transform, Vector3.DOWN * descend):
			racer.move_and_collide(Vector3.DOWN * descend)

	racer.velocity.y = 0.0

func _find_safe_surface_position(racer: WildDashCharacterController, water_y: float) -> Vector3:
	if racer == null or get_world_3d() == null:
		return Vector3.INF
	var origin: Vector3 = racer.global_position
	var rings: int = maxi(1, int(ceil(SURFACE_SEARCH_RADIUS / SURFACE_SEARCH_STEP)))
	for ring: int in range(rings + 1):
		var radius: float = float(ring) * SURFACE_SEARCH_STEP
		var sample_count: int = 1 if ring == 0 else 8
		for sample: int in range(sample_count):
			var angle: float = TAU * float(sample) / float(sample_count)
			var candidate := Vector3(
				origin.x + cos(angle) * radius,
				water_y + SURFACE_LOCK_OFFSET,
				origin.z + sin(angle) * radius
			)
			var pool: Dictionary = _pool_for_position(candidate)
			if pool.is_empty() or absf(float(pool.get("water_y", water_y)) - water_y) > 0.20:
				continue
			if _capsule_position_clear(racer, candidate):
				return candidate
	return Vector3.INF

func _capsule_position_clear(racer: WildDashCharacterController, feet_position: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = RACER_CAPSULE_RADIUS
	shape.height = RACER_CAPSULE_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, feet_position + Vector3.UP * RACER_CAPSULE_CENTER_Y)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [racer.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _log_surface_blocked(racer: WildDashCharacterController, water_y: float, hit: KinematicCollision3D) -> void:
	var racer_id: int = racer.get_instance_id()
	var now: float = Time.get_ticks_msec() * 0.001
	var last: float = float(_surface_block_log_time_by_id.get(racer_id, -99.0))
	if now - last < SURFACE_BLOCK_LOG_INTERVAL:
		return
	_surface_block_log_time_by_id[racer_id] = now
	var collider_name: String = "unknown"
	if hit != null and hit.get_collider() is Node:
		collider_name = String((hit.get_collider() as Node).name)
	print("LOGSPIRE SURFACE BLOCKED racer=%s collider=%s body_y=%.2f water_y=%.2f searching_safe_surface=true" % [
		RaceManager.get_racer_label(racer), collider_name, racer.global_position.y, water_y,
	])

func _begin_root_climb(racer: WildDashCharacterController, ramp: Dictionary) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	if not _recovery_target_clear(racer, ramp, TARGET_ROOT):
		_reject_recovery_target(racer, ramp, "root_clearance")
		return
	print("LOGSPIRE ROOT ATTACH racer=%s target=%s clearance=true" % [
		RaceManager.get_racer_label(racer), _target_signature(ramp),
	])
	super(racer, ramp)

func _begin_ladder_climb(racer: WildDashCharacterController, ladder: Dictionary) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	if not _recovery_target_clear(racer, ladder, TARGET_LADDER):
		_reject_recovery_target(racer, ladder, "ladder_clearance")
		return
	print("LOGSPIRE LADDER ATTACH racer=%s ladder=%s clearance=true" % [
		RaceManager.get_racer_label(racer), String(ladder.get("id", &"")),
	])
	super(racer, ladder)

func _finish_assisted_recovery(racer: WildDashCharacterController, exit_position: Vector3, message: String) -> void:
	if racer != null and is_instance_valid(racer):
		var racer_id: int = racer.get_instance_id()
		var kind := StringName(_traversal_kind_by_id.get(racer_id, &""))
		if kind != &"vine_rescue" and not _exit_position_clear(racer, exit_position):
			var target_value: Variant = _preferred_target_by_id.get(racer_id, _ladder_by_id.get(racer_id, {}))
			var target: Dictionary = target_value if target_value is Dictionary else {}
			_reject_recovery_target(racer, target, "unsafe_exit")
			return
		print("LOGSPIRE RECOVERY EXIT CLEAR racer=%s kind=%s x=%.2f y=%.2f z=%.2f" % [
			RaceManager.get_racer_label(racer), String(kind), exit_position.x, exit_position.y, exit_position.z,
		])
	super(racer, exit_position, message)

func _finish_water_recovery(racer: WildDashCharacterController) -> void:
	if racer != null and is_instance_valid(racer):
		var racer_id: int = racer.get_instance_id()
		var ladder_value: Variant = _ladder_by_id.get(racer_id, {})
		var ladder: Dictionary = ladder_value if ladder_value is Dictionary else {}
		var exit_value: Variant = ladder.get("safe_exit", ladder.get("exit", racer.global_position))
		var exit_position: Vector3 = exit_value if exit_value is Vector3 else racer.global_position
		if not _exit_position_clear(racer, exit_position):
			_reject_recovery_target(racer, ladder, "unsafe_ladder_exit")
			return
		print("LOGSPIRE RECOVERY EXIT CLEAR racer=%s kind=ladder x=%.2f y=%.2f z=%.2f" % [
			RaceManager.get_racer_label(racer), exit_position.x, exit_position.y, exit_position.z,
		])
	super(racer)

func _recovery_target_clear(racer: WildDashCharacterController, target: Dictionary, recovery_type: StringName) -> bool:
	if target.is_empty():
		return false
	var start_value: Variant = target.get("entry", target.get("bottom", racer.global_position))
	var end_value: Variant = target.get("safe_exit", target.get("exit", Vector3.INF))
	if not (start_value is Vector3) or not (end_value is Vector3):
		return false
	var start: Vector3 = start_value
	var finish: Vector3 = end_value
	if finish == Vector3.INF or not _exit_position_clear(racer, finish):
		return false

	var points: Array[Vector3] = []
	points.append(start)
	var path_value: Variant = target.get("path_points", [])
	if path_value is Array:
		for point_value: Variant in path_value:
			if point_value is Vector3:
				points.append(point_value)
	points.append(finish)
	for i: int in range(1, points.size()):
		if not _head_segment_clear(racer, points[i - 1], points[i]):
			return false
	return true

func _head_segment_clear(racer: WildDashCharacterController, from: Vector3, to: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(
		from + Vector3.UP * HEAD_CLEARANCE_Y,
		to + Vector3.UP * HEAD_CLEARANCE_Y,
		1
	)
	ray.exclude = [racer.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _exit_position_clear(racer: WildDashCharacterController, exit_position: Vector3) -> bool:
	if not _capsule_position_clear(racer, exit_position + Vector3.UP * 0.08):
		return false
	var floor_ray := PhysicsRayQueryParameters3D.create(
		exit_position + Vector3.UP * EXIT_FLOOR_CHECK_UP,
		exit_position - Vector3.UP * EXIT_FLOOR_CHECK_DOWN,
		1
	)
	floor_ray.exclude = [racer.get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(floor_ray).is_empty()

func _reject_recovery_target(racer: WildDashCharacterController, target: Dictionary, reason: String) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	_mark_target_blocked(racer, target)
	var signature: String = _target_signature(target)
	var racer_id: int = racer.get_instance_id()
	_preferred_target_by_id.erase(racer_id)
	_ladder_by_id.erase(racer_id)
	if StringName(_traversal_kind_by_id.get(racer_id, &"")) != &"":
		_abort_scripted_traversal_to_swim(racer, reason)
	else:
		_state_by_id[racer_id] = WaterState.SWIMMING
		_set_ux_state(racer, RecoveryUXState.SWIMMING)
	print("LOGSPIRE RECOVERY RETARGET racer=%s blocked=%s reason=%s immediate=true" % [
		RaceManager.get_racer_label(racer), signature, reason,
	])

func _handle_recovery_stuck(racer: WildDashCharacterController) -> void:
	if racer != null and is_instance_valid(racer):
		var racer_id: int = racer.get_instance_id()
		var target_value: Variant = _preferred_target_by_id.get(racer_id, _ladder_by_id.get(racer_id, {}))
		var target: Dictionary = target_value if target_value is Dictionary else {}
		_mark_target_blocked(racer, target)
		print("LOGSPIRE RECOVERY RETARGET racer=%s blocked=%s reason=no_progress immediate=true" % [
			RaceManager.get_racer_label(racer), _target_signature(target),
		])
	super(racer)

func _best_reliability_candidate(racer: WildDashCharacterController, candidates: Array, zone: int) -> Dictionary:
	if racer == null or candidates.is_empty():
		return {}
	var racer_id: int = racer.get_instance_id()
	var blocked_value: Variant = _blocked_targets_by_id.get(racer_id, {})
	var blocked: Dictionary = blocked_value if blocked_value is Dictionary else {}
	var legacy_blocked: String = String(_major_blocked_target_by_id.get(racer_id, ""))
	var best: Dictionary = {}
	var best_score: float = INF
	for value: Variant in candidates:
		if not (value is Dictionary):
			continue
		var candidate: Dictionary = value.duplicate(true)
		var signature: String = _target_signature(candidate)
		if blocked.has(signature) or (not legacy_blocked.is_empty() and signature == legacy_blocked):
			continue
		var score: float = _score_recovery_target(racer, candidate, zone)
		candidate["target_score"] = score
		if score < best_score:
			best_score = score
			best = candidate
	return best

func _mark_target_blocked(racer: WildDashCharacterController, target: Dictionary) -> void:
	if racer == null or target.is_empty():
		return
	var signature: String = _target_signature(target)
	if signature.is_empty():
		return
	var racer_id: int = racer.get_instance_id()
	var value: Variant = _blocked_targets_by_id.get(racer_id, {})
	var blocked: Dictionary = value if value is Dictionary else {}
	blocked[signature] = true
	_blocked_targets_by_id[racer_id] = blocked
	_major_blocked_target_by_id[racer_id] = signature

func _clear_reliability_runtime(racer_id: int) -> void:
	_blocked_targets_by_id.erase(racer_id)
	_surface_block_log_time_by_id.erase(racer_id)
	super(racer_id)
