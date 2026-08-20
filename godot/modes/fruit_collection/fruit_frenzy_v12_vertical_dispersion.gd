extends "res://modes/fruit_collection/fruit_frenzy_v11_combat_ai_polish.gd"

## Round 2 V12 — collection-first AI + tall orchard vertical collection.
##
## V10 added a second combat-target pass after the collection planner, which could
## overwrite fruit targets and make the roster move as one fighting blob. V12 owns
## the final decision pass: each AI receives one primary intent, regular fruit is
## reserved for a short lock window, combat is local/opportunistic, and six search
## sectors spread the field. The same layer expands the live pool to 30 fruit and
## turns all six orchard trees into real climb/branch routes.

const V12_FRUIT_COUNT: int = 30
const V12_GROUND_INDICES: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
const V12_WATER_INDICES: Array[int] = [11, 12]
const V12_LOW_INDICES: Array[int] = [13, 14, 15, 16]
const V12_HIGH_INDICES: Array[int] = [17, 18, 19, 20, 21, 22]
const V12_TREE_INDICES: Array[int] = [23, 24, 25, 26, 27, 28, 29]

const V12_TREE_TOP_HEIGHTS: Array[float] = [4.6, 5.1, 5.8, 6.4, 7.1, 7.8]
const V12_TREE_CENTERS: Array[Vector3] = [
	Vector3(-20.0, 0.0, -19.0), Vector3(-15.0, 0.0, -19.0), Vector3(-10.0, 0.0, -19.0),
	Vector3(-20.0, 0.0, -11.0), Vector3(-15.0, 0.0, -11.0), Vector3(-10.0, 0.0, -11.0),
]
const V12_WATER_POSITIONS: Array[Vector3] = [
	Vector3(10.4, 0.46, -14.8), Vector3(18.8, 0.46, -13.2),
]
const V12_LOW_POSITIONS: Array[Vector3] = [
	Vector3(8.8, 1.70, 9.0), Vector3(19.6, 1.65, 18.2),
	Vector3(-20.0, 1.65, 18.5), Vector3(10.2, 1.55, -13.8),
]
const V12_HIGH_POSITIONS: Array[Vector3] = [
	Vector3(-22.0, 2.85, 10.5), Vector3(-17.5, 3.35, 13.4), Vector3(-12.8, 3.95, 10.2),
	Vector3(-8.5, 4.45, 15.0), Vector3(-18.2, 5.00, 20.5), Vector3(-10.0, 5.45, 20.3),
]
const V12_TREE_POSITIONS: Array[Vector3] = [
	Vector3(-20.0, 3.75, -19.0),
	Vector3(-15.0, 4.35, -19.0),
	Vector3(-10.0, 5.05, -19.0),
	Vector3(-20.0, 5.65, -11.0),
	Vector3(-15.0, 6.35, -11.0),
	Vector3(-10.0, 7.10, -11.0),
	Vector3(-15.0, 7.55, -11.0),
]

const V12_INTENT_COLLECT: StringName = &"COLLECT"
const V12_INTENT_BANK: StringName = &"BANK"
const V12_INTENT_COMBAT: StringName = &"COMBAT"
const V12_INTENT_GOLDEN: StringName = &"GOLDEN"
const V12_INTENT_WATER: StringName = &"WATER"
const V12_INTENT_CANOPY: StringName = &"CANOPY"
const V12_TARGET_LOCK_MSEC: int = 2200
const V12_NORMAL_COMBAT_RANGE: float = 4.2
const V12_HUNTER_COMBAT_RANGE: float = 6.5
const V12_SEPARATION_RADIUS: float = 2.6
const V12_SEPARATION_STRENGTH: float = 1.15
const V12_SECTOR_SOFT_CAP: int = 2
const V12_INTENT_LOG_MSEC: int = 1600

var _v12_target_fruit_by_id: Dictionary = {}
var _v12_target_lock_until_by_id: Dictionary = {}
var _v12_intent_by_id: Dictionary = {}
var _v12_last_intent_log_msec: int = 0

