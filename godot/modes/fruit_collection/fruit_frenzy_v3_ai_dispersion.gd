extends "res://modes/fruit_collection/fruit_frenzy_v2_polish.gd"

## Round 2 V3 AI dispersion layer.
## Prevents the entire roster from selecting the same fruit/carrier/cart point.
## Core Harvest Heist rules and V2 combat polish remain intact.
## V3.1 also makes pickup visibility atomic for composite fruit visuals.

const MAX_GOLDEN_CHASERS := 3
const MAX_CARRIER_CHASERS := 2
const HOME_ZONE_BIAS := 28.0
const BANK_SLOT_RADIUS := 1.65
const REGULAR_RESPAWN_SECONDS := 4.5

var _ai_home_zone_by_id: Dictionary = {}

func _ready() -> void:
	await super()
	for i in range(ai_racers.size()):
		var racer: WildDashCharacterController = ai_racers[i]
		if racer != null:
			_ai_home_zone_by_id[racer.get_instance_id()] = i % 4
	_sync_all_fruit_visuals()
	print("FRUIT FRENZY V3.1 READY zones=4 fruit_reservation=true spill_reservation=true carrier_cap=%d golden_cap=%d bank_slots=true pickup_visibility=atomic respawn=%.1fs" % [
		MAX_CARRIER_CHASERS,
		MAX_GOLDEN_CHASERS,
		REGULAR_RESPAWN_SECONDS,
	])

# -----------------------------------------------------------------------------
# Composite fruit visibility safety
# -----------------------------------------------------------------------------

func _set_visual_tree_visible(root: Node, visible_state: bool) -> void:
	if root == null:
		return
	if root is GeometryInstance3D:
		(root as GeometryInstance3D).visible = visible_state
	for child: Node in root.get_children():
		_set_visual_tree_visible(child, visible_state)

func _sync_all_fruit_visuals() -> void:
	for i in range(fruits.size()):
		if i < fruit_active.size():
			_set_visual_tree_visible(fruits[i], fruit_active[i])
	for i in range(spill_fruits.size()):
		if i < spill_active.size():
			_set_visual_tree_visible(spill_fruits[i], spill_active[i])
	if _golden_fruit != null:
		_set_visual_tree_visible(_golden_fruit, _golden_active)

func _collect_regular_fruit(racer: WildDashCharacterController, index: int) -> void:
	super(racer, index)
	if index < 0 or index >= fruits.size():
		return
	# Keep the collected fruit gone long enough that pickup feedback is obvious.
	fruit_respawn[index] = REGULAR_RESPAWN_SECONDS
	_set_visual_tree_visible(fruits[index], false)

func _update_fruits(delta: float) -> void:
	super(delta)
	for i in range(fruits.size()):
		if i < fruit_active.size():
			_set_visual_tree_visible(fruits[i], fruit_active[i])

func _update_spill_fruits(delta: float) -> void:
	super(delta)
	for i in range(spill_fruits.size()):
		if i < spill_active.size():
			_set_visual_tree_visible(spill_fruits[i], spill_active[i])

func _process_pickups_and_banking() -> void:
	super()
	# Pickup happens in this physics tick; hide every composite child immediately.
	_sync_all_fruit_visuals()

func _spawn_spilled_fruit(position: Vector3, fruit_type: StringName, value: int) -> void:
	super(position, fruit_type, value)
	for i in range(spill_fruits.size()):
		if i < spill_active.size():
			_set_visual_tree_visible(spill_fruits[i], spill_active[i])

func _update_golden_event(delta: float) -> void:
	super(delta)
	if _golden_fruit != null:
		_set_visual_tree_visible(_golden_fruit, _golden_active)

func _update_golden_harvest() -> void:
	super()
	if _golden_fruit != null:
		_set_visual_tree_visible(_golden_fruit, _golden_active)

# -----------------------------------------------------------------------------
# AI dispersion
# -----------------------------------------------------------------------------

