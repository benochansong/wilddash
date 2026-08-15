extends "res://modes/fruit_collection/fruit_frenzy_v3_ai_dispersion.gd"

## Round 2 V4: vertical collection + species terrain identity.
## Keeps the existing Harvest Heist loop but turns Climb/Agility/Swim into
## visible route choices rather than selection-screen-only numbers.

const LOW_FRUIT_INDICES: Array[int] = [16, 17, 18]
const HIGH_FRUIT_INDICES: Array[int] = [19, 20, 21]
const TREE_FRUIT_INDICES: Array[int] = [22, 23]

const ORCHARD_TREE_CENTERS: Array[Vector3] = [
	Vector3(-20.0, 0.0, -19.0), Vector3(-15.0, 0.0, -19.0), Vector3(-10.0, 0.0, -19.0),
	Vector3(-20.0, 0.0, -11.0), Vector3(-15.0, 0.0, -11.0), Vector3(-10.0, 0.0, -11.0),
]

const LOW_FRUIT_POSITIONS: Array[Vector3] = [
	Vector3(9.0, 1.70, 9.0),
	Vector3(-20.0, 1.65, 18.5),
	Vector3(10.2, 1.55, -13.8),
]
const HIGH_FRUIT_POSITIONS: Array[Vector3] = [
	Vector3(-19.2, 3.00, 12.7),
	Vector3(-13.8, 4.05, 10.8),
	Vector3(-7.8, 3.35, 18.4),
]
const TREE_FRUIT_POSITIONS: Array[Vector3] = [
	Vector3(-20.0, 4.25, -19.0),
	Vector3(-15.0, 5.25, -11.0),
]

var _terrain_state_by_id: Dictionary = {}
var _access_denied_reported: Dictionary = {}
var _climb_assist_cooldown := 0.0

func _ready() -> void:
	await super()
	_configure_vertical_fruit_metadata()
	for i in range(fruits.size()):
		fruits[i].position = _fruit_position(i, fruit_cycles[i] if i < fruit_cycles.size() else 0)
	print("FRUIT FRENZY V4 VERTICAL READY distribution=GROUND_16 LOW_3 HIGH_3 TREE_2 percentages=66.7/12.5/12.5/8.3 water_traits=true full_roster_ai=true")

func _physics_process(delta: float) -> void:
	super(delta)
	_climb_assist_cooldown = maxf(0.0, _climb_assist_cooldown - delta)
	_update_player_climb_assist()

func _build_zone_world() -> void:
	super()
	_build_vertical_collection_geometry()

func _spawn_field() -> void:
	player = spawn_racer("Player", &"dog", Vector3(0.0, 0.15, 19.0), true, WildDashCharacterController.MovementMode.ARENA)
	_register_racer_state(player)

	var animals := WildDashAnimalCatalog.playable_ids()
	var total_ai: int = GameManager.ai_count
	for i in range(total_ai):
		var angle: float = TAU * float(i) / maxf(1.0, float(total_ai))
		var radius: float = 10.0 + float(i % 3) * 3.4
		var spawn := Vector3(cos(angle) * radius, 0.15, sin(angle) * radius)
		var animal := animals[i % animals.size()]
		var racer := spawn_racer(
			"AI_%02d" % (i + 1),
			animal,
			spawn,
			false,
			WildDashCharacterController.MovementMode.ARENA
		)
		var base_target_speed: float = 6.85 + float(i % 4) * 0.20
		spawn_ai_driver(racer, WildDashAIController.AIMode.ARENA, base_target_speed)
		_register_racer_state(racer)
		ai_personalities.append(_personality_for_ai(i))
		ai_base_target_speeds.append(base_target_speed)

	ai_scores.resize(ai_racers.size())
	for i in range(ai_scores.size()):
		ai_scores[i] = 0
	print("FRUIT FRENZY FIELD V4 total=%d ai=%d roster=12 crocodile=true" % [racers.size(), ai_racers.size()])

func _build_vertical_collection_geometry() -> void:
	# Low platforms: readable stepping targets that most animals can reach.
	create_box("LowFruitMarketCrate", Vector3(9.0, 0.85, 9.0), Vector3(2.8, 1.7, 2.8), Color(0.50, 0.30, 0.14), true)
	create_box("LowFruitHay", Vector3(-20.0, 0.82, 18.5), Vector3(3.0, 1.6, 2.5), Color(0.82, 0.66, 0.18), true)
	create_box("LowFruitRiverRock", Vector3(10.2, 0.76, -13.8), Vector3(2.5, 1.5, 2.5), Color(0.34, 0.36, 0.34), true)

	# Hill route: three distinct heights so Rabbit/Deer/Monkey/Cat/Fox can cash in
	# on jump/agility without hiding a huge portion of the score from heavy racers.
	create_box("HillHighPlatformA", Vector3(-19.2, 1.40, 12.7), Vector3(4.0, 2.8, 4.0), Color(0.43, 0.35, 0.18), true)
	create_box("HillHighPlatformB", Vector3(-13.8, 1.95, 10.8), Vector3(4.4, 3.9, 4.4), Color(0.45, 0.37, 0.19), true)
	create_box("HillHighPlatformC", Vector3(-7.8, 1.60, 18.4), Vector3(4.0, 3.2, 4.0), Color(0.42, 0.34, 0.17), true)

	# Two prototype climbable trees. Wide branch shelves make the gameplay read
	# clearly even before bespoke climbing animation exists.
	_create_branch_set("TreeRouteA", ORCHARD_TREE_CENTERS[0], 1.0)
	_create_branch_set("TreeRouteB", ORCHARD_TREE_CENTERS[4], 1.18)

