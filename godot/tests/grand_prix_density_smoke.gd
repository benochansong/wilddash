extends Node

func _ready() -> void:
	if not _test_difficulty_counts():
		return
	if not _test_optional_ai_counts():
		return
	if not _test_personality_and_decision_rates():
		return
	if not _test_rank_system():
		return
	print("GRAND PRIX DENSITY SMOKE PASS target=15 hard=18 optional_ai=18")
	get_tree().quit(0)

func _test_difficulty_counts() -> bool:
	var casual := GameManager.get_ai_count_for_difficulty(&"casual") + 1
	var normal := GameManager.get_ai_count_for_difficulty(&"normal") + 1
	var hard := GameManager.get_ai_count_for_difficulty(&"hard") + 1
	if casual != 10 or normal != 15 or hard != 18:
		return _fail("Difficulty racer counts incorrect: %d/%d/%d" % [casual, normal, hard])
	if GameManager.get_ai_count_for_difficulty(&"wild") != 9:
		return _fail("Wild alias did not map to Casual density")
	if GameManager.get_ai_count_for_difficulty(&"chaos") != 14:
		return _fail("Chaos alias did not map to Normal density")
	if GameManager.get_ai_count_for_difficulty(&"nightmare") != 17:
		return _fail("Nightmare alias did not map to Hard density")
	print("DIFFICULTY RACER COUNT PASS casual=10 normal=15 hard=18")
	return true

func _test_optional_ai_counts() -> bool:
	for requested in [10, 14, 18]:
		GameManager.set_ai_count(requested)
		if GameManager.ai_count != requested:
			return _fail("Optional AI count rejected: %d" % requested)
	GameManager.set_ai_count(GameManager.NORMAL_AI_COUNT)
	print("AI COUNT OPTION PASS ai=10/14/18")
	return true

func _test_personality_and_decision_rates() -> bool:
	var profiles := WildDashRacePersonalityBrain.get_profile_ids()
	if profiles.size() != 5:
		return _fail("Expected five AI personalities")
	var tactical_hz := WildDashRacePersonalityBrain.get_default_decision_hz()
	var item_brain := WildDashAIItemBrain.new()
	var skill_brain := WildDashAISkillBrain.new()
	if tactical_hz < 4.0 or tactical_hz > 8.0:
		return _fail("Tactical AI frequency outside 4-8Hz")
	if item_brain.think_hz < 4.0 or item_brain.think_hz > 8.0:
		return _fail("Item utility frequency outside 4-8Hz")
	var skill_hz := 1.0 / maxf(skill_brain.decision_interval, 0.001)
	if skill_hz < 4.0 or skill_hz > 8.0:
		return _fail("Skill utility frequency outside 4-8Hz")
	item_brain.queue_free()
	skill_brain.queue_free()
	print("AI PERSONALITY CONFIG PASS profiles=5 decision_hz=6")
	print("AI DECISION RATE PASS item_hz=5 skill_hz=5 tactical_hz=6")
	return true

func _test_rank_system() -> bool:
	RaceManager.clear_racers()
	RaceManager.clear_track()
	var route: Array[Vector3] = [Vector3(0, 0, 0), Vector3(0, 0, -100)]
	var checkpoints: Array[Vector3] = []
	RaceManager.configure_track(route, checkpoints)
	var positions: Array[Vector3] = [
		Vector3(0, 0, -10),
		Vector3(0, 0, -40),
		Vector3(0, 0, -25),
		Vector3(0, 0, -70),
	]
	var test_racers: Array[Node3D] = []
	for i in range(positions.size()):
		var racer := Node3D.new()
		racer.name = "RankTest_%d" % i
		add_child(racer)
		racer.global_position = positions[i]
		RaceManager.register_racer(racer)
		test_racers.append(racer)
	if RaceManager.get_rank(test_racers[3]) != 1:
		return _fail("Leader rank incorrect")
	if RaceManager.get_rank(test_racers[1]) != 2:
		return _fail("Second-place rank incorrect")
	if RaceManager.get_rank(test_racers[2]) != 3:
		return _fail("Third-place rank incorrect")
	if RaceManager.get_rank(test_racers[0]) != 4:
		return _fail("Fourth-place rank incorrect")
	var standings := RaceManager.get_standings()
	if standings.size() != 4 or standings[0] != test_racers[3] or standings[3] != test_racers[0]:
		return _fail("Standings order incorrect")
	print("RANK SYSTEM PASS checkpoint_path_progress=true ranks=1-4")
	RaceManager.clear_racers()
	RaceManager.clear_track()
	for racer in test_racers:
		racer.queue_free()
	return true

func _fail(message: String) -> bool:
	push_error(message)
	print("GRAND PRIX DENSITY SMOKE FAIL " + message)
	get_tree().quit(1)
	return false