func _update_ai_decisions() -> void:
	var fruit_claims: Dictionary = {}
	var spill_claims: Dictionary = {}
	var carrier_claims: Dictionary = {}
	var golden_chasers := 0

	for i in range(ai_racers.size()):
		if i >= ai_drivers.size():
			continue
		var racer: WildDashCharacterController = ai_racers[i]
		var driver: WildDashAIController = ai_drivers[i]
		if racer == null or driver == null:
			continue
		var personality: StringName = ai_personalities[i] if i < ai_personalities.size() else PERSONALITY_BALANCED
		var carry: int = _get_carry(racer)

		# Bankers approach different points around the cart instead of one exact point.
		if carry >= 4 or (personality == PERSONALITY_GATHERER and carry >= 3):
			driver.set_arena_target(_bank_slot_target(i))
			continue

		# Golden Fruit should create a small contest, not drag the whole field into one blob.
		if _golden_active and carry <= 2 and golden_chasers < MAX_GOLDEN_CHASERS:
			var golden_distance: float = racer.global_position.distance_squared_to(_golden_fruit.global_position)
			var eligible := personality == PERSONALITY_OPPORTUNIST or personality == PERSONALITY_BALANCED
			eligible = eligible or (personality == PERSONALITY_THIEF and golden_distance < 11.0 * 11.0)
			if eligible and ((i + _golden_event_index) % 2 == 0 or golden_distance < 8.0 * 8.0):
				driver.set_arena_target(_golden_fruit.global_position)
				golden_chasers += 1
				continue

		# Thieves can still create combat, but at most two AI may chase the same carrier.
		if personality == PERSONALITY_THIEF or personality == PERSONALITY_BALANCED:
			var victim := _best_unclaimed_carrier_target(
				racer,
				14.0 if personality == PERSONALITY_THIEF else 9.5,
				carrier_claims
			)
			if victim != null:
				var victim_id := victim.get_instance_id()
				carrier_claims[victim_id] = int(carrier_claims.get(victim_id, 0)) + 1
				driver.set_arena_target(victim.global_position)
				_try_ai_attack(racer, victim, personality)
				continue

		# Opportunists prefer one reserved spilled fruit each.
		if personality == PERSONALITY_OPPORTUNIST:
			var spill_index := _best_spill_index_for_ai(racer, spill_claims)
			if spill_index >= 0:
				spill_claims[spill_index] = i
				driver.set_arena_target(spill_fruits[spill_index].global_position)
				continue

		# Regular gathering is zone-biased and one fruit is reserved per AI decision pass.
		var fruit_index := _best_regular_fruit_index_for_ai(racer, i, fruit_claims)
		if fruit_index >= 0:
			fruit_claims[fruit_index] = i
			driver.set_arena_target(fruits[fruit_index].global_position)
			continue

		# If the home zone is temporarily empty, look for an unclaimed spill anywhere.
		var fallback_spill := _best_spill_index_for_ai(racer, spill_claims)
		if fallback_spill >= 0:
			spill_claims[fallback_spill] = i
			driver.set_arena_target(spill_fruits[fallback_spill].global_position)
		else:
			driver.set_arena_target(_fallback_zone_target(i))

func _best_regular_fruit_index_for_ai(
	racer: WildDashCharacterController,
	ai_index: int,
	claims: Dictionary,
) -> int:
	var best_index := -1
	var best_score := INF
	var home_zone := int(_ai_home_zone_by_id.get(racer.get_instance_id(), ai_index % 4))
	for fruit_index in range(fruits.size()):
		if claims.has(fruit_index):
			continue
		if not fruit_active[fruit_index] or not _can_carry_value(racer, fruit_values[fruit_index]):
			continue
		var score := racer.global_position.distance_squared_to(fruits[fruit_index].global_position)
		if fruit_index % 4 != home_zone:
			score += HOME_ZONE_BIAS
		# Stable tiny tie-break keeps adjacent AI from repeatedly picking identical paths.
		score += float((fruit_index * 7 + ai_index * 11) % 9) * 0.17
		if score < best_score:
			best_score = score
			best_index = fruit_index
	return best_index

func _best_spill_index_for_ai(racer: WildDashCharacterController, claims: Dictionary) -> int:
	var best_index := -1
	var best_distance := INF
	for spill_index in range(spill_fruits.size()):
		if claims.has(spill_index) or not spill_active[spill_index]:
			continue
		if not _can_carry_value(racer, spill_values[spill_index]):
			continue
		var distance := racer.global_position.distance_squared_to(spill_fruits[spill_index].global_position)
		if distance < best_distance:
			best_distance = distance
			best_index = spill_index
	return best_index

func _best_unclaimed_carrier_target(
	attacker: WildDashCharacterController,
	max_range: float,
	claims: Dictionary,
) -> WildDashCharacterController:
	var best: WildDashCharacterController = null
	var best_score := -INF
	var max_range_sq := max_range * max_range
	for candidate: WildDashCharacterController in racers:
		if candidate == null or candidate == attacker:
			continue
		var candidate_id := candidate.get_instance_id()
		if int(claims.get(candidate_id, 0)) >= MAX_CARRIER_CHASERS:
			continue
		var carry := _get_carry(candidate)
		if carry < 3:
			continue
		var distance_sq := attacker.global_position.distance_squared_to(candidate.global_position)
		if distance_sq > max_range_sq:
			continue
		var score := float(carry) * 10.0 - sqrt(distance_sq)
		# Prefer a target with fewer current pursuers when scores are otherwise close.
		score -= float(int(claims.get(candidate_id, 0))) * 7.5
		if score > best_score:
			best_score = score
			best = candidate
	return best

func _bank_slot_target(ai_index: int) -> Vector3:
	if _cart_root == null:
		return _fallback_zone_target(ai_index)
	var slot_count := maxi(6, mini(12, ai_racers.size()))
	var angle := TAU * float(ai_index % slot_count) / float(slot_count)
	return _cart_root.global_position + Vector3(cos(angle), 0.0, sin(angle)) * BANK_SLOT_RADIUS

func _fallback_zone_target(ai_index: int) -> Vector3:
	var zone := ai_index % 4
	var anchor := _zone_anchor(zone)
	var orbit_angle := TAU * float((ai_index / 4) % 4) / 4.0 + float(zone) * 0.31
	return anchor + Vector3(cos(orbit_angle) * 4.2, 0.0, sin(orbit_angle) * 4.2)
