extends "res://modes/logspire_leap/logspire_water_recovery_v9_priority_camera.gd"

## Round 3 recovery reliability authority.
## - submerged racers are reacquired and kept at the visible water surface
## - broad root ramps are the normal recovery target, ladders are secondary
## - entering a generous ladder capture zone immediately owns align and climb
## - one-second no-progress detection reselects a blocked route
## - a short visible vine pull is the final fail-safe after prolonged recovery
## - major world geometry still cannot be phased through by normal traversal

const SUBMERGED_REACQUIRE_DEPTH: float = 0.35
const SURFACE_LOCK_OFFSET: float = 0.52
const SURFACE_LOCK_TOLERANCE: float = 0.14
const SURFACE_ASCEND_SPEED: float = 9.0
const SURFACE_DESCEND_SPEED: float = 6.0
const MAJOR_WORLD_QUERY_MASK: int = 4
const MAJOR_BLOCKED_SCORE_PENALTY: float = 1000.0

const STAIR_AUTO_ATTACH_RADIUS: float = 1.5
const STAIR_CLIMB_SPEED_MPS: float = 3.4
const STAIR_CLIMB_MIN_SECONDS: float = 1.20
const STAIR_CLIMB_MAX_SECONDS: float = 3.20

const LADDER_CAPTURE_HALF_WIDTH: float = 1.50
const LADDER_CAPTURE_FRONT_METERS: float = 2.50
const LADDER_CAPTURE_BACK_METERS: float = 0.90
const LADDER_CAPTURE_RADIAL_FALLBACK: float = 2.20
const LADDER_ALIGN_RELIABLE_SECONDS: float = 0.20
const LADDER_CLIMB_RELIABLE_MAX_SECONDS: float = 3.00

const RECOVERY_STUCK_SECONDS: float = 1.00
const RECOVERY_PROGRESS_METERS: float = 0.18
const VINE_RESCUE_TRIGGER_SECONDS: float = 4.80
const VINE_RESCUE_DURATION: float = 1.00
const VINE_RESCUE_ARC_HEIGHT: float = 2.40
const VINE_ANCHOR_HEIGHT: float = 4.50
const RECOVERY_HARD_LIMIT_SECONDS: float = 7.00

var _major_blocked_target_by_id: Dictionary = {}
var _surface_reacquire_count: int = 0
var _recovery_elapsed_by_id: Dictionary = {}
var _recovery_last_progress_position_by_id: Dictionary = {}
var _recovery_stuck_elapsed_by_id: Dictionary = {}
var _recovery_stuck_count_by_id: Dictionary = {}
var _vine_rescue_started_by_id: Dictionary = {}
var _vine_visual_by_id: Dictionary = {}
var _vine_anchor_by_id: Dictionary = {}

func _physics_process(delta: float) -> void:
	super(delta)
	if not _configured or not RaceManager.active:
		return

	for value: Variant in RaceManager.racers.duplicate():
		var racer := value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer.finished:
			continue
		var racer_id: int = racer.get_instance_id()
		var pool: Dictionary = _pool_for_position(racer.global_position)

		if is_water_recovering(racer):
			if not pool.is_empty():
				var active_water_y: float = float(pool.get("water_y", racer.global_position.y))
				var traversal_kind := StringName(_traversal_kind_by_id.get(racer_id, &""))
				if traversal_kind == &"":
					_enforce_surface_lock(racer, active_water_y, delta)
			_update_recovery_watchdog(racer, delta)
			continue

		_clear_reliability_runtime(racer_id)
		if pool.is_empty():
			continue
		var water_y: float = float(pool.get("water_y", -999.0))
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
		var racer_id: int = racer.get_instance_id()
		_major_blocked_target_by_id.erase(racer_id)
		_clear_reliability_runtime(racer_id)
	super(racer, zone, water_y)
	if racer != null and is_instance_valid(racer) and is_water_recovering(racer):
		var racer_id: int = racer.get_instance_id()
		_recovery_elapsed_by_id[racer_id] = 0.0
		_recovery_stuck_elapsed_by_id[racer_id] = 0.0
		_recovery_stuck_count_by_id[racer_id] = 0
		_recovery_last_progress_position_by_id[racer_id] = racer.global_position
		print("LOGSPIRE RECOVERY START racer=%s zone=%d root_priority=true ladder_secondary=true vine_fail_safe=%.1fs" % [
			RaceManager.get_racer_label(racer), zone + 1, VINE_RESCUE_TRIGGER_SECONDS,
		])
		_enforce_surface_lock(racer, water_y, 0.0)

