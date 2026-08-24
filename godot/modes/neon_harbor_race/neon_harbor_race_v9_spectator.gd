extends "res://modes/neon_harbor_race/neon_harbor_race_v8_round5_campaign.gd"

const SPECTATOR_MODE = preload("res://scripts/spectator_mode.gd")

func _ready() -> void:
	super._ready()
	if SPECTATOR_MODE.is_enabled() and DisplayServer.get_name() != "headless":
		call_deferred("_bootstrap_round5_spectator")

func _bootstrap_round5_spectator() -> void:
	for _attempt: int in range(180):
		if player != null and _route_points.size() >= 2:
			break
		await get_tree().physics_frame
	if not SPECTATOR_MODE.is_enabled() or player == null or _route_points.size() < 2:
		push_warning("SPECTATOR ROUND 5 bootstrap unavailable")
		return

	var driver := spawn_ai_driver(
		player,
		WildDashAIController.AIMode.RACE,
		clampf(player.max_speed * 0.94, 11.0, 19.0),
		0.0,
		0.08,
		false
	)
	if driver != null:
		driver.steering_strength = 6.8
		driver.acceleration = 25.0
		driver.avoidance_distance = 8.5
		driver.set_race_route(_build_race_route_with_runout())
		var item_brain := AI_ITEM_BRAIN_SCRIPT.new() as WildDashAIItemBrain
		if item_brain != null:
			item_brain.name = "SpectatorFeaturedItemBrain"
			item_brain.configure(player, driver)
			add_child(item_brain)
			_ai_item_brains.append(item_brain)
	var finish_callable := Callable(self, "_spectator_featured_finished")
	if not RaceManager.racer_finished.is_connected(finish_callable):
		RaceManager.racer_finished.connect(finish_callable)
	SPECTATOR_MODE.install_camera(self, racers)
	print("SPECTATOR ROUND READY round=5 mode=neon_harbor_race all_ai=true racers=%d" % racers.size())

func _on_any_racer_finished(racer: Node3D, rank: int) -> void:
	super(racer, rank)
	if SPECTATOR_MODE.is_enabled() and racer == player and not mode_finished:
		_on_player_finished(rank)

func _spectator_featured_finished(racer: Node3D, rank: int) -> void:
	if SPECTATOR_MODE.is_enabled() and racer == player and not mode_finished:
		print("SPECTATOR FEATURED FINISH round=5 rank=%d advancing_campaign=true" % rank)
		_on_player_finished(rank)