func _ready() -> void:
	await super()
	for racer: WildDashCharacterController in ai_racers:
		if racer == null:
			continue
		var id: int = racer.get_instance_id()
		_v12_target_fruit_by_id[id] = -1
		_v12_target_lock_until_by_id[id] = 0
		_v12_intent_by_id[id] = V12_INTENT_COLLECT
	print("FRUIT FRENZY V12 READY fruit=30 distribution=GROUND_11 WATER_2 LOW_4 HIGH_6 TREE_7 vertical=13 orchard_gameplay_trees=6 ai_primary_intent=true reservation_ms=%d sectors=6" % V12_TARGET_LOCK_MSEC)

# -----------------------------------------------------------------------------
# 30-fruit pool and vertical anchors
# -----------------------------------------------------------------------------

func _create_fruits() -> void:
	for i: int in range(V12_FRUIT_COUNT):
		var fruit_type: StringName = _regular_type_for_index(i)
		var fruit: MeshInstance3D = _new_fruit_mesh("Fruit_%02d" % (i + 1), fruit_type)
		fruit.position = _fruit_position(i, 0)
		add_child(fruit)
		fruits.append(fruit)
		fruit_active.append(true)
		fruit_respawn.append(0.0)
		fruit_cycles.append(0)
		fruit_types.append(fruit_type)
		fruit_values.append(_fruit_value(fruit_type))

func _fruit_position(index: int, cycle: int) -> Vector3:
	if V12_WATER_INDICES.has(index):
		return V12_WATER_POSITIONS[V12_WATER_INDICES.find(index)]
	if V12_LOW_INDICES.has(index):
		return V12_LOW_POSITIONS[V12_LOW_INDICES.find(index)]
	if V12_HIGH_INDICES.has(index):
		return V12_HIGH_POSITIONS[V12_HIGH_INDICES.find(index)]
	if V12_TREE_INDICES.has(index):
		return V12_TREE_POSITIONS[V12_TREE_INDICES.find(index)]
	return super(index, cycle)

func _configure_vertical_fruit_metadata() -> void:
	for i: int in range(fruits.size()):
		var fruit: MeshInstance3D = fruits[i]
		if V12_TREE_INDICES.has(i):
			var tree_slot: int = V12_TREE_INDICES.find(i)
			var tree_index: int = mini(5, tree_slot)
			var tier: int = 1
			var required_climb: float = 7.4
			var required_agility: float = 7.4
			if tree_slot >= 2:
				tier = 2
				required_climb = 8.4
				required_agility = 8.0
			if tree_slot >= 5:
				tier = 4
				required_climb = 9.8
				required_agility = 9.5
			WildDashFruitAccessSystem.configure_fruit(fruit, WildDashFruitAccessSystem.FruitAccessType.TREE, required_climb, required_agility, tier)
			fruit.set_meta(&"wilddash_preferred_traits", [&"climb", &"agility"])
			fruit.set_meta(&"wilddash_tree_index", tree_index)
			fruit.set_meta(&"wilddash_vertical_anchor", true)
			if tree_slot >= 5:
				fruit.set_meta(&"wilddash_monkey_top_fruit", true)
				fruit.scale = Vector3.ONE * 1.20
		elif V12_HIGH_INDICES.has(i):
			var high_slot: int = V12_HIGH_INDICES.find(i)
			var required_agility: float = 8.0 + float(high_slot) * 0.25
			var required_climb: float = 5.8 + float(high_slot) * 0.35
			WildDashFruitAccessSystem.configure_fruit(fruit, WildDashFruitAccessSystem.FruitAccessType.HIGH_PLATFORM, required_climb, required_agility, 0)
			fruit.set_meta(&"wilddash_preferred_traits", [&"agility", &"climb"])
			fruit.set_meta(&"wilddash_vertical_anchor", true)
			fruit.scale = Vector3.ONE * 1.10
		elif V12_LOW_INDICES.has(i):
			WildDashFruitAccessSystem.configure_fruit(fruit, WildDashFruitAccessSystem.FruitAccessType.LOW_PLATFORM, 5.0, 5.8, 0)
		elif V12_WATER_INDICES.has(i):
			WildDashFruitAccessSystem.configure_fruit(fruit, WildDashFruitAccessSystem.FruitAccessType.WATER)
			fruit.set_meta(&"wilddash_preferred_traits", [&"swim"])
			fruit.set_meta(&"wilddash_river_fruit", true)
		else:
			WildDashFruitAccessSystem.configure_fruit(fruit, WildDashFruitAccessSystem.FruitAccessType.GROUND)

