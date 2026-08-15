extends Node

func _ready() -> void:
	var expected_ids: Array[StringName] = WildDashAnimalCatalog.playable_ids()
	if expected_ids.size() != 12:
		_fail("expected 12 playable animals, got %d" % expected_ids.size())
		return

	for animal_id: StringName in expected_ids:
		if not WildDashAnimalAbilityProfile.has_complete_profile(animal_id):
			_fail("incomplete or out-of-range profile: %s" % animal_id)
			return
		var ability: Dictionary = WildDashAnimalAbilityProfile.get_profile(animal_id)
		var terrain: Dictionary = WildDashRaceTerrainProfile.get_profile(animal_id)
		var combat: Dictionary = WildDashRaceCombatProfile.get_profile(animal_id)
		for stat_id: StringName in [&"swim", &"climb", &"agility", &"power", &"rough"]:
			var key := String(stat_id)
			if not is_equal_approx(float(ability[key]), float(terrain[key])):
				_fail("terrain mismatch %s %s" % [animal_id, key])
				return
		if not is_equal_approx(float(ability["defense"]), float(combat["defense"])):
			_fail("defense mismatch %s" % animal_id)
			return
		if not is_equal_approx(float(ability["power"]), float(combat["attack_power"])):
			_fail("power mismatch %s" % animal_id)
			return

	print("ANIMAL ABILITY PROFILE SMOKE PASS animals=12 stats=6 source=WildDashAnimalAbilityProfile")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("ANIMAL ABILITY PROFILE SMOKE FAIL: %s" % message)
	get_tree().quit(3)
