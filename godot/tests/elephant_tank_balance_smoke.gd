extends SceneTree

func _init() -> void:
	var failures: Array[String] = []

	var elephant_defense: float = WildDashRaceCombatBalance.get_defense_rating(&"elephant")
	var bear_defense: float = WildDashRaceCombatBalance.get_defense_rating(&"bear")
	var raccoon_defense: float = WildDashRaceCombatBalance.get_defense_rating(&"raccoon")
	if not (elephant_defense > bear_defense and bear_defense > raccoon_defense):
		failures.append("defense order must keep Elephant > Bear > Raccoon")

	var elephant_knockback: float = WildDashRaceCombatBalance.get_knockback_multiplier(&"elephant")
	var raccoon_knockback: float = WildDashRaceCombatBalance.get_knockback_multiplier(&"raccoon")
	if elephant_knockback >= 0.60:
		failures.append("Elephant must receive substantially reduced race knockback")
	if raccoon_knockback <= 1.15:
		failures.append("Raccoon must remain a clearly launchable featherweight")

	var light_launch: float = WildDashRaceCombatBalance.get_launch_strength(24.0, &"raccoon")
	var heavy_launch: float = WildDashRaceCombatBalance.get_launch_strength(24.0, &"elephant")
	if light_launch < 4.0:
		failures.append("Elephant full trunk power must visibly launch a featherweight")
	if heavy_launch > 0.01:
		failures.append("Elephant should not be vertically launched by the same trunk power")

	var elephant_item: float = WildDashRaceCombatBalance.get_item_disruption_multiplier(&"elephant")
	if elephant_item > 0.55:
		failures.append("IRON HIDE item disruption multiplier is too weak")

	var elephant_trap: float = WildDashRaceCombatBalance.get_trap_launch_multiplier(&"elephant")
	if elephant_trap > 0.50:
		failures.append("Elephant spring-trap launch resistance is too weak")

	if failures.is_empty():
		print("RC9 ELEPHANT TANK BALANCE PASS defense=%.1f item=%.2f trunk_light_launch=%.2f trap=%.2f" % [
			elephant_defense, elephant_item, light_launch, elephant_trap,
		])
		quit(0)
		return

	for failure: String in failures:
		push_error("RC9 ELEPHANT TANK BALANCE FAIL: %s" % failure)
	quit(1)
