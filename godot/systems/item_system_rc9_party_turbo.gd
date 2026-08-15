extends "res://systems/item_system.gd"

## RC9 party-racing item adapter.
##
## Keeps the existing ItemSystem implementation authoritative for every legacy
## item, while adding one explicit catch-up item: WILD TURBO. The adapter is the
## production autoload, so all existing ItemSystem calls continue through the
## same singleton/API instead of creating a competing item system.

const WILD_TURBO: StringName = &"wild_turbo"

const WILD_TURBO_DURATION: float = 1.50
const WILD_TURBO_INITIAL_SPEED_MULTIPLIER: float = 1.38
const WILD_TURBO_SPEED_MULTIPLIER: float = 1.68
const WILD_TURBO_ACCELERATION_MULTIPLIER: float = 1.50
const WILD_TURBO_HANDLING_MULTIPLIER: float = 1.05
const WILD_TURBO_CANONICAL_SPEED_CAP: float = 1.80
const WILD_TURBO_FRONT_WEIGHT: float = 2.0
const WILD_TURBO_MID_WEIGHT: float = 6.0
const WILD_TURBO_BACK_WEIGHT: float = 12.0

var _wild_turbo_effects: Dictionary = {}

func _ready() -> void:
	super._ready()
	_register_wild_turbo_definition()
	print("ITEM SYSTEM RC9 PARTY TURBO READY items=%d wild_turbo=true weights=%.0f/%.0f/%.0f duration=%.2f speed=%.2fx cap=%.2fx" % [
		get_item_count(), WILD_TURBO_FRONT_WEIGHT, WILD_TURBO_MID_WEIGHT, WILD_TURBO_BACK_WEIGHT,
		WILD_TURBO_DURATION, WILD_TURBO_SPEED_MULTIPLIER, WILD_TURBO_CANONICAL_SPEED_CAP,
	])

func _process(delta: float) -> void:
	super._process(delta)
	_update_wild_turbo_effects(delta)

func is_valid_item(item_id: StringName) -> bool:
	return item_id == WILD_TURBO or super.is_valid_item(item_id)

func is_new_item(item_id: StringName) -> bool:
	return item_id == WILD_TURBO or super.is_new_item(item_id)

func get_item_count() -> int:
	return super.get_item_count() + 1

func get_definition(item_id: StringName) -> WildDashItemDefinition:
	if item_id == WILD_TURBO and not _definitions.has(WILD_TURBO):
		_register_wild_turbo_definition()
	return super.get_definition(item_id)

func roll_item_for_rank(rank: int, total: int, history: Array = []) -> StringName:
	var safe_total: int = maxi(1, total)
	var normalized: float = float(clampi(rank, 1, safe_total) - 1) / float(maxi(1, safe_total - 1))
	var band: StringName = &"mid"
	if normalized <= 0.30:
		band = &"front"
	elif normalized >= 0.70:
		band = &"back"
	return _weighted_pick(band, history)

func use_held_item(character: Node) -> bool:
	if character == null or not character.has_method("get_held_item") or not character.has_method("set_held_item"):
		return false
	var item_id: StringName = StringName(character.call("get_held_item"))
	if item_id != WILD_TURBO:
		return super.use_held_item(character)
	if not _use_wild_turbo(character):
		return false
	character.call("set_held_item", &"")
	_last_used_item[character.get_instance_id()] = WILD_TURBO
	_usage_counts[WILD_TURBO] = int(_usage_counts.get(WILD_TURBO, 0)) + 1
	item_used.emit(character, WILD_TURBO)
	var rank: int = RaceManager.get_rank(character as Node3D) if character is Node3D else 0
	print("ITEM USE racer=%s item=WILD_TURBO rank=%d duration=%.2f speed_multiplier=%.2f acceleration_multiplier=%.2f cap=%.2f" % [
		_label(character), rank, WILD_TURBO_DURATION, WILD_TURBO_SPEED_MULTIPLIER,
		WILD_TURBO_ACCELERATION_MULTIPLIER, WILD_TURBO_CANONICAL_SPEED_CAP,
	])
	return true

