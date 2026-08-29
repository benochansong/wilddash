class_name WildDashTidalClashHazardController
extends Node3D

const WAVES: Array[Dictionary] = [
	{"p": 0.225, "kind": "SMALL", "lane": -4.8},
	{"p": 0.278, "kind": "MEDIUM", "lane": 4.2},
	{"p": 0.332, "kind": "LARGE", "lane": 0.0},
	{"p": 0.365, "kind": "MEDIUM", "lane": -3.8},
]
const WHIRLPOOLS: Array[Dictionary] = [
	{"p": 0.445, "lane": -5.8},
	{"p": 0.505, "lane": 5.2},
	{"p": 0.558, "lane": 0.0},
]
const OUTER := 11.0
const MIDDLE := 7.0
const CORE := 3.5
const TIDAL_TRIGGER := 0.59
const TIDAL_START := 0.61
const TIDAL_END := 0.79
const TIDAL_TELEGRAPH := 1.50
const TIDAL_SWEEP := 3.40
const HAZARD_META: StringName = &"tidal_hazard_priority_until_msec"

var _track: WildDashTidalClashTrack
var _drivers: Dictionary = {}
var _wave_seen: Dictionary = {}
var _wave_guided: Dictionary = {}
var _ride_until: Dictionary = {}
var _whirlpool_zone: Dictionary = {}
var _drift_until: Dictionary = {}
var _tidal_phase: StringName = &"IDLE"
var _tidal_elapsed := 0.0
var _tidal_progress := TIDAL_START
var _tidal_hits: Dictionary = {}
var _tidal_visual: MeshInstance3D
var _foam: StandardMaterial3D
var _water_fx: StandardMaterial3D
var _ready_complete := false

func _ready() -> void:
	process_priority = 40
	_build_materials()
	call_deferred("_bootstrap")
	if not ItemSystem.item_used.is_connected(_on_item_used):
		ItemSystem.item_used.connect(_on_item_used)
	if not ItemSystem.item_hit.is_connected(_on_item_hit):
		ItemSystem.item_hit.connect(_on_item_hit)

func _exit_tree() -> void:
	if ItemSystem.item_used.is_connected(_on_item_used):
		ItemSystem.item_used.disconnect(_on_item_used)
	if ItemSystem.item_hit.is_connected(_on_item_hit):
		ItemSystem.item_hit.disconnect(_on_item_hit)

func _bootstrap() -> void:
	for _attempt: int in range(180):
		_track = get_parent().get_node_or_null("TidalClashTrack") as WildDashTidalClashTrack
		_discover_drivers()
		if _track != null and not RaceManager.racers.is_empty():
			break
		await get_tree().physics_frame
	if _track == null:
		push_warning("TIDAL CLASH HAZARD bootstrap skipped: track unavailable")
		return
	_build_visuals()
	_ready_complete = true
	print("TIDAL CLASH HAZARDS READY waves=%d whirlpools=%d tidal_wave=true telegraph=%.2fs instant_elimination=false" % [WAVES.size(), WHIRLPOOLS.size(), TIDAL_TELEGRAPH])

func _physics_process(delta: float) -> void:
	if not _ready_complete or not RaceManager.active:
		return
	if _drivers.is_empty():
		_discover_drivers()
	_update_waves(delta)
	_update_whirlpools(delta)
	_update_tidal(delta)
	_update_body_drift()

func _update_waves(delta: float) -> void:
	var now := Time.get_ticks_msec()
	for value: Variant in RaceManager.racers:
		var racer := value as WildDashCharacterController
		if racer == null or racer.finished:
			continue
		var p := RaceManager.get_progress_percent(racer) * 0.01
		for index: int in range(WAVES.size()):
			var wave := WAVES[index]
			var wp := float(wave.get("p", 0.0))
			if p >= wp - 0.035 and p < wp - 0.006:
				_guide_wave(racer, index, wave, p)
			if absf(p - wp) > 0.0055:
				continue
			var key := "%d:%d" % [racer.get_instance_id(), index]
			if _wave_seen.has(key):
				continue
			_wave_seen[key] = true
			var lane := float(wave.get("lane", 0.0))
			if absf(_track.lateral_offset(racer.global_position, p) - lane) <= 2.6:
				_start_wave_ride(racer, String(wave.get("kind", "SMALL")))
			else:
				_apply_wave_hit(racer, String(wave.get("kind", "SMALL")), p)
		var racer_id := racer.get_instance_id()
		if now < int(_ride_until.get(racer_id, 0)) and not ItemSystem.has_effect(racer, ItemSystem.WILD_TURBO):
			var profile_max := float(racer.get_meta(&"tidal_profile_max_speed", racer.max_speed))
			racer.current_speed = move_toward(racer.current_speed, profile_max * 1.06, racer.acceleration * 0.32 * delta)