func _build_zone_world() -> void:
	super()
	_upgrade_tall_orchard_visuals()

func _build_vertical_collection_geometry() -> void:
	# Low-access props stay useful for heavy racers.
	create_box("V12LowMarketA", Vector3(8.8, 0.85, 9.0), Vector3(2.8, 1.7, 2.8), Color(0.50, 0.30, 0.14), true)
	create_box("V12LowMarketB", Vector3(19.6, 0.82, 18.2), Vector3(2.8, 1.6, 2.8), Color(0.52, 0.31, 0.14), true)
	create_box("V12LowHay", Vector3(-20.0, 0.82, 18.5), Vector3(3.0, 1.6, 2.5), Color(0.82, 0.66, 0.18), true)
	create_box("V12LowRiverRock", Vector3(10.2, 0.76, -13.8), Vector3(2.5, 1.5, 2.5), Color(0.34, 0.36, 0.34), true)

	for i: int in range(V12_HIGH_POSITIONS.size()):
		_build_high_platform_route(i, V12_HIGH_POSITIONS[i])

	for i: int in range(V12_TREE_CENTERS.size()):
		_build_gameplay_tree_branches(i, V12_TREE_CENTERS[i], V12_TREE_TOP_HEIGHTS[i])

func _build_high_platform_route(index: int, fruit_position: Vector3) -> void:
	var top_y: float = maxf(1.8, fruit_position.y - 0.72)
	var step_count: int = maxi(2, ceili(top_y / 0.82))
	for step: int in range(step_count):
		var ratio: float = float(step + 1) / float(step_count)
		var height: float = top_y * ratio
		var z_offset: float = (float(step_count - 1 - step) * 1.55)
		var center: Vector3 = Vector3(fruit_position.x, height * 0.5, fruit_position.z + z_offset)
		create_box(
			"V12HighRoute_%02d_Step_%02d" % [index, step],
			center,
			Vector3(3.0, height, 2.4),
			Color(0.43, 0.35, 0.18),
			true
		)

func _build_gameplay_tree_branches(index: int, center: Vector3, top_height: float) -> void:
	var low_y: float = top_height * 0.38
	var mid_y: float = top_height * 0.61
	var high_y: float = top_height * 0.82
	create_box("V12Tree_%02d_LowBranch" % index, center + Vector3(1.10, low_y, 0.0), Vector3(2.8, 0.30, 1.2), Color(0.36, 0.20, 0.08), true)
	create_box("V12Tree_%02d_MidBranch" % index, center + Vector3(-0.95, mid_y, 0.45), Vector3(2.6, 0.28, 1.1), Color(0.34, 0.18, 0.07), true)
	create_box("V12Tree_%02d_HighBranch" % index, center + Vector3(0.70, high_y, -0.25), Vector3(2.4, 0.26, 1.0), Color(0.32, 0.17, 0.065), true)
	create_box("V12Tree_%02d_LandingShelf" % index, center + Vector3(0.0, top_height - 0.42, 0.0), Vector3(2.1, 0.25, 1.7), Color(0.31, 0.16, 0.06), true)

func _upgrade_tall_orchard_visuals() -> void:
	for i: int in range(V12_TREE_CENTERS.size()):
		var old_crown: Node = get_node_or_null("OrchardTree_%02dCrown" % i)
		if old_crown is VisualInstance3D:
			(old_crown as VisualInstance3D).visible = false
		var center: Vector3 = V12_TREE_CENTERS[i]
		var top_height: float = V12_TREE_TOP_HEIGHTS[i]
		var trunk_height: float = top_height - 0.65
		create_box("V12TallTree_%02d_Trunk" % i, center + Vector3.UP * (trunk_height * 0.5), Vector3(1.10, trunk_height, 1.10), Color(0.31, 0.16, 0.07), true)
		var crown: MeshInstance3D = MeshInstance3D.new()
		crown.name = "V12TallTree_%02d_Crown" % i
		var crown_mesh: SphereMesh = SphereMesh.new()
		crown_mesh.radius = 2.15 + float(i) * 0.08
		crown_mesh.height = 3.2 + float(i) * 0.10
		crown_mesh.radial_segments = 8
		crown_mesh.rings = 5
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(0.18, 0.52, 0.15)
		material.roughness = 1.0
		crown_mesh.material = material
		crown.mesh = crown_mesh
		crown.position = center + Vector3.UP * (top_height + 0.45)
		add_child(crown)

