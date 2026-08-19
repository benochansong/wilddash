extends "res://modes/logspire_leap/logspire_water_recovery_v12_reliability_authority.gd"

## Integrated Round 3 reliability guard.
## V12 remains the gameplay authority. This layer only publishes explicit motion
## ownership, records bounded QA events, and protects one SAFE_EXIT physics frame
## before jump/landing assists may resume.

const DEEP_WATER_FAIL_SECONDS: float = 0.75

var _surface_reacquire_recorded_by_id: Dictionary = {}
var _deep_water_elapsed_by_id: Dictionary = {}
var _deep_water_fail_recorded_by_id: Dictionary = {}

func _physics_process(delta: float) -> void:
	super(delta)
	if not _configured or not RaceManager.active:
		return

	for value: Variant in RaceManager.racers.duplicate():
		var racer := value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer.finished:
			continue
		var racer_id: int = racer.get_instance_id()
		if not is_water_recovering(racer):
			_deep_water_elapsed_by_id.erase(racer_id)
			continue

		var traversal_kind := StringName(_traversal_kind_by_id.get(racer_id, &""))
		_qa_set_state(racer, &"RECOVERY" if traversal_kind != &"" else &"WATER", "water_authority")
		if traversal_kind != &"":
			_deep_water_elapsed_by_id.erase(racer_id)
			continue

		var pool: Dictionary = _pool_for_position(racer.global_position)
		if pool.is_empty():
			_deep_water_elapsed_by_id.erase(racer_id)
			continue
		var water_y: float = float(pool.get("water_y", racer.global_position.y))
		if racer.global_position.y < water_y - DEEP_WATER_GUARD_DEPTH:
			var elapsed: float = float(_deep_water_elapsed_by_id.get(racer_id, 0.0)) + delta
			_deep_water_elapsed_by_id[racer_id] = elapsed
			if elapsed >= DEEP_WATER_FAIL_SECONDS and not bool(_deep_water_fail_recorded_by_id.get(racer_id, false)):
				_deep_water_fail_recorded_by_id[racer_id] = true
				_qa_record_metric(&"deep_water_fail", racer, int(pool.get("zone", 0)))
				print("LOGSPIRE DEEP WATER FAIL racer=%s zone=%d duration=%.2f bounded_recovery_continues=true" % [
					RaceManager.get_racer_label(racer), int(pool.get("zone", 0)) + 1, elapsed,
				])
		else:
			_deep_water_elapsed_by_id[racer_id] = 0.0

func _enter_water(racer: WildDashCharacterController, zone: int, water_y: float) -> void:
	if racer != null and is_instance_valid(racer):
		var racer_id: int = racer.get_instance_id()
		_surface_reacquire_recorded_by_id.erase(racer_id)
		_deep_water_elapsed_by_id.erase(racer_id)
		_deep_water_fail_recorded_by_id.erase(racer_id)
		_qa_record_metric(&"water_enter", racer, zone)
	super(racer, zone, water_y)
	if racer != null and is_instance_valid(racer) and is_water_recovering(racer):
		_qa_set_state(racer, &"WATER", "water_enter")

func _update_swimming(racer: WildDashCharacterController, delta: float) -> void:
	_qa_set_state(racer, &"WATER", "swimming")
	super(racer, delta)

func _enforce_surface_lock(racer: WildDashCharacterController, water_y: float, delta: float) -> void:
	if racer != null and is_instance_valid(racer):
		var racer_id: int = racer.get_instance_id()
		var target_y: float = water_y + SURFACE_LOCK_OFFSET
		if target_y - racer.global_position.y > SURFACE_LOCK_TOLERANCE and not bool(_surface_reacquire_recorded_by_id.get(racer_id, false)):
			_surface_reacquire_recorded_by_id[racer_id] = true
			var pool: Dictionary = _pool_for_position(racer.global_position)
			_qa_record_metric(&"surface_reacquire", racer, int(pool.get("zone", int(_zone_by_id.get(racer_id, 0)))))
	super(racer, water_y, delta)

func _begin_root_climb(racer: WildDashCharacterController, ramp: Dictionary) -> void:
	super(racer, ramp)
	if racer == null or not is_instance_valid(racer):
		return
	var kind := StringName(_traversal_kind_by_id.get(racer.get_instance_id(), &""))
	if kind == &"root_climb":
		_qa_set_state(racer, &"RECOVERY", "root_climb")

