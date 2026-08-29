extends WildDashModeController

## ROUND 2 — FRUIT FRENZY: HARVEST HEIST
##
## Core loop:
## COLLECT -> CARRY -> FIGHT -> SPILL -> STEAL -> BANK
##
## This mode is intentionally self-contained. Grand Prix / RaceManager / shared
## race camera and terrain systems are not touched by this implementation.

const ROUND_DURATION: float = 90.0
const ARENA_SIZE: float = 52.0
const FRUIT_COUNT: int = 24
const MAX_CARRY: int = 5
const SPILL_POOL_SIZE: int = 30
const PICKUP_INTERVAL: float = 0.10
const AI_DECISION_INTERVAL: float = 0.16
const BANK_RADIUS: float = 3.15
const FRUIT_PICKUP_RADIUS: float = 1.20
const SPILL_LIFETIME: float = 8.0
const CART_DWELL_SECONDS: float = 20.0
const CART_MOVE_SECONDS: float = 2.4
const GOLDEN_EVENT_INTERVAL: float = 21.0
const GOLDEN_COUNTDOWN_SECONDS: float = 3.0
const GOLDEN_LIFETIME: float = 12.0
const GOLDEN_HARVEST_SECONDS: float = 20.0
const PLAYER_BODY_CHECK_COOLDOWN: float = 1.65
const AI_ATTACK_COOLDOWN: float = 1.90
const COMBAT_SPILL_COOLDOWN: float = 0.55
const WILD_BOOST_SECONDS: float = 3.5
const WILD_BOOST_MULTIPLIER: float = 1.08
const KNOCKBACK_SPILL_THRESHOLD: float = 2.1
const KNOCKBACK_STRONG_THRESHOLD: float = 6.4

const FRUIT_APPLE: StringName = &"apple"
const FRUIT_BANANA: StringName = &"banana"
const FRUIT_BERRY: StringName = &"berry"
const FRUIT_WILD: StringName = &"wild"
const FRUIT_GOLDEN: StringName = &"golden"

const PERSONALITY_GATHERER: StringName = &"gatherer"
const PERSONALITY_THIEF: StringName = &"thief"
const PERSONALITY_OPPORTUNIST: StringName = &"opportunist"
const PERSONALITY_BALANCED: StringName = &"balanced"

var fruits: Array[MeshInstance3D] = []
var fruit_active: Array[bool] = []
var fruit_respawn: Array[float] = []
var fruit_cycles: Array[int] = []
var fruit_types: Array[StringName] = []
var fruit_values: Array[int] = []

var spill_fruits: Array[MeshInstance3D] = []
var spill_active: Array[bool] = []
var spill_expiry: Array[float] = []
var spill_types: Array[StringName] = []
var spill_values: Array[int] = []

var carried_by_id: Dictionary = {}
var banked_by_id: Dictionary = {}
var base_arena_speed_by_id: Dictionary = {}
var wild_boost_by_id: Dictionary = {}
var last_knockback_by_id: Dictionary = {}
var spill_hit_cooldown_by_id: Dictionary = {}
var ai_attack_cooldown_by_id: Dictionary = {}

var ai_personalities: Array[StringName] = []
var ai_base_target_speeds: Array[float] = []
var ai_scores: Array[int] = []
var player_score: int = 0

var _pickup_elapsed: float = 0.0
var _ai_decision_elapsed: float = 0.0
var _player_body_check_cooldown: float = 0.0

var _cart_root: Node3D
var _cart_beacon: MeshInstance3D
var _cart_stop_index: int = 0
var _cart_dwell_elapsed: float = 0.0
var _cart_moving: bool = false
var _cart_move_elapsed: float = 0.0
var _cart_move_from: Vector3 = Vector3.ZERO
var _cart_move_to: Vector3 = Vector3.ZERO
var _cart_destination_name: String = "MARKET"

var _golden_fruit: MeshInstance3D
var _golden_beacon: MeshInstance3D
var _golden_active: bool = false
var _golden_age: float = 0.0
var _golden_event_timer: float = GOLDEN_EVENT_INTERVAL
var _golden_countdown_last: int = -1
var _golden_event_index: int = 0

var _golden_harvest_active: bool = false
var _golden_harvest_light: OmniLight3D

var _camera: Camera3D
var _camera_shake_remaining: float = 0.0
var _event_layer: CanvasLayer
var _event_label: Label
var _event_label_remaining: float = 0.0
var _direct_bootstrap: bool = false

func _ready() -> void:
	_bootstrap_round_context_if_needed()
	setup_mode(
		&"fruit_collection",
		"ROUND 2 — FRUIT FRENZY: HARVEST HEIST",
		"COLLECT → CARRY → BANK · F/Y BODY CHECK · E/X SKILL",
		false
	)
	create_rect_arena(ARENA_SIZE, ARENA_SIZE, true)
	_build_zone_world()
	_build_event_hud()
	_build_camera()
	_spawn_field()
	_create_fruits()
	_create_spill_pool()
	_create_harvest_cart()
	_create_golden_fruit()
	await get_tree().physics_frame
	await get_tree().physics_frame
	begin_mode(ROUND_DURATION, 6.0)
	print("FRUIT FRENZY V1 READY duration=%.0fs arena=%.0fx%.0f fruit=%d carry=%d spill_pool=%d ai=%d direct_bootstrap=%s" % [
		ROUND_DURATION,
		ARENA_SIZE,
		ARENA_SIZE,
		FRUIT_COUNT,
		MAX_CARRY,
		SPILL_POOL_SIZE,
		ai_racers.size(),
		str(_direct_bootstrap),
	])

func _physics_process(delta: float) -> void:
	if mode_finished or not GameManager.round_active:
		return

	time_remaining = maxf(0.0, time_remaining - delta)
	_player_body_check_cooldown = maxf(0.0, _player_body_check_cooldown - delta)
	_update_runtime_cooldowns(delta)
	_update_fruits(delta)
	_update_spill_fruits(delta)
	_update_harvest_cart(delta)
	_update_golden_event(delta)
	_update_golden_harvest()
	_update_speed_profiles()
	_detect_combat_spills()

	if InputManager.consume_race_bump():
		_try_player_body_check()

	_pickup_elapsed += delta
	if _pickup_elapsed >= PICKUP_INTERVAL:
		_pickup_elapsed = fmod(_pickup_elapsed, PICKUP_INTERVAL)
		_process_pickups_and_banking()

	_ai_decision_elapsed += delta
	if _ai_decision_elapsed >= AI_DECISION_INTERVAL:
		_ai_decision_elapsed = fmod(_ai_decision_elapsed, AI_DECISION_INTERVAL)
		_update_ai_decisions()

	_update_hud()
	if time_remaining <= 0.0:
		_finish_time_score_round()