# -----------------------------------------------------------------------------
# Tall-tree player and AI traversal
# -----------------------------------------------------------------------------

func _update_player_climb_assist() -> void:
	if player == null or not is_instance_valid(player) or _climb_assist_cooldown > 0.0:
		return
	if not Input.is_action_pressed(&"jump"):
		return
	var climb: float = WildDashAnimalAbilityProfile.get_stat(player.animal_id, &"climb")
	if climb < 6.5:
		return
	var max_height: float = _v12_max_climb_height(player.animal_id, climb)
	if player.global_position.y > max_height:
		return
	var nearest_distance: float = INF
	for center: Vector3 in V12_TREE_CENTERS:
		var planar: float = Vector2(player.global_position.x - center.x, player.global_position.z - center.z).length()
		nearest_distance = minf(nearest_distance, planar)
	if nearest_distance > 1.65:
		return
	var assist: float = 4.7 + clampf((climb - 6.5) * 0.62, 0.0, 2.2)
	if player.animal_id == &"monkey":
		assist += 1.15
	elif player.animal_id == &"cat":
		assist += 0.55
	player.velocity.y = maxf(player.velocity.y, assist)
	_climb_assist_cooldown = 0.23
	if player.is_player:
		hud.set_message("TREE CLIMB · %s · %.1fm MAX" % [player.get_display_name().to_upper(), max_height])

func _v12_max_climb_height(animal_id: StringName, climb: float) -> float:
	match animal_id:
		&"monkey": return 8.5
		&"cat": return 6.5
		&"raccoon": return 6.0
		_: return clampf(3.3 + maxf(0.0, climb - 6.0) * 0.65, 3.3, 5.8)

func _try_ai_vertical_assist(racer: WildDashCharacterController) -> void:
	if racer != null and racer.animal_id == &"monkey":
		var id: int = racer.get_instance_id()
		var target_index: int = int(_v12_target_fruit_by_id.get(id, -1))
		if target_index >= 0 and target_index < fruits.size() and fruit_active[target_index]:
			var fruit: MeshInstance3D = fruits[target_index]
			if WildDashFruitAccessSystem.get_access_type(fruit) == WildDashFruitAccessSystem.FruitAccessType.TREE:
				var tree_index: int = int(fruit.get_meta(&"wilddash_tree_index", -1))
				if tree_index >= 0 and tree_index < V12_TREE_CENTERS.size():
					var center: Vector3 = V12_TREE_CENTERS[tree_index]
					var planar_distance: float = Vector2(racer.global_position.x - center.x, racer.global_position.z - center.z).length()
					if planar_distance <= 1.9 and racer.global_position.y < fruit.global_position.y - 0.35:
						var toward: Vector3 = center - racer.global_position
						toward.y = 0.0
						if toward.length_squared() > 0.001:
							var planar_velocity: Vector3 = toward.normalized() * 1.35
							racer.velocity.x = planar_velocity.x
							racer.velocity.z = planar_velocity.z
						racer.velocity.y = maxf(racer.velocity.y, 7.2)
						_ai_vertical_assist_cooldown[id] = 0.22
						return
	super(racer)

func _build_round2_canopy_network() -> void:
	_canopy_visual_root = Node3D.new()
	_canopy_visual_root.name = "MonkeyCanopyNetworkV12"
	add_child(_canopy_visual_root)
	_canopy_routes.clear()
	var points: Array[Vector3] = [
		V12_TREE_CENTERS[0] + Vector3(0.0, 4.55, 0.0),
		V12_TREE_CENTERS[1] + Vector3(0.0, 5.00, 0.0),
		V12_TREE_CENTERS[2] + Vector3(0.0, 5.65, 0.0),
		V12_TREE_CENTERS[4] + Vector3(0.0, 6.65, 0.0),
		V12_TREE_CENTERS[5] + Vector3(0.0, 7.15, 0.0),
	]
	for i: int in range(points.size()):
		create_box("V12CanopyLanding_%02d" % i, points[i] - Vector3.UP * 0.22, Vector3(2.2, 0.26, 1.5), Color(0.34, 0.19, 0.07), true)
	for i: int in range(points.size() - 1):
		var route: WildDashCanopyVineRoute = WildDashCanopyVineRoute.new().configure(
			StringName("tall_orchard_vine_%02d" % i), points[i], points[i + 1],
			1.55 + float(i % 2) * 0.35, 10.8 + float(i) * 0.30, 4.45
		)
		_canopy_routes.append(route)
		_add_round2_vine_visual(route)
	_canopy.set_routes(_canopy_routes)