func _begin_ladder_climb(racer: WildDashCharacterController, ladder: Dictionary) -> void:
	super(racer, ladder)
	if racer == null or not is_instance_valid(racer):
		return
	var kind := StringName(_traversal_kind_by_id.get(racer.get_instance_id(), &""))
	if kind in [&"ladder_align", &"ladder_climb", &"ladder_exit"]:
		_qa_set_state(racer, &"RECOVERY", "ladder_climb")

func _begin_vine_rescue(racer: WildDashCharacterController) -> void:
	super(racer)
	if racer != null and is_instance_valid(racer) and StringName(_traversal_kind_by_id.get(racer.get_instance_id(), &"")) == &"vine_rescue":
		_qa_set_state(racer, &"RECOVERY", "vine_fail_safe")

func _finish_assisted_recovery(racer: WildDashCharacterController, exit_position: Vector3, message: String) -> void:
	var kind: StringName = &""
	var zone: int = 0
	if racer != null and is_instance_valid(racer):
		var racer_id: int = racer.get_instance_id()
		kind = StringName(_traversal_kind_by_id.get(racer_id, &""))
		zone = int(_zone_by_id.get(racer_id, 0))
	super(racer, exit_position, message)
	if racer == null or not is_instance_valid(racer) or is_water_recovering(racer):
		return
	if kind == &"root_climb":
		_qa_record_metric(&"root_success", racer, zone)
	elif kind in [&"ladder_align", &"ladder_climb", &"ladder_exit"]:
		_qa_record_metric(&"ladder_success", racer, zone)
	_qa_begin_safe_exit(racer, "assisted_recovery")

func _finish_water_recovery(racer: WildDashCharacterController) -> void:
	var kind: StringName = &""
	var zone: int = 0
	if racer != null and is_instance_valid(racer):
		var racer_id: int = racer.get_instance_id()
		kind = StringName(_traversal_kind_by_id.get(racer_id, &""))
		zone = int(_zone_by_id.get(racer_id, 0))
	super(racer)
	if racer == null or not is_instance_valid(racer) or is_water_recovering(racer):
		return
	if kind in [&"ladder_align", &"ladder_climb", &"ladder_exit"]:
		_qa_record_metric(&"ladder_success", racer, zone)
	_qa_begin_safe_exit(racer, "water_recovery")

func _handle_recovery_stuck(racer: WildDashCharacterController) -> void:
	if racer != null and is_instance_valid(racer):
		_qa_record_metric(&"recovery_stuck", racer, int(_zone_by_id.get(racer.get_instance_id(), 0)))
	super(racer)

func _clear_reliability_runtime(racer_id: int) -> void:
	_surface_reacquire_recorded_by_id.erase(racer_id)
	_deep_water_elapsed_by_id.erase(racer_id)
	_deep_water_fail_recorded_by_id.erase(racer_id)
	super(racer_id)

func _qa_begin_safe_exit(racer: WildDashCharacterController, source: String) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	_qa_set_state(racer, &"SAFE_EXIT", source)
	_qa_release_safe_exit_after_frame(racer.get_instance_id())

func _qa_release_safe_exit_after_frame(racer_id: int) -> void:
	await get_tree().physics_frame
	var racer := _qa_find_racer(racer_id)
	if racer == null or not is_instance_valid(racer) or is_water_recovering(racer):
		return
	_qa_set_state(racer, &"NORMAL" if racer.is_on_floor() else &"AIRBORNE", "safe_exit_complete")

func _qa_find_racer(racer_id: int) -> WildDashCharacterController:
	for value: Variant in RaceManager.racers:
		var racer := value as WildDashCharacterController
		if racer != null and is_instance_valid(racer) and racer.get_instance_id() == racer_id:
			return racer
	return null

func _qa_set_state(racer: WildDashCharacterController, state: StringName, source: String) -> void:
	var mode := get_parent()
	if mode != null and mode.has_method("reliability_set_motion_state"):
		mode.call("reliability_set_motion_state", racer, state, source)

func _qa_record_metric(metric: StringName, racer: WildDashCharacterController, zone_index: int) -> void:
	var mode := get_parent()
	if mode == null or not mode.has_method("reliability_record_metric"):
		return
	var zone_name: String = ""
	if mode.has_method("reliability_zone_name_from_index"):
		zone_name = String(mode.call("reliability_zone_name_from_index", zone_index))
	mode.call("reliability_record_metric", metric, racer, &"", zone_name)
