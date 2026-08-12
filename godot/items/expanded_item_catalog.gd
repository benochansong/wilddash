class_name WildDashExpandedItemCatalog
extends RefCounted

const SNOWBALL: StringName = &"snowball"
const BEE_SWARM: StringName = &"bee_swarm"
const TURBO_CHILI: StringName = &"turbo_chili"
const MUD_SPLASH: StringName = &"mud_splash"
const SPRING_TRAP: StringName = &"spring_trap"
const SWAP_BOOST: StringName = &"swap_boost"

const ITEM_IDS: Array[StringName] = [
	SNOWBALL,
	BEE_SWARM,
	TURBO_CHILI,
	MUD_SPLASH,
	SPRING_TRAP,
	SWAP_BOOST,
]

const META: Dictionary = {
	SNOWBALL: {"name": "SNOWBALL", "icon": "SB", "status": "SNOW SHOT", "role": &"attack"},
	BEE_SWARM: {"name": "BEE SWARM", "icon": "BZ", "status": "BUZZ CHASE", "role": &"attack"},
	TURBO_CHILI: {"name": "TURBO CHILI", "icon": "TC", "status": "HOT BOOST", "role": &"speed"},
	MUD_SPLASH: {"name": "MUD SPLASH", "icon": "MS", "status": "MUD TRAP", "role": &"trap"},
	SPRING_TRAP: {"name": "SPRING TRAP", "icon": "ST", "status": "BOUNCE TRAP", "role": &"trap"},
	SWAP_BOOST: {"name": "SWAP BOOST", "icon": "XB", "status": "CHASE SURGE", "role": &"utility"},
}

static func is_expanded(item_id: StringName) -> bool:
	return ITEM_IDS.has(item_id)

static func get_display_name(item_id: StringName) -> String:
	return str((META.get(item_id, {}) as Dictionary).get("name", String(item_id).to_upper().replace("_", " ")))

static func get_icon_text(item_id: StringName) -> String:
	return str((META.get(item_id, {}) as Dictionary).get("icon", "??"))

static func get_status_label(item_id: StringName) -> String:
	return str((META.get(item_id, {}) as Dictionary).get("status", "ITEM"))

static func get_role(item_id: StringName) -> StringName:
	return StringName((META.get(item_id, {}) as Dictionary).get("role", &"utility"))

static func get_count() -> int:
	return ITEM_IDS.size()