# -----------------------------------------------------------------------------
# One-pass collection-first AI intent planner
# -----------------------------------------------------------------------------

func _update_ai_decisions() -> void:
	var now_msec: int = Time.get_ticks_msec()
	var fruit_claims: Dictionary = {}
	var sector_counts: Dictionary = {}
	var carrier_claims: Dictionary = {}
	var golden_chasers: int = 0

	# Preserve valid locks before assigning new targets so one fruit remains one AI.
	for racer: WildDashCharacterController in ai_racers:
		if racer == null or racer.finished:
			continue
		var id: int = racer.get_instance_id()
		var locked_index: int = int(_v12_target_fruit_by_id.get(id, -1))
		var lock_until: int = int(_v12_target_lock_until_by_id.get(id, 0))
		if now_msec <= lock_until and _v12_fruit_target_valid(racer, locked_index):
			fruit_claims[locked_index] = id
			var sector: StringName = _v12_sector_for_fruit(locked_index)
			sector_counts[sector] = int(sector_counts.get(sector, 0)) + 1
		else:
			_v12_target_fruit_by_id[id] = -1

	for i: int in range(ai_racers.size()):
		if i >= ai_drivers.size():
			continue
		var racer: WildDashCharacterController = ai_racers[i]
		var driver: WildDashAIController = ai_drivers[i]
		if racer == null or driver == null or racer.finished:
			continue
		var id: int = racer.get_instance_id()
		var carry: int = _get_carry(racer)
		var personality: StringName = ai_personalities[i] if i < ai_personalities.size() else PERSONALITY_BALANCED

		if carry >= 4 or (personality == PERSONALITY_GATHERER and carry >= 3):
			_v12_set_intent(id, V12_INTENT_BANK)
			driver.set_arena_target(_bank_slot_target(i))
			continue

		if _golden_active and carry <= 2 and golden_chasers < 2 and _v12_should_chase_golden(personality, i):
			golden_chasers += 1
			_v12_set_intent(id, V12_INTENT_GOLDEN)
			driver.set_arena_target(_golden_fruit.global_position)
			continue

		var combat_range: float = V12_HUNTER_COMBAT_RANGE if racer.animal_id in [&"wolf", &"raccoon"] or personality == PERSONALITY_THIEF else V12_NORMAL_COMBAT_RANGE
		var victim: WildDashCharacterController = _v12_local_combat_target(racer, combat_range, carrier_claims)
		if victim != null:
			var victim_id: int = victim.get_instance_id()
			carrier_claims[victim_id] = int(carrier_claims.get(victim_id, 0)) + 1
			_v12_set_intent(id, V12_INTENT_COMBAT)
			driver.set_arena_target(victim.global_position)
			_try_ai_attack(racer, victim, personality)
			continue

		var target_index: int = int(_v12_target_fruit_by_id.get(id, -1))
		if not _v12_fruit_target_valid(racer, target_index):
			target_index = _v12_best_collect_target(racer, i, fruit_claims, sector_counts)
			if target_index >= 0:
				_v12_target_fruit_by_id[id] = target_index
				_v12_target_lock_until_by_id[id] = now_msec + V12_TARGET_LOCK_MSEC
				fruit_claims[target_index] = id
				var new_sector: StringName = _v12_sector_for_fruit(target_index)
				sector_counts[new_sector] = int(sector_counts.get(new_sector, 0)) + 1

		if target_index >= 0:
			var fruit: MeshInstance3D = fruits[target_index]
			var access_type: int = WildDashFruitAccessSystem.get_access_type(fruit)
			var intent: StringName = V12_INTENT_COLLECT
			if access_type == WildDashFruitAccessSystem.FruitAccessType.TREE:
				intent = V12_INTENT_CANOPY
			elif access_type == WildDashFruitAccessSystem.FruitAccessType.WATER:
				intent = V12_INTENT_WATER
			_v12_set_intent(id, intent)
			var target_position: Vector3 = _v12_apply_local_separation(racer, fruit.global_position)
			driver.set_arena_target(target_position)
		else:
			_v12_set_intent(id, V12_INTENT_COLLECT)
			driver.set_arena_target(_fallback_zone_target(i))

	if now_msec - _v12_last_intent_log_msec >= V12_INTENT_LOG_MSEC:
		_v12_last_intent_log_msec = now_msec
		_v12_log_intents(sector_counts)