func _process(delta: float) -> void:
	_update_camera(delta)
	_update_event_label(delta)
	_animate_pickups()

# -----------------------------------------------------------------------------
# Round lifecycle / direct-scene testing
# -----------------------------------------------------------------------------

func _bootstrap_round_context_if_needed() -> void:
	if GameManager.current_round_index >= 0:
		return
	var index: int = GameManager.ROUND_IDS.find(&"fruit_collection")
	if index < 0:
		push_error("FRUIT FRENZY: fruit_collection missing from ROUND_IDS")
		return
	ResultManager.reset_campaign()
	GameManager.current_round_index = index
	GameManager.campaign_running = true
	_direct_bootstrap = true
	print("FRUIT FRENZY DIRECT BOOTSTRAP round_index=%d" % [index + 1])

# -----------------------------------------------------------------------------
# Arena / zones
# -----------------------------------------------------------------------------

func _build_zone_world() -> void:
	_create_zone_pad("OrchardPad", _zone_anchor(0), Color(0.20, 0.34, 0.16), "ORCHARD")
	_create_zone_pad("RiverPad", _zone_anchor(1), Color(0.10, 0.30, 0.40), "RIVER BANK")
	_create_zone_pad("MarketPad", _zone_anchor(2), Color(0.34, 0.25, 0.16), "MARKET")
	_create_zone_pad("HillPad", _zone_anchor(3), Color(0.34, 0.31, 0.14), "HILL FARM")

	# ORCHARD: readable tree columns, fruit-rich but slightly obstructed.
	for i in range(6):
		var row: int = i / 3
		var col: int = i % 3
		var p := Vector3(-20.0 + float(col) * 5.0, 0.0, -19.0 + float(row) * 8.0)
		_make_tree("OrchardTree_%02d" % i, p)

	# RIVER BANK: visible shallow-water strip and simple stepping rocks.
	create_box("RiverWater", Vector3(14.0, 0.04, -14.0), Vector3(18.0, 0.08, 6.0), Color(0.08, 0.52, 0.70), false)
	for i in range(6):
		var rock_x: float = 8.0 + float(i) * 2.4
		var rock_z: float = -14.0 + (-1.0 if i % 2 == 0 else 1.0) * 1.1
		create_box("RiverRock_%02d" % i, Vector3(rock_x, 0.28, rock_z), Vector3(1.4, 0.55, 1.4), Color(0.33, 0.35, 0.34), true)

	# MARKET: bank-friendly open zone with low crates around the perimeter.
	var crate_positions: Array[Vector3] = [
		Vector3(8.0, 0.5, 9.0), Vector3(20.0, 0.5, 10.0),
		Vector3(9.0, 0.5, 20.0), Vector3(20.0, 0.5, 19.0),
	]
	for i in range(crate_positions.size()):
		create_box("MarketCrate_%02d" % i, crate_positions[i], Vector3(2.0, 1.0, 2.0), Color(0.48, 0.29, 0.13), true)

	# HILL FARM: low hay obstacles and one broad jumpable ridge.
	for i in range(5):
		var hay_pos := Vector3(-20.0 + float(i) * 3.7, 0.45, 17.0 + float(i % 2) * 3.0)
		create_box("Hay_%02d" % i, hay_pos, Vector3(2.0, 0.9, 1.4), Color(0.82, 0.66, 0.18), true)
	var ridge := create_box("HillJumpRidge", Vector3(-14.0, 0.34, 10.0), Vector3(8.0, 0.65, 3.2), Color(0.38, 0.31, 0.16), true)
	ridge.rotation_degrees.x = -7.0

	# Central landmark for Golden Harvest.
	_make_tree("GoldenHarvestTree", Vector3.ZERO, 1.35, Color(0.95, 0.72, 0.12))
	print("FRUIT FRENZY ARENA READY size=52 zones=4 routes_readable=true dynamic_platforms=0")

func _create_zone_pad(node_name: String, center: Vector3, color: Color, title: String) -> void:
	create_box(node_name, center + Vector3(0.0, 0.015, 0.0), Vector3(22.0, 0.03, 22.0), color, false)
	var label := Label3D.new()
	label.name = "%sLabel" % node_name
	label.text = title
	label.position = center + Vector3(0.0, 0.9, 0.0)
	label.font_size = 54
	label.outline_size = 10
	label.modulate = Color(1.0, 1.0, 1.0, 0.88)
	add_child(label)

func _make_tree(node_name: String, position: Vector3, scale_factor: float = 1.0, crown_color: Color = Color(0.20, 0.60, 0.18)) -> void:
	create_box("%sTrunk" % node_name, position + Vector3(0.0, 1.0 * scale_factor, 0.0), Vector3(0.8, 2.0 * scale_factor, 0.8), Color(0.31, 0.16, 0.07), true)
	var crown := MeshInstance3D.new()
	crown.name = "%sCrown" % node_name
	var mesh := SphereMesh.new()
	mesh.radius = 2.0 * scale_factor
	mesh.height = 4.0 * scale_factor
	var material := StandardMaterial3D.new()
	material.albedo_color = crown_color
	material.roughness = 1.0
	mesh.material = material
	crown.mesh = mesh
	crown.position = position + Vector3(0.0, 3.3 * scale_factor, 0.0)
	add_child(crown)

func _zone_anchor(index: int) -> Vector3:
	match index % 4:
		0: return Vector3(-14.0, 0.0, -14.0)
		1: return Vector3(14.0, 0.0, -14.0)
		2: return Vector3(14.0, 0.0, 14.0)
		_: return Vector3(-14.0, 0.0, 14.0)

# -----------------------------------------------------------------------------
# Racer field / carry state
# -----------------------------------------------------------------------------

