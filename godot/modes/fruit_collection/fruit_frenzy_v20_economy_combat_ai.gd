extends "res://modes/fruit_collection/fruit_frenzy_v19_species_interaction.gd"

## Round 2 V20 — Fruit spill, hit protection and combat AI pass.
##
## This remains a thin Fruit Collection-only adapter. The existing carry,
## loose-fruit pool, Golden Fruit, moving Harvest Cart bank, score, finish,
## V17 Fart Dizzy and V19 species combat remain authoritative.
##
## Philosophy:
## ATTACK -> BOUNDED SPILL / STEAL -> SCRAMBLE -> FAST RECOVERY -> BANK RACE.

const R2_HIT_PROTECTION_SECONDS: float = 0.84
const R2_HIT_SECOND_SCALE: float = 0.56
const R2_HIT_THIRD_SCALE: float = 0.30
const R2_HIT_FURTHER_SCALE: float = 0.12
const R2_BANK_REPEAT_KNOCKBACK_SCALE: float = 0.68
const R2_BANK_PROTECTION_RADIUS_BONUS: float = 1.35

const R2_SPILL_SECOND_SCALE: float = 0.50
const R2_SPILL_THIRD_SCALE: float = 0.0
const R2_SPILL_MAX_PER_HIT: int = 2
const R2_SPILL_RATIO_TARGET: float = 0.30

const R2_AI_MIN_UTILITY: float = 0.50
const R2_AI_HUNTER_MIN_UTILITY: float = 0.43
const R2_AI_DECISION_LOG_COOLDOWN: float = 1.10

const R2_TIER_LIGHT: StringName = &"LIGHT"
const R2_TIER_NORMAL: StringName = &"NORMAL"
const R2_TIER_HEAVY: StringName = &"HEAVY"
const R2_TIER_CONTROL: StringName = &"CONTROL"

var _r2_hit_last_time_by_id: Dictionary = {}
var _r2_hit_count_by_id: Dictionary = {}
var _r2_spill_last_time_by_id: Dictionary = {}
var _r2_spill_count_by_id: Dictionary = {}
var _r2_recovery_until_by_id: Dictionary = {}
var _r2_recovery_tag_by_id: Dictionary = {}
var _r2_ai_last_log_time_by_id: Dictionary = {}

func _ready() -> void:
	await super()
	for racer: WildDashCharacterController in racers:
		_r2_v20_register_state(racer)
	print("ROUND2 V20 ECONOMY COMBAT AI READY hit_window=%.2fs hit_scale=100/56/30/12 spill_chain=100/50/0 spill_cap_ratio=30%% spill_cap_max=%d bank_repeat_scale=%.2f" % [
		R2_HIT_PROTECTION_SECONDS,
		R2_SPILL_MAX_PER_HIT,
		R2_BANK_REPEAT_KNOCKBACK_SCALE,
	])

func _register_racer_state(racer: WildDashCharacterController) -> void:
	super(racer)
	_r2_v20_register_state(racer)

func _r2_v20_register_state(racer: WildDashCharacterController) -> void:
	if racer == null:
		return
	var id: int = racer.get_instance_id()
	_r2_hit_last_time_by_id[id] = -1000.0
	_r2_hit_count_by_id[id] = 0
	_r2_spill_last_time_by_id[id] = -1000.0
	_r2_spill_count_by_id[id] = 0
	_r2_ai_last_log_time_by_id[id] = -1000.0

func _physics_process(delta: float) -> void:
	super(delta)
	if not _r2_species_active():
		return
	_r2_emit_completed_recoveries()

# -----------------------------------------------------------------------------
# Shared hit-chain protection.
# First hit is full strength. Repeat hits inside 0.84 s retain interaction but
# lose most additional displacement. Near the moving bank, only repeat hits are
# softened further; the first hit remains a real risk.
# -----------------------------------------------------------------------------

func _r2_begin_protected_hit(
	attacker: WildDashCharacterController,
	target: WildDashCharacterController,
	attack_tag: StringName
) -> Dictionary:
	if target == null:
		return {"count": 0, "scale": 0.0, "bank": false}
	var id: int = target.get_instance_id()
	var now: float = Time.get_ticks_msec() * 0.001
	var last: float = float(_r2_hit_last_time_by_id.get(id, -1000.0))
	var count: int = 1
	if now - last <= R2_HIT_PROTECTION_SECONDS:
		count = int(_r2_hit_count_by_id.get(id, 0)) + 1
	_r2_hit_last_time_by_id[id] = now
	_r2_hit_count_by_id[id] = count

	var scale: float = 1.0
	if count == 2:
		scale = R2_HIT_SECOND_SCALE
	elif count == 3:
		scale = R2_HIT_THIRD_SCALE
	elif count >= 4:
		scale = R2_HIT_FURTHER_SCALE

	var bank_attack: bool = _r2_is_near_bank(target)
	if bank_attack and count >= 2:
		scale *= R2_BANK_REPEAT_KNOCKBACK_SCALE

	if count >= 2:
		print("ROUND2 COMBAT TELEMETRY hit_chain_protection=1 target=%s hit_index=%d knockback_scale=%.2f window=%.2f" % [
			target.name, count, scale, R2_HIT_PROTECTION_SECONDS,
		])
	if bank_attack:
		print("ROUND2 COMBAT TELEMETRY bank_attack=1 attacker=%s target=%s attack=%s repeat=%d scale=%.2f" % [
			attacker.name if attacker != null else "unknown", target.name, String(attack_tag), count, scale,
		])
	return {"count": count, "scale": scale, "bank": bank_attack}

