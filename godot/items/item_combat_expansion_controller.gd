class_name WildDashItemCombatExpansionController
extends Node

const CATALOG: Script = preload("res://items/expanded_item_catalog.gd")
const SNOWBALL_SCRIPT: Script = preload("res://items/snowball_projectile.gd")
const BEE_EFFECT_SCRIPT: Script = preload("res://items/bee_swarm_effect.gd")
const MUD_TRAP_SCRIPT: Script = preload("res://items/mud_splash_trap.gd")
const SPRING_TRAP_SCRIPT: Script = preload("res://items/spring_trap.gd")
const ROCKET_SCRIPT: Script = preload("res://items/rocket_nut.gd")

const ITEM_INPUT_BUFFER_MSEC := 170
const AI_DECISION_INTERVAL := 0.20
const EXPANSION_REPLACE_CHANCE := 0.34
const TURBO_CHILI_DURATION := 2.35
const SWAP_BOOST_DURATION := 1.75

var _rng := RandomNumberGenerator.new()
var _buffer_until_msec := 0
var _buffer_reported_empty := false
var _ai_elapsed := 0.0
var _boost_effects: Dictionary = {}
var _expansion_history: Dictionary = {}
var _reported_ready := false

func _ready() -> void:
	_rng.randomize()
	if not ItemSystem.item_granted.is_connected(_on_item_granted):
		ItemSystem.item_granted.connect(_on_item_granted)
	set_process_input(true)

func _exit_tree() -> void:
	if ItemSystem.item_granted.is_connected(_on_item_granted):
		ItemSystem.item_granted.disconnect(_on_item_granted)

func _input(event: InputEvent) -> void:
	if event == null or not event.is_action_pressed(&"item"):
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	_buffer_until_msec = Time.get_ticks_msec() + ITEM_INPUT_BUFFER_MSEC
	_buffer_reported_empty = false

func _physics_process(delta: float) -> void:
	_update_boost_effects()
	_resolve_player_input_buffer()
	_ai_elapsed += delta
	if _ai_elapsed >= AI_DECISION_INTERVAL:
		_ai_elapsed = 0.0
		_update_ai_expanded_items()
	if not _reported_ready and _resolve_player() != null:
		_reported_ready = true
		print("ITEM COMBAT EXPANSION READY base=%d expanded=%d total=%d input_buffer=%dms" % [
			ItemSystem.get_item_count(), CATALOG.get_count(), ItemSystem.get_item_count() + CATALOG.get_count(), ITEM_INPUT_BUFFER_MSEC,
		])

func is_expanded_item(item_id: StringName) -> bool:
	return CATALOG.is_expanded(item_id)

func get_total_item_count() -> int:
	return ItemSystem.get_item_count() + CATALOG.get_count()

func use_expanded_item(character: WildDashCharacterController, item_id: StringName) -> bool:
	if character == null or not CATALOG.is_expanded(item_id):
		return false
	var used := false
	match item_id:
		CATALOG.SNOWBALL:
			used = _use_snowball(character)
		CATALOG.BEE_SWARM:
			used = _use_bee_swarm(character)
		CATALOG.TURBO_CHILI:
			used = _use_turbo_chili(character)
		CATALOG.MUD_SPLASH:
			used = _use_mud_splash(character)
		CATALOG.SPRING_TRAP:
			used = _use_spring_trap(character)
		CATALOG.SWAP_BOOST:
			used = _use_swap_boost(character)
	if not used:
		return false
	character.set_held_item(&"")
	character.set_meta(&"wilddash_last_expanded_item", item_id)
	ItemSystem.item_used.emit(character, item_id)
	AudioManager.play_sfx_id("item", 1.0)
	print("ITEM USE racer=%s item=%s role=%s source=expansion" % [
		RaceManager.get_racer_label(character), CATALOG.get_display_name(item_id), String(CATALOG.get_role(item_id)).to_upper(),
	])
	return true