func _update_swimming(racer: WildDashCharacterController, delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	var racer_id: int = racer.get_instance_id()
	var zone: int = int(_zone_by_id.get(racer_id, 0))

	# A player or AI that physically reaches a ladder should never lose the ladder
	# because scoring currently prefers a root. Capture the local ladder volume
	# first, then let normal guidance remain Root -> Ladder.
	var captured_ladder: Dictionary = _ladder_capture_candidate(racer, zone)
	if not captured_ladder.is_empty():
		captured_ladder["recovery_type"] = TARGET_LADDER
		_preferred_target_by_id[racer_id] = captured_ladder
		_ladder_by_id[racer_id] = captured_ladder
		_update_recovery_camera_focus(racer, captured_ladder)
		_begin_ladder_climb(racer, captured_ladder)
		return

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
		print("LOGSPIRE RECOVERY TARGET racer=%s from=%s to=%s score=%.2f player_priority=%s priority=ROOT" % [
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
		_set_hud_message("RECOVERY ROUTE · SWIM TO THE ROOT · %.0fm" % target_distance)
		_apply_manual_recovery_swim(racer, water_y, delta)
	else:
		_apply_ai_recovery_swim(racer, target, water_y, delta)

func _choose_recovery_target(racer: WildDashCharacterController, zone: int) -> Dictionary:
	if racer == null or _ladder_system == null:
		return {}

	var roots: Array = []
	if _ladder_system.has_method("get_root_ramps_for_zone"):
		var roots_value: Variant = _ladder_system.call("get_root_ramps_for_zone", zone)
		if roots_value is Array:
			for value: Variant in roots_value:
				if value is Dictionary:
					var candidate: Dictionary = value.duplicate(true)
					candidate["recovery_type"] = TARGET_ROOT
					roots.append(candidate)
	var best_root: Dictionary = _best_reliability_candidate(racer, roots, zone)
	if not best_root.is_empty():
		return best_root

	var same_zone_ladders: Array = []
	var all_ladders: Array = []
	if _ladder_system.has_method("get_all_ladders"):
		var ladders_value: Variant = _ladder_system.call("get_all_ladders")
		if ladders_value is Array:
			for value: Variant in ladders_value:
				if not (value is Dictionary):
					continue
				var candidate: Dictionary = value.duplicate(true)
				candidate["recovery_type"] = TARGET_LADDER
				all_ladders.append(candidate)
				if int(candidate.get("zone", -1)) == zone:
					same_zone_ladders.append(candidate)
	var best_ladder: Dictionary = _best_reliability_candidate(racer, same_zone_ladders, zone)
	if best_ladder.is_empty():
		best_ladder = _best_reliability_candidate(racer, all_ladders, zone)
	return best_ladder

func _best_reliability_candidate(racer: WildDashCharacterController, candidates: Array, zone: int) -> Dictionary:
	if racer == null or candidates.is_empty():
		return {}
	var blocked: String = String(_major_blocked_target_by_id.get(racer.get_instance_id(), ""))
	var best: Dictionary = {}
	var best_score: float = INF
	for value: Variant in candidates:
		if not (value is Dictionary):
			continue
		var candidate: Dictionary = value.duplicate(true)
		if not blocked.is_empty() and _target_signature(candidate) == blocked:
			continue
		var score: float = _score_recovery_target(racer, candidate, zone)
		candidate["target_score"] = score
		if score < best_score:
			best_score = score
			best = candidate
	return best

func _ladder_capture_candidate(racer: WildDashCharacterController, zone: int) -> Dictionary:
	if racer == null or _ladder_system == null or not _ladder_system.has_method("get_all_ladders"):
		return {}
	var ladders_value: Variant = _ladder_system.call("get_all_ladders")
	if not (ladders_value is Array):
		return {}
	var best: Dictionary = {}
	var best_distance: float = INF
	for value: Variant in ladders_value:
		if not (value is Dictionary):
			continue
		var ladder: Dictionary = value
		if int(ladder.get("zone", -1)) != zone:
			continue
		var bottom_value: Variant = ladder.get("bottom", Vector3.ZERO)
		if not (bottom_value is Vector3):
			continue
		var bottom: Vector3 = bottom_value
		var to_racer := racer.global_position - bottom
		to_racer.y = 0.0
		var planar_distance: float = to_racer.length()
		var safe_value: Variant = ladder.get("safe_exit", ladder.get("exit", bottom + Vector3.FORWARD))
		var safe_exit: Vector3 = safe_value if safe_value is Vector3 else bottom + Vector3.FORWARD
		var forward := safe_exit - bottom
		forward.y = 0.0
		if forward.length_squared() <= 0.001:
			forward = Vector3.FORWARD
		else:
			forward = forward.normalized()
		var right := Vector3(-forward.z, 0.0, forward.x)
		var along: float = to_racer.dot(forward)
		var side: float = absf(to_racer.dot(right))
		var inside_box: bool = (
			side <= LADDER_CAPTURE_HALF_WIDTH
			and along >= -LADDER_CAPTURE_FRONT_METERS
			and along <= LADDER_CAPTURE_BACK_METERS
		)
		var inside_fallback: bool = planar_distance <= LADDER_CAPTURE_RADIAL_FALLBACK
		if not inside_box and not inside_fallback:
			continue
		if planar_distance < best_distance:
			best_distance = planar_distance
			best = ladder.duplicate(true)
	return best

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

func _begin_ladder_climb(racer: WildDashCharacterController, ladder: Dictionary) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	var racer_id: int = racer.get_instance_id()
	print("LOGSPIRE LADDER CAPTURE racer=%s ladder=%s width=%.1fm front=%.1fm jump_required=false" % [
		RaceManager.get_racer_label(racer),
		String(ladder.get("id", &"")),
		LADDER_CAPTURE_HALF_WIDTH * 2.0,
		LADDER_CAPTURE_FRONT_METERS,
	])
	super(racer, ladder)
	if StringName(_traversal_kind_by_id.get(racer_id, &"")) == &"ladder_align":
		_traversal_duration_by_id[racer_id] = LADDER_ALIGN_RELIABLE_SECONDS

func _update_ladder_align(racer: WildDashCharacterController, delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	super(racer, delta)
	if not is_instance_valid(racer):
		return
	var racer_id: int = racer.get_instance_id()
	if StringName(_traversal_kind_by_id.get(racer_id, &"")) == &"ladder_climb":
		var duration: float = float(_traversal_duration_by_id.get(racer_id, LADDER_CLIMB_RELIABLE_MAX_SECONDS))
		_traversal_duration_by_id[racer_id] = minf(duration, LADDER_CLIMB_RELIABLE_MAX_SECONDS)

func _update_root_climb(racer: WildDashCharacterController, delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	var racer_id: int = racer.get_instance_id()
	var elapsed_before: float = float(_recovery_elapsed_by_id.get(racer_id, 0.0))
	var was_stair: bool = StringName(_traversal_kind_by_id.get(racer_id, &"")) == &"root_climb"
	super(racer, delta)
	if was_stair and (not is_instance_valid(racer) or not is_water_recovering(racer) or StringName(_traversal_kind_by_id.get(racer_id, &"")) != &"root_climb"):
		if is_instance_valid(racer):
			print("LOGSPIRE STAIR EXIT racer=%s safe=true" % RaceManager.get_racer_label(racer))
			if not is_water_recovering(racer):
				print("LOGSPIRE ROOT RECOVERY SUCCESS racer=%s duration=%.2f safe=true" % [
					RaceManager.get_racer_label(racer), elapsed_before,
				])

func _update_ladder_climb(racer: WildDashCharacterController, delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	var racer_id: int = racer.get_instance_id()
	var before: Vector3 = racer.global_position
	var elapsed_before: float = float(_recovery_elapsed_by_id.get(racer_id, 0.0))
	var kind_before := StringName(_traversal_kind_by_id.get(racer_id, &""))
	if kind_before == &"vine_rescue":
		_update_vine_rescue(racer, delta)
		return
	var target_before_value: Variant = _preferred_target_by_id.get(racer_id, _ladder_by_id.get(racer_id, {}))
	var target_before: Dictionary = target_before_value if target_before_value is Dictionary else {}
	var was_recovering: bool = is_water_recovering(racer)

	super(racer, delta)

	if is_instance_valid(racer):
		var kind_after := StringName(_traversal_kind_by_id.get(racer_id, &""))
		if kind_after == &"ladder_climb":
			var climb_duration: float = float(_traversal_duration_by_id.get(racer_id, LADDER_CLIMB_RELIABLE_MAX_SECONDS))
			_traversal_duration_by_id[racer_id] = minf(climb_duration, LADDER_CLIMB_RELIABLE_MAX_SECONDS)
		if kind_before in [&"ladder_align", &"ladder_climb", &"ladder_exit"] and not is_water_recovering(racer):
			print("LOGSPIRE LADDER SUCCESS racer=%s duration=%.2f safe=true" % [
				RaceManager.get_racer_label(racer), elapsed_before,
			])

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

func _update_recovery_watchdog(racer: WildDashCharacterController, delta: float) -> void:
	if racer == null or not is_instance_valid(racer) or not is_water_recovering(racer):
		return
	var racer_id: int = racer.get_instance_id()
	var elapsed: float = float(_recovery_elapsed_by_id.get(racer_id, 0.0)) + delta
	_recovery_elapsed_by_id[racer_id] = elapsed
	var kind := StringName(_traversal_kind_by_id.get(racer_id, &""))
	if kind == &"vine_rescue":
		return

	var last_value: Variant = _recovery_last_progress_position_by_id.get(racer_id, racer.global_position)
	var last_position: Vector3 = last_value if last_value is Vector3 else racer.global_position
	if racer.global_position.distance_to(last_position) >= RECOVERY_PROGRESS_METERS:
		_recovery_last_progress_position_by_id[racer_id] = racer.global_position
		_recovery_stuck_elapsed_by_id[racer_id] = 0.0
	else:
		var stuck_elapsed: float = float(_recovery_stuck_elapsed_by_id.get(racer_id, 0.0)) + delta
		_recovery_stuck_elapsed_by_id[racer_id] = stuck_elapsed
		if stuck_elapsed >= RECOVERY_STUCK_SECONDS:
			_handle_recovery_stuck(racer)

	if not is_instance_valid(racer) or not is_water_recovering(racer):
		return
	if elapsed >= VINE_RESCUE_TRIGGER_SECONDS and not bool(_vine_rescue_started_by_id.get(racer_id, false)):
		_begin_vine_rescue(racer)
	elif elapsed >= RECOVERY_HARD_LIMIT_SECONDS and not bool(_vine_rescue_started_by_id.get(racer_id, false)):
		_begin_vine_rescue(racer)

func _handle_recovery_stuck(racer: WildDashCharacterController) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	var racer_id: int = racer.get_instance_id()
	var target_value: Variant = _preferred_target_by_id.get(racer_id, _ladder_by_id.get(racer_id, {}))
	var target: Dictionary = target_value if target_value is Dictionary else {}
	var signature: String = _target_signature(target)
	if not signature.is_empty():
		_major_blocked_target_by_id[racer_id] = signature
	var count: int = int(_recovery_stuck_count_by_id.get(racer_id, 0)) + 1
	_recovery_stuck_count_by_id[racer_id] = count
	_recovery_stuck_elapsed_by_id[racer_id] = 0.0
	_recovery_last_progress_position_by_id[racer_id] = racer.global_position
	print("LOGSPIRE RECOVERY STUCK racer=%s target=%s count=%d no_progress=%.1fs reselect=true" % [
		RaceManager.get_racer_label(racer), signature, count, RECOVERY_STUCK_SECONDS,
	])
	var kind := StringName(_traversal_kind_by_id.get(racer_id, &""))
	if kind != &"":
		_abort_scripted_traversal_to_swim(racer, "stuck_watchdog")
	else:
		_preferred_target_by_id.erase(racer_id)
		_ladder_by_id.erase(racer_id)
		_set_ux_state(racer, RecoveryUXState.SWIMMING)

func _begin_vine_rescue(racer: WildDashCharacterController) -> void:
	if racer == null or not is_instance_valid(racer) or not is_water_recovering(racer):
		return
	var racer_id: int = racer.get_instance_id()
	if bool(_vine_rescue_started_by_id.get(racer_id, false)):
		return
	var target: Vector3 = _vine_rescue_target(racer)
	if target == Vector3.INF:
		return
	var current_kind := StringName(_traversal_kind_by_id.get(racer_id, &""))
	if current_kind != &"":
		_abort_scripted_traversal_to_swim(racer, "vine_fail_safe")
	_vine_rescue_started_by_id[racer_id] = true
	_state_by_id[racer_id] = WaterState.LADDER_CLIMB
	_traversal_kind_by_id[racer_id] = &"vine_rescue"
	_traversal_elapsed_by_id[racer_id] = 0.0
	_traversal_duration_by_id[racer_id] = VINE_RESCUE_DURATION
	_traversal_from_by_id[racer_id] = racer.global_position
	_traversal_to_by_id[racer_id] = target
	_set_traversal_action_lock(racer, true)
	racer.collision_mask = 1
	racer.velocity = Vector3.ZERO
	_create_vine_visual(racer, target)
	var total_elapsed: float = float(_recovery_elapsed_by_id.get(racer_id, 0.0))
	print("LOGSPIRE VINE RESCUE racer=%s phase=start recovery_elapsed=%.2f pull_duration=%.2f teleport=false fail_safe=true" % [
		RaceManager.get_racer_label(racer), total_elapsed, VINE_RESCUE_DURATION,
	])
	if racer.is_player and DisplayServer.get_name() != "headless":
		_set_hud_message("VINE RESCUE · HOLD ON!")

func _update_vine_rescue(racer: WildDashCharacterController, delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	var racer_id: int = racer.get_instance_id()
	var duration: float = maxf(0.01, float(_traversal_duration_by_id.get(racer_id, VINE_RESCUE_DURATION)))
	var elapsed: float = float(_traversal_elapsed_by_id.get(racer_id, 0.0)) + delta
	_traversal_elapsed_by_id[racer_id] = elapsed
	var t: float = clampf(elapsed / duration, 0.0, 1.0)
	var from_value: Variant = _traversal_from_by_id.get(racer_id, racer.global_position)
	var to_value: Variant = _traversal_to_by_id.get(racer_id, racer.global_position)
	var from: Vector3 = from_value if from_value is Vector3 else racer.global_position
	var to: Vector3 = to_value if to_value is Vector3 else racer.global_position
	var position := from.lerp(to, t)
	position.y += sin(t * PI) * VINE_RESCUE_ARC_HEIGHT
	racer.global_position = position
	racer.velocity = Vector3.ZERO
	_update_vine_visual(racer)
	if t < 1.0:
		return
	var total_elapsed: float = float(_recovery_elapsed_by_id.get(racer_id, 0.0))
	print("LOGSPIRE VINE RESCUE racer=%s phase=complete duration=%.2f safe=true" % [
		RaceManager.get_racer_label(racer), total_elapsed,
	])
	_finish_assisted_recovery(racer, to, "VINE RESCUE COMPLETE · BACK TO THE RACE")

func _vine_rescue_target(racer: WildDashCharacterController) -> Vector3:
	if racer == null or _ladder_system == null:
		return Vector3.INF
	var zone: int = int(_zone_by_id.get(racer.get_instance_id(), 0))
	var best := Vector3.INF
	var best_distance: float = INF
	if _ladder_system.has_method("get_root_ramps_for_zone"):
		var roots_value: Variant = _ladder_system.call("get_root_ramps_for_zone", zone)
		if roots_value is Array:
			for value: Variant in roots_value:
				if not (value is Dictionary):
					continue
				var exit_value: Variant = (value as Dictionary).get("exit", Vector3.INF)
				if not (exit_value is Vector3):
					continue
				var point: Vector3 = exit_value
				var distance: float = Vector2(racer.global_position.x - point.x, racer.global_position.z - point.z).length()
				if distance < best_distance:
					best_distance = distance
					best = point
	if best != Vector3.INF:
		return best
	if _ladder_system.has_method("get_all_ladders"):
		var ladders_value: Variant = _ladder_system.call("get_all_ladders")
		if ladders_value is Array:
			for value: Variant in ladders_value:
				if not (value is Dictionary):
					continue
				var ladder: Dictionary = value
				if int(ladder.get("zone", -1)) != zone:
					continue
				var exit_value: Variant = ladder.get("safe_exit", ladder.get("exit", Vector3.INF))
				if not (exit_value is Vector3):
					continue
				var point: Vector3 = exit_value
				var distance: float = Vector2(racer.global_position.x - point.x, racer.global_position.z - point.z).length()
				if distance < best_distance:
					best_distance = distance
					best = point
	return best

func _create_vine_visual(racer: WildDashCharacterController, target: Vector3) -> void:
	if racer == null:
		return
	var racer_id: int = racer.get_instance_id()
	var vine := CSGBox3D.new()
	vine.name = "EmergencyVine_%d" % racer_id
	vine.use_collision = false
	vine.size = Vector3(0.16, 0.16, 1.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.62, 0.16)
	material.roughness = 0.92
	vine.material = material
	add_child(vine)
	_vine_visual_by_id[racer_id] = vine
	_vine_anchor_by_id[racer_id] = target + Vector3.UP * VINE_ANCHOR_HEIGHT
	_update_vine_visual(racer)

func _update_vine_visual(racer: WildDashCharacterController) -> void:
	if racer == null:
		return
	var racer_id: int = racer.get_instance_id()
	var vine_value: Variant = _vine_visual_by_id.get(racer_id, null)
	var vine := vine_value as CSGBox3D
	var anchor_value: Variant = _vine_anchor_by_id.get(racer_id, Vector3.INF)
	if vine == null or not is_instance_valid(vine) or not (anchor_value is Vector3):
		return
	var anchor: Vector3 = anchor_value
	if anchor == Vector3.INF:
		return
	var delta := anchor - racer.global_position
	var length: float = maxf(0.20, delta.length())
	vine.global_position = racer.global_position.lerp(anchor, 0.5)
	vine.size = Vector3(0.16, 0.16, length)
	vine.look_at(anchor, Vector3.UP)

func _finish_water_recovery(racer: WildDashCharacterController) -> void:
	if racer != null:
		var racer_id: int = racer.get_instance_id()
		_major_blocked_target_by_id.erase(racer_id)
	super(racer)
	if racer != null:
		_clear_reliability_runtime(racer.get_instance_id())

func _finish_assisted_recovery(racer: WildDashCharacterController, exit_position: Vector3, message: String) -> void:
	if racer != null:
		var racer_id: int = racer.get_instance_id()
		_major_blocked_target_by_id.erase(racer_id)
	super(racer, exit_position, message)
	if racer != null:
		_clear_reliability_runtime(racer.get_instance_id())

func _start_checkpoint_fallback(racer: WildDashCharacterController, reason: String) -> void:
	if racer != null:
		var racer_id: int = racer.get_instance_id()
		_major_blocked_target_by_id.erase(racer_id)
		_clear_reliability_runtime(racer_id)
	super(racer, reason)

func _clear_reliability_runtime(racer_id: int) -> void:
	_recovery_elapsed_by_id.erase(racer_id)
	_recovery_last_progress_position_by_id.erase(racer_id)
	_recovery_stuck_elapsed_by_id.erase(racer_id)
	_recovery_stuck_count_by_id.erase(racer_id)
	_vine_rescue_started_by_id.erase(racer_id)
	_vine_anchor_by_id.erase(racer_id)
	var vine_value: Variant = _vine_visual_by_id.get(racer_id, null)
	var vine := vine_value as Node
	if vine != null and is_instance_valid(vine):
		vine.queue_free()
	_vine_visual_by_id.erase(racer_id)

func _enforce_surface_lock(racer: WildDashCharacterController, water_y: float, delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	var target_y: float = water_y + SURFACE_LOCK_OFFSET
	var difference: float = target_y - racer.global_position.y
	var step_delta: float = maxf(delta, 1.0 / 60.0)
	if difference > SURFACE_LOCK_TOLERANCE:
		var ascend: float = minf(difference, SURFACE_ASCEND_SPEED * step_delta)
		racer.move_and_collide(Vector3.UP * ascend)
	elif difference < -SURFACE_LOCK_TOLERANCE:
		var descend: float = minf(-difference, SURFACE_DESCEND_SPEED * step_delta)
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
		_set_hud_message("RECOVERY ROUTE · FINDING ANOTHER EXIT")
	print("LOGSPIRE RECOVERY TRAVERSAL ABORT racer=%s reason=%s state=SWIMMING" % [
		RaceManager.get_racer_label(racer), reason,
	])