func _r2_current_hit_count(target: WildDashCharacterController) -> int:
	if target == null:
		return 0
	var id: int = target.get_instance_id()
	var now: float = Time.get_ticks_msec() * 0.001
	var last: float = float(_r2_hit_last_time_by_id.get(id, -1000.0))
	if now - last > R2_HIT_PROTECTION_SECONDS:
		return 0
	return int(_r2_hit_count_by_id.get(id, 0))

func _r2_is_near_bank(racer: WildDashCharacterController) -> bool:
	if racer == null or _cart_root == null:
		return false
	var racer_planar: Vector2 = Vector2(racer.global_position.x, racer.global_position.z)
	var cart_planar: Vector2 = Vector2(_cart_root.global_position.x, _cart_root.global_position.z)
	var radius: float = BANK_RADIUS + R2_BANK_PROTECTION_RADIUS_BONUS
	return racer_planar.distance_squared_to(cart_planar) <= radius * radius

# -----------------------------------------------------------------------------
# Central Fruit Frenzy spill authority guard.
# This does not create a second inventory. It bounds the amount before delegating
# to the existing _spill_racer implementation that owns carry subtraction and
# loose-fruit spawning.
# -----------------------------------------------------------------------------

func _spill_racer(racer: WildDashCharacterController, amount: int, reason: String) -> void:
	if racer == null or not _r2_species_active():
		super(racer, amount, reason)
		return
	var carry: int = _get_carry(racer)
	if carry <= 0 or amount <= 0:
		return

	var id: int = racer.get_instance_id()
	var now: float = Time.get_ticks_msec() * 0.001
	var last: float = float(_r2_spill_last_time_by_id.get(id, -1000.0))
	var chain_index: int = 1
	if now - last <= R2_HIT_PROTECTION_SECONDS:
		chain_index = int(_r2_spill_count_by_id.get(id, 0)) + 1
	_r2_spill_last_time_by_id[id] = now
	_r2_spill_count_by_id[id] = chain_index

	# MAX_CARRY is 5. A rounded 30% cap maps carry 2/3/4/5 to 1/1/1/2,
	# and carry 1 to zero so a normal hit never wipes the final fruit.
	var ratio_cap: int = maxi(1, int(round(float(carry) * R2_SPILL_RATIO_TARGET)))
	var loss_cap: int = mini(R2_SPILL_MAX_PER_HIT, mini(maxi(0, carry - 1), ratio_cap))
	var bounded: int = mini(amount, loss_cap)
	if chain_index == 2:
		bounded = int(floor(float(bounded) * R2_SPILL_SECOND_SCALE))
	elif chain_index >= 3:
		bounded = int(floor(float(bounded) * R2_SPILL_THIRD_SCALE))

	if bounded <= 0:
		print("ROUND2 COMBAT TELEMETRY fruit_spill_protected=1 racer=%s requested=%d carry=%d chain=%d spill=0 reason=%s" % [
			racer.name, amount, carry, chain_index, reason,
		])
		return

	if bounded < amount:
		print("ROUND2 COMBAT TELEMETRY fruit_spill_protected=1 racer=%s requested=%d bounded=%d carry=%d chain=%d reason=%s" % [
			racer.name, amount, bounded, carry, chain_index, reason,
		])
	super(racer, bounded, reason)
	print("ROUND2 COMBAT TELEMETRY fruit_spill=%d racer=%s carry_before=%d carry_after=%d chain=%d reason=%s" % [
		bounded, racer.name, carry, _get_carry(racer), chain_index, reason,
	])

func _combat_v2_try_spill(target: WildDashCharacterController, requested: int, reason: String) -> int:
	if target == null or requested <= 0 or _get_carry(target) <= 0:
		return 0
	var id: int = target.get_instance_id()
	if float(spill_hit_cooldown_by_id.get(id, 0.0)) > 0.0:
		print("ROUND2 COMBAT TELEMETRY fruit_spill_protected=1 racer=%s requested=%d reason=existing_spill_cooldown" % [target.name, requested])
		return 0
	var before: int = _get_carry(target)
	_spill_racer(target, requested, reason)
	var spilled: int = maxi(0, before - _get_carry(target))
	if spilled > 0:
		spill_hit_cooldown_by_id[id] = COMBAT_SPILL_COOLDOWN
	return spilled

# -----------------------------------------------------------------------------
# Attack tiers and recovery targets.
# -----------------------------------------------------------------------------

