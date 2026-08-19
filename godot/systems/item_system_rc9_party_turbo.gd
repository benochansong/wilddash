extends "res://systems/item_system.gd"

## RC9 production ItemSystem adapter. Base ItemSystem owns the original twelve
## items; this autoload adds the rare WILD TURBO plus the emergency Shockwave /
## Wind power pass without creating a second inventory system.

const WILD_TURBO: StringName = &"wild_turbo"
const WILD_TURBO_DURATION := 2.25
const WILD_TURBO_INITIAL := 1.45
const WILD_TURBO_SPEED := 1.80
const WILD_TURBO_ACCEL := 2.50
const WILD_TURBO_HANDLING := 1.08
const WILD_TURBO_CAP := 1.80
const WILD_TURBO_FRONT_WEIGHT := 3.0
const WILD_TURBO_MID_WEIGHT := 8.0
const WILD_TURBO_BACK_WEIGHT := 15.0
const WILD_TURBO_LAST_WEIGHT := 22.0

const POWER_SHOCKWAVE_RADIUS := 8.50
const POWER_SHOCKWAVE_DURATION := 0.68
const POWER_SHOCKWAVE_SLOW := 0.72
const POWER_SHOCKWAVE_KNOCKBACK := 5.80
const POWER_WIND_RADIUS := 9.00
const POWER_WIND_PUSH := 3.80
const POWER_WIND_SELF_SPEED := 1.16

var _wild_turbo_effects: Dictionary = {}

func _ready() -> void:
	super._ready()
	_register_wild_turbo()
	print("ITEM SYSTEM RC9 EMERGENCY READY items=%d wild_turbo=true duration=%.2f speed=%.2fx cap=%.2fx weights=%.0f/%.0f/%.0f/last%.0f" % [
		get_item_count(), WILD_TURBO_DURATION, WILD_TURBO_SPEED, WILD_TURBO_CAP,
		WILD_TURBO_FRONT_WEIGHT, WILD_TURBO_MID_WEIGHT, WILD_TURBO_BACK_WEIGHT, WILD_TURBO_LAST_WEIGHT,
	])

func _process(delta: float) -> void:
	super._process(delta)
	_update_wild_turbo(delta)

func is_valid_item(item_id: StringName) -> bool:
	return item_id == WILD_TURBO or super.is_valid_item(item_id)

func is_new_item(item_id: StringName) -> bool:
	return item_id == WILD_TURBO or super.is_new_item(item_id)

func get_item_count() -> int:
	return ITEM_IDS.size() + 1

func get_all_item_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for item_id: StringName in ITEM_IDS:
		result.append(item_id)
	result.append(WILD_TURBO)
	return result

func get_definition(item_id: StringName) -> WildDashItemDefinition:
	if _definitions.is_empty():
		super._register_definitions()
	if item_id == WILD_TURBO and not _definitions.has(WILD_TURBO):
		_register_wild_turbo()
	return super.get_definition(item_id)

func grant_item(character: Node, item_id: StringName) -> bool:
	var granted := super.grant_item(character, item_id)
	if granted and item_id == WILD_TURBO:
		var rank := RaceManager.get_rank(character as Node3D) if character is Node3D else 0
		var total := maxi(1, RaceManager.racers.size())
		print("WILD TURBO GRANTED racer=%s rank=%d/%d weight=%.1f" % [_label(character), rank, total, get_wild_turbo_weight_for_rank(rank, total)])
	return granted

func roll_item_for_rank(rank: int, total: int, history: Array = []) -> StringName:
	var safe_total := maxi(1, total)
	var normalized := float(clampi(rank, 1, safe_total) - 1) / float(maxi(1, safe_total - 1))
	var band: StringName = &"mid"
	if normalized <= 0.30:
		band = &"front"
	elif normalized >= 0.70:
		band = &"back"
	return _weighted_pick_rc9(band, history, get_wild_turbo_weight_for_rank(rank, safe_total))

func get_wild_turbo_weight_for_rank(rank: int, total: int) -> float:
	var safe_total := maxi(1, total)
	var safe_rank := clampi(rank, 1, safe_total)
	if safe_total > 1 and safe_rank == safe_total:
		return WILD_TURBO_LAST_WEIGHT
	var normalized := float(safe_rank - 1) / float(maxi(1, safe_total - 1))
	if normalized <= 0.30:
		return WILD_TURBO_FRONT_WEIGHT
	if normalized >= 0.70:
		return WILD_TURBO_BACK_WEIGHT
	return WILD_TURBO_MID_WEIGHT

func use_held_item(character: Node) -> bool:
	if character == null or not character.has_method("get_held_item"):
		return false
	var item_id := StringName(character.call("get_held_item"))
	if item_id == WILD_TURBO:
		if not _use_wild_turbo(character): return false
		_complete_special_use(character, WILD_TURBO)
		return true
	if item_id == SHOCKWAVE:
		if not _use_power_shockwave(character): return false
		_complete_special_use(character, SHOCKWAVE)
		return true
	if item_id == WIND_BOOST:
		if not _use_power_wind(character): return false
		_complete_special_use(character, WIND_BOOST)
		return true
	return super.use_held_item(character)

