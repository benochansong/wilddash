extends "res://items/item_combat_expansion_v2.gd"

## Round 1 catch-up item layer. The Acorn Bomb now survives Item Chaos replacement
## for trailing racers and can also appear as an extra yellow-box comeback roll.

func _on_item_granted(character: Node, item_id: StringName) -> void:
	if character == null or not character is WildDashCharacterController:
		return
	var racer: WildDashCharacterController = character as WildDashCharacterController
	if racer.movement_mode != WildDashCharacterController.MovementMode.RACE:
		return
	if racer.get_held_item() != item_id:
		return
	if WildDashLongBombItemSupport.maybe_inject_catchup_bomb(racer, item_id, _rng):
		return
	super(character, item_id)

func _try_use_any_item(character: WildDashCharacterController, item_id: StringName) -> bool:
	if item_id == ItemSystem.ACORN_BOMB:
		return WildDashLongBombItemSupport.use_long_bomb(character)
	return super(character, item_id)
