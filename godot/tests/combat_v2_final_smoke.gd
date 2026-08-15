extends Node

const ROUND2_SCENE: PackedScene = preload("res://modes/fruit_collection/fruit_collection.tscn")
const ROUND4_SCENE: PackedScene = preload("res://modes/push_out/push_out.tscn")

func _ready() -> void:
	var failures: Array[String] = []
	_check_ability(failures, &"dog", WildDashCombatAbilitySystem.get_basic_attack(&"dog"), &"dog_shoulder_push")
	_check_ability(failures, &"wolf", WildDashCombatAbilitySystem.get_heavy_attack(&"wolf"), &"wolf_pounce")
	_check_ability(failures, &"boar", WildDashCombatAbilitySystem.get_heavy_attack(&"boar"), &"boar_charge")
	_check_ability(failures, &"elephant", WildDashCombatAbilitySystem.get_basic_attack(&"elephant"), &"elephant_trunk_push")
	_check_ability(failures, &"bear", WildDashCombatAbilitySystem.get_heavy_attack(&"bear"), &"bear_body_slam")
	_check_ability(failures, &"raccoon", WildDashCombatAbilitySystem.get_heavy_attack(&"raccoon"), &"raccoon_spin_swipe")

	var boar_charge: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_heavy_attack(&"boar")
	if boar_charge == null or boar_charge.fruit_spill != 2 or boar_charge.mobility_impulse < 3.8:
		failures.append("Boar Charge must keep 2-fruit pressure and charge mobility")
	var elephant_push: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_basic_attack(&"elephant")
	if elephant_push == null or not elephant_push.has_impact(WildDashCombatAbilitySpec.ImpactType.PUSH):
		failures.append("Elephant Trunk Push must be a PUSH impact")
	var elephant_special: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_special_attack(&"elephant")
	if elephant_special == null or elephant_special.ability_id != &"elephant_ground_stomp":
		failures.append("Elephant Ground Stomp special missing")
	var bear_aerial: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_aerial_attack(&"bear")
	if bear_aerial == null or bear_aerial.ability_id != &"bear_belly_drop" or not bear_aerial.requires_airborne:
		failures.append("Bear Belly Drop aerial profile missing")
	var croc_special: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_special_attack(&"crocodile")
	if croc_special == null or croc_special.ability_id != &"crocodile_water_ambush":
		failures.append("Crocodile Water Ambush must survive final profile routing")
	elif croc_special.land_effect_multiplier < 0.50 or croc_special.land_effect_multiplier > 0.60:
		failures.append("Crocodile Water Ambush land multiplier must remain near 55 percent")

	var expected_identities: Dictionary = {
		&"dog": "BALANCED FIGHTER",
		&"wolf": "HUNTER",
		&"boar": "CHARGE BRUISER",
		&"rabbit": "AERIAL FIGHTER",
		&"deer": "LEAP DUELIST",
		&"monkey": "CANOPY TRICKSTER",
		&"elephant": "PUSH KING",
		&"bear": "CLOSE RANGE BRAWLER",
		&"crocodile": "WATER BRUISER",
		&"cat": "AMBUSH SPECIALIST",
		&"fox": "HIT & RUN",
		&"raccoon": "THIEF / CONTROL",
	}
	for animal_id_variant: Variant in expected_identities.keys():
		var animal_id: StringName = StringName(animal_id_variant)
		var expected: String = String(expected_identities[animal_id_variant])
		if WildDashAnimalAbilityProfile.get_identity(animal_id) != expected:
			failures.append("Identity mismatch for %s" % String(animal_id))

	if WildDashAnimalSpecialAbilitySystem.get_special_cooldown(&"boar") != 6.0:
		failures.append("Boar Mud Gas cooldown changed")
	if WildDashAnimalSpecialAbilitySystem.get_special_cooldown(&"bear") != 7.0:
		failures.append("Bear Heavy Gas cooldown changed")
	if WildDashAnimalSpecialAbilitySystem.get_special_cooldown(&"raccoon") != 7.0:
		failures.append("Raccoon Stink Cloud cooldown changed")
	if WildDashAnimalSpecialAbilitySystem.get_special_cooldown(&"monkey") != 5.5:
		failures.append("Monkey Jet Fart cooldown changed")
	if ROUND2_SCENE == null or ROUND4_SCENE == null:
		failures.append("Active Round 2 or Round 4 scene failed to preload")

	if failures.is_empty():
		print("COMBAT V2 FINAL SMOKE PASS roles=12 heavy=true hunter=true thief=true water_ambush=true fart_balance=true")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("COMBAT V2 FINAL SMOKE FAIL: %s" % failure)
	get_tree().quit(1)

func _check_ability(failures: Array[String], animal_id: StringName, spec: WildDashCombatAbilitySpec, expected_id: StringName) -> void:
	if spec == null or spec.ability_id != expected_id:
		failures.append("Ability mismatch for %s expected=%s" % [String(animal_id), String(expected_id)])