func _resolve_player_input_buffer() -> void:
	if _buffer_until_msec <= 0:
		return
	var now := Time.get_ticks_msec()
	if now > _buffer_until_msec:
		var expired_player := _resolve_player()
		var held := expired_player.get_held_item() if expired_player != null else &""
		if held == &"" and not _buffer_reported_empty:
			print("ITEM USE DENIED reason=NO_HELD_ITEM buffer_expired=true")
		elif held != &"":
			print("ITEM USE DENIED racer=%s item=%s reason=CONDITION_NOT_READY buffer_expired=true" % [
				RaceManager.get_racer_label(expired_player), _display_name(held),
			])
		_buffer_until_msec = 0
		return
	if not RaceManager.active:
		return
	var player := _resolve_player()
	if player == null or player.finished:
		return
	var item_id := player.get_held_item()
	if item_id == &"":
		_buffer_reported_empty = true
		return
	if _try_use_any_item(player, item_id):
		_buffer_until_msec = 0

func _try_use_any_item(character: WildDashCharacterController, item_id: StringName) -> bool:
	if CATALOG.is_expanded(item_id):
		return use_expanded_item(character, item_id)
	if ItemSystem.use_held_item(character):
		AudioManager.play_sfx_id("item", 1.0)
		return true
	# Rocket Nut used to fail silently whenever no valid homing target existed.
	# Preserve homing when possible, but fire a straight, wall-aware projectile
	# instead of eating the player's button press when the road ahead is empty.
	if item_id == ItemSystem.ROCKET_NUT:
		return _fire_rocket_forward_fallback(character)
	return false

func _fire_rocket_forward_fallback(character: WildDashCharacterController) -> bool:
	var world := character.get_parent()
	if world == null:
		return false
	var rocket: WildDashRocketNut = ROCKET_SCRIPT.new() as WildDashRocketNut
	rocket.name = "RocketNutStraight_%d" % Time.get_ticks_msec()
	world.add_child(rocket)
	rocket.configure(character, null)
	var forward := -character.global_transform.basis.z.normalized()
	rocket.global_position = _safe_forward_spawn(character, 1.75, 0.82)
	character.set_held_item(&"")
	ItemSystem.item_used.emit(character, ItemSystem.ROCKET_NUT)
	AudioManager.play_sfx_id("item", 1.0)
	print("ITEM USE racer=%s item=ROCKET NUT fallback=STRAIGHT_SHOT reason=NO_HOMING_TARGET" % RaceManager.get_racer_label(character))
	return true

func _on_item_granted(character: Node, item_id: StringName) -> void:
	if character == null or not character is WildDashCharacterController:
		return
	var racer := character as WildDashCharacterController
	if racer.movement_mode != WildDashCharacterController.MovementMode.RACE:
		return
	if racer.get_held_item() != item_id:
		return
	if _rng.randf() > EXPANSION_REPLACE_CHANCE:
		return
	var replacement := _pick_expanded_item(racer)
	if replacement == &"":
		return
	racer.set_held_item(replacement)
	_record_expansion_history(racer, replacement)
	print("ITEM EXPANSION ROLL racer=%s base=%s replacement=%s" % [
		RaceManager.get_racer_label(racer), ItemSystem.get_display_name(item_id), CATALOG.get_display_name(replacement),
	])

func _pick_expanded_item(racer: WildDashCharacterController) -> StringName:
	var rank := RaceManager.get_rank(racer)
	var total := maxi(1, RaceManager.racers.size())
	var back_ratio := float(clampi(rank, 1, total) - 1) / float(maxi(1, total - 1))
	var weights: Dictionary = {
		CATALOG.SNOWBALL: 1.05,
		CATALOG.BEE_SWARM: 0.95 + back_ratio * 0.20,
		CATALOG.TURBO_CHILI: 0.70 + back_ratio * 0.85,
		CATALOG.MUD_SPLASH: 1.10 - back_ratio * 0.25,
		CATALOG.SPRING_TRAP: 0.92,
		CATALOG.SWAP_BOOST: 0.65 + back_ratio * 0.90,
	}
	var history: Array = _expansion_history.get(racer.get_instance_id(), [])
	var total_weight := 0.0
	for candidate in CATALOG.ITEM_IDS:
		var weight := float(weights.get(candidate, 1.0))
		if history.has(candidate):
			weight *= 0.28
		weights[candidate] = weight
		total_weight += weight
	var roll := _rng.randf_range(0.0, total_weight)
	var cursor := 0.0
	for candidate in CATALOG.ITEM_IDS:
		cursor += float(weights[candidate])
		if roll <= cursor:
			return candidate
	return CATALOG.ITEM_IDS[0]

