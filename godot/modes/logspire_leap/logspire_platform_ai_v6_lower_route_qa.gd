extends "res://modes/logspire_leap/logspire_platform_ai_v5_phase_b.gd"

## Titan lower-route QA adapter.
##
## Generic race AI and the old Finale contender layer both have positional
## hard-recovery tools. They remain available outside CP4 -> CP5, but this layer
## makes the new lower Titan route a no-teleport corridor. Normal steering,
## obstacle avoidance and airborne correction continue to work. If route index
## progress stalls, the driver recomputes its route index from the current body
## position; neither racer transform nor checkpoint progress is written.

const LOWER_REACQUIRE_SECONDS: float = 3.0
const LOWER_ROUTE_PREFIXES: Array[String] = [
	"Z5_ROOT_RUN_",
	"Z5_BROKEN_TRUNK_",
	"Z5_FORK_SAFE_",
	"Z5_FORK_FAST_",
	"Z5_CANOPY_",
	"Z5_FINAL_",
]

var _lower_last_route_index: int = -1
var _lower_stagnant_seconds: float = 0.0
var _lower_reacquire_count: int = 0

func configure(
	racer: WildDashCharacterController,
	driver: WildDashAIController,
	graph: Node,
	gameplay: Node,
	route_points: Array[Vector3],
	safe_route_points: Array[Vector3],
	route_platform_ids: Array[StringName],
	safe_platform_ids: Array[StringName],
	route_id: StringName
) -> void:
	super(racer, driver, graph, gameplay, route_points, safe_route_points, route_platform_ids, safe_platform_ids, route_id)
	_lower_last_route_index = driver.get_route_index() if driver != null else -1
	print("LOGSPIRE PLATFORM AI V6 LOWER QA racer=%s route=%s cp4_cp5_teleport=false steering_recovery=true route_reacquire=true checkpoint_write=false" % [
		RaceManager.get_racer_label(racer), String(route_id),
	])

func _physics_process(delta: float) -> void:
	super(delta)
	_guard_lower_route_recovery(delta)

func _guard_lower_route_recovery(delta: float) -> void:
	if _racer == null or _driver == null or _route.is_empty():
		return
	if _racer.finished or not RaceManager.active:
		return
	var target_index: int = clampi(_driver.get_route_index(), 1, _route.size() - 1)
	var platform_id: StringName = _platform_id_for_index(target_index)
	if not _is_lower_route_platform(platform_id):
		_lower_stagnant_seconds = 0.0
		_lower_last_route_index = target_index
		return

	# The shared AI driver's hard-stuck clock normally ends in reset_motion().
	# Keep that clock at zero only inside the authored CP4 -> CP5 corridor. Its
	# ordinary soft steering recovery remains untouched.
	_driver.set("_recovery_stagnant_seconds", 0.0)
	_driver.set("_same_checkpoint_recoveries", 0)

	if target_index != _lower_last_route_index:
		_lower_last_route_index = target_index
		_lower_stagnant_seconds = 0.0
		return
	_lower_stagnant_seconds += delta
	if _lower_stagnant_seconds < LOWER_REACQUIRE_SECONDS:
		return

	# set_race_route() finds the nearest forward index from the racer's CURRENT
	# position. It does not move the racer and does not mutate checkpoint state.
	_driver.set_race_route(_route)
	_driver.steering_strength = maxf(_driver.steering_strength, 9.0)
	_driver.avoidance_distance = maxf(_driver.avoidance_distance, 5.8)
	_lower_last_route_index = _driver.get_route_index()
	_lower_stagnant_seconds = 0.0
	_lower_reacquire_count += 1
	print("R3 TITAN AI ROUTE REACQUIRE racer=%s platform=%s route=%s count=%d teleport=false checkpoint_write=false speed_boost=false" % [
		RaceManager.get_racer_label(_racer), String(platform_id), String(_route_id), _lower_reacquire_count,
	])

func _is_contender_late_target(platform_id: StringName) -> bool:
	if _is_lower_route_platform(platform_id):
		return false
	return super(platform_id)

func _is_lower_route_platform(platform_id: StringName) -> bool:
	var text: String = String(platform_id)
	for prefix: String in LOWER_ROUTE_PREFIXES:
		if text.begins_with(prefix):
			return true
	return false

func get_lower_route_reacquire_count() -> int:
	return _lower_reacquire_count