func _r2_attack_tier(animal_id: StringName, signature: StringName = &"") -> StringName:
	if animal_id in [&"rabbit", &"fox", &"cat", &"raccoon"]:
		return R2_TIER_LIGHT
	if animal_id in [&"elephant", &"bear", &"boar", &"monkey"]:
		return R2_TIER_HEAVY
	if animal_id == &"crocodile":
		return R2_TIER_CONTROL
	if signature == &"ground_slam":
		return R2_TIER_HEAVY
	return R2_TIER_NORMAL

func _r2_recovery_for(animal_id: StringName, signature: StringName = &"") -> float:
	if signature in [&"running_stomp", &"ground_slam"]:
		return 0.70
	match _r2_attack_tier(animal_id, signature):
		R2_TIER_LIGHT:
			return 0.34
		R2_TIER_HEAVY:
			return 0.68
		R2_TIER_CONTROL:
			return 0.48
		_:
			return 0.50

func _r2_spill_request(animal_id: StringName, strong: bool = false) -> int:
	var tier: StringName = _r2_attack_tier(animal_id)
	if strong and animal_id in [&"deer", &"boar", &"monkey"]:
		return 2
	if tier == R2_TIER_HEAVY:
		return 2
	return 1

func _r2_finish_v20_attack(source: WildDashCharacterController, attack_tag: StringName, recovery: float) -> void:
	if source == null:
		return
	var bounded: float = clampf(recovery, 0.25, 0.80)
	_r2_finish_signature_attack(source, bounded)
	var id: int = source.get_instance_id()
	_r2_recovery_until_by_id[id] = Time.get_ticks_msec() * 0.001 + bounded
	_r2_recovery_tag_by_id[id] = attack_tag

func _r2_emit_completed_recoveries() -> void:
	if _r2_recovery_until_by_id.is_empty():
		return
	var now: float = Time.get_ticks_msec() * 0.001
	for id_value: Variant in _r2_recovery_until_by_id.keys():
		if now < float(_r2_recovery_until_by_id.get(id_value, 0.0)):
			continue
		var tag: StringName = StringName(_r2_recovery_tag_by_id.get(id_value, &"attack"))
		print("ROUND2 COMBAT TELEMETRY recovery_complete=1 racer_id=%s attack=%s" % [str(id_value), String(tag)])
		_r2_recovery_until_by_id.erase(id_value)
		_r2_recovery_tag_by_id.erase(id_value)

func _r2_hit_feedback_seconds(animal_id: StringName, signature: StringName = &"") -> float:
	if signature in [&"running_stomp", &"ground_slam"]:
		return 0.38
	match _r2_attack_tier(animal_id, signature):
		R2_TIER_LIGHT:
			return 0.26
		R2_TIER_HEAVY:
			return 0.38
		R2_TIER_CONTROL:
			return 0.30
		_:
			return 0.32

# -----------------------------------------------------------------------------
# Direct/basic/heavy species profiles. Both player and AI resolve through this
# same function. It replaces the V10 direct knockback path only in Round 2 V20.
# -----------------------------------------------------------------------------

func _perform_round2_profile_attack(_spec: WildDashCombatAbilitySpec, heavy: bool) -> void:
	if player != null:
		_phase3_round2_profile_attack(player, heavy)