func _v12_fruit_target_valid(racer: WildDashCharacterController, fruit_index: int) -> bool:
	if racer == null or fruit_index < 0 or fruit_index >= fruits.size():
		return false
	if not fruit_active[fruit_index] or not _can_carry_value(racer, fruit_values[fruit_index]):
		return false
	return WildDashFruitAccessSystem.can_racer_reach_fruit(racer, fruits[fruit_index])

func _v12_best_collect_target(racer: WildDashCharacterController, ai_index: int, claims: Dictionary, sector_counts: Dictionary) -> int:
	var best_index: int = -1
	var best_score: float = INF
	for fruit_index: int in range(fruits.size()):
		if claims.has(fruit_index) or not _v12_fruit_target_valid(racer, fruit_index):
			continue
		var fruit: MeshInstance3D = fruits[fruit_index]
		var access_type: int = WildDashFruitAccessSystem.get_access_type(fruit)
		var sector: StringName = _v12_sector_for_fruit(fruit_index)
		var score: float = racer.global_position.distance_squared_to(fruit.global_position)
		var occupancy: int = int(sector_counts.get(sector, 0))
		if occupancy >= V12_SECTOR_SOFT_CAP:
			score += 190.0 + float(occupancy - V12_SECTOR_SOFT_CAP) * 80.0
		score += _v12_species_access_bias(racer.animal_id, access_type)
		score += float((fruit_index * 7 + ai_index * 11) % 13) * 0.23
		if score < best_score:
			best_score = score
			best_index = fruit_index
	return best_index

func _v12_species_access_bias(animal_id: StringName, access_type: int) -> float:
	match animal_id:
		&"monkey":
			if access_type == WildDashFruitAccessSystem.FruitAccessType.TREE: return -150.0
			if access_type == WildDashFruitAccessSystem.FruitAccessType.HIGH_PLATFORM: return -55.0
		&"rabbit", &"deer":
			if access_type == WildDashFruitAccessSystem.FruitAccessType.HIGH_PLATFORM: return -105.0
		&"cat":
			if access_type == WildDashFruitAccessSystem.FruitAccessType.TREE: return -90.0
			if access_type == WildDashFruitAccessSystem.FruitAccessType.HIGH_PLATFORM: return -75.0
		&"crocodile":
			if access_type == WildDashFruitAccessSystem.FruitAccessType.WATER: return -150.0
		&"raccoon":
			if access_type == WildDashFruitAccessSystem.FruitAccessType.WATER: return -65.0
			if access_type == WildDashFruitAccessSystem.FruitAccessType.LOW_PLATFORM: return -45.0
		&"bear":
			if access_type == WildDashFruitAccessSystem.FruitAccessType.WATER: return -55.0
		&"elephant", &"boar":
			if access_type == WildDashFruitAccessSystem.FruitAccessType.GROUND: return -60.0
			if access_type == WildDashFruitAccessSystem.FruitAccessType.LOW_PLATFORM: return -35.0
		&"fox":
			if access_type == WildDashFruitAccessSystem.FruitAccessType.HIGH_PLATFORM: return -65.0
			if access_type == WildDashFruitAccessSystem.FruitAccessType.LOW_PLATFORM: return -45.0
		&"dog", &"wolf":
			if access_type == WildDashFruitAccessSystem.FruitAccessType.GROUND: return -35.0
			if access_type == WildDashFruitAccessSystem.FruitAccessType.LOW_PLATFORM: return -20.0
	return 0.0

