extends Node

const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")

func _ready() -> void:
	await get_tree().process_frame
	var ok := true
	ok = _test_profiles() and ok
	ok = await _test_overtake_and_recovery() and ok
	RaceManager.active = false
	RaceManager.clear_racers()
	RaceManager.clear_track()
	if ok:
		print("DIFFICULTY SYSTEM SMOKE PASS")
		get_tree().quit(0)
	else:
		push_error("DIFFICULTY SYSTEM SMOKE FAIL")
		get_tree().quit(2)

func _test_profiles() -> bool:
	var casual := WildDashDifficultySystem.get_profile(WildDashDifficultySystem.CASUAL)
	var normal := WildDashDifficultySystem.get_profile(WildDashDifficultySystem.NORMAL)
	var hard := WildDashDifficultySystem.get_profile(WildDashDifficultySystem.HARD)
	var ok := true

	ok = _expect(WildDashDifficultySystem.normalize(&"wild") == WildDashDifficultySystem.CASUAL, "legacy wild alias") and ok
	ok = _expect(WildDashDifficultySystem.normalize(&"chaos") == WildDashDifficultySystem.NORMAL, "legacy chaos alias") and ok
	ok = _expect(WildDashDifficultySystem.normalize(&"nightmare") == WildDashDifficultySystem.HARD, "legacy nightmare alias") and ok

	ok = _expect(float(casual.reaction_interval) > float(normal.reaction_interval) and float(normal.reaction_interval) > float(hard.reaction_interval), "reaction ordering") and ok
	ok = _expect(float(casual.corner_precision) < float(normal.corner_precision) and float(normal.corner_precision) < float(hard.corner_precision), "corner precision ordering") and ok
	ok = _expect(float(casual.item_utility_threshold) > float(normal.item_utility_threshold) and float(normal.item_utility_threshold) > float(hard.item_utility_threshold), "item threshold ordering") and ok
	ok = _expect(float(casual.skill_utility_threshold) > float(normal.skill_utility_threshold) and float(normal.skill_utility_threshold) > float(hard.skill_utility_threshold), "skill threshold ordering") and ok
	ok = _expect(float(casual.obstacle_speed_scale) < float(normal.obstacle_speed_scale) and float(normal.obstacle_speed_scale) < float(hard.obstacle_speed_scale), "obstacle ordering") and ok
	ok = _expect(float(hard.ai_speed_scale) <= 1.04, "hard speed cheat capped") and ok
	ok = _expect(float(casual.recovery_penalty) < float(normal.recovery_penalty) and float(normal.recovery_penalty) < float(hard.recovery_penalty), "recovery penalty ordering") and ok

	print("DIFFICULTY CASUAL PASS reaction=%.2f item=%.2f skill=%.2f obstacle=%.2f recovery=%.2f" % [float(casual.reaction_interval), float(casual.item_utility_threshold), float(casual.skill_utility_threshold), float(casual.obstacle_speed_scale), float(casual.recovery_penalty)])
	print("DIFFICULTY NORMAL PASS reaction=%.2f item=%.2f skill=%.2f obstacle=%.2f recovery=%.2f" % [float(normal.reaction_interval), float(normal.item_utility_threshold), float(normal.skill_utility_threshold), float(normal.obstacle_speed_scale), float(normal.recovery_penalty)])
	print("DIFFICULTY HARD PASS reaction=%.2f item=%.2f skill=%.2f obstacle=%.2f recovery=%.2f" % [float(hard.reaction_interval), float(hard.item_utility_threshold), float(hard.skill_utility_threshold), float(hard.obstacle_speed_scale), float(hard.recovery_penalty)])
	print("AI CORNER PASS casual=%.2f normal=%.2f hard=%.2f" % [float(casual.corner_precision), float(normal.corner_precision), float(hard.corner_precision)])
	print("AI ITEM DECISION PASS thresholds=%.2f/%.2f/%.2f" % [float(casual.item_utility_threshold), float(normal.item_utility_threshold), float(hard.item_utility_threshold)])
	print("AI SKILL DECISION PASS thresholds=%.2f/%.2f/%.2f" % [float(casual.skill_utility_threshold), float(normal.skill_utility_threshold), float(hard.skill_utility_threshold)])

	var casual_shortcut := WildDashDifficultySystem.should_take_shortcut(WildDashDifficultySystem.CASUAL, 4)
	var normal_shortcut := WildDashDifficultySystem.should_take_shortcut(WildDashDifficultySystem.NORMAL, 4)
	var hard_shortcut := WildDashDifficultySystem.should_take_shortcut(WildDashDifficultySystem.HARD, 4)
	ok = _expect(not casual_shortcut and normal_shortcut and hard_shortcut, "shortcut risk ordering for stable seed") and ok
	print("AI SHORTCUT PASS casual=%s normal=%s hard=%s" % [str(casual_shortcut), str(normal_shortcut), str(hard_shortcut)])
	return ok

func _test_overtake_and_recovery() -> bool:
	GameManager.difficulty = WildDashDifficultySystem.NORMAL
	RaceManager.clear_racers()
	RaceManager.clear_track()
	var route: Array[Vector3] = [Vector3(0, 0, 0), Vector3(0, 0, -50), Vector3(0, 0, -100)]
	RaceManager.configure_track(route, [])

	var chaser := RACER_SCENE.instantiate() as WildDashCharacterController
	chaser.name = "DifficultyChaser"
	chaser.is_player = false
	chaser.animal_id = &"dog"
	chaser.movement_mode = WildDashCharacterController.MovementMode.RACE
	chaser.position = Vector3(0, 0.1, -8)
	add_child(chaser)

	var leader := RACER_SCENE.instantiate() as WildDashCharacterController
	leader.name = "DifficultyLeader"
	leader.is_player = false
	leader.animal_id = &"rabbit"
	leader.movement_mode = WildDashCharacterController.MovementMode.RACE
	leader.position = Vector3(0, 0.1, -14)
	add_child(leader)

	var driver := WildDashAIController.new()
	driver.name = "DifficultyDriver"
	driver.racer_path = NodePath("../DifficultyChaser")
	driver.target_speed = 12.8
	driver.preferred_lane = 0.0
	add_child(driver)
	driver.set_race_route(route)

	var brain := WildDashAICompetitionBrain.new()
	brain.name = "DifficultyCompetitionBrain"
	brain.configure(chaser, driver)
	add_child(brain)
	await get_tree().process_frame
	await get_tree().physics_frame
	RaceManager.active = true

	var overtake := brain.debug_has_overtake_target()
	var penalty := brain.debug_force_recovery_penalty()
	var ok := _expect(overtake, "competition brain sees leader")
	ok = _expect(absf(penalty - 1.10) < 0.01, "normal recovery penalty") and ok
	print("AI OVERTAKE PASS target_ahead=%s rank_chaser=%d rank_leader=%d" % [str(overtake), RaceManager.get_rank(chaser), RaceManager.get_rank(leader)])
	print("AI RECOVERY PASS normal_penalty=%.2fs" % penalty)
	return ok

func _expect(condition: bool, label: String) -> bool:
	if condition:
		return true
	push_error("Difficulty smoke assertion failed: %s" % label)
	return false
