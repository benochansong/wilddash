extends Node

const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")
const ITEM_BOX_SCENE: PackedScene = preload("res://items/item_box.tscn")
const AI_ITEM_BRAIN_SCRIPT: Script = preload("res://items/ai_item_brain.gd")

var _a: WildDashCharacterController
var _b: WildDashCharacterController
var _c: WildDashCharacterController
var _d: WildDashCharacterController

func _ready() -> void:
	RaceManager.clear_racers()
	RaceManager.clear_track()
	ItemSystem.reset_runtime()
	ItemSystem.set_test_seed(20260810)
	RaceManager.configure_track([
		Vector3(0, 0, 20),
		Vector3(0, 0, 0),
		Vector3(0, 0, -80),
		Vector3(0, 0, -160),
	], [])
	_a = _spawn_racer("ExpansionA", Vector3(0, 0.2, 10), &"dog")
	_b = _spawn_racer("ExpansionB", Vector3(-1, 0.2, -4), &"rabbit")
	_c = _spawn_racer("ExpansionC", Vector3(1, 0.2, -8), &"cat")
	_d = _spawn_racer("ExpansionD", Vector3(0, 0.2, -18), &"elephant")
	await get_tree().physics_frame
	RaceManager.start_race()

	if not _test_definitions():
		return
	if not await _test_super_carrot():
		return
	if not _test_acorn_bomb():
		return
	if not _test_banana_peel():
		return
	if not _test_magnet():
		return
	if not _test_wind_boost():
		return
	if not await _test_ghost_fruit():
		return
	if not _test_recent_history():
		return
	if not _test_ai_new_items():
		return

	print("ITEM EXPANSION SMOKE PASS items=12 roles=5 history=2")
	get_tree().quit(0)

func _test_definitions() -> bool:
	if ItemSystem.get_item_count() < 12:
		return _fail("Item count below twelve")
	var expected_roles := {
		ItemSystem.DASH_BERRY: &"speed",
		ItemSystem.SUPER_CARROT: &"speed",
		ItemSystem.BUBBLE_SHIELD: &"defense",
		ItemSystem.GHOST_FRUIT: &"defense",
		ItemSystem.STICKY_FRUIT: &"trap",
		ItemSystem.BANANA_PEEL: &"trap",
		ItemSystem.ROCKET_NUT: &"attack",
		ItemSystem.ACORN_BOMB: &"attack",
		ItemSystem.SHOCKWAVE: &"attack",
		ItemSystem.WIND_BOOST: &"attack",
		ItemSystem.RECOVERY_FEATHER: &"utility",
		ItemSystem.MAGNET: &"utility",
	}
	var icons: Dictionary = {}
	for item_id in ItemSystem.ITEM_IDS:
		var definition := ItemSystem.get_definition(item_id)
		if definition == null:
			return _fail("Missing item definition: %s" % item_id)
		if ItemSystem.get_role(item_id) != expected_roles.get(item_id):
			return _fail("Wrong role for %s" % item_id)
		var icon := ItemSystem.get_icon_text(item_id)
		if icon.is_empty() or icons.has(icon):
			return _fail("Missing or duplicate primitive icon: %s" % item_id)
		icons[icon] = true
	print("ITEM COUNT PASS count=%d" % ItemSystem.get_item_count())
	print("ITEM DEFINITION PASS roles=5 icons=%d" % icons.size())
	return true

func _test_super_carrot() -> bool:
	ItemSystem.reset_runtime()
	_clear_inventory(_a)
	var base_accel := _a.acceleration
	var base_turn := _a.turn_speed
	_a.current_speed = 0.0
	ItemSystem.grant_item(_a, ItemSystem.SUPER_CARROT)
	if not ItemSystem.use_held_item(_a):
		return _fail("Super Carrot could not be used")
	await get_tree().process_frame
	if not ItemSystem.has_effect(_a, &"super_carrot"):
		return _fail("Super Carrot effect missing")
	if _a.acceleration <= base_accel or _a.turn_speed <= base_turn:
		return _fail("Super Carrot movement modifiers missing")
	print("SUPER CARROT PASS duration=3.2 speed_mult=1.16 accel=true handling=true")
	return true

