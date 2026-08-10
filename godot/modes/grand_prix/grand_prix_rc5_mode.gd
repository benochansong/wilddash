extends "res://modes/grand_prix/grand_prix_mode.gd"

# The extended 2.47 km course is substantially longer than the prototype
# Grand Prix. RC5 keeps the relative item/skill multipliers intact and raises
# only the production race envelope so a full-throttle Normal run can land in
# the intended 130-170 second window.
const RC5_RACER_MAX_SPEED_SCALE := 1.35
const RC5_RACER_CRUISE_SPEED_SCALE := 1.10
const RC5_RACER_ACCELERATION_SCALE := 1.08

func _ready() -> void:
	await super._ready()
	var production_pace := DisplayServer.get_name() != "headless" or OS.has_environment("WILDDASH_REALTIME_BALANCE")
	if not production_pace:
		return

	for racer in RaceManager.racers:
		if not racer is WildDashCharacterController:
			continue
		var controller := racer as WildDashCharacterController
		controller.max_speed *= RC5_RACER_MAX_SPEED_SCALE
		controller.cruise_speed *= RC5_RACER_CRUISE_SPEED_SCALE
		controller.acceleration *= RC5_RACER_ACCELERATION_SCALE

	# The headless real-time balance proxy drives the Player with an AI driver.
	# Sync only that preserved-player driver to the same production max speed;
	# normal automated campaign runs keep the existing accelerated CI profile.
	if DisplayServer.get_name() == "headless":
		for driver in ai_drivers:
			if driver != null and driver.preserve_player_identity:
				driver.target_speed = player.max_speed
				driver.acceleration = player.acceleration
				break

	print("RC5 PRODUCTION PACE PASS player_max=%.2f cruise=%.2f accel=%.2f racer_scale=%.2f ai_scale=%.2f" % [
		player.max_speed,
		player.cruise_speed,
		player.acceleration,
		RC5_RACER_MAX_SPEED_SCALE,
		WildDashAIPackTactics.PRODUCTION_PACE_SCALE,
	])
