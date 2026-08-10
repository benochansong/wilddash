class_name WildDashDifficultySystem
extends RefCounted

const CASUAL: StringName = &"casual"
const NORMAL: StringName = &"normal"
const HARD: StringName = &"hard"

const ORDER: Array[StringName] = [CASUAL, NORMAL, HARD]

const PROFILES := {
	CASUAL: {
		"label": "CASUAL",
		"ai_count": 6,
		"speed_scale": 0.97,
		"acceleration_scale": 0.90,
		"steering_scale": 0.90,
		"corner_precision": 0.82,
		"reaction_interval": 0.24,
		"risk_taking": 0.28,
		"overtake_strength": 0.55,
		"lane_wander_scale": 1.35,
		"avoidance_scale": 0.90,
		"item_decision_interval": 0.48,
		"item_utility_threshold": 0.72,
		"skill_decision_interval": 0.55,
		"skill_utility_threshold": 0.82,
		"skill_warmup": 1.80,
		"obstacle_speed_scale": 0.78,
		"recovery_penalty_seconds": 0.45,
		"shortcut_chance": 0.32,
	},
	NORMAL: {
		"label": "NORMAL",
		"ai_count": 10,
		"speed_scale": 1.035,
		"acceleration_scale": 1.00,
		"steering_scale": 1.05,
		"corner_precision": 0.94,
		"reaction_interval": 0.14,
		"risk_taking": 0.62,
		"overtake_strength": 1.00,
		"lane_wander_scale": 0.92,
		"avoidance_scale": 1.02,
		"item_decision_interval": 0.30,
		"item_utility_threshold": 0.59,
		"skill_decision_interval": 0.31,
		"skill_utility_threshold": 0.67,
		"skill_warmup": 0.95,
		"obstacle_speed_scale": 1.08,
		"recovery_penalty_seconds": 0.95,
		"shortcut_chance": 0.72,
	},
	HARD: {
		"label": "HARD",
		"ai_count": 14,
		"speed_scale": 1.065,
		"acceleration_scale": 1.08,
		"steering_scale": 1.16,
		"corner_precision": 1.00,
		"reaction_interval": 0.085,
		"risk_taking": 0.88,
		"overtake_strength": 1.25,
		"lane_wander_scale": 0.62,
		"avoidance_scale": 1.08,
		"item_decision_interval": 0.21,
		"item_utility_threshold": 0.53,
		"skill_decision_interval": 0.22,
		"skill_utility_threshold": 0.59,
		"skill_warmup": 0.58,
		"obstacle_speed_scale": 1.22,
		"recovery_penalty_seconds": 1.35,
		"shortcut_chance": 0.94,
	},
}

static func normalize(id: StringName) -> StringName:
	match id:
		&"wild":
			return CASUAL
		&"chaos":
			return NORMAL
		&"nightmare":
			return HARD
		CASUAL, NORMAL, HARD:
			return id
		_:
			return NORMAL

static func get_profile(id: StringName) -> Dictionary:
	return PROFILES[normalize(id)].duplicate(true)

static func get_label(id: StringName) -> String:
	return String(get_profile(id).get("label", "NORMAL"))

static func get_default_ai_count(id: StringName) -> int:
	return int(get_profile(id).get("ai_count", 10))

static func should_use_shortcut(id: StringName, animal_id: StringName, racer_index: int) -> bool:
	var profile := get_profile(id)
	var chance := float(profile.get("shortcut_chance", 0.72))
	# Rabbit keeps a mobility identity, but the route is no longer guaranteed.
	# Other animals only gamble on the risky line in Hard.
	if animal_id == &"rabbit":
		chance = minf(1.0, chance + 0.12)
	elif normalize(id) != HARD:
		chance *= 0.18
	else:
		chance *= 0.42
	# Deterministic pseudo-random score keeps CI reproducible.
	var seed_value := (racer_index + 1) * 37 + String(animal_id).length() * 19
	var score := float(posmod(seed_value * 53, 997)) / 996.0
	return score <= chance

static func describe(id: StringName) -> String:
	var profile := get_profile(id)
	return "%s · AI %d · reaction %.3fs · risk %.2f · item %.2f · skill %.2f" % [
		get_label(id),
		int(profile.ai_count),
		float(profile.reaction_interval),
		float(profile.risk_taking),
		float(profile.item_utility_threshold),
		float(profile.skill_utility_threshold),
	]
