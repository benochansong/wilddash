extends Node

## Final Round 3 submerged fail-safe.
## WaterRecovery keeps the authored Vine Rescue path, but no racer may remain
## stranded below the water surface because recovery state or target selection
## became inconsistent. A genuinely submerged, unsupported racer that is not
## already moving through a Vine Rescue is reset directly to the latest Safe
## Route checkpoint after a very short confirmation window.

const WATER_META: StringName = &"logspire_water_recovery_active"
const TRAVERSAL_LOCK_META: StringName = &"logspire_traversal_action_lock"
const HARD_SUBMERGE_DEPTH: float = 0.58
const HARD_SUBMERGE_CONFIRM_SECONDS: float = 0.14
const HARD_SPAWN_HEIGHT: float = 1.24
const HARD_RUNWAY_BACKOFF_MIN: float = 0.80
const HARD_RUNWAY_BACKOFF_MAX: float = 1.60

var _water: Node
var _graph: Node
var _recovery: Node
var _submerged_elapsed_by_id: Dictionary = {}

func _ready() -> void:
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	await get_tree().physics_frame
	var root := get_parent()
	if root == null:
		return
	_water = root.get_node_or_null("WaterRecovery")
	_graph = root.get_node_or_null("PlatformGraph")
	_recovery = root.get_node_or_null("RecoverySystem")
	if _water == null or _graph == null:
		push_error("LOGSPIRE SUBMERGE WATCHDOG INIT FAIL missing water/graph")
		return
	print("LOGSPIRE SUBMERGE WATCHDOG READY depth=%.2fm confirm=%.2fs direct_checkpoint=true swim_stall=false camera_reset=true" % [
		HARD_SUBMERGE_DEPTH, HARD_SUBMERGE_CONFIRM_SECONDS,
	])

func _physics_process(delta: float) -> void:
	if _water == null or _graph == null or not RaceManager.active:
		return

	for value: Variant in RaceManager.racers.duplicate():
		var racer := value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer.finished:
			continue
		var racer_id: int = racer.get_instance_id()
		var pool: Dictionary = _pool_for_racer(racer)
		if pool.is_empty():
			_submerged_elapsed_by_id.erase(racer_id)
			continue
		var water_y: float = float(pool.get("water_y", racer.global_position.y))
		var submerged_depth: float = water_y - racer.global_position.y
		if submerged_depth < HARD_SUBMERGE_DEPTH:
			_submerged_elapsed_by_id.erase(racer_id)
			continue
		if _has_surface_support(racer):
			_submerged_elapsed_by_id.erase(racer_id)
			continue
		if _vine_rescue_active(racer_id):
			_submerged_elapsed_by_id.erase(racer_id)
			continue

		var elapsed: float = float(_submerged_elapsed_by_id.get(racer_id, 0.0)) + delta
		_submerged_elapsed_by_id[racer_id] = elapsed
		if elapsed < HARD_SUBMERGE_CONFIRM_SECONDS:
			continue
		_hard_checkpoint_escape(racer, submerged_depth)
		_submerged_elapsed_by_id.erase(racer_id)

func _pool_for_racer(racer: WildDashCharacterController) -> Dictionary:
	if racer == null or not is_instance_valid(racer) or _water == null:
		return {}
	if not _water.has_method("_pool_for_position"):
		return {}
	var value: Variant = _water.call("_pool_for_position", racer.global_position)
	return value if value is Dictionary else {}

func _has_surface_support(racer: WildDashCharacterController) -> bool:
	if _water == null or not _water.has_method("_has_nearby_surface_support"):
		return racer.is_on_floor()
	return bool(_water.call("_has_nearby_surface_support", racer))

func _vine_rescue_active(racer_id: int) -> bool:
	if _water == null:
		return false
	var value: Variant = _water.get("_traversal_kind_by_id")
	if not (value is Dictionary):
		return false
	return StringName((value as Dictionary).get(racer_id, &"")) == &"vine_rescue"