func _record_expansion_history(racer: WildDashCharacterController, item_id: StringName) -> void:
	var id := racer.get_instance_id()
	var history: Array = _expansion_history.get(id, [])
	history.append(item_id)
	while history.size() > 2:
		history.pop_front()
	_expansion_history[id] = history

func _use_snowball(character: WildDashCharacterController) -> bool:
	var world := character.get_parent()
	if world == null:
		return false
	var projectile: WildDashSnowballProjectile = SNOWBALL_SCRIPT.new() as WildDashSnowballProjectile
	projectile.name = "Snowball_%d" % Time.get_ticks_msec()
	world.add_child(projectile)
	var forward := -character.global_transform.basis.z.normalized()
	projectile.configure(character, forward)
	projectile.global_position = _safe_forward_spawn(character, 1.75, 0.78)
	return true

func _use_bee_swarm(character: WildDashCharacterController) -> bool:
	var target := ItemSystem.find_target_ahead(character, 58.0) as WildDashCharacterController
	if target == null:
		target = _nearest_rival(character, 32.0)
	if target == null:
		return false
	if not ItemSystem.apply_attack(target, character, &"bee_swarm", 1.15, 0.84, 0.0):
		return false
	var world := character.get_parent()
	if world != null:
		var effect: WildDashBeeSwarmEffect = BEE_EFFECT_SCRIPT.new() as WildDashBeeSwarmEffect
		effect.name = "BeeSwarm_%d" % Time.get_ticks_msec()
		effect.configure(target)
		world.add_child(effect)
	return true

func _use_turbo_chili(character: WildDashCharacterController) -> bool:
	_boost_effects[character.get_instance_id()] = {
		"character": character,
		"expires": _now_seconds() + TURBO_CHILI_DURATION,
		"speed_ratio": 1.34,
		"item": CATALOG.TURBO_CHILI,
	}
	character.current_speed = maxf(character.current_speed, character.max_speed * 1.24)
	return true

func _use_mud_splash(character: WildDashCharacterController) -> bool:
	var world := character.get_parent()
	if world == null:
		return false
	var trap: WildDashMudSplashTrap = MUD_TRAP_SCRIPT.new() as WildDashMudSplashTrap
	trap.name = "MudSplash_%d" % Time.get_ticks_msec()
	trap.owner_racer = character
	world.add_child(trap)
	var forward := -character.global_transform.basis.z.normalized()
	trap.global_position = character.global_position - forward * 2.25 + Vector3.UP * 0.08
	return true

func _use_spring_trap(character: WildDashCharacterController) -> bool:
	var world := character.get_parent()
	if world == null:
		return false
	var trap: WildDashSpringTrap = SPRING_TRAP_SCRIPT.new() as WildDashSpringTrap
	trap.name = "SpringTrap_%d" % Time.get_ticks_msec()
	trap.owner_racer = character
	world.add_child(trap)
	var forward := -character.global_transform.basis.z.normalized()
	trap.global_position = character.global_position - forward * 2.35 + Vector3.UP * 0.10
	return true

func _use_swap_boost(character: WildDashCharacterController) -> bool:
	var rank := RaceManager.get_rank(character)
	var total := maxi(1, RaceManager.racers.size())
	var back_ratio := float(clampi(rank, 1, total) - 1) / float(maxi(1, total - 1))
	var ratio := 1.14 + back_ratio * 0.16
	_boost_effects[character.get_instance_id()] = {
		"character": character,
		"expires": _now_seconds() + SWAP_BOOST_DURATION,
		"speed_ratio": ratio,
		"item": CATALOG.SWAP_BOOST,
	}
	character.current_speed = maxf(character.current_speed, character.max_speed * (1.08 + back_ratio * 0.10))
	return true

