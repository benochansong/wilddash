extends Node

signal item_granted(character: Node, item_id: StringName)
signal item_used(character: Node, item_id: StringName)
signal item_hit(target: Node, source: Node, effect_id: StringName, blocked: bool)
signal shield_changed(character: Node, active: bool)

const ITEM_DEFINITION_SCRIPT: Script = preload("res://items/item_definition.gd")
const TRAP_SCRIPT: Script = preload("res://items/sticky_fruit_trap.gd")
const ROCKET_SCRIPT: Script = preload("res://items/rocket_nut.gd")
const ACORN_BOMB_SCRIPT: Script = preload("res://items/acorn_bomb.gd")
const BANANA_PEEL_SCRIPT: Script = preload("res://items/banana_peel.gd")

const DASH_BERRY: StringName = &"dash_berry"
const BUBBLE_SHIELD: StringName = &"bubble_shield"
const STICKY_FRUIT: StringName = &"sticky_fruit"
const SHOCKWAVE: StringName = &"shockwave"
const ROCKET_NUT: StringName = &"rocket_nut"
const RECOVERY_FEATHER: StringName = &"recovery_feather"
const SUPER_CARROT: StringName = &"super_carrot"
const ACORN_BOMB: StringName = &"acorn_bomb"
const BANANA_PEEL: StringName = &"banana_peel"
const MAGNET: StringName = &"magnet"
const WIND_BOOST: StringName = &"wind_boost"
const GHOST_FRUIT: StringName = &"ghost_fruit"

const ITEM_IDS: Array[StringName] = [
	DASH_BERRY,
	BUBBLE_SHIELD,
	STICKY_FRUIT,
	SHOCKWAVE,
	ROCKET_NUT,
	RECOVERY_FEATHER,
	SUPER_CARROT,
	ACORN_BOMB,
	BANANA_PEEL,
	MAGNET,
	WIND_BOOST,
	GHOST_FRUIT,
]

const NEW_ITEM_IDS: Array[StringName] = [
	SUPER_CARROT,
	ACORN_BOMB,
	BANANA_PEEL,
	MAGNET,
	WIND_BOOST,
	GHOST_FRUIT,
]

const DASH_DURATION := 2.0
const DASH_SPEED_MULTIPLIER := 1.48
const SUPER_CARROT_DURATION := 3.2
const SUPER_CARROT_SPEED_MULTIPLIER := 1.16
const SUPER_CARROT_ACCELERATION_MULTIPLIER := 1.30
const SUPER_CARROT_HANDLING_MULTIPLIER := 1.18
const SHIELD_DURATION := 5.0
const MAGNET_DURATION := 3.6
const MAGNET_PICKUP_MULTIPLIER := 2.25
const GHOST_DURATION := 2.0
const GHOST_HANDLING_MULTIPLIER := 1.16
const HIT_IMMUNITY_DURATION := 0.75
const SHOCKWAVE_RADIUS := 7.5
const ROCKET_TARGET_DISTANCE := 52.0
const WIND_RADIUS := 8.5
const WIND_PUSH_STRENGTH := 2.4

var _rng := RandomNumberGenerator.new()
var _definitions: Dictionary = {}
var _item_history: Dictionary = {}
var _usage_counts: Dictionary = {}
var _dash_effects: Dictionary = {}
var _super_carrot_effects: Dictionary = {}
var _shield_effects: Dictionary = {}
var _slow_effects: Dictionary = {}
var _spin_effects: Dictionary = {}
var _magnet_effects: Dictionary = {}
var _ghost_effects: Dictionary = {}
var _movement_bases: Dictionary = {}
var _hit_immunity: Dictionary = {}
var _last_used_item: Dictionary = {}

func _ready() -> void:
	_register_definitions()
	_rng.randomize()

func _process(delta: float) -> void:
	_update_dash_effects()
	_update_super_carrot_effects()
	_update_slow_effects(delta)
	_update_spin_effects(delta)
	_update_magnet_effects()
	_update_ghost_effects()
	_refresh_item_movement_modifiers()
	_update_shields()
	_update_hit_immunity()

func is_valid_item(item_id: StringName) -> bool:
	return ITEM_IDS.has(item_id)

func is_new_item(item_id: StringName) -> bool:
	return NEW_ITEM_IDS.has(item_id)

func get_item_count() -> int:
	return ITEM_IDS.size()

func get_definition(item_id: StringName) -> WildDashItemDefinition:
	if _definitions.is_empty():
		_register_definitions()
	return _definitions.get(item_id) as WildDashItemDefinition