func _apply_wave_hit(racer: WildDashCharacterController, kind: String, p: float) -> void:
	var retention := 1.0
	var push := 0.0
	var pop := 0.0
	if kind == "MEDIUM":
		retention = 0.955
		push = 1.10
	elif kind == "LARGE":
		retention = 0.90
		push = 2.10
		pop = 1.35
	var resistance := float(racer.get_meta(&"tidal_wave_resistance", 1.0))
	racer.current_speed *= retention
	if push > 0.0:
		var side := -1.0
		if racer.get_instance_id() % 2 != 0:
			side = 1.0
		racer.apply_knockback(_track.route_right(p) * side, push * resistance)
	if pop > 0.0 and racer.is_on_floor():
		racer.velocity.y = maxf(racer.velocity.y, pop)
	_set_hazard_priority(racer, 650)
	_spawn_ring(racer.global_position, 2.4 if kind == "LARGE" else 1.5)
	_play_sfx("wave", 0.64 if kind == "LARGE" else 0.42)
	print("OCEAN WAVE racer=%s type=%s speed_retention=%.3f resistance=%.2f" % [String(racer.animal_id).capitalize(), kind, retention, resistance])

func _start_wave_ride(racer: WildDashCharacterController, kind: String) -> void:
	_ride_until[racer.get_instance_id()] = Time.get_ticks_msec() + 1000
	var profile_max := float(racer.get_meta(&"tidal_profile_max_speed", racer.max_speed))
	racer.current_speed = maxf(racer.current_speed, profile_max * 1.05)
	print("WAVE RIDE racer=%s wave=%s bonus=1.06 duration=1.00" % [String(racer.animal_id).capitalize(), kind])

func _update_whirlpools(delta: float) -> void:
	for value: Variant in RaceManager.racers:
		var racer := value as WildDashCharacterController
		if racer == null or racer.finished:
			continue
		var best_distance := INF
		var best_center := Vector3.ZERO
		var best_p := 0.0
		for data: Dictionary in WHIRLPOOLS:
			var center := _whirlpool_center(data)
			var offset := racer.global_position - center
			offset.y = 0.0
			var distance := offset.length()
			if distance < best_distance:
				best_distance = distance
				best_center = center
				best_p = float(data.get("p", 0.0))
		if best_distance > OUTER:
			_restore_handling(racer)
			continue
		var zone: StringName = &"OUTER"
		if best_distance <= CORE:
			zone = &"CORE"
		elif best_distance <= MIDDLE:
			zone = &"MIDDLE"
		_apply_whirlpool(racer, zone, best_center, best_p, best_distance, delta)
		var racer_id := racer.get_instance_id()
		var previous := StringName(String(_whirlpool_zone.get(racer_id, &"")))
		if previous != zone:
			_whirlpool_zone[racer_id] = zone
			print("OCEAN HAZARD type=WHIRLPOOL racer=%s zone=%s" % [String(racer.animal_id).capitalize(), String(zone)])

func _apply_whirlpool(racer: WildDashCharacterController, zone: StringName, center: Vector3, p: float, distance: float, delta: float) -> void:
	var toward := center - racer.global_position
	toward.y = 0.0
	if toward.length_squared() <= 0.001:
		toward = _track.route_right(p)
	else:
		toward = toward.normalized()
	var pull_scale := float(racer.get_meta(&"tidal_whirlpool_pull_scale", 1.0))
	var profile_max := float(racer.get_meta(&"tidal_profile_max_speed", racer.max_speed))
	var base_turn := float(racer.get_meta(&"tidal_profile_turn_speed", racer.turn_speed))
	var handling := 0.92
	var speed := 0.97
	var pull := 0.75
	if zone == &"MIDDLE":
		handling = 0.90
		speed = 0.88
		pull = 1.40
	elif zone == &"CORE":
		handling = 0.86
		speed = 0.72
		pull = 2.10
		racer.rotate_y(1.25 * delta * pull_scale)
	racer.turn_speed = base_turn * handling
	if not ItemSystem.has_effect(racer, ItemSystem.WILD_TURBO):
		racer.current_speed = minf(racer.current_speed, profile_max * speed)
	racer.apply_knockback(toward, pull * pull_scale * delta * 4.2)
	_set_hazard_priority(racer, 420)
	_nudge_from_whirlpool(racer, center, p, distance)

