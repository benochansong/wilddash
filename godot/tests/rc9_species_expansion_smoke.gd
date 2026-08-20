extends Node

const GRAND_PRIX_SCENE: PackedScene = preload("res://modes/grand_prix/grand_prix.tscn")
const FRUIT_FRENZY_SCENE: PackedScene = preload("res://modes/fruit_collection/fruit_collection.tscn")
const WILD_RUMBLE_SCENE: PackedScene = preload("res://modes/push_out/push_out.tscn")
const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")
const FUTURE_ITEMS: Script = preload("res://items/future_item_catalog.gd")

func _ready() -> void:
	var failures: Array[String] = []
	var roster := WildDashAnimalCatalog.playable_ids()
	if roster.size() != 12:
		failures.append("playable roster must remain 12")
	if not roster.has(&"crocodile") or roster.has(&"panda"):
		failures.append("active roster must contain Crocodile and archive Panda")
	if WildDashAnimalCatalog.get_definition(&"panda") == null:
		failures.append("Panda definition must remain preserved for future expansion")

	var croc := WildDashAnimalAbilityProfile.get_profile(&"crocodile")
	var expected := {
		"swim": 10.0, "climb": 4.0, "agility": 4.5,
		"power": 8.5, "rough": 9.0, "defense": 8.5,
	}
	for key in expected.keys():
		if not is_equal_approx(float(croc.get(key, -1.0)), float(expected[key])):
			failures.append("Crocodile stat mismatch %s" % key)

	var croc_definition := WildDashAnimalCatalog.get_definition(&"crocodile")
	if croc_definition == null or croc_definition.visual_scene == null:
		failures.append("Crocodile definition/visual missing")
	else:
		var water_multiplier := WildDashTerrainAbilitySystem.get_terrain_speed_multiplier(&"crocodile", WildDashTerrainAbilitySystem.TERRAIN_WATER)
		var arena_water_speed := croc_definition.arena_move_speed * water_multiplier
		if absf(arena_water_speed - 10.0) > 0.15:
			failures.append("Crocodile Fruit Frenzy water speed should be about 10.0, got %.2f" % arena_water_speed)

	var special_expectations := {
		&"boar": 6.0,
		&"bear": 7.0,
		&"raccoon": 7.0,
		&"monkey": 5.5,
	}
	for animal_id in special_expectations.keys():
		if not WildDashAnimalSpecialAbilitySystem.can_use_special(animal_id, &"fruit_collection"):
			failures.append("Round 2 special missing for %s" % String(animal_id))
		if not WildDashAnimalSpecialAbilitySystem.can_use_special(animal_id, &"push_out"):
			failures.append("Round 4 special missing for %s" % String(animal_id))
		if not is_equal_approx(WildDashAnimalSpecialAbilitySystem.get_special_cooldown(animal_id), float(special_expectations[animal_id])):
			failures.append("special cooldown mismatch for %s" % String(animal_id))

	var monkey := RACER_SCENE.instantiate() as WildDashCharacterController
	if monkey == null:
		failures.append("shared racer scene failed")
	else:
		monkey.is_player = false
		monkey.movement_mode = WildDashCharacterController.MovementMode.ARENA
		monkey.animal_id = &"monkey"
		add_child(monkey)
		await get_tree().physics_frame
		var tree_fruit := MeshInstance3D.new()
		WildDashFruitAccessSystem.configure_fruit(tree_fruit, WildDashFruitAccessSystem.FruitAccessType.TREE, 9.5, 7.5, 3)
		if not WildDashFruitAccessSystem.can_racer_reach_fruit(monkey, tree_fruit):
			failures.append("Monkey must reach high Tree Fruit")
		tree_fruit.queue_free()

	if FUTURE_ITEMS.get_staged_count() != 4:
		failures.append("four future Round 1 items must remain staged")
	if GRAND_PRIX_SCENE == null or FRUIT_FRENZY_SCENE == null or WILD_RUMBLE_SCENE == null:
		failures.append("one or more active round scenes failed to preload")

	if failures.is_empty():
		print("RC9 SPECIES EXPANSION SMOKE PASS roster=12 crocodile=true vertical_fruit=true specials=4 item_chaos=true staged_items=4")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("RC9 SPECIES EXPANSION SMOKE FAIL: %s" % failure)
	get_tree().quit(1)