func _spawn_field() -> void:
	player = spawn_racer("Player", &"dog", Vector3(0.0, 0.15, 19.0), true, WildDashCharacterController.MovementMode.ARENA)
	_register_racer_state(player)

	var animals: Array[StringName] = [&"rabbit", &"elephant", &"cat", &"dog"]
	var total_ai: int = GameManager.ai_count
	for i in range(total_ai):
		var angle: float = TAU * float(i) / maxf(1.0, float(total_ai))
		var radius: float = 10.0 + float(i % 3) * 3.4
		var spawn := Vector3(cos(angle) * radius, 0.15, sin(angle) * radius)
		var racer := spawn_racer(
			"AI_%02d" % (i + 1),
			animals[i % animals.size()],
			spawn,
			false,
			WildDashCharacterController.MovementMode.ARENA
		)
		var base_target_speed: float = 7.0 + float(i % 4) * 0.22
		spawn_ai_driver(racer, WildDashAIController.AIMode.ARENA, base_target_speed)
		_register_racer_state(racer)
		ai_personalities.append(_personality_for_ai(i))
		ai_base_target_speeds.append(base_target_speed)

	ai_scores.resize(ai_racers.size())
	for i in range(ai_scores.size()):
		ai_scores[i] = 0
	print("FRUIT FRENZY FIELD total=%d ai=%d personalities=%s" % [
		racers.size(),
		ai_racers.size(),
		_personality_summary(),
	])

func _register_racer_state(racer: WildDashCharacterController) -> void:
	if racer == null:
		return
	var key: int = racer.get_instance_id()
	carried_by_id[key] = 0
	banked_by_id[key] = 0
	base_arena_speed_by_id[key] = racer.arena_move_speed
	wild_boost_by_id[key] = 0.0
	last_knockback_by_id[key] = 0.0
	spill_hit_cooldown_by_id[key] = 0.0
	ai_attack_cooldown_by_id[key] = 0.0

func _personality_for_ai(index: int) -> StringName:
	match index % 4:
		0: return PERSONALITY_GATHERER
		1: return PERSONALITY_THIEF
		2: return PERSONALITY_OPPORTUNIST
		_: return PERSONALITY_BALANCED

func _personality_summary() -> String:
	var gatherer := 0
	var thief := 0
	var opportunist := 0
	var balanced := 0
	for personality: StringName in ai_personalities:
		match personality:
			PERSONALITY_GATHERER: gatherer += 1
			PERSONALITY_THIEF: thief += 1
			PERSONALITY_OPPORTUNIST: opportunist += 1
			_: balanced += 1
	return "G%d/T%d/O%d/B%d" % [gatherer, thief, opportunist, balanced]

# -----------------------------------------------------------------------------
# Fruit pool / types
# -----------------------------------------------------------------------------

func _create_fruits() -> void:
	for i in range(FRUIT_COUNT):
		var fruit_type: StringName = _regular_type_for_index(i)
		var fruit := _new_fruit_mesh("Fruit_%02d" % (i + 1), fruit_type)
		fruit.position = _fruit_position(i, 0)
		add_child(fruit)
		fruits.append(fruit)
		fruit_active.append(true)
		fruit_respawn.append(0.0)
		fruit_cycles.append(0)
		fruit_types.append(fruit_type)
		fruit_values.append(_fruit_value(fruit_type))

func _create_spill_pool() -> void:
	for i in range(SPILL_POOL_SIZE):
		var node := _new_fruit_mesh("SpillFruit_%02d" % (i + 1), FRUIT_APPLE)
		node.visible = false
		add_child(node)
		spill_fruits.append(node)
		spill_active.append(false)
		spill_expiry.append(0.0)
		spill_types.append(FRUIT_APPLE)
		spill_values.append(1)

func _create_golden_fruit() -> void:
	_golden_fruit = _new_fruit_mesh("GoldenFruit", FRUIT_GOLDEN)
	_golden_fruit.visible = false
	add_child(_golden_fruit)

	_golden_beacon = MeshInstance3D.new()
	_golden_beacon.name = "GoldenFruitBeacon"
	var beacon_mesh := CylinderMesh.new()
	beacon_mesh.top_radius = 0.16
	beacon_mesh.bottom_radius = 0.32
	beacon_mesh.height = 7.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.80, 0.10, 0.30)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0, 0.65, 0.05) * 1.5
	beacon_mesh.material = material
	_golden_beacon.mesh = beacon_mesh
	_golden_beacon.visible = false
	add_child(_golden_beacon)

func _new_fruit_mesh(node_name: String, fruit_type: StringName) -> MeshInstance3D:
	var fruit := MeshInstance3D.new()
	fruit.name = node_name
	_configure_fruit_visual(fruit, fruit_type)
	return fruit

func _configure_fruit_visual(fruit: MeshInstance3D, fruit_type: StringName) -> void:
	var mesh: PrimitiveMesh
	var color := Color(0.95, 0.18, 0.16)
	var emission_strength := 0.18
	match fruit_type:
		FRUIT_BANANA:
			var capsule := CapsuleMesh.new()
			capsule.radius = 0.28
			capsule.height = 1.10
			mesh = capsule
			color = Color(1.0, 0.82, 0.10)
		FRUIT_BERRY:
			var sphere := SphereMesh.new()
			sphere.radius = 0.34
			sphere.height = 0.68
			mesh = sphere
			color = Color(0.55, 0.20, 0.84)
		FRUIT_WILD:
			var box := BoxMesh.new()
			box.size = Vector3(0.78, 0.78, 0.78)
			mesh = box
			color = Color(0.10, 0.90, 0.38)
			emission_strength = 0.80
		FRUIT_GOLDEN:
			var golden := SphereMesh.new()
			golden.radius = 0.62
			golden.height = 1.24
			mesh = golden
			color = Color(1.0, 0.68, 0.04)
			emission_strength = 1.80
		_:
			var apple := SphereMesh.new()
			apple.radius = 0.43
			apple.height = 0.86
			mesh = apple
			color = Color(0.96, 0.20, 0.18)

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.48
	material.emission_enabled = true
	material.emission = color * emission_strength
	mesh.material = material
	fruit.mesh = mesh

func _regular_type_for_index(index: int) -> StringName:
	if index % 9 == 7:
		return FRUIT_WILD
	match index % 3:
		0: return FRUIT_APPLE
		1: return FRUIT_BANANA
		_: return FRUIT_BERRY