func get_display_name(item_id: StringName) -> String:
	if item_id == &"":
		return "—"
	var definition := get_definition(item_id)
	return definition.display_name if definition != null else String(item_id).to_upper()

func get_icon_text(item_id: StringName) -> String:
	if item_id == &"":
		return "--"
	var definition := get_definition(item_id)
	return definition.icon_text if definition != null else "?"

func get_role(item_id: StringName) -> StringName:
	var definition := get_definition(item_id)
	return definition.role if definition != null else &"utility"

func grant_item(character: Node, item_id: StringName) -> bool:
	if character == null or not is_valid_item(item_id):
		return false
	if not character.has_method("get_held_item") or not character.has_method("set_held_item"):
		return false
	if StringName(character.call("get_held_item")) != &"":
		return false
	character.call("set_held_item", item_id)
	item_granted.emit(character, item_id)
	return true

func grant_weighted_item(character: Node) -> bool:
	if character == null:
		return false
	var total := maxi(1, RaceManager.racers.size())
	var rank := RaceManager.get_rank(character as Node3D) if character is Node3D else total
	var history: Array = _item_history.get(character.get_instance_id(), [])
	var item_id := roll_item_for_rank(rank, total, history)
	if not grant_item(character, item_id):
		return false
	_record_item_history(character, item_id)
	return true

func roll_item_for_rank(rank: int, total: int, history: Array = []) -> StringName:
	var safe_total := maxi(1, total)
	var normalized := float(clampi(rank, 1, safe_total) - 1) / float(maxi(1, safe_total - 1))
	var band: StringName = &"mid"
	if normalized <= 0.30:
		band = &"front"
	elif normalized >= 0.70:
		band = &"back"
	return _weighted_pick(band, history)

func use_held_item(character: Node) -> bool:
	if character == null or not character.has_method("get_held_item") or not character.has_method("set_held_item"):
		return false
	var item_id := StringName(character.call("get_held_item"))
	if item_id == &"" or not is_valid_item(item_id):
		return false

	var used := false
	match item_id:
		DASH_BERRY:
			used = _use_dash_berry(character)
		BUBBLE_SHIELD:
			used = _use_bubble_shield(character)
		STICKY_FRUIT:
			used = _use_sticky_fruit(character)
		SHOCKWAVE:
			used = _use_shockwave(character)
		ROCKET_NUT:
			used = _use_rocket_nut(character)
		RECOVERY_FEATHER:
			used = _use_recovery_feather(character)
		SUPER_CARROT:
			used = _use_super_carrot(character)
		ACORN_BOMB:
			used = _use_acorn_bomb(character)
		BANANA_PEEL:
			used = _use_banana_peel(character)
		MAGNET:
			used = _use_magnet(character)
		WIND_BOOST:
			used = _use_wind_boost(character)
		GHOST_FRUIT:
			used = _use_ghost_fruit(character)

	if not used:
		return false
	character.call("set_held_item", &"")
	_last_used_item[character.get_instance_id()] = item_id
	_usage_counts[item_id] = int(_usage_counts.get(item_id, 0)) + 1
	item_used.emit(character, item_id)
	print("ITEM USE racer=%s item=%s role=%s" % [_label(character), get_display_name(item_id), String(get_role(item_id)).to_upper()])
	return true

func apply_attack(
	target: Node,
	source: Node,
	effect_id: StringName,
	duration := 1.0,
	slow_multiplier := 0.65,
	knockback_strength := 0.0,
) -> bool:
	if target == null or target == source or not is_instance_valid(target):
		return false
	if target is WildDashCharacterController and (target as WildDashCharacterController).finished:
		return false
	var id := target.get_instance_id()
	var now := _now_seconds()
	if float(_hit_immunity.get(id, 0.0)) > now:
		return false

	if has_shield(target):
		_shield_effects.erase(id)
		_hit_immunity[id] = now + 0.45
		shield_changed.emit(target, false)
		item_hit.emit(target, source, effect_id, true)
		print("ITEM SHIELD BLOCK target=%s effect=%s" % [_label(target), String(effect_id)])
		return true

	if duration > 0.0:
		_slow_effects[id] = {
			"character": target,
			"expires": now + clampf(duration, 0.2, 1.5),
			"multiplier": clampf(slow_multiplier, 0.45, 1.0),
			"effect": effect_id,
		}
	if target is WildDashCharacterController:
		var controller := target as WildDashCharacterController
		controller.current_speed *= clampf(slow_multiplier, 0.45, 1.0)
		if knockback_strength > 0.0 and controller.has_method("apply_knockback"):
			var direction := -controller.global_transform.basis.z
			if source is Node3D:
				direction = controller.global_position - (source as Node3D).global_position
			controller.apply_knockback(direction, minf(knockback_strength, 6.0))
	_hit_immunity[id] = now + HIT_IMMUNITY_DURATION
	item_hit.emit(target, source, effect_id, false)
	print("ITEM HIT target=%s effect=%s duration=%.2f" % [_label(target), String(effect_id), minf(duration, 1.5)])
	return true