func _phase3_round2_profile_attack(source: WildDashCharacterController, heavy: bool) -> bool:
	if source == null or not _r2_species_active():
		return false
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_heavy_attack(source.animal_id) if heavy else WildDashCombatAbilitySystem.get_basic_attack(source.animal_id)
	if spec == null:
		return false
	var target: WildDashCharacterController = _combat_v2_front_target(source, spec.range, spec.arc_dot)
	var momentum_ratio: float = clampf(Vector2(source.velocity.x, source.velocity.z).length() / maxf(1.0, source.arena_move_speed), 0.0, 1.0)
	var momentum_multiplier: float = WildDashCombatAbilitySystem.get_momentum_effect_multiplier(spec, momentum_ratio)
	var context: Dictionary = {
		"in_water": _is_river_position(source.global_position),
		"momentum_multiplier": momentum_multiplier,
	}
	var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(source, target, spec, &"fruit_collection", context)
	if not result.applied:
		return false

	var forward: Vector3 = -source.global_transform.basis.z
	forward.y = 0.0
	forward = Vector3.FORWARD if forward.length_squared() <= 0.001 else forward.normalized()
	if result.mobility_impulse > 0.01:
		source.apply_knockback(forward, result.mobility_impulse)

	var attack_tag: StringName = _r2_attack_tag_for(source.animal_id, heavy)
	var recovery: float = _r2_recovery_for(source.animal_id)
	if target == null:
		_r2_finish_v20_attack(source, attack_tag, 0.58 if source.animal_id == &"boar" and heavy else recovery)
		if source == player and hud != null:
			hud.set_message("%s · NO TARGET" % spec.display_name)
		return false

	var offset: Vector3 = target.global_position - source.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return false

	var behind: bool = WildDashCombatV2AIBrain.is_behind_target(source, target)
	if source.animal_id == &"wolf" and heavy and behind:
		result.knockback *= 1.22
		result.stagger *= 1.24
	var is_cat_ambush: bool = source.animal_id == &"cat" and _combat_v2_is_back_attack(source, target)
	if is_cat_ambush:
		result.knockback *= 1.18
		result.stagger *= 1.24

	var protection: Dictionary = _r2_begin_protected_hit(source, target, attack_tag)
	var hit_scale: float = float(protection.get("scale", 1.0))
	target.apply_knockback(offset.normalized(), result.knockback * hit_scale)

	var stole: bool = false
	if source.animal_id == &"raccoon":
		stole = _phase3_try_quick_steal(source, target)
	var spilled: int = 0
	if not stole:
		var strong: bool = source.animal_id == &"boar" and heavy
		spilled = _combat_v2_try_spill(target, _r2_spill_request(source.animal_id, strong), String(spec.display_name))

	_r2_short_hit_feedback(target, _r2_hit_feedback_seconds(source.animal_id) * maxf(0.55, hit_scale))
	_apply_power_stun(source, target)
	_r2_finish_v20_attack(source, attack_tag, recovery)

	if source == player:
		if source.animal_id == &"cat" and is_cat_ambush:
			_set_round2_speed_bonus(CAT_AMBUSH_SPEED_SCALE, CAT_AMBUSH_SPEED_SECONDS)
		elif source.animal_id == &"fox":
			_set_round2_speed_bonus(FOX_ESCAPE_SPEED_SCALE, FOX_ESCAPE_SPEED_SECONDS)
	AudioManager.play_sfx_id("hit", 1.0 if _r2_attack_tier(source.animal_id) == R2_TIER_HEAVY else 0.88)
	WildDashCombatV2FX.spawn_impact(self, target.global_position + Vector3.UP * 0.60, _phase3_fx_kind(source.animal_id, heavy), 1.05)

	if source == player and hud != null:
		if stole:
			hud.set_message("FRUIT SWIPE! · STEAL +1")
		elif spilled > 0:
			hud.set_message("%s! · FRUIT SPILL +%d" % [spec.display_name, spilled])
		else:
			hud.set_message("%s! · HIT PROTECTED" % spec.display_name)
	_r2_log_attack_hit(source, target, attack_tag, hit_scale, spilled, stole)
	return true

func _r2_attack_tag_for(animal_id: StringName, heavy: bool) -> StringName:
	match animal_id:
		&"wolf": return &"wolf_pounce"
		&"cat": return &"cat_pounce"
		&"boar": return &"boar_charge" if heavy else &"boar_push"
		&"elephant": return &"elephant_push"
		&"bear": return &"bear_shove"
		&"fox": return &"fox_dash_bump"
		&"rabbit": return &"rabbit_hop_kick"
		&"raccoon": return &"raccoon_swipe"
		&"deer": return &"deer_bump"
		&"monkey": return &"monkey_bump"
		&"crocodile": return &"crocodile_bite"
		_: return &"dog_shoulder_bump"

# -----------------------------------------------------------------------------
# Deer / Monkey signatures.
# -----------------------------------------------------------------------------

func _r2_apply_deer_stomp(source: WildDashCharacterController, target: WildDashCharacterController) -> bool:
	if source == null or target == null or not _r2_species_active():
		return false
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_aerial_attack(&"deer")
	if spec == null:
		return false
	var height: float = source.global_position.y - target.global_position.y
	var horizontal_speed: float = Vector2(source.velocity.x, source.velocity.z).length()
	var aerial_scale: float = WildDashAerialCombatSystem.get_effect_scale(source, source.velocity.y, height, horizontal_speed)
	var context: Dictionary = {"airborne": true, "in_water": _is_river_position(source.global_position), "momentum_multiplier": aerial_scale}
	var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(source, target, spec, &"fruit_collection", context)
	if not result.applied:
		return false
	var offset: Vector3 = target.global_position - source.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		offset = -source.global_transform.basis.z
	var protection: Dictionary = _r2_begin_protected_hit(source, target, &"deer_running_stomp")
	var hit_scale: float = float(protection.get("scale", 1.0))
	target.apply_knockback(offset.normalized(), result.knockback * hit_scale)
	var strong: bool = aerial_scale >= 1.10
	var spilled: int = _combat_v2_try_spill(target, _r2_spill_request(&"deer", strong), "DEER RUNNING STOMP")
	_r2_short_hit_feedback(target, _r2_hit_feedback_seconds(&"deer", &"running_stomp") * maxf(0.55, hit_scale))
	source.velocity.y = maxf(source.velocity.y, source.jump_velocity * WildDashAerialCombatSystem.get_bounce_scale(&"deer"))
	_r2_finish_v20_attack(source, &"deer_running_stomp", _r2_recovery_for(&"deer", &"running_stomp"))
	WildDashCombatV2FX.spawn_impact(self, target.global_position + Vector3.UP * 0.45, &"stomp", 1.0)
	AudioManager.play_sfx_id("hit", 0.94)
	if source == player and hud != null:
		hud.set_message("RUNNING STOMP! · SPILL +%d" % spilled)
	_r2_log_attack_hit(source, target, &"deer_running_stomp", hit_scale, spilled, false)
	return true

