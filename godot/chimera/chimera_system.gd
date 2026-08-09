class_name WildDashChimeraSystem
extends RefCounted

const PALETTES: Array[StringName] = [&"classic", &"sunset", &"ocean", &"forest"]
const PATTERNS: Array[StringName] = [&"stripe", &"spots", &"split", &"plain"]

static func is_valid_palette(id: StringName) -> bool:
	return id in PALETTES

static func is_valid_pattern(id: StringName) -> bool:
	return id in PATTERNS

static func default_loadout() -> WildDashChimeraLoadout:
	return WildDashChimeraLoadout.new()

## HEAD -> the exact active skill used by the source animal.
static func head_skill_definition(head_id: StringName) -> WildDashAnimalDefinition:
	return WildDashAnimalCatalog.get_definition(head_id)

## BODY -> one restrained passive identity. Bonuses stay in the 5-10% range.
static func body_passive_profile(body_id: StringName) -> Dictionary:
	match body_id:
		&"rabbit":
			return {
				"name": "LIGHT FRAME",
				"description": "Acceleration +7%, but receives 3% more knockback.",
				"acceleration_multiplier": 1.07,
				"turn_multiplier": 1.00,
				"knockback_received_multiplier": 1.03,
				"collision_retention_multiplier": 1.00,
			}
		&"elephant":
			return {
				"name": "HEAVY FRAME",
				"description": "Knockback received -9%, with slightly slower handling.",
				"acceleration_multiplier": 1.00,
				"turn_multiplier": 0.97,
				"knockback_received_multiplier": 0.91,
				"collision_retention_multiplier": 1.03,
			}
		&"cat":
			return {
				"name": "FLEX FRAME",
				"description": "Handling +6%, with slightly lower collision retention.",
				"acceleration_multiplier": 1.00,
				"turn_multiplier": 1.06,
				"knockback_received_multiplier": 1.00,
				"collision_retention_multiplier": 0.98,
			}
		_:
			return {
				"name": "STEADY FRAME",
				"description": "Collision speed retention +6%.",
				"acceleration_multiplier": 1.00,
				"turn_multiplier": 1.00,
				"knockback_received_multiplier": 1.00,
				"collision_retention_multiplier": 1.06,
			}

## TAIL -> a smaller utility modifier. Bonuses stay in the 3-7% range.
static func tail_utility_profile(tail_id: StringName) -> Dictionary:
	match tail_id:
		&"rabbit":
			return {
				"name": "HOP ASSIST",
				"description": "Jump +5%, pickup reach +3%.",
				"acceleration_multiplier": 1.00,
				"turn_multiplier": 1.00,
				"jump_multiplier": 1.05,
				"knockback_decay_multiplier": 1.00,
				"pickup_radius_multiplier": 1.03,
			}
		&"elephant":
			return {
				"name": "BALANCE TAIL",
				"description": "Knockback recovery +6%.",
				"acceleration_multiplier": 1.00,
				"turn_multiplier": 1.00,
				"jump_multiplier": 1.00,
				"knockback_decay_multiplier": 1.06,
				"pickup_radius_multiplier": 1.00,
			}
		&"cat":
			return {
				"name": "REFLEX TAIL",
				"description": "Handling +6%, acceleration recovery +3%.",
				"acceleration_multiplier": 1.03,
				"turn_multiplier": 1.06,
				"jump_multiplier": 1.00,
				"knockback_decay_multiplier": 1.03,
				"pickup_radius_multiplier": 1.00,
			}
		_:
			return {
				"name": "RALLY TAIL",
				"description": "Acceleration recovery +4%.",
				"acceleration_multiplier": 1.04,
				"turn_multiplier": 1.00,
				"jump_multiplier": 1.00,
				"knockback_decay_multiplier": 1.00,
				"pickup_radius_multiplier": 1.00,
			}

## Compatibility alias for old callers: passive now belongs to BODY, not HEAD.
static func passive_profile(body_id: StringName) -> Dictionary:
	return body_passive_profile(body_id)

static func describe(loadout: WildDashChimeraLoadout) -> Dictionary:
	if loadout == null:
		loadout = default_loadout()
	loadout.normalize()
	var head := WildDashAnimalCatalog.get_definition(loadout.head_id)
	var body := WildDashAnimalCatalog.get_definition(loadout.body_id)
	var tail := WildDashAnimalCatalog.get_definition(loadout.tail_id)
	var body_passive := body_passive_profile(loadout.body_id)
	var tail_utility := tail_utility_profile(loadout.tail_id)
	return {
		"head": head.display_name,
		"body": body.display_name,
		"tail": tail.display_name,
		"skill_name": head.skill_name,
		"skill_description": head.skill_description,
		"body_passive": body_passive,
		"tail_utility": tail_utility,
		"passive": body_passive,
		"body_role": body_passive.name,
		"utility_name": tail_utility.name,
		"palette": String(loadout.palette_id),
		"pattern": String(loadout.pattern_id),
	}

static func palette_color(id: StringName, fallback: Color) -> Color:
	match id:
		&"sunset": return Color(1.0, 0.38, 0.24)
		&"ocean": return Color(0.20, 0.68, 0.92)
		&"forest": return Color(0.28, 0.76, 0.45)
		_: return fallback
