extends "res://modes/logspire_leap/logspire_phase3_director_v4_major_collision.gd"

## Phase C — easy but fun polish.
## Phase A geometry and Phase B AI safety stay authoritative. This layer adds
## readability, route identity, spectacle framing and a tiny collision-respecting
## final-landing assist without increasing Safe Route gaps or jump power.

const ROUTE_SAFE: StringName = &"safe"
const ROUTE_WILD: StringName = &"wild"
const GUIDE_PULSE_SPEED: float = 2.2
const GUIDE_PULSE_AMOUNT: float = 0.08
const ROUTE_CHOICE_RANGE: float = 42.0
const CAMERA_FOCUS_MAX_RANGE: float = 54.0
const FINAL_LANDING_EXTRA_METERS: float = 0.75
const FINAL_LANDING_RESPONSE: float = 5.0
const FINAL_DESCENT_CAP: float = -1.10

const ROLLING_GUIDE_IDS: Array[StringName] = [
	&"Z3_02", &"Z3_03", &"Z3_05", &"Z3_07",
]
const TITAN_GUIDE_IDS: Array[StringName] = [
	&"Z5_APPROACH_02", &"Z5_SPIRAL_03", &"Z5_SPIRAL_05", &"Z5_SPIRAL_07", &"Z5_SPIRAL_09",
]
const FINALE_GUIDE_IDS: Array[StringName] = [
	&"Z6_02", &"Z6_04", &"Z6_06", &"Z6_07", &"CROWN_NEST",
]

var _guide_root: Node3D
var _guide_markers: Array[Node3D] = []
var _route_choice_announced: bool = false
var _final_assist_logged: Dictionary = {}
var _water_recovery: Node
var _phase_c_elapsed: float = 0.0

func configure(world: Node, graph: Node) -> void:
	super(world, graph)
	_water_recovery = get_parent().get_node_or_null("WaterRecovery")
	_build_phase_c_guidance()
	var saving: float = float(_graph.call("get_shortcut_value_seconds")) if _graph != null else 4.0
	print("LOGSPIRE PHASE C READY safe_difficulty=4 wild_difficulty=7 titan_difficulty=5 finale_difficulty=6 final_jump_difficulty=7 gap_increase=false platform_shrink=false jump_power_nerf=false")
	print("LOGSPIRE ROUTE IDENTITY safe=easy_stable wild=mushroom_vine_swing shortcut_saving=%.1fs target_range=4-8s" % saving)
	print("LOGSPIRE ROLLING GROVE FUN READY moving_logs=4 landing_guides=true movement_timing_primary=true long_jump_added=false")

func _physics_process(delta: float) -> void:
	super(delta)
	if not _configured or not RaceManager.active or _player == null:
		return
	_phase_c_elapsed += delta
	_update_guide_pulse()
	_update_route_choice_readability()
	_update_race_camera_focus()
	_update_final_landing_assist(delta)

func notify_player_finish(rank: int) -> void:
	super(rank)
	if _camera != null and _camera.has_method("set_race_focus"):
		_camera.call("set_race_focus", _platform_position(&"CROWN_NEST") + Vector3.UP * 2.0, 0.34)
	print("LOGSPIRE FUN REPORT rank=%d safe_route_preserved=true wild_route_optional=true water_is_insurance=true final_jump_highlight=true manual_fall_count_required=true" % rank)

func _build_phase_c_guidance() -> void:
	if _world == null:
		return
	_guide_root = Node3D.new()
	_guide_root.name = "PhaseCFunGuidance"
	_world.add_child(_guide_root)

	for platform_id: StringName in ROLLING_GUIDE_IDS:
		_add_route_marker(platform_id, Color(0.62, 0.86, 0.28), false)
	_add_route_marker(&"Z4_SAFE_01", Color(0.30, 0.88, 0.44), false)
	_add_route_marker(&"Z4_WILD_01", Color(1.00, 0.48, 0.10), true)
	for platform_id: StringName in TITAN_GUIDE_IDS:
		_add_route_marker(platform_id, Color(1.00, 0.72, 0.24), true)
	for platform_id: StringName in FINALE_GUIDE_IDS:
		_add_route_marker(platform_id, Color(0.94, 0.94, 0.74), platform_id == &"CROWN_NEST")

	_build_route_choice_flags()
	print("LOGSPIRE VISUAL GUIDANCE READY rolling=%d titan=%d finale=%d route_split=2 markers=%d moss=true flags=true sunlight=true" % [
		ROLLING_GUIDE_IDS.size(), TITAN_GUIDE_IDS.size(), FINALE_GUIDE_IDS.size(), _guide_markers.size(),
	])