func _complete_special_use(character: Node, item_id: StringName) -> void:
	character.call("set_held_item", &"")
	_last_used_item[character.get_instance_id()] = item_id
	_usage_counts[item_id] = int(_usage_counts.get(item_id, 0)) + 1
	item_used.emit(character, item_id)
	if item_id == WILD_TURBO:
		print("WILD TURBO USE racer=%s duration=%.2f multiplier=%.2f accel=%.2f handling=%.2f" % [_label(character), WILD_TURBO_DURATION, WILD_TURBO_SPEED, WILD_TURBO_ACCEL, WILD_TURBO_HANDLING])
	else:
		print("ITEM USE racer=%s item=%s source=rc9_power" % [_label(character), get_display_name(item_id)])

func has_effect(character: Node, effect_id: StringName) -> bool:
	if character != null and effect_id == WILD_TURBO:
		return _effect_active(_wild_turbo_effects, character.get_instance_id(), _now_seconds())
	return super.has_effect(character, effect_id)

func get_status_text(character: Node) -> String:
	if character != null:
		var id := character.get_instance_id()
		var now := _now_seconds()
		if _effect_active(_wild_turbo_effects, id, now):
			return "WILD TURBO %.1fs · MAX TURBO" % _effect_remaining(_wild_turbo_effects, id, now)
		if character.has_method("get_held_item") and StringName(character.call("get_held_item")) == WILD_TURBO:
			return "WILD TURBO READY · Q / B"
	return super.get_status_text(character)

func get_unique_used_count() -> int:
	return super.get_unique_used_count() + (1 if get_usage_count(WILD_TURBO) > 0 else 0)

func get_new_unique_used_count() -> int:
	return super.get_new_unique_used_count() + (1 if get_usage_count(WILD_TURBO) > 0 else 0)

func reset_runtime() -> void:
	for id: Variant in _wild_turbo_effects.keys():
		_cleanup_wild_turbo(int(id))
	_wild_turbo_effects.clear()
	super.reset_runtime()

func get_wild_turbo_speed_cap(character: Node) -> float:
	return _canonical_max(character as WildDashCharacterController) * WILD_TURBO_CAP if character is WildDashCharacterController else 0.0

func _weighted_pick_rc9(band: StringName, history: Array, wild_weight: float) -> StringName:
	var ids := get_all_item_ids()
	var weighted: Dictionary = {}
	var total := 0.0
	for item_id: StringName in ids:
		var weight := wild_weight if item_id == WILD_TURBO else get_definition(item_id).weight_for_band(band)
		weight *= _history_multiplier(item_id, history)
		weighted[item_id] = weight
		total += weight
	if total <= 0.0:
		return DASH_BERRY
	var roll := _rng.randf_range(0.0, total)
	var cursor := 0.0
	for item_id: StringName in ids:
		cursor += float(weighted.get(item_id, 0.0))
		if roll <= cursor:
			return item_id
	return ids[-1]

func _register_wild_turbo() -> void:
	if _definitions.has(WILD_TURBO): return
	_register_definition(WILD_TURBO, "WILD TURBO", &"speed", "WT", "WILD TURBO",
		WILD_TURBO_FRONT_WEIGHT, WILD_TURBO_MID_WEIGHT, WILD_TURBO_BACK_WEIGHT,
		WILD_TURBO_DURATION, WILD_TURBO_SPEED, WILD_TURBO_ACCEL)

func _use_wild_turbo(character: Node) -> bool:
	if not character is WildDashCharacterController: return false
	var racer := character as WildDashCharacterController
	var id := racer.get_instance_id()
	if _wild_turbo_effects.has(id): _cleanup_wild_turbo(id)
	var canonical := _canonical_max(racer)
	var cap := canonical * WILD_TURBO_CAP
	racer.current_speed = maxf(racer.current_speed, canonical * WILD_TURBO_INITIAL)
	var base_turn := racer.turn_speed
	var turbo_turn := base_turn * WILD_TURBO_HANDLING
	racer.turn_speed = turbo_turn
	var vfx := _spawn_turbo_vfx(racer)
	var camera := racer.get_viewport().get_camera_3d()
	var base_fov := camera.fov if camera != null else 0.0
	var turbo_fov := minf(96.0, base_fov + 10.0) if camera != null else 0.0
	if camera != null: camera.fov = turbo_fov
	_wild_turbo_effects[id] = {"character": racer, "expires": _now_seconds() + WILD_TURBO_DURATION,
		"base_turn": base_turn, "turbo_turn": turbo_turn, "vfx": vfx, "camera": camera,
		"base_fov": base_fov, "turbo_fov": turbo_fov}
	racer.set_meta(&"wild_turbo_active", true)
	AudioManager.play_sfx_id("skill", 1.0)
	AudioManager.play_sfx_id("item", 1.0)
	if racer.has_meta(&"wild_tide_terrain"): AudioManager.play_sfx_id("splash", 0.92)
	print("WILD TURBO SPEED CAP racer=%s canonical=%.2f initial=%.2f cap=%.2f multiplier=%.2f" % [_label(racer), canonical, canonical * WILD_TURBO_INITIAL, cap, WILD_TURBO_CAP])
	return true