func _fruit_value(fruit_type: StringName) -> int:
	match fruit_type:
		FRUIT_WILD: return 2
		FRUIT_GOLDEN: return 3
		_: return 1

func _fruit_position(index: int, cycle: int) -> Vector3:
	var zone_index: int = index % 4
	var anchor := _zone_anchor(zone_index)
	var slot: int = index / 4
	var x_offset: float = -7.2 + float((slot * 5 + cycle * 3) % 7) * 2.35
	var z_offset: float = -6.0 + float((slot * 3 + cycle * 4) % 6) * 2.35
	return anchor + Vector3(x_offset, 0.78, z_offset)

func _update_fruits(delta: float) -> void:
	for i in range(fruits.size()):
		if fruit_active[i]:
			continue
		fruit_respawn[i] -= delta
		if fruit_respawn[i] > 0.0:
			continue
		fruit_cycles[i] += 1
		fruit_active[i] = true
		fruits[i].visible = true
		fruits[i].position = _fruit_position(i, fruit_cycles[i])

func _update_spill_fruits(delta: float) -> void:
	for i in range(spill_fruits.size()):
		if not spill_active[i]:
			continue
		spill_expiry[i] -= delta
		if spill_expiry[i] <= 0.0:
			spill_active[i] = false
			spill_fruits[i].visible = false

# -----------------------------------------------------------------------------
# Pickup / carry / banking
# -----------------------------------------------------------------------------

func _process_pickups_and_banking() -> void:
	for racer: WildDashCharacterController in racers:
		if racer == null or racer.finished:
			continue
		_try_pickup_regular_fruit(racer)
		_try_pickup_spill_fruit(racer)
		_try_pickup_golden_fruit(racer)
		_try_bank_racer(racer)

func _try_pickup_regular_fruit(racer: WildDashCharacterController) -> void:
	var radius: float = racer.get_interaction_radius(FRUIT_PICKUP_RADIUS)
	var radius_sq := radius * radius
	for i in range(fruits.size()):
		if not fruit_active[i]:
			continue
		if racer.global_position.distance_squared_to(fruits[i].global_position) > radius_sq:
			continue
		if not _can_carry_value(racer, fruit_values[i]):
			if racer.is_player:
				hud.set_message("BAG FULL · BANK BEFORE PICKING %s" % String(fruit_types[i]).to_upper())
			return
		_collect_regular_fruit(racer, i)
		return

func _collect_regular_fruit(racer: WildDashCharacterController, index: int) -> void:
	fruit_active[index] = false
	fruit_respawn[index] = 2.4
	fruits[index].visible = false
	_add_carry(racer, fruit_values[index])
	if fruit_types[index] == FRUIT_WILD:
		wild_boost_by_id[racer.get_instance_id()] = WILD_BOOST_SECONDS
	AudioManager.play_sfx_id("item", 0.78)
	if racer.is_player:
		var bonus := " · WILD SPEED!" if fruit_types[index] == FRUIT_WILD else ""
		hud.set_message("%s +%d · CARRY %d/%d%s" % [
			String(fruit_types[index]).to_upper(),
			fruit_values[index],
			_get_carry(racer),
			MAX_CARRY,
			bonus,
		])

func _try_pickup_spill_fruit(racer: WildDashCharacterController) -> void:
	var radius: float = racer.get_interaction_radius(FRUIT_PICKUP_RADIUS)
	var radius_sq := radius * radius
	for i in range(spill_fruits.size()):
		if not spill_active[i]:
			continue
		if racer.global_position.distance_squared_to(spill_fruits[i].global_position) > radius_sq:
			continue
		if not _can_carry_value(racer, spill_values[i]):
			return
		spill_active[i] = false
		spill_fruits[i].visible = false
		_add_carry(racer, spill_values[i])
		AudioManager.play_sfx_id("item", 0.72)
		if racer.is_player:
			hud.set_message("STOLEN FRUIT +%d · CARRY %d/%d" % [spill_values[i], _get_carry(racer), MAX_CARRY])
		return

func _try_pickup_golden_fruit(racer: WildDashCharacterController) -> void:
	if not _golden_active:
		return
	var radius: float = racer.get_interaction_radius(1.55)
	if racer.global_position.distance_squared_to(_golden_fruit.global_position) > radius * radius:
		return
	if not _can_carry_value(racer, 3):
		if racer.is_player:
			hud.set_message("GOLDEN FRUIT NEEDS 3 FREE CARRY SLOTS!")
		return
	_add_carry(racer, 3)
	_golden_active = false
	_golden_fruit.visible = false
	_golden_beacon.visible = false
	_golden_event_timer = GOLDEN_EVENT_INTERVAL
	_golden_countdown_last = -1
	AudioManager.play_sfx_id("skill", 1.0)
	_show_event("GOLDEN FRUIT CLAIMED · +3", 1.5)
	print("FRUIT FRENZY GOLDEN CLAIM racer=%s carry=%d" % [racer.name, _get_carry(racer)])

func _try_bank_racer(racer: WildDashCharacterController) -> void:
	if _cart_root == null or _get_carry(racer) <= 0:
		return
	var planar_racer := Vector2(racer.global_position.x, racer.global_position.z)
	var planar_cart := Vector2(_cart_root.global_position.x, _cart_root.global_position.z)
	if planar_racer.distance_squared_to(planar_cart) > BANK_RADIUS * BANK_RADIUS:
		return
	_bank_racer(racer)

func _bank_racer(racer: WildDashCharacterController) -> void:
	var carry: int = _get_carry(racer)
	if carry <= 0:
		return
	var multiplier: int = 2 if _golden_harvest_active else 1
	var bank_value: int = carry * multiplier
	var key: int = racer.get_instance_id()
	banked_by_id[key] = _get_banked(racer) + bank_value
	carried_by_id[key] = 0
	if racer == player:
		player_score = _get_banked(racer)
	var ai_index: int = ai_racers.find(racer)
	if ai_index >= 0 and ai_index < ai_scores.size():
		ai_scores[ai_index] = _get_banked(racer)
	AudioManager.play_sfx_id("ui", 0.95)
	if racer.is_player:
		_show_event("BANK +%d%s" % [bank_value, " · GOLDEN x2" if multiplier == 2 else ""], 1.1)
		hud.set_message("SAFE! BANKED SCORE %d" % _get_banked(racer))
	print("FRUIT FRENZY BANK racer=%s carry=%d multiplier=%d banked=%d" % [
		racer.name, carry, multiplier, _get_banked(racer),
	])

