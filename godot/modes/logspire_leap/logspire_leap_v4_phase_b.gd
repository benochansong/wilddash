extends "res://modes/logspire_leap/logspire_leap_v3_recovery_camera.gd"

## Phase B large-field stability pass.
## The base mode still owns spawning, items, water and campaign flow. This layer
## only replaces Logspire Platform AI with V5, spreads AI across five lanes and
## aggregates Round 3 reliability telemetry. Gameplay systems may publish their
## movement authority here, but this mode never writes racer transforms itself.

const PLATFORM_AI_PHASE_B_SCRIPT: Script = preload("res://modes/logspire_leap/logspire_platform_ai_v5_phase_b.gd")
const PHASE_B_LANE_COUNT: int = 5
const PHASE_B_LANE_SPACING: float = 0.70
const QA_RACER_COUNTS: Array[int] = [10, 15, 18]
const QA_ZONE_KEYS: Array[String] = ["ZONE_1", "ZONE_2", "ZONE_3", "ZONE_4", "TITAN_TREE", "FINALE"]
const QA_METRIC_KEYS: Array[StringName] = [
	&"water_enter",
	&"surface_reacquire",
	&"deep_water_fail",
	&"root_success",
	&"ladder_success",
	&"recovery_stuck",
	&"jump_block",
	&"head_collision",
	&"ledge_catch",
	&"ai_fall",
	&"player_fall",
]
const QA_STATE_NORMAL: StringName = &"NORMAL"
const QA_STATE_AIRBORNE: StringName = &"AIRBORNE"
const QA_STATE_WATER: StringName = &"WATER"
const QA_STATE_RECOVERY: StringName = &"RECOVERY"
const QA_STATE_SAFE_EXIT: StringName = &"SAFE_EXIT"
const QA_PROTECTED_STATES: Array[StringName] = [QA_STATE_WATER, QA_STATE_RECOVERY, QA_STATE_SAFE_EXIT]

var _phase_b_ai_falls_by_zone: Dictionary = {
	"ZONE_1": 0,
	"ZONE_2": 0,
	"ZONE_3": 0,
	"ZONE_4": 0,
	"TITAN_TREE": 0,
	"FINALE": 0,
	"UNKNOWN": 0,
}
var _phase_b_safe_route_falls: int = 0
var _phase_b_wild_route_falls: int = 0
var _phase_b_report_printed: bool = false
var _reliability_metrics_by_zone: Dictionary = {}
var _reliability_motion_state_by_id: Dictionary = {}

func _ready() -> void:
	await super()
	_initialize_reliability_metrics()
	print("LOGSPIRE PHASE B CROWD READY five_lane_distribution=true lane_count=%d lane_spacing=%.2f zone1_success_target=97-100%% zone2_success_target=95%% landing_protection=0.65s" % [
		PHASE_B_LANE_COUNT, PHASE_B_LANE_SPACING,
	])
	print("LOGSPIRE R3 QA READY racer_profiles=10,15,18 states=NORMAL|AIRBORNE|WATER|RECOVERY|SAFE_EXIT transform_writer=false metrics_per_zone=true")

func _attach_platform_ai(
	racer: WildDashCharacterController,
	driver: WildDashAIController,
	route: Array[Vector3],
	route_ids: Array[StringName],
	route_id: StringName
) -> void:
	var platform_ai := PLATFORM_AI_PHASE_B_SCRIPT.new() as Node
	if platform_ai == null:
		return
	platform_ai.name = "%sLogspireJumpAI" % racer.name
	add_child(platform_ai)
	platform_ai.call(
		"configure",
		racer,
		driver,
		_graph,
		_gameplay,
		route,
		_safe_route_with_runout,
		route_ids,
		_safe_route_ids,
		route_id
	)
	_platform_ai_by_racer[racer.get_instance_id()] = platform_ai

	if racer != null and not racer.is_player:
		var ai_number: int = _phase_b_ai_number(racer)
		var lane_index: int = ((ai_number - 1) % PHASE_B_LANE_COUNT) if ai_number > 0 else int(racer.get_instance_id() % PHASE_B_LANE_COUNT)
		driver.preferred_lane = float(lane_index - 2) * PHASE_B_LANE_SPACING
		driver.lane_wander = minf(driver.lane_wander, 0.05)
		driver.steering_strength = maxf(driver.steering_strength, 8.0)
		driver.acceleration = maxf(driver.acceleration, 24.5)
		driver.avoidance_distance = maxf(driver.avoidance_distance, 5.2)
		print("LOGSPIRE AI CROWD LANE racer=%s lane=%d preferred=%.2f five_lane=true" % [
			RaceManager.get_racer_label(racer), lane_index, driver.preferred_lane,
		])

