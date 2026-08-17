extends "res://modes/logspire_leap/logspire_water_recovery_v8_traversal_ux.gd"

## Final recovery UX authority for the player-tested water pass.
## Adds explicit UX states, distance-aware target scoring, player priority at
## recovery entries, and a Round 3-only recovery camera focus.

enum RecoveryUXState {
	RACING,
	FALLING,
	WATER_ENTRY,
	SWIMMING,
	JUMP_OUT_APPROACH,
	AUTO_VAULT,
	ROOT_APPROACH,
	ROOT_CLIMB,
	LADDER_APPROACH,
	LADDER_ALIGN,
	LADDER_CLIMB,
	SAFE_EXIT,
}

const TARGET_JUMP_OUT: StringName = &"jump_out"
const TARGET_ROOT: StringName = &"root"
const TARGET_LADDER: StringName = &"ladder"
const TARGET_SWITCH_HYSTERESIS: float = 1.25
const JUMP_OUT_TYPE_BIAS: float = 0.0
const ROOT_TYPE_BIAS: float = 1.65
const LADDER_TYPE_BIAS: float = 3.25
const CONGESTION_RADIUS: float = 4.8
const CONGESTION_PENALTY_PER_RACER: float = 1.10
const PLAYER_PRIORITY_RADIUS: float = 5.0
const AI_PLAYER_YIELD_PENALTY: float = 7.5
const WRONG_ZONE_PENALTY: float = 5.0
const BEHIND_PROGRESS_PENALTY: float = 2.0

var _ux_state_by_id: Dictionary = {}
var _preferred_target_by_id: Dictionary = {}

func _enter_water(racer: WildDashCharacterController, zone: int, water_y: float) -> void:
	if racer != null and is_instance_valid(racer):
		_set_ux_state(racer, RecoveryUXState.WATER_ENTRY)
	super(racer, zone, water_y)
	if racer != null and is_instance_valid(racer) and is_water_recovering(racer):
		_set_ux_state(racer, RecoveryUXState.SWIMMING)
		if racer.is_player:
			racer.set_meta(&"logspire_recovery_player_priority", true)

