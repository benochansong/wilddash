class_name WildDashRaceCombatCoreV3Power
extends "res://systems/race_combat_core_v3.gd"

## RC9 item-impact polish. The shared V3 hit/protection logic remains authoritative;
## this layer only gives Shockwave a slightly stronger pack-separation impulse.

const POWER_SHOCKWAVE_RADIUS: float = 9.2
const POWER_SHOCKWAVE_INNER_EXTRA_PUSH: float = 1.20
const POWER_SHOCKWAVE_OUTER_PUSH: float = 1.85

func _on_item_used_v3(character: Node, item_id: StringName) -> void:
	if item_id != ItemSystem.SHOCKWAVE or not character is WildDashCharacterController:
		return
	var source: WildDashCharacterController = character as WildDashCharacterController
	for racer: WildDashCharacterController in WildDashRaceCombatCoreV3.get_nearby_racers(source, POWER_SHOCKWAVE_RADIUS):
		var distance: float = source.global_position.distance_to(racer.global_position)
		var direction: Vector3 = racer.global_position - source.global_position
		direction.y = 0.0
		if direction.length_squared() <= 0.001:
			continue
		var extra_push: float = POWER_SHOCKWAVE_INNER_EXTRA_PUSH if distance <= 7.5 else POWER_SHOCKWAVE_OUTER_PUSH
		racer.apply_knockback(direction.normalized(), extra_push)
		racer.current_speed *= 0.93 if distance <= 7.5 else 0.89
	_spawn_shockwave_ring(source.global_position)
	print("SHOCKWAVE POWER REINFORCE radius=%.1f inner_extra=%.2f outer_push=%.2f chain_stun_added=false" % [
		POWER_SHOCKWAVE_RADIUS, POWER_SHOCKWAVE_INNER_EXTRA_PUSH, POWER_SHOCKWAVE_OUTER_PUSH,
	])