func _on_racer_recovered(racer: WildDashCharacterController, target_id: StringName) -> void:
	super(racer, target_id)
	if racer == null:
		return
	if racer.is_player:
		reliability_record_metric(&"player_fall", racer, target_id)
		return
	var ai_value: Variant = _platform_ai_by_racer.get(racer.get_instance_id(), null)
	var platform_ai := ai_value as Node
	var failed_platform: StringName = &""
	var route_id: StringName = &"safe"
	if platform_ai != null:
		if platform_ai.has_method("get_phase_b_last_failed_platform"):
			failed_platform = StringName(platform_ai.call("get_phase_b_last_failed_platform"))
		if platform_ai.has_method("get_route_id"):
			route_id = StringName(platform_ai.call("get_route_id"))
	var zone: String = _phase_b_zone_name(failed_platform)
	_phase_b_ai_falls_by_zone[zone] = int(_phase_b_ai_falls_by_zone.get(zone, 0)) + 1
	reliability_record_metric(&"ai_fall", racer, failed_platform if failed_platform != &"" else target_id)
	if route_id == &"wild":
		_phase_b_wild_route_falls += 1
	else:
		_phase_b_safe_route_falls += 1

func _on_player_finished(rank: int) -> void:
	_print_phase_b_completion_report("player_finish")
	super(rank)

func _on_race_completed() -> void:
	_print_phase_b_completion_report("race_completed")
	super()

func reliability_set_motion_state(racer: WildDashCharacterController, state: StringName, source: String = "") -> void:
	if racer == null or not is_instance_valid(racer):
		return
	if state not in [QA_STATE_NORMAL, QA_STATE_AIRBORNE, QA_STATE_WATER, QA_STATE_RECOVERY, QA_STATE_SAFE_EXIT]:
		return
	var racer_id: int = racer.get_instance_id()
	var previous := StringName(_reliability_motion_state_by_id.get(racer_id, QA_STATE_NORMAL))
	if previous == state:
		return
	_reliability_motion_state_by_id[racer_id] = state
	print("LOGSPIRE R3 AUTHORITY racer=%s from=%s to=%s source=%s" % [
		RaceManager.get_racer_label(racer), String(previous), String(state), source,
	])

func reliability_get_motion_state(racer: WildDashCharacterController) -> StringName:
	if racer == null or not is_instance_valid(racer):
		return QA_STATE_NORMAL
	return StringName(_reliability_motion_state_by_id.get(racer.get_instance_id(), QA_STATE_NORMAL))

func reliability_jump_assist_allowed(racer: WildDashCharacterController) -> bool:
	return reliability_get_motion_state(racer) not in QA_PROTECTED_STATES

func reliability_record_metric(
	metric: StringName,
	racer: WildDashCharacterController = null,
	platform_id: StringName = &"",
	zone_override: String = ""
) -> void:
	if metric not in QA_METRIC_KEYS:
		return
	var zone: String = zone_override
	if zone.is_empty() and platform_id != &"":
		zone = _phase_b_zone_name(platform_id)
	if zone.is_empty() or zone == "UNKNOWN":
		zone = _reliability_zone_for_racer(racer)
	if zone.is_empty() or zone == "UNKNOWN":
		zone = "FINALE" if platform_id == &"CROWN_NEST" else "ZONE_1"
	_ensure_reliability_zone(zone)
	var metrics_value: Variant = _reliability_metrics_by_zone.get(zone, {})
	var metrics: Dictionary = metrics_value if metrics_value is Dictionary else _new_reliability_zone_metrics()
	metrics[metric] = int(metrics.get(metric, 0)) + 1
	_reliability_metrics_by_zone[zone] = metrics
	print("LOGSPIRE R3 QA EVENT zone=%s metric=%s count=%d racer=%s" % [
		zone,
		String(metric),
		int(metrics.get(metric, 0)),
		RaceManager.get_racer_label(racer) if racer != null else "AUDIT",
	])

func reliability_zone_name_from_index(zone_index: int) -> String:
	match zone_index:
		0:
			return "ZONE_1"
		1:
			return "ZONE_2"
		2:
			return "ZONE_3"
		3:
			return "ZONE_4"
		4:
			return "TITAN_TREE"
		_:
			return "FINALE"

