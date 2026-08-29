extends "res://modes/fruit_collection/fruit_frenzy_v15_active_ai_dispersion.gd"

## Round 2 V16 — campaign-clear balance.
##
## Fruit Frenzy remains a competitive score chase against 14 AI racers, but the
## campaign CLEAR contract is now explicit and player-readable: bank 8 points.
## AI leader score remains a secondary challenge and awards Harvest Champion.

const ROUND2_CLEAR_TARGET: int = 8
const ROUND2_GREAT_TARGET: int = 12
const ROUND2_PERFECT_TARGET: int = 16

func _finish_time_score_round() -> void:
	if mode_finished:
		return
	player_score = _get_banked(player)
	var best_ai: int = 0
	var best_ai_name: String = ""
	for racer: WildDashCharacterController in ai_racers:
		if racer == null:
			continue
		var score: int = _get_banked(racer)
		if score > best_ai:
			best_ai = score
			best_ai_name = racer.name

	var success: bool = player_score >= ROUND2_CLEAR_TARGET
	var performance_grade: StringName = _round2_performance_grade(player_score)
	var harvest_champion: bool = player_score >= best_ai
	print("ROUND2 RESULT banked=%d best_ai=%d target=%d clear=%s grade=%s harvest_champion=%s carry_unbanked=%d" % [
		player_score,
		best_ai,
		ROUND2_CLEAR_TARGET,
		str(success),
		String(performance_grade),
		str(harvest_champion),
		_get_carry(player),
	])
	finish_mode(success, player_score, {
		"target": ROUND2_CLEAR_TARGET,
		"banked_score": player_score,
		"best_ai": best_ai,
		"best_ai_name": best_ai_name,
		"performance_grade": String(performance_grade),
		"harvest_champion": harvest_champion,
		"duration": ROUND_DURATION,
		"carry_unbanked": _get_carry(player),
		"golden_harvest": _golden_harvest_active,
		"mode_variant": "harvest_heist_v16",
	})

func _round2_performance_grade(score: int) -> StringName:
	if score >= ROUND2_PERFECT_TARGET:
		return &"PERFECT"
	if score >= ROUND2_GREAT_TARGET:
		return &"GREAT"
	if score >= ROUND2_CLEAR_TARGET:
		return &"CLEAR"
	return &"MISS"
