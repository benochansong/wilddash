extends Node

const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")
const CONTROLLER_SCRIPT: Script = preload("res://items/item_combat_expansion_controller.gd")
const CATALOG: Script = preload("res://items/expanded_item_catalog.gd")

var _failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	RaceManager.clear_racers()
	RaceManager.clear_track()
	ItemSystem.reset_runtime()
	RaceManager.active = true

	var world := Node3D.new()
	world.name = "ItemCombatHarness"
	add_child(world)
	var player := RACER_SCENE.instantiate() as WildDashCharacterController
	player.name = "Player"
	player.is_player = true
	player.position = Vector3.ZERO
	world.add_child(player)
	var target := RACER_SCENE.instantiate() as WildDashCharacterController
	target.name = "Target"
	target.is_player = false
	target.position = Vector3(0.0, 0.0, -7.0)
	world.add_child(target)
	var controller: WildDashItemCombatExpansionController = CONTROLLER_SCRIPT.new() as WildDashItemCombatExpansionController
	controller.name = "ItemCombatExpansionController"
	world.add_child(controller)
	await get_tree().physics_frame
	await get_tree().physics_frame

	if ItemSystem.get_item_count() != 12:
		_failures.append("base item count expected 12 got %d" % ItemSystem.get_item_count())
	if CATALOG.get_count() != 6:
		_failures.append("expanded item count expected 6 got %d" % CATALOG.get_count())
	if controller.get_total_item_count() != 18:
		_failures.append("combined item count expected 18 got %d" % controller.get_total_item_count())
	else:
		print("ITEM MATRIX PASS base=12 expanded=6 total=18")

	for item_id in CATALOG.ITEM_IDS:
		ItemSystem.reset_runtime()
		player.set_held_item(item_id)
		var used := controller.use_expanded_item(player, item_id)
		if not used:
			_failures.append("expanded use failed %s" % CATALOG.get_display_name(item_id))
			continue
		if player.get_held_item() != &"":
			_failures.append("expanded consume failed %s" % CATALOG.get_display_name(item_id))
		else:
			print("EXPANDED ITEM USE PASS item=%s role=%s" % [CATALOG.get_display_name(item_id), String(CATALOG.get_role(item_id))])
		await get_tree().process_frame

	# Rocket Nut must remain usable without a homing target: the reliability
	# controller supplies a straight, wall-aware fallback instead of silent fail.
	target.position = Vector3(80.0, 0.0, 80.0)
	player.set_held_item(ItemSystem.ROCKET_NUT)
	var fallback_used := bool(controller.call("_try_use_any_item", player, ItemSystem.ROCKET_NUT))
	if not fallback_used or player.get_held_item() != &"":
		_failures.append("rocket no-target fallback failed")
	else:
		print("ITEM FIRE RELIABILITY PASS rocket_no_target=straight_fallback")

	if not _failures.is_empty():
		for failure in _failures:
			push_error("ITEM COMBAT EXPANSION REGRESSION FAIL " + failure)
		RaceManager.active = false
		get_tree().quit(1)
		return
	print("ITEM COMBAT EXPANSION REGRESSION PASS total=18 expanded_use=6 rocket_fallback=true")
	RaceManager.active = false
	get_tree().quit(0)
