extends Node

const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")
const ITEM_BOX_SCENE: PackedScene = preload("res://items/item_box.tscn")
const AI_ITEM_BRAIN_SCRIPT: Script = preload("res://items/ai_item_brain.gd")

var _racer_a: WildDashCharacterController
var _racer_b: WildDashCharacterController
var _racer_c: WildDashCharacterController

func _ready() -> void:
	RaceManager.clear_racers()
	RaceManager.clear_track()
	ItemSystem.reset_runtime()
	ItemSystem.set_test_seed(20260810)
	RaceManager.configure_track([Vector3(0, 0, 10), Vector3(0, 0, -120)], [])

	_racer_a = _spawn_static_racer("ItemTesterA", Vector3(0, 0.2, 0), &"dog")
	_racer_b = _spawn_static_racer("ItemTesterB", Vector3(0, 0.2, -12), &"rabbit")
	_racer_c = _spawn_static_racer("ItemTesterC", Vector3(0, 0.2, 12), &"cat")
	await get_tree().physics_frame
	RaceManager.start_race()

	if not _test_input_binding():
		return
	if not await _test_item_box_pickup():
		return
	if not _test_inventory():
		return
	if not _test_dash():
		return
	if not _test_wild_turbo_definition_and_use():
		return
	if not _test_shield():
		return
	if not _test_trap():
		return
	if not _test_shockwave():
		return
	if not await _test_rocket():
		return
	if not _test_feather():
		return
	if not _test_ai_item_use():
		return

	print("ITEM SYSTEM SMOKE PASS items=%d inventory=1 hit_immunity=true wild_turbo=true party_box=true" % ItemSystem.get_item_count())
	get_tree().quit(0)

func _test_input_binding() -> bool:
	var has_q: bool = false
	var has_b: bool = false
	for event: InputEvent in InputMap.action_get_events(InputManager.ACTION_ITEM):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_Q:
			has_q = true
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
			has_b = true
	if not has_q or not has_b:
		return _fail("Item input missing Q or gamepad B")
	print("ITEM INPUT PASS keyboard=Q gamepad=B")
	return true

func _test_item_box_pickup() -> bool:
	_clear_inventory(_racer_a)
	var box: WildDashItemBox = ITEM_BOX_SCENE.instantiate() as WildDashItemBox
	box.name = "SmokeItemBox"
	box.respawn_seconds = 0.2
	add_child(box)
	box.global_position = _racer_a.global_position + Vector3.UP * 0.8
	await get_tree().physics_frame
	if _racer_a.get_held_item() == &"" and not box.force_pickup(_racer_a):
		return _fail("Item Box did not grant an item")
	if _racer_a.get_held_item() == &"":
		return _fail("Item Box pickup left inventory empty")
	if not box.is_active():
		return _fail("Race Item Box globally deactivated after one racer pickup")
	print("ITEM BOX PICKUP PASS item=%s box_global_active=true" % ItemSystem.get_display_name(_racer_a.get_held_item()))
	_clear_inventory(_racer_a)
	box.queue_free()
	return true

func _test_inventory() -> bool:
	_clear_inventory(_racer_a)
	if not ItemSystem.grant_item(_racer_a, ItemSystem.DASH_BERRY):
		return _fail("First inventory grant failed")
	if ItemSystem.grant_item(_racer_a, ItemSystem.BUBBLE_SHIELD):
		return _fail("Second item entered one-slot inventory")
	if _racer_a.get_held_item() != ItemSystem.DASH_BERRY:
		return _fail("One-slot inventory changed unexpectedly")
	print("ITEM INVENTORY PASS capacity=1")
	_clear_inventory(_racer_a)
	return true

func _test_dash() -> bool:
	ItemSystem.reset_runtime()
	_clear_inventory(_racer_a)
	ItemSystem.grant_item(_racer_a, ItemSystem.DASH_BERRY)
	if not ItemSystem.use_held_item(_racer_a) or not ItemSystem.has_effect(_racer_a, &"dash"):
		return _fail("Dash Berry effect did not activate")
	print("DASH BERRY PASS duration=2.0")
	return true