func apply_spin(target: Node, source: Node, duration := 0.85) -> bool:
	if target == null or target == source or not is_instance_valid(target):
		return false
	if not target is WildDashCharacterController or (target as WildDashCharacterController).finished:
		return false
	var id := target.get_instance_id()
	var now := _now_seconds()
	if float(_hit_immunity.get(id, 0.0)) > now:
		return false
	if has_shield(target):
		_shield_effects.erase(id)
		_hit_immunity[id] = now + 0.45
		shield_changed.emit(target, false)
		item_hit.emit(target, source, &"banana_peel", true)
		print("ITEM SHIELD BLOCK target=%s effect=banana_peel" % _label(target))
		return true
	var controller := target as WildDashCharacterController
	_spin_effects[id] = {
		"character": controller,
		"expires": now + clampf(duration, 0.7, 1.0),
	}
	controller.current_speed *= 0.62
	_hit_immunity[id] = now + HIT_IMMUNITY_DURATION
	item_hit.emit(target, source, &"banana_peel", false)
	print("ITEM SPIN HIT target=%s duration=%.2f" % [_label(target), clampf(duration, 0.7, 1.0)])
	return true

func has_shield(character: Node) -> bool:
	if character == null:
		return false
	var expires := float(_shield_effects.get(character.get_instance_id(), 0.0))
	if expires <= _now_seconds():
		if expires > 0.0:
			_shield_effects.erase(character.get_instance_id())
		return false
	return true

func has_effect(character: Node, effect_id: StringName) -> bool:
	if character == null:
		return false
	var id := character.get_instance_id()
	var now := _now_seconds()
	match effect_id:
		&"dash":
			return _effect_active(_dash_effects, id, now)
		&"super_carrot":
			return _effect_active(_super_carrot_effects, id, now)
		&"slow":
			return _effect_active(_slow_effects, id, now)
		&"spin":
			return _effect_active(_spin_effects, id, now)
		&"shield":
			return has_shield(character)
		&"magnet":
			return _effect_active(_magnet_effects, id, now)
		&"ghost":
			return _effect_active(_ghost_effects, id, now)
	return false

func get_status_text(character: Node) -> String:
	if character == null:
		return "ITEM EMPTY"
	var now := _now_seconds()
	var id := character.get_instance_id()
	if _effect_active(_super_carrot_effects, id, now):
		return "SUPER CARROT %.1fs" % _effect_remaining(_super_carrot_effects, id, now)
	if _effect_active(_ghost_effects, id, now):
		return "GHOST %.1fs · RACER COLLISION OFF" % _effect_remaining(_ghost_effects, id, now)
	if _effect_active(_magnet_effects, id, now):
		return "MAGNET %.1fs · PICKUP RANGE +" % _effect_remaining(_magnet_effects, id, now)
	if _effect_active(_dash_effects, id, now):
		return "DASH ACTIVE %.1fs" % _effect_remaining(_dash_effects, id, now)
	if has_shield(character):
		return "SHIELD ACTIVE %.1fs" % (float(_shield_effects[id]) - now)
	if _effect_active(_spin_effects, id, now):
		return "SPIN RECOVERY %.1fs" % _effect_remaining(_spin_effects, id, now)
	if _effect_active(_slow_effects, id, now):
		return "HIT RECOVERY %.1fs" % _effect_remaining(_slow_effects, id, now)
	if character.has_method("get_held_item"):
		var held := StringName(character.call("get_held_item"))
		if held != &"":
			var definition := get_definition(held)
			var label := definition.status_label if definition != null else "ITEM"
			return "%s READY · Q / B" % label
	return "ITEM EMPTY"

func get_pickup_radius(character: Node, base_radius: float) -> float:
	if character == null:
		return base_radius
	if has_effect(character, &"magnet"):
		return base_radius * MAGNET_PICKUP_MULTIPLIER
	return base_radius

