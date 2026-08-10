extends Node

const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")

func _ready() -> void:
	await get_tree().process_frame
	var failures: Array[String] = []

	var casual := WildDashDifficultySystem.get_profile(WildDashDifficultySystem.CASUAL)
	var normal := WildDashDifficultySystem.get_profile(WildDashDifficultySystem.NORMAL)
	var hard := WildDashDifficultySystem.get_profile(WildDashDifficultySystem.HARD)

	_check(WildDashDifficultySystem.normalize(&"wild") == WildDashDifficultySystem.CASUAL, "legacy wild alias", failures)
	_check(WildDashDifficultySystem.normalize(&"chaos") == WildDashDifficultySystem.NORMAL, "legacy chaos alias", failures)
	_check(WildDashDifficultySystem.normalize(&"nightmare") == WildDashDifficultySystem.HARD, "legacy nightmare alias", failures)
	_check(int(casual.ai_count) == 6 and int(normal.ai_count) == 10 and int(hard.ai_count) == 14, "difficulty ai counts", failures)
	_check(float(hard.speed_scale) <= 1.07, "hard speed cap prevents speed-only cheating", failures)
	print("DIFFICULTY CASUAL PASS ai=%d reaction=%.3f risk=%.2f" % [int(casual.ai_count), float(casual.reaction_interval), float(casual.risk_taking)])
	print("DIFFICULTY NORMAL PASS ai=%d reaction=%.3f risk=%.2f" % [int(normal.ai_count), float(normal.reaction_interval), float(normal.risk_taking)])
	print("DIFFICULTY HARD PASS ai=%d reaction=%.3f risk=%.2f" % [int(hard.ai_count), float(hard.reaction_interval), float(hard.risk_taking)])

	_check(float(casual.reaction_interval) > float(normal.reaction_interval) and float(normal.reaction_interval) > float(hard.reaction_interval), "reaction ordering", failures)
	_check(float(casual.corner_precision) < float(normal.corner_precision) and float(normal.corner_precision) < float(hard.corner_precision), "corner precision ordering", failures)
	_check(float(casual.steering_scale) < float(normal.steering_scale) and float(normal.steering_scale) < float(hard.steering_scale), "corner steering ordering", failures)
	print("AI CORNER PASS casual=%.2f normal=%.2f hard=%.2f" % [float(casual.corner_precision), float(normal.corner_precision), float(hard.corner_precision)])

	var item_casual := WildDashAIItemBrain.new()
	var item_normal := WildDashAIItemBrain.new()
	var item_hard := WildDashAIItemBrain.new()
	item_casual.configure_difficulty(WildDashDifficultySystem.CASUAL)
	item_normal.configure_difficulty(WildDashDifficultySystem.NORMAL)
	item_hard.configure_difficulty(WildDashDifficultySystem.HARD)
	_check(item_casual.get_utility_threshold() > item_normal.get_utility_threshold(), "item casual threshold", failures)
	_check(item_normal.get_utility_threshold() > item_hard.get_utility_threshold(), "item hard threshold", failures)
	_check(item_casual.get_decision_interval() > item_normal.get_decision_interval() and item_normal.get_decision_interval() > item_hard.get_decision_interval(), "item decision interval", failures)
	print("AI ITEM DECISION PASS thresholds=%.2f/%.2f/%.2f" % [item_casual.get_utility_threshold(), item_normal.get_utility_threshold(), item_hard.get_utility_threshold()])
	item_casual.free()
	item_normal.free()
	item_hard.free()

	var skill_casual := WildDashAISkillBrain.new()
	var skill_normal := WildDashAISkillBrain.new()
	var skill_hard := WildDashAISkillBrain.new()
	skill_casual.configure_difficulty(WildDashDifficultySystem.CASUAL)
	skill_normal.configure_difficulty(WildDashDifficultySystem.NORMAL)
	skill_hard.configure_difficulty(WildDashDifficultySystem.HARD)
	_check(skill_casual.get_utility_threshold() > skill_normal.get_utility_threshold() and skill_normal.get_utility_threshold() > skill_hard.get_utility_threshold(), "skill threshold ordering", failures)
	_check(skill_casual.get_decision_interval() > skill_normal.get_decision_interval() and skill_normal.get_decision_interval() > skill_hard.get_decision_interval(), "skill reaction ordering", failures)
	print("AI SKILL DECISION PASS thresholds=%.2f/%.2f/%.2f" % [skill_casual.get_utility_threshold(), skill_normal.get_utility_threshold(), skill_hard.get_utility_threshold()])
	skill_casual.free()
	skill_normal.free()
	skill_hard.free()

	_check(float(casual.overtake_strength) < float(normal.overtake_strength) and float(normal.overtake_strength) < float(hard.overtake_strength), "overtake strength ordering", failures)
	var actual_overtake := await _verify_actual_overtake(failures)
	_check(actual_overtake, "actual overtake response", failures)
	print("AI OVERTAKE PASS actual=%s normal_strength=%.2f hard_strength=%.2f" % [str(actual_overtake), float(normal.overtake_strength), float(hard.overtake_strength)])

	_check(float(casual.shortcut_chance) < float(normal.shortcut_chance) and float(normal.shortcut_chance) < float(hard.shortcut_chance), "shortcut risk ordering", failures)
	_check(WildDashDifficultySystem.should_use_shortcut(WildDashDifficultySystem.HARD, &"rabbit", 0), "hard rabbit shortcut", failures)
	print("AI SHORTCUT PASS casual=%.2f normal=%.2f hard=%.2f" % [float(casual.shortcut_chance), float(normal.shortcut_chance), float(hard.shortcut_chance)])

	_check(float(casual.recovery_penalty_seconds) < float(normal.recovery_penalty_seconds) and float(normal.recovery_penalty_seconds) < float(hard.recovery_penalty_seconds), "recovery penalty ordering", failures)
	_check(float(normal.recovery_penalty_seconds) >= 0.9 and float(hard.recovery_penalty_seconds) <= 1.5, "recovery penalty range", failures)
	print("AI RECOVERY PASS penalties=%.2f/%.2f/%.2f" % [float(casual.recovery_penalty_seconds), float(normal.recovery_penalty_seconds), float(hard.recovery_penalty_seconds)])

	_check(float(casual.obstacle_speed_scale) < 1.0 and float(normal.obstacle_speed_scale) > 1.0 and float(hard.obstacle_speed_scale) > float(normal.obstacle_speed_scale), "obstacle difficulty ordering", failures)

	if not failures.is_empty():
		for failure in failures:
			push_error("DIFFICULTY SYSTEM FAIL " + failure)
		RaceManager.active = false
		RaceManager.clear_racers()
		RaceManager.clear_track()
		get_tree().quit(1)
		return

	print("DIFFICULTY SYSTEM PASS speed_cheat=false profiles=3 max_ai=14")
	RaceManager.active = false
	RaceManager.clear_racers()
	RaceManager.clear_track()
	get_tree().quit(0)

