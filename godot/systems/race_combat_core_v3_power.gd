class_name WildDashRaceCombatCoreV3Power
extends "res://systems/race_combat_core_v3.gd"

## RC9 Round 1 item-impact polish.
## Physical Shockwave force now belongs to ItemSystem's explicit distance falloff.
## This layer remains the visual reinforcement only, preventing a second hidden
## impulse from flattening the intended center / middle / outer power curve.

func _on_item_used_v3(character: Node, item_id: StringName) -> void:
	if item_id != ItemSystem.SHOCKWAVE or not character is WildDashCharacterController:
		return
	var source: WildDashCharacterController = character as WildDashCharacterController
	_spawn_shockwave_ring(source.global_position)
	print("SHOCKWAVE POWER REINFORCE physics_owner=item_system distance_falloff=true extra_push=0 chain_stun_added=false")
