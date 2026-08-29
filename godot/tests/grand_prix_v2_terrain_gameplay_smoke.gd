extends SceneTree

func _init() -> void:
	var failures: Array[String] = []
	var bundle: Dictionary = WildDashGrandPrixV2Layout.build_route_bundle()
	var river_length: float = WildDashGrandPrixV2Layout.get_section_length(bundle, &"long_river")
	var mountain_length: float = WildDashGrandPrixV2Layout.get_section_length(bundle, &"mountain_ascent")
	var summit_length: float = WildDashGrandPrixV2Layout.get_section_length(bundle, &"summit_ridge")
	var rough_length: float = WildDashGrandPrixV2Layout.get_section_length(bundle, &"rough_descent")
	var elevation: Vector2 = WildDashGrandPrixV2Layout.get_elevation_range(bundle)

	if river_length < 280.0 or river_length > 350.0:
		failures.append("long_river must stay within 280-350m, got %.1fm" % river_length)
	if mountain_length < 350.0 or mountain_length > 450.0:
		failures.append("mountain_ascent must stay within 350-450m, got %.1fm" % mountain_length)
	if summit_length < 150.0 or summit_length > 200.0:
		failures.append("summit_ridge must stay within 150-200m, got %.1fm" % summit_length)
	if rough_length < 300.0 or rough_length > 390.0:
		failures.append("rough_descent must stay within 300-390m, got %.1fm" % rough_length)
	if elevation.y < 50.0:
		failures.append("summit must remain visually high, got %.1fm" % elevation.y)

	var bear_swim: float = WildDashRaceTerrainProfile.get_swim_speed_ratio(&"bear")
	var dog_swim: float = WildDashRaceTerrainProfile.get_swim_speed_ratio(&"dog")
	var cat_swim: float = WildDashRaceTerrainProfile.get_swim_speed_ratio(&"cat")
	if not (bear_swim > dog_swim and dog_swim > cat_swim):
		failures.append("river pace must keep Bear > Dog > Cat")
	if WildDashRaceTerrainProfile.get_river_current_susceptibility(&"bear") >= WildDashRaceTerrainProfile.get_river_current_susceptibility(&"cat"):
		failures.append("Bear must resist river current better than Cat")

	var monkey_climb: float = WildDashRaceTerrainProfile.get_climb_speed_ratio(&"monkey")
	var cat_climb: float = WildDashRaceTerrainProfile.get_climb_speed_ratio(&"cat")
	var elephant_climb: float = WildDashRaceTerrainProfile.get_climb_speed_ratio(&"elephant")
	if not (monkey_climb > elephant_climb and cat_climb > elephant_climb):
		failures.append("Monkey/Cat climb advantage over Elephant must remain")

	var elephant_rough: float = WildDashRaceTerrainProfile.get_rough_speed_ratio(&"elephant")
	var bear_rough: float = WildDashRaceTerrainProfile.get_rough_speed_ratio(&"bear")
	var rabbit_rough: float = WildDashRaceTerrainProfile.get_rough_speed_ratio(&"rabbit")
	if not (elephant_rough > rabbit_rough and bear_rough > rabbit_rough):
		failures.append("Elephant/Bear rough advantage over Rabbit must remain")

	if not WildDashRaceTerrainProfile.can_break_light_obstacle(&"elephant"):
		failures.append("Elephant must retain Power obstacle breaking")
	if not WildDashRaceTerrainProfile.can_break_light_obstacle(&"bear"):
		failures.append("Bear must retain Power obstacle breaking")
	if WildDashRaceTerrainProfile.can_break_light_obstacle(&"cat"):
		failures.append("Cat should use Agility rather than Power obstacle breaking")

	if failures.is_empty():
		print("GRAND PRIX V2 TERRAIN SMOKE PASS river=%.1fm mountain=%.1fm summit=%.1fm rough=%.1fm elevation=%.1f..%.1f bear_swim=%.3f cat_swim=%.3f" % [
			river_length, mountain_length, summit_length, rough_length,
			elevation.x, elevation.y, bear_swim, cat_swim,
		])
		quit(0)
		return

	for failure: String in failures:
		push_error("GRAND PRIX V2 TERRAIN SMOKE FAIL: %s" % failure)
	quit(1)
