extends "res://items/item_combat_expansion_controller.gd"

## Round 3 / Round 5 catch-up item layer. Keeps the shared expanded-item balance,
## adds long-range Acorn Bomb behavior, and protects the canonical WILD TURBO
## comeback roll from being silently replaced after ItemSystem grants it.

func _on_item_granted(character: Node, item_id: StringName) -> void:
	if character == null or not character is WildDashCharacterController:
		return
	var racer: WildDashCharacterController = character as WildDashCharacterController
	if racer.movement_mode != WildDashCharacterController.MovementMode.RACE:
		return
	if racer.get_held_item() != item_id:
		return
	if item_id == ItemSystem.WILD_TURBO:
		print("WILD TURBO PROTECTED racer=%s source=shared_long_bomb no_expansion_replace=true" % RaceManager.get_racer_label(racer))
		return
	if WildDashLongBombItemSupport.maybe_inject_catchup_bomb(racer, item_id, _rng):
		return
	super(character, item_id)

func _try_use_any_item(character: WildDashCharacterController, item_id: StringName) -> bool:
	if item_id == ItemSystem.ACORN_BOMB:
		return WildDashLongBombItemSupport.use_long_bomb(character)
	return super(character, item_id)
