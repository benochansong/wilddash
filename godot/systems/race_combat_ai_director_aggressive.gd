class_name WildDashRaceCombatAIDirectorAggressive
extends "res://systems/race_combat_ai_director_safe.gd"

## RC9 emergency party-combat pass.
## Keeps safe projectile caching, target reservation, rivalry and anti-gang-up,
## but makes nearby overtake fights substantially more visible. Player receives
## no targeting bonus and the attacker cap is held at two racers.

const PARTY_BODY_MIN_DISTANCE: float = 0.95
const PARTY_BODY_MAX_DISTANCE: float = 3.60
const PARTY_BODY_MAX_VERTICAL: float = 1.95
const PARTY_COMBAT_MIX_SECONDS: float = 10.0

var _party_mix_elapsed: float = 0.0
var _party_ai_vs_ai_hits: int = 0
var _party_ai_vs_player_hits: int = 0
var _party_player_vs_ai_hits: int = 0
var _party_body_hits: int = 0
var _party_item_hits: int = 0

func _process(delta: float) -> void:
	super._process(delta)
	if not RaceManager.active:
		_party_mix_elapsed = 0.0
		return
	_party_mix_elapsed += delta
	if _party_mix_elapsed < PARTY_COMBAT_MIX_SECONDS:
		return
	print("COMBAT EVENTS / 10s round=%s ai_vs_ai=%d ai_vs_player=%d player_vs_ai=%d body=%d items=%d attacker_cap=2" % [
		String(round_id),
		_party_ai_vs_ai_hits,
		_party_ai_vs_player_hits,
		_party_player_vs_ai_hits,
		_party_body_hits,
		_party_item_hits,
	])
	_party_mix_elapsed = 0.0
	_party_ai_vs_ai_hits = 0
	_party_ai_vs_player_hits = 0
	_party_player_vs_ai_hits = 0
	_party_body_hits = 0
	_party_item_hits = 0

func _evaluate_racer(racer: WildDashCharacterController, now_seconds: float, serial: int) -> void:
	var driver: WildDashAIController = _driver_for(racer)
	if driver == null:
		return
	_update_overtake_rivalry(racer)

	# Safety always wins. Combat becomes aggressive only after route/hazard/stuck
	# checks have yielded a safe passing window.
	if _hazard_priority_active(racer):
		return
	if _try_pack_buster_evade(racer, driver, now_seconds, serial):
		return
	if _try_heavy_evade(racer, driver, now_seconds, serial):
		return
	if _recovery_priority_active(racer, driver):
		_try_recovery_item(racer)
		return

	var target: WildDashCharacterController = _select_combat_target(racer)
	if _try_defensive_item(racer, driver, now_seconds, serial):
		return

	if now_seconds >= _next_global_offense_time:
		# Overtake contact is intentionally checked before ranged offense so the
		# field visibly bumps and trades lanes instead of only firing items.
		if _try_body_check(racer, driver, target, now_seconds, serial):
			_next_global_offense_time = now_seconds + _global_offense_gap()
			return
		if _try_offensive_item(racer, driver, target, now_seconds, serial):
			if target != null:
				_reserve_target(racer, target, TARGET_RESERVATION_SECONDS)
			_next_global_offense_time = now_seconds + _global_offense_gap()
			return

	_try_item_box_lane_nudge(racer, driver, now_seconds)

func _global_offense_gap() -> float:
	match StringName(GameManager.difficulty):
		&"easy": return 1.45
		&"hard": return 1.00
		&"nightmare": return 0.88
		_: return 1.18

func _minimum_item_hold() -> float:
	match StringName(GameManager.difficulty):
		&"easy": return 0.66
		&"hard", &"nightmare": return 0.34
		_: return 0.46

func _combat_aggression(racer: WildDashCharacterController) -> float:
	if racer == null:
		return 0.58
	var base: float = super._combat_aggression(racer)
	var multiplier: float = 1.18
	var bonus: float = 0.07
	if racer.animal_id in [&"wolf", &"boar", &"bear", &"elephant", &"crocodile"]:
		bonus = 0.09
	elif racer.animal_id in [&"raccoon", &"dog", &"monkey"]:
		bonus = 0.08
	elif racer.animal_id in [&"rabbit", &"cat", &"fox", &"deer"]:
		bonus = 0.05
	return clampf(base * multiplier + bonus, 0.26, 0.98)

func _item_bias_for(racer: WildDashCharacterController) -> float:
	if racer == null:
		return 1.0
	var bias: float = super._item_bias_for(racer) * 1.20
	if racer.animal_id == &"raccoon":
		bias *= 1.08
	elif racer.animal_id == &"fox":
		bias *= 1.05
	return clampf(bias, 0.90, 1.55)

