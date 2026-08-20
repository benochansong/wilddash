extends Node

## Final Round 3 submerged fail-safe.
## WaterRecovery keeps the authored Vine Rescue path, but no racer may remain
## stranded below the water surface because recovery state or target selection
## became inconsistent. A genuinely submerged, unsupported racer that is not
## already moving through a Vine Rescue is reset to a bounded Safe Route exit.
##
## Sky Log Finale adds a route-support guard in front of this fail-safe. The
## generic water sampler remains authoritative, but authored Z6/Crown platform
## geometry is also checked so a supported racer cannot be mistaken for a deep
## swimmer because one ray missed a thin edge or seam. Genuine Finale water falls
## recover to the nearest bounded Z6 platform instead of snapping all the way
## back to the single Z6_START checkpoint.

const WATER_META: StringName = &"logspire_water_recovery_active"
const TRAVERSAL_LOCK_META: StringName = &"logspire_traversal_action_lock"
const HARD_SUBMERGE_DEPTH: float = 0.58
const HARD_SUBMERGE_CONFIRM_SECONDS: float = 0.14
const HARD_SPAWN_HEIGHT: float = 1.24
const HARD_RUNWAY_BACKOFF_MIN: float = 0.80
const HARD_RUNWAY_BACKOFF_MAX: float = 1.60
const FINALE_SUPPORT_VERTICAL_BELOW: float = 0.25
const FINALE_SUPPORT_VERTICAL_ABOVE: float = 1.55
const FINALE_SUPPORT_EXTRA_RADIUS: float = 0.90
const FINALE_RECOVERY_MAX_PLANAR_DISTANCE: float = 12.5
const FINALE_GUARD_LOG_COOLDOWN_MSEC: int = 1500
const FINALE_SUPPORT_IDS: Array[StringName] = [
	&"Z6_START",
	&"Z6_01",
	&"Z6_02",
	&"Z6_03",
	&"Z6_04",
	&"Z6_05",
	&"Z6_06",
	&"Z6_07",
	&"CROWN_NEST",
]
const FINALE_RECOVERY_IDS: Array[StringName] = [
	&"Z6_START",
	&"Z6_01",
	&"Z6_02",
	&"Z6_03",
	&"Z6_04",
	&"Z6_05",
	&"Z6_06",
	&"Z6_07",
]

var _water: Node
var _graph: Node
var _recovery: Node
var _submerged_elapsed_by_id: Dictionary = {}
var _finale_guard_last_log_msec_by_id: Dictionary = {}

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
	print("LOGSPIRE SUBMERGE WATCHDOG READY depth=%.2fm confirm=%.2fs direct_checkpoint=true swim_stall=false camera_reset=true finale_support_guard=true" % [
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

		# Support always wins over visual/Area water overlap. The generic nine-ray
		# probe handles arbitrary geometry; the Finale route guard additionally
		# recognizes the authored flat Z6 platforms by their known landing bounds.
		var finale_support_id: StringName = _finale_route_support_platform(racer)
		if _has_surface_support(racer) or finale_support_id != &"":
			_submerged_elapsed_by_id.erase(racer_id)
			if finale_support_id != &"":
				_log_finale_false_water_blocked(racer, finale_support_id, submerged_depth)
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

func _finale_route_support_platform(racer: WildDashCharacterController) -> StringName:
	if racer == null or not is_instance_valid(racer) or _graph == null:
		return &""
	for platform_id: StringName in FINALE_SUPPORT_IDS:
		var position_value: Variant = _graph.call("get_platform_position", platform_id)
		if not (position_value is Vector3):
			continue
		var position: Vector3 = position_value
		var landing_radius: float = 4.0
		if _graph.has_method("get_landing_radius"):
			landing_radius = maxf(3.0, float(_graph.call("get_landing_radius", platform_id)))
		var planar_distance: float = Vector2(
			racer.global_position.x - position.x,
			racer.global_position.z - position.z
		).length()
		var platform_top_y: float = position.y + 0.40
		var foot_delta: float = racer.global_position.y - platform_top_y
		if planar_distance <= landing_radius + FINALE_SUPPORT_EXTRA_RADIUS and foot_delta >= -FINALE_SUPPORT_VERTICAL_BELOW and foot_delta <= FINALE_SUPPORT_VERTICAL_ABOVE:
			return platform_id
	return &""

func _log_finale_false_water_blocked(
	racer: WildDashCharacterController,
	platform_id: StringName,
	submerged_depth: float
) -> void:
	if racer == null:
		return
	var racer_id: int = racer.get_instance_id()
	var now_msec: int = Time.get_ticks_msec()
	var last_msec: int = int(_finale_guard_last_log_msec_by_id.get(racer_id, -1000000))
	if now_msec - last_msec < FINALE_GUARD_LOG_COOLDOWN_MSEC:
		return
	_finale_guard_last_log_msec_by_id[racer_id] = now_msec
	print("r3_finale_false_water_blocked racer=%s source=submerge_watchdog object=%s depth=%.2f support_priority=true" % [
		RaceManager.get_racer_label(racer), String(platform_id), submerged_depth,
	])

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

	# The generic checkpoint list contains only Z6_START for the Finale. Use the
	# nearest non-finish Z6 platform when the fall is horizontally inside the
	# Finale corridor; this avoids a large backwards screen snap while preserving
	# a bounded, fair re-entry. Outside the Finale, retain the established logic.
	var finale_target_id: StringName = _nearest_finale_recovery_target(racer)
	var target_id: StringName = finale_target_id
	if target_id == &"":
		target_id = _latest_checkpoint_target(racer)
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
	var finale_recovery: bool = finale_target_id != &""
	if finale_recovery:
		print("r3_finale_recovery_trigger racer=%s source=submerge_watchdog target=%s depth=%.2f supported=false" % [
			RaceManager.get_racer_label(racer), String(target_id), submerged_depth,
		])

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
	if finale_recovery:
		print("r3_finale_recovery_exit racer=%s target=%s safe_spawn=true loop_guard=true source=submerge_watchdog" % [
			RaceManager.get_racer_label(racer), String(target_id),
		])
	print("LOGSPIRE HARD WATER ESCAPE racer=%s target=%s depth=%.2f checkpoint=%d immediate=true water_authority_cleared=true camera_normalized=true" % [
		RaceManager.get_racer_label(racer),
		String(target_id),
		submerged_depth,
		RaceManager.get_checkpoint_progress(racer),
	])

func _nearest_finale_recovery_target(racer: WildDashCharacterController) -> StringName:
	if racer == null or _graph == null:
		return &""
	var best_id: StringName = &""
	var best_distance: float = FINALE_RECOVERY_MAX_PLANAR_DISTANCE
	for platform_id: StringName in FINALE_RECOVERY_IDS:
		var position_value: Variant = _graph.call("get_platform_position", platform_id)
		if not (position_value is Vector3):
			continue
		var position: Vector3 = position_value
		var distance: float = Vector2(
			racer.global_position.x - position.x,
			racer.global_position.z - position.z
		).length()
		if distance <= best_distance:
			best_distance = distance
			best_id = platform_id
	return best_id

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