func find_target_ahead(character: Node3D, max_distance := ROCKET_TARGET_DISTANCE) -> Node3D:
	if character == null:
		return null
	var forward := -character.global_transform.basis.z.normalized()
	var own_progress := RaceManager.get_track_progress(character)
	var best: Node3D = null
	var best_score := INF
	for rival in RaceManager.racers:
		if rival == character or not is_instance_valid(rival) or RaceManager.finish_order.has(rival):
			continue
		var offset := rival.global_position - character.global_position
		var distance := offset.length()
		if distance <= 0.01 or distance > max_distance:
			continue
		if forward.dot(offset.normalized()) < 0.20:
			continue
		if RaceManager.get_track_progress(rival) + 3.0 < own_progress:
			continue
		var score := distance - maxf(0.0, RaceManager.get_track_progress(rival) - own_progress) * 0.02
		if score < best_score:
			best_score = score
			best = rival
	return best

func has_target_ahead(character: Node3D, max_distance := ROCKET_TARGET_DISTANCE) -> bool:
	return find_target_ahead(character, max_distance) != null

func get_nearest_racer_ahead_distance(character: Node3D, max_distance := ROCKET_TARGET_DISTANCE) -> float:
	var target := find_target_ahead(character, max_distance)
	return INF if target == null else character.global_position.distance_to(target.global_position)

func count_racers_ahead(character: Node3D, max_distance := 18.0, min_forward_dot := 0.15) -> int:
	if character == null:
		return 0
	var forward := -character.global_transform.basis.z.normalized()
	var count := 0
	for rival in RaceManager.racers:
		if rival == character or not is_instance_valid(rival) or RaceManager.finish_order.has(rival):
			continue
		var offset := rival.global_position - character.global_position
		var distance := offset.length()
		if distance <= 0.01 or distance > max_distance:
			continue
		if forward.dot(offset.normalized()) >= min_forward_dot:
			count += 1
	return count

func count_racers_near(character: Node3D, radius: float) -> int:
	if character == null:
		return 0
	var count := 0
	for rival in RaceManager.racers:
		if rival == character or not is_instance_valid(rival) or RaceManager.finish_order.has(rival):
			continue
		if character.global_position.distance_to(rival.global_position) <= radius:
			count += 1
	return count

func has_racer_behind(character: Node3D, radius := 9.0) -> bool:
	if character == null:
		return false
	var forward := -character.global_transform.basis.z.normalized()
	for rival in RaceManager.racers:
		if rival == character or not is_instance_valid(rival) or RaceManager.finish_order.has(rival):
			continue
		var offset := rival.global_position - character.global_position
		if offset.length() <= radius and offset.length_squared() > 0.01 and forward.dot(offset.normalized()) < -0.15:
			return true
	return false

func is_item_station_ahead(character: Node3D, max_distance := 32.0) -> bool:
	if character == null or get_tree() == null:
		return false
	var forward := -character.global_transform.basis.z.normalized()
	for node in get_tree().get_nodes_in_group("wilddash_item_box"):
		if not node is Node3D or not is_instance_valid(node):
			continue
		if node.has_method("is_active") and not bool(node.call("is_active")):
			continue
		var offset := (node as Node3D).global_position - character.global_position
		var distance := offset.length()
		if distance <= 0.01 or distance > max_distance:
			continue
		if forward.dot(offset.normalized()) > 0.05:
			return true
	return false

func set_test_seed(seed: int) -> void:
	_rng.seed = seed

func get_last_used_item(character: Node) -> StringName:
	if character == null:
		return &""
	return StringName(_last_used_item.get(character.get_instance_id(), &""))

func get_item_history(character: Node) -> Array:
	if character == null:
		return []
	return (_item_history.get(character.get_instance_id(), []) as Array).duplicate()

func get_usage_count(item_id: StringName) -> int:
	return int(_usage_counts.get(item_id, 0))

func get_unique_used_count() -> int:
	var count := 0
	for item_id in ITEM_IDS:
		if get_usage_count(item_id) > 0:
			count += 1
	return count

func get_new_unique_used_count() -> int:
	var count := 0
	for item_id in NEW_ITEM_IDS:
		if get_usage_count(item_id) > 0:
			count += 1
	return count

func reset_runtime() -> void:
	for id in _ghost_effects.keys():
		_cleanup_ghost_effect(int(id))
	for id in _movement_bases.keys():
		_restore_movement_base(int(id))
	_dash_effects.clear()
	_super_carrot_effects.clear()
	_shield_effects.clear()
	_slow_effects.clear()
	_spin_effects.clear()
	_magnet_effects.clear()
	_ghost_effects.clear()
	_movement_bases.clear()
	_hit_immunity.clear()
	_last_used_item.clear()
	_item_history.clear()
	_usage_counts.clear()

func _use_dash_berry(character: Node) -> bool:
	if not character is WildDashCharacterController:
		return false
	var controller := character as WildDashCharacterController
	_dash_effects[controller.get_instance_id()] = {
		"character": controller,
		"expires": _now_seconds() + DASH_DURATION,
	}
	controller.current_speed = maxf(controller.current_speed, controller.max_speed * 1.32)
	return true