func _v12_local_combat_target(source: WildDashCharacterController, max_range: float, claims: Dictionary) -> WildDashCharacterController:
	var best: WildDashCharacterController
	var best_score: float = -INF
	var max_range_sq: float = max_range * max_range
	for target: WildDashCharacterController in racers:
		if target == null or target == source or target.finished:
			continue
		var carry: int = _get_carry(target)
		if carry <= 0:
			continue
		var target_id: int = target.get_instance_id()
		var allowed_chasers: int = 2 if carry >= 4 else 1
		if int(claims.get(target_id, 0)) >= allowed_chasers:
			continue
		var distance_sq: float = source.global_position.distance_squared_to(target.global_position)
		if distance_sq > max_range_sq:
			continue
		var score: float = float(carry) * 8.0 - sqrt(distance_sq) * 2.0
		if source.animal_id in [&"wolf", &"raccoon"]:
			score += 5.0
		if score > best_score:
			best_score = score
			best = target
	return best

func _v12_apply_local_separation(racer: WildDashCharacterController, target: Vector3) -> Vector3:
	var separation: Vector3 = Vector3.ZERO
	for other: WildDashCharacterController in ai_racers:
		if other == null or other == racer or other.finished:
			continue
		var delta: Vector3 = racer.global_position - other.global_position
		delta.y = 0.0
		var distance: float = delta.length()
		if distance <= 0.01 or distance >= V12_SEPARATION_RADIUS:
			continue
		separation += delta.normalized() * (1.0 - distance / V12_SEPARATION_RADIUS)
	if separation.length_squared() <= 0.001:
		return target
	return target + separation.normalized() * V12_SEPARATION_STRENGTH

func _v12_sector_for_fruit(fruit_index: int) -> StringName:
	if fruit_index < 0 or fruit_index >= fruits.size():
		return &"CENTER_PERIMETER"
	var fruit: MeshInstance3D = fruits[fruit_index]
	var access_type: int = WildDashFruitAccessSystem.get_access_type(fruit)
	if access_type == WildDashFruitAccessSystem.FruitAccessType.TREE:
		return &"ORCHARD_CANOPY"
	if access_type == WildDashFruitAccessSystem.FruitAccessType.WATER:
		return &"RIVER"
	var p: Vector3 = fruit.global_position
	if p.x < -5.0 and p.z < -5.0:
		return &"ORCHARD_GROUND"
	if p.x > 5.0 and p.z < -5.0:
		return &"RIVER"
	if p.x > 5.0 and p.z > 5.0:
		return &"MARKET"
	if p.x < -5.0 and p.z > 5.0:
		return &"HILL"
	return &"CENTER_PERIMETER"

func _v12_should_chase_golden(personality: StringName, ai_index: int) -> bool:
	if personality == PERSONALITY_OPPORTUNIST:
		return true
	if personality == PERSONALITY_BALANCED:
		return ai_index % 2 == 0
	return false

func _v12_set_intent(id: int, intent: StringName) -> void:
	_v12_intent_by_id[id] = intent

func _v12_log_intents(sector_counts: Dictionary) -> void:
	var destinations: Dictionary = {}
	for racer: WildDashCharacterController in ai_racers:
		if racer == null:
			continue
		var id: int = racer.get_instance_id()
		var intent: StringName = StringName(_v12_intent_by_id.get(id, V12_INTENT_COLLECT))
		destinations[intent] = int(destinations.get(intent, 0)) + 1
	print("ROUND2 AI INTENT SUMMARY intents=%s sectors=%s collection_first=true combat_local=true reservation_one_per_fruit=true" % [str(destinations), str(sector_counts)])

func _phase3_nearest_tree_fruit(racer: WildDashCharacterController) -> MeshInstance3D:
	if racer != null:
		var index: int = int(_v12_target_fruit_by_id.get(racer.get_instance_id(), -1))
		if index >= 0 and index < fruits.size() and fruit_active[index]:
			var locked: MeshInstance3D = fruits[index]
			if WildDashFruitAccessSystem.get_access_type(locked) == WildDashFruitAccessSystem.FruitAccessType.TREE:
				return locked
	return super(racer)
