extends SceneTree

func _init() -> void:
	var failures: Array[String] = []
	var animals: Array[StringName] = [
		&"dog", &"wolf", &"boar", &"rabbit", &"deer", &"monkey",
		&"elephant", &"bear", &"panda", &"cat", &"fox", &"raccoon",
	]
	for animal_id: StringName in animals:
		if not WildDashRaceTerrainProfile.has_complete_profile(animal_id):
			failures.append("missing terrain profile for %s" % String(animal_id))

	var bear_swim: float = WildDashRaceTerrainProfile.get_swim_speed_ratio(&"bear")
	var dog_swim: float = WildDashRaceTerrainProfile.get_swim_speed_ratio(&"dog")
	var cat_swim: float = WildDashRaceTerrainProfile.get_swim_speed_ratio(&"cat")
	if not (bear_swim > dog_swim and dog_swim > cat_swim):
		failures.append("swim pace must keep Bear > Dog > Cat")
	if bear_swim < 1.0:
		failures.append("Bear must gain a real race advantage in the river")
	if cat_swim > 0.82:
		failures.append("Cat should have a meaningful water weakness")

	if not WildDashRaceTerrainProfile.can_break_light_obstacle(&"elephant"):
		failures.append("Elephant must qualify for future light-obstacle breaking")
	if not WildDashRaceTerrainProfile.can_break_light_obstacle(&"bear"):
		failures.append("Bear must qualify for future light-obstacle breaking")
	if WildDashRaceTerrainProfile.can_break_light_obstacle(&"rabbit"):
		failures.append("Rabbit must not qualify for power-based obstacle breaking")

	var zone: WildDashTerrainZone = WildDashTerrainZone.new()
	zone.configure_route_box(
		&"test_water",
		&"water",
		Vector3(0, 0, 0),
		Vector3(0, 0, -20),
		4.0,
		6.0,
		0.10,
		0.90
	)
	if not zone.contains_global_point(Vector3(0, 0, -10)):
		failures.append("terrain zone must include its route centre")
	if zone.contains_global_point(Vector3(4, 0, -10)):
		failures.append("terrain zone must reject points outside its width")
	zone.free()

	if failures.is_empty():
		print("RC9 TERRAIN ADVENTURE PASS bear_swim=%.3f dog_swim=%.3f cat_swim=%.3f" % [
			bear_swim, dog_swim, cat_swim,
		])
		quit(0)
		return

	for failure: String in failures:
		push_error("RC9 TERRAIN ADVENTURE FAIL: %s" % failure)
	quit(1)