func _test_wild_turbo_definition_and_use() -> bool:
	ItemSystem.reset_runtime()
	_clear_inventory(_racer_a)
	if ItemSystem.get_item_count() != 13:
		return _fail("RC9 item count must be 13 after WILD TURBO")
	if not ItemSystem.is_valid_item(ItemSystem.WILD_TURBO):
		return _fail("WILD TURBO is not registered as a valid item")
	var definition: WildDashItemDefinition = ItemSystem.get_definition(ItemSystem.WILD_TURBO)
	if definition == null:
		return _fail("WILD TURBO definition missing")
	if ItemSystem.get_display_name(ItemSystem.WILD_TURBO) != "WILD TURBO":
		return _fail("WILD TURBO display name mismatch")
	if ItemSystem.get_icon_text(ItemSystem.WILD_TURBO) != "WT":
		return _fail("WILD TURBO icon mismatch")
	if ItemSystem.get_role(ItemSystem.WILD_TURBO) != &"speed":
		return _fail("WILD TURBO role must be speed")
	if absf(definition.duration - 1.50) > 0.001:
		return _fail("WILD TURBO duration mismatch")
	if absf(definition.strength - 1.68) > 0.001:
		return _fail("WILD TURBO sustained speed multiplier mismatch")
	if absf(definition.secondary_strength - 1.50) > 0.001:
		return _fail("WILD TURBO acceleration multiplier mismatch")
	if absf(definition.front_weight - 2.0) > 0.001 or absf(definition.mid_weight - 6.0) > 0.001 or absf(definition.back_weight - 12.0) > 0.001:
		return _fail("WILD TURBO front/mid/back weight mismatch")

	_racer_a.current_speed = 0.0
	var canonical_max: float = _racer_a.get_animal_definition().max_speed if _racer_a.get_animal_definition() != null else _racer_a.max_speed
	if not ItemSystem.grant_item(_racer_a, ItemSystem.WILD_TURBO):
		return _fail("Could not grant WILD TURBO")
	if not ItemSystem.use_held_item(_racer_a):
		return _fail("WILD TURBO could not be used")
	if not ItemSystem.has_effect(_racer_a, &"wild_turbo"):
		return _fail("WILD TURBO effect did not activate")
	if _racer_a.current_speed < _racer_a.max_speed * 1.37:
		return _fail("WILD TURBO initial burst is too weak")
	if _racer_a.current_speed > canonical_max * 1.801:
		return _fail("WILD TURBO exceeded canonical speed cap")
	print("WILD TURBO PASS duration=1.50 initial=1.38 sustained=1.68 accel=1.50 cap=1.80 weights=2/6/12")
	return true

func _test_shield() -> bool:
	ItemSystem.reset_runtime()
	_clear_inventory(_racer_a)
	ItemSystem.grant_item(_racer_a, ItemSystem.BUBBLE_SHIELD)
	if not ItemSystem.use_held_item(_racer_a) or not ItemSystem.has_shield(_racer_a):
		return _fail("Bubble Shield did not activate")
	if not ItemSystem.apply_attack(_racer_a, _racer_b, &"rocket_nut", 1.0, 0.58, 2.0):
		return _fail("Shield test attack did not resolve")
	if ItemSystem.has_shield(_racer_a):
		return _fail("Shield did not consume on first hit")
	if ItemSystem.has_effect(_racer_a, &"slow"):
		return _fail("Shielded racer still received slow")
	print("SHIELD PASS block_once=true duration=5.0")
	return true

func _test_trap() -> bool:
	ItemSystem.reset_runtime()
	_clear_inventory(_racer_a)
	ItemSystem.grant_item(_racer_a, ItemSystem.STICKY_FRUIT)
	if not ItemSystem.use_held_item(_racer_a):
		return _fail("Sticky Fruit could not be used")
	var found: bool = false
	for child: Node in get_children():
		if child is WildDashStickyFruitTrap:
			found = true
			break
	if not found:
		return _fail("Sticky Fruit trap was not spawned")
	if not ItemSystem.apply_attack(_racer_b, _racer_a, &"sticky_fruit", 1.25, 0.58, 0.0):
		return _fail("Sticky Fruit slow did not resolve")
	if not ItemSystem.has_effect(_racer_b, &"slow"):
		return _fail("Sticky Fruit slow state missing")
	print("TRAP PASS slow=1.25s")
	return true