func _can_carry_value(racer: WildDashCharacterController, value: int) -> bool:
	return _get_carry(racer) + value <= MAX_CARRY

func _add_carry(racer: WildDashCharacterController, value: int) -> void:
	var key: int = racer.get_instance_id()
	carried_by_id[key] = clampi(_get_carry(racer) + value, 0, MAX_CARRY)

func _get_carry(racer: WildDashCharacterController) -> int:
	if racer == null:
		return 0
	return int(carried_by_id.get(racer.get_instance_id(), 0))

func _get_banked(racer: WildDashCharacterController) -> int:
	if racer == null:
		return 0
	return int(banked_by_id.get(racer.get_instance_id(), 0))

# -----------------------------------------------------------------------------
# Risk / reward movement
# -----------------------------------------------------------------------------

func _update_runtime_cooldowns(delta: float) -> void:
	for racer: WildDashCharacterController in racers:
		if racer == null:
			continue
		var key: int = racer.get_instance_id()
		wild_boost_by_id[key] = maxf(0.0, float(wild_boost_by_id.get(key, 0.0)) - delta)
		spill_hit_cooldown_by_id[key] = maxf(0.0, float(spill_hit_cooldown_by_id.get(key, 0.0)) - delta)
		ai_attack_cooldown_by_id[key] = maxf(0.0, float(ai_attack_cooldown_by_id.get(key, 0.0)) - delta)

func _update_speed_profiles() -> void:
	for racer: WildDashCharacterController in racers:
		if racer == null:
			continue
		var key: int = racer.get_instance_id()
		var base_speed: float = float(base_arena_speed_by_id.get(key, racer.arena_move_speed))
		var carry_multiplier: float = _carry_speed_multiplier(_get_carry(racer))
		var zone_multiplier: float = _zone_speed_multiplier(racer.global_position)
		var wild_multiplier: float = WILD_BOOST_MULTIPLIER if float(wild_boost_by_id.get(key, 0.0)) > 0.0 else 1.0
		racer.arena_move_speed = base_speed * carry_multiplier * zone_multiplier * wild_multiplier

	for i in range(ai_drivers.size()):
		if i >= ai_racers.size() or i >= ai_base_target_speeds.size():
			continue
		var racer: WildDashCharacterController = ai_racers[i]
		var key: int = racer.get_instance_id()
		var carry_multiplier: float = _carry_speed_multiplier(_get_carry(racer))
		var zone_multiplier: float = _zone_speed_multiplier(racer.global_position)
		var wild_multiplier: float = WILD_BOOST_MULTIPLIER if float(wild_boost_by_id.get(key, 0.0)) > 0.0 else 1.0
		ai_drivers[i].target_speed = ai_base_target_speeds[i] * carry_multiplier * zone_multiplier * wild_multiplier

func _carry_speed_multiplier(carry: int) -> float:
	if carry >= 5:
		return 0.92
	if carry >= 3:
		return 0.96
	return 1.0

func _zone_speed_multiplier(position: Vector3) -> float:
	# River water itself is slower, while the stepping-rock line remains fast.
	if position.x >= 5.0 and position.z <= -8.0 and position.z >= -20.0:
		return 0.91
	return 1.0

# -----------------------------------------------------------------------------
# Combat / spill / stealing
# -----------------------------------------------------------------------------

func _try_player_body_check() -> void:
	if player == null or _player_body_check_cooldown > 0.0:
		return
	var target := _find_body_check_target(player)
	if target == null:
		hud.set_message("BODY CHECK · NO TARGET")
		return
	var offset := target.global_position - player.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return
	var impulse: float = WildDashRacingActionController.calculate_body_check_impulse(player.animal_id, target.animal_id)
	target.apply_knockback(offset.normalized(), impulse)
	_player_body_check_cooldown = PLAYER_BODY_CHECK_COOLDOWN
	var spill_amount: int = 2 if impulse >= 6.4 else 1
	_spill_racer(target, spill_amount, "PLAYER BODY CHECK")
	spill_hit_cooldown_by_id[target.get_instance_id()] = COMBAT_SPILL_COOLDOWN
	AudioManager.play_sfx_id("hit", 0.95)
	hud.set_message("BODY CHECK! %s DROPPED FRUIT" % target.get_display_name().to_upper())

func _find_body_check_target(attacker: WildDashCharacterController) -> WildDashCharacterController:
	var best: WildDashCharacterController = null
	var best_distance: float = 3.1 * 3.1
	var forward := -attacker.global_transform.basis.z.normalized()
	for candidate: WildDashCharacterController in racers:
		if candidate == null or candidate == attacker or candidate.finished:
			continue
		var offset := candidate.global_position - attacker.global_position
		if absf(offset.y) > 1.8:
			continue
		var planar := Vector3(offset.x, 0.0, offset.z)
		var distance_sq := planar.length_squared()
		if distance_sq >= best_distance or distance_sq <= 0.001:
			continue
		if forward.dot(planar.normalized()) < 0.05:
			continue
		best = candidate
		best_distance = distance_sq
	return best

func _detect_combat_spills() -> void:
	for racer: WildDashCharacterController in racers:
		if racer == null:
			continue
		var key: int = racer.get_instance_id()
		var current_knockback: float = racer.get_knockback_velocity().length()
		var previous_knockback: float = float(last_knockback_by_id.get(key, 0.0))
		last_knockback_by_id[key] = current_knockback
		if float(spill_hit_cooldown_by_id.get(key, 0.0)) > 0.0:
			continue
		if current_knockback < KNOCKBACK_SPILL_THRESHOLD:
			continue
		if current_knockback - previous_knockback < 0.75:
			continue
		var amount: int = 2 if current_knockback >= KNOCKBACK_STRONG_THRESHOLD else 1
		_spill_racer(racer, amount, "SKILL / COMBAT HIT")
		spill_hit_cooldown_by_id[key] = COMBAT_SPILL_COOLDOWN

