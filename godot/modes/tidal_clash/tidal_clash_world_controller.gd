class_name WildDashTidalClashWorldController
extends Node3D

const PROFILE_BOOTSTRAP_FRAMES: int = 180
const CURRENT_LOG_COOLDOWN_MSEC: int = 1800
const CURRENT_ZONES: Array[Dictionary] = [
	{"start": 0.10, "end": 0.16, "bonus": 1.06, "lane": -4.5},
	{"start": 0.60, "end": 0.69, "bonus": 1.07, "lane": 5.5},
	{"start": 0.86, "end": 0.94, "bonus": 1.09, "lane": 0.0},
]

var _track: WildDashTidalClashTrack
var _profiled_ids: Dictionary = {}
var _wake_multimesh: MultiMesh
var _wake_instance: MultiMeshInstance3D
var _wake_material: StandardMaterial3D
var _current_log_until: Dictionary = {}
var _drivers_by_id: Dictionary = {}
var _ready_complete: bool = false

func _ready() -> void:
	process_priority = 20
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	for _attempt: int in range(PROFILE_BOOTSTRAP_FRAMES):
		_track = get_parent().get_node_or_null("TidalClashTrack") as WildDashTidalClashTrack
		if _track != null and not RaceManager.racers.is_empty():
			break
		await get_tree().physics_frame
	if _track == null:
		push_warning("TIDAL CLASH WORLD bootstrap skipped: track unavailable")
		return
	_apply_all_water_profiles()
	_discover_ai_drivers()
	_build_current_visuals()
	_build_wake_multimesh()
	_ready_complete = true
	print("TIDAL CLASH WATER WORLD READY water_ratio=100% compressed_species_profile=true heavy_wave_resistance=true light_escape=true wakes=multimesh currents=%d" % CURRENT_ZONES.size())

func _physics_process(delta: float) -> void:
	if not _ready_complete:
		return
	_apply_new_racer_profiles()
	if _drivers_by_id.is_empty():
		_discover_ai_drivers()
	_update_currents(delta)
	_update_wakes()

func _apply_new_racer_profiles() -> void:
	for value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer):
			continue
		if _profiled_ids.has(racer.get_instance_id()):
			continue
		_apply_water_profile(racer)

func _apply_all_water_profiles() -> void:
	for value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = value as WildDashCharacterController
		if racer != null and is_instance_valid(racer):
			_apply_water_profile(racer)

func _apply_water_profile(racer: WildDashCharacterController) -> void:
	if racer == null:
		return
	var racer_id: int = racer.get_instance_id()
	if _profiled_ids.has(racer_id):
		return
	_profiled_ids[racer_id] = true

	var multiplier: float = _round5_water_multiplier(racer.animal_id)
	racer.max_speed *= multiplier
	racer.cruise_speed *= multiplier
	racer.acceleration *= clampf(0.96 + (multiplier - 1.0) * 0.35, 0.92, 1.04)

	var turn_scale: float = _light_turn_scale(racer.animal_id)
	racer.turn_speed *= turn_scale

	racer.set_meta(&"wild_tide_terrain", WildDashTerrainAbilitySystem.TERRAIN_DEEP_WATER)
	racer.set_meta(&"tidal_clash_water", true)
	racer.set_meta(&"tidal_water_multiplier", multiplier)
	racer.set_meta(&"tidal_profile_max_speed", racer.max_speed)
	racer.set_meta(&"tidal_profile_turn_speed", racer.turn_speed)
	racer.set_meta(&"tidal_wave_resistance", _wave_resistance(racer.animal_id))
	racer.set_meta(&"tidal_whirlpool_pull_scale", _whirlpool_pull_scale(racer.animal_id))
	racer.set_meta(&"tidal_whirlpool_exit_accel", _whirlpool_exit_accel(racer.animal_id))
	print("TIDAL WATER PROFILE animal=%s multiplier=%.3f wave_resist=%.2f turn=%.2f whirlpool_pull=%.2f" % [
		String(racer.animal_id), multiplier, _wave_resistance(racer.animal_id),
		turn_scale, _whirlpool_pull_scale(racer.animal_id),
	])

