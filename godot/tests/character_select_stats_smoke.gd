extends SceneTree

const ANIMALS: Array[StringName] = [
	&"dog", &"wolf", &"boar", &"rabbit", &"deer", &"monkey",
	&"elephant", &"bear", &"crocodile", &"cat", &"fox", &"raccoon",
]

func _init() -> void:
	var failures: Array[String] = []
	var panel := WildDashAnimalStatsPanel.new()
	if panel.PANEL_WIDTH < 380.0:
		failures.append("A-layout stats panel is too narrow for six readable stat rows")
	panel.free()

	for animal_id: StringName in ANIMALS:
		if not WildDashAnimalSelectionPresentation.has_complete_profile(animal_id):
			failures.append("missing six-stat lobby profile for %s" % String(animal_id))
			continue
		var profile: Dictionary = WildDashAnimalSelectionPresentation.get_profile(animal_id)
		if profile.size() != 6:
			failures.append("%s must expose Terrain 5 + Defense" % String(animal_id))
		var terrain: Dictionary = WildDashRaceTerrainProfile.get_profile(animal_id)
		for terrain_stat: String in ["swim", "climb", "agility", "power", "rough"]:
			if not is_equal_approx(float(profile[terrain_stat]), float(terrain[terrain_stat])):
				failures.append("%s lobby %s must mirror terrain gameplay data" % [String(animal_id), terrain_stat])
		if not is_equal_approx(float(profile["defense"]), WildDashRaceCombatProfile.get_defense(animal_id)):
			failures.append("%s lobby Defense must mirror Combat V2" % String(animal_id))

	var elephant: Dictionary = WildDashAnimalSelectionPresentation.get_profile(&"elephant")
	var bear: Dictionary = WildDashAnimalSelectionPresentation.get_profile(&"bear")
	var crocodile: Dictionary = WildDashAnimalSelectionPresentation.get_profile(&"crocodile")
	var cat: Dictionary = WildDashAnimalSelectionPresentation.get_profile(&"cat")
	if float(elephant["defense"]) != 10.0:
		failures.append("Elephant lobby Defense must display 10.0")
	if float(bear["defense"]) != 9.0:
		failures.append("Bear lobby Defense must display 9.0")
	if float(crocodile["swim"]) != 10.0 or float(crocodile["power"]) != 8.5:
		failures.append("Crocodile lobby must display Swim 10.0 and Power 8.5")
	if float(cat["defense"]) >= float(bear["defense"]):
		failures.append("lobby must clearly communicate Bear > Cat Defense")

	var elephant_strengths: Array[StringName] = WildDashAnimalSelectionPresentation.get_strengths(&"elephant", 2)
	if not elephant_strengths.has(&"power") or not elephant_strengths.has(&"rough"):
		failures.append("Elephant top lobby tags should expose Power and Rough")
	var cat_weaknesses: Array[StringName] = WildDashAnimalSelectionPresentation.get_weaknesses(&"cat", 2)
	if not cat_weaknesses.has(&"swim") or not cat_weaknesses.has(&"defense"):
		failures.append("Cat lobby weakness tags should expose Swim and Defense")

	if failures.is_empty():
		print("RC9 CHARACTER SELECT STATS PASS animals=12 stats=6 defense=true crocodile=true layout=A")
		quit(0)
		return

	for failure: String in failures:
		push_error("RC9 CHARACTER SELECT STATS FAIL: %s" % failure)
	quit(1)
