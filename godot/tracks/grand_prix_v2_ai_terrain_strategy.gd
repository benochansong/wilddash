class_name WildDashGrandPrixV2AITerrainStrategy
extends Node

## Stage 3 terrain-aware lane scorer.
## Keeps every AI on the authoritative V2 route for finish reliability, but
## selects LEFT/CENTER/RIGHT lines per section from terrain affinity, personality,
## hazard pressure and nearby congestion.

const THINK_INTERVAL: float = 0.28
const LANE_RESPONSE: float = 0.72

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _elapsed: float = 0.0
var _last_choice_by_racer: Dictionary = {}

func _ready() -> void:
	process_priority = 82
	call_deferred("_resolve_track")

func _resolve_track() -> void:
	for _frame: int in range(4):
		await get_tree().process_frame
	_track = _find_v2_track(get_parent())
	if _track != null:
		_route = _track.get_route_points()
		print("GRAND PRIX V2 AI TERRAIN STRATEGY READY route_points=%d difficulty=%s" % [
			_route.size(), String(GameManager.difficulty),
		])

func _process(delta: float) -> void:
	if _track == null or _route.size() < 2 or not RaceManager.active:
		return
	_elapsed += delta
	if _elapsed < THINK_INTERVAL:
		return
	_elapsed = 0.0

	for node: Node in get_tree().get_nodes_in_group("wilddash_ai_driver"):
		if not node is WildDashAIController:
			continue
		var driver: WildDashAIController = node as WildDashAIController
		if driver.preserve_player_identity:
			continue
		var racer: WildDashCharacterController = driver.get_racer()
		if racer == null or racer.finished:
			continue
		var segment_index: int = clampi(driver.get_route_index() - 1, 0, _route.size() - 2)
		var section_id: StringName = _track.get_v2_section_id_for_segment(segment_index)
		var width: float = _track.get_v2_width_for_segment(segment_index)
		var personality: String = _personality_for_racer(racer)
		var selected: Dictionary = choose_lane_for(
			racer.animal_id,
			section_id,
			personality,
			GameManager.difficulty,
			_lane_congestion(racer, segment_index, -1.0),
			_lane_congestion(racer, segment_index, 0.0),
			_lane_congestion(racer, segment_index, 1.0)
		)
		var lane_sign: float = float(selected.get("lane_sign", 0.0))
		var lane_limit: float = maxf(1.8, width * 0.30)
		var target_lane: float = lane_sign * minf(4.4, lane_limit)
		driver.preferred_lane = move_toward(driver.preferred_lane, target_lane, LANE_RESPONSE)

		var key: int = racer.get_instance_id()
		var choice_key: String = "%s:%s" % [String(section_id), String(selected.get("lane_name", "CENTER"))]
		if String(_last_choice_by_racer.get(key, "")) != choice_key:
			_last_choice_by_racer[key] = choice_key
			print("AI TERRAIN ROUTE racer=%s animal=%s section=%s lane=%s personality=%s score=%.2f congestion=%d/%d/%d" % [
				racer.name, String(racer.animal_id), String(section_id), String(selected.get("lane_name", "CENTER")),
				personality, float(selected.get("score", 0.0)),
				int(selected.get("left_congestion", 0)), int(selected.get("center_congestion", 0)), int(selected.get("right_congestion", 0)),
			])

static func choose_lane_for(
	animal_id: StringName,
	section_id: StringName,
	personality: String,
	difficulty: StringName,
	left_congestion: int = 0,
	center_congestion: int = 0,
	right_congestion: int = 0
) -> Dictionary:
	var scores: Dictionary = {
		"LEFT": _base_lane_score(animal_id, section_id, "LEFT"),
		"CENTER": _base_lane_score(animal_id, section_id, "CENTER"),
		"RIGHT": _base_lane_score(animal_id, section_id, "RIGHT"),
	}

	match personality:
		"Aggressive":
			scores["CENTER"] = float(scores["CENTER"]) + 2.0
		"Safe":
			scores["RIGHT"] = float(scores["RIGHT"]) + 2.2
		"Shortcut":
			scores["LEFT"] = float(scores["LEFT"]) + 2.4
		"Item Fighter":
			scores["CENTER"] = float(scores["CENTER"]) + 0.9
		_:
			scores["RIGHT"] = float(scores["RIGHT"]) + 0.35

	if difficulty == &"wild":
		scores["RIGHT"] = float(scores["RIGHT"]) + 1.25
		scores["LEFT"] = float(scores["LEFT"]) - 0.25
	elif difficulty == &"nightmare":
		scores["LEFT"] = float(scores["LEFT"]) * 1.10
		scores["CENTER"] = float(scores["CENTER"]) * 1.08

	scores["LEFT"] = float(scores["LEFT"]) - float(left_congestion) * 0.85
	scores["CENTER"] = float(scores["CENTER"]) - float(center_congestion) * 0.85
	scores["RIGHT"] = float(scores["RIGHT"]) - float(right_congestion) * 0.85

	var best_name: String = "CENTER"
	var best_score: float = float(scores[best_name])
	for lane_name: String in ["LEFT", "CENTER", "RIGHT"]:
		var candidate: float = float(scores[lane_name])
		if candidate > best_score:
			best_name = lane_name
			best_score = candidate

	return {
		"lane_name": best_name,
		"lane_sign": -1.0 if best_name == "LEFT" else (1.0 if best_name == "RIGHT" else 0.0),
		"score": best_score,
		"left_congestion": left_congestion,
		"center_congestion": center_congestion,
		"right_congestion": right_congestion,
	}