func _round5_water_multiplier(animal_id: StringName) -> float:
	match animal_id:
		&"crocodile": return 1.09
		&"raccoon": return 1.02
		&"bear": return 1.01
		&"elephant": return 1.00
		&"boar": return 0.99
		&"wolf": return 0.99
		&"dog": return 1.00
		&"deer": return 0.98
		&"fox": return 0.98
		&"monkey": return 0.97
		&"cat": return 0.97
		&"rabbit": return 0.96
		_: return 0.99

func _wave_resistance(animal_id: StringName) -> float:
	match animal_id:
		&"elephant": return 0.65
		&"bear": return 0.75
		&"boar": return 0.80
		&"crocodile": return 0.78
		_: return 1.0

func _light_turn_scale(animal_id: StringName) -> float:
	match animal_id:
		&"rabbit": return 1.10
		&"cat": return 1.08
		&"fox": return 1.07
		_: return 1.0

func _whirlpool_pull_scale(animal_id: StringName) -> float:
	match animal_id:
		&"rabbit": return 0.84
		&"cat": return 0.86
		&"fox": return 0.88
		&"crocodile": return 0.90
		&"elephant": return 0.92
		_: return 1.0

func _whirlpool_exit_accel(animal_id: StringName) -> float:
	match animal_id:
		&"rabbit": return 1.12
		&"cat": return 1.10
		&"fox": return 1.09
		_: return 1.0

func _update_currents(delta: float) -> void:
	if not RaceManager.active or _track == null:
		return
	for value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer.finished:
			continue
		var progress: float = RaceManager.get_progress_percent(racer) * 0.01
		var zone: Dictionary = _current_zone(progress)
		if zone.is_empty():
			continue
		var direction: Vector3 = _track.route_direction(progress)
		var forward: Vector3 = -racer.global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() <= 0.001:
			continue
		forward = forward.normalized()
		var alignment: float = forward.dot(direction)
		var current_lane: float = float(zone.get("lane", 0.0))
		var lateral: float = _track.lateral_offset(racer.global_position, progress)
		var on_current_line: bool = absf(lateral - current_lane) <= 4.2
		_nudge_ai_to_current_line(racer, current_lane, progress)
		if not on_current_line:
			continue
		var profile_max: float = float(racer.get_meta(&"tidal_profile_max_speed", racer.max_speed))
		var turbo_active: bool = ItemSystem.has_effect(racer, ItemSystem.WILD_TURBO)
		if alignment >= 0.20:
			var bonus: float = float(zone.get("bonus", 1.07))
			var cap: float = profile_max * bonus
			if turbo_active:
				cap = maxf(cap, ItemSystem.get_wild_turbo_speed_cap(racer))
			racer.current_speed = move_toward(racer.current_speed, cap, racer.acceleration * 0.36 * delta)
			racer.set_meta(&"tidal_current_bonus", bonus)
			_log_current(racer, bonus)
		elif alignment <= -0.20 and not turbo_active:
			racer.current_speed = move_toward(racer.current_speed, profile_max * 0.92, racer.acceleration * 0.22 * delta)
			racer.set_meta(&"tidal_current_bonus", 0.96)

func _discover_ai_drivers() -> void:
	_drivers_by_id.clear()
	var parent_node: Node = get_parent()
	for node: Node in get_tree().get_nodes_in_group("wilddash_ai_driver"):
		if node == null or node.get_parent() != parent_node or not (node is WildDashAIController):
			continue
		var driver: WildDashAIController = node as WildDashAIController
		if driver.preserve_player_identity:
			continue
		var racer: WildDashCharacterController = driver.get_racer()
		if racer != null:
			_drivers_by_id[racer.get_instance_id()] = driver

func _nudge_ai_to_current_line(racer: WildDashCharacterController, lane: float, progress: float) -> void:
	var value: Variant = _drivers_by_id.get(racer.get_instance_id())
	if not (value is WildDashAIController) or not is_instance_valid(value):
		return
	var driver: WildDashAIController = value as WildDashAIController
	if Time.get_ticks_msec() < int(racer.get_meta(&"tidal_hazard_priority_until_msec", 0)):
		return
	var half_width: float = _track.get_width_at_progress(progress) * 0.5 - 3.0
	driver.preferred_lane = clampf(lerpf(driver.preferred_lane, lane, 0.06), -half_width, half_width)