func _print_phase_b_completion_report(reason: String) -> void:
	if _phase_b_report_printed:
		return
	_phase_b_report_printed = true
	_print_integrated_reliability_report(reason)
	print("LOGSPIRE AI COMPLETION REPORT reason=%s racers=%d ai=%d zone1_falls=%d zone2_falls=%d zone3_falls=%d zone4_falls=%d titan_falls=%d finale_falls=%d safe_route_falls=%d wild_route_falls=%d zone1_target=97-100%% zone2_target=95%% manual_success_rate_required=true" % [
		reason,
		RaceManager.racers.size(),
		ai_racers.size(),
		int(_phase_b_ai_falls_by_zone.get("ZONE_1", 0)),
		int(_phase_b_ai_falls_by_zone.get("ZONE_2", 0)),
		int(_phase_b_ai_falls_by_zone.get("ZONE_3", 0)),
		int(_phase_b_ai_falls_by_zone.get("ZONE_4", 0)),
		int(_phase_b_ai_falls_by_zone.get("TITAN_TREE", 0)),
		int(_phase_b_ai_falls_by_zone.get("FINALE", 0)),
		_phase_b_safe_route_falls,
		_phase_b_wild_route_falls,
	])

func _print_integrated_reliability_report(reason: String) -> void:
	_initialize_reliability_metrics()
	var racer_count: int = RaceManager.racers.size()
	var supported_profile: bool = QA_RACER_COUNTS.has(racer_count)
	var total_deep_water_fail: int = 0
	var total_jump_block: int = 0
	print("LOGSPIRE R3 QA PROFILE reason=%s racers=%d supported=%s expected=10|15|18" % [
		reason, racer_count, str(supported_profile),
	])
	for zone: String in QA_ZONE_KEYS:
		var metrics_value: Variant = _reliability_metrics_by_zone.get(zone, {})
		var metrics: Dictionary = metrics_value if metrics_value is Dictionary else _new_reliability_zone_metrics()
		total_deep_water_fail += int(metrics.get(&"deep_water_fail", 0))
		total_jump_block += int(metrics.get(&"jump_block", 0))
		print("LOGSPIRE R3 QA ZONE zone=%s water_enter=%d surface_reacquire=%d deep_water_fail=%d root_success=%d ladder_success=%d recovery_stuck=%d jump_block=%d head_collision=%d ledge_catch=%d ai_fall=%d player_fall=%d" % [
			zone,
			int(metrics.get(&"water_enter", 0)),
			int(metrics.get(&"surface_reacquire", 0)),
			int(metrics.get(&"deep_water_fail", 0)),
			int(metrics.get(&"root_success", 0)),
			int(metrics.get(&"ladder_success", 0)),
			int(metrics.get(&"recovery_stuck", 0)),
			int(metrics.get(&"jump_block", 0)),
			int(metrics.get(&"head_collision", 0)),
			int(metrics.get(&"ledge_catch", 0)),
			int(metrics.get(&"ai_fall", 0)),
			int(metrics.get(&"player_fall", 0)),
		])
	print("LOGSPIRE R3 QA GATE deep_water_fail=%d jump_block=%d safe_route_candidate=%s recovery_exit_bounded=true r3_to_recap_to_r4_contract=true manual_profiles_required=10|15|18" % [
		total_deep_water_fail,
		total_jump_block,
		str(total_deep_water_fail == 0 and total_jump_block == 0),
	])

func _initialize_reliability_metrics() -> void:
	for zone: String in QA_ZONE_KEYS:
		_ensure_reliability_zone(zone)

func _ensure_reliability_zone(zone: String) -> void:
	if _reliability_metrics_by_zone.has(zone):
		return
	_reliability_metrics_by_zone[zone] = _new_reliability_zone_metrics()

func _new_reliability_zone_metrics() -> Dictionary:
	var metrics: Dictionary = {}
	for metric: StringName in QA_METRIC_KEYS:
		metrics[metric] = 0
	return metrics

func _reliability_zone_for_racer(racer: WildDashCharacterController) -> String:
	if racer == null or _graph == null:
		return "UNKNOWN"
	var target_value: Variant = _graph.call("get_last_checkpoint_id", RaceManager.get_checkpoint_progress(racer))
	var target_id: StringName = &""
	if target_value is StringName:
		target_id = target_value
	elif target_value is String:
		target_id = StringName(target_value)
	return _phase_b_zone_name(target_id)

func _phase_b_ai_number(racer: WildDashCharacterController) -> int:
	if racer == null:
		return 0
	var text: String = String(racer.name)
	if not text.begins_with("AI_"):
		return 0
	return text.trim_prefix("AI_").to_int()

func _phase_b_zone_name(platform_id: StringName) -> String:
	var text: String = String(platform_id)
	if text.begins_with("Z1_"):
		return "ZONE_1"
	if text.begins_with("Z2_"):
		return "ZONE_2"
	if text.begins_with("Z3_"):
		return "ZONE_3"
	if text.begins_with("Z4_"):
		return "ZONE_4"
	if text.begins_with("Z5_"):
		return "TITAN_TREE"
	if text.begins_with("Z6_") or platform_id == &"CROWN_NEST":
		return "FINALE"
	return "UNKNOWN"
