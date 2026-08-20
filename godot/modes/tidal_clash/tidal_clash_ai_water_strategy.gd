class_name WildDashTidalClashAIStrategy
extends "res://systems/race_combat_ai_director_party_turbo.gd"

## Round 5 adapter for the existing Race Combat AI Director.
## Driving, target reservation, rivalry, anti-gang-up and item authority remain in
## the inherited RC9 director; this layer only adds TIDAL CLASH aggression,
## water-hazard yielding and the wider 8..45m Wild Turbo catch-up window.

const TIDAL_TURBO_MIN_GAP: float = 8.0
const TIDAL_TURBO_MAX_GAP: float = 45.0
const FINAL_TIDAL_SPRINT_PROGRESS: float = 82.0
const HAZARD_PRIORITY_META: StringName = &"tidal_hazard_priority_until_msec"

func _combat_aggression(racer: WildDashCharacterController) -> float:
	return clampf(super._combat_aggression(racer) * 1.12, 0.20, 0.98)

func _hazard_priority_active(racer: WildDashCharacterController) -> bool:
	if racer != null and round_id == &"tidal_clash":
		var until_msec: int = int(racer.get_meta(HAZARD_PRIORITY_META, 0))
		if Time.get_ticks_msec() < until_msec:
			return true
	return super._hazard_priority_active(racer)

func _try_utility_item(
	racer: WildDashCharacterController,
	driver: WildDashAIController,
	age: float,
	rank: int,
	total: int,
	serial: int
) -> bool:
	var item_id: StringName = racer.get_held_item()
	if round_id != &"tidal_clash" or item_id != ItemSystem.WILD_TURBO:
		return super._try_utility_item(racer, driver, age, rank, total, serial)
	if age < _minimum_item_hold():
		return false

	var trailing_half: bool = rank > ceili(float(maxi(1, total)) * 0.5)
	var max_hold_release: bool = age >= ITEM_MAX_HOLD_SECONDS
	var gap: float = ItemSystem.get_nearest_racer_ahead_distance(racer, 52.0)
	var has_gap_target: bool = gap < 100000.0
	var useful_gap: bool = has_gap_target and gap >= TIDAL_TURBO_MIN_GAP and gap <= TIDAL_TURBO_MAX_GAP
	var progress_percent: float = RaceManager.get_progress_percent(racer)
	var final_sprint: bool = progress_percent >= FINAL_TIDAL_SPRINT_PROGRESS
	if not trailing_half and not max_hold_release:
		return false
	if not useful_gap and not max_hold_release and not final_sprint:
		return false

	var route_state: Dictionary = _turbo_route_safety(driver)
	var route_band: String = String(route_state.get("band", "STRAIGHT"))
	var turn_angle: float = float(route_state.get("angle", 0.0))
	if route_band == "SHARP" and not max_hold_release:
		return false

	var chance: float = 0.55
	if route_band == "STRAIGHT":
		chance = 0.84
	elif route_band == "MODERATE":
		chance = 0.56
	else:
		chance = 0.15
	if trailing_half:
		chance += 0.09
	if useful_gap:
		chance += 0.07
	if final_sprint:
		chance += 0.18
	if max_hold_release:
		chance = maxf(chance, 0.80)
	chance = clampf(chance * _item_bias_for(racer), 0.10, 0.97)

	if not _decision_roll(racer, serial, 117, chance):
		return false
	var used: bool = ItemSystem.use_held_item(racer)
	if not used:
		return false
	_record_item_event()
	print("AI ITEM animal=%s item=WILD_TURBO rank=%d gap=%s route=%s turn=%.1f progress=%.1f decision=CATCH_UP final_sprint=%s" % [
		String(racer.animal_id),
		rank,
		"INF" if not has_gap_target else "%.1f" % gap,
		"FINAL_TIDAL_SPRINT" if final_sprint else route_band,
		turn_angle,
		progress_percent,
		str(final_sprint),
	])
	return true