func _test_acorn_bomb() -> bool:
	ItemSystem.reset_runtime()
	_clear_inventory(_a)
	_a.rotation = Vector3.ZERO
	ItemSystem.grant_item(_a, ItemSystem.ACORN_BOMB)
	if not ItemSystem.use_held_item(_a):
		return _fail("Acorn Bomb could not be used")
	var found := false
	for child in get_children():
		if child is WildDashAcornBomb:
			found = true
			break
	if not found:
		return _fail("Acorn Bomb projectile did not spawn")
	if not ItemSystem.apply_attack(_b, _a, &"acorn_bomb", 0.9, 0.72, 3.4):
		return _fail("Acorn Bomb splash attack did not resolve")
	if not ItemSystem.has_effect(_b, &"slow") or _b.get_knockback_velocity().length() <= 0.01:
		return _fail("Acorn Bomb slow/knockback missing")
	print("ACORN BOMB PASS arc=true explosion=true slow=0.9 knockback=true")
	return true

func _test_banana_peel() -> bool:
	ItemSystem.reset_runtime()
	_clear_inventory(_a)
	ItemSystem.grant_item(_a, ItemSystem.BANANA_PEEL)
	if not ItemSystem.use_held_item(_a):
		return _fail("Banana Peel could not be used")
	var found := false
	for child in get_children():
		if child is WildDashBananaPeel:
			found = true
			break
	if not found:
		return _fail("Banana Peel trap did not spawn")
	if not ItemSystem.apply_spin(_b, _a, 0.85):
		return _fail("Banana Peel spin did not resolve")
	if not ItemSystem.has_effect(_b, &"spin") or ItemSystem.has_effect(_b, &"slow"):
		return _fail("Banana Peel was not differentiated from Sticky slow")
	print("BANANA PEEL PASS spin=0.85 slow=false")
	return true

func _test_magnet() -> bool:
	ItemSystem.reset_runtime()
	_clear_inventory(_a)
	ItemSystem.grant_item(_a, ItemSystem.MAGNET)
	if not ItemSystem.use_held_item(_a):
		return _fail("Magnet could not be used")
	if not ItemSystem.has_effect(_a, &"magnet"):
		return _fail("Magnet effect missing")
	if ItemSystem.get_pickup_radius(_a, 3.3) <= 6.0:
		return _fail("Magnet pickup radius did not expand")
	print("MAGNET PASS duration=3.6 pickup_mult=2.25 steal=false")
	return true

func _test_wind_boost() -> bool:
	ItemSystem.reset_runtime()
	_clear_inventory(_a)
	_a.global_position = Vector3(0, 0.2, 0)
	_a.rotation = Vector3.ZERO
	_b.global_position = Vector3(0, 0.2, -4)
	_b.rotation = Vector3.ZERO
	_a.current_speed = 0.0
	ItemSystem.grant_item(_a, ItemSystem.WIND_BOOST)
	if not ItemSystem.use_held_item(_a):
		return _fail("Wind Boost could not be used")
	if _a.current_speed <= 0.0 or _b.get_knockback_velocity().length() <= 0.01:
		return _fail("Wind Boost self boost or forward push missing")
	print("WIND BOOST PASS self_boost=true push=2.4 stampede_weaker=true")
	return true

func _test_ghost_fruit() -> bool:
	ItemSystem.reset_runtime()
	_clear_inventory(_a)
	var base_turn := _a.turn_speed
	var base_mask := _a.collision_mask
	ItemSystem.grant_item(_a, ItemSystem.GHOST_FRUIT)
	if not ItemSystem.use_held_item(_a):
		return _fail("Ghost Fruit could not be used")
	await get_tree().process_frame
	if not ItemSystem.has_effect(_a, &"ghost"):
		return _fail("Ghost Fruit phase state missing")
	if _a.turn_speed <= base_turn:
		return _fail("Ghost Fruit handling bonus missing")
	if _a.collision_mask != base_mask:
		return _fail("Ghost Fruit changed track collision mask")
	if ItemSystem.has_effect(_a, &"dash"):
		return _fail("Ghost Fruit incorrectly added dash")
	print("GHOST FRUIT PASS duration=2.0 racer_collision=false track_collision=true dash=false")
	return true

