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

	if not await _test_high_speed_player_sweep_and_follower_pickup():
		return
	if not await _test_player_refreshes_held_item_and_same_box_lock():
		return
	if not _test_ai_keeps_one_slot_rule():
		return

	print("ITEM BOX RACE PICKUP REGRESSION PASS swept=true party_reuse=true same_box_cooldown=true global_lock=true replace=true ai_one_slot=true box_global_active=true")
	get_tree().quit(0)

func _test_high_speed_player_sweep_and_follower_pickup() -> bool:
	_player.set_held_item(&"")
	_ai.set_held_item(&"")
	_player.global_position = Vector3(0, 0.2, 8)
	_ai.global_position = Vector3(12, 0.2, 0)
	var box: WildDashItemBox = _spawn_box("SweptPickupBox", Vector3(0, 0.8, 0))
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
	if not box.is_active():
		return _fail("Race pickup globally deactivated the party Item Box")

	# The same racer must not immediately consume the same station again, even if
	# its inventory is cleared manually. This also catches body_entered + scan
	# double grants that happen within the same short window.
	_player.set_held_item(&"")
	if box.force_pickup(_player):
		return _fail("Same racer bypassed same-box cooldown")

	# A different following racer must still be able to use this exact box without
	# waiting for the leader's old global 4s respawn.
	if not box.force_pickup(_ai):
		return _fail("Following AI could not collect leader's still-active Item Box")
	if _ai.get_held_item() == &"":
		return _fail("Follower pickup returned true but AI inventory stayed empty")
	if not box.is_active():
		return _fail("Follower pickup globally deactivated party Item Box")
	print("ITEM BOX PARTY FOLLOWER PASS player_item=true ai_item=%s box_global_active=true" % ItemSystem.get_display_name(_ai.get_held_item()))
	box.queue_free()
	return true

func _test_player_refreshes_held_item_and_same_box_lock() -> bool:
	# The prior pickup leaves a short racer-global lock. Keep this replacement box
	# away from the physics scanner and wait just beyond that anti-double-pickup
	# window before exercising human one-slot replacement.
	var first_box: WildDashItemBox = _spawn_box("ReplacementBox", Vector3(30, 0.8, 30))
	if first_box.force_pickup(_player):
		return _fail("Global pickup lock did not block immediate adjacent box")
	for _frame: int in range(28):
		await get_tree().physics_frame
	if not first_box.force_pickup(_player):
		return _fail("Player with held/empty item could not collect replacement Item Box after global lock")
	if _player.get_held_item() == &"":
		return _fail("Player replacement pickup left inventory empty")
	if not first_box.is_active():
		return _fail("Player replacement globally deactivated party Item Box")

	var held_after_refresh: StringName = _player.get_held_item()
	_player.set_held_item(&"")
	if first_box.force_pickup(_player):
		return _fail("Same-box 2.2s cooldown did not block player re-pickup")
	_player.set_held_item(held_after_refresh)
	print("ITEM BOX PLAYER REPLACE PASS item=%s same_box_lock=true box_global_active=true" % ItemSystem.get_display_name(_player.get_held_item()))
	first_box.queue_free()
	return true

func _test_ai_keeps_one_slot_rule() -> bool:
	_ai.set_held_item(&"")
	if not ItemSystem.grant_item(_ai, ItemSystem.DASH_BERRY):
		return _fail("Could not seed AI held item")
	var box: WildDashItemBox = _spawn_box("AIInventoryBox", Vector3(36, 0.8, 30))
	if box.force_pickup(_ai):
		return _fail("AI replaced an occupied one-slot inventory")
	if _ai.get_held_item() != ItemSystem.DASH_BERRY:
		return _fail("AI held item changed unexpectedly")
	if not box.is_active():
		return _fail("AI rejected pickup consumed the box")
	print("ITEM BOX AI ONE SLOT PASS item=%s box_global_active=true" % ItemSystem.get_display_name(_ai.get_held_item()))
	box.queue_free()
	return true

func _spawn_racer(node_name: String, at: Vector3, is_player_character: bool) -> WildDashCharacterController:
	var racer: WildDashCharacterController = RACER_SCENE.instantiate() as WildDashCharacterController
	racer.name = node_name
	racer.is_player = is_player_character
	racer.movement_mode = WildDashCharacterController.MovementMode.RACE
	racer.animal_id = &"dog"
	racer.position = at
	add_child(racer)
	return racer

func _spawn_box(node_name: String, at: Vector3) -> WildDashItemBox:
	var box: WildDashItemBox = ITEM_BOX_SCENE.instantiate() as WildDashItemBox
	box.name = node_name
	box.respawn_seconds = 20.0
	add_child(box)
	box.global_position = at
	return box

func _fail(message: String) -> bool:
	push_error("ITEM BOX RACE PICKUP REGRESSION FAIL " + message)
	get_tree().quit(1)
	return false