func _verify_actual_overtake(failures: Array[String]) -> bool:
	RaceManager.active = false
	RaceManager.clear_racers()
	RaceManager.clear_track()
	var route: Array[Vector3] = [Vector3(0, 0, 10), Vector3(0, 0, -40), Vector3(0, 0, -100)]
	var checkpoints: Array[Vector3] = []
	RaceManager.configure_track(route, checkpoints)

	var chaser := RACER_SCENE.instantiate() as WildDashCharacterController
	var leader := RACER_SCENE.instantiate() as WildDashCharacterController
	_check(chaser != null and leader != null, "overtake racers instantiate", failures)
	if chaser == null or leader == null:
		return false
	chaser.name = "OvertakeChaser"
	leader.name = "OvertakeLeader"
	chaser.animal_id = &"dog"
	leader.animal_id = &"rabbit"
	chaser.is_player = false
	leader.is_player = false
	chaser.movement_mode = WildDashCharacterController.MovementMode.RACE
	leader.movement_mode = WildDashCharacterController.MovementMode.RACE
	chaser.position = Vector3(0, 1.0, 4.0)
	leader.position = Vector3(0.2, 1.0, -2.0)
	add_child(chaser)
	add_child(leader)
	RaceManager.register_racer(chaser)
	RaceManager.register_racer(leader)

	var driver := WildDashAIController.new()
	driver.name = "OvertakeDriver"
	driver.racer_path = NodePath("../OvertakeChaser")
	driver.ai_mode = WildDashAIController.AIMode.RACE
	driver.target_speed = 10.0
	driver.lane_wander = 0.0
	add_child(driver)
	driver.apply_difficulty(WildDashDifficultySystem.NORMAL)
	driver.set_race_route(route)
	RaceManager.start_race()
	for _i in range(12):
		await get_tree().physics_frame
	var result := driver.get_overtake_count() > 0
	RaceManager.active = false
	driver.queue_free()
	chaser.queue_free()
	leader.queue_free()
	await get_tree().process_frame
	return result

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
