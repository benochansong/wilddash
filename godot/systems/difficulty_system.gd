class_name WildDashDifficultySystem
extends RefCounted

const CASUAL: StringName = &"casual"
const NORMAL: StringName = &"normal"
const HARD: StringName = &"hard"

const LEGACY_ALIASES := {
	&"wild": CASUAL,
	&"chaos": NORMAL,
	&"nightmare": HARD,
}

const PROFILES := {
	CASUAL: {
		"display_name": "CASUAL",
		"reaction_interval": 0.46,
		"corner_precision": 0.82,
		"risk_taking": 0.28,
		"mistake_chance": 0.10,
		"ai_speed_scale": 0.97,
		"steering_scale": 0.88,
		"acceleration_scale": 0.92,
		"avoidance_scale": 0.92,
		"item_decision_interval": 0.46,
		"item_utility_threshold": 0.74,
		"skill_decision_interval": 0.46,
		"skill_utility_threshold": 0.80,
		"shortcut_probability": 0.18,
		"obstacle_speed_scale": 0.82,
		"recovery_penalty": 0.55,
		"stuck_recovery_seconds": 3.4,
	},
	NORMAL: {
		"display_name": "NORMAL",
		"reaction_interval": 0.30,
		"corner_precision": 1.00,
		"risk_taking": 0.58,
		"mistake_chance": 0.055,
		"ai_speed_scale": 1.00,
		"steering_scale": 1.04,
		"acceleration_scale": 1.00,
		"avoidance_scale": 1.00,
		"item_decision_interval": 0.30,
		"item_utility_threshold": 0.60,
		"skill_decision_interval": 0.31,
		"skill_utility_threshold": 0.69,
		"shortcut_probability": 0.52,
		"obstacle_speed_scale": 1.05,
		"recovery_penalty": 1.10,
		"stuck_recovery_seconds": 4.0,
	},
	HARD: {
		"display_name": "HARD",
		"reaction_interval": 0.22,
		"corner_precision": 1.16,
		"risk_taking": 0.82,
		"mistake_chance": 0.025,
		"ai_speed_scale": 1.035,
		"steering_scale": 1.16,
		"acceleration_scale": 1.06,
		"avoidance_scale": 1.08,
		"item_decision_interval": 0.22,
		"item_utility_threshold": 0.52,
		"skill_decision_interval": 0.23,
		"skill_utility_threshold": 0.61,
		"shortcut_probability": 0.78,
		"obstacle_speed_scale": 1.22,
		"recovery_penalty": 1.65,
		"stuck_recovery_seconds": 4.8,
	},
}

static func normalize(id: StringName) -> StringName:
	if PROFILES.has(id):
		return id
	if LEGACY_ALIASES.has(id):
		return LEGACY_ALIASES[id]
	return NORMAL

static func get_profile(id: StringName) -> Dictionary:
	return PROFILES[normalize(id)].duplicate(true)

static func get_current_profile() -> Dictionary:
	var manager := Engine.get_main_loop().root.get_node_or_null("GameManager") if Engine.get_main_loop() is SceneTree else null
	if manager != null:
		return get_profile(manager.difficulty)
	return get_profile(NORMAL)

static func get_display_name(id: StringName) -> String:
	return String(get_profile(id).display_name)

static func should_take_shortcut(id: StringName, stable_seed: int) -> bool:
	var probability: float = float(get_profile(id).shortcut_probability)
	var bucket := abs(stable_seed * 1103515245 + 12345) % 1000
	return float(bucket) / 1000.0 < probability

static func apply_small_ai_variance(base_value: float, stable_seed: int) -> float:
	# Personality variance is deliberately small: difficulty comes from decisions,
	# not hidden speed cheats. Range is approximately -1.5% .. +1.5%.
	var centered := float(abs(stable_seed * 73 + 19) % 31 - 15) / 1000.0
	return base_value * (1.0 + centered)