func _spill_racer(racer: WildDashCharacterController, amount: int, reason: String) -> void:
	var carry: int = _get_carry(racer)
	if carry <= 0:
		return
	var actual: int = mini(clampi(amount, 1, 3), carry)
	carried_by_id[racer.get_instance_id()] = carry - actual
	for i in range(actual):
		var angle: float = TAU * float(i) / maxf(1.0, float(actual)) + float(racer.get_instance_id() % 11) * 0.17
		var radius: float = 2.4 + float(i % 2) * 1.15
		var position := racer.global_position + Vector3(cos(angle) * radius, 0.72, sin(angle) * radius)
		_spawn_spilled_fruit(position, _spill_type_for_index(i), 1)
	AudioManager.play_sfx_id("hit", 0.82)
	if racer.is_player:
		_show_event("FRUIT DROPPED! -%d" % actual, 1.05)
		hud.set_message("YOU WERE HIT · RECOVER YOUR FRUIT!")
	print("FRUIT FRENZY SPILL racer=%s amount=%d carry_after=%d reason=%s" % [
		racer.name, actual, _get_carry(racer), reason,
	])

func _spawn_spilled_fruit(position: Vector3, fruit_type: StringName, value: int) -> void:
	var index: int = _find_free_spill_slot()
	if index < 0:
		index = _oldest_spill_slot()
	spill_active[index] = true
	spill_expiry[index] = SPILL_LIFETIME
	spill_types[index] = fruit_type
	spill_values[index] = value
	_configure_fruit_visual(spill_fruits[index], fruit_type)
	spill_fruits[index].position = position
	spill_fruits[index].visible = true

func _find_free_spill_slot() -> int:
	for i in range(spill_active.size()):
		if not spill_active[i]:
			return i
	return -1

func _oldest_spill_slot() -> int:
	var best_index: int = 0
	var shortest_life: float = INF
	for i in range(spill_expiry.size()):
		if spill_expiry[i] < shortest_life:
			shortest_life = spill_expiry[i]
			best_index = i
	return best_index

func _spill_type_for_index(index: int) -> StringName:
	match index % 3:
		0: return FRUIT_APPLE
		1: return FRUIT_BANANA
		_: return FRUIT_BERRY

# -----------------------------------------------------------------------------
# AI decisions
# -----------------------------------------------------------------------------

func _update_ai_decisions() -> void:
	for i in range(ai_racers.size()):
		if i >= ai_drivers.size():
			continue
		var racer: WildDashCharacterController = ai_racers[i]
		var driver: WildDashAIController = ai_drivers[i]
		var personality: StringName = ai_personalities[i] if i < ai_personalities.size() else PERSONALITY_BALANCED
		var carry: int = _get_carry(racer)

		if carry >= 4 or (personality == PERSONALITY_GATHERER and carry >= 3):
			driver.set_arena_target(_cart_root.global_position)
			continue

		if _golden_active and carry <= 2:
			var golden_distance: float = racer.global_position.distance_squared_to(_golden_fruit.global_position)
			if personality in [PERSONALITY_OPPORTUNIST, PERSONALITY_BALANCED] or golden_distance < 18.0 * 18.0:
				driver.set_arena_target(_golden_fruit.global_position)
				continue

		if personality == PERSONALITY_THIEF or personality == PERSONALITY_BALANCED:
			var victim := _best_carrier_target(racer, 14.0 if personality == PERSONALITY_THIEF else 9.5)
			if victim != null:
				driver.set_arena_target(victim.global_position)
				_try_ai_attack(racer, victim, personality)
				continue

		if personality == PERSONALITY_OPPORTUNIST:
			var spill_target := _nearest_active_spill_position(racer.global_position)
			if spill_target != Vector3.INF:
				driver.set_arena_target(spill_target)
				continue

		var fruit_target := _nearest_collectible_position(racer)
		if fruit_target != Vector3.INF:
			driver.set_arena_target(fruit_target)
		else:
			driver.set_arena_target(_cart_root.global_position)

func _best_carrier_target(attacker: WildDashCharacterController, max_range: float) -> WildDashCharacterController:
	var best: WildDashCharacterController = null
	var best_score: float = -INF
	var max_range_sq := max_range * max_range
	for candidate: WildDashCharacterController in racers:
		if candidate == null or candidate == attacker:
			continue
		var carry: int = _get_carry(candidate)
		if carry < 3:
			continue
		var distance_sq: float = attacker.global_position.distance_squared_to(candidate.global_position)
		if distance_sq > max_range_sq:
			continue
		var score: float = float(carry) * 10.0 - sqrt(distance_sq)
		if score > best_score:
			best_score = score
			best = candidate
	return best

func _try_ai_attack(attacker: WildDashCharacterController, target: WildDashCharacterController, personality: StringName) -> void:
	var key: int = attacker.get_instance_id()
	if float(ai_attack_cooldown_by_id.get(key, 0.0)) > 0.0:
		return
	var offset := target.global_position - attacker.global_position
	offset.y = 0.0
	if offset.length_squared() > 2.65 * 2.65 or offset.length_squared() <= 0.001:
		return
	var strength: float = 5.4 if personality == PERSONALITY_THIEF else 4.5
	target.apply_knockback(offset.normalized(), strength)
	var amount: int = 2 if personality == PERSONALITY_THIEF and _get_carry(target) >= 4 else 1
	_spill_racer(target, amount, "AI THIEF BODY CHECK")
	spill_hit_cooldown_by_id[target.get_instance_id()] = COMBAT_SPILL_COOLDOWN
	ai_attack_cooldown_by_id[key] = AI_ATTACK_COOLDOWN
	AudioManager.play_sfx_id("hit", 0.68)

func _nearest_collectible_position(racer: WildDashCharacterController) -> Vector3:
	var best_position := Vector3.INF
	var best_distance := INF
	for i in range(fruits.size()):
		if not fruit_active[i] or not _can_carry_value(racer, fruit_values[i]):
			continue
		var distance: float = racer.global_position.distance_squared_to(fruits[i].global_position)
		if distance < best_distance:
			best_distance = distance
			best_position = fruits[i].global_position
	var spill_position := _nearest_active_spill_position(racer.global_position)
	if spill_position != Vector3.INF:
		var spill_distance: float = racer.global_position.distance_squared_to(spill_position)
		if spill_distance < best_distance:
			best_position = spill_position
	return best_position