func _restore_handling(racer: WildDashCharacterController) -> void:
	if racer.has_meta(&"tidal_profile_turn_speed"):
		racer.turn_speed = float(racer.get_meta(&"tidal_profile_turn_speed", racer.turn_speed))
	var exit_scale := float(racer.get_meta(&"tidal_whirlpool_exit_accel", 1.0))
	if exit_scale > 1.0 and not ItemSystem.has_effect(racer, ItemSystem.WILD_TURBO):
		var profile_max := float(racer.get_meta(&"tidal_profile_max_speed", racer.max_speed))
		racer.current_speed = minf(profile_max, racer.current_speed + racer.acceleration * (exit_scale - 1.0) * 0.025)

func _update_tidal(delta: float) -> void:
	if _tidal_phase == &"DONE":
		return
	if _tidal_phase == &"IDLE":
		if _leader_progress() < TIDAL_TRIGGER:
			return
		_tidal_phase = &"TELEGRAPH"
		_tidal_elapsed = 0.0
		_tidal_hits.clear()
		_set_hud("TIDAL WAVE →  SHIFT / JUMP / RIDE")
		_prepare_ai_for_tidal()
		_show_tidal(true, 0.28)
		_play_sfx("ui", 0.65)
		print("TIDAL WAVE phase=TELEGRAPH warning=1.50")
		return
	_tidal_elapsed += delta
	if _tidal_phase == &"TELEGRAPH":
		_show_tidal(true, 0.28 + 0.32 * clampf(_tidal_elapsed / TIDAL_TELEGRAPH, 0.0, 1.0))
		if _tidal_elapsed < TIDAL_TELEGRAPH:
			return
		_tidal_phase = &"ACTIVE"
		_tidal_elapsed = 0.0
		_play_sfx("wave", 0.92)
		print("TIDAL WAVE phase=ACTIVE")
		return
	var t := clampf(_tidal_elapsed / TIDAL_SWEEP, 0.0, 1.0)
	_tidal_progress = lerpf(TIDAL_START, TIDAL_END, t)
	_show_tidal(true, 0.88)
	_apply_tidal_hits(_tidal_progress)
	if t >= 1.0:
		_tidal_phase = &"DONE"
		_show_tidal(false, 0.0)
		_set_hud("FINAL TIDAL SPRINT — TURBO WINDOW")
		print("TIDAL WAVE phase=DONE")

func _apply_tidal_hits(p: float) -> void:
	for value: Variant in RaceManager.racers:
		var racer := value as WildDashCharacterController
		if racer == null or racer.finished:
			continue
		var racer_id := racer.get_instance_id()
		if _tidal_hits.has(racer_id):
			continue
		var rp := RaceManager.get_progress_percent(racer) * 0.01
		if absf(rp - p) > 0.009:
			continue
		_tidal_hits[racer_id] = true
		var lateral := _track.lateral_offset(racer.global_position, rp)
		var riding := absf(lateral) <= 2.7
		var jumping := not racer.is_on_floor() and racer.velocity.y > 0.25
		if riding or jumping:
			print("TIDAL WAVE EVADE racer=%s method=%s" % [String(racer.animal_id), "RIDE" if riding else "JUMP"])
			continue
		var resistance := float(racer.get_meta(&"tidal_wave_resistance", 1.0))
		var sign_value := -1.0
		if lateral < 0.0:
			sign_value = 1.0
		racer.current_speed *= 0.84
		racer.apply_knockback(_track.route_right(rp) * sign_value, 4.25 * resistance)
		racer.velocity.y = maxf(racer.velocity.y, 1.85)
		_set_hazard_priority(racer, 900)
		_spawn_ring(racer.global_position, 3.3)
		_play_sfx("splash", 0.88)
		print("TIDAL WAVE HIT racer=%s speed_loss=16%% resistance=%.2f instant_death=false" % [String(racer.animal_id).capitalize(), resistance])