func _r2_apply_monkey_ground_slam(source: WildDashCharacterController) -> bool:
	if source == null or not _r2_species_active():
		return false
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_aerial_attack(&"monkey")
	if spec == null:
		return false
	var candidates: Array[Dictionary] = []
	for target: WildDashCharacterController in racers:
		if target == null or target == source or target.finished:
			continue
		var height: float = source.global_position.y - target.global_position.y
		if height < 0.48 or height > 3.45:
			continue
		var planar: Vector3 = target.global_position - source.global_position
		planar.y = 0.0
		var distance: float = planar.length()
		if distance <= R2_MONKEY_SLAM_RADIUS:
			candidates.append({"target": target, "distance": distance, "height": height})
	if candidates.is_empty():
		return false
	candidates.sort_custom(Callable(self, "_r2_sort_target_distance"))

	var hit_count: int = 0
	var spill_budget: int = 2
	for entry: Dictionary in candidates:
		if hit_count >= R2_MONKEY_SLAM_MAX_TARGETS:
			break
		var target: WildDashCharacterController = entry.get("target") as WildDashCharacterController
		if target == null:
			continue
		var distance: float = float(entry.get("distance", R2_MONKEY_SLAM_RADIUS))
		var height: float = float(entry.get("height", 0.8))
		var horizontal_speed: float = Vector2(source.velocity.x, source.velocity.z).length()
		var aerial_scale: float = WildDashAerialCombatSystem.get_effect_scale(source, source.velocity.y, height, horizontal_speed)
		var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(source, target, spec, &"fruit_collection", {"airborne": true, "in_water": false, "momentum_multiplier": aerial_scale})
		if not result.applied:
			continue
		var center: bool = distance <= R2_MONKEY_SLAM_CENTER_RADIUS
		var area_scale: float = 1.0 if center else R2_MONKEY_SLAM_OUTER_SCALE
		var protection: Dictionary = _r2_begin_protected_hit(source, target, &"monkey_ground_slam")
		var hit_scale: float = float(protection.get("scale", 1.0))
		var offset: Vector3 = target.global_position - source.global_position
		offset.y = 0.0
		if offset.length_squared() <= 0.001:
			offset = -source.global_transform.basis.z
		target.apply_knockback(offset.normalized(), result.knockback * area_scale * hit_scale)
		_r2_short_hit_feedback(target, _r2_hit_feedback_seconds(&"monkey", &"ground_slam") * maxf(0.55, hit_scale))
		var spilled: int = 0
		if center and spill_budget > 0:
			spilled = _combat_v2_try_spill(target, mini(2, spill_budget), "MONKEY GROUND SLAM")
			spill_budget -= spilled
		_r2_log_attack_hit(source, target, &"monkey_ground_slam", hit_scale, spilled, false)
		hit_count += 1
	if hit_count <= 0:
		return false
	source.velocity.y = maxf(source.velocity.y, source.jump_velocity * WildDashAerialCombatSystem.get_bounce_scale(&"monkey"))
	_r2_finish_v20_attack(source, &"monkey_ground_slam", _r2_recovery_for(&"monkey", &"ground_slam"))
	WildDashCombatV2FX.spawn_impact(self, source.global_position + Vector3.UP * 0.20, &"stomp", 1.20)
	AudioManager.play_sfx_id("hit", 0.96)
	return true

# -----------------------------------------------------------------------------
# Bear wide shove / Crocodile tail control.
# -----------------------------------------------------------------------------

func _r2_bear_wide_shove(source: WildDashCharacterController) -> bool:
	if source == null or not _r2_species_active():
		return false
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_heavy_attack(&"bear")
	if spec == null:
		return false
	var candidates: Array[Dictionary] = _r2_collect_arc_targets(source, spec.range, spec.arc_dot)
	if candidates.is_empty():
		_r2_finish_v20_attack(source, &"bear_wide_shove", _r2_recovery_for(&"bear"))
		return false
	var hits: int = 0
	var spill_budget: int = 2
	for entry: Dictionary in candidates:
		if hits >= R2_BEAR_WIDE_MAX_TARGETS:
			break
		var target: WildDashCharacterController = entry.get("target") as WildDashCharacterController
		if target == null:
			continue
		var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(source, target, spec, &"fruit_collection", {"in_water": _is_river_position(source.global_position)})
		if not result.applied:
			continue
		var offset: Vector3 = target.global_position - source.global_position
		offset.y = 0.0
		if offset.length_squared() <= 0.001:
			continue
		var protection: Dictionary = _r2_begin_protected_hit(source, target, &"bear_wide_shove")
		var hit_scale: float = float(protection.get("scale", 1.0))
		target.apply_knockback(offset.normalized(), result.knockback * R2_BEAR_WIDE_KNOCKBACK_SCALE * hit_scale)
		_r2_short_hit_feedback(target, _r2_hit_feedback_seconds(&"bear") * maxf(0.55, hit_scale))
		var spilled: int = 0
		if spill_budget > 0:
			spilled = _combat_v2_try_spill(target, mini(2, spill_budget), "BEAR WIDE SHOVE")
			spill_budget -= spilled
		_r2_log_attack_hit(source, target, &"bear_wide_shove", hit_scale, spilled, false)
		hits += 1
	_r2_finish_v20_attack(source, &"bear_wide_shove", _r2_recovery_for(&"bear"))
	if hits > 0:
		AudioManager.play_sfx_id("hit", 0.96)
	return hits > 0

