class_name WildDashRaceCombatAIDirectorPartyTurbo
extends "res://systems/race_combat_ai_director_aggressive.gd"

## Adds WILD TURBO decision-making to the existing aggressive Race Combat AI.
## All attack, defense, target reservation, rivalry and Body Check behavior stays
## in the inherited director; this layer only handles the new catch-up speed item.

const TURBO_MIN_GAP: float = 8.0
const TURBO_MAX_GAP: float = 40.0
const TURBO_ROUTE_LOOKAHEAD_DEGREES_STRAIGHT: float = 24.0
const TURBO_ROUTE_LOOKAHEAD_DEGREES_MODERATE: float = 50.0
const TURBO_OPEN_WATER_PROGRESS_MIN: float = 82.0
const TURBO_NO_TARGET_DISTANCE: float = 100000.0

func _try_utility_item(
	racer: WildDashCharacterController,
	driver: WildDashAIController,
	age: float,
	rank: int,
	total: int,
	serial: int
) -> bool:
	var item_id: StringName = racer.get_held_item()
	if item_id != ItemSystem.WILD_TURBO:
		return super._try_utility_item(racer, driver, age, rank, total, serial)
	if age < _minimum_item_hold():
		return false

	var trailing_half: bool = rank > ceili(float(maxi(1, total)) * 0.5)
	var max_hold_release: bool = age >= ITEM_MAX_HOLD_SECONDS
	var gap: float = ItemSystem.get_nearest_racer_ahead_distance(racer, 48.0)
	var has_gap_target: bool = gap < TURBO_NO_TARGET_DISTANCE
	var useful_gap: bool = has_gap_target and gap >= TURBO_MIN_GAP and gap <= TURBO_MAX_GAP
	var progress_percent: float = RaceManager.get_progress_percent(racer)
	var open_water: bool = (
		round_id == &"neon_harbor_race"
		and racer.has_meta(&"wild_tide_terrain")
		and progress_percent >= TURBO_OPEN_WATER_PROGRESS_MIN
	)
	if not trailing_half and not max_hold_release:
		return false
	if not useful_gap and not max_hold_release and not open_water:
		return false

	var route_state: Dictionary = _turbo_route_safety(driver)
	var turn_angle: float = float(route_state.get("angle", 0.0))
	var route_band: String = String(route_state.get("band", "STRAIGHT"))
	if route_band == "SHARP" and not max_hold_release:
		return false

	var chance: float = 0.52
	if route_band == "STRAIGHT":
		chance = 0.82
	elif route_band == "MODERATE":
		chance = 0.54
	else:
		chance = 0.16
	if trailing_half:
		chance += 0.08
	if useful_gap:
		chance += 0.06
	if open_water:
		chance += 0.12
	if max_hold_release:
		chance = maxf(chance, 0.78)
	chance = clampf(chance * _item_bias_for(racer), 0.10, 0.96)

	if not _decision_roll(racer, serial, 81, chance):
		return false
	var used: bool = ItemSystem.use_held_item(racer)
	if not used:
		return false
	_record_item_event()
	print("AI ITEM animal=%s item=WILD_TURBO rank=%d gap=%s route=%s turn=%.1f progress=%.1f decision=CATCH_UP open_water=%s" % [
		String(racer.animal_id),
		rank,
		"INF" if not has_gap_target else "%.1f" % gap,
		route_band,
		turn_angle,
		progress_percent,
		str(open_water),
	])
	return true

func _turbo_route_safety(driver: WildDashAIController) -> Dictionary:
	if driver == null:
		return {"angle": 0.0, "band": "STRAIGHT"}
	var route_value: Variant = driver.get("_race_route")
	if not (route_value is Array):
		return {"angle": 0.0, "band": "STRAIGHT"}
	var route: Array = route_value
	if route.size() < 3:
		return {"angle": 0.0, "band": "STRAIGHT"}
	var route_index: int = clampi(driver.get_route_index(), 1, route.size() - 2)
	var a_value: Variant = route[route_index - 1]
	var b_value: Variant = route[route_index]
	var c_value: Variant = route[route_index + 1]
	if not (a_value is Vector3) or not (b_value is Vector3) or not (c_value is Vector3):
		return {"angle": 0.0, "band": "STRAIGHT"}
	var a: Vector3 = a_value
	var b: Vector3 = b_value
	var c: Vector3 = c_value
	var incoming: Vector3 = b - a
	var outgoing: Vector3 = c - b
	incoming.y = 0.0
	outgoing.y = 0.0
	if incoming.length_squared() <= 0.001 or outgoing.length_squared() <= 0.001:
		return {"angle": 0.0, "band": "STRAIGHT"}
	incoming = incoming.normalized()
	outgoing = outgoing.normalized()
	var dot_value: float = clampf(incoming.dot(outgoing), -1.0, 1.0)
	var angle: float = rad_to_deg(acos(dot_value))
	var band: String = "SHARP"
	if angle <= TURBO_ROUTE_LOOKAHEAD_DEGREES_STRAIGHT:
		band = "STRAIGHT"
	elif angle <= TURBO_ROUTE_LOOKAHEAD_DEGREES_MODERATE:
		band = "MODERATE"
	return {"angle": angle, "band": band}
