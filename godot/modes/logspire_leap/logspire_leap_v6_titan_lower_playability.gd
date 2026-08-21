extends "res://modes/logspire_leap/logspire_leap_v5_finish_ai_convergence.gd"

## Round 3 Titan lower-route production QA adapter.
##
## This layer does not redesign the race. It replaces only the per-racer
## Platform AI adapter with the CP4 -> CP5 no-teleport variant and relocates the
## stale Titan item station onto the optional FAST fork. The 15-racer production
## target keeps the existing weighted route choice, which prefers SAFE on normal
## difficulty while retaining FAST-field variety.

const PLATFORM_AI_LOWER_QA_SCRIPT: Script = preload("res://modes/logspire_leap/logspire_platform_ai_v6_lower_route_qa.gd")

func _ready() -> void:
	await super()
	print("R3 TITAN PHASE2 MODE READY cp4_cp5_no_teleport=true safe_route_preferred=true fast_route_optional=true item_reward_on_fast=true")

func _attach_platform_ai(
	racer: WildDashCharacterController,
	driver: WildDashAIController,
	route: Array[Vector3],
	route_ids: Array[StringName],
	route_id: StringName
) -> void:
	var platform_ai := PLATFORM_AI_LOWER_QA_SCRIPT.new() as Node
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

		if ai_number in FINALE_CONTENDER_AI_NUMBERS and platform_ai.has_method("set_finale_contender"):
			platform_ai.call("set_finale_contender", true)
			print("r3_ai_finale_contender_selected racer=%s animal=%s slot=%d of=%d titan_lower_teleport=false" % [
				RaceManager.get_racer_label(racer), String(racer.animal_id), ai_number, GameManager.ai_count,
			])

func _spawn_phase2_item_boxes() -> void:
	_item_boxes.clear()
	var respawn: float = 5.8
	if RaceManager.racers.size() >= 18:
		respawn = 4.8
	elif RaceManager.racers.size() >= 15:
		respawn = 5.2

	# Preserve the 20-box density contract. The old Z5_APPROACH_02 id was retired
	# by Phase 1, so its three-box station now communicates the optional FAST fork.
	_spawn_item_station(&"Z1_07", [-2.8, 0.0, 2.8], ROUTE_SAFE, respawn)
	_spawn_item_station(&"Z2_08", [-2.7, 0.0, 2.7], ROUTE_SAFE, respawn)
	_spawn_item_station(&"Z3_04", [-3.2, 0.0, 3.2], ROUTE_SAFE, respawn)
	_spawn_item_station(&"Z4_MERGE", [-3.4, 0.0, 3.4], ROUTE_SAFE, respawn)
	_spawn_item_station(&"Z5_FORK_FAST_02", [-2.3, 0.0, 2.3], ROUTE_WILD, respawn)
	_spawn_item_station(&"Z6_START", [-2.8, 0.0, 2.8], ROUTE_SAFE, respawn)
	_spawn_item_station(&"Z4_WILD_05", [-1.7, 1.7], ROUTE_WILD, respawn)

	var density_percent: float = float(_item_boxes.size()) / float(ROUND1_REFERENCE_ITEM_BOXES) * 100.0
	print("LOGSPIRE ITEM DENSITY boxes=%d target=%d round1_reference=%d density=%.1f%% broad_platforms=true wild_reward=5 titan_fast_reward=3 instant_fall_items_clamped=true" % [
		_item_boxes.size(), PHASE2_TARGET_ITEM_BOXES, ROUND1_REFERENCE_ITEM_BOXES, density_percent,
	])
	if _item_boxes.size() != PHASE2_TARGET_ITEM_BOXES:
		push_warning("LOGSPIRE ITEM DENSITY expected=%d actual=%d" % [PHASE2_TARGET_ITEM_BOXES, _item_boxes.size()])