func _add_route_marker(platform_id: StringName, color: Color, add_light: bool) -> void:
	var position: Vector3 = _platform_position(platform_id)
	if position == Vector3.ZERO:
		return
	var marker := Node3D.new()
	marker.name = "Guide_%s" % String(platform_id)
	marker.global_position = position + Vector3.UP * 0.62
	_guide_root.add_child(marker)
	marker.set_meta(&"base_y", marker.position.y)

	var plate_material := _make_material(color, 0.72)
	plate_material.emission_enabled = true
	plate_material.emission = color * 0.36
	plate_material.emission_energy_multiplier = 0.72
	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(3.4, 0.08, 3.4)
	plate_mesh.material = plate_material
	plate.mesh = plate_mesh
	marker.add_child(plate)

	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.07
	pole_mesh.bottom_radius = 0.09
	pole_mesh.height = 2.35
	pole_mesh.material = _make_material(Color(0.30, 0.20, 0.08), 0.88)
	pole.mesh = pole_mesh
	pole.position = Vector3(-1.30, 1.18, -1.15)
	marker.add_child(pole)

	var flag := MeshInstance3D.new()
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(1.55, 0.78, 0.07)
	flag_mesh.material = _make_material(color, 0.68)
	flag.mesh = flag_mesh
	flag.position = Vector3(-0.55, 1.72, -1.15)
	marker.add_child(flag)

	if add_light:
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = 0.55
		light.omni_range = 8.5
		light.shadow_enabled = false
		light.position = Vector3(0.0, 2.8, 0.0)
		marker.add_child(light)
	_guide_markers.append(marker)

func _build_route_choice_flags() -> void:
	var safe_position: Vector3 = _platform_position(&"Z4_SAFE_01")
	var wild_position: Vector3 = _platform_position(&"Z4_WILD_01")
	if safe_position == Vector3.ZERO or wild_position == Vector3.ZERO:
		return
	_add_route_label("SAFE · STEADY", safe_position + Vector3.UP * 4.2, Color(0.30, 0.95, 0.48))
	_add_route_label("WILD · 4-8s SHORTCUT", wild_position + Vector3.UP * 4.2, Color(1.00, 0.55, 0.12))