func _create_branch_set(prefix: String, center: Vector3, scale_factor: float) -> void:
	create_box(prefix + "LowBranch", center + Vector3(1.15, 1.75, 0.0), Vector3(2.8, 0.28, 1.1), Color(0.36, 0.20, 0.08), true)
	create_box(prefix + "MidBranch", center + Vector3(-0.95, 2.75 * scale_factor, 0.45), Vector3(2.5, 0.26, 1.0), Color(0.34, 0.18, 0.07), true)
	create_box(prefix + "HighBranch", center + Vector3(0.65, 3.75 * scale_factor, -0.25), Vector3(2.2, 0.24, 0.9), Color(0.32, 0.17, 0.065), true)

func _fruit_position(index: int, cycle: int) -> Vector3:
	if LOW_FRUIT_INDICES.has(index):
		return LOW_FRUIT_POSITIONS[LOW_FRUIT_INDICES.find(index)]
	if HIGH_FRUIT_INDICES.has(index):
		return HIGH_FRUIT_POSITIONS[HIGH_FRUIT_INDICES.find(index)]
	if TREE_FRUIT_INDICES.has(index):
		return TREE_FRUIT_POSITIONS[TREE_FRUIT_INDICES.find(index)]
	return super(index, cycle)

func _configure_vertical_fruit_metadata() -> void:
	for i in range(fruits.size()):
		var fruit := fruits[i]
		if TREE_FRUIT_INDICES.has(i):
			var tree_slot := TREE_FRUIT_INDICES.find(i)
			var tier := 2 if tree_slot == 0 else 3
			var required_climb := 8.5 if tier == 2 else 9.5
			WildDashFruitAccessSystem.configure_fruit(fruit, WildDashFruitAccessSystem.FruitAccessType.TREE, required_climb, 7.5, tier)
			fruit.set_meta(&"wilddash_preferred_traits", [&"climb", &"agility"])
		elif HIGH_FRUIT_INDICES.has(i):
			WildDashFruitAccessSystem.configure_fruit(fruit, WildDashFruitAccessSystem.FruitAccessType.HIGH_PLATFORM, 7.0, 8.5, 0)
			fruit.set_meta(&"wilddash_preferred_traits", [&"agility", &"climb"])
		elif LOW_FRUIT_INDICES.has(i):
			WildDashFruitAccessSystem.configure_fruit(fruit, WildDashFruitAccessSystem.FruitAccessType.LOW_PLATFORM, 5.5, 6.0, 0)
		else:
			WildDashFruitAccessSystem.configure_fruit(fruit, WildDashFruitAccessSystem.FruitAccessType.GROUND)

func _try_pickup_regular_fruit(racer: WildDashCharacterController) -> void:
	var radius: float = racer.get_interaction_radius(FRUIT_PICKUP_RADIUS)
	var radius_sq := radius * radius
	for i in range(fruits.size()):
		if not fruit_active[i]:
			continue
		if racer.global_position.distance_squared_to(fruits[i].global_position) > radius_sq:
			continue
		if not WildDashFruitAccessSystem.can_racer_reach_fruit(racer, fruits[i]):
			if racer.is_player:
				var report_key := "%s:%d" % [String(racer.animal_id), i]
				if not _access_denied_reported.has(report_key):
					_access_denied_reported[report_key] = true
					var access_name := WildDashFruitAccessSystem.get_access_name(fruits[i])
					var reason := WildDashFruitAccessSystem.access_reason(racer, fruits[i])
					hud.set_message("%s FRUIT · %s" % [access_name, reason.replace("_", " ")])
					print("FRUIT ACCESS DENIED animal=%s access=%s reason=%s" % [String(racer.animal_id), access_name, reason])
			return
		if not _can_carry_value(racer, fruit_values[i]):
			if racer.is_player:
				hud.set_message("BAG FULL · BANK BEFORE PICKING %s" % String(fruit_types[i]).to_upper())
			return
		if racer.is_player and WildDashFruitAccessSystem.get_access_type(fruits[i]) != WildDashFruitAccessSystem.FruitAccessType.GROUND:
			print("FRUIT ACCESS animal=%s access=%s result=true" % [String(racer.animal_id), WildDashFruitAccessSystem.get_access_name(fruits[i])])
		_collect_regular_fruit(racer, i)
		return

