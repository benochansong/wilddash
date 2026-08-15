extends "res://modes/push_out/wild_rumble_round4_combat_v2_runtime_fix.gd"

## Round 4 campaign-result balance.
## Titan Crown still plays as permanent-elimination last-animal-standing, but the
## campaign CLEAR contract recognizes a Top-3 finish. First place remains the
## unique Titan Champion and receives the strongest campaign score bonus.

const ROUND4_CLEAR_PLACEMENT_MAX: int = 3

func _ring_out(victim: WildDashCharacterController) -> void:
	if victim == null or mode_finished or not _is_combatant_active(victim):
		return
	var victim_id: int = victim.get_instance_id()
	var attacker: WildDashCharacterController = _last_attacker.get(victim_id, null) as WildDashCharacterController
	var credited: bool = attacker != null and is_instance_valid(attacker) and attacker != victim
	credited = credited and float(_last_hit_age.get(victim_id, ATTACK_CREDIT_WINDOW + 1.0)) <= ATTACK_CREDIT_WINDOW
	if credited:
		var attacker_id: int = attacker.get_instance_id()
		_scores[attacker_id] = int(_scores.get(attacker_id, 0)) + RING_OUT_SCORE
		_ko_counts[attacker_id] = int(_ko_counts.get(attacker_id, 0)) + 1

	_drop_relic_for(victim, "RING OUT")
	_drop_crown_for(victim, "RING OUT")
	_round4_eliminated[victim_id] = true
	_last_attacker.erase(victim_id)
	_last_hit_age[victim_id] = ATTACK_CREDIT_WINDOW + 1.0
	_set_combatant_active(victim, false)
	_spawn_impact_ring(victim.global_position, 1.4, Color(1.0, 0.22, 0.06))
	_round4_camera_shake_remaining = maxf(_round4_camera_shake_remaining, 0.18)

	var alive: int = _round4_alive_count()
	var placement: int = clampi(alive + 1, 1, maxi(1, racers.size()))
	if victim == player:
		var finalist: bool = placement <= ROUND4_CLEAR_PLACEMENT_MAX
		var winner_name: String = _round4_survivor_name() if alive == 1 else ""
		if hud != null:
			if finalist:
				hud.set_message("FINALIST · #%d / %d · CAMPAIGN CLEAR" % [placement, racers.size()])
			else:
				hud.set_message("ELIMINATED · #%d / %d" % [placement, racers.size()])
		print("ROUND4 RESULT placement=%d racers=%d finalist=%s titan_champion=false clear=%s alive_at_finish=%d" % [
			placement, racers.size(), str(finalist), str(finalist), alive,
		])
		finish_mode(finalist, _score_for(player), {
			"dominance": _score_for(player),
			"kos": _kos_for(player),
			"placement": placement,
			"racers": racers.size(),
			"alive_at_finish": alive,
			"eliminated": true,
			"winner": winner_name,
			"titan_champion": false,
			"finalist": finalist,
			"titan_crown_finale": true,
			"elimination": true,
		})
		return

	if hud != null:
		if credited and attacker == player:
			hud.set_message("RING OUT! +%d · %d LEFT" % [RING_OUT_SCORE, alive])
		else:
			hud.set_message("%s ELIMINATED · %d LEFT" % [victim.get_display_name().to_upper(), alive])
	print("WILD RUMBLE ELIMINATION victim=%s attacker=%s alive=%d permanent=true" % [
		victim.get_display_name(),
		attacker.get_display_name() if credited else "none",
		alive,
	])
	if alive <= 1:
		_finish_last_survivor()

func _finish_last_survivor() -> void:
	if mode_finished or player == null:
		return
	var player_alive: bool = _is_combatant_active(player)
	var survivor_name: String = _round4_survivor_name()
	var placement: int = 1 if player_alive else clampi(_round4_alive_count() + 1, 1, maxi(1, racers.size()))
	var titan_champion: bool = player_alive and placement == 1
	var finalist: bool = placement <= ROUND4_CLEAR_PLACEMENT_MAX
	if hud != null:
		hud.set_message("TITAN CHAMPION · %s" % survivor_name.to_upper())
	print("ROUND4 RESULT placement=%d racers=%d finalist=%s titan_champion=%s clear=%s winner=%s" % [
		placement, racers.size(), str(finalist), str(titan_champion), str(finalist), survivor_name,
	])
	finish_mode(finalist, _score_for(player) + (15 if titan_champion else 0), {
		"dominance": _score_for(player),
		"kos": _kos_for(player),
		"placement": placement,
		"racers": racers.size(),
		"alive_at_finish": _round4_alive_count(),
		"eliminated": not player_alive,
		"winner": survivor_name,
		"titan_champion": titan_champion,
		"finalist": finalist,
		"titan_crown_finale": true,
		"elimination": true,
	})

func _round4_survivor_name() -> String:
	for racer: WildDashCharacterController in racers:
		if racer != null and _is_combatant_active(racer):
			return racer.get_display_name()
	return "NONE"