func _update_body_drift() -> void:
	var now := Time.get_ticks_msec()
	for value: Variant in RaceManager.racers:
		var racer := value as WildDashCharacterController
		if racer == null or racer.finished:
			continue
		var racer_id := racer.get_instance_id()
		if now < int(_drift_until.get(racer_id, 0)):
			continue
		var knockback := racer.get_knockback_velocity()
		knockback.y = 0.0
		if knockback.length() < 2.0:
			continue
		_drift_until[racer_id] = now + 480
		var extra := clampf(knockback.length() * 0.12, 0.25, 0.85)
		racer.apply_knockback(knockback.normalized(), extra)
		_spawn_splash(racer.global_position, knockback.normalized())

func _guide_wave(racer: WildDashCharacterController, index: int, wave: Dictionary, p: float) -> void:
	var driver := _driver_for(racer)
	if driver == null:
		return
	var key := "%d:%d" % [racer.get_instance_id(), index]
	if _wave_guided.has(key):
		return
	_wave_guided[key] = true
	var half_width := _track.get_width_at_progress(p) * 0.5 - 3.0
	driver.preferred_lane = clampf(float(wave.get("lane", 0.0)), -half_width, half_width)
	_set_hazard_priority(racer, 950)

func _nudge_from_whirlpool(racer: WildDashCharacterController, center: Vector3, p: float, distance: float) -> void:
	var driver := _driver_for(racer)
	if driver == null:
		return
	var center_lane := _track.lateral_offset(center, p)
	var racer_lane := _track.lateral_offset(racer.global_position, p)
	var sign_value := -1.0
	if racer_lane > center_lane:
		sign_value = 1.0
	var strength := 0.72
	if distance <= MIDDLE:
		strength = 1.25
	if racer.animal_id in [&"rabbit", &"cat", &"fox"]:
		strength *= 1.18
	var half_width := _track.get_width_at_progress(p) * 0.5 - 3.0
	driver.preferred_lane = clampf(driver.preferred_lane + sign_value * strength, -half_width, half_width)

func _prepare_ai_for_tidal() -> void:
	for value: Variant in RaceManager.racers:
		var racer := value as WildDashCharacterController
		if racer == null or racer.is_player:
			continue
		var driver := _driver_for(racer)
		if driver == null:
			continue
		var p := RaceManager.get_progress_percent(racer) * 0.01
		var half_width := _track.get_width_at_progress(p) * 0.5 - 3.0
		var lane_sign := -1.0
		if racer.get_instance_id() % 2 != 0:
			lane_sign = 1.0
		driver.preferred_lane = clampf(lane_sign * minf(6.0, half_width), -half_width, half_width)
		_set_hazard_priority(racer, int((TIDAL_TELEGRAPH + 0.45) * 1000.0))
		if racer.animal_id in [&"rabbit", &"cat", &"fox"] and racer.is_on_floor():
			racer.velocity.y = maxf(racer.velocity.y, racer.jump_velocity * 0.72)

func _discover_drivers() -> void:
	_drivers.clear()
	for node: Node in get_tree().get_nodes_in_group("wilddash_ai_driver"):
		if node == null or node.get_parent() != get_parent() or not (node is WildDashAIController):
			continue
		var driver := node as WildDashAIController
		if driver.preserve_player_identity:
			continue
		var racer := driver.get_racer()
		if racer != null:
			_drivers[racer.get_instance_id()] = driver

func _driver_for(racer: WildDashCharacterController) -> WildDashAIController:
	var value: Variant = _drivers.get(racer.get_instance_id())
	if value is WildDashAIController and is_instance_valid(value):
		return value as WildDashAIController
	return null

func _leader_progress() -> float:
	var best := 0.0
	for value: Variant in RaceManager.racers:
		var racer := value as WildDashCharacterController
		if racer != null and not racer.finished:
			best = maxf(best, RaceManager.get_progress_percent(racer) * 0.01)
	return best

func _whirlpool_center(data: Dictionary) -> Vector3:
	var p := float(data.get("p", 0.0))
	return _track.sample_route(p) + _track.route_right(p) * float(data.get("lane", 0.0)) + Vector3.UP * 0.02

func _set_hazard_priority(racer: WildDashCharacterController, duration_msec: int) -> void:
	racer.set_meta(HAZARD_META, Time.get_ticks_msec() + duration_msec)

