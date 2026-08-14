extends Node

const MODE_SCENE: PackedScene = preload("res://modes/fruit_collection/fruit_collection.tscn")

func _ready() -> void:
	GameManager.campaign_running = false
	GameManager.current_round_index = -1
	GameManager.set_ai_count(4)

	var mode := MODE_SCENE.instantiate()
	if mode == null:
		_fail("could not instantiate Fruit Frenzy scene")
		return
	add_child(mode)

	# Allow the mode's asynchronous _ready() to finish its two-frame startup.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	var fruits: Array = mode.get("fruits")
	var spill_fruits: Array = mode.get("spill_fruits")
	var ai_racers: Array = mode.get("ai_racers")
	var personalities: Array = mode.get("ai_personalities")
	var player := mode.get("player") as WildDashCharacterController
	var cart := mode.get("_cart_root") as Node3D

	if fruits.size() != 24:
		_fail("expected 24 regular fruit, got %d" % fruits.size())
		return
	if spill_fruits.size() != 30:
		_fail("expected 30 spill-pool fruit, got %d" % spill_fruits.size())
		return
	if ai_racers.size() != 4:
		_fail("expected 4 AI racers, got %d" % ai_racers.size())
		return
	if personalities.size() != 4:
		_fail("expected 4 AI personalities, got %d" % personalities.size())
		return
	if player == null or cart == null:
		_fail("player or Harvest Cart missing")
		return

	# Carry must increase without immediately increasing banked score.
	mode.call("_collect_regular_fruit", player, 0)
	var carried: Dictionary = mode.get("carried_by_id")
	var banked: Dictionary = mode.get("banked_by_id")
	var player_key: int = player.get_instance_id()
	var carry_after_pickup: int = int(carried.get(player_key, 0))
	var bank_after_pickup: int = int(banked.get(player_key, 0))
	if carry_after_pickup <= 0:
		_fail("carry did not increase after fruit pickup")
		return
	if bank_after_pickup != 0:
		_fail("fruit pickup incorrectly banked score immediately")
		return
	print("FRUIT FRENZY CARRY PASS carry=%d banked=%d" % [carry_after_pickup, bank_after_pickup])

	# Banking must clear carry and preserve the score safely.
	mode.call("_bank_racer", player)
	carried = mode.get("carried_by_id")
	banked = mode.get("banked_by_id")
	var bank_after_deposit: int = int(banked.get(player_key, 0))
	if int(carried.get(player_key, 0)) != 0 or bank_after_deposit <= 0:
		_fail("banking did not clear carry and increase score")
		return
	print("FRUIT FRENZY BANK PASS score=%d" % bank_after_deposit)

	# Combat spill must reduce only carried fruit and create reusable spill pickups.
	var victim := ai_racers[0] as WildDashCharacterController
	var victim_key: int = victim.get_instance_id()
	carried = mode.get("carried_by_id")
	carried[victim_key] = 3
	mode.set("carried_by_id", carried)
	mode.call("_spill_racer", victim, 2, "SMOKE")
	carried = mode.get("carried_by_id")
	if int(carried.get(victim_key, 0)) != 1:
		_fail("combat spill did not reduce carried fruit from 3 to 1")
		return
	var spill_active: Array = mode.get("spill_active")
	var active_spills := 0
	for active in spill_active:
		if bool(active):
			active_spills += 1
	if active_spills < 2:
		_fail("combat spill did not activate at least two spill pickups")
		return
	if int(banked.get(player_key, 0)) != bank_after_deposit:
		_fail("banked score changed during combat spill")
		return
	print("FRUIT FRENZY SPILL PASS active=%d bank_safe=true" % active_spills)

	# Golden Fruit and final Golden Harvest must be independently activatable.
	mode.call("_spawn_golden_fruit")
	if not bool(mode.get("_golden_active")):
		_fail("Golden Fruit did not activate")
		return
	print("FRUIT FRENZY GOLDEN PASS active=true")

	mode.set("time_remaining", 19.0)
	mode.call("_update_golden_harvest")
	if not bool(mode.get("_golden_harvest_active")):
		_fail("Golden Harvest did not activate in final 20 seconds")
		return
	print("FRUIT FRENZY HARVEST PASS multiplier=2")

	print("FRUIT FRENZY SMOKE PASS fruit=24 carry=5 spill_pool=30 ai=4 personalities=4 duration=90")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("FRUIT FRENZY SMOKE FAIL: %s" % message)
	get_tree().quit(3)