func _r2_crocodile_tail_sweep(source: WildDashCharacterController) -> bool:
	if source == null or not _r2_species_active():
		return false
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_heavy_attack(&"crocodile")
	if spec == null:
		return false
	var forward: Vector3 = -source.global_transform.basis.z
	forward.y = 0.0
	forward = Vector3.FORWARD if forward.length_squared() <= 0.001 else forward.normalized()
	var hits: int = 0
	var spill_budget: int = 1
	for target: WildDashCharacterController in racers:
		if target == null or target == source or target.finished:
			continue
		var offset: Vector3 = target.global_position - source.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= 0.05 or distance > spec.range:
			continue
		if forward.dot(offset.normalized()) < R2_CROCODILE_TAIL_ARC_DOT:
			continue
		var directional_multiplier: float = WildDashCombatAbilitySystem.get_tail_direction_multiplier(source, target)
		var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(source, target, spec, &"fruit_collection", {"in_water": _is_river_position(source.global_position), "directional_multiplier": directional_multiplier})
		if not result.applied:
			continue
		var protection: Dictionary = _r2_begin_protected_hit(source, target, &"crocodile_tail_sweep")
		var hit_scale: float = float(protection.get("scale", 1.0))
		target.apply_knockback(offset.normalized(), result.knockback * hit_scale)
		_r2_short_hit_feedback(target, _r2_hit_feedback_seconds(&"crocodile") * maxf(0.55, hit_scale))
		var spilled: int = 0
		if spill_budget > 0:
			spilled = _combat_v2_try_spill(target, 1, "CROCODILE TAIL SWEEP V20")
			spill_budget -= spilled
		_r2_log_attack_hit(source, target, &"crocodile_tail_sweep", hit_scale, spilled, false)
		hits += 1
	_r2_finish_v20_attack(source, &"crocodile_tail_sweep", _r2_recovery_for(&"crocodile"))
	if hits > 0:
		AudioManager.play_sfx_id("hit", 0.88)
	return hits > 0

# -----------------------------------------------------------------------------
# Raccoon steal remains the existing carry authority, but cannot take the last
# fruit and cannot chain-steal a recently hit target.
# -----------------------------------------------------------------------------

func _phase3_try_quick_steal(source: WildDashCharacterController, target: WildDashCharacterController) -> bool:
	if source == null or target == null or not _r2_species_active():
		return false
	var source_id: int = source.get_instance_id()
	var target_id: int = target.get_instance_id()
	var now: float = Time.get_ticks_msec() * 0.001
	if float(_phase3_steal_cooldown_by_id.get(source_id, 0.0)) > 0.0:
		return false
	if float(_r2_raccoon_target_protected_until.get(target_id, 0.0)) > now:
		return false
	if _r2_current_hit_count(target) > 1:
		print("ROUND2 COMBAT TELEMETRY fruit_spill_protected=1 fruit_steal=0 target=%s reason=hit_chain" % target.name)
		return false
	if _get_carry(target) <= 1 or _get_carry(source) >= MAX_CARRY:
		return false
	var steal_amount: int = mini(R2_RACCOON_STEAL_AMOUNT, mini(_get_carry(target) - 1, MAX_CARRY - _get_carry(source)))
	if steal_amount <= 0:
		return false
	carried_by_id[target_id] = _get_carry(target) - steal_amount
	_add_carry(source, steal_amount)
	_phase3_steal_cooldown_by_id[source_id] = RACCOON_STEAL_COOLDOWN
	_r2_raccoon_target_protected_until[target_id] = now + R2_RACCOON_TARGET_PROTECTION_SECONDS
	if target == player:
		_show_event("FRUIT STOLEN! -%d" % steal_amount, 0.9)
	print("ROUND2 COMBAT TELEMETRY fruit_steal=%d attacker=%s target=%s target_protection=%.2f" % [
		steal_amount, source.name, target.name, R2_RACCOON_TARGET_PROTECTION_SECONDS,
	])
	return true

# -----------------------------------------------------------------------------
# AI combat utility. V12/V15 keep collection-first intent and sector dispersion;
# this override only decides whether a local combat candidate is actually worth
# giving up the nearby fruit route for.
# -----------------------------------------------------------------------------

