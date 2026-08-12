extends Node

const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")
const ITEM_BOX_SCENE: PackedScene = preload("res://items/item_box.tscn")

var _player: WildDashCharacterController
var _ai: WildDashCharacterController

func _ready() -> void:
	RaceManager.clear_racers()
	RaceManager.clear_track()
	ItemSystem.reset_runtime()
	ItemSystem.set_test_seed(20260812)
	RaceManager.configure_track([Vector3(0, 0, 12), Vector3(0, 0, -40)], [])

	_player = _spawn_racer("PickupPlayer", Vector3(0, 0.2, 8), true)
	_ai = _spawn_racer("PickupAI", Vector3(12, 0.2, 0), false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	RaceManager.start_race()

	if not await _test_high_speed_player_sweep():
		return
	if not await _test_player_refreshes_held_item():
		return
	if not _test_ai_keeps_one_slot_rule():
		return

	print("ITEM BOX RACE PICKUP REGRESSION PASS swept=true replace=true row_cooldown=true ai_one_slot=true")
	get_tree().quit(0)

func _test_high_speed_player_sweep() -> bool:
	_player.set_held_item(&"")
	_player.global_position = Vector3(0, 0.2, 8)
	var box := _spawn_box("SweptPickupBox", Vector3(0, 0.8, 0))
	# Allow the box to remember the player's approach position, then jump the
	# racer across the box farther than the physical collision diameter. The
	# swept XZ corridor must still detect the crossing.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_player.global_position = Vector3(0, 0.2, -8)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _player.get_held_item() == &"":
		return _fail("High-speed player crossing missed the Item Box")
	if box.is_active():
		return _fail("Swept player pickup did not deactivate the Item Box")
	print("ITEM BOX SWEPT PLAYER PASS item=%s" % ItemSystem.get_display_name(_player.get_held_item()))
	box.queue_free()
	return true

func _test_player_refreshes_held_item() -> bool:
	# Keep the replacement box far away so the physics scanner cannot consume
	# it by proximity. force_pickup then isolates the row cooldown/replacement
	# contract from the swept pickup test above.
	var first_box := _spawn_box("ReplacementBox", Vector3(30, 0.8, 30))
	if first_box.force_pickup(_player):
		return _fail("Pickup row cooldown did not block immediate adjacent box")
	for _frame in range(24):
		await get_tree().physics_frame
	if not first_box.force_pickup(_player):
		return _fail("Player with held item could not refresh inventory from Item Box")
	if _player.get_held_item() == &"":
		return _fail("Player replacement pickup left inventory empty")
	if first_box.is_active():
		return _fail("Replacement pickup did not deactivate Item Box")
	print("ITEM BOX PLAYER REPLACE PASS item=%s" % ItemSystem.get_display_name(_player.get_held_item()))
	first_box.queue_free()
	return true

func _test_ai_keeps_one_slot_rule() -> bool:
	_ai.set_held_item(&"")
	if not ItemSystem.grant_item(_ai, ItemSystem.DASH_BERRY):
		return _fail("Could not seed AI held item")
	var box := _spawn_box("AIInventoryBox", Vector3(36, 0.8, 30))
	if box.force_pickup(_ai):
		return _fail("AI replaced an occupied one-slot inventory")
	if _ai.get_held_item() != ItemSystem.DASH_BERRY:
		return _fail("AI held item changed unexpectedly")
	if not box.is_active():
		return _fail("AI rejected pickup consumed the box")
	print("ITEM BOX AI ONE SLOT PASS item=%s" % ItemSystem.get_display_name(_ai.get_held_item()))
	box.queue_free()
	return true

func _spawn_racer(node_name: String, at: Vector3, is_player_character: bool) -> WildDashCharacterController:
	var racer := RACER_SCENE.instantiate() as WildDashCharacterController
	racer.name = node_name
	racer.is_player = is_player_character
	racer.movement_mode = WildDashCharacterController.MovementMode.RACE
	racer.animal_id = &"dog"
	racer.position = at
	add_child(racer)
	return racer

func _spawn_box(node_name: String, at: Vector3) -> WildDashItemBox:
	var box := ITEM_BOX_SCENE.instantiate() as WildDashItemBox
	box.name = node_name
	box.respawn_seconds = 20.0
	add_child(box)
	box.global_position = at
	return box

func _fail(message: String) -> bool:
	push_error("ITEM BOX RACE PICKUP REGRESSION FAIL " + message)
	get_tree().quit(1)
	return false
