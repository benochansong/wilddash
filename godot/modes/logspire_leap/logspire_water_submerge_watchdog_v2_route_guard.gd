extends "res://modes/logspire_leap/logspire_water_submerge_watchdog.gd"

## Round 3 false water-reset repair.
##
## The production upper river uses a deliberately generous invisible Area3D. In
## full play that volume can overlap Titan Tree route space. The original hard
## watchdog only had an authored support guard for Z6 and could therefore treat a
## brief floor/seam miss on Z5 as deep water, producing the visible
## "BACK TO THE RACE · WATER RESET" even though the racer never fell.
##
## This layer keeps the hard escape for genuine water failures, but makes reset a
## last-resort decision: authored Safe Route support, recent support grace, the
## WaterRecovery real-entry predicate, and sustained downward motion must all be
## cleared before the hard-reset timer may accumulate.

const ROUTE_HARD_SUBMERGE_CONFIRM_SECONDS: float = 0.32
const ROUTE_SUPPORT_EXTRA_RADIUS: float = 1.15
const ROUTE_SUPPORT_VERTICAL_BELOW: float = 0.38
const ROUTE_SUPPORT_VERTICAL_ABOVE: float = 1.45
const ROUTE_SUPPORT_GRACE_SECONDS: float = 0.55
const ROUTE_HARD_MIN_DESCENT_SPEED: float = -0.18
const ROUTE_GUARD_LOG_COOLDOWN_MSEC: int = 1500

var _route_support_ids: Array[StringName] = []
var _last_route_support_msec_by_id: Dictionary = {}
var _route_guard_last_log_msec_by_id: Dictionary = {}

func _ready() -> void:
	super()
	print("LOGSPIRE SUBMERGE WATCHDOG V2 READY confirm=%.2fs route_support_guard=true recent_support_grace=%.2fs strict_water_authority=true descent_required=true false_reset_block=true" % [
		ROUTE_HARD_SUBMERGE_CONFIRM_SECONDS,
		ROUTE_SUPPORT_GRACE_SECONDS,
	])

func _physics_process(delta: float) -> void:
	if _water == null or _graph == null or not RaceManager.active:
		return
	_ensure_route_support_ids()

	for value: Variant in RaceManager.racers.duplicate():
		var racer := value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer.finished:
			continue
		var racer_id: int = racer.get_instance_id()
		var pool: Dictionary = _pool_for_racer(racer)
		if pool.is_empty():
			_clear_candidate(racer_id)
			continue
		var water_y: float = float(pool.get("water_y", racer.global_position.y))
		var submerged_depth: float = water_y - racer.global_position.y
		if submerged_depth < HARD_SUBMERGE_DEPTH:
			_clear_candidate(racer_id)
			continue

		# Floor/support authority always wins over the broad invisible river volume.
		var route_support_id: StringName = _authored_route_support_platform(racer)
		if racer.is_on_floor() or _has_surface_support(racer) or route_support_id != &"":
			_remember_route_support(racer_id)
			_clear_candidate(racer_id)
			if route_support_id != &"":
				_log_false_reset_blocked(racer, route_support_id, submerged_depth, "authored_route")
			continue

		# Losing floor contact at a platform edge or bridge seam for a handful of
		# physics frames is not a water fall. Preserve the last confirmed support long
		# enough to cover a normal Round 3 jump arc.
		if _has_recent_route_support(racer_id):
			_clear_candidate(racer_id)
			_log_false_reset_blocked(racer, &"RECENT_SAFE_ROUTE", submerged_depth, "support_grace")
			continue

		if _vine_rescue_active(racer_id):
			_clear_candidate(racer_id)
			continue

		# Reuse WaterRecovery's stricter real-entry test. It already requires feet
		# below water, no nearby support and downward movement. The watchdog must not
		# be a less-safe second authority than the primary recovery system.
		if _water.has_method("should_handle_racer") and not bool(_water.call("should_handle_racer", racer)):
			_clear_candidate(racer_id)
			_log_false_reset_blocked(racer, &"WATER_ENTRY_REJECTED", submerged_depth, "strict_water_authority")
			continue

		# A racer at a jump apex, rising from a ledge catch, or standing nearly still
		# cannot accumulate a hard-reset timer merely because an invisible pool
		# overlaps their coordinates.
		if racer.velocity.y > ROUTE_HARD_MIN_DESCENT_SPEED:
			_clear_candidate(racer_id)
			_log_false_reset_blocked(racer, &"NOT_DESCENDING", submerged_depth, "descent_guard")
			continue

		var elapsed: float = float(_submerged_elapsed_by_id.get(racer_id, 0.0)) + delta
		_submerged_elapsed_by_id[racer_id] = elapsed
		if elapsed < ROUTE_HARD_SUBMERGE_CONFIRM_SECONDS:
			continue

		print("r3_true_water_reset_confirmed racer=%s depth=%.2f elapsed=%.2f unsupported=true descending=true strict_water_authority=true" % [
			RaceManager.get_racer_label(racer), submerged_depth, elapsed,
		])
		_hard_checkpoint_escape(racer, submerged_depth)
		_clear_candidate(racer_id)