func _best_regular_fruit_index_for_ai(racer: WildDashCharacterController, ai_index: int, claims: Dictionary) -> int:
	var best_index := -1
	var best_score := INF
	var home_zone := int(_ai_home_zone_by_id.get(racer.get_instance_id(), ai_index % 4))
	for fruit_index in range(fruits.size()):
		if claims.has(fruit_index):
			continue
		if not fruit_active[fruit_index] or not _can_carry_value(racer, fruit_values[fruit_index]):
			continue
		if not WildDashFruitAccessSystem.can_racer_reach_fruit(racer, fruits[fruit_index]):
			continue
		var score := racer.global_position.distance_squared_to(fruits[fruit_index].global_position)
		if fruit_index < 16 and fruit_index % 4 != home_zone:
			score += HOME_ZONE_BIAS
		var access_type := WildDashFruitAccessSystem.get_access_type(fruits[fruit_index])
		match racer.animal_id:
			&"monkey":
				if access_type == WildDashFruitAccessSystem.FruitAccessType.TREE: score -= 42.0
			&"cat":
				if access_type in [WildDashFruitAccessSystem.FruitAccessType.TREE, WildDashFruitAccessSystem.FruitAccessType.HIGH_PLATFORM]: score -= 28.0
			&"rabbit", &"deer":
				if access_type == WildDashFruitAccessSystem.FruitAccessType.HIGH_PLATFORM: score -= 26.0
			&"crocodile", &"raccoon", &"bear":
				if _is_river_position(fruits[fruit_index].global_position): score -= 34.0
			&"elephant", &"boar":
				if access_type == WildDashFruitAccessSystem.FruitAccessType.GROUND: score -= 18.0
		score += float((fruit_index * 7 + ai_index * 11) % 9) * 0.17
		if score < best_score:
			best_score = score
			best_index = fruit_index
	return best_index

func _update_speed_profiles() -> void:
	super()
	for racer: WildDashCharacterController in racers:
		if racer == null:
			continue
		var in_water := _is_river_position(racer.global_position)
		var terrain := WildDashTerrainAbilitySystem.TERRAIN_WATER if in_water else WildDashTerrainAbilitySystem.TERRAIN_LAND
		if in_water:
			var scale := WildDashTerrainAbilitySystem.get_terrain_speed_multiplier(racer.animal_id, terrain)
			racer.arena_move_speed *= scale
		var id := racer.get_instance_id()
		var previous := StringName(_terrain_state_by_id.get(id, &""))
		if previous != terrain:
			_terrain_state_by_id[id] = terrain
			if racer.is_player or racer.animal_id == &"crocodile":
				print("CROCODILE WATER BONUS animal=%s terrain=%s speed_scale=%.2f" % [
					String(racer.animal_id), String(terrain), WildDashTerrainAbilitySystem.get_terrain_speed_multiplier(racer.animal_id, terrain),
				])

	for i in range(ai_drivers.size()):
		if i >= ai_racers.size():
			continue
		var racer := ai_racers[i]
		if racer != null and _is_river_position(racer.global_position):
			ai_drivers[i].target_speed *= WildDashTerrainAbilitySystem.get_terrain_speed_multiplier(racer.animal_id, WildDashTerrainAbilitySystem.TERRAIN_WATER)

func _is_river_position(position: Vector3) -> bool:
	return position.x >= 5.0 and position.x <= 23.0 and position.z >= -17.5 and position.z <= -10.5

func _update_player_climb_assist() -> void:
	if player == null or not is_instance_valid(player) or _climb_assist_cooldown > 0.0:
		return
	if not Input.is_action_pressed(&"jump"):
		return
	var climb := WildDashAnimalAbilityProfile.get_stat(player.animal_id, &"climb")
	if climb < 7.0:
		return
	var near_tree := false
	for center in ORCHARD_TREE_CENTERS:
		var planar := Vector2(player.global_position.x - center.x, player.global_position.z - center.z)
		if planar.length() <= 2.7 and player.global_position.y <= 5.8:
			near_tree = true
			break
	if not near_tree:
		return
	var assist := 4.2 + (climb - 7.0) * 0.55
	if player.animal_id == &"monkey":
		assist += 1.0
	elif player.animal_id == &"cat":
		assist += 0.45
	player.velocity.y = maxf(player.velocity.y, assist)
	_climb_assist_cooldown = 0.30
	if player.is_player:
		hud.set_message("CLIMB ASSIST · %s %.1f" % [player.get_display_name().to_upper(), climb])
