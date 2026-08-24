extends "res://modes/logspire_leap/logspire_leap_v6_titan_lower_playability.gd"

## Spectator-only adapter over the current production Titan lower-route stack.
## Normal play is unchanged. In spectator mode the logical featured racer is
## driven by the same lower-route AI stack as the field and the camera is watch-only.

const SPECTATOR_MODE = preload("res://scripts/spectator_mode.gd")

func _ready() -> void:
	await super()
	if not SPECTATOR_MODE.is_enabled() or DisplayServer.get_name() == "headless" or player == null:
		return
	var driver := spawn_ai_driver(
		player,
		WildDashAIController.AIMode.RACE,
		clampf(player.max_speed * 0.90, 10.5, 15.5),
		0.0,
		0.02,
		false
	)
	if driver != null:
		driver.steering_strength = 8.0
		driver.acceleration = 25.0
		driver.avoidance_distance = 5.2
		driver.set_race_route(_safe_route_with_runout)
		_attach_platform_ai(player, driver, _safe_route_with_runout, _safe_route_ids, ROUTE_SAFE)
		_attach_item_brain(player, driver)
	SPECTATOR_MODE.install_camera(self, racers)
	print("SPECTATOR ROUND READY round=3 mode=logspire_leap all_ai=true racers=%d production_base=v6_titan_lower" % racers.size())

func _on_any_racer_finished(racer: Node3D, rank: int) -> void:
	super(racer, rank)
	if SPECTATOR_MODE.is_enabled() and racer == player and not mode_finished:
		_on_player_finished(rank)