func _use_bubble_shield(character: Node) -> bool:
	if not character is WildDashCharacterController:
		return false
	_shield_effects[character.get_instance_id()] = _now_seconds() + SHIELD_DURATION
	shield_changed.emit(character, true)
	return true

func _use_sticky_fruit(character: Node) -> bool:
	if not character is WildDashCharacterController:
		return false
	var controller := character as WildDashCharacterController
	var world := controller.get_parent()
	if world == null:
		return false
	var trap: WildDashStickyFruitTrap = TRAP_SCRIPT.new() as WildDashStickyFruitTrap
	trap.name = "StickyFruit_%d" % Time.get_ticks_msec()
	trap.owner_racer = controller
	world.add_child(trap)
	var forward := -controller.global_transform.basis.z.normalized()
	trap.global_position = controller.global_position - forward * 2.2 + Vector3.UP * 0.25
	return true

func _use_shockwave(character: Node) -> bool:
	if not character is WildDashCharacterController:
		return false
	var controller := character as WildDashCharacterController
	var hits := 0
	for rival in RaceManager.racers:
		if rival == controller or not is_instance_valid(rival) or RaceManager.finish_order.has(rival):
			continue
		var distance := controller.global_position.distance_to(rival.global_position)
		if distance <= SHOCKWAVE_RADIUS:
			if apply_attack(rival, controller, &"shockwave", 0.65, 0.78, 4.6):
				hits += 1
	print("SHOCKWAVE RESOLVE racer=%s hits=%d" % [_label(controller), hits])
	return true

func _use_rocket_nut(character: Node) -> bool:
	if not character is WildDashCharacterController:
		return false
	var controller := character as WildDashCharacterController
	var target := find_target_ahead(controller)
	if target == null:
		return false
	var world := controller.get_parent()
	if world == null:
		return false
	var rocket: WildDashRocketNut = ROCKET_SCRIPT.new() as WildDashRocketNut
	rocket.name = "RocketNut_%d" % Time.get_ticks_msec()
	world.add_child(rocket)
	rocket.configure(controller, target)
	var forward := -controller.global_transform.basis.z.normalized()
	rocket.global_position = controller.global_position + forward * 2.0 + Vector3.UP * 0.9
	return true

func _use_recovery_feather(character: Node) -> bool:
	if not character is WildDashCharacterController:
		return false
	var controller := character as WildDashCharacterController
	controller.velocity.y = maxf(controller.velocity.y, controller.jump_velocity * 1.12)
	controller.current_speed = maxf(controller.current_speed, controller.max_speed * 1.20)
	return true

func _use_super_carrot(character: Node) -> bool:
	if not character is WildDashCharacterController:
		return false
	var controller := character as WildDashCharacterController
	_ensure_movement_base(controller)
	_super_carrot_effects[controller.get_instance_id()] = {
		"character": controller,
		"expires": _now_seconds() + SUPER_CARROT_DURATION,
	}
	controller.current_speed = maxf(controller.current_speed, controller.max_speed * 1.08)
	return true

func _use_acorn_bomb(character: Node) -> bool:
	if not character is WildDashCharacterController:
		return false
	var controller := character as WildDashCharacterController
	var world := controller.get_parent()
	if world == null:
		return false
	var bomb: WildDashAcornBomb = ACORN_BOMB_SCRIPT.new() as WildDashAcornBomb
	bomb.name = "AcornBomb_%d" % Time.get_ticks_msec()
	world.add_child(bomb)
	bomb.configure(controller)
	var forward := -controller.global_transform.basis.z.normalized()
	bomb.global_position = controller.global_position + forward * 1.8 + Vector3.UP * 1.25
	return true

func _use_banana_peel(character: Node) -> bool:
	if not character is WildDashCharacterController:
		return false
	var controller := character as WildDashCharacterController
	var world := controller.get_parent()
	if world == null:
		return false
	var peel: WildDashBananaPeel = BANANA_PEEL_SCRIPT.new() as WildDashBananaPeel
	peel.name = "BananaPeel_%d" % Time.get_ticks_msec()
	peel.owner_racer = controller
	world.add_child(peel)
	var forward := -controller.global_transform.basis.z.normalized()
	peel.global_position = controller.global_position - forward * 2.15 + Vector3.UP * 0.12
	return true

func _use_magnet(character: Node) -> bool:
	if not character is WildDashCharacterController:
		return false
	_magnet_effects[character.get_instance_id()] = {
		"character": character,
		"expires": _now_seconds() + MAGNET_DURATION,
	}
	return true