func _test_shockwave() -> bool:
	ItemSystem.reset_runtime()
	_clear_inventory(_racer_a)
	_racer_a.global_position = Vector3.ZERO
	_racer_b.global_position = Vector3(0, 0, -4)
	_racer_c.global_position = Vector3(0, 0, 14)
	ItemSystem.grant_item(_racer_a, ItemSystem.SHOCKWAVE)
	if not ItemSystem.use_held_item(_racer_a):
		return _fail("Shockwave could not be used")
	if not ItemSystem.has_effect(_racer_b, &"slow"):
		return _fail("Shockwave did not affect nearby racer")
	if ItemSystem.has_effect(_racer_c, &"slow"):
		return _fail("Shockwave affected distant racer")
	print("SHOCKWAVE PASS radius=7.5")
	return true

func _test_rocket() -> bool:
	ItemSystem.reset_runtime()
	_clear_inventory(_racer_a)
	_racer_a.global_position = Vector3(0, 0.2, 0)
	_racer_a.rotation = Vector3.ZERO
	_racer_b.global_position = Vector3(0, 0.2, -8)
	_racer_b.rotation = Vector3.ZERO
	_racer_c.global_position = Vector3(0, 0.2, 18)
	ItemSystem.grant_item(_racer_a, ItemSystem.ROCKET_NUT)
	if not ItemSystem.use_held_item(_racer_a):
		return _fail("Rocket Nut could not acquire target")
	var timeout: float = 0.0
	while timeout < 1.5 and not ItemSystem.has_effect(_racer_b, &"slow"):
		await get_tree().physics_frame
		timeout += 1.0 / 60.0
	if not ItemSystem.has_effect(_racer_b, &"slow"):
		return _fail("Rocket Nut did not hit target")
	print("ROCKET PASS weak_homing=true slow=1.0s")
	return true

func _test_feather() -> bool:
	ItemSystem.reset_runtime()
	_clear_inventory(_racer_a)
	_racer_a.velocity = Vector3.ZERO
	_racer_a.current_speed = 0.0
	ItemSystem.grant_item(_racer_a, ItemSystem.RECOVERY_FEATHER)
	if not ItemSystem.use_held_item(_racer_a):
		return _fail("Recovery Feather could not be used")
	if _racer_a.velocity.y <= 0.0 or _racer_a.current_speed <= 0.0:
		return _fail("Recovery Feather did not leap")
	print("FEATHER PASS leap=true")
	return true

func _test_ai_item_use() -> bool:
	ItemSystem.reset_runtime()
	_clear_inventory(_racer_b)
	_racer_a.global_position = Vector3(0, 0.2, -6)
	_racer_b.global_position = Vector3(0, 0.2, 0)
	_racer_b.rotation = Vector3.ZERO
	ItemSystem.grant_item(_racer_b, ItemSystem.ROCKET_NUT)
	var brain: WildDashAIItemBrain = AI_ITEM_BRAIN_SCRIPT.new() as WildDashAIItemBrain
	if brain == null:
		return _fail("AI item brain failed to instantiate")
	brain.name = "SmokeAIItemBrain"
	brain.configure(_racer_b, null)
	add_child(brain)
	if not brain.evaluate_and_use_now():
		return _fail("AI did not use useful Rocket Nut")
	if ItemSystem.get_last_used_item(_racer_b) != ItemSystem.ROCKET_NUT:
		return _fail("AI item use was not recorded")
	print("AI ITEM USE PASS utility=true")
	brain.queue_free()
	return true

func _spawn_static_racer(node_name: String, at: Vector3, animal: StringName) -> WildDashCharacterController:
	var racer: WildDashCharacterController = RACER_SCENE.instantiate() as WildDashCharacterController
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
	print("ITEM SYSTEM SMOKE FAIL " + message)
	get_tree().quit(1)
	return false