func _nearest_active_spill_position(origin: Vector3) -> Vector3:
	var best_position := Vector3.INF
	var best_distance := INF
	for i in range(spill_fruits.size()):
		if not spill_active[i]:
			continue
		var distance: float = origin.distance_squared_to(spill_fruits[i].global_position)
		if distance < best_distance:
			best_distance = distance
			best_position = spill_fruits[i].global_position
	return best_position

# -----------------------------------------------------------------------------
# Harvest Cart / moving bank
# -----------------------------------------------------------------------------

func _create_harvest_cart() -> void:
	_cart_root = Node3D.new()
	_cart_root.name = "HarvestCart"
	_cart_root.position = _cart_stop_position(0)
	add_child(_cart_root)

	_make_child_box(_cart_root, "CartBase", Vector3(0.0, 0.65, 0.0), Vector3(3.8, 1.1, 2.8), Color(0.52, 0.30, 0.11))
	_make_child_box(_cart_root, "Basket", Vector3(0.0, 1.65, 0.0), Vector3(3.1, 1.0, 2.1), Color(0.86, 0.58, 0.18))
	_make_child_box(_cart_root, "Flag", Vector3(0.0, 3.0, 0.0), Vector3(0.22, 3.2, 0.22), Color(0.92, 0.74, 0.16))

	_cart_beacon = MeshInstance3D.new()
	_cart_beacon.name = "BankBeacon"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.20
	mesh.bottom_radius = 0.40
	mesh.height = 7.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.20, 0.95, 0.38, 0.26)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(0.20, 0.95, 0.38) * 0.9
	mesh.material = material
	_cart_beacon.mesh = mesh
	_cart_beacon.position = Vector3(0.0, 3.4, 0.0)
	_cart_root.add_child(_cart_beacon)
	print("FRUIT FRENZY CART READY stop=%s dwell=%.1fs bank_radius=%.2f" % [_cart_destination_name, CART_DWELL_SECONDS, BANK_RADIUS])

func _make_child_box(parent: Node3D, node_name: String, local_position: Vector3, size: Vector3, color: Color) -> void:
	var box := CSGBox3D.new()
	box.name = node_name
	box.position = local_position
	box.size = size
	box.use_collision = false
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	box.material = material
	parent.add_child(box)

func _update_harvest_cart(delta: float) -> void:
	if _cart_root == null:
		return
	if _cart_moving:
		_cart_move_elapsed += delta
		var t: float = clampf(_cart_move_elapsed / CART_MOVE_SECONDS, 0.0, 1.0)
		var eased: float = t * t * (3.0 - 2.0 * t)
		_cart_root.position = _cart_move_from.lerp(_cart_move_to, eased)
		if t >= 1.0:
			_cart_moving = false
			_cart_dwell_elapsed = 0.0
			_show_event("HARVEST CART ARRIVED · %s" % _cart_destination_name, 1.25)
		return

	_cart_dwell_elapsed += delta
	if _cart_dwell_elapsed < CART_DWELL_SECONDS:
		return
	_cart_stop_index = (_cart_stop_index + 1) % 4
	_cart_move_from = _cart_root.position
	_cart_move_to = _cart_stop_position(_cart_stop_index)
	_cart_move_elapsed = 0.0
	_cart_moving = true
	_cart_destination_name = _cart_stop_name(_cart_stop_index)
	_show_event("HARVEST CART MOVING → %s" % _cart_destination_name, 1.8)
	AudioManager.play_sfx_id("ui", 0.72)

func _cart_stop_position(index: int) -> Vector3:
	match index % 4:
		0: return _zone_anchor(2) + Vector3(-1.0, 0.0, -1.0)
		1: return _zone_anchor(0) + Vector3(2.5, 0.0, 2.0)
		2: return _zone_anchor(1) + Vector3(-2.0, 0.0, 2.0)
		_: return _zone_anchor(3) + Vector3(2.0, 0.0, -2.0)

func _cart_stop_name(index: int) -> String:
	match index % 4:
		0: return "MARKET"
		1: return "ORCHARD"
		2: return "RIVER BANK"
		_: return "HILL FARM"

# -----------------------------------------------------------------------------
# Golden Fruit / Golden Harvest
# -----------------------------------------------------------------------------

func _update_golden_event(delta: float) -> void:
	if _golden_harvest_active:
		return
	if _golden_active:
		_golden_age += delta
		if _golden_age >= GOLDEN_LIFETIME:
			_golden_active = false
			_golden_fruit.visible = false
			_golden_beacon.visible = false
			_golden_event_timer = GOLDEN_EVENT_INTERVAL
			_golden_countdown_last = -1
		return

	_golden_event_timer -= delta
	if _golden_event_timer <= GOLDEN_COUNTDOWN_SECONDS and _golden_event_timer > 0.0:
		var count: int = maxi(1, int(ceil(_golden_event_timer)))
		if count != _golden_countdown_last:
			_golden_countdown_last = count
			_show_event("GOLDEN FRUIT INCOMING!  %d" % count, 0.92)
	if _golden_event_timer <= 0.0:
		_spawn_golden_fruit()

func _spawn_golden_fruit() -> void:
	_golden_event_index += 1
	var zone_index: int = _golden_event_index % 4
	var anchor := _zone_anchor(zone_index)
	var offset := Vector3(3.0 if _golden_event_index % 2 == 0 else -3.0, 0.0, 2.0 if zone_index % 2 == 0 else -2.0)
	var position := anchor + offset + Vector3.UP * 1.0
	_golden_fruit.position = position
	_golden_beacon.position = position + Vector3.UP * 3.0
	_golden_fruit.visible = true
	_golden_beacon.visible = true
	_golden_active = true
	_golden_age = 0.0
	_golden_countdown_last = -1
	AudioManager.play_sfx_id("skill", 1.0)
	_show_event("GOLDEN FRUIT!  +3 VALUE", 1.6)
	_camera_shake_remaining = 0.28
	print("FRUIT FRENZY GOLDEN SPAWN zone=%d position=%s" % [zone_index, str(position)])