func _use_wind_boost(character: Node) -> bool:
	if not character is WildDashCharacterController:
		return false
	var controller := character as WildDashCharacterController
	controller.current_speed = maxf(controller.current_speed, controller.max_speed * 1.12)
	var forward := -controller.global_transform.basis.z.normalized()
	var hits := 0
	for rival in RaceManager.racers:
		if rival == controller or not is_instance_valid(rival) or RaceManager.finish_order.has(rival):
			continue
		var offset := rival.global_position - controller.global_position
		var distance := offset.length()
		if distance <= 0.01 or distance > WIND_RADIUS:
			continue
		if forward.dot(offset.normalized()) < 0.20:
			continue
		if apply_attack(rival, controller, &"wind_boost", 0.0, 1.0, WIND_PUSH_STRENGTH):
			hits += 1
	print("WIND BOOST RESOLVE racer=%s hits=%d push=%.1f" % [_label(controller), hits, WIND_PUSH_STRENGTH])
	return true

func _use_ghost_fruit(character: Node) -> bool:
	if not character is WildDashCharacterController:
		return false
	var controller := character as WildDashCharacterController
	var id := controller.get_instance_id()
	if _ghost_effects.has(id):
		_cleanup_ghost_effect(id)
	_ensure_movement_base(controller)
	var exceptions: Array = []
	for rival in RaceManager.racers:
		if rival == controller or not is_instance_valid(rival) or not rival is PhysicsBody3D:
			continue
		controller.add_collision_exception_with(rival)
		(rival as PhysicsBody3D).add_collision_exception_with(controller)
		exceptions.append(rival)
	_ghost_effects[id] = {
		"character": controller,
		"expires": _now_seconds() + GHOST_DURATION,
		"exceptions": exceptions,
	}
	return true

func _weighted_pick(band: StringName, history: Array) -> StringName:
	var weighted: Dictionary = {}
	var total := 0.0
	for item_id in ITEM_IDS:
		var definition := get_definition(item_id)
		var weight := definition.weight_for_band(band) if definition != null else 1.0
		weight *= _history_multiplier(item_id, history)
		weighted[item_id] = weight
		total += weight
	if total <= 0.0:
		return DASH_BERRY
	var roll := _rng.randf_range(0.0, total)
	var cursor := 0.0
	for item_id in ITEM_IDS:
		cursor += float(weighted.get(item_id, 0.0))
		if roll <= cursor:
			return item_id
	return ITEM_IDS[ITEM_IDS.size() - 1]

func _history_multiplier(item_id: StringName, history: Array) -> float:
	if history.is_empty():
		return 1.0
	var last := StringName(history[history.size() - 1])
	if history.size() >= 2:
		var previous := StringName(history[history.size() - 2])
		if item_id == last and item_id == previous:
			return 0.06
		if item_id == previous:
			return 0.78
	if item_id == last:
		return 0.38
	return 1.0

func _record_item_history(character: Node, item_id: StringName) -> void:
	var id := character.get_instance_id()
	var history: Array = _item_history.get(id, [])
	history.append(item_id)
	while history.size() > 2:
		history.pop_front()
	_item_history[id] = history

func _update_dash_effects() -> void:
	var now := _now_seconds()
	for id in _dash_effects.keys():
		var data: Dictionary = _dash_effects[id]
		var character = data.get("character")
		if character == null or not is_instance_valid(character) or float(data.get("expires", 0.0)) <= now:
			_dash_effects.erase(id)
			continue
		if character is WildDashCharacterController:
			var controller := character as WildDashCharacterController
			controller.current_speed = maxf(controller.current_speed, controller.max_speed * DASH_SPEED_MULTIPLIER)

func _update_super_carrot_effects() -> void:
	var now := _now_seconds()
	for id in _super_carrot_effects.keys():
		var data: Dictionary = _super_carrot_effects[id]
		var character = data.get("character")
		if character == null or not is_instance_valid(character) or float(data.get("expires", 0.0)) <= now:
			_super_carrot_effects.erase(id)
			continue
		if character is WildDashCharacterController:
			var controller := character as WildDashCharacterController
			controller.current_speed = maxf(controller.current_speed, controller.max_speed * SUPER_CARROT_SPEED_MULTIPLIER)

