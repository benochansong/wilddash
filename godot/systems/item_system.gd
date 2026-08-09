extends Node

signal item_granted(character: Node, item_id: StringName)
signal item_used(character: Node, item_id: StringName)
signal item_hit(target: Node, source: Node, effect_id: StringName, blocked: bool)
signal shield_changed(character: Node, active: bool)

const TRAP_SCRIPT: Script = preload("res://items/sticky_fruit_trap.gd")
const ROCKET_SCRIPT: Script = preload("res://items/rocket_nut.gd")

const DASH_BERRY: StringName = &"dash_berry"
const BUBBLE_SHIELD: StringName = &"bubble_shield"
const STICKY_FRUIT: StringName = &"sticky_fruit"
const SHOCKWAVE: StringName = &"shockwave"
const ROCKET_NUT: StringName = &"rocket_nut"
const RECOVERY_FEATHER: StringName = &"recovery_feather"

const ITEM_IDS: Array[StringName] = [
	DASH_BERRY,
	BUBBLE_SHIELD,
	STICKY_FRUIT,
	SHOCKWAVE,
	ROCKET_NUT,
	RECOVERY_FEATHER,
]

const DISPLAY_NAMES := {
	DASH_BERRY: "DASH BERRY",
	BUBBLE_SHIELD: "BUBBLE SHIELD",
	STICKY_FRUIT: "STICKY FRUIT",
	SHOCKWAVE: "SHOCKWAVE",
	ROCKET_NUT: "ROCKET NUT",
	RECOVERY_FEATHER: "RECOVERY FEATHER",
}

const FRONT_WEIGHTS := {
	DASH_BERRY: 8.0,
	BUBBLE_SHIELD: 18.0,
	STICKY_FRUIT: 30.0,
	SHOCKWAVE: 12.0,
	ROCKET_NUT: 24.0,
	RECOVERY_FEATHER: 8.0,
}
const MID_WEIGHTS := {
	DASH_BERRY: 20.0,
	BUBBLE_SHIELD: 18.0,
	STICKY_FRUIT: 17.0,
	SHOCKWAVE: 16.0,
	ROCKET_NUT: 17.0,
	RECOVERY_FEATHER: 12.0,
}
const BACK_WEIGHTS := {
	DASH_BERRY: 28.0,
	BUBBLE_SHIELD: 15.0,
	STICKY_FRUIT: 8.0,
	SHOCKWAVE: 22.0,
	ROCKET_NUT: 10.0,
	RECOVERY_FEATHER: 17.0,
}

const DASH_DURATION := 2.0
const DASH_SPEED_MULTIPLIER := 1.48
const SHIELD_DURATION := 5.0
const HIT_IMMUNITY_DURATION := 0.75
const SHOCKWAVE_RADIUS := 7.5
const ROCKET_TARGET_DISTANCE := 52.0

var _rng := RandomNumberGenerator.new()
var _dash_effects: Dictionary = {}
var _shield_effects: Dictionary = {}
var _slow_effects: Dictionary = {}
var _hit_immunity: Dictionary = {}
var _last_used_item: Dictionary = {}

func _ready() -> void:
	_rng.randomize()

func _process(delta: float) -> void:
	_update_dash_effects()
	_update_slow_effects(delta)
	_update_shields()
	_update_hit_immunity()

func is_valid_item(item_id: StringName) -> bool:
	return ITEM_IDS.has(item_id)

func get_display_name(item_id: StringName) -> String:
	if item_id == &"":
		return "—"
	return str(DISPLAY_NAMES.get(item_id, String(item_id).to_upper()))

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
	var item_id := roll_item_for_rank(rank, total)
	return grant_item(character, item_id)

func roll_item_for_rank(rank: int, total: int) -> StringName:
	var safe_total := maxi(1, total)
	var normalized := float(clampi(rank, 1, safe_total) - 1) / float(maxi(1, safe_total - 1))
	var weights: Dictionary
	if normalized <= 0.30:
		weights = FRONT_WEIGHTS
	elif normalized >= 0.70:
		weights = BACK_WEIGHTS
	else:
		weights = MID_WEIGHTS
	return _weighted_pick(weights)

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

	if not used:
		return false
	character.call("set_held_item", &"")
	_last_used_item[character.get_instance_id()] = item_id
	item_used.emit(character, item_id)
	print("ITEM USE racer=%s item=%s" % [_label(character), get_display_name(item_id)])
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
	if effect_id == &"dash":
		var data: Dictionary = _dash_effects.get(id, {})
		return not data.is_empty() and float(data.get("expires", 0.0)) > _now_seconds()
	if effect_id == &"slow":
		var data: Dictionary = _slow_effects.get(id, {})
		return not data.is_empty() and float(data.get("expires", 0.0)) > _now_seconds()
	if effect_id == &"shield":
		return has_shield(character)
	return false

func get_status_text(character: Node) -> String:
	if character == null:
		return "ITEM EMPTY"
	var now := _now_seconds()
	var id := character.get_instance_id()
	var dash: Dictionary = _dash_effects.get(id, {})
	if not dash.is_empty() and float(dash.get("expires", 0.0)) > now:
		return "DASH ACTIVE %.1fs" % (float(dash.get("expires", 0.0)) - now)
	if has_shield(character):
		return "SHIELD ACTIVE %.1fs" % (float(_shield_effects[id]) - now)
	var slow: Dictionary = _slow_effects.get(id, {})
	if not slow.is_empty() and float(slow.get("expires", 0.0)) > now:
		return "HIT RECOVERY %.1fs" % (float(slow.get("expires", 0.0)) - now)
	if character.has_method("get_held_item") and StringName(character.call("get_held_item")) != &"":
		return "ITEM READY · Q / B"
	return "ITEM EMPTY"

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

func set_test_seed(seed: int) -> void:
	_rng.seed = seed

func get_last_used_item(character: Node) -> StringName:
	if character == null:
		return &""
	return StringName(_last_used_item.get(character.get_instance_id(), &""))

func reset_runtime() -> void:
	_dash_effects.clear()
	_shield_effects.clear()
	_slow_effects.clear()
	_hit_immunity.clear()
	_last_used_item.clear()

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

func _weighted_pick(weights: Dictionary) -> StringName:
	var total := 0.0
	for item_id in ITEM_IDS:
		total += float(weights.get(item_id, 0.0))
	if total <= 0.0:
		return DASH_BERRY
	var roll := _rng.randf_range(0.0, total)
	var cursor := 0.0
	for item_id in ITEM_IDS:
		cursor += float(weights.get(item_id, 0.0))
		if roll <= cursor:
			return item_id
	return ITEM_IDS[ITEM_IDS.size() - 1]

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
			controller.rotation.y += sin(now * 18.0 + float(id % 7)) * 0.55 * delta

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

func _now_seconds() -> float:
	return Time.get_ticks_msec() * 0.001

func _label(character: Node) -> String:
	if character is Node3D and RaceManager.racers.has(character):
		return RaceManager.get_racer_label(character)
	return character.name if character != null else "Unknown"
