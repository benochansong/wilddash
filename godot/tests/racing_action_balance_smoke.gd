extends SceneTree

func _init() -> void:
	var failures: Array[String] = []

	var normal_target: float = WildDashRacingActionController.get_normal_race_target(20.0, 12.0)
	var boost_target: float = WildDashRacingActionController.get_overdrive_target(20.0)
	if not normal_target < 20.0:
		failures.append("normal race target must remain below max speed")
	if not boost_target > 20.0:
		failures.append("boost target must exceed max speed")
	if WildDashRacingActionController.BOOST_DURATION < 0.8 or WildDashRacingActionController.BOOST_DURATION > 1.3:
		failures.append("boost duration left the short tactical burst envelope")
	var recharge_seconds: float = WildDashRacingActionController.BOOST_ENERGY_MAX / WildDashRacingActionController.BOOST_RECHARGE_PER_SECOND
	if recharge_seconds < 3.5 or recharge_seconds > 5.5:
		failures.append("boost recharge left the intended 3.5-5.5 second tuning window")

	var elephant_power: float = WildDashRacingActionController.get_body_check_power(&"elephant")
	var bear_power: float = WildDashRacingActionController.get_body_check_power(&"bear")
	var boar_power: float = WildDashRacingActionController.get_body_check_power(&"boar")
	var panda_power: float = WildDashRacingActionController.get_body_check_power(&"panda")
	if not (elephant_power > bear_power and bear_power > boar_power and boar_power > panda_power):
		failures.append("heavy body-check power order must remain Elephant > Bear > Boar > Panda")

	var elephant_into_raccoon: float = WildDashRacingActionController.calculate_body_check_impulse(&"elephant", &"raccoon")
	var raccoon_into_elephant: float = WildDashRacingActionController.calculate_body_check_impulse(&"raccoon", &"elephant")
	if elephant_into_raccoon <= raccoon_into_elephant * 2.5:
		failures.append("heavy-vs-light body check must be clearly stronger than light-vs-heavy")
	if elephant_into_raccoon > 10.5:
		failures.append("maximum body-check impulse is too high for controlled race contact")

	if failures.is_empty():
		print("RC9 RACING ACTION BALANCE PASS normal=%.2f boost=%.2f recharge=%.2fs elephant_raccoon=%.2f raccoon_elephant=%.2f" % [
			normal_target, boost_target, recharge_seconds, elephant_into_raccoon, raccoon_into_elephant,
		])
		quit(0)
		return

	for failure: String in failures:
		push_error("RC9 RACING ACTION BALANCE FAIL: %s" % failure)
	quit(1)
