extends "res://modes/logspire_leap/logspire_leap_v3_recovery_camera.gd"

## Phase B large-field stability pass.
## The base mode still owns spawning, items, water and campaign flow. This layer
## only replaces Logspire Platform AI with V5, spreads AI across five lanes and
## aggregates fall telemetry for the 15/18-racer manual test.

const PLATFORM_AI_PHASE_B_SCRIPT: Script = preload("res://modes/logspire_leap/logspire_platform_ai_v5_phase_b.gd")
const PHASE_B_LANE_COUNT: int = 5
const PHASE_B_LANE_SPACING: float = 0.70

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

func _ready() -> void:
	await super()
	print("LOGSPIRE PHASE B CROWD READY five_lane_distribution=true lane_count=%d lane_spacing=%.2f zone1_success_target=97-100%% zone2_success_target=95%% landing_protection=0.65s" % [
		PHASE_B_LANE_COUNT, PHASE_B_LANE_SPACING,
	])

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
		var lane_index: int = posmod(ai_number - 1, PHASE_B_LANE_COUNT) if ai_number > 0 else posmod(int(racer.get_instance_id()), PHASE_B_LANE_COUNT)
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
	if racer == null or racer.is_player:
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

func _print_phase_b_completion_report(reason: String) -> void:
	if _phase_b_report_printed:
		return
	_phase_b_report_printed = true
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
