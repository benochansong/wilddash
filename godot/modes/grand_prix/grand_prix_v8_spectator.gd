extends "res://modes/grand_prix/grand_prix_v7_wild_moments.gd"

const SPECTATOR_MODE = preload("res://scripts/spectator_mode.gd")

func _ready() -> void:
	await super()
	if not SPECTATOR_MODE.is_enabled() or DisplayServer.get_name() == "headless" or player == null:
		return
	var driver := spawn_ai_driver(
		player,
		WildDashAIController.AIMode.RACE,
		clampf(player.max_speed * 0.96, 11.0, 18.0),
		0.0,
		0.06,
		false
	)
	if driver != null:
		driver.steering_strength = 6.2
		driver.acceleration = 24.0
		driver.avoidance_distance = 8.2
		driver.set_race_route(_build_race_route_with_runout())
		var item_brain := AI_ITEM_BRAIN_SCRIPT.new() as WildDashAIItemBrain
		if item_brain != null:
			item_brain.name = "SpectatorFeaturedItemBrain"
			item_brain.configure(player, driver)
			add_child(item_brain)
			_ai_item_brains.append(item_brain)
	SPECTATOR_MODE.install_camera(self, racers)
	print("SPECTATOR ROUND READY round=1 mode=grand_prix all_ai=true racers=%d" % racers.size())

func _on_any_racer_finished(racer: Node3D, rank: int) -> void:
	super(racer, rank)
	if SPECTATOR_MODE.is_enabled() and racer == player and not mode_finished:
		_on_player_finished(rank)
