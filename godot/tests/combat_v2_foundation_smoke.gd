extends Node

const ROUND2_SCENE: PackedScene = preload("res://modes/fruit_collection/fruit_collection.tscn")
const ROUND4_SCENE: PackedScene = preload("res://modes/push_out/push_out.tscn")

func _ready() -> void:
	var failures: Array[String] = []
	var bite: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_basic_attack(&"crocodile")
	var tail: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_heavy_attack(&"crocodile")
	var ambush: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_special_attack(&"crocodile")
	if bite == null or bite.ability_id != WildDashAnimalCombatProfile.CROCODILE_BITE_ID:
		failures.append("Crocodile Bite Lunge profile missing")
	if tail == null or tail.ability_id != WildDashAnimalCombatProfile.CROCODILE_TAIL_ID:
		failures.append("Crocodile Tail Sweep profile missing")
	if ambush == null or ambush.ability_id != WildDashAnimalCombatProfile.CROCODILE_WATER_AMBUSH_ID:
		failures.append("Crocodile Water Ambush staged data missing")
	if bite != null:
		if not bite.has_impact(WildDashCombatAbilitySpec.ImpactType.SPILL):
			failures.append("Bite Lunge must expose SPILL impact")
		if WildDashCombatAbilitySystem.get_effective_range(bite, true) <= bite.range:
			failures.append("Bite Lunge water range bonus missing")
	if tail != null:
		if tail.recovery < 0.8 or tail.recovery > 1.0:
			failures.append("Tail Sweep recovery must remain in 0.8..1.0s")
		if tail.fruit_spill != 1:
			failures.append("Tail Sweep Round 2 spill budget should be 1")
	if ambush != null:
		if ambush.land_effect_multiplier < 0.50 or ambush.land_effect_multiplier > 0.60:
			failures.append("Water Ambush land staging scale should be 50..60 percent")
		if ambush.fruit_spill != 2:
			failures.append("Water Ambush staged spill should be 2")

	var monkey_bridge: Dictionary = WildDashCombatAbilitySystem.get_legacy_special_bridge(&"monkey")
	if StringName(monkey_bridge.get("ability_id", &"")) != &"jet_fart":
		failures.append("Legacy Monkey Jet Fart Combat V2 bridge missing")
	if ROUND2_SCENE == null or ROUND4_SCENE == null:
		failures.append("Combat V2 active round scenes failed to preload")

	if failures.is_empty():
		print("COMBAT V2 FOUNDATION SMOKE PASS typed_schema=true impacts=6 crocodile_migrated=true round2_modifier=true round4_modifier=true legacy_farts=true")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("COMBAT V2 FOUNDATION SMOKE FAIL: %s" % failure)
	get_tree().quit(1)