func _build_materials() -> void:
	_foam = StandardMaterial3D.new()
	_foam.albedo_color = Color(0.90, 1.0, 1.0, 0.80)
	_foam.emission_enabled = true
	_foam.emission = Color(0.36, 0.88, 1.0)
	_foam.emission_energy_multiplier = 0.90
	_foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_water_fx = _foam.duplicate() as StandardMaterial3D
	_water_fx.albedo_color = Color(0.08, 0.72, 0.90, 0.55)

func _build_visuals() -> void:
	for data: Dictionary in WAVES:
		var p := float(data.get("p", 0.0))
		var mesh := BoxMesh.new()
		mesh.size = Vector3(_track.get_width_at_progress(p) - 3.0, 0.08, 2.4)
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.position = _track.sample_route(p) + Vector3.UP * 0.07
		var direction := _track.route_direction(p)
		visual.rotation.y = atan2(direction.x, direction.z)
		visual.material_override = _foam
		add_child(visual)
	for data: Dictionary in WHIRLPOOLS:
		for radius: float in [3.1, 5.9, 9.2]:
			var torus := TorusMesh.new()
			torus.inner_radius = radius - 0.10
			torus.outer_radius = radius + 0.10
			torus.rings = 20
			torus.ring_segments = 8
			var ring := MeshInstance3D.new()
			ring.mesh = torus
			ring.position = _whirlpool_center(data)
			ring.material_override = _water_fx
			add_child(ring)
	_tidal_visual = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	_tidal_visual.mesh = mesh
	_tidal_visual.material_override = _foam
	_tidal_visual.visible = false
	add_child(_tidal_visual)

func _show_tidal(visible: bool, intensity: float) -> void:
	if _tidal_visual == null:
		return
	_tidal_visual.visible = visible
	if not visible:
		return
	var center := _track.sample_route(_tidal_progress)
	var direction := _track.route_direction(_tidal_progress)
	var basis := Basis(Vector3.UP, atan2(direction.x, direction.z)).scaled(Vector3(_track.get_width_at_progress(_tidal_progress) + 2.0, 0.24 + intensity * 0.55, 3.4))
	_tidal_visual.transform = Transform3D(basis, center + Vector3.UP * (0.12 + intensity * 0.26))

func _spawn_ring(position: Vector3, radius: float) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(0.2, radius - 0.12)
	torus.outer_radius = radius + 0.12
	torus.rings = 18
	torus.ring_segments = 7
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.position = position + Vector3.UP * 0.06
	ring.material_override = _foam
	add_child(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector3(1.65, 1.0, 1.65), 0.32)
	tween.tween_callback(ring.queue_free)

func _spawn_splash(position: Vector3, direction: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.7, 0.14, 0.48)
	var splash := MeshInstance3D.new()
	splash.mesh = mesh
	splash.position = position + direction * 0.8 + Vector3.UP * 0.08
	splash.rotation.y = atan2(direction.x, direction.z)
	splash.material_override = _foam
	add_child(splash)
	var tween := create_tween()
	tween.tween_property(splash, "scale", Vector3(1.35, 1.0, 1.35), 0.18)
	tween.tween_callback(splash.queue_free)

func _on_item_used(character: Node, item_id: StringName) -> void:
	var racer := character as WildDashCharacterController
	if racer == null or not racer.has_meta(&"tidal_clash_water"):
		return
	if item_id == ItemSystem.WILD_TURBO:
		_spawn_ring(racer.global_position, 2.1)
		_play_sfx("skill", 0.62)
	elif item_id == ItemSystem.SHOCKWAVE:
		_spawn_ring(racer.global_position, 4.0)
		_play_sfx("splash", 0.72)

func _on_item_hit(target: Node, _source: Node, effect_id: StringName, blocked: bool) -> void:
	var racer := target as WildDashCharacterController
	if blocked or racer == null or not racer.has_meta(&"tidal_clash_water"):
		return
	var effect := String(effect_id).to_lower()
	if effect.contains("bomb") or effect.contains("acorn") or effect.contains("rocket"):
		_spawn_ring(racer.global_position, 3.1 if effect.contains("bomb") else 2.2)
		_play_sfx("splash", 0.78)

func _set_hud(text: String) -> void:
	var hud_value: Variant = get_parent().get("hud")
	if hud_value is WildDashModeHUD:
		(hud_value as WildDashModeHUD).set_message(text)

func _play_sfx(id: String, volume: float) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx_id", id, volume)