func _ensure_route_support_ids() -> void:
	if not _route_support_ids.is_empty() or _graph == null or not _graph.has_method("get_route_ids"):
		return
	var value: Variant = _graph.call("get_route_ids", &"safe")
	if not (value is Array):
		return
	for item: Variant in value:
		if item is StringName:
			_route_support_ids.append(item)
		elif item is String:
			_route_support_ids.append(StringName(item))
	print("LOGSPIRE WATER ROUTE SUPPORT CACHE platforms=%d includes_titan=true includes_finale=true graph_top_is_surface=true" % _route_support_ids.size())

func _authored_route_support_platform(racer: WildDashCharacterController) -> StringName:
	if racer == null or not is_instance_valid(racer) or _graph == null:
		return &""
	for platform_id: StringName in _route_support_ids:
		var position_value: Variant = _graph.call("get_platform_position", platform_id)
		if not (position_value is Vector3):
			continue
		var top: Vector3 = position_value
		var landing_radius: float = 4.0
		if _graph.has_method("get_landing_radius"):
			landing_radius = maxf(3.0, float(_graph.call("get_landing_radius", platform_id)))
		var planar_distance: float = Vector2(
			racer.global_position.x - top.x,
			racer.global_position.z - top.z
		).length()
		var foot_delta: float = racer.global_position.y - top.y
		if planar_distance <= landing_radius + ROUTE_SUPPORT_EXTRA_RADIUS and foot_delta >= -ROUTE_SUPPORT_VERTICAL_BELOW and foot_delta <= ROUTE_SUPPORT_VERTICAL_ABOVE:
			return platform_id
	return &""

func _remember_route_support(racer_id: int) -> void:
	_last_route_support_msec_by_id[racer_id] = Time.get_ticks_msec()

func _has_recent_route_support(racer_id: int) -> bool:
	if not _last_route_support_msec_by_id.has(racer_id):
		return false
	var now_msec: int = Time.get_ticks_msec()
	var last_msec: int = int(_last_route_support_msec_by_id.get(racer_id, -1000000))
	return float(now_msec - last_msec) / 1000.0 <= ROUTE_SUPPORT_GRACE_SECONDS

func _clear_candidate(racer_id: int) -> void:
	_submerged_elapsed_by_id.erase(racer_id)

func _log_false_reset_blocked(
	racer: WildDashCharacterController,
	platform_id: StringName,
	submerged_depth: float,
	reason: String
) -> void:
	if racer == null or not racer.is_player:
		return
	var racer_id: int = racer.get_instance_id()
	var now_msec: int = Time.get_ticks_msec()
	var last_msec: int = int(_route_guard_last_log_msec_by_id.get(racer_id, -1000000))
	if now_msec - last_msec < ROUTE_GUARD_LOG_COOLDOWN_MSEC:
		return
	_route_guard_last_log_msec_by_id[racer_id] = now_msec
	print("r3_false_water_reset_blocked racer=%s object=%s depth=%.2f reason=%s no_rewind=true" % [
		RaceManager.get_racer_label(racer), String(platform_id), submerged_depth, reason,
	])
