extends "res://items/item_combat_expansion_controller.gd"

## Round 1 Item Chaos V2.
## Keeps the proven item implementations but makes the expanded six actually
## visible in normal play and reduces repetitive role streaks.

const CHAOS_EXPANSION_REPLACE_CHANCE := 0.52

func _ready() -> void:
	super()
	print("ITEM CHAOS V2 base_count=%d expanded_count=%d expanded_chance=%.2f role_anti_repeat=true" % [
		ItemSystem.get_item_count(), CATALOG.get_count(), CHAOS_EXPANSION_REPLACE_CHANCE,
	])

func _on_item_granted(character: Node, item_id: StringName) -> void:
	if character == null or not character is WildDashCharacterController:
		return
	var racer := character as WildDashCharacterController
	if racer.movement_mode != WildDashCharacterController.MovementMode.RACE:
		return
	if racer.get_held_item() != item_id:
		return
	if _rng.randf() > CHAOS_EXPANSION_REPLACE_CHANCE:
		return
	var replacement := _pick_expanded_item(racer)
	if replacement == &"":
		return
	racer.set_held_item(replacement)
	_record_expansion_history(racer, replacement)
	_expanded_ready_at_msec[racer.get_instance_id()] = Time.get_ticks_msec() + _ai_hold_msec()
	print("ITEM CHAOS ROLL racer=%s base=%s replacement=%s chance=%.2f" % [
		RaceManager.get_racer_label(racer), ItemSystem.get_display_name(item_id), CATALOG.get_display_name(replacement), CHAOS_EXPANSION_REPLACE_CHANCE,
	])

func _pick_expanded_item(racer: WildDashCharacterController) -> StringName:
	var rank := RaceManager.get_rank(racer)
	var total := maxi(1, RaceManager.racers.size())
	var back_ratio := float(clampi(rank, 1, total) - 1) / float(maxi(1, total - 1))
	var weights: Dictionary = {
		CATALOG.SNOWBALL: 1.05,
		CATALOG.BEE_SWARM: 0.95 + back_ratio * 0.20,
		CATALOG.TURBO_CHILI: 0.70 + back_ratio * 0.85,
		CATALOG.MUD_SPLASH: 1.10 - back_ratio * 0.25,
		CATALOG.SPRING_TRAP: 0.92,
		CATALOG.SWAP_BOOST: 0.65 + back_ratio * 0.90,
	}
	var history: Array = _expansion_history.get(racer.get_instance_id(), [])
	var recent_roles: Array[StringName] = []
	for recent_item in history:
		if CATALOG.is_expanded(StringName(recent_item)):
			recent_roles.append(CATALOG.get_role(StringName(recent_item)))

	var total_weight := 0.0
	for candidate in CATALOG.ITEM_IDS:
		var weight := float(weights.get(candidate, 1.0))
		if history.has(candidate):
			weight *= 0.24
		var role := CATALOG.get_role(candidate)
		var role_repeats := recent_roles.count(role)
		if role_repeats >= 2:
			weight *= 0.42
		elif role_repeats == 1:
			weight *= 0.76
		weights[candidate] = weight
		total_weight += weight

	if total_weight <= 0.001:
		return CATALOG.ITEM_IDS[0]
	var roll := _rng.randf_range(0.0, total_weight)
	var cursor := 0.0
	for candidate in CATALOG.ITEM_IDS:
		cursor += float(weights[candidate])
		if roll <= cursor:
			return candidate
	return CATALOG.ITEM_IDS[0]