func _update_slow_effects(delta: float) -> void:
	var now := _now_seconds()
	for id in _slow_effects.keys():
		var data: Dictionary = _slow_effects[id]
		var character = data.get("character")
		if character == null or not is_instance_valid(character) or float(data.get("expires", 0.0)) <= now:
			_slow_effects.erase(id)
			continue
		if character is WildDashCharacterController:
			var controller := character as WildDashCharacterController
			var multiplier := float(data.get("multiplier", 0.65))
			controller.current_speed = minf(controller.current_speed, controller.max_speed * multiplier)
			controller.rotation.y += sin(now * 18.0 + float(int(id) % 7)) * 0.55 * delta

func _update_spin_effects(delta: float) -> void:
	var now := _now_seconds()
	for id in _spin_effects.keys():
		var data: Dictionary = _spin_effects[id]
		var character = data.get("character")
		if character == null or not is_instance_valid(character) or float(data.get("expires", 0.0)) <= now:
			_spin_effects.erase(id)
			continue
		if character is WildDashCharacterController:
			var controller := character as WildDashCharacterController
			controller.rotation.y += 8.5 * delta
			controller.current_speed = minf(controller.current_speed, controller.max_speed * 0.62)

func _update_magnet_effects() -> void:
	var now := _now_seconds()
	for id in _magnet_effects.keys():
		var data: Dictionary = _magnet_effects[id]
		var character = data.get("character")
		if character == null or not is_instance_valid(character) or float(data.get("expires", 0.0)) <= now:
			_magnet_effects.erase(id)

func _update_ghost_effects() -> void:
	var now := _now_seconds()
	for id in _ghost_effects.keys():
		var data: Dictionary = _ghost_effects[id]
		var character = data.get("character")
		if character == null or not is_instance_valid(character) or float(data.get("expires", 0.0)) <= now:
			_cleanup_ghost_effect(int(id))

func _ensure_movement_base(controller: WildDashCharacterController) -> void:
	if controller == null:
		return
	var id := controller.get_instance_id()
	if _movement_bases.has(id):
		return
	_movement_bases[id] = {
		"character": controller,
		"acceleration": controller.acceleration,
		"turn_speed": controller.turn_speed,
	}

func _refresh_item_movement_modifiers() -> void:
	var now := _now_seconds()
	for id in _movement_bases.keys():
		var base: Dictionary = _movement_bases[id]
		var character = base.get("character")
		if character == null or not is_instance_valid(character) or not character is WildDashCharacterController:
			_movement_bases.erase(id)
			continue
		var controller := character as WildDashCharacterController
		var carrot_active := _effect_active(_super_carrot_effects, int(id), now)
		var ghost_active := _effect_active(_ghost_effects, int(id), now)
		if not carrot_active and not ghost_active:
			_restore_movement_base(int(id))
			continue
		var acceleration_multiplier := SUPER_CARROT_ACCELERATION_MULTIPLIER if carrot_active else 1.0
		var handling_multiplier := 1.0
		if carrot_active:
			handling_multiplier *= SUPER_CARROT_HANDLING_MULTIPLIER
		if ghost_active:
			handling_multiplier *= GHOST_HANDLING_MULTIPLIER
		controller.acceleration = float(base.get("acceleration", controller.acceleration)) * acceleration_multiplier
		controller.turn_speed = float(base.get("turn_speed", controller.turn_speed)) * handling_multiplier

func _restore_movement_base(id: int) -> void:
	var base: Dictionary = _movement_bases.get(id, {})
	if base.is_empty():
		return
	var character = base.get("character")
	if character != null and is_instance_valid(character) and character is WildDashCharacterController:
		var controller := character as WildDashCharacterController
		controller.acceleration = float(base.get("acceleration", controller.acceleration))
		controller.turn_speed = float(base.get("turn_speed", controller.turn_speed))
	_movement_bases.erase(id)

func _cleanup_ghost_effect(id: int) -> void:
	var data: Dictionary = _ghost_effects.get(id, {})
	if data.is_empty():
		return
	var character = data.get("character")
	var exceptions: Array = data.get("exceptions", [])
	if character != null and is_instance_valid(character) and character is PhysicsBody3D:
		var body := character as PhysicsBody3D
		for rival in exceptions:
			if rival == null or not is_instance_valid(rival) or not rival is PhysicsBody3D:
				continue
			body.remove_collision_exception_with(rival)
			(rival as PhysicsBody3D).remove_collision_exception_with(body)
	_ghost_effects.erase(id)

func _update_shields() -> void:
	var now := _now_seconds()
	for id in _shield_effects.keys():
		var expires := float(_shield_effects[id])
		if expires <= now:
			_shield_effects.erase(id)
			continue
		var character := instance_from_id(int(id))
		if character == null or not is_instance_valid(character):
			_shield_effects.erase(id)
			continue
		if character is WildDashCharacterController:
			var controller := character as WildDashCharacterController
			if controller.has_blocking_collision():
				_shield_effects.erase(id)
				controller.current_speed = maxf(controller.current_speed, controller.cruise_speed)
				_hit_immunity[id] = now + 0.45
				shield_changed.emit(controller, false)
				print("ITEM SHIELD COLLISION BLOCK racer=%s" % _label(controller))