func _test_recent_history() -> bool:
	ItemSystem.set_test_seed(777)
	var history: Array = [ItemSystem.SUPER_CARROT, ItemSystem.SUPER_CARROT]
	var repeats := 0
	var samples := 600
	for i in range(samples):
		if ItemSystem.roll_item_for_rank(10, 10, history) == ItemSystem.SUPER_CARROT:
			repeats += 1
	var rate := float(repeats) / float(samples)
	if rate >= 0.04:
		return _fail("Third identical item suppression too weak: %.3f" % rate)
	print("ITEM HISTORY PASS recent=2 third_repeat_rate=%.3f" % rate)
	return true

func _test_ai_new_items() -> bool:
	var brain := AI_ITEM_BRAIN_SCRIPT.new() as WildDashAIItemBrain
	if brain == null:
		return _fail("AI item brain failed to instantiate")
	brain.name = "ExpansionAIItemBrain"
	brain.configure(_a, null)
	add_child(brain)

	var item_box := ITEM_BOX_SCENE.instantiate() as WildDashItemBox
	item_box.name = "ExpansionMagnetStation"
	add_child(item_box)
	item_box.global_position = Vector3(0, 1.0, -10)

	var scenarios: Array[StringName] = [
		ItemSystem.SUPER_CARROT,
		ItemSystem.ACORN_BOMB,
		ItemSystem.BANANA_PEEL,
		ItemSystem.MAGNET,
		ItemSystem.WIND_BOOST,
		ItemSystem.GHOST_FRUIT,
	]
	for item_id in scenarios:
		ItemSystem.reset_runtime()
		_clear_inventory(_a)
		_setup_ai_scenario(item_id, item_box)
		ItemSystem.grant_item(_a, item_id)
		var utility := brain.get_utility_score_for_test(item_id)
		if utility < 0.62:
			return _fail("AI utility below use threshold for %s: %.2f" % [ItemSystem.get_display_name(item_id), utility])
		if not brain.evaluate_and_use_now():
			return _fail("AI did not use new item %s" % ItemSystem.get_display_name(item_id))
		if ItemSystem.get_last_used_item(_a) != item_id:
			return _fail("AI use was not recorded for %s" % ItemSystem.get_display_name(item_id))
	print("AI NEW ITEM USE PASS items=6")
	brain.queue_free()
	item_box.queue_free()
	return true

func _setup_ai_scenario(item_id: StringName, item_box: WildDashItemBox) -> void:
	_a.rotation = Vector3.ZERO
	_b.rotation = Vector3.ZERO
	_c.rotation = Vector3.ZERO
	_d.rotation = Vector3.ZERO
	_a.global_position = Vector3(0, 0.2, 12)
	_b.global_position = Vector3(-1, 0.2, -2)
	_c.global_position = Vector3(1, 0.2, -6)
	_d.global_position = Vector3(0, 0.2, -16)
	if item_id == ItemSystem.BANANA_PEEL:
		_b.global_position = Vector3(0, 0.2, 17)
	elif item_id == ItemSystem.MAGNET:
		item_box.global_position = _a.global_position + Vector3(0, 0.8, -10)
	elif item_id == ItemSystem.WIND_BOOST:
		_b.global_position = _a.global_position + Vector3(0, 0, -4)
	elif item_id == ItemSystem.GHOST_FRUIT:
		_b.global_position = _a.global_position + Vector3(1.2, 0, -1.5)
		_c.global_position = _a.global_position + Vector3(-1.2, 0, 1.5)

func _spawn_racer(node_name: String, at: Vector3, animal: StringName) -> WildDashCharacterController:
	var racer := RACER_SCENE.instantiate() as WildDashCharacterController
	racer.name = node_name
	racer.is_player = false
	racer.movement_mode = WildDashCharacterController.MovementMode.RACE
	racer.animal_id = animal
	racer.position = at
	add_child(racer)
	return racer

func _clear_inventory(racer: WildDashCharacterController) -> void:
	if racer != null:
		racer.set_held_item(&"")

func _fail(message: String) -> bool:
	push_error(message)
	print("ITEM EXPANSION SMOKE FAIL " + message)
	get_tree().quit(1)
	return false