func _update_swimming(racer: WildDashCharacterController, delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	_cancel_stale_checkpoint_recovery(racer)
	racer.collision_mask = 1
	var racer_id: int = racer.get_instance_id()
	var zone: int = int(_zone_by_id.get(racer_id, 0))
	var water_y: float = float(_water_y_by_id.get(racer_id, racer.global_position.y))
	var controlled_by_player: bool = racer.is_player and DisplayServer.get_name() != "headless"
	var target: Dictionary = _choose_recovery_target(racer, zone)
	if target.is_empty():
		_set_ux_state(racer, RecoveryUXState.SWIMMING)
		_clear_recovery_camera_focus_if_needed(racer)
		if controlled_by_player:
			_set_hud_message("RECOVERY ROUTE · FIND AN EXIT")
			_apply_manual_recovery_swim(racer, water_y, delta)
		return

	_preferred_target_by_id[racer_id] = target
	_update_recovery_camera_focus(racer, target)
	var recovery_type := StringName(target.get("recovery_type", &""))
	var target_distance: float = _distance_to_target(racer, target)

	match recovery_type:
		TARGET_JUMP_OUT:
			_set_ux_state(racer, RecoveryUXState.JUMP_OUT_APPROACH)
			var should_vault: bool = target_distance <= LOW_LEDGE_AUTO_VAULT_RADIUS
			if controlled_by_player and target_distance <= LOW_LEDGE_DETECTION_RADIUS and InputManager.consume_jump():
				should_vault = true
			elif not controlled_by_player and target_distance <= LOW_LEDGE_DETECTION_RADIUS:
				should_vault = true
			if should_vault and _vault_landing_is_safe(racer, target):
				_begin_auto_vault(racer, target)
				return
			if controlled_by_player:
				_set_hud_message("RECOVERY ROUTE · %s" % ("JUMP BACK UP! · SPACE" if target_distance <= LOW_LEDGE_DETECTION_RADIUS else "SWIM TO LOW LEDGE"))
				_apply_manual_recovery_swim(racer, water_y, delta)
			else:
				_apply_ai_recovery_swim(racer, target, water_y, delta)

		TARGET_ROOT:
			_set_ux_state(racer, RecoveryUXState.ROOT_APPROACH)
			if target_distance <= ROOT_AUTO_ATTACH_RADIUS:
				_begin_root_climb(racer, target)
				return
			if controlled_by_player:
				_set_hud_message("RECOVERY ROUTE · SWIM TO THE ROOT")
				_apply_manual_recovery_swim(racer, water_y, delta)
			else:
				_apply_ai_recovery_swim(racer, target, water_y, delta)

		TARGET_LADDER:
			_set_ux_state(racer, RecoveryUXState.LADDER_APPROACH)
			_ladder_by_id[racer_id] = target
			if target_distance <= LADDER_AUTO_ATTACH_RADIUS:
				_begin_ladder_climb(racer, target)
				return
			if controlled_by_player:
				_set_hud_message("RECOVERY ROUTE · SWIM TO THE LADDER · %.0fm" % target_distance)
				_apply_manual_recovery_swim(racer, water_y, delta)
			else:
				_apply_ai_recovery_swim(racer, {"entry": target.get("bottom", racer.global_position)}, water_y, delta)

		_:
			_set_ux_state(racer, RecoveryUXState.SWIMMING)
			if controlled_by_player:
				_apply_manual_recovery_swim(racer, water_y, delta)

func _begin_auto_vault(racer: WildDashCharacterController, entry: Dictionary) -> void:
	_set_ux_state(racer, RecoveryUXState.AUTO_VAULT)
	_set_traversal_action_lock(racer, true)
	super(racer, entry)

func _begin_root_climb(racer: WildDashCharacterController, ramp: Dictionary) -> void:
	_set_ux_state(racer, RecoveryUXState.ROOT_CLIMB)
	_set_traversal_action_lock(racer, true)
	super(racer, ramp)

func _begin_ladder_climb(racer: WildDashCharacterController, ladder: Dictionary) -> void:
	_set_ux_state(racer, RecoveryUXState.LADDER_ALIGN)
	_set_traversal_action_lock(racer, true)
	super(racer, ladder)

func _update_ladder_climb(racer: WildDashCharacterController, delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	var racer_id: int = racer.get_instance_id()
	var kind := StringName(_traversal_kind_by_id.get(racer_id, &""))
	match kind:
		&"auto_vault": _set_ux_state(racer, RecoveryUXState.AUTO_VAULT)
		&"root_climb": _set_ux_state(racer, RecoveryUXState.ROOT_CLIMB)
		&"ladder_align": _set_ux_state(racer, RecoveryUXState.LADDER_ALIGN)
		&"ladder_climb": _set_ux_state(racer, RecoveryUXState.LADDER_CLIMB)
		&"ladder_exit": _set_ux_state(racer, RecoveryUXState.SAFE_EXIT)
	_set_traversal_action_lock(racer, true)
	super(racer, delta)

func _finish_water_recovery(racer: WildDashCharacterController) -> void:
	if racer == null:
		return
	_set_ux_state(racer, RecoveryUXState.SAFE_EXIT)
	_clear_recovery_camera_focus_if_needed(racer)
	_set_traversal_action_lock(racer, false)
	super(racer)
	_set_ux_state(racer, RecoveryUXState.RACING)
	_clear_v9_runtime(racer.get_instance_id())

func _finish_assisted_recovery(racer: WildDashCharacterController, exit_position: Vector3, message: String) -> void:
	if racer == null:
		return
	_set_ux_state(racer, RecoveryUXState.SAFE_EXIT)
	_clear_recovery_camera_focus_if_needed(racer)
	_set_traversal_action_lock(racer, false)
	super(racer, exit_position, message)
	_set_ux_state(racer, RecoveryUXState.RACING)
	_clear_v9_runtime(racer.get_instance_id())

func _start_checkpoint_fallback(racer: WildDashCharacterController, reason: String) -> void:
	if racer != null:
		_clear_recovery_camera_focus_if_needed(racer)
		_set_traversal_action_lock(racer, false)
	super(racer, reason)

func get_recovery_ux_state(racer: WildDashCharacterController) -> StringName:
	if racer == null:
		return &"RACING"
	return _ux_state_name(int(_ux_state_by_id.get(racer.get_instance_id(), RecoveryUXState.RACING)))

func _choose_recovery_target(racer: WildDashCharacterController, zone: int) -> Dictionary:
	if racer == null or _ladder_system == null:
		return {}
	var candidates: Array[Dictionary] = []

	if _ladder_system.has_method("get_jump_outs_for_zone"):
		var jumps_value: Variant = _ladder_system.call("get_jump_outs_for_zone", zone)
		if jumps_value is Array:
			for value: Variant in jumps_value:
				if not (value is Dictionary):
					continue
				var candidate: Dictionary = value.duplicate(true)
				if float(candidate.get("height", 99.0)) > MAX_JUMP_OUT_HEIGHT:
					continue
				candidate["recovery_type"] = TARGET_JUMP_OUT
				candidates.append(candidate)

	if _ladder_system.has_method("get_root_ramps_for_zone"):
		var roots_value: Variant = _ladder_system.call("get_root_ramps_for_zone", zone)
		if roots_value is Array:
			for value: Variant in roots_value:
				if not (value is Dictionary):
					continue
				var candidate: Dictionary = value.duplicate(true)
				candidate["recovery_type"] = TARGET_ROOT
				candidates.append(candidate)

	if _ladder_system.has_method("get_all_ladders"):
		var ladders_value: Variant = _ladder_system.call("get_all_ladders")
		if ladders_value is Array:
			for value: Variant in ladders_value:
				if not (value is Dictionary):
					continue
				var candidate: Dictionary = value.duplicate(true)
				candidate["recovery_type"] = TARGET_LADDER
				candidates.append(candidate)

	if candidates.is_empty():
		return {}

	var best: Dictionary = {}
	var best_score: float = INF
	for candidate: Dictionary in candidates:
		var score: float = _score_recovery_target(racer, candidate, zone)
		candidate["target_score"] = score
		if score < best_score:
			best_score = score
			best = candidate

	var racer_id: int = racer.get_instance_id()
	var current_value: Variant = _preferred_target_by_id.get(racer_id, {})
	if current_value is Dictionary and not (current_value as Dictionary).is_empty():
		var current: Dictionary = (current_value as Dictionary).duplicate(true)
		var current_score: float = _score_recovery_target(racer, current, zone)
		if current_score <= best_score + TARGET_SWITCH_HYSTERESIS:
			current["target_score"] = current_score
			return current
	return best

func _score_recovery_target(racer: WildDashCharacterController, target: Dictionary, current_zone: int) -> float:
	var recovery_type := StringName(target.get("recovery_type", &""))
	var score: float = _distance_to_target(racer, target)
	match recovery_type:
		TARGET_JUMP_OUT:
			score += JUMP_OUT_TYPE_BIAS
			score += maxf(0.0, float(target.get("height", 0.0)) - 1.0) * 0.35
		TARGET_ROOT:
			score += ROOT_TYPE_BIAS
		TARGET_LADDER:
			score += LADDER_TYPE_BIAS
		_:
			score += 8.0

	var target_zone: int = int(target.get("zone", current_zone))
	if target_zone != current_zone:
		score += absf(float(target_zone - current_zone)) * WRONG_ZONE_PENALTY
	var checkpoint_progress: int = RaceManager.get_checkpoint_progress(racer)
	if target_zone < checkpoint_progress - 1:
		score += float(checkpoint_progress - target_zone) * BEHIND_PROGRESS_PENALTY

	var point := _target_point(target, racer.global_position)
	var congestion: int = _count_recovery_racers_near(point, racer)
	score += float(congestion) * CONGESTION_PENALTY_PER_RACER
	if not racer.is_player and _player_is_near(point):
		score += AI_PLAYER_YIELD_PENALTY
	return score

func _distance_to_target(racer: WildDashCharacterController, target: Dictionary) -> float:
	var point := _target_point(target, racer.global_position)
	return Vector2(racer.global_position.x - point.x, racer.global_position.z - point.z).length()

func _target_point(target: Dictionary, fallback: Vector3) -> Vector3:
	var recovery_type := StringName(target.get("recovery_type", &""))
	var value: Variant = target.get("bottom", fallback) if recovery_type == TARGET_LADDER else target.get("entry", fallback)
	return value if value is Vector3 else fallback

func _count_recovery_racers_near(point: Vector3, self_racer: WildDashCharacterController) -> int:
	var count: int = 0
	for value: Variant in RaceManager.racers:
		var other := value as WildDashCharacterController
		if other == null or not is_instance_valid(other) or other == self_racer:
			continue
		if not is_water_recovering(other):
			continue
		if Vector2(other.global_position.x - point.x, other.global_position.z - point.z).length() <= CONGESTION_RADIUS:
			count += 1
	return count

func _player_is_near(point: Vector3) -> bool:
	for value: Variant in RaceManager.racers:
		var other := value as WildDashCharacterController
		if other == null or not is_instance_valid(other) or not other.is_player:
			continue
		if not is_water_recovering(other):
			continue
		if Vector2(other.global_position.x - point.x, other.global_position.z - point.z).length() <= PLAYER_PRIORITY_RADIUS:
			return true
	return false

func _update_recovery_camera_focus(racer: WildDashCharacterController, target: Dictionary) -> void:
	if racer == null or not racer.is_player or DisplayServer.get_name() == "headless":
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or not camera.has_method("set_recovery_focus"):
		return
	camera.call("set_recovery_focus", _target_point(target, racer.global_position))

func _clear_recovery_camera_focus_if_needed(racer: WildDashCharacterController) -> void:
	if racer == null or not racer.is_player or DisplayServer.get_name() == "headless":
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null and camera.has_method("clear_recovery_focus"):
		camera.call("clear_recovery_focus")

func _set_ux_state(racer: WildDashCharacterController, state: int) -> void:
	if racer == null:
		return
	var racer_id: int = racer.get_instance_id()
	_ux_state_by_id[racer_id] = state
	racer.set_meta(&"logspire_recovery_ux_state", _ux_state_name(state))

func _ux_state_name(state: int) -> StringName:
	match state:
		RecoveryUXState.FALLING: return &"FALLING"
		RecoveryUXState.WATER_ENTRY: return &"WATER_ENTRY"
		RecoveryUXState.SWIMMING: return &"SWIMMING"
		RecoveryUXState.JUMP_OUT_APPROACH: return &"JUMP_OUT_APPROACH"
		RecoveryUXState.AUTO_VAULT: return &"AUTO_VAULT"
		RecoveryUXState.ROOT_APPROACH: return &"ROOT_APPROACH"
		RecoveryUXState.ROOT_CLIMB: return &"ROOT_CLIMB"
		RecoveryUXState.LADDER_APPROACH: return &"LADDER_APPROACH"
		RecoveryUXState.LADDER_ALIGN: return &"LADDER_ALIGN"
		RecoveryUXState.LADDER_CLIMB: return &"LADDER_CLIMB"
		RecoveryUXState.SAFE_EXIT: return &"SAFE_EXIT"
		_: return &"RACING"

func _set_traversal_action_lock(racer: WildDashCharacterController, locked: bool) -> void:
	if racer == null:
		return
	racer.set_meta(&"logspire_traversal_action_lock", locked)

func _clear_v9_runtime(racer_id: int) -> void:
	_preferred_target_by_id.erase(racer_id)
	_ux_state_by_id.erase(racer_id)
