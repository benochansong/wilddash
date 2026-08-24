extends "res://modes/fruit_collection/fruit_frenzy_v20_economy_combat_ai.gd"

const SPECTATOR_MODE = preload("res://scripts/spectator_mode.gd")

func _ready() -> void:
	await super()
	if not SPECTATOR_MODE.is_enabled() or DisplayServer.get_name() == "headless" or player == null:
		return

	var base_speed: float = clampf(player.arena_move_speed * 0.78, 6.6, 8.6)
	var featured_driver := spawn_ai_driver(
		player,
		WildDashAIController.AIMode.ARENA,
		base_speed,
		0.0,
		0.0,
		false
	)
	if featured_driver != null:
		# Keep all AI-decision arrays index-aligned by adding the featured racer as
		# the final AI slot. Existing Fruit Frenzy decision logic then drives it.
		ai_racers.append(player)
		ai_personalities.append(PERSONALITY_BALANCED)
		ai_base_target_speeds.append(base_speed)
		ai_scores.append(0)
	SPECTATOR_MODE.install_camera(self, racers)
	print("SPECTATOR ROUND READY round=2 mode=fruit_collection all_ai=true racers=%d" % racers.size())