func has_effect(character: Node, effect_id: StringName) -> bool:
	if character == null:
		return false
	if effect_id == WILD_TURBO or effect_id == &"wild_turbo":
		return _effect_active(_wild_turbo_effects, character.get_instance_id(), _now_seconds())
	return super.has_effect(character, effect_id)

func get_status_text(character: Node) -> String:
	if character != null:
		var id: int = character.get_instance_id()
		var now: float = _now_seconds()
		if _effect_active(_wild_turbo_effects, id, now):
			return "WILD TURBO %.1fs · MAX TURBO" % _effect_remaining(_wild_turbo_effects, id, now)
	return super.get_status_text(character)

func get_unique_used_count() -> int:
	var count: int = super.get_unique_used_count()
	if get_usage_count(WILD_TURBO) > 0:
		count += 1
	return count

func get_new_unique_used_count() -> int:
	var count: int = super.get_new_unique_used_count()
	if get_usage_count(WILD_TURBO) > 0:
		count += 1
	return count

func reset_runtime() -> void:
	for id_value: Variant in _wild_turbo_effects.keys():
		_cleanup_wild_turbo_effect(int(id_value))
	_wild_turbo_effects.clear()
	super.reset_runtime()

func get_wild_turbo_speed_cap(character: Node) -> float:
	if not (character is WildDashCharacterController):
		return 0.0
	return _wild_turbo_speed_cap(character as WildDashCharacterController)

func _weighted_pick(band: StringName, history: Array) -> StringName:
	var item_ids: Array[StringName] = _rc9_item_ids()
	var weighted: Dictionary = {}
	var total: float = 0.0
	for item_id: StringName in item_ids:
		var definition: WildDashItemDefinition = get_definition(item_id)
		var weight: float = definition.weight_for_band(band) if definition != null else 1.0
		weight *= _history_multiplier(item_id, history)
		weighted[item_id] = weight
		total += weight
	if total <= 0.0:
		return DASH_BERRY
	var roll: float = _rng.randf_range(0.0, total)
	var cursor: float = 0.0
	for item_id: StringName in item_ids:
		cursor += float(weighted.get(item_id, 0.0))
		if roll <= cursor:
			return item_id
	return item_ids[item_ids.size() - 1]

func _rc9_item_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for item_id: StringName in ITEM_IDS:
		result.append(item_id)
	result.append(WILD_TURBO)
	return result

func _register_wild_turbo_definition() -> void:
	if _definitions.has(WILD_TURBO):
		return
	_register_definition(
		WILD_TURBO,
		"WILD TURBO",
		&"speed",
		"WT",
		"MAX TURBO",
		WILD_TURBO_FRONT_WEIGHT,
		WILD_TURBO_MID_WEIGHT,
		WILD_TURBO_BACK_WEIGHT,
		WILD_TURBO_DURATION,
		WILD_TURBO_SPEED_MULTIPLIER,
		WILD_TURBO_ACCELERATION_MULTIPLIER
	)

func _use_wild_turbo(character: Node) -> bool:
	if not (character is WildDashCharacterController):
		return false
	var controller: WildDashCharacterController = character as WildDashCharacterController
	var id: int = controller.get_instance_id()
	if _wild_turbo_effects.has(id):
		_cleanup_wild_turbo_effect(id)

	var cap: float = _wild_turbo_speed_cap(controller)
	var initial_speed: float = minf(controller.max_speed * WILD_TURBO_INITIAL_SPEED_MULTIPLIER, cap)
	var base_turn_speed: float = controller.turn_speed
	var turbo_turn_speed: float = base_turn_speed * WILD_TURBO_HANDLING_MULTIPLIER
	controller.current_speed = maxf(controller.current_speed, initial_speed)
	controller.turn_speed = turbo_turn_speed

	var vfx: Node3D = _spawn_wild_turbo_vfx(controller)
	_wild_turbo_effects[id] = {
		"character": controller,
		"expires": _now_seconds() + WILD_TURBO_DURATION,
		"base_turn_speed": base_turn_speed,
		"turbo_turn_speed": turbo_turn_speed,
		"vfx": vfx,
	}

	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx_id", "item", 1.0)
		if controller.has_meta(&"wild_tide_terrain"):
			audio.call("play_sfx_id", "splash", 0.86)
	return true

