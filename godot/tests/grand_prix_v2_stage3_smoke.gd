extends SceneTree

func _init() -> void:
	var failures: Array[String] = []
	var bundle: Dictionary = WildDashGrandPrixV2Layout.build_route_bundle()
	var total_length: float = WildDashGrandPrixV2Layout.get_total_length(bundle)
	var elevation: Vector2 = WildDashGrandPrixV2Layout.get_elevation_range(bundle)
	var river_length: float = WildDashGrandPrixV2Layout.get_section_length(bundle, &"long_river")
	var mountain_length: float = WildDashGrandPrixV2Layout.get_section_length(bundle, &"mountain_ascent")
	var summit_length: float = WildDashGrandPrixV2Layout.get_section_length(bundle, &"summit_ridge")
	var rough_length: float = WildDashGrandPrixV2Layout.get_section_length(bundle, &"rough_descent")

	if total_length < 2400.0 or total_length > 2700.0:
		failures.append("Grand Prix V2 total length out of range: %.1fm" % total_length)
	if elevation.y - elevation.x < 50.0:
		failures.append("Adventure elevation range must remain dramatic: %.1fm..%.1fm" % [elevation.x, elevation.y])
	if river_length < 280.0 or mountain_length < 350.0 or summit_length < 150.0 or rough_length < 300.0:
		failures.append("Stage 2 terrain sections regressed")

	var expected_kinds: Array[StringName] = [
		&"small_rock", &"large_boulder", &"fallen_log", &"rotating_log",
		&"moving_gate", &"mud_patch", &"rolling_boulder", &"rock_fall",
	]
	if WildDashGrandPrixV2Stage3Controller.OBSTACLE_KINDS.size() < 8:
		failures.append("Stage 3 must keep at least 8 obstacle families")
	for kind: StringName in expected_kinds:
		if not WildDashGrandPrixV2Stage3Controller.OBSTACLE_KINDS.has(kind):
			failures.append("Missing Stage 3 obstacle family: %s" % String(kind))

	var wild_profile: Dictionary = WildDashGrandPrixV2Stage3Controller.get_difficulty_profile(&"wild")
	var normal_profile: Dictionary = WildDashGrandPrixV2Stage3Controller.get_difficulty_profile(&"chaos")
	var hard_profile: Dictionary = WildDashGrandPrixV2Stage3Controller.get_difficulty_profile(&"nightmare")
	if not (float(wild_profile["hazard_speed"]) < float(normal_profile["hazard_speed"]) and float(normal_profile["hazard_speed"]) < float(hard_profile["hazard_speed"])):
		failures.append("Hazard speed must scale Wild < Chaos < Nightmare")
	if not (float(wild_profile["current_scale"]) < float(normal_profile["current_scale"]) and float(normal_profile["current_scale"]) < float(hard_profile["current_scale"])):
		failures.append("River current must scale Wild < Chaos < Nightmare")
	if bool(wild_profile["extra_hazards"]) or not bool(hard_profile["extra_hazards"]):
		failures.append("Only Nightmare should enable Stage 3 extra hazards")
	if WildDashGrandPrixV2DynamicHazard.MIN_WARNING_SECONDS < 1.0:
		failures.append("Dynamic hazard warning must remain at least one second")
	if WildDashGrandPrixV2DynamicHazard.HIT_PROTECTION_MSEC < 600:
		failures.append("Dynamic hazards need anti-stunlock impact protection")

	var bear_river: Dictionary = WildDashGrandPrixV2AITerrainStrategy.choose_lane_for(&"bear", &"long_river", "Balanced", &"chaos")
	var cat_river: Dictionary = WildDashGrandPrixV2AITerrainStrategy.choose_lane_for(&"cat", &"long_river", "Balanced", &"chaos")
	var elephant_forest: Dictionary = WildDashGrandPrixV2AITerrainStrategy.choose_lane_for(&"elephant", &"forest_obstacle", "Balanced", &"chaos")
	var monkey_mountain: Dictionary = WildDashGrandPrixV2AITerrainStrategy.choose_lane_for(&"monkey", &"mountain_ascent", "Shortcut", &"chaos")
	if String(bear_river["lane_name"]) != "CENTER":
		failures.append("Bear should prefer the direct swim line in River")
	if String(cat_river["lane_name"]) != "LEFT":
		failures.append("Cat should prefer the water-avoidance technical line")
	if String(elephant_forest["lane_name"]) != "CENTER":
		failures.append("Elephant should prefer the Power/Defense forest line")
	if String(monkey_mountain["lane_name"]) != "LEFT":
		failures.append("Monkey Shortcut AI should prefer the Agility/Climb mountain line")

	if not WildDashRaceTerrainProfile.can_break_light_obstacle(&"elephant") or not WildDashRaceTerrainProfile.can_break_light_obstacle(&"bear"):
		failures.append("Heavy Power racers must retain light-obstacle breaking")
	if WildDashRaceTerrainProfile.can_break_light_obstacle(&"rabbit"):
		failures.append("Rabbit should solve obstacles with Agility rather than Power")
	if WildDashRaceCombatBalance.get_defense_rating(&"elephant") <= WildDashRaceCombatBalance.get_defense_rating(&"cat"):
		failures.append("Defense must remain meaningful for obstacle/hazard impact")

	if failures.is_empty():
		print("GRAND PRIX V2 STAGE3 SMOKE PASS total=%.1fm elevation=%.1f..%.1f river=%.1f mountain=%.1f summit=%.1f rough=%.1f kinds=%d bear_river=%s cat_river=%s" % [
			total_length, elevation.x, elevation.y, river_length, mountain_length, summit_length, rough_length,
			WildDashGrandPrixV2Stage3Controller.OBSTACLE_KINDS.size(), String(bear_river["lane_name"]), String(cat_river["lane_name"]),
		])
		quit(0)
		return

	for failure: String in failures:
		push_error("GRAND PRIX V2 STAGE3 SMOKE FAIL: %s" % failure)
	quit(1)