func _update_hit_immunity() -> void:
	var now := _now_seconds()
	for id in _hit_immunity.keys():
		if float(_hit_immunity[id]) <= now:
			_hit_immunity.erase(id)

func _effect_active(storage: Dictionary, id: int, now: float) -> bool:
	var data: Dictionary = storage.get(id, {})
	return not data.is_empty() and float(data.get("expires", 0.0)) > now

func _effect_remaining(storage: Dictionary, id: int, now: float) -> float:
	var data: Dictionary = storage.get(id, {})
	return maxf(0.0, float(data.get("expires", now)) - now)

func _register_definitions() -> void:
	if not _definitions.is_empty():
		return
	_register_definition(DASH_BERRY, "DASH BERRY", &"speed", "DB", "BURST SPEED", 5.0, 9.0, 13.0, DASH_DURATION, DASH_SPEED_MULTIPLIER, 1.0)
	_register_definition(BUBBLE_SHIELD, "BUBBLE SHIELD", &"defense", "BS", "SHIELD", 14.0, 10.0, 8.0, SHIELD_DURATION, 1.0, 1.0)
	_register_definition(STICKY_FRUIT, "STICKY FRUIT", &"trap", "SF", "SLOW TRAP", 15.0, 9.0, 4.0, 0.0, 0.52, 1.25)
	_register_definition(SHOCKWAVE, "SHOCKWAVE", &"attack", "SW", "AREA BLAST", 6.0, 10.0, 14.0, 0.0, SHOCKWAVE_RADIUS, 4.6)
	_register_definition(ROCKET_NUT, "ROCKET NUT", &"attack", "RN", "HOMING SHOT", 8.0, 10.0, 7.0, 0.0, ROCKET_TARGET_DISTANCE, 1.0)
	_register_definition(RECOVERY_FEATHER, "RECOVERY FEATHER", &"utility", "RF", "RECOVERY LEAP", 4.0, 8.0, 14.0, 0.0, 1.20, 1.12)
	_register_definition(SUPER_CARROT, "SUPER CARROT", &"speed", "SC", "CHASE BOOST", 7.0, 10.0, 16.0, SUPER_CARROT_DURATION, SUPER_CARROT_SPEED_MULTIPLIER, SUPER_CARROT_HANDLING_MULTIPLIER)
	_register_definition(ACORN_BOMB, "ACORN BOMB", &"attack", "AB", "ARC BOMB", 8.0, 10.0, 7.0, 0.0, 4.6, 3.4)
	_register_definition(BANANA_PEEL, "BANANA PEEL", &"trap", "BP", "SPIN TRAP", 15.0, 9.0, 4.0, 0.85, 1.0, 1.0)
	_register_definition(MAGNET, "MAGNET", &"utility", "MG", "PICKUP MAGNET", 6.0, 9.0, 9.0, MAGNET_DURATION, MAGNET_PICKUP_MULTIPLIER, 1.0)
	_register_definition(WIND_BOOST, "WIND BOOST", &"attack", "WB", "WIND PUSH", 10.0, 10.0, 7.0, 0.0, WIND_RADIUS, WIND_PUSH_STRENGTH)
	_register_definition(GHOST_FRUIT, "GHOST FRUIT", &"defense", "GF", "PHASE", 12.0, 10.0, 7.0, GHOST_DURATION, GHOST_HANDLING_MULTIPLIER, 1.0)

func _register_definition(
	item_id: StringName,
	display_name: String,
	role: StringName,
	icon_text: String,
	status_label: String,
	front_weight: float,
	mid_weight: float,
	back_weight: float,
	duration: float,
	strength: float,
	secondary_strength: float,
) -> void:
	var definition := ITEM_DEFINITION_SCRIPT.new() as WildDashItemDefinition
	definition.configure(
		item_id,
		display_name,
		role,
		icon_text,
		status_label,
		front_weight,
		mid_weight,
		back_weight,
		duration,
		strength,
		secondary_strength,
	)
	_definitions[item_id] = definition

func _now_seconds() -> float:
	return Time.get_ticks_msec() * 0.001

func _label(character: Node) -> String:
	if character is Node3D and RaceManager.racers.has(character):
		return RaceManager.get_racer_label(character)
	return character.name if character != null else "Unknown"