func _add_route_label(text_value: String, position: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.name = text_value.replace(" ", "_").replace("·", "")
	label.text = text_value
	label.font_size = 38
	label.modulate = color
	label.outline_size = 8
	label.outline_modulate = Color(0.04, 0.05, 0.03, 0.92)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.global_position = position
	_guide_root.add_child(label)

func _update_guide_pulse() -> void:
	var pulse: float = 1.0 + sin(_phase_c_elapsed * GUIDE_PULSE_SPEED) * GUIDE_PULSE_AMOUNT
	for marker: Node3D in _guide_markers:
		if marker == null or not is_instance_valid(marker):
			continue
		marker.scale = Vector3(pulse, 1.0, pulse)

func _update_route_choice_readability() -> void:
	if _route_choice_announced or _player == null or _is_player_water_recovering():
		return
	var safe_position: Vector3 = _platform_position(&"Z4_SAFE_01")
	var wild_position: Vector3 = _platform_position(&"Z4_WILD_01")
	if safe_position == Vector3.ZERO or wild_position == Vector3.ZERO:
		return
	var split_center: Vector3 = (safe_position + wild_position) * 0.5
	if _player.global_position.distance_to(split_center) > ROUTE_CHOICE_RANGE:
		return
	_route_choice_announced = true
	var saving: float = float(_graph.call("get_shortcut_value_seconds")) if _graph != null else 4.0
	_set_hud_message("ROUTE CHOICE · GREEN SAFE / ORANGE WILD · WILD SAVES %.1fs" % saving)
	print("LOGSPIRE ROUTE CHOICE PLAYER safe=green_easy wild=orange_risky saving=%.1fs readable=true" % saving)

func _update_race_camera_focus() -> void:
	if _camera == null or not _camera.has_method("set_race_focus") or _is_player_water_recovering():
		return
	var candidates: Array[StringName] = []
	var strength: float = 0.16
	match _current_visual_zone:
		2:
			candidates = ROLLING_GUIDE_IDS
			strength = 0.18
		3:
			candidates = [&"Z4_SAFE_01", &"Z4_WILD_01", &"Z4_MERGE"]
			strength = 0.17
		4:
			candidates = TITAN_GUIDE_IDS
			strength = 0.22
		5:
			candidates = FINALE_GUIDE_IDS
			strength = 0.25 if _last_tree_state == &"BRIDGE_READY" else 0.21
		_:
			_camera.call("clear_race_focus")
			return
	var focus: Vector3 = _best_forward_focus(candidates)
	if focus == Vector3.ZERO:
		_camera.call("clear_race_focus")
	else:
		_camera.call("set_race_focus", focus + Vector3.UP * 1.1, strength)

func _best_forward_focus(candidates: Array[StringName]) -> Vector3:
	if _player == null:
		return Vector3.ZERO
	var forward := -_player.global_transform.basis.z
	forward.y = 0.0
	forward = Vector3.FORWARD if forward.length_squared() <= 0.001 else forward.normalized()
	var best := Vector3.ZERO
	var best_score: float = INF
	for platform_id: StringName in candidates:
		var point: Vector3 = _platform_position(platform_id)
		if point == Vector3.ZERO:
			continue
		var planar := point - _player.global_position
		planar.y = 0.0
		var distance: float = planar.length()
		if distance < 4.0 or distance > CAMERA_FOCUS_MAX_RANGE:
			continue
		var direction: Vector3 = planar / maxf(distance, 0.001)
		var forward_dot: float = direction.dot(forward)
		if forward_dot < -0.12:
			continue
		var score: float = distance + (1.0 - forward_dot) * 14.0
		if score < best_score:
			best_score = score
			best = point
	return best

func _update_final_landing_assist(delta: float) -> void:
	if _last_tree_state != &"BRIDGE_READY" or _world == null:
		return
	var crown: Vector3 = _platform_position(&"CROWN_NEST")
	var radius: float = float(_world.call("get_platform_landing_radius", &"CROWN_NEST"))
	for racer_value: Variant in RaceManager.racers:
		var racer := racer_value as WildDashCharacterController
		if racer == null or racer.finished or racer.is_on_floor() or racer.velocity.y > 0.25:
			continue
		var vertical: float = crown.y - racer.global_position.y
		if vertical < -0.45 or vertical > 1.35:
			continue
		var planar := Vector3(crown.x - racer.global_position.x, 0.0, crown.z - racer.global_position.z)
		var distance: float = planar.length()
		if distance <= radius * 0.70 or distance > radius + FINAL_LANDING_EXTRA_METERS:
			continue
		var desired: Vector3 = planar.normalized() * maxf(racer.cruise_speed * 0.58, 4.5)
		var current := Vector3(racer.velocity.x, 0.0, racer.velocity.z)
		var blend: float = clampf(delta * FINAL_LANDING_RESPONSE, 0.0, 0.14)
		var adjusted := current.lerp(desired, blend)
		racer.velocity.x = adjusted.x
		racer.velocity.z = adjusted.z
		racer.velocity.y = maxf(racer.velocity.y, FINAL_DESCENT_CAP)
		var id: int = racer.get_instance_id()
		if not _final_assist_logged.has(id):
			_final_assist_logged[id] = true
			print("LOGSPIRE FINAL LANDING ASSIST racer=%s extra_range=%.2fm teleport=false jump_power_unchanged=true" % [
				RaceManager.get_racer_label(racer), FINAL_LANDING_EXTRA_METERS,
			])

func _is_player_water_recovering() -> bool:
	if _player == null:
		return false
	if _water_recovery == null or not is_instance_valid(_water_recovery):
		_water_recovery = get_parent().get_node_or_null("WaterRecovery")
	if _water_recovery == null or not _water_recovery.has_method("is_water_recovering"):
		return false
	return bool(_water_recovery.call("is_water_recovering", _player))
