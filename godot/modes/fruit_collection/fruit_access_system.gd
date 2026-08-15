class_name WildDashFruitAccessSystem
extends RefCounted

enum FruitAccessType {
	GROUND,
	LOW_PLATFORM,
	HIGH_PLATFORM,
	TREE,
	WATER,
}

const ACCESS_NAMES: Dictionary = {
	FruitAccessType.GROUND: "GROUND",
	FruitAccessType.LOW_PLATFORM: "LOW_PLATFORM",
	FruitAccessType.HIGH_PLATFORM: "HIGH_PLATFORM",
	FruitAccessType.TREE: "TREE",
	FruitAccessType.WATER: "WATER",
}

static func configure_fruit(
	fruit: Node,
	access_type: int,
	required_climb: float = 0.0,
	required_agility: float = 0.0,
	branch_tier: int = 0
) -> void:
	if fruit == null:
		return
	fruit.set_meta(&"wilddash_fruit_access_type", access_type)
	fruit.set_meta(&"wilddash_required_climb", required_climb)
	fruit.set_meta(&"wilddash_required_agility", required_agility)
	fruit.set_meta(&"wilddash_branch_tier", branch_tier)

static func get_access_type(fruit: Node) -> int:
	if fruit == null:
		return FruitAccessType.GROUND
	return int(fruit.get_meta(&"wilddash_fruit_access_type", FruitAccessType.GROUND))

static func get_access_name(fruit: Node) -> String:
	return str(ACCESS_NAMES.get(get_access_type(fruit), "GROUND"))

static func can_racer_reach_fruit(racer: WildDashCharacterController, fruit: Node) -> bool:
	if racer == null or fruit == null:
		return false
	var access_type: int = get_access_type(fruit)
	if access_type == FruitAccessType.GROUND or access_type == FruitAccessType.WATER:
		# River water is intentionally shallow, so WATER fruit is never hard-locked.
		# Crocodile earns the advantage through Swim 10 / water speed instead of an
		# artificial pickup restriction; other racers may still contest the fruit.
		return true
	var climb: float = WildDashAnimalAbilityProfile.get_stat(racer.animal_id, &"climb")
	var agility: float = WildDashAnimalAbilityProfile.get_stat(racer.animal_id, &"agility")
	var required_climb: float = float(fruit.get_meta(&"wilddash_required_climb", 0.0))
	var required_agility: float = float(fruit.get_meta(&"wilddash_required_agility", 0.0))
	if climb >= required_climb and agility >= required_agility:
		return true
	# Jump specialists may improvise access to low branches/platforms even when
	# their climbing score is below the nominal threshold.
	if access_type == FruitAccessType.LOW_PLATFORM:
		return agility >= maxf(6.0, required_agility - 1.0)
	if access_type == FruitAccessType.HIGH_PLATFORM:
		return agility >= 9.0 and climb >= maxf(6.0, required_climb - 1.5)
	if access_type == FruitAccessType.TREE:
		var tier: int = int(fruit.get_meta(&"wilddash_branch_tier", 0))
		if tier <= 1 and racer.animal_id in [&"rabbit", &"deer"] and agility >= 9.0:
			return true
	return false

static func access_reason(racer: WildDashCharacterController, fruit: Node) -> String:
	if racer == null or fruit == null:
		return "INVALID"
	if can_racer_reach_fruit(racer, fruit):
		return "OK"
	var climb: float = WildDashAnimalAbilityProfile.get_stat(racer.animal_id, &"climb")
	var agility: float = WildDashAnimalAbilityProfile.get_stat(racer.animal_id, &"agility")
	var required_climb: float = float(fruit.get_meta(&"wilddash_required_climb", 0.0))
	var required_agility: float = float(fruit.get_meta(&"wilddash_required_agility", 0.0))
	if climb < required_climb:
		return "CLIMB_TOO_LOW"
	if agility < required_agility:
		return "JUMP_TOO_LOW"
	return "ACCESS_DENIED"