static func _base_lane_score(animal_id: StringName, section_id: StringName, lane_name: String) -> float:
	var swim: float = WildDashRaceTerrainProfile.get_swim(animal_id)
	var climb: float = WildDashRaceTerrainProfile.get_climb(animal_id)
	var agility: float = WildDashRaceTerrainProfile.get_agility(animal_id)
	var power: float = WildDashRaceTerrainProfile.get_power(animal_id)
	var rough: float = WildDashRaceTerrainProfile.get_rough(animal_id)
	var defense: float = WildDashRaceCombatBalance.get_defense_rating(animal_id)

	match section_id:
		&"forest_obstacle":
			if lane_name == "LEFT": return agility * 0.78 + climb * 0.12
			if lane_name == "CENTER": return power * 0.72 + defense * 0.18
			return 5.4 + agility * 0.22
		&"long_river":
			if lane_name == "CENTER": return swim * 0.90 + rough * 0.10
			if lane_name == "LEFT": return (10.0 - swim) * 0.56 + agility * 0.36 + 2.0
			return swim * 0.42 + rough * 0.34 + 3.4
		&"mountain_ascent":
			if lane_name == "LEFT": return climb * 0.56 + agility * 0.44
			if lane_name == "CENTER": return climb * 0.62 + power * 0.30
			return 4.2 + climb * 0.42 + defense * 0.12
		&"rough_descent":
			if lane_name == "LEFT": return rough * 0.48 + agility * 0.42
			if lane_name == "CENTER": return rough * 0.58 + power * 0.30
			return 4.0 + rough * 0.40 + defense * 0.12
		&"canyon_obstacle":
			if lane_name == "CENTER": return power * 0.50 + defense * 0.42
			if lane_name == "LEFT": return agility * 0.74 + climb * 0.12
			return 4.4 + agility * 0.30 + defense * 0.10
		&"final_sprint":
			if lane_name == "CENTER": return power * 0.34 + defense * 0.26 + 4.2
			return agility * 0.40 + 4.6
		_:
			return 5.0

func _personality_for_racer(racer: WildDashCharacterController) -> String:
	for node: Node in get_tree().get_nodes_in_group("wilddash_ai_tactics"):
		if not node is WildDashAIPackTactics:
			continue
		var tactics: WildDashAIPackTactics = node as WildDashAIPackTactics
		if tactics.get_racer() == racer:
			return tactics.get_personality_name()
	return "Balanced"

func _lane_congestion(racer: WildDashCharacterController, segment_index: int, lane_sign: float) -> int:
	if segment_index < 0 or segment_index + 1 >= _route.size():
		return 0
	var a: Vector3 = _route[segment_index]
	var b: Vector3 = _route[segment_index + 1]
	var forward: Vector3 = b - a
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
	var width: float = _track.get_v2_width_for_segment(segment_index)
	var target_lateral: float = lane_sign * minf(4.4, maxf(1.8, width * 0.30))
	var count: int = 0
	for other_node: Node3D in RaceManager.racers:
		if other_node == racer or not other_node is WildDashCharacterController:
			continue
		var offset: Vector3 = other_node.global_position - racer.global_position
		offset.y = 0.0
		if offset.length() > 19.0:
			continue
		var lateral: float = (other_node.global_position - a).dot(right)
		if absf(lateral - target_lateral) <= 2.3:
			count += 1
	return count

func _find_v2_track(node: Node) -> WildDashGrandPrixV2Track:
	if node is WildDashGrandPrixV2Track:
		return node as WildDashGrandPrixV2Track
	for child: Node in node.get_children():
		var found: WildDashGrandPrixV2Track = _find_v2_track(child)
		if found != null:
			return found
	return null