func _hard_checkpoint_escape(racer: WildDashCharacterController, submerged_depth: float) -> void:
	if racer == null or not is_instance_valid(racer) or _graph == null:
		return
	var racer_id: int = racer.get_instance_id()
	var target_id: StringName = _latest_checkpoint_target(racer)
	if target_id == &"":
		target_id = _first_safe_route_target()
	if target_id == &"":
		push_warning("LOGSPIRE HARD WATER ESCAPE FAILED no checkpoint target")
		return

	var position_value: Variant = _graph.call("get_platform_position", target_id)
	if not (position_value is Vector3):
		return
	var target_position: Vector3 = position_value
	var forward_value: Variant = _graph.call("get_platform_forward", target_id, &"safe")
	var forward: Vector3 = forward_value if forward_value is Vector3 else Vector3.FORWARD
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var landing_radius: float = 4.0
	if _graph.has_method("get_landing_radius"):
		landing_radius = maxf(3.0, float(_graph.call("get_landing_radius", target_id)))
	var runway_backoff: float = clampf(
		landing_radius * 0.24,
		HARD_RUNWAY_BACKOFF_MIN,
		HARD_RUNWAY_BACKOFF_MAX
	)
	var safe_spawn: Vector3 = target_position - forward * runway_backoff + Vector3.UP * HARD_SPAWN_HEIGHT

	# Cancel all transform ownership left by the water stack before reset.
	if _recovery != null:
		_erase_dictionary_entry(_recovery, "_pending", racer_id)
	if _water.has_method("_release_racer_control"):
		_water.call("_release_racer_control", racer)
	if _water.has_method("_clear_reliability_runtime"):
		_water.call("_clear_reliability_runtime", racer_id)
	if _water.has_method("_clear_water_runtime"):
		_water.call("_clear_water_runtime", racer_id)
	for property_name: String in [
		"_traversal_kind_by_id",
		"_traversal_elapsed_by_id",
		"_traversal_duration_by_id",
		"_traversal_from_by_id",
		"_traversal_to_by_id",
		"_traversal_path_by_id",
		"_preferred_target_by_id",
		"_ladder_by_id",
	]:
		_erase_dictionary_entry(_water, property_name, racer_id)
	_set_water_state_racing(racer_id)

	if racer.has_meta(WATER_META):
		racer.remove_meta(WATER_META)
	if racer.has_meta(TRAVERSAL_LOCK_META):
		racer.remove_meta(TRAVERSAL_LOCK_META)
	racer.reset_motion(safe_spawn)
	racer.rotation.y = atan2(-forward.x, -forward.z)
	racer.current_speed = 0.0
	racer.velocity = Vector3.ZERO
	_reset_recovery_camera(racer)
	if _recovery != null and _recovery.has_method("begin_retry_grace"):
		_recovery.call("begin_retry_grace", racer, "hard_water_escape")
	if _water.has_method("_set_hud_message") and racer.is_player and DisplayServer.get_name() != "headless":
		_water.call("_set_hud_message", "BACK TO THE RACE · WATER RESET")
	print("LOGSPIRE HARD WATER ESCAPE racer=%s target=%s depth=%.2f checkpoint=%d immediate=true water_authority_cleared=true camera_normalized=true" % [
		RaceManager.get_racer_label(racer),
		String(target_id),
		submerged_depth,
		RaceManager.get_checkpoint_progress(racer),
	])

func _reset_recovery_camera(racer: WildDashCharacterController) -> void:
	if racer == null or not racer.is_player:
		return
	if _water != null and _water.has_method("_clear_recovery_camera_focus_if_needed"):
		_water.call("_clear_recovery_camera_focus_if_needed", racer)
	var root := get_parent()
	if root == null:
		return
	var camera := root.get_node_or_null("ChaseCamera") as Camera3D
	if camera == null:
		return
	if camera.has_method("clear_recovery_focus"):
		camera.call("clear_recovery_focus")
	if camera.has_method("clear_race_focus"):
		camera.call("clear_race_focus")
	# set_target immediately recalculates an obstruction-safe chase position, so
	# the first post-reset jump cannot inherit a water-camera transform buried in
	# Titan geometry.
	if camera.has_method("set_target"):
		camera.call("set_target", racer)
	print("LOGSPIRE WATER CAMERA RESET racer=%s recovery_mode=false race_focus=false obstruction_recheck=true" % RaceManager.get_racer_label(racer))

func _latest_checkpoint_target(racer: WildDashCharacterController) -> StringName:
	if racer == null or _graph == null or not _graph.has_method("get_last_checkpoint_id"):
		return &""
	var value: Variant = _graph.call("get_last_checkpoint_id", RaceManager.get_checkpoint_progress(racer))
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return &""

func _first_safe_route_target() -> StringName:
	if _graph == null or not _graph.has_method("get_route_ids"):
		return &""
	var value: Variant = _graph.call("get_route_ids", &"safe")
	if not (value is Array) or (value as Array).is_empty():
		return &""
	var first: Variant = (value as Array)[0]
	if first is StringName:
		return first
	if first is String:
		return StringName(first)
	return &""

func _erase_dictionary_entry(object: Object, property_name: String, racer_id: int) -> void:
	if object == null:
		return
	var value: Variant = object.get(property_name)
	if value is Dictionary:
		(value as Dictionary).erase(racer_id)

func _set_water_state_racing(racer_id: int) -> void:
	if _water == null:
		return
	var value: Variant = _water.get("_state_by_id")
	if value is Dictionary:
		# WaterState.RACING is the first enum value and therefore zero.
		(value as Dictionary)[racer_id] = 0
