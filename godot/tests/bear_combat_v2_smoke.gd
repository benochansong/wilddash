extends SceneTree

func _init() -> void:
	var failures: Array[String] = []
	var tap_action: Dictionary = {
		"kind": &"tap",
		"direction": 0,
		"direction_name": &"neutral",
		"held_seconds": 0.12,
	}
	var hold_action: Dictionary = {
		"kind": &"hold",
		"direction": 0,
		"direction_name": &"neutral",
		"held_seconds": 0.50,
	}
	var tap: Dictionary = WildDashRaceCombatCoreV2.build_tuned_command(tap_action, &"bear")
	var hold: Dictionary = WildDashRaceCombatCoreV2.build_tuned_command(hold_action, &"bear")

	if float(tap["attack_power"]) < 9.4:
		failures.append("Bear tap attack power must remain heavy-bruiser tier")
	if float(hold["attack_power"]) <= float(tap["attack_power"]):
		failures.append("Bear hold attack must exceed tap attack power")
	if float(tap["range"]) < 5.0:
		failures.append("Bear tap range must support close-pack combat")
	if float(tap["cooldown"]) > 1.80:
		failures.append("Bear tap cooldown is too slow to compensate for low race speed")
	if WildDashRaceCombatProfile.get_defense(&"bear") < 8.9:
		failures.append("Bear must remain fortress-tier defense")
	if WildDashRaceCombatProfile.get_stability(&"bear") < 8.9:
		failures.append("Bear must recover quickly after contact")

	var tap_raw: float = float(tap["attack_power"]) * 2.20
	var hold_raw: float = float(hold["attack_power"]) * 2.20
	var raccoon_tap: float = WildDashRaceCombatBalance.get_ring_out_impulse(tap_raw, &"raccoon")
	var raccoon_hold: float = WildDashRaceCombatBalance.get_ring_out_impulse(hold_raw, &"raccoon")
	var bear_hold_received: float = WildDashRaceCombatBalance.get_ring_out_impulse(hold_raw, &"bear")
	if raccoon_tap < 32.0:
		failures.append("Bear shoulder bash must heavily displace featherweights")
	if raccoon_hold < 44.0:
		failures.append("Bear slam must be a real ring-out threat to Raccoon")
	if bear_hold_received >= raccoon_hold * 0.65:
		failures.append("Bear defense must clearly resist the same heavy impact")

	# Race-damage pass: a successful Bear hit must cost real race time, not only
	# produce a visual knockback. Defense/Stability must still protect heavy racers.
	var cat_tap_damage: float = WildDashBearCombatV2Controller.get_race_damage(&"tap", &"cat")
	var elephant_tap_damage: float = WildDashBearCombatV2Controller.get_race_damage(&"tap", &"elephant")
	var cat_hold_damage: float = WildDashBearCombatV2Controller.get_race_damage(&"hold", &"cat")
	var cat_tap_disruption: float = WildDashBearCombatV2Controller.get_disruption_seconds(&"tap", &"cat")
	var cat_hold_disruption: float = WildDashBearCombatV2Controller.get_disruption_seconds(&"hold", &"cat")
	var cat_hold_cap: float = WildDashBearCombatV2Controller.get_disruption_speed_cap_ratio(&"hold", &"cat")
	var elephant_hold_cap: float = WildDashBearCombatV2Controller.get_disruption_speed_cap_ratio(&"hold", &"elephant")

	if cat_tap_damage <= elephant_tap_damage:
		failures.append("Low-defense racers must take more Bear momentum damage than Elephant")
	if cat_hold_damage <= cat_tap_damage * 1.45:
		failures.append("Bear Slam must create materially more race damage than Shoulder Bash")
	if cat_tap_disruption < 0.70:
		failures.append("Bear Shoulder Bash disruption is too short to create race-position loss")
	if cat_hold_disruption <= cat_tap_disruption:
		failures.append("Bear Slam disruption must last longer than Shoulder Bash")
	if cat_hold_cap >= 0.62:
		failures.append("Bear Slam must significantly cap a light racer's recovery speed")
	if elephant_hold_cap <= cat_hold_cap:
		failures.append("Elephant Defense must preserve a higher post-hit recovery speed cap")

	if failures.is_empty():
		print("RC9 BEAR COMBAT V2 PASS tap_atk=%.2f hold_atk=%.2f tap_raccoon=%.2f hold_raccoon=%.2f bear_received=%.2f cat_tap_damage=%.1f elephant_tap_damage=%.1f cat_hold_damage=%.1f cat_tap_disruption=%.2fs cat_hold_disruption=%.2fs cat_hold_cap=%.2f elephant_hold_cap=%.2f" % [
			float(tap["attack_power"]),
			float(hold["attack_power"]),
			raccoon_tap,
			raccoon_hold,
			bear_hold_received,
			cat_tap_damage,
			elephant_tap_damage,
			cat_hold_damage,
			cat_tap_disruption,
			cat_hold_disruption,
			cat_hold_cap,
			elephant_hold_cap,
		])
		quit(0)
		return

	for failure: String in failures:
		push_error("RC9 BEAR COMBAT V2 FAIL: %s" % failure)
	quit(1)