func _update_wild_turbo_effects(delta: float) -> void:
	var now: float = _now_seconds()
	for id_value: Variant in _wild_turbo_effects.keys():
		var id: int = int(id_value)
		var data: Dictionary = _wild_turbo_effects.get(id, {})
		var character_value: Variant = data.get("character")
		if character_value == null or not is_instance_valid(character_value):
			_cleanup_wild_turbo_effect(id)
			continue
		if float(data.get("expires", 0.0)) <= now:
			_cleanup_wild_turbo_effect(id)
			continue
		if not (character_value is WildDashCharacterController):
			_cleanup_wild_turbo_effect(id)
			continue

		var controller: WildDashCharacterController = character_value as WildDashCharacterController
		var cap: float = _wild_turbo_speed_cap(controller)
		var sustained: float = minf(controller.max_speed * WILD_TURBO_SPEED_MULTIPLIER, cap)
		var turbo_acceleration: float = controller.acceleration * WILD_TURBO_ACCELERATION_MULTIPLIER
		controller.current_speed = move_toward(controller.current_speed, sustained, turbo_acceleration * delta)
		var minimum_burst: float = minf(controller.max_speed * 1.48, cap)
		controller.current_speed = maxf(controller.current_speed, minimum_burst)

		var vfx_value: Variant = data.get("vfx")
		if vfx_value is Node3D and is_instance_valid(vfx_value):
			var vfx: Node3D = vfx_value as Node3D
			vfx.scale.z = 0.88 + sin(now * 24.0) * 0.10

func _cleanup_wild_turbo_effect(id: int) -> void:
	var data: Dictionary = _wild_turbo_effects.get(id, {})
	if data.is_empty():
		return
	var character_value: Variant = data.get("character")
	if character_value is WildDashCharacterController and is_instance_valid(character_value):
		var controller: WildDashCharacterController = character_value as WildDashCharacterController
		var base_turn: float = float(data.get("base_turn_speed", controller.turn_speed))
		var turbo_turn: float = float(data.get("turbo_turn_speed", controller.turn_speed))
		# Only restore when another terrain/system has not intentionally replaced
		# turn_speed while Turbo was active.
		if absf(controller.turn_speed - turbo_turn) <= 0.02:
			controller.turn_speed = base_turn
	var vfx_value: Variant = data.get("vfx")
	if vfx_value is Node and is_instance_valid(vfx_value):
		(vfx_value as Node).queue_free()
	_wild_turbo_effects.erase(id)

func _wild_turbo_speed_cap(controller: WildDashCharacterController) -> float:
	if controller == null:
		return 0.0
	var canonical_max: float = controller.max_speed
	var definition: WildDashAnimalDefinition = controller.get_animal_definition()
	if definition != null and definition.max_speed > 0.01:
		canonical_max = definition.max_speed
	return maxf(controller.max_speed, canonical_max * WILD_TURBO_CANONICAL_SPEED_CAP)

func _spawn_wild_turbo_vfx(controller: WildDashCharacterController) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "WildTurboVFX"
	root.position = Vector3(0.0, 0.58, 1.55)
	controller.add_child(root)

	var dry_material: StandardMaterial3D = _turbo_material(Color(1.0, 0.76, 0.10), Color(1.0, 0.34, 0.04), 2.6)
	var water_material: StandardMaterial3D = _turbo_material(Color(0.35, 0.96, 1.0), Color(0.05, 0.72, 1.0), 2.8)
	var material: StandardMaterial3D = water_material if controller.has_meta(&"wild_tide_terrain") else dry_material
	for side: float in [-1.0, 1.0]:
		var streak: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(0.13, 0.10, 4.4)
		streak.mesh = mesh
		streak.position = Vector3(side * 0.68, 0.0, 1.35)
		streak.material_override = material
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(streak)
		if controller.has_meta(&"wild_tide_terrain"):
			var foam: MeshInstance3D = MeshInstance3D.new()
			var foam_mesh: BoxMesh = BoxMesh.new()
			foam_mesh.size = Vector3(0.26, 0.035, 3.6)
			foam.mesh = foam_mesh
			foam.position = Vector3(side * 0.78, -0.42, 1.15)
			foam.material_override = water_material
			foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(foam)
	return root

func _turbo_material(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