func _update_wild_turbo(delta: float) -> void:
	var now := _now_seconds()
	for id_value: Variant in _wild_turbo_effects.keys():
		var id := int(id_value)
		var data: Dictionary = _wild_turbo_effects.get(id, {})
		var racer_value: Variant = data.get("character", null)
		if racer_value == null or not is_instance_valid(racer_value):
			_wild_turbo_effects.erase(id)
			continue
		var racer := racer_value as WildDashCharacterController
		if racer == null:
			_wild_turbo_effects.erase(id)
			continue
		if float(data.get("expires", 0.0)) <= now:
			_cleanup_wild_turbo(id)
			continue
		var canonical := _canonical_max(racer)
		var cap := canonical * WILD_TURBO_CAP
		racer.current_speed = minf(cap, move_toward(racer.current_speed, cap, racer.acceleration * WILD_TURBO_ACCEL * delta))

func _cleanup_wild_turbo(id: int) -> void:
	var data: Dictionary = _wild_turbo_effects.get(id, {})
	if data.is_empty(): return
	var racer_value: Variant = data.get("character", null)
	if racer_value != null and is_instance_valid(racer_value):
		var racer := racer_value as WildDashCharacterController
		if racer != null:
			if absf(racer.turn_speed - float(data.get("turbo_turn", racer.turn_speed))) <= 0.03:
				racer.turn_speed = float(data.get("base_turn", racer.turn_speed))
			racer.remove_meta(&"wild_turbo_active")
	var camera_value: Variant = data.get("camera", null)
	if camera_value != null and is_instance_valid(camera_value):
		var camera := camera_value as Camera3D
		if camera != null and absf(camera.fov - float(data.get("turbo_fov", camera.fov))) <= 0.2:
			camera.fov = float(data.get("base_fov", camera.fov))
	var vfx_value: Variant = data.get("vfx", null)
	if vfx_value != null and is_instance_valid(vfx_value):
		var vfx := vfx_value as Node
		if vfx != null:
			vfx.queue_free()
	_wild_turbo_effects.erase(id)

func _canonical_max(racer: WildDashCharacterController) -> float:
	if racer == null: return 0.0
	var definition := racer.get_animal_definition()
	return definition.max_speed if definition != null and definition.max_speed > 0.01 else racer.max_speed

func _use_power_shockwave(character: Node) -> bool:
	if not character is WildDashCharacterController: return false
	var source := character as WildDashCharacterController
	var hits := 0
	for value: Variant in RaceManager.racers:
		var target := value as WildDashCharacterController
		if target == null or target == source or target.finished: continue
		if source.global_position.distance_to(target.global_position) <= POWER_SHOCKWAVE_RADIUS:
			if apply_attack(target, source, &"shockwave", POWER_SHOCKWAVE_DURATION, POWER_SHOCKWAVE_SLOW, POWER_SHOCKWAVE_KNOCKBACK): hits += 1
	print("SHOCKWAVE POWER RESOLVE racer=%s hits=%d radius=%.1f knockback=%.1f speed_loss=%.0f%%" % [_label(source), hits, POWER_SHOCKWAVE_RADIUS, POWER_SHOCKWAVE_KNOCKBACK, (1.0 - POWER_SHOCKWAVE_SLOW) * 100.0])
	return true

func _use_power_wind(character: Node) -> bool:
	if not character is WildDashCharacterController: return false
	var source := character as WildDashCharacterController
	source.current_speed = maxf(source.current_speed, source.max_speed * POWER_WIND_SELF_SPEED)
	var forward := -source.global_transform.basis.z.normalized()
	var hits := 0
	for value: Variant in RaceManager.racers:
		var target := value as WildDashCharacterController
		if target == null or target == source or target.finished: continue
		var offset := target.global_position - source.global_position
		if offset.length() <= POWER_WIND_RADIUS and offset.length() > 0.01 and forward.dot(offset.normalized()) >= 0.16:
			if apply_attack(target, source, &"wind_boost", 0.18, 0.94, POWER_WIND_PUSH): hits += 1
	print("WIND BOOST POWER RESOLVE racer=%s hits=%d radius=%.1f push=%.1f" % [_label(source), hits, POWER_WIND_RADIUS, POWER_WIND_PUSH])
	return true

func _spawn_turbo_vfx(racer: WildDashCharacterController) -> Node3D:
	var root := Node3D.new()
	root.name = "WildTurboVFX"
	root.position = Vector3(0.0, 0.58, 1.55)
	racer.add_child(root)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.96, 1.0) if racer.has_meta(&"wild_tide_terrain") else Color(1.0, 0.76, 0.10)
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 3.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for side: float in [-1.0, 1.0]:
		var streak := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.14, 0.10, 6.0)
		streak.mesh = mesh
		streak.position = Vector3(side * 0.72, 0.0, 1.75)
		streak.material_override = material
		root.add_child(streak)
	return root
