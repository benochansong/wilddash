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

static func passive_profile(head_id: StringName) -> Dictionary:
	match head_id:
		&"rabbit":
			return {
				"name": "Long-Ear Sense",
				"description": "과일과 상호작용 판정 범위 +20%",
				"pickup_radius_multiplier": 1.20,
				"turn_multiplier": 1.0,
				"knockback_received_multiplier": 1.0,
				"collision_retention": 0.92,
			}
		&"elephant":
			return {
				"name": "Thick Skull",
				"description": "받는 넉백 -25%",
				"pickup_radius_multiplier": 1.0,
				"turn_multiplier": 1.0,
				"knockback_received_multiplier": 0.75,
				"collision_retention": 0.93,
			}
		&"cat":
			return {
				"name": "Quick Reflex",
				"description": "회전 반응 +12%",
				"pickup_radius_multiplier": 1.0,
				"turn_multiplier": 1.12,
				"knockback_received_multiplier": 1.0,
				"collision_retention": 0.92,
			}
		_:
			return {
				"name": "Trail Sense",
				"description": "장애물 충돌 후 속도 보존 향상",
				"pickup_radius_multiplier": 1.0,
				"turn_multiplier": 1.0,
				"knockback_received_multiplier": 1.0,
				"collision_retention": 0.96,
			}

static func describe(loadout: WildDashChimeraLoadout) -> Dictionary:
	if loadout == null:
		loadout = default_loadout()
	loadout.normalize()
	var head := WildDashAnimalCatalog.get_definition(loadout.head_id)
	var body := WildDashAnimalCatalog.get_definition(loadout.body_id)
	var tail := WildDashAnimalCatalog.get_definition(loadout.tail_id)
	return {
		"head": head.display_name,
		"body": body.display_name,
		"tail": tail.display_name,
		"passive": passive_profile(loadout.head_id),
		"skill_name": tail.skill_name,
		"skill_description": tail.skill_description,
		"body_role": body.role,
		"palette": String(loadout.palette_id),
		"pattern": String(loadout.pattern_id),
	}

static func palette_color(id: StringName, fallback: Color) -> Color:
	match id:
		&"sunset": return Color(1.0, 0.38, 0.24)
		&"ocean": return Color(0.20, 0.68, 0.92)
		&"forest": return Color(0.28, 0.76, 0.45)
		_: return fallback