func _body_check_cooldown(animal_id: StringName) -> float:
	match animal_id:
		&"rabbit": return 1.18
		&"cat": return 1.20
		&"fox": return 1.24
		&"dog", &"monkey": return 1.34
		&"deer", &"raccoon": return 1.38
		&"wolf": return 1.42
		&"boar": return 1.50
		&"bear", &"crocodile": return 1.58
		&"elephant": return 1.72
		_: return 1.42

func _target_attacker_cap(_attacker: WildDashCharacterController, _target: WildDashCharacterController) -> int:
	# Hard fairness rule for the emergency pass. Rivalry may change target score,
	# but never allows a three-AI dogpile on the same racer/player.
	return 2

func _try_body_check(
	racer: WildDashCharacterController,
	_driver: WildDashAIController,
	target: WildDashCharacterController,
	now_seconds: float,
	serial: int
) -> bool:
	if target == null or WildDashRaceCombatCoreV3.get_recent_hit_protection(target):
		return false
	var racer_id: int = racer.get_instance_id()
	if float(_body_next_by_id.get(racer_id, 0.0)) > now_seconds:
		return false

	var raw_offset: Vector3 = target.global_position - racer.global_position
	if absf(raw_offset.y) > PARTY_BODY_MAX_VERTICAL:
		return false
	var offset: Vector3 = Vector3(raw_offset.x, 0.0, raw_offset.z)
	var distance: float = offset.length()
	if distance < PARTY_BODY_MIN_DISTANCE or distance > PARTY_BODY_MAX_DISTANCE:
		return false
	if not WildDashRaceCombatCoreV3.can_body_check_target(racer, target, PARTY_BODY_MAX_DISTANCE):
		return false

	var forward: Vector3 = -racer.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		return false
	forward = forward.normalized()
	var alignment: float = forward.dot(offset / distance)
	if alignment < -0.18:
		return false
	var driver: WildDashAIController = _driver_for(racer)
	if racer.animal_id == &"elephant" and driver != null and absf(driver.preferred_lane) > 2.75:
		return false

	var aggression: float = _combat_aggression(racer)
	var overtake_bonus: float = 0.0
	if distance <= 3.15 and racer.current_speed >= target.current_speed * 0.94:
		overtake_bonus = 0.22
	var rivalry_bonus: float = 0.08 if _is_rivalry_active(racer, target) else 0.0
	var chance: float = clampf(aggression * 0.70 + overtake_bonus + rivalry_bonus, 0.16, 0.94)
	if racer.animal_id == &"raccoon":
		chance *= 0.86
	if not _decision_roll(racer, serial, 83, chance):
		return false

	var profile: WildDashRaceImpactProfile = WildDashRaceCombatCoreV3.build_body_check_profile(racer, target)
	var applied: bool = WildDashRaceCombatCoreV3.apply_race_impact(
		racer,
		target,
		&"body_check",
		profile,
		racer.global_position
	)
	if not applied:
		return false
	_body_next_by_id[racer_id] = now_seconds + _body_check_cooldown(racer.animal_id)
	_reserve_target(racer, target, TARGET_RESERVATION_SECONDS)
	_record_body_event()
	print("AI BODY CHECK attacker=%s target=%s distance=%.1f rank=%d chance=%.2f impact=%s knockback=%.2f cooldown=%.2f" % [
		String(racer.animal_id),
		RaceManager.get_racer_label(target),
		distance,
		RaceManager.get_rank(racer),
		chance,
		String(profile.impact_label),
		profile.knockback,
		_body_check_cooldown(racer.animal_id),
	])
	return true

func _on_item_hit(target: Node, source: Node, effect_id: StringName, blocked: bool) -> void:
	super._on_item_hit(target, source, effect_id, blocked)
	if blocked:
		return
	var victim: WildDashCharacterController = target as WildDashCharacterController
	var attacker: WildDashCharacterController = source as WildDashCharacterController
	if victim == null or attacker == null or victim == attacker:
		return
	if not RaceManager.racers.has(victim) or not RaceManager.racers.has(attacker):
		return

	var mix: String = "AI_VS_AI"
	if attacker.is_player and not victim.is_player:
		_party_player_vs_ai_hits += 1
		mix = "PLAYER_VS_AI"
	elif not attacker.is_player and victim.is_player:
		_party_ai_vs_player_hits += 1
		mix = "AI_VS_PLAYER"
	else:
		_party_ai_vs_ai_hits += 1

	if effect_id == &"body_check":
		_party_body_hits += 1
	else:
		_party_item_hits += 1

	if not attacker.is_player:
		if effect_id == &"body_check":
			print("AI BODY CHECK HIT attacker=%s target=%s mix=%s" % [
				RaceManager.get_racer_label(attacker), RaceManager.get_racer_label(victim), mix,
			])
		else:
			print("AI ITEM HIT attacker=%s target=%s item=%s mix=%s" % [
				RaceManager.get_racer_label(attacker), RaceManager.get_racer_label(victim), String(effect_id), mix,
			])
