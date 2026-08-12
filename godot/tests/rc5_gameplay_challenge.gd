extends Node

const TRACK_SCENE: PackedScene = preload("res://tracks/grand_prix_track.tscn")
const NEON_TRACK_SCENE: PackedScene = preload("res://tracks/neon_harbor_track.tscn")
const MIN_TRACK_LENGTH := 2200.0
const MAX_TRACK_LENGTH := 2600.0
const MIN_CHECKPOINTS := 10
const MAX_CHECKPOINTS := 12
const MIN_ITEMS := 12
const MAX_SHIELD_SHARE := 0.18

func _ready() -> void:
	await get_tree().process_frame
	var failures: Array[String] = []

	# Difficulty / campaign integration. Check each StringName explicitly instead
	# of comparing a typed Array[StringName] against an untyped literal array.
	_check(GameManager.CASUAL_AI_COUNT == 9, "Casual should be Player + 9 AI", failures)
	_check(GameManager.NORMAL_AI_COUNT == 14, "Normal should be Player + 14 AI", failures)
	_check(GameManager.HARD_AI_COUNT == 17, "Hard should be Player + 17 AI", failures)
	_check(GameManager.DEFAULT_AI_COUNT == GameManager.NORMAL_AI_COUNT, "Normal should be production default", failures)
	_check(GameManager.MAX_AI_COUNT >= GameManager.HARD_AI_COUNT, "Hard racer count supported", failures)
	_check(GameManager.ROUND_IDS.size() == 4, "four-round campaign size", failures)
	if GameManager.ROUND_IDS.size() == 4:
		_check(GameManager.ROUND_IDS[0] == &"grand_prix", "Round 1 Grand Prix", failures)
		_check(GameManager.ROUND_IDS[1] == &"fruit_collection", "Round 2 Fruit Collection", failures)
		_check(GameManager.ROUND_IDS[2] == &"neon_harbor_race", "Round 3 Neon Harbor", failures)
		_check(GameManager.ROUND_IDS[3] == &"push_out", "Round 4 Push Out", failures)
	_check(ResourceLoader.exists("res://modes/floor_collapse/floor_collapse.tscn"), "Floor Collapse preserved outside campaign", failures)

	# Item challenge: 12 distinct definitions, rank weighting, shield frequency,
	# dash ceiling, and chain-CC protection.
	_check(ItemSystem.get_item_count() >= MIN_ITEMS, "minimum 12 items", failures)
	var front_total := 0.0
	var mid_total := 0.0
	var back_total := 0.0
	var shield_front := 0.0
	var shield_mid := 0.0
	var shield_back := 0.0
	for item_id: StringName in ItemSystem.ITEM_IDS:
		var definition := ItemSystem.get_definition(item_id)
		_check(definition != null, "item definition %s" % item_id, failures)
		if definition == null:
			continue
		_check(definition.front_weight > 0.0 and definition.mid_weight > 0.0 and definition.back_weight > 0.0, "rank weights %s" % item_id, failures)
		front_total += definition.front_weight
		mid_total += definition.mid_weight
		back_total += definition.back_weight
		if item_id == ItemSystem.BUBBLE_SHIELD:
			shield_front = definition.front_weight
			shield_mid = definition.mid_weight
			shield_back = definition.back_weight
	_check(ItemSystem.DASH_DURATION <= 2.0, "Dash Berry duration cap", failures)
	_check(ItemSystem.DASH_SPEED_MULTIPLIER <= 1.50, "Dash Berry speed cap", failures)
	_check(ItemSystem.HIT_IMMUNITY_DURATION >= 0.75, "anti chain-CC immunity", failures)
	if front_total > 0.0 and mid_total > 0.0 and back_total > 0.0:
		_check(shield_front / front_total <= MAX_SHIELD_SHARE, "front shield share", failures)
		_check(shield_mid / mid_total <= MAX_SHIELD_SHARE, "mid shield share", failures)
		_check(shield_back / back_total <= MAX_SHIELD_SHARE, "back shield share", failures)
		print("RC5 SHIELD WEIGHT PASS front=%.1f%% mid=%.1f%% back=%.1f%% cap=%.0f%%" % [
			shield_front / front_total * 100.0,
			shield_mid / mid_total * 100.0,
			shield_back / back_total * 100.0,
			MAX_SHIELD_SHARE * 100.0,
		])

	# Character identity and known exploit caps.
	var dog := WildDashAnimalCatalog.get_definition(&"dog")
	var rabbit := WildDashAnimalCatalog.get_definition(&"rabbit")
	var elephant := WildDashAnimalCatalog.get_definition(&"elephant")
	var cat := WildDashAnimalCatalog.get_definition(&"cat")
	_check(dog != null and rabbit != null and elephant != null and cat != null, "four base characters", failures)
	_check(WildDashAnimalCatalog.race_roster_ids().size() == 12, "twelve-species race NPC roster", failures)
	if dog != null and rabbit != null and elephant != null and cat != null:
		_check(dog.skill_id == &"rally_dash" and dog.skill_cooldown >= 9.0, "Dog Rally Dash cooldown", failures)
		_check(dog.skill_speed_multiplier <= 1.15 and dog.skill_acceleration_multiplier <= 1.60, "Dog Rally Dash ceiling", failures)
		_check(rabbit.skill_id == &"spring_leap" and rabbit.skill_jump_multiplier <= 1.50, "Rabbit shortcut leap ceiling", failures)
		_check(elephant.skill_id == &"stampede" and elephant.skill_cooldown >= 11.0 and elephant.skill_push_strength <= 4.5, "Elephant pack-race ceiling", failures)
		_check(cat.skill_id == &"shadow_step" and cat.skill_forward_impulse <= 4.5 and cat.skill_lateral_impulse <= 7.0 and cat.skill_evade_duration <= 0.40, "Cat track-boundary dash ceiling", failures)
		var max_speed := maxf(maxf(dog.max_speed, rabbit.max_speed), maxf(elephant.max_speed, cat.max_speed))
		var min_speed := minf(minf(dog.max_speed, rabbit.max_speed), minf(elephant.max_speed, cat.max_speed))
		_check(max_speed / min_speed <= 1.12, "base character speed spread", failures)
		_check(ItemSystem.DASH_SPEED_MULTIPLIER * dog.skill_speed_multiplier <= 1.75, "Dog + Dash theoretical ceiling", failures)

	# Chimera remains bounded and based on the original four playable animals.
	var max_chimera_accel := 1.0
	var max_chimera_turn := 1.0
	for animal_id: StringName in WildDashAnimalCatalog.all_ids():
		var source := WildDashAnimalCatalog.get_definition(animal_id)
		_check(WildDashChimeraSystem.head_skill_definition(animal_id) == source, "Chimera exact head skill %s" % animal_id, failures)
		var body := WildDashChimeraSystem.body_passive_profile(animal_id)
		var tail := WildDashChimeraSystem.tail_utility_profile(animal_id)
		_check(_bounded(body.get("acceleration_multiplier", 1.0), 0.90, 1.10), "Chimera body accel %s" % animal_id, failures)
		_check(_bounded(body.get("turn_multiplier", 1.0), 0.90, 1.10), "Chimera body turn %s" % animal_id, failures)
		_check(_bounded(body.get("knockback_received_multiplier", 1.0), 0.90, 1.10), "Chimera body knockback %s" % animal_id, failures)
		_check(_bounded(tail.get("acceleration_multiplier", 1.0), 0.93, 1.07), "Chimera tail accel %s" % animal_id, failures)
		_check(_bounded(tail.get("turn_multiplier", 1.0), 0.93, 1.07), "Chimera tail turn %s" % animal_id, failures)
		_check(_bounded(tail.get("pickup_radius_multiplier", 1.0), 0.93, 1.07), "Chimera tail pickup %s" % animal_id, failures)
		max_chimera_accel = maxf(max_chimera_accel, float(body.get("acceleration_multiplier", 1.0)) * float(tail.get("acceleration_multiplier", 1.0)))
		max_chimera_turn = maxf(max_chimera_turn, float(body.get("turn_multiplier", 1.0)) * float(tail.get("turn_multiplier", 1.0)))
	_check(max_chimera_accel <= 1.18 and max_chimera_turn <= 1.18, "Chimera combined passive ceiling", failures)
	print("RC5 CHIMERA CAP PASS accel=%.3f turn=%.3f" % [max_chimera_accel, max_chimera_turn])

	# Round 1 extended production track remains unchanged.
	RaceManager.clear_racers()
	RaceManager.clear_track()
	var track := TRACK_SCENE.instantiate() as WildDashGrandPrixTrack
	_check(track != null, "Grand Prix track instantiate", failures)
	if track != null:
		add_child(track)
		await get_tree().physics_frame
		var length := track.get_track_length()
		var checkpoints := track.get_checkpoint_positions().size()
		var shortcut_a := track.get_shortcut_a_saving()
		var shortcut_b := track.get_shortcut_b_saving()
		_check(length >= MIN_TRACK_LENGTH and length <= MAX_TRACK_LENGTH, "2.2-2.6km Grand Prix", failures)
		_check(checkpoints >= MIN_CHECKPOINTS and checkpoints <= MAX_CHECKPOINTS, "10-12 checkpoints", failures)
		_check(shortcut_a >= 45.0 and shortcut_a <= 95.0, "Shortcut A risk/reward", failures)
		_check(shortcut_b >= 45.0 and shortcut_b <= 95.0, "Shortcut B risk/reward", failures)
		print("RC5 TRACK CHALLENGE PASS length=%.1fm checkpoints=%d shortcuts=2 save_a=%.1fm save_b=%.1fm" % [length, checkpoints, shortcut_a, shortcut_b])
		track.queue_free()
		await get_tree().process_frame

	# Round 3 must be a distinct shorter night race, not another copy of Round 1.
	RaceManager.clear_racers()
	RaceManager.clear_track()
	var neon := NEON_TRACK_SCENE.instantiate() as WildDashNeonHarborTrack
	_check(neon != null, "Neon Harbor track instantiate", failures)
	if neon != null:
		add_child(neon)
		await get_tree().physics_frame
		_check(neon.get_track_length() >= 1500.0 and neon.get_track_length() <= 1900.0, "1.5-1.9km Neon Harbor", failures)
		_check(neon.get_route_points().size() >= 22 and neon.get_route_points().size() <= 28, "22-28 Neon Harbor route points", failures)
		_check(neon.get_checkpoint_positions().size() >= 8 and neon.get_checkpoint_positions().size() <= 10, "8-10 Neon Harbor checkpoints", failures)
		_check(neon.get_zone_names().has("Industrial Tunnel") and neon.get_zone_names().has("Neon Downtown"), "Neon Harbor distinct zones", failures)
		_check(neon.get_shortcut_a_saving() > 8.0, "Neon Harbor shortcut risk/reward", failures)
		print("RC5 ROUND3 NEON HARBOR PASS length=%.1fm points=%d checkpoints=%d zones=%d npc_species=%d" % [
			neon.get_track_length(), neon.get_route_points().size(), neon.get_checkpoint_positions().size(), neon.get_zone_names().size(), WildDashAnimalCatalog.race_roster_ids().size(),
		])

	if not failures.is_empty():
		for failure in failures:
			push_error("RC5 GAMEPLAY CHALLENGE FAIL " + failure)
		get_tree().quit(1)
		return
	print("RC5 GAMEPLAY CHALLENGE PASS items=%d skills=4 racers=15 hard=18 round3=neon_harbor" % ItemSystem.get_item_count())
	get_tree().quit(0)

func _bounded(value: Variant, minimum: float, maximum: float) -> bool:
	var number := float(value)
	return number >= minimum - 0.0001 and number <= maximum + 0.0001

func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
