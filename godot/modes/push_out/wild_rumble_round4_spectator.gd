extends "res://modes/push_out/wild_rumble_round4_wild_moments.gd"

const SPECTATOR_MODE = preload("res://scripts/spectator_mode.gd")

func _ready() -> void:
	await super()
	if not SPECTATOR_MODE.is_enabled() or DisplayServer.get_name() == "headless" or player == null:
		return
	var arena_speed: float = clampf(player.arena_move_speed * 0.72, 5.4, 7.4)
	var featured_driver := spawn_ai_driver(
		player,
		WildDashAIController.AIMode.ARENA,
		arena_speed,
		0.0,
		0.0,
		false
	)
	if featured_driver != null:
		# The existing Round 4 target/combat loops operate on ai_racers, so the
		# logical featured racer joins that field only while spectating.
		ai_racers.append(player)
		_ai_push_cooldowns.append(0.55)
	SPECTATOR_MODE.install_camera(self, racers)
	print("SPECTATOR ROUND READY round=4 mode=push_out all_ai=true racers=%d" % racers.size())