func _update_boost_effects() -> void:
	var now := _now_seconds()
	for id in _boost_effects.keys():
		var data: Dictionary = _boost_effects[id]
		var character = data.get("character")
		if character == null or not is_instance_valid(character) or float(data.get("expires", 0.0)) <= now:
			_boost_effects.erase(id)
			continue
		if character is WildDashCharacterController:
			var racer := character as WildDashCharacterController
			racer.current_speed = maxf(racer.current_speed, racer.max_speed * float(data.get("speed_ratio", 1.12)))

func _update_ai_expanded_items() -> void:
	if not RaceManager.active:
		return
	for racer_node in RaceManager.racers:
		if not racer_node is WildDashCharacterController:
			continue
		var racer := racer_node as WildDashCharacterController
		if racer.is_player or racer.finished:
			continue
		var item_id := racer.get_held_item()
		if not CATALOG.is_expanded(item_id):
			continue
		if _ai_utility(racer, item_id) >= 0.62:
			use_expanded_item(racer, item_id)

func _ai_utility(racer: WildDashCharacterController, item_id: StringName) -> float:
	var rank := RaceManager.get_rank(racer)
	var total := maxi(1, RaceManager.racers.size())
	var back_ratio := float(clampi(rank, 1, total) - 1) / float(maxi(1, total - 1))
	match item_id:
		CATALOG.SNOWBALL:
			return 0.86 if ItemSystem.has_target_ahead(racer, 46.0) else 0.46
		CATALOG.BEE_SWARM:
			return 0.88 if ItemSystem.has_target_ahead(racer, 58.0) else 0.52
		CATALOG.TURBO_CHILI:
			return 0.54 + back_ratio * 0.38
		CATALOG.MUD_SPLASH:
			return 0.88 if ItemSystem.has_racer_behind(racer, 11.0) else 0.34
		CATALOG.SPRING_TRAP:
			return 0.84 if ItemSystem.has_racer_behind(racer, 9.0) else 0.32
		CATALOG.SWAP_BOOST:
			return 0.48 + back_ratio * 0.48
	return 0.0

func _safe_forward_spawn(character: WildDashCharacterController, distance: float, height: float) -> Vector3:
	var forward := -character.global_transform.basis.z.normalized()
	var desired := character.global_position + forward * distance + Vector3.UP * height
	var from := character.global_position + Vector3.UP * height
	var query := PhysicsRayQueryParameters3D.create(from, desired, 1)
	query.exclude = [character.get_rid()]
	var hit := character.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired
	var hit_pos: Vector3 = hit.get("position", from)
	return from.lerp(hit_pos, 0.58)

func _nearest_rival(character: WildDashCharacterController, max_distance: float) -> WildDashCharacterController:
	var best: WildDashCharacterController = null
	var best_distance := max_distance
	for rival in RaceManager.racers:
		if rival == character or not rival is WildDashCharacterController or not is_instance_valid(rival) or RaceManager.finish_order.has(rival):
			continue
		var distance := character.global_position.distance_to(rival.global_position)
		if distance < best_distance:
			best_distance = distance
			best = rival as WildDashCharacterController
	return best

func _resolve_player() -> WildDashCharacterController:
	var direct := get_parent().get_node_or_null("Player") as WildDashCharacterController
	if direct != null:
		return direct
	for racer in RaceManager.racers:
		if racer is WildDashCharacterController and (racer as WildDashCharacterController).is_player:
			return racer as WildDashCharacterController
	return null

func _display_name(item_id: StringName) -> String:
	return CATALOG.get_display_name(item_id) if CATALOG.is_expanded(item_id) else ItemSystem.get_display_name(item_id)

func _now_seconds() -> float:
	return Time.get_ticks_msec() * 0.001