func _v12_local_combat_target(
	source: WildDashCharacterController,
	max_range: float,
	claims: Dictionary
) -> WildDashCharacterController:
	if source == null or float(ai_attack_cooldown_by_id.get(source.get_instance_id(), 0.0)) > 0.0:
		return null
	var hunter: bool = source.animal_id in [&"wolf", &"raccoon"]
	var effective_range: float = minf(max_range, V15_HUNTER_COMBAT_RANGE if hunter else V15_NORMAL_COMBAT_RANGE)
	var best: WildDashCharacterController = null
	var best_utility: float = -INF
	var threshold: float = R2_AI_HUNTER_MIN_UTILITY if hunter else R2_AI_MIN_UTILITY
	for target: WildDashCharacterController in racers:
		if target == null or target == source or target.finished:
			continue
		var carry: int = _get_carry(target)
		if carry <= 0:
			continue
		var target_id: int = target.get_instance_id()
		var allowed_chasers: int = 2 if carry >= 5 else 1
		if int(claims.get(target_id, 0)) >= allowed_chasers:
			continue
		var distance: float = source.global_position.distance_to(target.global_position)
		if distance > effective_range:
			continue
		var utility: float = _r2_ai_attack_utility(source, target, effective_range)
		if utility >= threshold and utility > best_utility:
			best_utility = utility
			best = target
	return best

func _try_ai_attack(attacker: WildDashCharacterController, target: WildDashCharacterController, personality: StringName) -> void:
	if attacker == null or target == null or not _r2_species_active():
		return
	var hunter: bool = attacker.animal_id in [&"wolf", &"raccoon"] or personality == PERSONALITY_THIEF
	var range: float = V15_HUNTER_COMBAT_RANGE if hunter else V15_NORMAL_COMBAT_RANGE
	var utility: float = _r2_ai_attack_utility(attacker, target, range)
	var threshold: float = R2_AI_HUNTER_MIN_UTILITY if hunter else R2_AI_MIN_UTILITY
	if utility < threshold:
		return
	var id: int = attacker.get_instance_id()
	var before: float = float(ai_attack_cooldown_by_id.get(id, 0.0))
	super(attacker, target, personality)
	var after: float = float(ai_attack_cooldown_by_id.get(id, 0.0))
	if after > before + 0.01:
		_r2_log_ai_attack_decision(attacker, target, utility, threshold)

func _r2_ai_attack_utility(source: WildDashCharacterController, target: WildDashCharacterController, max_range: float) -> float:
	if source == null or target == null or max_range <= 0.01:
		return -INF
	var target_carry: int = _get_carry(target)
	var own_carry: int = _get_carry(source)
	var distance: float = source.global_position.distance_to(target.global_position)
	var distance_score: float = clampf(1.0 - distance / max_range, 0.0, 1.0)
	var utility: float = float(target_carry) / float(MAX_CARRY) * 0.32
	utility += distance_score * 0.20

	var bank_distance: float = INF
	if _cart_root != null:
		bank_distance = target.global_position.distance_to(_cart_root.global_position)
	if bank_distance <= BANK_RADIUS + 4.5:
		utility += 0.15
	if own_carry >= 3:
		utility -= 0.11 * float(own_carry - 2)

	var score_gap: float = float(_get_banked(target) - _get_banked(source))
	utility += clampf(score_gap / 18.0, -0.06, 0.10)
	if time_remaining <= 20.0 and target_carry >= 3:
		utility += 0.08
	if time_remaining <= 8.0 and bank_distance <= BANK_RADIUS + 5.5:
		utility += 0.06

	if _golden_active and target.global_position.distance_to(_golden_fruit.global_position) <= 4.8:
		utility += 0.12

	var forward: Vector3 = -source.global_transform.basis.z
	forward.y = 0.0
	forward = Vector3.FORWARD if forward.length_squared() <= 0.001 else forward.normalized()
	var toward: Vector3 = target.global_position - source.global_position
	toward.y = 0.0
	var alignment: float = 0.0 if toward.length_squared() <= 0.001 else forward.dot(toward.normalized())
	if alignment >= 0.55:
		utility += 0.08
	elif alignment < -0.10:
		utility -= 0.11

	var collectible: Vector3 = _nearest_collectible_position(source)
	if collectible != Vector3.INF and own_carry <= 2:
		var fruit_distance: float = source.global_position.distance_to(collectible)
		if fruit_distance + 1.5 < distance:
			utility -= 0.14

	utility += _r2_ai_species_style_modifier(source, target, distance)
	return utility

func _r2_ai_species_style_modifier(source: WildDashCharacterController, target: WildDashCharacterController, distance: float) -> float:
	match source.animal_id:
		&"deer", &"monkey":
			var vertical: float = source.global_position.y - target.global_position.y
			return 0.16 if (not source.is_on_floor() or vertical >= 0.35) else -0.08
		&"elephant", &"bear":
			return 0.05 * float(mini(3, _r2_enemy_count_near(source.global_position, source, 4.2)))
		&"boar":
			return 0.10 if _r2_clear_charge_lane(source, target) else -0.08
		&"crocodile":
			return 0.06 * float(mini(3, _r2_enemy_count_near(source.global_position, source, 4.4)))
		&"wolf", &"cat":
			return 0.10 if _r2_enemy_count_near(target.global_position, target, 3.5) <= 1 else -0.03
		&"fox":
			return 0.04 + float(_get_carry(target)) * 0.018
		&"rabbit":
			return 0.04 if distance <= 2.8 else -0.03
		&"raccoon":
			return float(_get_carry(target)) * 0.035
		_:
			return 0.02

