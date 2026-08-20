class_name WildDashRaceCombatAIDirectorSafe
extends "res://systems/race_combat_ai_director.gd"

## RC9 runtime-safety hotfix for the shared race combat AI director.
##
## The base director originally cached the live WildDashAcornBomb Node itself in
## _bomb_warning_seen. Once a short-lived bomb queued itself for deletion, the
## maintenance pass later read that stale Object and cast it back to Node while
## checking is_instance_valid(). That can produce a freed-instance runtime fault.
## This layer keeps the same combat behavior but stores only the bomb instance ID
## and never dereferences a cached projectile after it has been freed.

const BOMB_WARNING_CACHE_LIMIT: int = 192

func _try_pack_buster_evade(
	racer: WildDashCharacterController,
	driver: WildDashAIController,
	now_seconds: float,
	serial: int
) -> bool:
	if racer == null or driver == null or not is_instance_valid(racer) or not is_instance_valid(driver):
		return false
	var racer_id: int = racer.get_instance_id()
	var next_value: Variant = _defense_next_by_id.get(racer_id, 0.0)
	if float(next_value) > now_seconds:
		return false
	var parent_node: Node = get_parent()
	if parent_node == null:
		return false
	for child: Node in parent_node.get_children():
		if child == null or not is_instance_valid(child) or not (child is WildDashAcornBomb):
			continue
		var bomb: WildDashAcornBomb = child as WildDashAcornBomb
		if bomb == null or not is_instance_valid(bomb) or bomb.is_queued_for_deletion():
			continue
		if bomb.owner_racer == racer:
			continue
		var bomb_id: int = bomb.get_instance_id()
		var key: String = "%d:%d" % [racer_id, bomb_id]
		if _bomb_warning_seen.has(key):
			continue
		var planar: Vector3 = bomb.global_position - racer.global_position
		planar.y = 0.0
		var distance: float = planar.length()
		# Ballistic V3 is short-lived. Near-apex/descending projectiles with a close
		# planar footprint are treated as the landing telegraph.
		if distance > 10.0 or bomb.velocity.y > 4.0:
			continue
		# IMPORTANT: cache only a scalar ID, never a live/freed projectile Object.
		_bomb_warning_seen[key] = bomb_id
		var chance: float = _bomb_evade_chance()
		if not _decision_roll(racer, serial, 89, chance):
			return false
		var right: Vector3 = racer.global_transform.basis.x
		right.y = 0.0
		if right.length_squared() <= 0.001:
			right = Vector3.RIGHT
		else:
			right = right.normalized()
		var side_amount: float = planar.dot(right)
		var evade_sign: float = -1.0 if side_amount >= 0.0 else 1.0
		if absf(side_amount) < 0.20:
			evade_sign = -1.0 if racer_id % 2 == 0 else 1.0
		driver.preferred_lane = clampf(driver.preferred_lane + evade_sign * 1.55, -3.6, 3.6)
		if racer.animal_id in [&"rabbit", &"cat", &"deer", &"monkey"] and racer.is_on_floor():
			racer.velocity.y = maxf(racer.velocity.y, racer.jump_velocity * 0.82)
		_defense_next_by_id[racer_id] = now_seconds + DEFENSE_COOLDOWN_SECONDS
		_record_defense_event()
		print("AI DEFENSE animal=%s action=BOMB_EVADE chance=%.2f distance=%.1f safe_cache=true" % [
			String(racer.animal_id), chance, distance,
		])
		return true
	return false

func _cleanup_bomb_warning_cache() -> void:
	# Keys include both racer instance ID and bomb instance ID, so entries are
	# naturally unique per projectile. Keep the cache bounded without ever reading
	# or casting a projectile Object that may already have been freed.
	if _bomb_warning_seen.size() > BOMB_WARNING_CACHE_LIMIT:
		_bomb_warning_seen.clear()
		print("AI COMBAT BOMB CACHE RESET safe_scalar_cache=true")

func _driver_for(racer: WildDashCharacterController) -> WildDashAIController:
	if racer == null or not is_instance_valid(racer):
		return null
	var value: Variant = _drivers_by_id.get(racer.get_instance_id())
	if value == null or not is_instance_valid(value):
		return null
	return value as WildDashAIController
