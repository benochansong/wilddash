extends Node

const ROUND2_SCENE: PackedScene = preload("res://modes/fruit_collection/fruit_collection.tscn")
const ROUND4_SCENE: PackedScene = preload("res://modes/push_out/push_out.tscn")

func _ready() -> void:
	var failures: Array[String] = []
	var monkey_mobility: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_mobility_attack(&"monkey")
	if monkey_mobility == null or monkey_mobility.ability_id != &"monkey_swing_kick":
		failures.append("Monkey Swing Kick mobility profile missing")
	elif monkey_mobility.fruit_spill != 1:
		failures.append("Monkey Swing Kick must spill exactly one fruit in Round 2")

	var rabbit_aerial: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_aerial_attack(&"rabbit")
	if rabbit_aerial == null or rabbit_aerial.ability_id != &"rabbit_high_stomp":
		failures.append("Rabbit High Stomp profile missing")
	elif rabbit_aerial.base_stagger < 34.0:
		failures.append("Rabbit should remain the phase-2 aerial Stagger specialist")

	var deer_aerial: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_aerial_attack(&"deer")
	if deer_aerial == null or deer_aerial.ability_id != &"deer_hoof_drop":
		failures.append("Deer Hoof Drop profile missing")
	elif deer_aerial.momentum_scaling <= 0.0:
		failures.append("Deer Hoof Drop must scale with momentum")

	var cat_heavy: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_heavy_attack(&"cat")
	if cat_heavy == null or cat_heavy.ability_id != &"cat_pounce":
		failures.append("Cat Pounce profile missing")

	var fox_basic: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_basic_attack(&"fox")
	if fox_basic == null or fox_basic.ability_id != &"fox_dash_hit":
		failures.append("Fox Dash Hit profile missing")

	var route: WildDashCanopyVineRoute = WildDashCanopyVineRoute.new().configure(
		&"smoke_vine", Vector3(0.0, 4.0, 0.0), Vector3(8.0, 4.0, 0.0), 2.0, 10.0, 4.0
	)
	var midpoint: Vector3 = route.sample(0.5)
	if midpoint.y >= 3.0:
		failures.append("Canopy fake swing should sag below the elevated anchors")
	if route.approximate_length() <= 8.0:
		failures.append("Curved canopy route length must exceed straight chord length")
	var canopy: WildDashCanopyTraversalSystem = WildDashCanopyTraversalSystem.new()
	var routes: Array[WildDashCanopyVineRoute] = [route]
	canopy.set_routes(routes)
	if canopy.find_nearest_vine(Vector3(0.0, 4.0, 0.0), 1.0) == null:
		failures.append("Canopy nearest-vine lookup failed")
	if WildDashCombatAbilitySystem.get_monkey_swing_impact_scale(0.0) < 0.74:
		failures.append("Swing impact low-speed clamp changed unexpectedly")
	if WildDashCombatAbilitySystem.get_monkey_swing_impact_scale(1.0) > 1.36:
		failures.append("Swing impact high-speed clamp changed unexpectedly")
	if ROUND2_SCENE == null or ROUND4_SCENE == null:
		failures.append("Round 2 or Round 4 active scene failed to preload")

	if failures.is_empty():
		print("COMBAT V2 CANOPY SMOKE PASS vines=typed monkey_swing=true rabbit_chain_profile=true deer_momentum=true cat_ambush_profile=true fox_hit_run=true")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("COMBAT V2 CANOPY SMOKE FAIL: %s" % failure)
	get_tree().quit(1)