func _build_current_visuals() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.58, 0.98, 1.0, 0.58)
	material.emission_enabled = true
	material.emission = Color(0.10, 0.72, 0.92)
	material.emission_energy_multiplier = 0.82
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var transforms: Array[Transform3D] = []
	for zone: Dictionary in CURRENT_ZONES:
		var start: float = float(zone.get("start", 0.0))
		var end: float = float(zone.get("end", start))
		var lane: float = float(zone.get("lane", 0.0))
		for sample_index: int in range(6):
			var progress: float = lerpf(start, end, (float(sample_index) + 0.5) / 6.0)
			var center: Vector3 = _track.sample_route(progress) + _track.route_right(progress) * lane
			var direction: Vector3 = _track.route_direction(progress)
			var yaw: float = atan2(direction.x, direction.z)
			var basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3(0.32, 0.025, 4.8))
			transforms.append(Transform3D(basis, center + Vector3.UP * 0.04))
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3.ONE
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = "OceanCurrentStreaks"
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func _current_zone(progress: float) -> Dictionary:
	for zone: Dictionary in CURRENT_ZONES:
		if progress >= float(zone.get("start", 0.0)) and progress <= float(zone.get("end", 0.0)):
			return zone
	return {}

func _log_current(racer: WildDashCharacterController, bonus: float) -> void:
	var now: int = Time.get_ticks_msec()
	var racer_id: int = racer.get_instance_id()
	if now < int(_current_log_until.get(racer_id, 0)):
		return
	_current_log_until[racer_id] = now + CURRENT_LOG_COOLDOWN_MSEC
	print("OCEAN CURRENT racer=%s bonus=%.2f" % [String(racer.animal_id).capitalize(), bonus])

func _build_wake_multimesh() -> void:
	_wake_material = StandardMaterial3D.new()
	_wake_material.albedo_color = Color(0.84, 0.98, 1.0, 0.72)
	_wake_material.emission_enabled = true
	_wake_material.emission = Color(0.18, 0.72, 0.92)
	_wake_material.emission_energy_multiplier = 0.82
	_wake_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wake_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3.ONE
	_wake_multimesh = MultiMesh.new()
	_wake_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_wake_multimesh.mesh = mesh
	_wake_multimesh.instance_count = maxi(2, RaceManager.racers.size() * 2)
	_wake_multimesh.visible_instance_count = 0
	_wake_instance = MultiMeshInstance3D.new()
	_wake_instance.name = "RacerWaterWakeMultiMesh"
	_wake_instance.multimesh = _wake_multimesh
	_wake_instance.material_override = _wake_material
	_wake_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wake_instance)

func _update_wakes() -> void:
	if _wake_multimesh == null:
		return
	var needed: int = maxi(2, RaceManager.racers.size() * 2)
	if _wake_multimesh.instance_count != needed:
		_wake_multimesh.instance_count = needed
	var instance_index: int = 0
	for value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer):
			continue
		var speed_ratio: float = clampf(racer.current_speed / maxf(1.0, racer.max_speed), 0.0, 2.0)
		var turbo: bool = ItemSystem.has_effect(racer, ItemSystem.WILD_TURBO)
		var length: float = lerpf(1.2, 4.8, clampf(speed_ratio, 0.0, 1.0))
		var width: float = 0.16
		if turbo:
			length = 8.5
			width = 0.24
		var basis: Basis = racer.global_transform.basis
		var forward: Vector3 = -basis.z
		forward.y = 0.0
		if forward.length_squared() <= 0.001:
			forward = Vector3.FORWARD
		else:
			forward = forward.normalized()
		var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
		var yaw: float = atan2(forward.x, forward.z)
		for side: float in [-1.0, 1.0]:
			if instance_index >= _wake_multimesh.instance_count:
				break
			var wake_basis: Basis = Basis(Vector3.UP, yaw)
			wake_basis = wake_basis.scaled(Vector3(width, 0.025, length))
			var position: Vector3 = racer.global_position - forward * (length * 0.52 + 0.65) + right * side * 0.55 + Vector3(0.0, -0.34, 0.0)
			_wake_multimesh.set_instance_transform(instance_index, Transform3D(wake_basis, position))
			instance_index += 1
	_wake_multimesh.visible_instance_count = instance_index
