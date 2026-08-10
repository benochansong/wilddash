extends Node

const TRACK_SCENE: PackedScene = preload("res://tracks/grand_prix_track.tscn")

func _ready() -> void:
	await get_tree().process_frame
	var failures: Array[String] = []

	# Item identity: six consumables stay meaningful beside cooldown skills.
	_check(ItemSystem.ITEM_IDS.size() == 6, "six items", failures)
	_check(ItemSystem.DASH_DURATION <= 2.0, "dash item duration", failures)
	_check(ItemSystem.DASH_SPEED_MULTIPLIER <= 1.50, "dash item speed cap", failures)
	_check(ItemSystem.SHIELD_DURATION <= 5.0, "shield duration cap", failures)
	_check(ItemSystem.SHOCKWAVE_RADIUS <= 7.5, "shockwave radius cap", failures)

	var dog := WildDashAnimalCatalog.get_definition(&"dog")
	var rabbit := WildDashAnimalCatalog.get_definition(&"rabbit")
	var elephant := WildDashAnimalCatalog.get_definition(&"elephant")
	var cat := WildDashAnimalCatalog.get_definition(&"cat")
	_check(dog != null and rabbit != null and elephant != null and cat != null, "animal definitions", failures)
	if dog != null and rabbit != null and elephant != null and cat != null:
		_check(dog.skill_name == "RALLY DASH" and is_equal_approx(dog.skill_cooldown, 9.0), "dog skill", failures)
		_check(dog.skill_speed_multiplier <= 1.15 and dog.skill_acceleration_multiplier <= 1.60, "dog stability cap", failures)
		_check(rabbit.skill_name == "SPRING LEAP" and is_equal_approx(rabbit.skill_cooldown, 8.0), "rabbit skill", failures)
		_check(rabbit.skill_jump_multiplier <= 1.50, "rabbit leap cap", failures)
		_check(elephant.skill_name == "STAMPEDE" and elephant.skill_cooldown >= 11.0, "elephant cooldown", failures)
		_check(elephant.skill_contact_force <= 4.5, "elephant push cap", failures)
		_check(cat.skill_name == "SHADOW STEP" and is_equal_approx(cat.skill_cooldown, 8.0), "cat skill", failures)
		_check(cat.skill_dash_distance <= 5.5 and cat.skill_evasion_duration <= 0.40, "cat dash boundary cap", failures)

		var max_speed := maxf(maxf(dog.max_speed, rabbit.max_speed), maxf(elephant.max_speed, cat.max_speed))
		var min_speed := minf(minf(dog.max_speed, rabbit.max_speed), minf(elephant.max_speed, cat.max_speed))
		_check(max_speed / min_speed <= 1.12, "base character speed spread", failures)

	# Chimera: HEAD is exact source skill, BODY <=10%, TAIL <=7% utility.
	for animal_id: StringName in WildDashAnimalCatalog.all_ids():
		var source := WildDashAnimalCatalog.get_definition(animal_id)
		_check(WildDashChimeraSystem.head_skill_definition(animal_id) == source, "chimera exact head skill %s" % animal_id, failures)
		var body := WildDashChimeraSystem.body_passive_profile(animal_id)
		_check(_bounded(body.get("acceleration_multiplier", 1.0), 0.90, 1.10), "body accel %s" % animal_id, failures)
		_check(_bounded(body.get("turn_multiplier", 1.0), 0.90, 1.10), "body handling %s" % animal_id, failures)
		_check(_bounded(body.get("knockback_received_multiplier", 1.0), 0.90, 1.10), "body knockback %s" % animal_id, failures)
		var tail := WildDashChimeraSystem.tail_utility_profile(animal_id)
		_check(_bounded(tail.get("acceleration_multiplier", 1.0), 0.93, 1.07), "tail accel %s" % animal_id, failures)
		_check(_bounded(tail.get("turn_multiplier", 1.0), 0.93, 1.07), "tail handling %s" % animal_id, failures)
		_check(_bounded(tail.get("jump_multiplier", 1.0), 0.93, 1.07), "tail jump %s" % animal_id, failures)
		_check(_bounded(tail.get("pickup_radius_multiplier", 1.0), 0.93, 1.07), "tail pickup %s" % animal_id, failures)

	# Track pacing and shortcut risk/reward.
	var track := TRACK_SCENE.instantiate() as WildDashGrandPrixTrack
	_check(track != null, "track instantiate", failures)
	if track != null:
		add_child(track)
		await get_tree().physics_frame
		var route := track.get_route_points()
		var checkpoints := track.get_checkpoint_positions()
		var length := track.get_track_length()
		_check(route.size() == 17, "route point count", failures)
		_check(checkpoints.size() == 7, "checkpoint count", failures)
		_check(length >= 1450.0 and length <= 1500.0, "track length", failures)
		var safe_distance := route[12].distance_to(route[13]) + route[13].distance_to(route[14])
		var shortcut_distance := route[12].distance_to(route[14])
		var saving := safe_distance - shortcut_distance
		var saving_ratio := saving / safe_distance
		_check(saving > 60.0 and saving <= 90.0, "shortcut saving distance", failures)
		_check(saving_ratio <= 0.30, "shortcut advantage cap", failures)
		var mean_ai_speed := (13.2 + 12.5 + 13.0 + 12.8) / 4.0
		var neutral_seconds := length / mean_ai_speed
		_check(neutral_seconds >= 80.0 and neutral_seconds <= 120.0, "neutral race pace estimate", failures)
		print("RC3 BALANCE TRACK length=%.1fm neutral=%.1fs shortcut_save=%.1fm shortcut_ratio=%.1f%%" % [length, neutral_seconds, saving, saving_ratio * 100.0])

	if not failures.is_empty():
		for failure in failures:
			push_error("RC3 BALANCE FAIL " + failure)
		get_tree().quit(1)
		return
	print("RC3 BALANCE PASS items=6 skills=4 chimera_caps=true elephant_cap=true rabbit_shortcut=true cat_boundary=true dog_cap=true")
	get_tree().quit(0)

func _bounded(value: Variant, minimum: float, maximum: float) -> bool:
	var number := float(value)
	return number >= minimum - 0.0001 and number <= maximum + 0.0001

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