func _update_golden_harvest() -> void:
	if _golden_harvest_active or time_remaining > GOLDEN_HARVEST_SECONDS:
		return
	_golden_harvest_active = true
	if _golden_active:
		_golden_active = false
		_golden_fruit.visible = false
		_golden_beacon.visible = false
	_spawn_golden_harvest_burst()
	_enable_golden_harvest_light()
	AudioManager.play_sfx_id("finish", 1.0)
	_show_event("GOLDEN HARVEST! · FINAL 20 SEC · BANK VALUE x2", 2.4)
	_camera_shake_remaining = 0.42
	print("FRUIT FRENZY GOLDEN HARVEST bank_multiplier=2 remaining=%.1f" % time_remaining)

func _spawn_golden_harvest_burst() -> void:
	for i in range(12):
		var angle: float = TAU * float(i) / 12.0
		var radius: float = 5.0 + float(i % 3) * 3.0
		var position := Vector3(cos(angle) * radius, 0.72, sin(angle) * radius)
		_spawn_spilled_fruit(position, _spill_type_for_index(i), 1)

func _enable_golden_harvest_light() -> void:
	_golden_harvest_light = OmniLight3D.new()
	_golden_harvest_light.name = "GoldenHarvestLight"
	_golden_harvest_light.position = Vector3(0.0, 6.0, 0.0)
	_golden_harvest_light.light_color = Color(1.0, 0.72, 0.18)
	_golden_harvest_light.light_energy = 1.7
	_golden_harvest_light.omni_range = 28.0
	add_child(_golden_harvest_light)

# -----------------------------------------------------------------------------
# Camera / HUD
# -----------------------------------------------------------------------------

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "FruitFrenzyCamera"
	_camera.position = Vector3(0.0, 26.0, 21.0)
	_camera.fov = 68.0
	_camera.current = true
	add_child(_camera)
	_camera.look_at(Vector3.ZERO, Vector3.UP)

func _update_camera(delta: float) -> void:
	if _camera == null or player == null:
		return
	var focus := player.global_position
	focus.y = 0.6
	if _golden_active and player.global_position.distance_squared_to(_golden_fruit.global_position) < 22.0 * 22.0:
		focus = focus.lerp(_golden_fruit.global_position, 0.18)
	elif _cart_root != null and player.global_position.distance_squared_to(_cart_root.global_position) < 20.0 * 20.0:
		focus = focus.lerp(_cart_root.global_position, 0.11)

	var desired := focus + Vector3(0.0, 24.0, 19.0)
	if _camera_shake_remaining > 0.0:
		_camera_shake_remaining = maxf(0.0, _camera_shake_remaining - delta)
		var phase: float = float(Time.get_ticks_msec()) * 0.034
		desired += Vector3(sin(phase), 0.0, cos(phase * 1.17)) * 0.22
	_camera.position = _camera.position.lerp(desired, clampf(delta * 4.6, 0.0, 1.0))
	_camera.look_at(focus, Vector3.UP)

func _build_event_hud() -> void:
	_event_layer = CanvasLayer.new()
	_event_layer.layer = 55
	add_child(_event_layer)
	_event_label = Label.new()
	_event_label.position = Vector2(430.0, 86.0)
	_event_label.size = Vector2(740.0, 64.0)
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.add_theme_font_size_override("font_size", 28)
	_event_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.18))
	_event_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	_event_label.add_theme_constant_override("shadow_offset_x", 2)
	_event_label.add_theme_constant_override("shadow_offset_y", 2)
	_event_layer.add_child(_event_label)

func _show_event(text: String, duration: float) -> void:
	if _event_label == null:
		return
	_event_label.text = text
	_event_label.visible = true
	_event_label_remaining = maxf(_event_label_remaining, duration)

func _update_event_label(delta: float) -> void:
	if _event_label == null:
		return
	_event_label_remaining = maxf(0.0, _event_label_remaining - delta)
	if _event_label_remaining <= 0.0:
		_event_label.visible = false

func _update_hud() -> void:
	if hud == null or player == null:
		return
	player_score = _get_banked(player)
	var leader: int = player_score
	for racer: WildDashCharacterController in ai_racers:
		leader = maxi(leader, _get_banked(racer))
	var cart_text: String = _cart_destination_name
	if _cart_moving:
		cart_text = "MOVING → %s" % _cart_destination_name
	var final_text: String = " · GOLDEN x2" if _golden_harvest_active else ""
	hud.set_metrics("TIME %02d   SCORE %d   CARRY %d/%d   LEADER %d   CART %s%s   FPS %d" % [
		int(ceil(time_remaining)),
		player_score,
		_get_carry(player),
		MAX_CARRY,
		leader,
		cart_text,
		final_text,
		Engine.get_frames_per_second(),
	])

func _animate_pickups() -> void:
	var time: float = float(Time.get_ticks_msec()) * 0.001
	for i in range(fruits.size()):
		if not fruit_active[i]:
			continue
		fruits[i].rotation.y += 0.018
		fruits[i].position.y = 0.78 + sin(time * 2.5 + float(i) * 0.73) * 0.08
	for i in range(spill_fruits.size()):
		if spill_active[i]:
			spill_fruits[i].rotation.y += 0.025
	if _golden_active:
		_golden_fruit.rotation.y += 0.045

# -----------------------------------------------------------------------------
# Round end
# -----------------------------------------------------------------------------

func _finish_time_score_round() -> void:
	if mode_finished:
		return
	player_score = _get_banked(player)
	var best_ai: int = 0
	var best_ai_name: String = ""
	for racer: WildDashCharacterController in ai_racers:
		var score: int = _get_banked(racer)
		if score > best_ai:
			best_ai = score
			best_ai_name = racer.name
	var success: bool = player_score >= best_ai
	print("FRUIT FRENZY COMPLETE player=%d best_ai=%d best_ai_name=%s success=%s carry_unbanked=%d golden_harvest=%s" % [
		player_score,
		best_ai,
		best_ai_name,
		str(success),
		_get_carry(player),
		str(_golden_harvest_active),
	])
	finish_mode(success, player_score, {
		"best_ai": best_ai,
		"best_ai_name": best_ai_name,
		"duration": ROUND_DURATION,
		"carry_unbanked": _get_carry(player),
		"golden_harvest": _golden_harvest_active,
		"mode_variant": "harvest_heist",
	})
