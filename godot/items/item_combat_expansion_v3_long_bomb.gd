extends "res://items/item_combat_expansion_v2.gd"

## Round 1 catch-up item layer. The Acorn Bomb survives Item Chaos replacement
## for trailing racers and can appear as an extra comeback roll. RC9 emergency
## combat pass also strengthens Bee Swarm without changing the shared expanded
## item controller used by other modes.

const BEE_SWARM_EMERGENCY_DURATION: float = 1.35
const BEE_SWARM_EMERGENCY_SLOW: float = 0.78
const BEE_SWARM_EMERGENCY_KNOCKBACK: float = 1.05

func _on_item_granted(character: Node, item_id: StringName) -> void:
	if character == null or not character is WildDashCharacterController:
		return
	var racer: WildDashCharacterController = character as WildDashCharacterController
	if racer.movement_mode != WildDashCharacterController.MovementMode.RACE:
		return
	if racer.get_held_item() != item_id:
		return
	# WILD TURBO is already the rare top-tier comeback roll. Item Chaos must not
	# silently replace it with another expanded item after grant.
	if item_id == ItemSystem.WILD_TURBO:
		return
	if WildDashLongBombItemSupport.maybe_inject_catchup_bomb(racer, item_id, _rng):
		return
	super(character, item_id)

func _try_use_any_item(character: WildDashCharacterController, item_id: StringName) -> bool:
	if item_id == ItemSystem.ACORN_BOMB:
		return WildDashLongBombItemSupport.use_long_bomb(character)
	return super(character, item_id)

func _use_bee_swarm(character: WildDashCharacterController) -> bool:
	var target: WildDashCharacterController = ItemSystem.find_target_ahead(character, 58.0) as WildDashCharacterController
	if target == null:
		target = _nearest_rival(character, 32.0)
	if target == null:
		return false
	if not ItemSystem.apply_attack(
		target,
		character,
		&"bee_swarm",
		BEE_SWARM_EMERGENCY_DURATION,
		BEE_SWARM_EMERGENCY_SLOW,
		BEE_SWARM_EMERGENCY_KNOCKBACK
	):
		return false
	var world: Node = character.get_parent()
	if world != null:
		var effect: WildDashBeeSwarmEffect = BEE_EFFECT_SCRIPT.new() as WildDashBeeSwarmEffect
		effect.name = "BeeSwarm_%d" % Time.get_ticks_msec()
		effect.configure(target)
		world.add_child(effect)
	print("BEE SWARM POWER target=%s duration=%.2f slow=%.2f knockback=%.2f" % [
		RaceManager.get_racer_label(target),
		BEE_SWARM_EMERGENCY_DURATION,
		BEE_SWARM_EMERGENCY_SLOW,
		BEE_SWARM_EMERGENCY_KNOCKBACK,
	])
	return true
