extends SceneTree

const ANIMALS: Array[StringName] = [
	&"dog", &"wolf", &"boar", &"rabbit", &"deer", &"monkey",
	&"elephant", &"bear", &"panda", &"cat", &"fox", &"raccoon",
]

func _init() -> void:
	var failures: Array[String] = []

	for animal_id: StringName in ANIMALS:
		if not WildDashRaceCombatProfile.has_complete_profile(animal_id):
			failures.append("missing complete combat profile for %s" % String(animal_id))
			continue
		var profile: Dictionary = WildDashRaceCombatProfile.get_profile(animal_id)
		if float(profile["attack_power"]) <= 0.0:
			failures.append("attack_power must be positive for %s" % String(animal_id))
		if float(profile["defense"]) <= 0.0:
			failures.append("defense must be positive for %s" % String(animal_id))
		if float(profile["stability"]) <= 0.0:
			failures.append("stability must be positive for %s" % String(animal_id))
		if float(profile["cooldown"]) <= 0.0:
			failures.append("cooldown must be positive for %s" % String(animal_id))
		if float(profile["range"]) <= 0.0:
			failures.append("range must be positive for %s" % String(animal_id))
		if float(profile["launch"]) <= 0.0:
			failures.append("launch must be positive for %s" % String(animal_id))

	if not (
		WildDashRaceCombatProfile.get_defense(&"elephant")
		> WildDashRaceCombatProfile.get_defense(&"bear")
		and WildDashRaceCombatProfile.get_defense(&"bear")
		> WildDashRaceCombatProfile.get_defense(&"raccoon")
	):
		failures.append("defense order must keep Elephant > Bear > Raccoon")

	if WildDashRaceCombatProfile.get_stability(&"cat") <= WildDashRaceCombatProfile.get_stability(&"dog"):
		failures.append("Cat should recover with higher stability than Dog")

	var tap: Dictionary = {
		"sequence": 1,
		"kind": &"tap",
		"direction": 0,
		"direction_name": &"neutral",
		"held_seconds": 0.18,
	}
	var hold_right: Dictionary = {
		"sequence": 2,
		"kind": &"hold",
		"direction": 1,
		"direction_name": &"right",
		"held_seconds": 0.50,
	}
	var tap_command: Dictionary = WildDashRaceCombatCoreV2.build_tuned_command(tap, &"bear")
	var hold_command: Dictionary = WildDashRaceCombatCoreV2.build_tuned_command(hold_right, &"bear")
	if float(hold_command["attack_power"]) <= float(tap_command["attack_power"]):
		failures.append("hold attack must exceed tap attack power")
	if float(hold_command["range"]) <= float(tap_command["range"]):
		failures.append("hold directional attack must exceed tap range")
	if float(hold_command["launch"]) <= float(tap_command["launch"]):
		failures.append("hold attack must exceed tap launch rating")
	if float(hold_command["cooldown"]) <= float(tap_command["cooldown"]):
		failures.append("hold attack must pay a longer cooldown")

	if failures.is_empty():
		print("RC9 COMBAT V2 SMOKE PASS profiles=%d elephant_def=%.1f bear_hold_atk=%.1f bear_hold_range=%.2f" % [
			ANIMALS.size(),
			WildDashRaceCombatProfile.get_defense(&"elephant"),
			float(hold_command["attack_power"]),
			float(hold_command["range"]),
		])
		quit(0)
		return

	for failure: String in failures:
		push_error("RC9 COMBAT V2 SMOKE FAIL: %s" % failure)
	quit(1)