func _r2_enemy_count_near(position: Vector3, exclude: WildDashCharacterController, radius: float) -> int:
	var count: int = 0
	var radius_sq: float = radius * radius
	for racer: WildDashCharacterController in racers:
		if racer == null or racer == exclude or racer.finished:
			continue
		if racer.global_position.distance_squared_to(position) <= radius_sq:
			count += 1
	return count

func _r2_clear_charge_lane(source: WildDashCharacterController, target: WildDashCharacterController) -> bool:
	if source == null or target == null:
		return false
	var forward: Vector3 = -source.global_transform.basis.z
	forward.y = 0.0
	forward = Vector3.FORWARD if forward.length_squared() <= 0.001 else forward.normalized()
	var offset: Vector3 = target.global_position - source.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return false
	return forward.dot(offset.normalized()) >= 0.62

func _r2_log_ai_attack_decision(source: WildDashCharacterController, target: WildDashCharacterController, utility: float, threshold: float) -> void:
	var id: int = source.get_instance_id()
	var now: float = Time.get_ticks_msec() * 0.001
	if now - float(_r2_ai_last_log_time_by_id.get(id, -1000.0)) < R2_AI_DECISION_LOG_COOLDOWN:
		return
	_r2_ai_last_log_time_by_id[id] = now
	print("ROUND2 COMBAT TELEMETRY AI_attack_decision=execute species=%s target=%s utility=%.2f threshold=%.2f target_fruit=%d own_fruit=%d bank_near=%s time=%.1f" % [
		String(source.animal_id), target.name, utility, threshold, _get_carry(target), _get_carry(source), str(_r2_is_near_bank(target)), time_remaining,
	])

# -----------------------------------------------------------------------------
# Aerial legacy path for Cat/Fox/Rabbit AI also participates in chain protection.
# -----------------------------------------------------------------------------

func _r2_apply_legacy_ai_aerial(source: WildDashCharacterController, target: WildDashCharacterController) -> bool:
	if source == null or target == null:
		return false
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_aerial_attack(source.animal_id)
	if spec == null:
		return false
	var height: float = source.global_position.y - target.global_position.y
	var horizontal_speed: float = Vector2(source.velocity.x, source.velocity.z).length()
	var aerial_scale: float = WildDashAerialCombatSystem.get_effect_scale(source, source.velocity.y, height, horizontal_speed)
	var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(source, target, spec, &"fruit_collection", {"airborne": true, "in_water": _is_river_position(source.global_position), "momentum_multiplier": aerial_scale})
	if not result.applied:
		return false
	var offset: Vector3 = target.global_position - source.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		offset = Vector3.FORWARD
	var attack_tag: StringName = StringName("%s_aerial" % String(source.animal_id))
	var protection: Dictionary = _r2_begin_protected_hit(source, target, attack_tag)
	var hit_scale: float = float(protection.get("scale", 1.0))
	target.apply_knockback(offset.normalized(), result.knockback * hit_scale)
	var spilled: int = _combat_v2_try_spill(target, 1, "AI %s" % spec.display_name)
	_r2_short_hit_feedback(target, _r2_hit_feedback_seconds(source.animal_id) * maxf(0.55, hit_scale))
	source.velocity.y = maxf(source.velocity.y, source.jump_velocity * WildDashAerialCombatSystem.get_bounce_scale(source.animal_id))
	_r2_finish_v20_attack(source, attack_tag, _r2_recovery_for(source.animal_id))
	_r2_log_attack_hit(source, target, attack_tag, hit_scale, spilled, false)
	return true

# -----------------------------------------------------------------------------
# Hit telemetry. One line per resolved hit; no per-frame logging.
# -----------------------------------------------------------------------------

func _r2_log_attack_hit(
	source: WildDashCharacterController,
	target: WildDashCharacterController,
	attack_tag: StringName,
	hit_scale: float,
	spilled: int,
	stole: bool
) -> void:
	if source == null or target == null:
		return
	var specific: String = ""
	if attack_tag in [&"deer_running_stomp", &"monkey_ground_slam"]:
		specific = " stomp_hit=1"
	elif attack_tag in [&"elephant_push", &"bear_wide_shove", &"bear_shove", &"boar_charge", &"boar_push"]:
		specific = " push_hit=1"
	elif attack_tag in [&"wolf_pounce", &"cat_pounce"]:
		specific = " pounce_hit=1"
	elif attack_tag == &"crocodile_tail_sweep":
		specific = " tail_sweep_hit=1"
	print("ROUND2 COMBAT TELEMETRY round2_attack=1 species_attack=%s attack_hit=1 species=%s target=%s hit_scale=%.2f fruit_spill=%d fruit_steal=%d%s" % [
		String(attack_tag), String(source.animal_id), target.name, hit_scale, spilled, 1 if stole else 0, specific,
	])
